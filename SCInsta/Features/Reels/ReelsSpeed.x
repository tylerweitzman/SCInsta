#import "../../InstagramHeaders.h"

// Force 2x reels playback. Any speed IG sets (including reset to 1x) becomes 2x.
static const float kReelsSpeed = 2.0f;

%hook IGSundialViewerVideoCell
- (void)setPlaybackSpeed:(float)speed {
    %orig(kReelsSpeed);
}
- (void)sundialVideoPlaybackViewDidStartPlaying:(id)arg1 {
    %orig;
    [self setPlaybackSpeed:kReelsSpeed];
}
%end
