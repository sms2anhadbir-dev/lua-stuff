#import <Foundation/Foundation.h>

// Runs Lua/Luau source inside the HOST GAME's existing VM, so the game's
// own globals (Instance, game, UDim2, ...) are in scope. It does not create
// its own Lua state — it captures the game's.
@interface LuaEngine : NSObject

+ (instancetype)shared;

// YES once we've captured the game's Lua state and found its loader.
@property (nonatomic, readonly) BOOL ready;

// Run a chunk in the game's VM. Returns nil on success, or an error string
// (including "game VM not captured yet" if the game hasn't started Lua).
- (NSString *)run:(NSString *)source;

@end
