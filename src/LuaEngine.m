#import "LuaEngine.h"
#import "lua.h"
#import "lualib.h"
#import "lauxlib.h"

static int l_log(lua_State *L) {
    const char *msg = luaL_checkstring(L, 1);
    NSLog(@"[LuaInject] %s", msg);
    return 0;
}

static int l_bundleid(lua_State *L) {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    lua_pushstring(L, bid.UTF8String);
    return 1;
}

static const luaL_Reg kInjectLib[] = {
    {"log",      l_log},
    {"bundleid", l_bundleid},
    {NULL, NULL},
};

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
        luaL_openlibs(_L);
        luaL_newlib(_L, kInjectLib);
        lua_setglobal(_L, "inject");
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
