#import "teaBASE.h"

@implementation teaBASE

- (void)mainViewDidLoad {
    for (NSTableColumn *col in self.gitExtensionsTable.tableColumns) {
        col.headerCell.attributedStringValue = [[NSAttributedString alloc] initWithString:col.title attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:10]}];
    }
}

- (void)willSelect {
    [self updateSSHStates];

    BOOL hasSignedCommits = [self gpgSignEnabled];
    
    [self updateVersions];
    
    [self.gpgSignSwitch setState:hasSignedCommits ? NSControlStateValueOn : NSControlStateValueOff];
    [self.homebrewSwitch setState:[self homebrewInstalled] ? NSControlStateValueOn : NSControlStateValueOff];
    [self.pkgxSwitch setState:[self pkgxInstalled] ? NSControlStateValueOn : NSControlStateValueOff];
    [self.xcodeCLTSwitch setState:[self xcodeCLTInstalled] ? NSControlStateValueOn : NSControlStateValueOff];
    [self.dockerSwitch setState:self.dockerVersion.stringValue.length > 0 ? NSControlStateValueOn : NSControlStateValueOff];
    [self.dotfileSyncSwitch setState:self.dotfileSyncEnabled ? NSControlStateValueOn : NSControlStateValueOff];
    [self.dotfileSyncEditWhitelistButton setEnabled:self.dotfileSyncSwitch.state == NSControlStateValueOn];
    [self.dotfileSyncViewRepoButton setEnabled:self.dotfileSyncEditWhitelistButton.enabled];
    
    if ([self.defaultsController.defaults boolForKey:@"xyz.tea.BASE.integrated-GitHub"]) {
        self.greenCheckGitHubIntegration.hidden = NO;
    }
    if ([self.defaultsController.defaults boolForKey:@"xyz.tea.BASE.printed-GPG-emergency-kit"]) {
        self.greenCheckGPGBackup.hidden = NO;
    }
    
    [self calculateSecurityRating];
    
    [self updateGitGudListing];
    [self updateGitIdentity];
    
    id v = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (v) {
        self.selfVersionLabel.stringValue = [NSString stringWithFormat:@"v%@", v];
    }
}

- (void)didSelect {
    [self checkForUpdates];
}

- (void)calculateSecurityRating {
    BOOL hasSignedCommits = self.gpgSignSwitch.state == NSControlStateValueOn;
    BOOL hasSSHPassPhrase = self.sshPassPhraseSwitch.state == NSControlStateValueOn;
    BOOL hasSSH = self.sshSwitch.state == NSControlStateValueOn;
    BOOL hasGitHubIntegration = self.greenCheckGitHubIntegration.hidden == NO;
    BOOL hasGPGBackup = self.greenCheckGPGBackup.hidden == NO;
    
    float rating = hasSignedCommits + hasSSHPassPhrase + hasSSH + hasGitHubIntegration + hasGPGBackup;
    [self.ratingIndicator setIntValue:rating];
    
    if (self.ratingIndicator.intValue >= self.ratingIndicator.maxValue) {
        [self.ratingIndicator setFillColor:[NSColor systemGreenColor]];
    } else if (self.ratingIndicator.intValue <= 1) {
        [self.ratingIndicator setFillColor:[NSColor systemRedColor]];
    }
}

