TARGET := iphone:clang:14.5:13.0
# arm64 only: the open-source Linux toolchain's arm64e ABI doesn't match
# Apple's, so an arm64e slice can fail to load. arm64 runs everywhere.
ARCHS  := arm64

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = LuaInject

# Injection glue + UI + fishhook (for capturing the host game's Lua state).
# We do NOT bundle our own Lua: we run inside the game's existing Luau VM,
# so bundling Lua would only cause symbol clashes.
LuaInject_FILES = $(wildcard src/*.m) $(wildcard vendor/fishhook/*.c)
LuaInject_CFLAGS = -fobjc-arc -Ivendor/fishhook
LuaInject_FRAMEWORKS = Foundation UIKit
LuaInject_INSTALL_PATH = /usr/lib

include $(THEOS_MAKE_PATH)/library.mk

# Fetch fishhook source if not present
before-all::
	@bash scripts/fetch-fishhook.sh
