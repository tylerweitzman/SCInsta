#import "../../InstagramHeaders.h"

// Hide the notes tray row at the top of the DM inbox.
// Demangled names: IGDirectInboxListAdapterDataSource.IGDirectInboxListAdapterDataSource
//                  IGDirectNotesViewModelsSwift.IGDirectNotesTrayRowViewModel
%hook _TtC34IGDirectInboxListAdapterDataSource34IGDirectInboxListAdapterDataSource
- (id)objectsForListAdapter:(id)arg1 {
    NSArray *orig = %orig;
    Class notesRow = objc_getClass("_TtC28IGDirectNotesViewModelsSwift29IGDirectNotesTrayRowViewModel");
    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:orig.count];

    static BOOL didLogClasses = NO;
    if (!didLogClasses) {
        didLogClasses = YES;
        NSLog(@"[SCInsta] inbox list objects: %@", [orig valueForKey:@"class"]);
    }

    for (id obj in orig) {
        if (notesRow && [obj isKindOfClass:notesRow]) {
            NSLog(@"[SCInsta] Hiding notes tray");
            continue;
        }
        [filtered addObject:obj];
    }

    return [filtered copy];
}
%end
