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
                // ^^ runs the installer on the NSURLSession queue as the download
                // is deleted when it exits. afaict this is fine.
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
    // using a terminal as the install steps requires `sudo`
    id path = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/Scripts/install-docker.sh"];
    run_in_terminal(path);
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

- (IBAction)installCaskItem:(NSButton *)sender {
    if (![NSFileManager.defaultManager isExecutableFileAtPath:brewPath()]) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"Prerequisite Unsatisfied";
        alert.informativeText = @"Homebrew must be installed first.";
        [alert runModal];
        return;
    }
    
    id cmd = [NSString stringWithFormat:@"brew install --cask %@", sender.identifier];
    run_in_terminal(cmd);
    [sender setTitle:@"Installing…"];
    [sender setImage:[NSImage imageWithSystemSymbolName:@"circle.lefthalf.striped.horizontal.inverse" accessibilityDescription:nil]];
}

NSString* getBundleIDForUTI(NSString* uti) {
    CFStringRef cfUTI = (__bridge CFStringRef)uti;
    LSRolesMask role = kLSRolesAll;

    CFStringRef bundleID = LSCopyDefaultRoleHandlerForContentType(cfUTI, role);

    if (bundleID != NULL) {
        NSString* result = (__bridge_transfer NSString*)bundleID;
        return result;
    }

    return nil;
}

- (void)updateInstallationStatuses {
    for (NSPopUpButton *chooser in @[self.defaultTerminalChooser, self.defaultEditorChooser]) {
        [chooser removeAllItems];
        [chooser addItemWithTitle:@"Terminal.app"];
        [chooser itemAtIndex:0].identifier = @"com.apple.terminal";
    }

    #define update_button(btn, bundleID, chooser, title) { \
        BOOL is_installed = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:bundleID] != nil; \
        [btn setTitle:is_installed ? @"Installed" : @"Install"]; \
        [btn setImage:[NSImage imageWithSystemSymbolName:is_installed ? @"checkmark.circle" : @"arrow.down.circle" accessibilityDescription:nil]]; \
        [btn setEnabled:!is_installed]; \
        if (is_installed) [chooser addItemWithTitle:title]; \
        if ([defaultBundleID isEqualToString:bundleID]) [chooser selectItemWithTitle:title]; \
        [chooser itemWithTitle:title].identifier = bundleID; \
    }
    
    #define update(btn, bundleID) \
        update_button(btn, bundleID, self.defaultTerminalChooser, btn.identifier)
    
    NSString* defaultBundleID = getBundleIDForUTI(@"public.unix-executable");
    update(self.warpInstallButton, @"dev.warp.Warp-Stable");
    update(self.hyperInstallButton, @"co.zeit.Hyper");
    update(self.iterm2InstallButton, @"com.googlecode.iterm2");
    
    #undef update
    #define update(btn, bundleID, title) \
        update_button(btn, bundleID, self.defaultEditorChooser, title); \
        if ([bundleID isEqualToString:defaultBundleID]) { \
            self.defaultEditorLabel.stringValue = title; \
        }
    
    defaultBundleID = getBundleIDForUTI(@"public.plain-text");
    update(self.vscodeInstallButton, @"com.microsoft.VSCode", @"Visual Studio Code");
    update(self.cotEditorInstallButton, @"com.coteditor.CotEditor", @"Cot");
    update(self.zedInstallButton, @"dev.zed.Zed", @"Zed");
    update(self.cursorInstallButton, @"com.todesktop.230313mzl4w4u92", @"Cursor");
  #undef update
}

- (IBAction)onDefaultTerminalChanged:(NSPopUpButton *)sender {
    CFStringRef bundleID = (__bridge CFStringRef)sender.selectedItem.identifier;
    
    LSSetDefaultRoleHandlerForContentType((__bridge CFStringRef)@"public.unix-executable", kLSRolesShell, bundleID);
    LSSetDefaultRoleHandlerForContentType((__bridge CFStringRef)@"com.apple.terminal.shell-script", kLSRolesShell, bundleID);
    
    [self updateInstallationStatuses];
}

- (IBAction)openCdToLocationInFinder:(id)sender {
    id path = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/cd to.app"];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:path]]];
}

- (IBAction)showDefaultEditorWindow:(id)sender {
    [[sender window] beginSheet:self.defaultEditorWindow completionHandler:^(NSModalResponse returnCode) {
        
        CFStringRef bundleID = (__bridge CFStringRef)self.defaultEditorChooser.selectedItem.identifier;
        
        LSSetDefaultRoleHandlerForContentType((__bridge CFStringRef)@"public.plain-text", kLSRolesEditor | kLSRolesViewer, bundleID);
        
        if (self.addAdditionalProgrammerTextFormatsCheckbox.state == NSControlStateValueOn) {
            id utis = @[
                @"public.swift-source",
                @"public.geojson",
                @"public.protobuf-source",
                @"com.apple.property-list",
                @"com.apple.xml-property-list",
                @"com.apple.ascii-property-list",
                @"public.c-header",
                @"public.c-plus-plus-header",
                @"public.c-source",
                @"public.c-source.preprocessed",
                @"public.opencl-source",
                @"public.module-map",
                @"public.objective-c-source",
                @"public.objective-c-source.preprocessed",
                @"public.objective-c-plus-plus-source",
                @"public.objective-c-plus-plus-source.preprocessed",
                @"public.c-plus-plus-source",
                @"public.c-plus-plus-source.preprocessed",
                @"public.assembly-source",
                @"public.nasm-assembly-source",
                @"public.yacc-source",
                @"public.lex-source",
                @"public.mig-source",
                @"public.ruby-script",
                @"public.python-script",
                @"public.php-script",
                @"public.perl-script",
                @"public.make-source",
                @"public.bash-script",
                @"public.shell-script",
                @"public.csh-script",
                @"public.ksh-script",
                @"public.tcsh-script",
                @"public.zsh-script",
                @"public.xml",
                @"net.daringfireball.markdown",
                @"public.json",
                @"public.yaml",
                @"public.css",
                @"com.microsoft.typescript",
                @"org.python.restructuredtext",
                @"org.lua.lua-source",
                @"com.netscape.javascript-source",
                @"org.rust-lang.rust-script",
                @"public.html",  //NOTE doesn't seem to stick
                @"org.golang.go-script",
                @"public.comma-separated-values-text",
                @"org.iso.sql",
                @"com.sun.java-source",
                @"com.microsoft.c-sharp",
                @"org.tug.tex",
                @"public.toml",
                @"com.microsoft.ini",
                @"public.patch-file",
                @"dev.dart.dart-script"
            ];
            
            for (id uti in utis) {
                LSSetDefaultRoleHandlerForContentType((__bridge CFStringRef)uti, kLSRolesEditor | kLSRolesViewer, bundleID);
            }
        }
    }];
}

@end
