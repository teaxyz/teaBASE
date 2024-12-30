@import Foundation;
@import AppKit;

NSString *brewPath(void) {
#if __arm64__
    return @"/opt/homebrew/bin/brew";
#else
    return @"/usr/local/bin/brew";
#endif
}

BOOL run(NSString *cmd, NSArray *args, NSPipe *pipe) {
    if (![NSFileManager.defaultManager isExecutableFileAtPath:cmd]) {
        // throws an exception if cannot execute which makes the prefpane go POOF
        return -1;
    }
    
    id brew = [brewPath() stringByDeletingLastPathComponent];
    id PATH = [NSString stringWithFormat:@"%@:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin", brew];
    
    NSTask *task = [NSTask new];
    [task setLaunchPath:cmd];
    [task setArguments:args];
    // need to add other PATHs to PATH since GUI apps don’t operate with the user’s shell rc added
    [task setEnvironment:@{
        @"PATH": PATH,
        @"HOME": NSHomeDirectory()
    }];
    if (pipe) [task setStandardError:pipe];
    id error;
    @try {
        [task launchAndReturnError:&error]; // configures task to not throw and thus potentially break us
        if (!error) {
            [task waitUntilExit];
            return task.terminationStatus == 0;
        } else {
            NSLog(@"teaBASE: %@", error);
            return -1;
        }
    } @catch (id e) {
        NSLog(@"teaBASE: %@", e);
        return -2;
    }
}

NSString *which(NSString *cmd) {
    id brew = [brewPath() stringByDeletingLastPathComponent];
    NSArray *paths = @[brew, @"/usr/local/bin", @"/usr/bin", @"/bin", @"/usr/sbin", @"/sbin"];
    
    for (NSString *dir in paths) {
        NSString *path = [dir stringByAppendingPathComponent:cmd];
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:path]) {
            return path;
        }
    }
    
    return cmd; //ohwell
}

NSString *output(NSString *cmd, NSArray *args) {
    if (![NSFileManager.defaultManager isExecutableFileAtPath:cmd]) {
        // throws an exception if cannot execute which makes the prefpane go POOF
        return nil;
    }
    
    NSTask *task = [NSTask new];
    [task setLaunchPath:cmd];
    [task setArguments:args];
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    id error;
    [task launchAndReturnError:&error]; // configures task to not throw and thus potentially break us
    if (error) return nil;
    [task waitUntilExit];
    if (task.terminationStatus == 0) {
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        id str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    } else {
        return nil;
    }
}

BOOL file_contains(NSString *path, NSString *token) {
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    
    if (fileHandle == nil) {
        return NO; // TODO error condition
    }
    
    // Read the first 1024 bytes (or less if the file is shorter)
    NSData *fileData = [fileHandle readDataOfLength:1024];
    [fileHandle closeFile];
    
    if (fileData == nil || [fileData length] == 0) {
        return NO; // TODO error condition
    }
    
    // Convert the data to a string
    NSString *fileContents = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
    
    if (fileContents == nil) {
        return NO; // TODO error condition
    }
    
    // Normalize whitespace in both strings before comparison
    NSString *normalizedContents = [fileContents stringByReplacingOccurrencesOfString:@"\\s+" withString:@" " options:NSRegularExpressionSearch range:NSMakeRange(0, fileContents.length)];
    NSString *normalizedToken = [token stringByReplacingOccurrencesOfString:@"\\s+" withString:@" " options:NSRegularExpressionSearch range:NSMakeRange(0, token.length)];
    
    NSRange range = [normalizedContents rangeOfString:normalizedToken];
    return (range.location != NSNotFound);
}

