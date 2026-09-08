#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface FeedViewController : UICollectionViewController
@property(nonatomic, retain) UIView *view;
@property(nonatomic, retain) UICollectionView *collectionView;
@end

@interface JobsDetailViewController : UIViewController
@property(nonatomic, retain) UIView *view;
@end

@interface FLEXManager : NSObject
+ (instancetype)sharedManager;
- (void)showExplorer;
- (void)hideExplorer;
- (void)toggleExplorer;
@end

static BOOL is_iPad() {
    if ([(NSString *)[UIDevice currentDevice].model hasPrefix:@"iPad"]) {
        return YES;
    }
    return NO;
}
