--[[
objc_class_metatable = {}
function objc_class_metatable.__index (self, method)
  return function ()
    print("index:")
    print(table.concat(self, ","))
    print(method)
  end
end
--]]

--[[ Here's our module in Lua
objc = {
  class = objc_lookup_class,
}
--]]


print("Hello from Lunokhod! :)")

manager = objc.class.NSFileManager.defaultManager()
print(manager:currentDirectoryPath("test"))