#import <UIKit/UIKit.h>

@interface _TtC29IGCoreRootTestFlightNagPlugin35TestFlightUpdateNudgeViewController : UIViewController
@end

// "It's time to update Instagram Beta" is IGCoreRootTestFlightNagPlugin.TestFlightUpdateNudgeViewController.
static BOOL isUpdateNudge(UIViewController *vc) {
    if ([vc isKindOfClass:[UINavigationController class]]) vc = ((UINavigationController *)vc).topViewController;
    return [NSStringFromClass([vc class]) containsString:@"TestFlightUpdateNudge"];
}

%hook UIViewController
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void (^)(void))completion {
    NSLog(@"[SCInsta] present: %@", NSStringFromClass([vc class]));

    if (isUpdateNudge(vc)) {
        NSLog(@"[SCInsta] Skipping TestFlight update nudge");
        if (completion) completion();
        return;
    }

    %orig;
}
%end

// Fallback if it gets shown some other way (pushed, embedded, etc.)
%hook _TtC29IGCoreRootTestFlightNagPlugin35TestFlightUpdateNudgeViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSLog(@"[SCInsta] Dismissing TestFlight update nudge");
    if (self.navigationController && self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:NO];
    } else {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
}
%end
