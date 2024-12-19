#import "teaBASE.h"

@implementation teaBASE (CleanInstall)

- (IBAction)generateCleanInstallPack:(id)sender {
    NSString *script_path = [[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingPathComponent:@"Contents/Scripts/make-clean-install-pack.command"];

    run(@"/usr/bin/open", @[script_path], nil);    
}

- (IBAction)openCleanInstallGuide:(id)sender {
    id url = @"https://github.com/teaxyz/teaBASE/blob/main/Docs/clean-install-guide.md";
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}

@end
