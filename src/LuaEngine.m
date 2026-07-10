#import "LuaEngine.h"
#import "lua.h"
#import "lualib.h"
#import "lauxlib.h"

// Replacement for Lua's default print: routes output to the device log so
// scripts can just call print(...) with no special API.
static int l_print(lua_State *L) {
    int n = lua_gettop(L);
    NSMutableString *out = [NSMutableString string];
    for (int i = 1; i <= n; i++) {
        size_t len = 0;
        const char *s = luaL_tolstring(L, i, &len);   // like tostring()
        if (i > 1) [out appendString:@"\t"];
        [out appendString:[NSString stringWithUTF8String:s ?: ""]];
        lua_pop(L, 1);   // pop the string luaL_tolstring pushed
    }
    NSLog(@"[Lua] %@", out);
    return 0;
}

@implementation LuaEngine {
    lua_State *_L;
}

+ (instancetype)shared {
    static LuaEngine *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [LuaEngine new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _L = luaL_newstate();
        luaL_openlibs(_L);                 // full standard library
        lua_pushcfunction(_L, l_print);    // override print -> device log
        lua_setglobal(_L, "print");
    }
    return self;
}

- (NSString *)run:(NSString *)source {
    if (source.length == 0) return @"empty script";
    @synchronized (self) {
        if (luaL_loadstring(_L, source.UTF8String) != LUA_OK ||
            lua_pcall(_L, 0, 0, 0) != LUA_OK) {
            NSString *err = @(lua_tostring(_L, -1) ?: "unknown error");
            lua_pop(_L, 1);
            return err;
        }
    }
    return nil;
}

@end