- (void)updateGitIdentity {
    id pkgx = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/MacOS/pkgx"];
    id user = output(pkgx, @[@"git", @"config", @"--global", @"user.name"]);
    id mail = output(pkgx, @[@"git", @"config", @"--global", @"user.email"]);
    user = [user stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    mail = [mail stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.gitIdentityLabel.stringValue = [NSString stringWithFormat:@"%@ <%@>", user, mail];
    self.gitIdentityUsernameLabel.stringValue = user;
    self.gitIdentityEmailLabel.stringValue = mail;
}

- (void)updateSSHStates {
    BOOL hasSSH = [self checkForSSH];
    BOOL hasSSHPassPhrase = hasSSH && [self checkForSSHPassPhrase]; // check both ∵ our pp-check is false-positive if no key file
    BOOL hasICloudIntegration = hasSSH && hasSSHPassPhrase && [self checkForSSHPassphraseICloudKeychainIntegration];
    
    [self.sshSwitch setState:hasSSH ? NSControlStateValueOn : NSControlStateValueOff];
    [self.sshPassPhraseSwitch setState:hasSSHPassPhrase ? NSControlStateValueOn : NSControlStateValueOff];
    [self.sshPassphraseICloudIntegrationSwitch setState:hasICloudIntegration ? NSControlStateValueOn : NSControlStateValueOff];
    
    self.sshPassPhraseSwitch.enabled = hasSSH;
    self.sshPassphraseICloudIntegrationSwitch.enabled = hasSSH;
}

- (NSString *)sshPrivateKeyFile {
    NSURL *home = [NSFileManager.defaultManager homeDirectoryForCurrentUser];
    
    //TODO filenames can be arbituary and configurable which makes life complex
    // eg. we could just try and figure out what is used for github, but that's not our *whole* story is it?
    
    //NOTE order is same as ssh sources read order
    for (NSString *file in @[@"id_rsa", @"id_dsa", @"id_ecdsa", @"id_ed25519"]) {
        NSString *path = [[home.path stringByAppendingPathComponent:@".ssh"] stringByAppendingPathComponent:file];
        if (![NSFileManager.defaultManager isReadableFileAtPath:path]) continue;
        if (![NSFileManager.defaultManager isReadableFileAtPath:[NSString stringWithFormat:@"%@.pub", path]]) continue;
        return path;
    }
    
    return nil;
}

- (BOOL)checkForSSH {
    return [self sshPrivateKeyFile] != nil;
}

- (BOOL)checkForSSHPassPhrase {
    id path = [self sshPrivateKeyFile];
    
    // attempts to decrypt the key, if there’s a passphrase this will fail
    return run(@"/usr/bin/ssh-keygen", @[@"-y", @"-f", path, @"-P", @""], nil) == NO;
}

- (BOOL)checkForSSHPassphraseICloudKeychainIntegration {
    NSURL *home = [NSFileManager.defaultManager homeDirectoryForCurrentUser];
    id path = [home.path stringByAppendingPathComponent:@".ssh/config"];
    return file_contains(path, @"UseKeychain yes");
}

- (BOOL)xcodeCLTInstalled {
    if ([NSFileManager.defaultManager isExecutableFileAtPath:@"/Library/Developer/CommandLineTools/usr/bin/git"]) {
        return YES;
    }
    //TODO Xcode can be installed anywhere, instead check for the bundle ID with spotlight API or mdfind
    if ([NSFileManager.defaultManager isExecutableFileAtPath:@"/Applications/Xcode.app"]) {
        return YES;
    }
    return NO;
}

- (void)updateVersions {
    NSString *brew_out = output(brewPath(), @[@"--version"]);
    NSString *pkgx_out = output(@"/usr/local/bin/pkgx", @[@"--version"]);
    NSString *xcode_clt_out = output(@"/usr/sbin/pkgutil", @[@"--pkg-info=com.apple.pkg.CLTools_Executables"]);
    
    id path = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/Scripts/docker-version.sh"];

    NSString *docker_version = output(path, @[]);
    
    BOOL has_clt = [NSFileManager.defaultManager isExecutableFileAtPath:@"/Library/Developer/CommandLineTools/usr/bin/git"];
    //TODO Xcode can be installed anywhere, instead check for the bundle ID with spotlight API or mdfind
    BOOL has_xcode = [NSFileManager.defaultManager isExecutableFileAtPath:@"/Applications/Xcode.app"];
    // emulate login shell to ensure PATH contains everything the user has configured
    // ∵ GUI apps do not have full user PATH set otherwise
    NSString *git_out = nil;
    if (has_clt || has_xcode) {
        // only check if clt or xcode otherwise this may trigger the XcodeCLT installation GUI flow
        git_out = output(@"/bin/sh", @[@"-l", @"-c", @"git --version"]);
    }
    
    brew_out = [[brew_out componentsSeparatedByString:@" "] lastObject];    // Homebrew 1.2.3
    pkgx_out = [[pkgx_out componentsSeparatedByString:@" "] lastObject];    // pkgx 1.2.3
    git_out = [[git_out componentsSeparatedByString:@" "] objectAtIndex:2]; // git version 1.2.3
    xcode_clt_out = [[[[xcode_clt_out componentsSeparatedByString:@"\n"] objectAtIndex:1] componentsSeparatedByString:@" "] objectAtIndex:1]; // Version: 1.2.3
    
    self.brewVersion.stringValue = brew_out ? [NSString stringWithFormat:@"v%@", brew_out] : @"";
    self.pkgxVersion.stringValue = pkgx_out ? [NSString stringWithFormat:@"v%@", pkgx_out] : @"";
    self.gitVersion.stringValue = git_out ? [NSString stringWithFormat:@"v%@", git_out] : @"";
    self.xcodeCLTVersion.stringValue = xcode_clt_out ? [NSString stringWithFormat:@"v%@", xcode_clt_out] : @"";
    self.dockerVersion.stringValue = docker_version ? [@"v" stringByAppendingString:docker_version] : @"";
    
    [self.installGitButton setHidden:git_out != nil];
}

- (BOOL)gpgSignEnabled {
    NSURL *home = [NSFileManager.defaultManager homeDirectoryForCurrentUser];
    NSString *path = [home.path stringByAppendingPathComponent:@".gitconfig"];
    return file_contains(path, @"gpgsign = true");
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

- (IBAction)openGitHub:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://github.com/teaxyz/teaBASE"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)onShareClicked:(id)sender {
    [self openTwitterURLWithStars:self.ratingIndicator.intValue];
}


- (void)openTwitterURLWithStars:(int)starCount {
    // Construct the stars string
    NSMutableString *stars = [NSMutableString string];
    for (int i = 0; i < 5; i++) {
        if (i < starCount) {
            [stars appendString:@"★"];
        } else {
            [stars appendString:@"☆"];
        }
    }

    // URL encode the message
    NSString *message = [NSString stringWithFormat:@"I got %@ developer security with @teaprotocol’s teaBASE", stars];
    NSString *encodedMessage = [message stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];

    // Construct the full URL
    NSString *urlString = [NSString stringWithFormat:@"https://twitter.com/intent/tweet?text=%@", encodedMessage];
    NSURL *url = [NSURL URLWithString:urlString];

    // Open the URL
    [NSWorkspace.sharedWorkspace openURL:url];
}

@end


@implementation teaBASE (SSH)

- (IBAction)createSSHPrivateKey:(NSSwitch *)sender {
    id path = [self sshPrivateKeyFile] ?: [NSHomeDirectory() stringByAppendingPathComponent:@".ssh/id_ed25519"];
    
    if (sender.state == NSControlStateValueOn) {
        NSArray *arguments = @[@"-t", @"ed25519", @"-C", @"Generated by teaBASE", @"-f", path, @"-N", @""];
        
        if (run(@"/usr/bin/ssh-keygen", arguments, nil)) {
            [self calculateSecurityRating];
            [self updateSSHStates];
        } else {
            NSAlert *alert = [NSAlert new];
            alert.messageText = @"ssh-keygen failed";
            [alert runModal];
            [self.sshSwitch setState:NSControlStateValueOff];
        }
    } else {
        NSAlert *alert = [NSAlert new];
        alert.alertStyle = NSAlertStyleCritical;
        alert.messageText = @"Data Loss Warning";
        alert.informativeText = @"Deleting your SSH key pair cannot be undone by teaBASE.";
        
        NSButton *deleteButton = [alert addButtonWithTitle:@"Delete Keys"];
        deleteButton.hasDestructiveAction = YES;
        
        [alert addButtonWithTitle:@"Cancel"];
        
        [alert beginSheetModalForWindow:sender.window completionHandler:^(NSModalResponse returnCode) {
            if (returnCode == NSAlertFirstButtonReturn) {
                id err;
                if (![NSFileManager.defaultManager removeItemAtPath:path error:&err]) {
                    [[NSAlert alertWithError:err] runModal];
                    return;
                }
                id pubpath = [NSString stringWithFormat:@"%@.pub", path];
                if (![NSFileManager.defaultManager removeItemAtPath:pubpath error:&err]) {
                    [[NSAlert alertWithError:err] runModal];
                }
            }
            [self updateSSHStates];
        }];
    }
}

- (IBAction)createSSHPassPhrase:(NSSwitch *)sender {
    if (sender.state == NSControlStateValueOn) {
        [self.mainView.window beginSheet:self.sshPassphraseWindow completionHandler:^(NSModalResponse returnCode) {
            
            //TODO should not remove passphrase window until complete in case of failure
            
            if (returnCode == NSModalResponseCancel) {
                [self.sshPassPhraseSwitch setState:NSControlStateValueOff];
                return;
            }
            
            id path = [self sshPrivateKeyFile];
            
            id passphrase = self.sshPassphraseTextField.stringValue;
            
            NSPipe *pipe = [NSPipe pipe];
            
            if (!run(@"/usr/bin/ssh-keygen", @[@"-p", @"-N", passphrase, @"-f", path], pipe)) {
                id stderr = [NSString stringWithUTF8String:[pipe.fileHandleForReading readDataToEndOfFile].bytes];
                
                NSAlert *alert = [NSAlert new];
                alert.messageText = @"ssh-keygen failed";
                alert.informativeText = stderr;
                [alert runModal];
                return;
            }
            
            [self.sshPassphraseTextField setStringValue:@""]; // get it out of memory ASAP
            [self.sshPassPhraseSwitch setEnabled:NO];
            [self updateSSHStates];
            [self calculateSecurityRating];
        }];
    } else {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"Unimplemented. Soz.";
        [alert runModal];
        
        [sender setState:NSControlStateValueOn];
    }
}

- (IBAction)createSSHPassPhraseStep2:(id)sender {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Your passphrase won’t be stored";
    alert.informativeText = @"Please print the Emergency Kit and save it securely, or confirm you have another way to restore your credentials.\n\nDon’t worry—losing your SSH credentials is (usually—but tediously) recoverable.";
    [alert addButtonWithTitle:@"Print Kit"];
    [alert addButtonWithTitle:@"Proceed Without Kit"];
    [alert addButtonWithTitle:@"Cancel"];

    [alert beginSheetModalForWindow:self.sshPassphraseWindow completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self printSSHEmergencyKit:self.sshPassphraseTextField.stringValue sender:sender];
        } else if (returnCode == NSAlertSecondButtonReturn) {
            [NSApp endSheet:self.sshPassphraseWindow returnCode:NSModalResponseOK];
        }
    }];
}

