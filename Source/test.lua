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
print("-----------------------------------------------")


--- Helpers --------------------------------------------------------------------------

function newinstance (self, init)
  --local o = {}
  setmetatable(init, self)
  self.__index = self
  return init
end

function uuid ()
  return tostring(objc.class.NSProcessInfo:processInfo():globallyUniqueString())
end

function unique_classname (prefix)
  if prefix == nil then prefix = "Class" end
  return prefix .. "_" .. string.gsub(uuid(), "-", "")
end

--[[

  Convert string describing selector and types to
  selector string and types string.

  Example:

    (void)webView:(id) didFinishLoadForFrame:(id)

  will return:

    "webView:didFinishLoadFrame:", "v@:@@"

--]]
function toselector (s)
  local objc_types = {
    void = "v",
    id = "@",
    IBAction = "@",
    double = "d",
    int = "i"
    --TODO: add more types
  }
  local sel = ""
  local types = ""
  local w
  local i = 0
  local istype = true
  local hasreturntype = false

  while 1 do
    w, i = string.match(s, "([%w_:]+)()", i)
    if w == nil then break end
    if istype then
      types = types .. objc_types[w]
      if not hasreturntype then
        types = types .. "@:" -- add self and _cmd types
        hasreturntype = true
      end
    else
      sel = sel .. w
    end
    istype = not istype
  end
  return sel, types
end

--[[

  Call function func with arguments if it's not nil

--]]
function maybecall(func, ...)
  if func ~= nil then
    func(...)
  end
end


-------------------------------------------------------------------------------------

function Class (param)
  return objc.newclass(
    param.name or unique_classname(param.prefix or ""),
    param.parent or objc.class.NSObject,
    function (c)
      for k, v in pairs(param.methods) do
        local sel, typ = toselector(k)
        objc.addmethod(c, sel, typ, v)
      end
    end)
end

function Object (param)
  return Class(param):alloc():init()
end

function setaction (t, func)
  local ctr = Object{
                prefix = "ActionController",
                methods = {
                  ["(IBAction)doAction:(id)"] = func
                }
              }
  t.object:setTarget_(ctr)
  t.object:setAction_(ctr.doAction_)
end

-------------------------------------------------------------------------------------

Window = {}

function Window:new (t)
  local w = newinstance(self, t)
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

function Button:new (init)
  local b = newinstance(self, init)
  b.object = objc.class.NSButton:alloc():initWithFrame_(
                objc.rect(b.x or 0, b.y or 0, b.width or 0, b.height or 0))
  b.object:setBezelStyle_(b.style or 1) -- NSRoundedBezelStyle
  b.object:setTitle_(b.title or "")
  setaction(b, function () b:action() end)
  return b
end

--------------------------------------
--[[
Class{
  name = "MyClass",
  parent = objc.class.NSObject,
  methods = {
    "(id)webView:(id)didFinishLoadForFrame:(id)" = function () print "OK" end
  }
}
]]

-------------------------------------------------------------------------------------

WebView = {}

function WebView:new (init)

  if not self.frameworkloaded then
    objc.loadframework("WebKit")
    self.frameworkloaded = true
  end

  local w = newinstance(self, init)
  w.object = objc.class.WebView:alloc():initWithFrame_(
    objc.rect(w.x or 0, w.y or 0, w.width or 0, w.height or 0))

  w.object:setFrameLoadDelegate_(
    Object{
      prefix = "WebViewDelegate",
      methods = {
        ["(void)webView:(id)didFinishLoadForFrame:(id)"] =
          function (_,_,frame) maybecall(w.onload, w, frame) end
      }
    }
  )

  if w.url ~= nil then
    w:load(w.url)
  end
  return w
end

function WebView:load (url)
  self.object:mainFrame():loadRequest_(objc.class.NSURLRequest:requestWithURL_(
    objc.class.NSURL:URLWithString_(url)))
end

-------------------------------------------------------------------------------------

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
        action = function (btn)
                    print("Hello world!")
                 end
      }

local quitButton = Button:new{
        x = 100,
        width = 100,
        height = 60,
        title = "Quit",
        action = function (sender)
                    print("Click again to quit")
                    sender.action = function ()
                      app:terminate_(nil)
                    end
                  end
      }

window:addview(sayButton)
window:addview(quitButton)

local web = WebView:new{
        y = 100,
        width = 500,
        height = 500,
        url = "about:blank",
        onload = function (w, frame)
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

--]] --EOF
