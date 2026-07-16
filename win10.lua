-- win10_gui.lua - ComputerCraft 文本模式 Windows 10 风格 GUI 框架

local gui = {}

-- Windows 10 配色方案（扁平化）
local colors = {
    desktop       = colors.lightBlue,   -- 桌面背景（类似默认壁纸色）
    windowBg      = colors.white,       -- 窗口客户区背景
    windowBorder  = colors.lightGray,   -- 窗口细边框
    titleActive   = colors.blue,        -- 活动标题栏背景
    titleInactive = colors.lightGray,   -- 非活动标题栏背景
    titleText     = colors.white,       -- 标题文字
    closeBtn      = colors.red,         -- 关闭按钮背景
    closeText     = colors.white,       -- 关闭按钮文字
    maxiBtn       = colors.lightGray,   -- 最大化/最小化按钮背景
    maxiText      = colors.black,       -- 按钮文字
    btnFace       = colors.lightGray,   -- 普通按钮背景
    btnText       = colors.black,       -- 按钮文字
    btnHover      = colors.gray,        -- 按钮悬停背景
    labelText     = colors.black,       -- 标签文字
}

-- 全局状态
local windows = {}           -- 所有顶层窗口
local focusedWindow = nil    -- 当前活动窗口
local dragTarget = nil       -- 正在拖拽的窗口
local dragOffsetX, dragOffsetY = 0, 0
local mouseDown = false

------------------------------------------------------------
-- 工具函数
------------------------------------------------------------
local function writeAt(x, y, text, fg, bg)
    if x < 1 or y < 1 then return end
    term.setCursorPos(x, y)
    if bg then term.setBackgroundColor(bg) end
    if fg then term.setTextColor(fg) end
    term.write(text)
end

local function fillRect(x, y, w, h, bg)
    if w <= 0 or h <= 0 then return end
    term.setBackgroundColor(bg)
    for dy = 0, h - 1 do
        term.setCursorPos(x, y + dy)
        term.write(string.rep(" ", w))
    end
end

local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px < rx + rw and py >= ry and py < ry + rh
end

-- 绘制单线边框（扁平风格）
local function drawFlatBorder(x, y, w, h, color)
    term.setBackgroundColor(color)
    term.setTextColor(color)
    -- 顶边和底边用空格填充，实际边框由背景色体现，这里采用字符边框
    term.setBackgroundColor(colors.windowBorder)
    term.setTextColor(colors.windowBorder)
    -- 外边框用细线字符
    local tl, tr, bl, br = "┌", "┐", "└", "┘"
    local hz, vt = "─", "│"
    term.setCursorPos(x, y)
    term.write(tl .. string.rep(hz, w - 2) .. tr)
    term.setCursorPos(x, y + h - 1)
    term.write(bl .. string.rep(hz, w - 2) .. br)
    for dy = 1, h - 2 do
        term.setCursorPos(x, y + dy)
        term.write(vt)
        term.setCursorPos(x + w - 1, y + dy)
        term.write(vt)
    end
end

------------------------------------------------------------
-- 基础组件
------------------------------------------------------------
local Component = {}
Component.__index = Component

