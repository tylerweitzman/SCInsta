#import "../../InstagramHeaders.h"
#import "../../Utils.h"

// Ported from upstream SCInsta Navigation.xm. Removes the CLIPS (reels) surface
// from both the tab bar and the swipeable surface collection.
static BOOL isSurfaceShown(IGMainAppSurfaceIntent *surface) {
    NSString *tab = [surface respondsToSelector:@selector(tabStringFromSurfaceIntent)] ? [surface tabStringFromSurfaceIntent] : nil;
    NSLog(@"[SCInsta] tab surface: %@ subtype=%@", tab, [surface valueForKey:@"_subtype"]);

    return ![tab isEqualToString:@"CLIPS"];
}

static NSArray *filterSurfacesArray(NSArray *surfaces) {
    NSMutableArray *filtered = [NSMutableArray array];

    for (IGMainAppSurfaceIntent *surface in surfaces) {
        if (![surface isKindOfClass:%c(IGMainAppSurfaceIntent)]) break;
        if (isSurfaceShown(surface)) [filtered addObject:surface];
    }

    return filtered;
}

%hook IGTabBarControllerSwipeCoordinator
- (id)initWithSurfaces:(id)surfaces parentViewController:(id)controller enableHaptics:(BOOL)haptics launcherSet:(id)set {
    return %orig(filterSurfacesArray(surfaces), controller, haptics, set);
}
%end

%hook IGTabBarController
- (void)_layoutTabBar {
    NSArray *surfaces = [SCIUtils getIvarForObj:self name:"_tabBarSurfaces"];
    [SCIUtils setIvarForObj:self name:"_tabBarSurfaces" value:filterSurfacesArray(surfaces)];

    %orig;
}

- (id)_buttonForTabBarSurface:(id)surface {
    id button = %orig(surface);

    if (!isSurfaceShown(surface)) {
        NSLog(@"[SCInsta] Hiding reels tab");
        return nil;
    }

    return button;
}
%end
