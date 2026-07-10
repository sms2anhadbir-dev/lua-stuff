-- Plain Lua. No special API — just standard Lua 5.4.
print("hello from " .. _VERSION)

-- loadstring-style dynamic code (loadstring was renamed to load in 5.4):
local f = load("return 2 + 2")
print("2+2 =", f())

for i = 1, 3 do
    print("count", i)
end
