#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// Demangled name: Hinge.AppDelegate
@interface _TtC5Hinge11AppDelegate : UIResponder <UIApplicationDelegate>
@end

@interface FLEXManager : NSObject
+ (instancetype)sharedManager;
- (void)showExplorer;
- (void)hideExplorer;
- (void)toggleExplorer;
@end
