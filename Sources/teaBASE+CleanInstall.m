#import "teaBASE.h"

@implementation teaBASE (CleanInstall)

- (IBAction)generateCleanInstallPack:(id)sender {
    if (![self pkgxInstalled]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"pkgx Required";
        alert.informativeText = @"pkgx is required to generate a clean install pack. Would you like to install it now?";
        [alert addButtonWithTitle:@"Install"];
        [alert addButtonWithTitle:@"Cancel"];
        
        NSModalResponse response = [alert runModal];
        if (response == NSAlertFirstButtonReturn) {
            [self installSubexecutable:@"pkgx"];
            [self updateVersions];

            // Update switch state based on actual installation status
            [self.pkgxSwitch setEnabled:YES];
            [self.pkgxSwitch setState:[self pkgxInstalled] ? NSControlStateValueOn : NSControlStateValueOff];

            // After installation, proceed with generating the pack
            [self generateCleanInstallPack:sender];
        }
        return;
    }
    
    NSString *script_path = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/Scripts/make-clean-install-pack.command"];
    run(@"/usr/bin/open", @[script_path], nil);    
}

- (IBAction)openCleanInstallGuide:(id)sender {
    id url = @"https://github.com/teaxyz/teaBASE/blob/main/Docs/clean-install-guide.md";
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

@end
