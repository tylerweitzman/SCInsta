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
// IG 445+: class moved to Swift. Demangled name: IGMainStoryTrayDataSource.IGMainStoryTrayDataSource
%hook _TtC25IGMainStoryTrayDataSource25IGMainStoryTrayDataSource
- (id)initWithUserSession:(id)arg1 {
    NSLog(@"[SCInsta] Hiding story tray (swift data source)");
    return nil;
}
%end
