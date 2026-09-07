--[[
    SpongeHUB - Universal UI Framework
    Static, module-driven GUI. Modules register with UI:Add_Module(name)
    and add controls (Toggle / Slider / Button / Label) that bind to UN.Config.

    Methods:
        UI:Create(title)        -> builds the static GUI
        UI:Add_Module(name)     -> returns a module handle {Toggle, Slider, Button, Label}
        UI:Select(name)         -> show a module's panel
        UI:List()               -> returns {name, ...} of registered modules
        UI:Unload()             -> destroys the GUI (use UN.UnloadAll for full unload)
        UI:Toggle()             -> show/hide GUI
]]

local UN = getgenv().UN
assert(UN, "[UI] Load Utils.luau first!")

local UserInputService = UN.UserInputService
local CoreGui = game:GetService("CoreGui")

local UI = {}
UI.Modules = {}          -- name -> {button, frame, y}
UI.Gui = nil
UI.Main = nil
UI.ListFrame = nil
UI.ContentFrame = nil
UI.Open = false
UI.Selected = nil

local ACCENT = Color3.fromRGB(200, 120, 255)
local PANEL = Color3.fromRGB(18, 18, 28)
local BTN = Color3.fromRGB(40, 40, 60)
local BTN_ON = Color3.fromRGB(70, 40, 110)

function UI:Create(title)
    if self.Gui then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "SpongeHubUI"
    gui.ResetOnSpawn = false
    gui.Parent = CoreGui
    self.Gui = gui

    local main = Instance.new("Frame", gui)
    main.Size = UDim2.new(0, 380, 0, 440)
    main.Position = UDim2.new(0.5, -190, 0.5, -220)
    main.BackgroundColor3 = PANEL
    main.BorderSizePixel = 0
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)
    self.Main = main

    local titleL = Instance.new("TextLabel", main)
    titleL.Size = UDim2.new(1, -40, 0, 28)
    titleL.Position = UDim2.new(0, 8, 0, 4)
    titleL.Text = title or "SpongeHUB"
    titleL.TextColor3 = ACCENT
    titleL.BackgroundTransparency = 1
    titleL.Font = Enum.Font.GothamBold
    titleL.TextSize = 16
    titleL.TextXAlignment = Enum.TextXAlignment.Left

    local closeBtn = Instance.new("TextButton", main)
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -30, 0, 4)
    closeBtn.Text = "X"
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.BorderSizePixel = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function()
        self:Toggle()
    end)

    --// Sidebar list (UI:List)
    local list = Instance.new("Frame", main)
    list.Size = UDim2.new(0, 120, 1, -36)
    list.Position = UDim2.new(0, 0, 0, 32)
    list.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    list.BorderSizePixel = 0
    local listLayout = Instance.new("UIListLayout", list)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)
    self.ListFrame = list

    --// Content panel
    local content = Instance.new("ScrollingFrame", main)
    content.Size = UDim2.new(1, -124, 1, -64)
    content.Position = UDim2.new(0, 122, 0, 32)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.ScrollBarThickness = 4
    self.ContentFrame = content

    --// Unload All button
    local unloadBtn = Instance.new("TextButton", main)
    unloadBtn.Size = UDim2.new(1, -8, 0, 26)
    unloadBtn.Position = UDim2.new(0, 4, 1, -30)
    unloadBtn.Text = "Unload All"
    unloadBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
    unloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    unloadBtn.BorderSizePixel = 0
    unloadBtn.Font = Enum.Font.GothamBold
    unloadBtn.TextSize = 13
    Instance.new("UICorner", unloadBtn).CornerRadius = UDim.new(0, 6)
    unloadBtn.MouseButton1Click:Connect(function()
        UN.UnloadAll()
        pcall(function() self.Gui:Destroy() end)
        self.Gui = nil
    end)

    --// Show first module by default later; toggle key
    UN.TrackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
            self:Toggle()
        end
    end))

    main.Visible = false
    self.Open = false
end

function UI:Toggle()
    if not self.Main then return end
    self.Open = not self.Open
    self.Main.Visible = self.Open
end

function UI:Select(name)
    local entry = self.Modules[name]
    if not entry then return end
    for n, e in pairs(self.Modules) do
        e.frame.Visible = (n == name)
        e.button.BackgroundColor3 = (n == name) and BTN_ON or BTN
    end
    self.Selected = name
end

function UI:List()
    local names = {}
    for n, _ in pairs(self.Modules) do
        table.insert(names, n)
    end
    return names
end

function UI:Unload()
    pcall(function()
        if self.Gui then self.Gui:Destroy() end
    end)
    self.Gui = nil
end