- (void)printSSHEmergencyKit:(NSString *)passphrase sender:(id)sender {
    NSString *privkey_path = [self sshPrivateKeyFile];
    NSString *pubkey_path = [NSString stringWithFormat:@"%@.pub", privkey_path];
    NSString *filename = [privkey_path lastPathComponent];
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:pubkey_path encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        [[NSAlert alertWithError:error] runModal];
        return;
    }

    content = [NSString stringWithFormat:@"Recreate the following at: `~/.ssh/%@.pub`:\n\n%@", filename, content];
    
    NSString *privkey_content = [NSString stringWithContentsOfFile:privkey_path encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        [[NSAlert alertWithError:error] runModal];
        return;
    }
    
    content = [content stringByAppendingString:@"\n\n"];
    content = [content stringByAppendingString:@"Recreate the following at: `~/.ssh/"];
    content = [content stringByAppendingString:filename];
    content = [content stringByAppendingString:@"\n\n"];
    content = [content stringByAppendingString:privkey_content];
    content = [content stringByAppendingString:@"\n\n"];
    
    content = [content stringByAppendingString:@"Passphrase:\n\n"];
    content = [content stringByAppendingString:passphrase];
        
    // Create an NSTextView and set the document content
    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 612, 612)]; // Typical page size
    [textView setString:content];
    
    // Configure the print operation for the text view
    NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:textView];
    [printOperation setShowsPrintPanel:YES];
    [printOperation setShowsProgressPanel:YES];
    [printOperation setJobTitle:@"SSH_Emergency_Kit.pdf"];

    // Run the print operation (this will display the print dialog)
    [printOperation runOperationModalForWindow:[sender window] delegate:self didRunSelector:@selector(sshPrintOperationDidRun:success:) contextInfo:nil];
}

