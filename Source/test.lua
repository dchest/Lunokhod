--[[
print("Hello from Lunokhod!")

manager = objc.class.NSFileManager:defaultManager()
print(manager:currentDirectoryPath())
print(manager:displayNameAtPath_("/Applications"))

number = objc.class.NSNumber:numberWithInteger_(200)
print(number:className(), "(length=" .. number:className():length() .. ")", number)
--]]
--[[
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

    objc.add_method(class, "secondTest:and:also:", "@@:idd@",
      function (self, first, second, third, fourth)
        print(self, "Second test")
        print("1 argument: ", first)
        print("2 argument: ", second)
        print("3 argument: ", third)
        print("4 argument: ", fourth)
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
print(sub:secondTest_and_also_(10, 20, 30, "from lua"))
--]]

--[[
-- test Cocoa
print("-----------------------------------------------")


-- Helper functions to create UI elements

function Window (t)
  local win = objc.class.NSWindow:alloc():initWithContentRect_styleMask_backing_defer_(
    objc.rect(t.x or 0, t.y or 0, t.width or 300, t.height or 200),
    t.style or 15,
    2,  -- NSBackingStoreBuffered
    false)
  win:setTitle_(t.title or "")
  return win
end

function Button (t)
  local button = objc.class.NSButton:alloc():initWithFrame_(
    objc.rect(t.x or 0, t.y or 0, t.width or 0, t.height or 0))
  button:setBezelStyle_(t.bezelStyle or 1) -- NSRoundedBezelStyle
  button:setTitle_(t.title or "")
  if t.action ~= nil then
    local controller_class = "ButtonController_"..tostring(math.random(1, 1000))
    local controller = objc.new_class(controller_class,
      objc.class.NSObject,
      function (class)
        objc.add_method(class, "buttonAction:", "@@:@", t.action)
      end):alloc():init()
    button:setTarget_(controller)
    button:setAction_(controller.buttonAction_)
  end
  return button
end

function WebView (t)
  local web = objc.class.WebView:alloc():initWithFrame_(
    objc.rect(t.x or 0, t.y or 0, t.width or 0, t.height or 0))
  if t.onload ~= nil then
    local delegate_class = "WebViewDelegate_"..tostring(math.random(1, 1000))
    local delegate = objc.new_class(delegate_class, objc.class.NSObject,
      function (class)
        objc.add_method(class, "webView:didFinishLoadForFrame:", "v@:@@", t.onload)
      end):alloc():init()
    web:setFrameLoadDelegate_(delegate)
  end
  local frame = web:mainFrame()
  if t.url ~= nil then
    frame:loadRequest_(objc.class.NSURLRequest:requestWithURL_(
      objc.class.NSURL:URLWithString_(t.url)))
  end
  return web
end

-- Application

app = objc.class.NSApplication:sharedApplication()


local window = Window{
        x = 0,
        y = 0,
        width = 500,
        height = 600,
        title = "Hello World"
      }

local sayButton = Button{
        width = 100,
        height = 60,
        title = "Say Hello",
        action = function (sender)
                    print("Hello world!")
                  end
       }

local quitButton = Button{
        x = 100,
        width = 100,
        height = 60,
        title = "Quit",
        action = function (sender)
                    app:terminate_(sender)
                  end
       }

window:contentView():addSubview_(sayButton)
window:contentView():addSubview_(quitButton)

objc.load_framework("/System/Library/Frameworks/WebKit.framework")

web = WebView{
        y = 100,
        width = 500,
        height = 500,
        url = "http://www.codingrobots.com",
        onload = function (sender, view, frame)
                    -- save page screenshot
                    local v = frame:frameView():documentView()
                    local rect = v:bounds()
                    local imageRep = v:bitmapImageRepForCachingDisplayInRect_(rect)
                    v:cacheDisplayInRect_toBitmapImageRep_(rect, imageRep)
                    local image = objc.class.NSImage:alloc():init()
                    image:addRepresentation_(imageRep)
                    image:TIFFRepresentation():writeToFile_atomically_("/Users/dmitry/Desktop/1.tiff", 1)
                 end
      }
window:contentView():addSubview_(web)

window:display()
window:makeKeyAndOrderFront_(window)
app:run()

--]]
