#import "teaBASE.h"

@implementation teaBASE (Helpers)

- (void)installSubexecutable:(NSString *)name {
    NSString *src = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"Contents/MacOS/%@", name]];
    NSString *script = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/Scripts/usr-local-install.sh"];
    
    char *arguments[] = {(char *)src.fileSystemRepresentation, NULL};
    
    // we cannot use bash
    sudo_run_cmd((char *)script.fileSystemRepresentation, arguments, [NSString stringWithFormat:@"`%@` install failed", name]);
}

- (BOOL)xcodeCLTInstalled {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/xcode-select"];
    [task setArguments:@[@"-p"]];
    
    NSPipe *nullPipe = [NSPipe pipe];
    [task setStandardOutput:nullPipe];
    [task setStandardError:nullPipe];
    
    NSError *error = nil;
    [task launchAndReturnError:&error];
    
    if (error) {
        NSLog(@"teaBASE: xcodeCLTInstalled [error]: %@", error);
        return NO;
    }
    
    [task waitUntilExit];
    
    NSLog(@"teaBASE: xcodeCLTInstalled [output]: %d", task.terminationStatus);
    
    return task.terminationStatus == 0;
}

- (BOOL)xcodeInstalled {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/mdfind"];
    [task setArguments:@[@"kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'"]];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task setStandardError:pipe];
    
    NSError *error = nil;
    [task launchAndReturnError:&error];
    
    if (error) {
        NSLog(@"teaBASE: xcodeInstalled [error]: %@", error);
        return NO;
    }
    
    NSFileHandle *fileHandle = [pipe fileHandleForReading];
    NSData *data = [fileHandle readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    [task waitUntilExit];
    
    NSLog(@"teaBASE: xcodeInstalled [output]: %@", output);
    
    return output.length > 0;
}

- (BOOL)homebrewInstalled {
    return [NSFileManager.defaultManager isReadableFileAtPath:brewPath()];
}

- (BOOL)pkgxInstalled {
    //TODO need to check more locations
    return [NSFileManager.defaultManager isReadableFileAtPath:@"/usr/local/bin/pkgx"];
}

- (IBAction)modalCancel:(NSButton *)sender {
    [NSApp endSheet:[sender window] returnCode:NSModalResponseCancel];
}

- (IBAction)modalOK:(NSButton *)sender {
    [NSApp endSheet:[sender window] returnCode:NSModalResponseOK];
}

@end