- (void)sshPrintOperationDidRun:(NSPrintOperation *)op success:(BOOL)success {
    if (success) {
        [NSApp endSheet:self.sshPassphraseWindow returnCode:NSModalResponseOK];
    }
}

- (IBAction)configureSSHPassphraseICloudKeychainIntegration:(NSSwitch *)sender {
    NSURL *home = [NSFileManager.defaultManager homeDirectoryForCurrentUser];
    NSString *sshDir = [home.path stringByAppendingPathComponent:@".ssh"];
    NSString *ssh_config = [sshDir stringByAppendingPathComponent:@"config"];
    NSString *content = @"Host *\n  UseKeychain yes";

    // Create .ssh directory if it doesn't exist and set permissions
    if (![[NSFileManager defaultManager] fileExistsAtPath:sshDir]) {
        NSError *dirError = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:sshDir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0700} error:&dirError];
        if (dirError) {
            [[NSAlert alertWithError:dirError] runModal];
            [sender setState:NSControlStateValueOff];
            return;
        }
    }

    if (sender.state == NSControlStateValueOn) {
        NSError *error = nil;
        NSString *existingContent = @"";
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:ssh_config];
        
        if (exists) {
            existingContent = [NSString stringWithContentsOfFile:ssh_config encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                [[NSAlert alertWithError:error] runModal];
                [sender setState:NSControlStateValueOff];
                return;
            }
            existingContent = [existingContent stringByAppendingString:@"\n"];
        }
        
        NSString *newContent = [existingContent stringByAppendingString:[NSString stringWithFormat:@"%@\n", content]];
        NSError *writeError = nil;
        BOOL success = [newContent writeToFile:ssh_config atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
        
        if (!success || writeError) {
            [[NSAlert alertWithError:writeError] runModal];
            [sender setState:NSControlStateValueOff];
            return;
        }

        // Check and set proper file permissions (600) if needed
        NSError *attributesError = nil;
        NSDictionary *currentAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:ssh_config error:&attributesError];
        if (attributesError) {
            [[NSAlert alertWithError:attributesError] runModal];
        } else {
            NSNumber *currentPermissions = [currentAttributes objectForKey:NSFilePosixPermissions];
            if (![currentPermissions isEqualToNumber:@0600]) {
                NSError *chmodError = nil;
                NSDictionary *attributes = @{NSFilePosixPermissions: @0600};
                [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:ssh_config error:&chmodError];
                if (chmodError) {
                    [[NSAlert alertWithError:chmodError] runModal];
                    // Don't revert the switch state since the file was written successfully
                }
            }
        }
    } else {
        NSError *error = nil;
        NSString *fileContent = [NSString stringWithContentsOfFile:ssh_config encoding:NSUTF8StringEncoding error:&error];
        
        if (error) {
            [[NSAlert alertWithError:error] runModal];
            [sender setState:NSControlStateValueOn];
            return;
        }
        
        NSMutableArray *lines = [[fileContent componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] mutableCopy];
        NSMutableArray *newLines = [NSMutableArray array];
        BOOL skipNextLine = NO;
        
        for (NSString *line in lines) {
            if (skipNextLine) {
                skipNextLine = NO;
                continue;
            }
            if ([line isEqualToString:@"Host *"]) {
                NSUInteger index = [lines indexOfObject:line];
                if (index + 1 < lines.count && [lines[index + 1] containsString:@"UseKeychain yes"]) {
                    skipNextLine = YES;
                    continue;
                }
            }
            [newLines addObject:line];
        }
        
        NSString *updatedContent = [[newLines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
        NSError *writeError = nil;
        BOOL success = [updatedContent writeToFile:ssh_config atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
        
        if (!success || writeError) {
            [[NSAlert alertWithError:writeError] runModal];
            [sender setState:NSControlStateValueOn];
            return;
        }
    }
}

@end

@implementation teaBASE (NSTextFieldDelegate)

- (void)controlTextDidChange:(NSNotification *)obj {
    self.sshApplyPassphraseButton.enabled = self.sshPassphraseTextField.stringValue.length > 0;
}

@end


@implementation teaBASE (GPG)

- (IBAction)signCommits:(NSSwitch *)sender {
    NSString *git = which(@"git");
    NSArray *config = @[@"config", @"--global"];
    
    if ([git isEqualToString:@"/usr/bin/git"] && ![self xcodeCLTInstalled]) {
        git = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/MacOS/pkgx"];
        config = @[@"git", @"config", @"--global"];
    }
        
    if (sender.state == NSControlStateValueOn) {
        
        //FIXME if XDG_CONFIG_HOME set uses that which requires us to run a script in a login shell to extract
        id configfile = [NSHomeDirectory() stringByAppendingPathComponent:@".config/pkgx/bpb.toml"];
        
        if ([NSFileManager.defaultManager isReadableFileAtPath:configfile]) {
            run(git, [config arrayByAddingObjectsFromArray:@[@"commit.gpgsign", @"true"]], nil);
            run(git, [config arrayByAddingObjectsFromArray:@[@"gpg.program", @"bpb"]], nil);
            
            if (![NSFileManager.defaultManager isExecutableFileAtPath:@"/usr/local/bin/bpb"]) {
                [self installSubexecutable:@"bpb"];
            }
            
            [self calculateSecurityRating];
        }
        else [self.mainView.window beginSheet:self.gpgPassphraseWindow completionHandler:^(NSModalResponse returnCode) {
            if (returnCode != NSModalResponseOK) {
                [self.gpgSignSwitch setState:NSControlStateValueOff];
            } else {
                id username = self.setupGPGWindowUsername.stringValue;
                id email = self.setupGPGWindowEmail.stringValue;
                [self installBPB:username email:email];
                
                //TODO need to have a git installed first
                run(git, [config arrayByAddingObjectsFromArray:@[@"commit.gpgsign", @"true"]], nil);
                run(git, [config arrayByAddingObjectsFromArray:@[@"gpg.program", @"bpb"]], nil);
                [self calculateSecurityRating];
            }
        }];
    } else {
        run(git, [config arrayByAddingObjectsFromArray:@[@"commit.gpgsign", @"false"]], nil);
        [self calculateSecurityRating];
    }
}

- (void)installBPB:(id)username email:(id)email {
    if (![NSFileManager.defaultManager isExecutableFileAtPath:@"/usr/local/bin/bpb"]) {
        [self installSubexecutable:@"bpb"];
    }
    
    if (![NSFileManager.defaultManager isReadableFileAtPath:[NSHomeDirectory() stringByAppendingPathComponent:@".bpb_keys.toml"]]) {
        id initstr = [NSString stringWithFormat:@"%@ <%@>", username, email];
        run(@"/usr/local/bin/bpb", @[@"init", initstr], nil);
    }
}

- (IBAction)printGPGEmergencyKit:(id)sender {
    NSString *pubkey = output(@"/usr/local/bin/bpb", @[@"print"]);
    NSString *privkey = output(@"/usr/bin/security", @[@"find-generic-password", @"-s", @"xyz.tea.BASE.bpb", @"-w"]);
    
    id content = @"Public Key:\n\n";
    content = [content stringByAppendingString:pubkey];
    content = [content stringByAppendingString:@"\n\nPrivate Key:\n\n"];
    content = [content stringByAppendingString:privkey];

    // Create an NSTextView and set the document content
    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 612, 612)]; // Typical page size
    [textView setString:content];
    
    // Configure the print operation for the text view
    NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:textView];
    [printOperation setShowsPrintPanel:YES];
    [printOperation setShowsProgressPanel:YES];
    [printOperation setJobTitle:@"GPG_Emergency_Kit.pdf"];

    // Run the print operation (this will display the print dialog)
    [printOperation runOperationModalForWindow:[sender window] delegate:self didRunSelector:@selector(didPrintGPGEmergencyKit:success:) contextInfo:nil];
}

