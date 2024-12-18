#import "teaBASE.h"

@implementation teaBASE

- (void)mainViewDidLoad {
    for (NSTableColumn *col in self.gitExtensionsTable.tableColumns) {
        col.headerCell.attributedStringValue = [[NSAttributedString alloc] initWithString:col.title attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:10]}];
    }
}

- (void)willSelect {
    // Initially disable all interactive elements
    [self.gpgSignSwitch setEnabled:NO];
    [self.homebrewSwitch setEnabled:NO];
    [self.pkgxSwitch setEnabled:NO];
    [self.xcodeCLTSwitch setEnabled:NO];
    [self.dockerSwitch setEnabled:NO];
    [self.dotfileSyncSwitch setEnabled:NO];
    [self.dotfileSyncEditWhitelistButton setEnabled:NO];
    [self.dotfileSyncViewRepoButton setEnabled:NO];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    // Create containers for async results
    __block BOOL hasSignedCommits = NO;
    __block BOOL homebrewInstalled = NO;
    __block BOOL pkgxInstalled = NO;
    __block BOOL xcodeCLTInstalled = NO;
    __block BOOL dotfileSyncEnabled = NO;
    
    // Perform heavy operations in background
    dispatch_group_async(group, backgroundQueue, ^{
        [self updateSSHStates];
    });
    
    dispatch_group_async(group, backgroundQueue, ^{
        hasSignedCommits = [self gpgSignEnabled];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.gpgSignSwitch setState:hasSignedCommits ? NSControlStateValueOn : NSControlStateValueOff];
            [self.gpgSignSwitch setEnabled:YES];
        });
    });
    
    dispatch_group_async(group, backgroundQueue, ^{
        [self updateVersions];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.dockerSwitch setState:self.dockerVersion.stringValue.length > 0 ? NSControlStateValueOn : NSControlStateValueOff];
            [self.dockerSwitch setEnabled:YES];
        });
    });
    
    dispatch_group_async(group, backgroundQueue, ^{
        homebrewInstalled = [self homebrewInstalled];
        pkgxInstalled = [self pkgxInstalled];
        xcodeCLTInstalled = [self xcodeCLTInstalled];
        dotfileSyncEnabled = self.dotfileSyncEnabled;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.homebrewSwitch setState:homebrewInstalled ? NSControlStateValueOn : NSControlStateValueOff];
            [self.pkgxSwitch setState:pkgxInstalled ? NSControlStateValueOn : NSControlStateValueOff];
            [self.xcodeCLTSwitch setState:xcodeCLTInstalled ? NSControlStateValueOn : NSControlStateValueOff];
            [self.dotfileSyncSwitch setState:dotfileSyncEnabled ? NSControlStateValueOn : NSControlStateValueOff];
            
            [self.homebrewSwitch setEnabled:YES];
            [self.pkgxSwitch setEnabled:YES];
            [self.xcodeCLTSwitch setEnabled:YES];
            [self.dotfileSyncSwitch setEnabled:YES];
            
            BOOL dotfileSyncActive = self.dotfileSyncSwitch.state == NSControlStateValueOn;
            [self.dotfileSyncEditWhitelistButton setEnabled:dotfileSyncActive];
            [self.dotfileSyncViewRepoButton setEnabled:dotfileSyncActive];
        });
    });
    
    // Once all background tasks complete, update remaining UI elements
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
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
    });
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

- (void)updateVersions {
    NSString *brew_out = output(brewPath(), @[@"--version"]);
    NSString *pkgx_out = output(@"/usr/local/bin/pkgx", @[@"--version"]);
    NSString *xcode_clt_out = output(@"/usr/sbin/pkgutil", @[@"--pkg-info=com.apple.pkg.CLTools_Executables"]);
    
    id path = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/Scripts/docker-version.sh"];

    NSString *docker_version = output(path, @[]);
    
    BOOL has_clt = [self xcodeCLTInstalled];
    BOOL has_xcode = [self xcodeInstalled];
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

- (IBAction)openGitHub:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://github.com/teaxyz/teaBASE"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)onShareClicked:(id)sender {
    const int starCount = self.ratingIndicator.intValue;

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
