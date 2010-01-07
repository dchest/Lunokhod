--[[
print("Hello from Lunokhod!")

manager = objc.class.NSFileManager:defaultManager()
print(manager:currentDirectoryPath())
print(manager:displayNameAtPath_("/Applications"))

number = objc.class.NSNumber:numberWithInteger_(200)
print(number:className(), "(length=" .. number:className():length() .. ")", number)

for i=1,20000 do
  manager = objc.class.NSFileManager:defaultManager()
  manager:currentDirectoryPath()
  manager:displayNameAtPath_("/Applications"):length()
end
--]]


MyClass = objc.new_class("MyClass", objc.class.NSObject, 
  function (class) -- class initialization 
    print ("Class initialization")
    
    objc.add_method(class, "testMe", "v@:", function (self) print "\n=====YES!====\n" end)
    
  end
)

print "\n"
for k,v in pairs(__LUNOKHOD_DISPATCH) do
  print("-->", k,v)
  for k2, v2 in pairs(v) do
    print("\t->", k2, v2)
  end
end

MyClass:alloc():init():testMe()

MySubClass = objc.new_class("MySubClass", objc.class.MyClass,
  function (class)
    print ("initing subclass")
  end)
  
a = MySubClass:alloc():init()
a:testMe()
for i=1,1000 do
  a:testMe()
end

--print(MyClass:description())

--[=[
TODO

-- Creating classes:

Video = objc.class.new{
  name = "Video",
  parent = "NSObject",

  vars = {
    imagerep = ""
  }

  methods = {    
    imageRepresentation = function (self)
      local imagerep = fetch_image()
      return imagerep
    end
  }
}

-- alternative (or original):

-- this will be in C
function objc.new_class(name, parent, init_func)
  local c = objc.create_class(name, parent)
  init_func(c)
  objc.finalize_class(c)
  return c
end


MyClass = objc.new_class("MyClass", objc.class.NSObject, 
  function (class) -- class initialization 

    objc.add_method(class, "doSomething:withMe:", "v:@@", -- need to get rid of types
      function (self, a, b) -- body of method
        print("test method", a, b)
      end) 

    objc.add_method(class, "doSomethingElse:", "v@:@", -- need to get rid of types
      function (self, a) -- body of method
        print("second method", a)
      end) 

    objc.add_ivar(k, ...)
  end)

--[[ 

Some docs:

objc module (table):

objc = {
  class = objc_lookup_class,
}
--]]
--]=]