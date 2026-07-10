#import <Foundation/Foundation.h>

// Thin wrapper around a persistent Lua state living inside the host process.
@interface LuaEngine : NSObject

+ (instancetype)shared;

// Run a chunk of Lua source. Returns nil on success, or an error string.
- (NSString *)run:(NSString *)source;

@end
