#import <UIKit/UIKit.h>

// Floating on-screen UI injected into the host app: a draggable "W" button
// that opens a Lua code editor for run / save & run.
@interface LuaOverlay : NSObject
+ (void)present;
@end
