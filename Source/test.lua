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
    
    objc.add_method(class, "testMe", "v@:", 
      function (self) 
        print "testMe works" 
      end)

    objc.add_method(class, "secondTest:and:also:", "@@:id@", 
      function (self, first, second, third) 
        print(self, "Second test")
        print("1 argument: ", first) 
        print("2 argument: ", second) 
        print("3 argument: ", third) 
        return "string returned from secondTest:and:also:"
      end)
    
  end)

MySubClass = objc.new_class("MySubClass", objc.class.MyClass,
  function (class)
    print ("initing subclass")
  end)

MyClass:alloc():init():testMe()
sub = MySubClass:alloc():init()
sub:testMe()
print(sub:secondTest_and_also_(10, 20, "from lua"))


