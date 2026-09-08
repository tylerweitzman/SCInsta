#import "../../InstagramHeaders.h"
#import "../../Manager.h"

// "Welcome to instagram" suggested users in feed
%hook IGSuggestedUnitViewModel
- (id)initWithAYMFModel:(id)arg1 headerViewModel:(id)arg2 {
    if ([SCIManager getPref:@"no_suggested_users"]) {
        NSLog(@"[SCInsta] Hiding suggested users: main feed welcome section");

        return nil;
    }

    return %orig;
}
%end
%hook IGSuggestionsUnitViewModel
- (id)initWithAYMFModel:(id)arg1 headerViewModel:(id)arg2 {
    if (true) {
        NSLog(@"[SCInsta] Hiding suggested users: main feed welcome section");

        return nil;
    }

    return %orig;
} 
%end
// Suggested users carousel in profile header
// IG 445+: Swift class. Demangled name: IGProfileHeader.IGProfileHeaderView
%hook _TtC15IGProfileHeader19IGProfileHeaderView
- (id)objectsForListAdapter:(id)arg1 {
    NSArray *orig = %orig;
    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:orig.count];

    for (id obj in orig) {
        if ([obj isKindOfClass:%c(IGProfileChainingModel)]) {
            NSLog(@"[SCInsta] Hiding suggested users: profile header");
            continue;
        }
        [filtered addObject:obj];
    }

    return [filtered copy];
}
%end

// "Discover people" action button in profile action bar (action id 3)
%hook IGProfileActionBarViewModel
- (id)initWithIdentifier:(id)arg1 rows:(id)rows allActionsToDisplay:(id)allActions overflowActions:(id)overflowActions actionToBadgeInfoMap:(id)arg5 allBusinessActions:(id)arg6 overflowBusinessActions:(id)arg7 contactSheetActions:(id)arg8 user:(id)arg9 sponsoredInfoProvider:(id)arg10 profileBackgroundColor:(id)arg11 buttonSwapVariant:(long long)arg12 {
    NSPredicate *notDiscover = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", @[ @(3) ]];

    NSOrderedSet *all = [[allActions copy] filteredOrderedSetUsingPredicate:notDiscover];
    NSOrderedSet *overflow = [[overflowActions copy] filteredOrderedSetUsingPredicate:notDiscover];
    NSMutableArray *filteredRows = [NSMutableArray new];
    for (NSOrderedSet *set in rows) {
        [filteredRows addObject:[set filteredOrderedSetUsingPredicate:notDiscover]];
    }

    return %orig(arg1, [filteredRows copy], all, overflow, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12);
}
%end
