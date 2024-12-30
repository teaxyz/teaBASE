#import "teaBASE.h"

@implementation teaBASE (SelfUpdate)

- (void)checkForUpdates {
    id current_version = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    current_version = [@"v" stringByAppendingString:current_version ?: @"0.0.0"];
    
    id url = @"https://api.github.com/repos/teaxyz/teaBASE/releases/latest";
    url = [NSURL URLWithString:url];

    NSMutableURLRequest *rq = [NSMutableURLRequest requestWithURL:url];
    [rq setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:rq completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) return NSLog(@"teaBASE: fetch error: %@", error.localizedDescription);
        if (!data) return NSLog(@"teaBASE: no data from: %@", url);
        
        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) return NSLog(@"Error parsing JSON: %@", jsonError.localizedDescription);
        
        NSString *latest_version = json[@"tag_name"];
        
        if (!semver_is_greater(latest_version, current_version)) return;
        
        id fmt = [NSString stringWithFormat:@"-%@.dmg", [latest_version substringFromIndex:1]];
        for (NSDictionary *asset in json[@"assets"]) {
            if ([asset[@"name"] hasSuffix:fmt]) {
                return dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    download(asset[@"browser_download_url"], self);
                });
            }
        }
    }];
    [task resume];
}

void download(id url, teaBASE *self) {
#if DEBUG
    NSLog(@"teaBASE: would update to: %@", url);
#else
    NSLog(@"teaBASE: updating to: %@", url);
    
    id bundle_path = [[NSBundle bundleForClass:[self class]] bundlePath];
    id script_path = [bundle_path stringByAppendingPathComponent:@"Contents/Scripts/self-update.sh"];

    run(script_path, @[url, bundle_path], nil);
#endif
}

// naive compare that ignores pre-release ids etc.
BOOL semver_is_greater(NSString *version1, NSString *version2) {
    // Remove leading 'v' if present
    if ([version1 hasPrefix:@"v"]) {
        version1 = [version1 substringFromIndex:1];
    }
    if ([version2 hasPrefix:@"v"]) {
        version2 = [version2 substringFromIndex:1];
    }
    
    NSArray<NSString *> *components1 = [version1 componentsSeparatedByString:@"."];
    NSArray<NSString *> *components2 = [version2 componentsSeparatedByString:@"."];

    NSInteger maxLength = MAX(components1.count, components2.count);

    for (NSInteger i = 0; i < maxLength; i++) {
        NSInteger value1 = i < components1.count ? [components1[i] integerValue] : 0;
        NSInteger value2 = i < components2.count ? [components2[i] integerValue] : 0;

        if (value1 > value2) {
            return YES;
        } else if (value1 < value2) {
            return NO;
        }
    }

    return NO;
}

@end