- (void)didPrintGPGEmergencyKit:(NSPrintOperation *)op success:(BOOL)success {
    if (success) {
        self.greenCheckGPGBackup.hidden = NO;
        [self.defaultsController.defaults setValue:@YES forKey:@"xyz.tea.BASE.printed-GPG-emergency-kit"];
        [self calculateSecurityRating];
    }
}

@end


@implementation teaBASE (Integration)

- (IBAction)integrateWithGitHub:(id)sender {
    //TODO not great since we don’t know when we’re finished
    //NOTE `gh` fails when uploading an existing GPG key (though is fine for existing ssh keys)
    //TODO ^^ report as bug?
    //TODO pipe output and handle it so exit code is good

    NSString *script_path = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/Scripts/github-integration.sh"];

    run(@"/usr/bin/open", @[
        @"-a", @"Terminal.app", script_path
    ], nil);
    
    self.greenCheckGitHubIntegration.hidden = NO;
    [self.defaultsController.defaults setValue:@YES forKey:@"xyz.tea.BASE.integrated-GitHub"];
    [self calculateSecurityRating];
}

@end


@implementation teaBASE (PMs)

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

- (IBAction)installBrewStep2:(NSButton *)sender {
    [sender setEnabled:NO];
    [self.brewInstallWindowSpinner startAnimation:sender];
    
    //TODO use API to determine latest release?
    id urlstr = @"https://github.com/Homebrew/brew/releases/download/4.4.9/Homebrew-4.4.9.pkg";
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



@implementation teaBASE (git)

- (IBAction)installGit:(NSButton *)sender {
    if (sender.selectedTag != 2) {
        run(@"/usr/bin/xcode-select", @[@"--install"], nil);
        // for weird reasons the install window does not come to the front on Somona
        run(@"/usr/bin/open", @[@"/System/Library/CoreServices/Install Command Line Developer Tools.app"], nil);
    } else {
        run(brewPath(), @[@"install", @"git"], nil);
    }
}

- (IBAction)editGitIdentity:(NSButton *)sender {
    [sender.window beginSheet:self.gitIdentityWindow completionHandler:^(NSModalResponse returnCode) {
        if (returnCode != NSModalResponseOK) return;
        
        id pkgx = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/MacOS/pkgx"];
        run(pkgx, @[@"git", @"config", @"--global", @"user.name", self.gitIdentityUsernameLabel.stringValue], nil);
        run(pkgx, @[@"git", @"config", @"--global", @"user.email", self.gitIdentityEmailLabel.stringValue], nil);
        
        self.gitIdentityLabel.stringValue = [NSString stringWithFormat:@"%@ <%@>", self.gitIdentityUsernameLabel.stringValue, self.gitIdentityEmailLabel.stringValue];
    }];
}

- (void)updateGitGudListing {
    NSString *pkgx = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/MacOS/pkgx"];
    
    //FIXME deno will cache this permanantly, we need to version it or pkg this properly
    id url = @"https://raw.githubusercontent.com/pkgxdev/git-gud/refs/heads/main/src/app.ts";

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSString *json = output(pkgx, @[
            @"+git",
            @"deno~2.0", @"run", @"--unstable-kv", @"-A", url, @"lsij"
        ]);
        
        if (!json) return;
        
        NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
        
        NSError *error;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [[NSAlert alertWithError:error] runModal];
            } else {
                self->gitGudInstalledListing = jsonObject;
                [self.gitExtensionsTable reloadData];
            }
        });
    });
}

