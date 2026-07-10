#import <UIKit/UIKit.h>
#import "LuaOverlay.h"

// Wait for the host app to have an active UI scene, then show the W overlay.
static void TryPresent(int attempt) {
    BOOL ready = NO;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if (s.activationState == UISceneActivationStateForegroundActive) {
            ready = YES;
            break;
        }
    }
    if (ready) {
        [LuaOverlay present];
        return;
    }
    if (attempt > 60) return; // give up after ~30s
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC),
        dispatch_get_main_queue(), ^{ TryPresent(attempt + 1); });
}

__attribute__((constructor))
static void LuaInjectInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool { TryPresent(0); }
    });
}
