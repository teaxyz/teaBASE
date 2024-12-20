#import "teaBASE.h"

@implementation teaBASE (DevTools)

- (IBAction)installBrew:(NSSwitch *)sender {
    if (![NSFileManager.defaultManager isExecutableFileAtPath:@"/Library/Developer/CommandLineTools/usr/bin/git"]) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"Prerequisite Unsatisfied";
        alert.informativeText = @"Homebrew requires the Xcode Command Line Tools (CLT) to be installed first";
        [alert runModal];
        
        [sender setState:NSControlStateValueOff];
        return;
    }
    
    if (sender.state == NSControlStateValueOn) {
        [self.brewManualInstallInstructions setEditable:YES];
        [self.brewManualInstallInstructions checkTextInDocument:sender];
        [self.brewManualInstallInstructions setEditable:NO];
        
        [self.mainView.window beginSheet:self.brewInstallWindow completionHandler:^(NSModalResponse returnCode) {
            if (returnCode != NSModalResponseOK) {
                [self.homebrewSwitch setState:NSControlStateValueOff];
            } else {
                [self updateVersions];
            }
            [self.brewInstallWindowSpinner stopAnimation:sender];
        }];
    } else {
    #if __arm64
        // Get the contents of the directory
        NSError *error = nil;
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/opt/homebrew" error:&error];
        
        if (error) {
            [[NSAlert alertWithError:error] runModal];
            return;
        }
        
        // Iterate over each item in the directory
        for (NSString *item in contents) {
            NSString *itemPath = [@"/opt/homebrew" stringByAppendingPathComponent:item];
            
            BOOL success = [[NSFileManager defaultManager] removeItemAtPath:itemPath error:&error];
            if (!success) {
                [[NSAlert alertWithError:error] runModal];
                return;
            }
        }
        
        [self updateVersions];
    #else
        NSAlert *alert = [NSAlert new];
        alert.informativeText = @"Please manually run the Homebrew uninstall script";
        [alert runModal];
        [sender setState:NSControlStateValueOn];
    #endif
    }
}

static BOOL installer(NSURL *url) {
    NSURL *newurl = [[url URLByDeletingPathExtension] URLByAppendingPathExtension:@".pkg"];
    [NSFileManager.defaultManager moveItemAtURL:url toURL:newurl error:nil];
            
    char *arguments[] = {"-pkg", (char*)newurl.fileSystemRepresentation, "-target", "/", NULL};
    
    return sudo_run_cmd("/usr/sbin/installer", arguments, @"Homebrew install failed");
}

static NSString* fetchLatestBrewVersion(void) {
    NSURL *url = [NSURL URLWithString:@"https://api.github.com/repos/Homebrew/brew/releases/latest"];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) return nil;
    
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || !json[@"tag_name"]) return nil;
    
    NSString *version = json[@"tag_name"];
    if ([version hasPrefix:@"v"]) {
        version = [version substringFromIndex:1];
    }
    return version;
}

- (IBAction)installBrewStep2:(NSButton *)sender {
    [sender setEnabled:NO];
    [self.brewInstallWindowSpinner startAnimation:sender];
    
    NSString *version = fetchLatestBrewVersion();
    if (!version) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"Failed to fetch latest Homebrew version";
        alert.informativeText = @"Please try again later or install manually.";
        [alert runModal];
        [NSApp endSheet:self.brewInstallWindow returnCode:NSModalResponseAbort];
        [sender setEnabled:YES];
        return;
    }
    
    NSString *urlstr = [NSString stringWithFormat:@"https://github.com/Homebrew/brew/releases/download/%@/Homebrew-%@.pkg", version, version];
    NSURL *url = [NSURL URLWithString:urlstr];

    [[[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSAlert alertWithError:error] runModal];
                [NSApp endSheet:self.brewInstallWindow returnCode:NSModalResponseAbort];
                [sender setEnabled:YES];
            });
        } else if (installer(location)) {
                // ^^ Runs the installer on the NSURLSession queue. The downloaded
                // file is deleted when the installation completes, which appears to be fine.
            dispatch_async(dispatch_get_main_queue(), ^{
                
                if (self.setupBrewShellEnvCheckbox.state == NSControlStateValueOn) {
                    NSString *zprofilePath = [NSHomeDirectory() stringByAppendingPathComponent:@".zprofile"];
                    NSString *cmdline = [NSString stringWithFormat:@"eval \"$(%@ shellenv)\"", brewPath()];
                    
                    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:zprofilePath];
                    
                    // Check if the file exists, if not create it
                    if (!exists) {
                        [[NSFileManager defaultManager] createFileAtPath:zprofilePath contents:nil attributes:nil];
                    }
                    if (!file_contains(zprofilePath, cmdline)) {
                        // Open the file for appending
                        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:zprofilePath];
                        if (fileHandle) {
                            [fileHandle seekToEndOfFile];
                            if (exists) {
                                [fileHandle writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
                            }
                            [fileHandle writeData:[cmdline dataUsingEncoding:NSUTF8StringEncoding]];
                            [fileHandle writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
                            [fileHandle closeFile];
                        } else {
                            //TODO
                        }
                    }
                }

                [NSApp endSheet:self.brewInstallWindow returnCode:NSModalResponseOK];
                [sender setEnabled:YES];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [NSAlert new];
                alert.messageText = @"Installation Error";
                alert.informativeText = @"Unknown error occurred. Please install Homebrew manually.";
                [alert runModal];
                [NSApp endSheet:self.brewInstallWindow returnCode:NSModalResponseAbort];
                [sender setEnabled:YES];
            });
        }
    }] resume];
}

- (IBAction)installPkgx:(NSSwitch *)sender {
    if (sender.state == NSControlStateValueOn) {
        [self installSubexecutable:@"pkgx"];
        [self updateVersions];
    } else {
        char *args[] = {"/usr/local/bin/pkgx", NULL};
        sudo_run_cmd("/bin/rm", args, @"Couldn’t delete /usr/local/bin/pkgx");
    }
}

- (IBAction)installDocker:(NSSwitch *)sender {
    // using Terminal as the install steps requires `sudo`
    // using script as you can only pass a single arg to Terminal.app apparently
    id path = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/Scripts/install-docker.sh"];
    run(@"/usr/bin/open", @[@"-a", @"Terminal.app", path], nil);
}

- (IBAction)openDockerHome:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://docker.com"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)openPkgxHome:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://pkgx.sh"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)openHomebrewHome:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://brew.sh"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)openXcodeCLTHome:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://developer.apple.com/xcode/resources/"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)gitAddOnsHelpButton:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://github.com/pkgxdev/git-gud"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

@end