- (IBAction)manageGitGud:(id)sender {
    if (!gitGudListing) {
        [self reloadGitGudListing:sender];
    }
    
    [self.mainView.window beginSheet:self.gitGudWindow completionHandler:^(NSModalResponse returnCode) {
        [self updateGitGudListing];
    }];
}

- (void)reloadGitGudListing:(id)sender{
    //TODO need to update this sometimes
    
    [self.gitGudWindowSpinner startAnimation:sender];
    
    NSString *pkgx = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/MacOS/pkgx"];
    id url = @"https://raw.githubusercontent.com/pkgxdev/git-gud/refs/heads/main/src/app.ts";
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        @try {
            NSString *json = output(pkgx, @[
                @"+git",
                @"deno~2.0", @"run", @"--unstable-kv", @"-Ar", url, @"lsj"
            ]);
            
            NSError *error;
            NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
            id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    [[NSAlert alertWithError:error] runModal];
                } else {
                    self->gitGudListing = jsonObject;
                    [self.gitGudTableView reloadData];
                    [self updateGitGudSelection];
                }
            });
        } @catch (id e) {
            //noop
        } @finally {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.gitGudWindowSpinner stopAnimation:sender];
            });
        }
    });
}

- (IBAction)vetGitGudPackage:(id)sender {
    NSInteger row = self.gitGudTableView.selectedRow;
    if (row < 0 || row >= gitGudListing.count) return;
    NSString *name = [gitGudListing[row] objectForKey:@"name"];
    if (!name) return;
    
    NSString *pkgx = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/MacOS/pkgx"];
    id url = @"https://raw.githubusercontent.com/pkgxdev/git-gud/refs/heads/main/src/app.ts";
    
    run(pkgx, @[
        @"+git",
        @"deno~2.0", @"run", @"--unstable-kv", @"-A", url, @"vet", name
    ], nil);
}

