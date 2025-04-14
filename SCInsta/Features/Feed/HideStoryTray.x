#import "../../InstagramHeaders.h"
#import "../../Manager.h"

// Disable story data source
%hook IGMainStoryTrayDataSource
- (id)initWithUserSession:(id)arg1 {
    if (true) {
        NSLog(@"[SCInsta] Hiding story tray");

        return nil;
    }
    
    return %orig;
}
%end