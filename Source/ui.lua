-- This is not a module, since we want almost
-- everything here to be in global space

--- Helpers ---------------------------------------------------------------------

--[[

  Create new instance of "class" (table) `self` and initialize it with `init` table.

--]]
function newinstance (self, init)
  setmetatable(init, self)
  self.__index = self
  return init
end

function uuid ()
  return tostring(objc.class.NSProcessInfo:processInfo():globallyUniqueString())
end

--[[

  Return unique string good for use as a class name.

  (prefix_UUID, or Class_UUID if no prefix given)

--]]
function unique_classname (prefix)
  return (prefix or "Class") .. "_" .. string.gsub(uuid(), "-", "")
end

--[[

  Convert string describing Objective-C method to selector and types strings.

  Examples:

    "(void)webView:(id) didFinishLoadForFrame:(id)" => "webView:didFinishLoadFrame:", "v@:@@"
    "(unsigned int)test" => "test", "I@:"

--]]
local function parse_method (method)
  local objc_types = {
    _Bool = "B",
    char = "c",
    ["unsigned char"] = "C",
    double = "d",
    float = "f",
    int = "i",
    ["unsigned int"] = "I",
    long = "l",
    ["unsigned long"] = "L",
    ["long long"] = "q",
    ["unsigned long long"] = "Q",
    short = "s",
    ["unsigned short"] = "S",
    void = "v",
    id = "@",
    IBAction = "@",
    class = "#",
    ["void *"] = "^",
    ["const char *"] = "*",
    array = "[",
    struct = "{",
    SEL = ":",
  }
  local sel = ""
  local types = ""
  local isreturntype = true

  for t, s in string.gmatch(method, "%(([^%)]+)%)%s?([^%(]*)") do
    types = types .. objc_types[t]
    if isreturntype then
      types = types .. "@:" -- insert self and _cmd types
      isreturntype = false
    end
    sel = sel .. s
  end
  return sel, types
end

--[[

  Call function `func` (with arguments) if it's not nil

--]]
function maybecall (func, ...)
  if func ~= nil then
    return func(...)
  end
end


-------------------------------------------------------------------------------------

--[[

  Create new Objective-C class and return it.

  Example:

    Class{
      name = "MyClass",
      parent = objc.class.NSObject,
      methods = {
        "(id)webView:(id)didFinishLoadForFrame:(id)" = function () print "OK" end
      }
    }

  Can omit:

    `parent` - default is objc.class.NSObject
    `name` - default is a unique class name (with `prefix` if given)
    `methods` - default is don't add methods... but why?

--]]
function Class (param)
  return objc.newclass(
    param.name or unique_classname(param.prefix or ""),
    param.parent or objc.class.NSObject,
    function (c)
      for k, v in pairs(param.methods) do
        local sel, typ = parse_method(k)
        objc.addmethod(c, sel, typ, v)
      end
    end)
end

--[[

  Create new Objective-C class and return a new instance of it.

  Arguments are the same as in `Class`.

--]]
function Object (param)
  return Class(param):alloc():init()
end

--[[

  Assign an action function to table's Objective-C object.

  Creates a new controller object (with method `func`) and sets it as target.

--]]
function setaction (t, func)
  local ctr = Object{
                prefix = "ActionController",
                methods = {
                  ["(IBAction)doAction:(id)"] = func
                }
              }
  t.object:setTarget_(ctr)
  t.object:setAction_(ctr.doAction_)
  return ctr -- just in case the caller needs it
end

----------------------------------------------------------------------------------

Window = {}

function Window:new (t)
  local w = newinstance(self, t)
  w.object = objc.class.NSWindow:alloc():initWithContentRect_styleMask_backing_defer_(
    objc.rect(t.x or 0, t.y or 0, t.width or 300, t.height or 200),
    t.style or 15,
    2,  -- NSBackingStoreBuffered
    false)
  w.object:setTitle_(t.title or "")
  if t.subviews ~= nil then
    for _, v in ipairs(t.subviews) do
      w.object:contentView():addSubview_(v.object)
    end
  end
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

----------------------------------------------------------------------------------

Button = {}

function Button:new (init)
  local b = newinstance(self, init)
  b.object = objc.class.NSButton:alloc():initWithFrame_(
                objc.rect(b.x or 0, b.y or 0, b.width or 0, b.height or 0))
  b.object:setBezelStyle_(b.style or 1) -- NSRoundedBezelStyle
  b.object:setTitle_(b.title or "")
  setaction(b, function () b:action() end)
  if b.superview ~= nil then
    b.superview:addview(b)
  end
  return b
end

----------------------------------------------------------------------------------

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

----------------------------------------------------------------------------------

function Application ()
  return objc.class.NSApplication:sharedApplication()
end

