-----------------------------------------------------------------------------
-- Application

app = Application()

local sayButton = Button:new{
        --superview = window,
        width = 100,
        height = 60,
        title = "Say Hello",
        action = function (btn)
                    print("Hello world!")
                 end
      }

local quitButton = Button:new{
        --superview = window,
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


local window = Window:new{
        x = 0,
        y = 0,
        width = 500,
        height = 600,
        title = "Hello World",
        subviews = { sayButton, quitButton }
      }


-- Example of prototype-based OO
local anotherButton = quitButton:new{
  superview = window,
  x = 200,
  title = "Haha",
  action = function () print"Haha" end
}

local web = WebView:new{
        y = 100,
        width = 500,
        height = 500,
        url = "http://www.google.com",
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