- (IBAction)installGitGudPackage:(id)sender {
    [self.gitGudWindowSpinner startAnimation:sender];
    
    NSInteger row = self.gitGudTableView.selectedRow;
    if (row < 0 || row >= gitGudListing.count) return;
    NSString *name = [gitGudListing[row] objectForKey:@"name"];
    if (!name) return;
    
    NSString *pkgx = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/MacOS/pkgx"];
    id url = @"https://raw.githubusercontent.com/pkgxdev/git-gud/refs/heads/main/src/app.ts";
    
    run(pkgx, @[
        @"+git",
        @"deno~2.0", @"run", @"--unstable-kv", @"-A", url, @"install", name
    ], nil);
    
    [self reloadGitGudListing:sender];
}

- (IBAction)uninstallGitGudPackage:(id)sender {
    [self.gitGudWindowSpinner startAnimation:sender];
    
    NSInteger row = self.gitGudTableView.selectedRow;
    if (row < 0 || row >= gitGudListing.count) return;
    NSString *name = [gitGudListing[row] objectForKey:@"name"];
    if (!name) return;
    
    NSString *pkgx = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/MacOS/pkgx"];
    id url = @"https://raw.githubusercontent.com/pkgxdev/git-gud/refs/heads/main/src/app.ts";
    
    run(pkgx, @[
        @"+git",
        @"deno~2.0", @"run", @"--unstable-kv", @"-A", url, @"uninstall", name
    ], nil);
    
    [self reloadGitGudListing:sender];
}

- (void)updateGitGudSelection {
    NSInteger row = [self.gitGudTableView selectedRow];
    if (row < 0 || row >= gitGudListing.count) {
        [self.gitGudInstallButton setEnabled:NO];
        [self.gitGudUninstallButton setEnabled:NO];
        [self.gitGudBVetButton setEnabled:NO];
    } else {
        BOOL installed = [gitGudListing[row] boolForKey:@"installed"];
        [self.gitGudInstallButton setEnabled:!installed];
        [self.gitGudUninstallButton setEnabled:installed];
        [self.gitGudBVetButton setEnabled:YES];
    }
}

