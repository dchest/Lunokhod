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

MyClass = objc.newclass("MyClass", objc.class.NSObject,
  function (class) -- class initialization
    print ("Class initialization")

    objc.addmethod(class, "testMe", "v@:",
      function (self)
        print "testMe works"
      end)

    objc.addmethod(class, "secondTest:and:also:", "@@:idd@",
      function (self, first, second, third, fourth)
        print(self, "Second test")
        print("1 argument: ", first)
        print("2 argument: ", second)
        print("3 argument: ", third)
        print("4 argument: ", fourth)
        return "string returned from secondTest:and:also:"
      end)

  end)

MySubClass = objc.newclass("MySubClass", objc.class.MyClass,
  function (class)
    print ("initing subclass")
  end)

MyClass:alloc():init():testMe()
sub = MySubClass:alloc():init()
sub:testMe()
print(sub:secondTest_and_also_(10, 20, 30, "from lua"))
--]]

---[[
-- test Cocoa
print("-----------------------------------------------")


-- Helpers --

function newinstance (t)
  local o = {}
  setmetatable(o, t)
  t.__index = t
  return o
end

function uuid ()
  return tostring(objc.class.NSProcessInfo:processInfo():globallyUniqueString())
end

function unique_classname (prefix)
  if prefix == nil then prefix = "Class" end
  return prefix .. "_" .. string.gsub(uuid(), "-", "")
end


-------------------------------------------------------------------------------------

Window = {}

function Window:new (t)
  local w = newinstance(self)
  w.object = objc.class.NSWindow:alloc():initWithContentRect_styleMask_backing_defer_(
    objc.rect(t.x or 0, t.y or 0, t.width or 300, t.height or 200),
    t.style or 15,
    2,  -- NSBackingStoreBuffered
    false)
  w.object:setTitle_(t.title or "")
  return w
end

function Window:addview (v)
  if type(v) == "table" then v = v.object end
  self.object:contentView():addSubview_(v)
end

function Window:show ()
  self.object:display()
  self.object:makeKeyAndOrderFront_(self.object)
end

-------------------------------------------------------------------------------------

Button = {}

function Button:new (t)
  local b = newinstance(self)
  b.object = objc.class.NSButton:alloc():initWithFrame_(
                objc.rect(t.x or 0, t.y or 0, t.width or 0, t.height or 0))
  b.object:setBezelStyle_(t.bezelStyle or 1) -- NSRoundedBezelStyle
  b.object:setTitle_(t.title or "")

  if t.action ~= nil then
    -- controller object is unique for every button
    local ctr = objc.newclass(unique_classname("ButtonController"), objc.class.NSObject,
      function (class)
        objc.addmethod(class, "buttonAction:", "@@:@", function (s) print(s) t.action(button) end)
      end):alloc():init()
    b.object:setTarget_(ctr)
    b.object:setAction_(ctr.buttonAction_)
  end

  return b
end

-------------------------------------------------------------------------------------

function WebView (t)
  local web = objc.class.WebView:alloc():initWithFrame_(
    objc.rect(t.x or 0, t.y or 0, t.width or 0, t.height or 0))
  if t.onload ~= nil then
    local delegate_class = "WebViewDelegate_"..tostring(math.random(1, 1000))
    local delegate = objc.newclass(delegate_class, objc.class.NSObject,
      function (class)
        objc.addmethod(class, "webView:didFinishLoadForFrame:", "v@:@@",
            function (sender, webview, frame)
              t.onload(webview, frame)
            end)
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

local window = Window:new{
        x = 0,
        y = 0,
        width = 500,
        height = 600,
        title = "Hello World"
      }

local sayButton = Button:new{
        width = 100,
        height = 60,
        title = "Say Hello",
        action = function ()
                    print("Hello world!")
                  end
      }

local quitButton = Button:new{
        x = 100,
        width = 100,
        height = 60,
        title = "Quit",
        action = function ()
                    app:terminate_(nil)
                  end
      }

window:addview(sayButton)
window:addview(quitButton)

objc.loadframework("/System/Library/Frameworks/WebKit.framework")

local web = WebView{
        y = 100,
        width = 500,
        height = 500,
        url = "http://www.google.com",
        onload = function (webview, frame)
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
window:addview(web)

window:show()

app:run()

--]]
