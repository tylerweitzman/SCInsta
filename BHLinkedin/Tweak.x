#import "Headers.h"

%hook UIView
- (void)layoutSubviews {
    %orig;
    if ([[[self class] description]containsString:@"Feed"]) {
        [self removeFromSuperview];
    }
}
%end