BOOL sudo_run_cmd(char *cmd, char *arguments[], NSString *errorTitle) {
    
    #define DIE(xx) { dispatch_async(dispatch_get_main_queue(), ^{ \
            NSAlert *alert = [NSAlert new]; \
            alert.messageText = errorTitle; \
            alert.informativeText = @"dunno why ∵ we cannot get stderr (stage " xx ")"; \
            [alert runModal]; \
            AuthorizationFree(authorization, kAuthorizationFlagDefaults); \
    }); return NO; }

    AuthorizationRef authorization;
    OSStatus status = AuthorizationCreate(NULL, NULL, kAuthorizationFlagDefaults, &authorization);
    if (status != errAuthorizationSuccess) DIE("0");

    AuthorizationItem items = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationRights rights = {1, &items};
    status = AuthorizationCopyRights(authorization, &rights, NULL, kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights | kAuthorizationFlagPreAuthorize, NULL);

    if (status != errAuthorizationSuccess) DIE();
    if (status != errAuthorizationSuccess) DIE("1");
    
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    status = AuthorizationExecuteWithPrivileges(authorization, cmd, kAuthorizationFlagDefaults, arguments, NULL);
  #pragma clang diagnostic pop
    
    if (status != errAuthorizationSuccess) DIE("2");
    
    int wait_status;
    pid_t pid = wait(&wait_status);
    if (pid == -1 || !WIFEXITED(wait_status) || WEXITSTATUS(wait_status) != 0) {
        DIE();
    }

    AuthorizationFree(authorization, kAuthorizationFlagDefaults);
    
    return YES;
    
    #undef DIE
}

BOOL run_in_terminal(NSString *input) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *commandFilePath = nil;
    NSError *error = nil;
    
    if ([input hasSuffix:@".command"] && [fileManager fileExistsAtPath:input]) {
        // If the input is a valid `.command` file, use it directly
        commandFilePath = input;
    } else {
        NSString *tempDir = [fileManager URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:[NSURL fileURLWithPath:NSHomeDirectory()] create:YES error:&error].path;
        NSString *tempFileName = [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"command"];
        commandFilePath = [tempDir stringByAppendingPathComponent:tempFileName];
        
        // Add a shebang and the input string as content
        NSString *commandContent = [NSString stringWithFormat:@"#!/bin/sh\n%@\n%@",
            input,
            @"rm \"$0\"; rmdir \"$(dirname \"$0\")\""  // delete self afterwards
        ];
        
        // Write the content to the temporary file
        [commandContent writeToFile:commandFilePath
                         atomically:YES
                           encoding:NSUTF8StringEncoding
                              error:&error];
        
        if (error) {
            NSLog(@"teaBASE: failed to write temporary file: %@", error);
            return NO;
        }
        
        // Make the temporary file executable
        if (![fileManager setAttributes:@{NSFilePosixPermissions: @(0755)}
                           ofItemAtPath:commandFilePath
                                  error:&error]) {
            NSLog(@"teaBASE: failed to set file executable: %@", error);
            return NO;
        }
    }
    
    NSURL *fileURL = [NSURL fileURLWithPath:commandFilePath];
    BOOL success = [[NSWorkspace sharedWorkspace] openURL:fileURL];

    if (!success) {
        NSLog(@"teaBASE: execution failed: %@", input);
    }
    
    return success;
}


@interface VerticallyAlignedTextFieldCell: NSTextFieldCell
@end

@implementation VerticallyAlignedTextFieldCell

- (NSRect)titleRectForBounds:(NSRect)theRect {
    NSRect titleFrame = [super titleRectForBounds:theRect];
    NSSize titleSize = [[self attributedStringValue] size];
    titleFrame.origin.y = theRect.origin.y - .5 + (theRect.size.height - titleSize.height) / 2.0;
    return titleFrame;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSRect titleRect = [self titleRectForBounds:cellFrame];
    [[self attributedStringValue] drawInRect:titleRect];
}

@end


@interface DraggableIconView : NSImageView <NSDraggingSource>
@end

@implementation DraggableIconView

- (void)mouseDown:(NSEvent *)event {
    id filePath = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/cd to.app"];
    
    // Create a pasteboard item with the file URL
    NSPasteboardItem *pasteboardItem = [NSPasteboardItem new];
    [pasteboardItem setString:filePath forType:NSPasteboardTypeFileURL];
    
    // Create the dragging item
    NSDraggingItem *draggingItem = [[NSDraggingItem alloc] initWithPasteboardWriter:pasteboardItem];
    [draggingItem setDraggingFrame:self.bounds contents:self.image];
    
    // Begin the dragging session
    [self beginDraggingSessionWithItems:@[draggingItem] event:event source:self];
}

#pragma mark - NSDraggingSource

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    return NSDragOperationCopy; // Allow copying the item
}

@end
