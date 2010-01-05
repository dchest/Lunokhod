print("Hello from Lunokhod!")

manager = objc.class.NSFileManager:defaultManager()
print(manager:currentDirectoryPath())

--[[ 

Some docs:

objc module (table):

objc = {
  class = objc_lookup_class,
}
--]]
