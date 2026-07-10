#import "LuaEngine.h"
#import "fishhook.h"
#import <dlfcn.h>

// We deliberately do NOT include lua.h or link our own Lua. We talk to the
// game's Lua/Luau by function pointers resolved from the game's own binary.
typedef struct lua_State lua_State;

#pragma mark - Captured game state

// The first Lua state the game creates. Captured by hooking lua_newstate.
static lua_State *gGameL = NULL;

// Original lua_newstate, so our hook can call through to it.
typedef lua_State *(*newstate_t)(void *alloc, void *ud);
static newstate_t orig_lua_newstate = NULL;

static lua_State *my_lua_newstate(void *alloc, void *ud) {
    lua_State *L = orig_lua_newstate ? orig_lua_newstate(alloc, ud) : NULL;
    if (L && !gGameL) {
        gGameL = L;
        NSLog(@"[LuaInject] captured game lua_State %p", (void *)L);
    }
    return L;
}

// Install the hook as early as possible (before the game boots its VM).
__attribute__((constructor))
static void InstallLuaHook(void) {
    struct rebinding r = { "lua_newstate",
                           (void *)my_lua_newstate,
                           (void **)&orig_lua_newstate };
    rebind_symbols(&r, 1);
    NSLog(@"[LuaInject] lua_newstate hook installed");
}

#pragma mark - Resolved game Lua functions

// Lua 5.x path
typedef int   (*loadstring_t)(lua_State *, const char *);
typedef int   (*pcallk_t)(lua_State *, int, int, int, long, void *);
typedef const char *(*tolstring_t)(lua_State *, int, size_t *);
typedef void  (*settop_t)(lua_State *, int);

// Luau path (compile source -> bytecode -> load)
typedef char *(*luau_compile_t)(const char *, size_t, void *, size_t *);
typedef int   (*luau_load_t)(lua_State *, const char *, const char *, size_t, int);

static loadstring_t   fn_loadstring  = NULL;
static pcallk_t       fn_pcallk      = NULL;
static tolstring_t    fn_tolstring   = NULL;
static settop_t       fn_settop      = NULL;
static luau_compile_t fn_luau_compile = NULL;
static luau_load_t    fn_luau_load    = NULL;
static BOOL           gResolved       = NO;

static void *Sym(const char *name) { return dlsym(RTLD_DEFAULT, name); }

static void ResolveOnce(void) {
    if (gResolved) return;
    gResolved = YES;
    fn_tolstring    = (tolstring_t)Sym("lua_tolstring");
    fn_settop       = (settop_t)Sym("lua_settop");
    fn_pcallk       = (pcallk_t)Sym("lua_pcallk");   // 5.4
    if (!fn_pcallk) fn_pcallk = (pcallk_t)Sym("lua_pcall"); // luau/5.1 shape differs; see below
    fn_loadstring   = (loadstring_t)Sym("luaL_loadstring");
    fn_luau_compile = (luau_compile_t)Sym("luau_compile");
    fn_luau_load    = (luau_load_t)Sym("luau_load");
}

@implementation LuaEngine

+ (instancetype)shared {
    static LuaEngine *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [LuaEngine new]; });
    return s;
}

- (BOOL)ready {
    ResolveOnce();
    return gGameL != NULL && (fn_luau_load || fn_loadstring);
}

- (NSString *)popError:(lua_State *)L {
    if (fn_tolstring) {
        const char *e = fn_tolstring(L, -1, NULL);
        NSString *err = @(e ?: "unknown error");
        if (fn_settop) fn_settop(L, -2); // pop the error
        return err;
    }
    return @"error (couldn't read message)";
}

- (NSString *)run:(NSString *)source {
    if (source.length == 0) return @"empty script";
    ResolveOnce();
    if (!gGameL) return @"game VM not captured yet — start the game / open a level first";

    lua_State *L = gGameL;
    const char *src = source.UTF8String;

    // Prefer the Luau path if the game is Luau; else fall back to Lua 5.x.
    int loadStatus;
    if (fn_luau_compile && fn_luau_load) {
        size_t blen = 0;
        char *bytecode = fn_luau_compile(src, strlen(src), NULL, &blen);
        if (!bytecode || blen == 0) return @"luau_compile failed (syntax error?)";
        loadStatus = fn_luau_load(L, "=Xsign", bytecode, blen, 0);
        free(bytecode);
    } else if (fn_loadstring) {
        loadStatus = fn_loadstring(L, src);
    } else {
        return @"couldn't find the game's Lua loader — its symbols aren't exported";
    }

    if (loadStatus != 0) return [self popError:L];

    if (!fn_pcallk) return @"loaded, but couldn't find lua_pcall to run it";
    // lua_pcallk(L, nargs=0, nresults=0, errfunc=0, ctx=0, k=NULL)
    int callStatus = fn_pcallk(L, 0, 0, 0, 0, NULL);
    if (callStatus != 0) return [self popError:L];
    return nil;
}

@end
