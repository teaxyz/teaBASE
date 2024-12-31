#import "teaBASE.h"

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
        id src = [bundle pathForResource:@"dotfile-sync-launchd" ofType:@"plist"];
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
            run_in_terminal(script_path, [NSBundle bundleForClass:self.class]);
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

