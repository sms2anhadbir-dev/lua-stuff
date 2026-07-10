TARGET := iphone:clang:14.5:13.0
ARCHS  := arm64 arm64e

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = LuaInject

# Our injection glue + the vendored Lua interpreter sources
LuaInject_FILES = $(wildcard src/*.m) $(wildcard vendor/lua/*.c)
LuaInject_CFLAGS = -fobjc-arc -Ivendor/lua -DLUA_USE_IOS
LuaInject_FRAMEWORKS = Foundation UIKit
LuaInject_INSTALL_PATH = /usr/lib

include $(THEOS_MAKE_PATH)/library.mk

# Fetch Lua source if not present
before-all::
	@bash scripts/fetch-lua.sh
