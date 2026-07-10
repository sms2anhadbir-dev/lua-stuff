-- Dropped at /var/mobile/Library/LuaInject/scripts/example.lua on device
inject.log("Lua runtime is live inside " .. inject.bundleid())

-- Gate behaviour to a specific host app if you want:
if inject.bundleid() == "com.example.targetapp" then
    inject.log("hello from the target app")
end