@end



@implementation teaBASE (dotfileSync)

- (BOOL)dotfileSyncEnabled {
    return run(@"/bin/launchctl", @[@"list", @"xyz.tea.BASE.dotfile-sync"], nil);
}

- (BOOL)dotfileDirThere {
    BOOL isdir = NO;
    id path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/teaBASE/dotfiles.git"];
    if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isdir]) return NO;
    if (!isdir) return NO;
    return YES;
}

- (IBAction)onDotfileSyncToggled:(NSSwitch *)sender {
    
    id dst = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents/xyz.tea.BASE.dotfile-sync.plist"];
    
    if (sender.state == NSControlStateValueOn) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        id src = [bundle pathForResource:@"xyz.tea.BASE.dotfile-sync" ofType:@"plist"];
        NSString *contents = [NSString stringWithContentsOfFile:src encoding:NSUTF8StringEncoding error:nil];
        id prefpane_path = [bundle bundlePath];
        contents = [contents stringByReplacingOccurrencesOfString:@"$PREFPANE" withString:prefpane_path];
        contents = [contents stringByReplacingOccurrencesOfString:@"$HOME" withString:NSHomeDirectory()];
        [NSFileManager.defaultManager createDirectoryAtPath:[dst stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        [contents writeToFile:dst atomically:NO encoding:NSUTF8StringEncoding error:nil];
        run(@"/bin/launchctl", @[@"load", dst], nil);
        
        //TODO need to wait for the above launchctl job to finish lol
        
        NSLog(@"teaBASE: %@", self.dotfileDirThere ? @"YES" :@"NO");
        
        if (!self.dotfileDirThere) {
            NSString *script_path = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/Scripts/dotfile-sync.sh"];

            run(@"/usr/bin/open", @[
                @"-a", @"Terminal.app", script_path
            ], nil);
        }
        
    } else {
        run(@"/bin/launchctl", @[@"unload", dst], nil);
        [[NSFileManager defaultManager] removeItemAtPath:dst error:nil];
    }
    
    //FIXME need to know when the below script finishes before loading us into launchctl
    
    BOOL worked = [self dotfileSyncEnabled];
    
    [self.dotfileSyncEditWhitelistButton setEnabled:worked];
    [self.dotfileSyncViewRepoButton setEnabled:worked];
    [self.dotfileSyncSwitch setState:worked ? NSControlStateValueOn : NSControlStateValueOff];
}

- (IBAction)viewDotfilesRepo:(id)sender {
    //TODO use the origin remote URL to figure this out instead
    id pkgx = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/MacOS/pkgx"];
    run(pkgx, @[@"gh", @"repo", @"view", @"--web", @"dotfiles"], nil);
}

- (IBAction)editWhitelist:(id)sender {
    id url = @"https://github.com/teaxyz/teaBASE/blob/main/Scripts/dotfile-sync.sh";
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

@end



@implementation teaBASE (NSTableViewDataSource)

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.gitExtensionsTable) {
        return gitGudInstalledListing.count;
    } else {
        return gitGudListing.count;
    }
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView == self.gitExtensionsTable) {
        if ([tableColumn.identifier isEqualToString:@"name"]) {
            return [gitGudInstalledListing[row] objectForKey:@"name"];
        } else if ([tableColumn.identifier isEqualToString:@"type"]) {
            return [gitGudInstalledListing[row] objectForKey:@"description"];
        }
    } else {
        if ([tableColumn.identifier isEqualToString:@"name"]) {
            return [gitGudListing[row] objectForKey:@"name"];
        } else if ([tableColumn.identifier isEqualToString:@"description"]) {
            return [gitGudListing[row] objectForKey:@"description"];
        } else if ([tableColumn.identifier isEqualToString:@"installed"]) {
            return [[gitGudListing[row] objectForKey:@"installed"] boolValue] ? @"✓" : @"";
        }
    }
    return @"";
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    return 20;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if (notification.object == self.gitGudTableView) {
        [self updateGitGudSelection];
    }
}

@end


@implementation teaBASE (Helpers)

- (void)installSubexecutable:(NSString *)name {
    NSString *src = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"Contents/MacOS/%@", name]];
    NSString *script = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/Scripts/usr-local-install.sh"];
            
    char *arguments[] = {(char *)src.fileSystemRepresentation, NULL};

    // we cannot use bash
    sudo_run_cmd((char *)script.fileSystemRepresentation, arguments, [NSString stringWithFormat:@"`%@` install failed", name]);
}

@end
