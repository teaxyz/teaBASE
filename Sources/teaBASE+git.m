#import "teaBASE.h"

@implementation teaBASE (git)

- (IBAction)installGit:(NSButton *)sender {
    if (sender.selectedTag != 2) {
        run(@"/usr/bin/xcode-select", @[@"--install"], nil);
        // for weird reasons the install window does not come to the front on Sonoma
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

- (void)updateGitIdentity {
    id pkgx = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/MacOS/pkgx"];
    id user = output(pkgx, @[@"git", @"config", @"--global", @"user.name"]);
    id mail = output(pkgx, @[@"git", @"config", @"--global", @"user.email"]);
    if (user && mail) {
        self.gitIdentityLabel.stringValue = [NSString stringWithFormat:@"%@ <%@>", user, mail];
        self.gitIdentityUsernameLabel.stringValue = user;
        self.gitIdentityEmailLabel.stringValue = mail;
    }
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
