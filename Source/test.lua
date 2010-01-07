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

--[[
-- test Cocoa
print("-----------------------------------------------")

app = objc.class.NSApplication:sharedApplication()

win = objc.class.NSWindow:alloc():initWithContentRect_styleMask_backing_defer_(
  objc.rect(0, 0, 300, 200), 
  15, -- NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask
  2,  -- NSBackingStoreBuffered
  false)
win:setTitle_('Hello World')

button = objc.class.NSButton:alloc():initWithFrame_(objc.rect(0,0,200,200))
win:contentView():addSubview_(button)
button:setBezelStyle_(1) -- NSRoundedBezelStyle
button:setTitle_('Hello!')
--button:sizeToFit()

button_controller = objc.new_class("ButtonController", objc.class.NSObject,
                      function (class)
                        objc.add_method(class, "sayHello:", "@@:@",
                          function (sender)
                            print("Hello, world!")
                          end)
                      end):alloc():init()
button:setTarget_(button_controller)
button:setAction_(button_controller.sayHello_)

win:display()
win:makeKeyAndOrderFront_(win)
app:activateIgnoringOtherApps_(1)
app:run()

--]]