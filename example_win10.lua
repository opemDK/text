-- example_win10.lua
local gui = require("win10_gui")

-- Main window
local mainWin = gui.Window:new(4, 3, 32, 10, "Windows 10 Style")
mainWin:addChild(gui.Label:new(2, 2, "Flat design, modern colors", colors.black, colors.white))

local counter = 0
local countLabel = gui.Label:new(2, 4, "Count: 0", colors.black, colors.white)
mainWin:addChild(countLabel)

mainWin:addChild(gui.Button:new(2, 6, "Increment", function()
    counter = counter + 1
    countLabel.text = "Count: " .. counter
end))

-- Second window
local secondWin = gui.Window:new(40, 5, 24, 8, "Settings")
secondWin:addChild(gui.Label:new(2, 2, "This is a demo window", colors.black, colors.white))
secondWin:addChild(gui.Button:new(2, 4, "Exit", function()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    error("User exit", 0)
end))

gui.addWindow(mainWin)
gui.addWindow(secondWin)

gui.run()
