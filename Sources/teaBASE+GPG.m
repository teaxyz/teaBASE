#import "teaBASE.h"

@implementation teaBASE (GPG)

- (BOOL)gpgSignEnabled {
    id pkgx = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/MacOS/pkgx"];
    return [output(pkgx, @[@"git", @"config", @"--global", @"commit.gpgsign"]) isEqualToString:@"true"];
}

- (NSString *)bpbConfigPath {
    //FIXME if XDG_* vars set uses that which requires us to run a script in a login shell to extract
    id configfile = [NSHomeDirectory() stringByAppendingPathComponent:@".config/pkgx/bpb.toml"];
    if (![NSFileManager.defaultManager isReadableFileAtPath:configfile]) {
        configfile = [NSHomeDirectory() stringByAppendingPathComponent:@".local/share/pkgx/bpb.toml"];
    }
    return configfile;
}

- (IBAction)signCommits:(NSSwitch *)sender {
    NSString *git = which(@"git");
    NSArray *config = @[@"config", @"--global"];
    
    if ([git isEqualToString:@"/usr/bin/git"] && ![self xcodeCLTInstalled]) {
        git = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/MacOS/pkgx"];
        config = @[@"git", @"config", @"--global"];
    }
        
    if (sender.state == NSControlStateValueOn) {
        
        
        id configfile = [self bpbConfigPath];
        
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
    
    if (![NSFileManager.defaultManager isReadableFileAtPath:[self bpbConfigPath]]) {
        id initstr = [NSString stringWithFormat:@"%@ <%@>", username, email];
        run(@"/usr/local/bin/bpb", @[@"init", initstr], nil);
    }
}

- (IBAction)printGPGEmergencyKit:(id)sender {
    NSString *pubkey = output(@"/usr/local/bin/bpb", @[@"print"]);
    NSString *privkey = output(@"/usr/bin/security", @[@"find-generic-password", @"-s", @"xyz.tea.BASE.bpb", @"-w"]);
    
    if (!pubkey || !privkey) {
        NSAlert *alert = [NSAlert new];
        alert.informativeText = @"An error occurred trying to obtain your GPG keypair";
        [alert runModal];
        return;
    }
    
    id content = @"Public Key:\n\n";
    content = [content stringByAppendingString:pubkey];
    content = [content stringByAppendingString:@"\n\nPrivate Key:\n\n"];
    content = [content stringByAppendingString:privkey];

    // Create an NSTextView and set the document content
    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 612, 612)]; // Typical page size
    [textView setString:content];
    
    // Set font to Menlo (monospace) and make it smaller in order to fit the page
    NSFont *monoFont = [NSFont fontWithName:@"Menlo" size:9.6];
    [textView setFont:monoFont];
    [[textView textStorage] setFont:monoFont]; // Ensure the entire text storage uses the font
    
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
