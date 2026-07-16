-- example_win10.lua
local gui = require("win10_gui")

-- 主窗口
local mainWin = gui.Window:new(4, 3, 32, 10, "Windows 10 风格")
mainWin:addChild(gui.Label:new(2, 2, "扁平化设计，现代色彩", colors.black, colors.white))

local counter = 0
local countLabel = gui.Label:new(2, 4, "计数: 0", colors.black, colors.white)
mainWin:addChild(countLabel)

mainWin:addChild(gui.Button:new(2, 6, "增加", function()
    counter = counter + 1
    countLabel.text = "计数: " .. counter
end))

-- 第二个窗口
local secondWin = gui.Window:new(40, 5, 22, 8, "设置")
secondWin:addChild(gui.Label:new(2, 2, "这是一个演示窗口", colors.black, colors.white))
secondWin:addChild(gui.Button:new(2, 4, "退出", function()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    error("用户退出", 0)
end))

gui.addWindow(mainWin)
gui.addWindow(secondWin)

gui.run()