function Component:new(x, y, width, height)
    local obj = {
        x = x, y = y,
        width = width, height = height,
        visible = true,
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function Component:draw(xAbs, yAbs) end

function Component:isInside(px, py)
    return pointInRect(px, py, self.x, self.y, self.width, self.height)
end

function Component:onClick(mx, my) end

------------------------------------------------------------
-- 标签
------------------------------------------------------------
local Label = setmetatable({}, { __index = Component })
Label.__index = Label

function Label:new(x, y, text, fg, bg)
    local obj = Component.new(self, x, y, #text, 1)
    obj.text = text
    obj.fg = fg or colors.labelText
    obj.bg = bg or colors.windowBg
    return obj
end

function Label:draw(xAbs, yAbs)
    if not self.visible then return end
    writeAt(xAbs, yAbs, self.text, self.fg, self.bg)
end

------------------------------------------------------------
-- Win10 风格扁平按钮
------------------------------------------------------------
local Button = setmetatable({}, { __index = Component })
Button.__index = Button

function Button:new(x, y, text, callback)
    local obj = Component.new(self, x, y, #text + 2, 1) -- 左右各留1格内边距
    obj.text = text
    obj.callback = callback
    obj.isHovered = false
    return obj
end

function Button:draw(xAbs, yAbs)
    if not self.visible then return end
    local bg = self.isHovered and colors.btnHover or colors.btnFace
    local fg = colors.btnText
    local pad = string.rep(" ", 1)  -- 内边距
    local innerText = pad .. self.text .. pad
    writeAt(xAbs, yAbs, innerText, fg, bg)
end

function Button:onClick(mx, my)
    if self.callback and self:isInside(mx, my) then
        self.callback()
        return true
    end
    return false
end

------------------------------------------------------------
-- 窗口
------------------------------------------------------------
local Window = setmetatable({}, { __index = Component })
Window.__index = Window

function Window:new(x, y, width, height, title)
    height = math.max(height, 4)
    width = math.max(width, 12)  -- 确保标题栏能放下按钮
    local obj = Component.new(self, x, y, width, height)
    obj.title = title or "Window"
    obj.children = {}
    obj.draggable = true
    obj.showClose = true
    obj.showMaximize = true
    obj.showMinimize = true
    obj.onClose = nil
    return obj
end

function Window:addChild(component)
    table.insert(self.children, component)
end

function Window:draw()
    if not self.visible then return end
    local x, y, w, h = self.x, self.y, self.width, self.height
    local isActive = (focusedWindow == self)

    -- 1. 绘制细边框
    drawFlatBorder(x, y, w, h, colors.windowBorder)

    -- 2. 填充客户区背景（标题栏除外）
    fillRect(x + 1, y + 2, w - 2, h - 3, colors.windowBg)

    -- 3. 标题栏（扁平无立体）
    local titleBg = isActive and colors.titleActive or colors.titleInactive
    fillRect(x + 1, y + 1, w - 2, 1, titleBg)

    -- 标题文字
    local titleText = string.sub(self.title, 1, w - 8)  -- 为按钮留出空间
    writeAt(x + 2, y + 1, titleText, colors.titleText, titleBg)

    -- 4. 标题栏按钮（从右向左绘制）
    local btnStartX = x + w - 2   -- 按钮区域右端（内边框内）
    local btnY = y + 1
    local btnWidth = 2            -- 每个按钮占2格宽（字符+左右空隙）

    if self.showClose then
        local btnX = btnStartX - btnWidth + 1
        local hover = false -- 悬停状态在事件循环中处理，这里先默认不悬停
        local bg = colors.closeBtn
        local fg = colors.closeText
        -- 按钮背景矩形
        fillRect(btnX, btnY, btnWidth, 1, bg)
        writeAt(btnX + 1, btnY, "X", fg, bg)
        btnStartX = btnX - 1
    end
    if self.showMaximize then
        local btnX = btnStartX - btnWidth + 1
        local bg = colors.maxiBtn
        local fg = colors.maxiText
        fillRect(btnX, btnY, btnWidth, 1, bg)
        writeAt(btnX + 1, btnY, "□", fg, bg)
        btnStartX = btnX - 1
    end
    if self.showMinimize then
        local btnX = btnStartX - btnWidth + 1
        local bg = colors.maxiBtn
        local fg = colors.maxiText
        fillRect(btnX, btnY, btnWidth, 1, bg)
        writeAt(btnX + 1, btnY, "─", fg, bg)   -- 使用长破折号
        btnStartX = btnX - 1
    end

    -- 5. 绘制子组件（客户区坐标转换）
    local clientX, clientY = x + 1, y + 2
    for _, child in ipairs(self.children) do
        child:draw(clientX + child.x - 1, clientY + child.y - 1)
    end
end

-- 返回标题栏按钮类型（基于坐标）
function Window:getTitleButtonAt(mx, my)
    if not pointInRect(mx, my, self.x + 1, self.y + 1, self.width - 2, 1) then
        return nil
    end
    local btnStartX = self.x + self.width - 2
    local btnY = self.y + 1
    local btnWidth = 2
    if self.showClose and pointInRect(mx, my, btnStartX - btnWidth + 1, btnY, btnWidth, 1) then
        return "close"
    end
    btnStartX = btnStartX - btnWidth
    if self.showMaximize and pointInRect(mx, my, btnStartX - btnWidth + 1, btnY, btnWidth, 1) then
        return "maximize"
    end
    btnStartX = btnStartX - btnWidth
    if self.showMinimize and pointInRect(mx, my, btnStartX - btnWidth + 1, btnY, btnWidth, 1) then
        return "minimize"
    end
    return nil
end

function Window:isTitleBar(mx, my)
    local btnCount = (self.showClose and 1 or 0) + (self.showMaximize and 1 or 0) + (self.showMinimize and 1 or 0)
    local btnSpace = btnCount * 2 + 1 -- 每个按钮2格，另加1格间距
    local titleX = self.x + 1
    local titleY = self.y + 1
    local titleW = self.width - 2 - btnSpace
    return pointInRect(mx, my, titleX, titleY, titleW, 1)
end

function Window:close()
    if self.onClose then self.onClose() end
    self.visible = false
    for i, w in ipairs(windows) do
        if w == self then
            table.remove(windows, i)
            break
        end
    end
    if focusedWindow == self then
        focusedWindow = nil
    end
end

function Window:bringToFront()
    for i, w in ipairs(windows) do
        if w == self then
            table.remove(windows, i)
            break
        end
    end
    table.insert(windows, self)
    focusedWindow = self
end

function Window:handleClientClick(mx, my)
    local relX = mx - self.x - 1
    local relY = my - self.y - 2
    for _, child in ipairs(self.children) do
        if child.visible and child:isInside(relX, relY) then
            if child:onClick(relX, relY) then
                return true
            end
        end
    end
    return false
end

function Window:hasInteractiveAt(mx, my)
    local relX = mx - self.x - 1
    local relY = my - self.y - 2
    for _, child in ipairs(self.children) do
        if child.visible and child:isInside(relX, relY) then
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- 全局管理
------------------------------------------------------------
function gui.addWindow(window)
    table.insert(windows, window)
    window:bringToFront()
end

function gui.redraw()
    term.setBackgroundColor(colors.desktop)
    term.clear()
    for _, w in ipairs(windows) do
        w:draw()
    end
end

local function topWindowAt(mx, my)
    for i = #windows, 1, -1 do
        local w = windows[i]
        if w.visible and pointInRect(mx, my, w.x, w.y, w.width, w.height) then
            return w
        end
    end
    return nil
end

-- 更新按钮悬停状态（同时处理普通按钮和标题栏按钮）
local function updateHover(mx, my)
    local changed = false
    for _, w in ipairs(windows) do
        if w.visible and pointInRect(mx, my, w.x, w.y, w.width, w.height) then
            -- 客户区按钮悬停
            local relX = mx - w.x - 1
            local relY = my - w.y - 2
            for _, child in ipairs(w.children) do
                if child.isHovered ~= nil then
                    local hover = child:isInside(relX, relY)
                    if hover ~= child.isHovered then
                        child.isHovered = hover
                        changed = true
                    end
                end
            end
            -- 标题栏按钮悬停（简化处理，仅记录状态用于重绘，这里不单独保存按钮状态，每次重绘根据鼠标位置计算）
            -- 我们只需在绘制时判断，但为了即时反馈，可在 mouse_move 中触发重绘
        else
            for _, child in ipairs(w.children) do
                if child.isHovered then
                    child.isHovered = false
                    changed = true
                end
            end
        end
    end
    return changed
end

function gui.run()
    while true do
        gui.redraw()
        local event, p1, p2, p3 = os.pullEvent()

        if event == "mouse_click" then
            local button, mx, my = p1, p2, p3
            if button == 1 then
                local target = topWindowAt(mx, my)
                if target then
                    target:bringToFront()
                    local btn = target:getTitleButtonAt(mx, my)
                    if btn == "close" then
                        target:close()
                    elseif btn == "maximize" then
                        -- 可扩展最大化功能
                    elseif btn == "minimize" then
                        -- 可扩展最小化功能
                    elseif target:isTitleBar(mx, my) and not target:hasInteractiveAt(mx, my) then
                        dragTarget = target
                        dragOffsetX = mx - target.x
                        dragOffsetY = my - target.y
                        mouseDown = true
                    else
                        target:handleClientClick(mx, my)
                    end
                end
            end
        elseif event == "mouse_up" then
            local button = p1
            if button == 1 then
                dragTarget = nil
                mouseDown = false
            end
        elseif event == "mouse_drag" then
            local button, mx, my = p1, p2, p3
            if button == 1 and dragTarget then
                local sw, sh = term.getSize()
                dragTarget.x = math.max(1, math.min(mx - dragOffsetX, sw - dragTarget.width + 1))
                dragTarget.y = math.max(1, math.min(my - dragOffsetY, sh - dragTarget.height + 1))
            end
        elseif event == "mouse_move" then
            local mx, my = p1, p2
            if updateHover(mx, my) then
                gui.redraw()
            end
        elseif event == "key" then
            local key = p1
            if key == keys.q and #windows == 0 then
                term.setBackgroundColor(colors.black)
                term.clear()
                term.setCursorPos(1, 1)
                return
            end
        elseif event == "term_resize" then
            for _, w in ipairs(windows) do
                local sw, sh = term.getSize()
                w.x = math.min(w.x, sw - w.width + 1)
                w.y = math.min(w.y, sh - w.height + 1)
            end
        end
    end
end

gui.Window = Window
gui.Button = Button
gui.Label = Label

return gui