--// Register a module; returns a handle with control builders bound to UN.Config
function UI:Add_Module(name)
    if not self.Gui then self:Create() end
    if self.Modules[name] then
        return self.Modules[name].handle
    end

    local btn = Instance.new("TextButton", self.ListFrame)
    btn.Size = UDim2.new(1, -8, 0, 26)
    btn.BackgroundColor3 = BTN
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = name
    btn.AutoButtonColor = false

    local frame = Instance.new("Frame", self.ContentFrame)
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.AutomaticSize = Enum.AutomaticSize.Y

    local state = {button = btn, frame = frame, y = 0}
    self.Modules[name] = state

    btn.MouseButton1Click:Connect(function() self:Select(name) end)

    local handle = {}
    function handle:_next()
        state.y = state.y + 30
        return UDim2.new(0, 6, 0, state.y - 26)
    end

    function handle:Toggle(label, configKey, callback)
        local btnC = Instance.new("TextButton", frame)
        btnC.Size = UDim2.new(1, -12, 0, 24)
        btnC.Position = self:_next()
        btnC.BackgroundColor3 = BTN
        btnC.BorderSizePixel = 0
        btnC.Font = Enum.Font.Gotham
        btnC.TextSize = 13
        btnC.TextXAlignment = Enum.TextXAlignment.Left
        btnC.AutoButtonColor = false
        local function refresh()
            local on = UN.Config[configKey]
            btnC.Text = (on and "[X] " or "[ ] ") .. label
            btnC.TextColor3 = on and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(200, 200, 200)
        end
        btnC.MouseButton1Click:Connect(function()
            UN.Config[configKey] = not UN.Config[configKey]
            if callback then callback(UN.Config[configKey]) end
            refresh()
        end)
        refresh()
    end

    function handle:Slider(label, min, max, configKey, callback)
        local btnC = Instance.new("TextButton", frame)
        btnC.Size = UDim2.new(1, -12, 0, 24)
        btnC.Position = self:_next()
        btnC.BackgroundColor3 = BTN
        btnC.BorderSizePixel = 0
        btnC.Font = Enum.Font.Gotham
        btnC.TextSize = 13
        btnC.TextXAlignment = Enum.TextXAlignment.Left
        btnC.AutoButtonColor = false
        local function refresh()
            btnC.Text = label .. ": " .. tostring(UN.Config[configKey])
        end
        btnC.MouseButton1Click:Connect(function()
            local cur = UN.Config[configKey]
            local step = math.max(1, math.floor((max - min) / 10))
            local nv = cur + step
            if nv > max then nv = min end
            UN.Config[configKey] = nv
            if callback then callback(nv) end
            refresh()
        end)
        refresh()
    end

    function handle:Button(label, callback)
        local btnC = Instance.new("TextButton", frame)
        btnC.Size = UDim2.new(1, -12, 0, 24)
        btnC.Position = self:_next()
        btnC.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
        btnC.BorderSizePixel = 0
        btnC.Font = Enum.Font.Gotham
        btnC.TextSize = 13
        btnC.TextColor3 = Color3.fromRGB(255, 255, 255)
        btnC.Text = label
        btnC.AutoButtonColor = false
        btnC.MouseButton1Click:Connect(function()
            if callback then callback() end
        end)
        return btnC
    end

    function handle:Label(text)
        local lbl = Instance.new("TextLabel", frame)
        lbl.Size = UDim2.new(1, -12, 0, 22)
        lbl.Position = self:_next()
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = text
    end

    function handle:Section(title)
        local sec = Instance.new("TextLabel", frame)
        sec.Size = UDim2.new(1, -12, 0, 20)
        sec.Position = self:_next()
        sec.BackgroundColor3 = Color3.fromRGB(55, 45, 80)
        sec.BorderSizePixel = 0
        sec.Font = Enum.Font.GothamBold
        sec.TextSize = 13
        sec.TextColor3 = ACCENT
        sec.TextXAlignment = Enum.TextXAlignment.Left
        sec.Text = "  " .. title
        state.y = state.y + 4
    end

    --// Dropdown / cycle button: cycles through `options`, stores chosen in UN.Config[configKey]
    function handle:Dropdown(label, options, configKey)
        local btnC = Instance.new("TextButton", frame)
        btnC.Size = UDim2.new(1, -12, 0, 24)
        btnC.Position = self:_next()
        btnC.BackgroundColor3 = BTN
        btnC.BorderSizePixel = 0
        btnC.Font = Enum.Font.Gotham
        btnC.TextSize = 13
        btnC.TextXAlignment = Enum.TextXAlignment.Left
        btnC.AutoButtonColor = false
        local function refresh()
            btnC.Text = label .. ": " .. tostring(UN.Config[configKey])
        end
        btnC.MouseButton1Click:Connect(function()
            local cur = UN.Config[configKey]
            local idx = 1
            for i, o in ipairs(options) do if o == cur then idx = i end end
            UN.Config[configKey] = options[idx % #options + 1]
            refresh()
        end)
        refresh()
        return btnC
    end

    --// Keybind recorder: click, then press a key; stores Enum.KeyCode name in UN.Config[configKey]
    function handle:Keybind(label, configKey)
        local btnC = Instance.new("TextButton", frame)
        btnC.Size = UDim2.new(1, -12, 0, 24)
        btnC.Position = self:_next()
        btnC.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        btnC.BorderSizePixel = 0
        btnC.Font = Enum.Font.Gotham
        btnC.TextSize = 13
        btnC.TextXAlignment = Enum.TextXAlignment.Left
        btnC.AutoButtonColor = false
        local recording = false
        local function refresh()
            local v = UN.Config[configKey]
            btnC.Text = label .. ": " .. (recording and "[press key]" or tostring(v or "None"))
        end
        btnC.MouseButton1Click:Connect(function()
            recording = true
            refresh()
        end)
        UN.TrackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
            if recording and not gpe then
                UN.Config[configKey] = tostring(input.KeyCode)
                recording = false
                refresh()
            end
        end))
        refresh()
        return btnC
    end

    --// LogBox: a live-updating multi-line TextLabel the module can refresh itself
    function handle:LogBox(height)
        local box = Instance.new("TextLabel", frame)
        box.Size = UDim2.new(1, -12, 0, height or 160)
        box.Position = self:_next()
        box.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
        box.BorderSizePixel = 0
        box.Font = Enum.Font.Code
        box.TextSize = 11
        box.TextColor3 = Color3.fromRGB(180, 255, 180)
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.TextYAlignment = Enum.TextYAlignment.Top
        box.TextWrapped = true
        box.Text = ""
        return box
    end

    state.handle = handle
    if not self.Selected then self:Select(name) end
    return handle
end

UN.RegisterModule("UI", UI)
print("[UN] UI framework loaded.")
