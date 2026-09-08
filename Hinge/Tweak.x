#import "Headers.h"

%hook _TtC5Hinge11AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)options {
    BOOL result = %orig;
    NSLog(@"[Hinge] tweak loaded");
    [[%c(FLEXManager) sharedManager] showExplorer];
    return result;
}
- (void)applicationWillResignActive:(id)application {
    %orig;
    [[%c(FLEXManager) sharedManager] showExplorer];
}
%end

// Hinge ships a debug "App version override" read from this defaults key.
// Set it so the min-version check and X-App-Version header see a current version.
%ctor {
    [[NSUserDefaults standardUserDefaults] setObject:@"10.0.0" forKey:@"co.hinge.app_version_override"];
    NSLog(@"[Hinge] bundle version=%@ override=%@",
          [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
          [[NSUserDefaults standardUserDefaults] objectForKey:@"co.hinge.app_version_override"]);
}
