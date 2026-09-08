#import <UIKit/UIKit.h>

// Version-independent "update required" suppression.
//
// The prompt is Hinge.AlertViewController (a pure-Swift onboarding interstitial)
// shown when the server's config min_app_version exceeds the app's version. The
// decision logic is Swift with no hookable selector, and stamping the bundle
// version only lasts until the server minimum passes it. So instead we detect the
// alert by its own copy at display time and dismiss it. This keeps working no
// matter how high Hinge raises the server minimum.
//
// Demangled name: Hinge.AlertViewController
@interface _TtC5Hinge19AlertViewController : UIViewController
@end

static BOOL viewContainsText(UIView *view, NSString *needle) {
    if ([view isKindOfClass:[UILabel class]]) {
        NSString *t = ((UILabel *)view).text;
        if (t && [t rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    for (UIView *sub in view.subviews) {
        if (viewContainsText(sub, needle)) return YES;
    }
    return NO;
}

%hook _TtC5Hinge19AlertViewController
- (void)viewDidLoad {
    %orig;

    // Labels are populated during viewDidLoad; scan on the next runloop tick.
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        if (viewContainsText(self.view, @"no longer supported")) {
            NSLog(@"[Hinge] Skipping 'update required' alert");
            [self dismissViewControllerAnimated:NO completion:nil];
        }
    });
}
%end
