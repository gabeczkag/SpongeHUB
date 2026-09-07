--[==[
    SpongeHUB - Universal Hub
    Loads all UniversalItems modules, builds a GUI, runs the main loop,
    and provides an "Unload All" button. Works on ANY game.

    Modules are pulled in with #include (resolved by the loader from
    scripts/UnversalItems/). You can add/remove includes freely, e.g.:
        --#include Aimbot.luau
        --#include ESP.luau
    The loader inlines them before running, so this file is self-contained.

    To load just this hub, run scripts/UnversalItems/loader.luau (it loads
    Utils.luau + this file), or paste this file's contents into your executor.
]==]

--#include Utils.luau
--#include Aimbot.luau
--#include PlayerMovement.luau
--#include AntiCheat.luau
--#include ESP.luau

local UN = getgenv().UN
assert(UN, "[Hub] Utils.luau failed to load (check #include).")

local Players = UN.Players
local RunService = UN.RunService
local UserInputService = UN.UserInputService
local LocalPlayer = UN.LocalPlayer

--// Init modules that need setup
if UN.State.Modules.AntiCheat then UN.State.Modules.AntiCheat:Init() end
if UN.State.Modules.Movement then UN.State.Modules.Movement:Init() end

--// ===================== GUI =====================
local CoreGui = game:GetService("CoreGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UniversalHubGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 320, 0, 360)
mainFrame.Position = UDim2.new(0.5, -160, 0.5, -180)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 30)
title.Text = "SpongeHUB Universal"
title.TextColor3 = Color3.fromRGB(200, 120, 255)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16

local tabs = {"Aimbot", "ESP", "Movement", "AntiCheat"}
local tabFrames = {}
local tabButtons = {}
local contentHolder = Instance.new("Frame", mainFrame)
contentHolder.Size = UDim2.new(1, -10, 1, -70)
contentHolder.Position = UDim2.new(0, 5, 0, 35)
contentHolder.BackgroundTransparency = 1

local tabBar = Instance.new("Frame", mainFrame)
tabBar.Size = UDim2.new(1, 0, 0, 25)
tabBar.Position = UDim2.new(0, 0, 0, 30)
tabBar.BackgroundTransparency = 1
local t = 0
for _, name in ipairs(tabs) do
    local btn = Instance.new("TextButton", tabBar)
    btn.Size = UDim2.new(1 / #tabs, 0, 1, 0)
    btn.Position = UDim2.new(t / #tabs, 0, 0, 0)
    btn.Text = name
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    tabButtons[name] = btn

    local frame = Instance.new("ScrollingFrame", contentHolder)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = false
    frame.CanvasSize = UDim2.new(0, 0, 0, 400)
    frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    frame.ScrollBarThickness = 4
    tabFrames[name] = frame
    t = t + 1
end

local function SelectTab(name)
    for n, f in pairs(tabFrames) do
        f.Visible = (n == name)
        tabButtons[n].BackgroundColor3 = (n == name) and Color3.fromRGB(70, 40, 110) or Color3.fromRGB(40, 40, 60)
    end
end
for _, name in ipairs(tabs) do
    tabButtons[name].MouseButton1Click:Connect(function() SelectTab(name) end)
end
SelectTab("Aimbot")

local yCursor = {}
local function NextPos(tab)
    yCursor[tab] = (yCursor[tab] or 0) + 28
    return UDim2.new(0, 8, 0, yCursor[tab] - 24)
end

local function Toggle(tab, label, configKey, callback)
    local btn = Instance.new("TextButton", tabFrames[tab])
    btn.Size = UDim2.new(1, -16, 0, 24)
    btn.Position = NextPos(tab)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    local function refresh()
        btn.Text = (UN.Config[configKey] and "[X] " or "[ ] ") .. label
        btn.TextColor3 = UN.Config[configKey] and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(200, 200, 200)
    end
    btn.MouseButton1Click:Connect(function()
        UN.Config[configKey] = not UN.Config[configKey]
        if callback then callback(UN.Config[configKey]) end
        refresh()
    end)
    refresh()
end

local function Slider(tab, label, min, max, configKey)
    local btn = Instance.new("TextButton", tabFrames[tab])
    btn.Size = UDim2.new(1, -16, 0, 24)
    btn.Position = NextPos(tab)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    local function refresh()
        btn.Text = label .. ": " .. UN.Config[configKey]
    end
    btn.MouseButton1Click:Connect(function()
        local cur = UN.Config[configKey]
        local nv = cur + math.max(1, math.floor((max - min) / 10))
        if nv > max then nv = min end
        UN.Config[configKey] = nv
        refresh()
    end)
    refresh()
end

--// Build controls
Toggle("Aimbot", "Enable Aimbot", "AimbotEnabled")
Toggle("Aimbot", "Team Check", "AimbotTeamCheck")
Slider("Aimbot", "FOV", 30, 500, "AimbotFOV")
Slider("Aimbot", "Smoothing", 1, 20, "AimbotSmoothing")

Toggle("ESP", "Enable ESP", "ESPEnabled")
Toggle("ESP", "Box", "ESPBox")
Toggle("ESP", "Name", "ESPName")
Toggle("ESP", "Health", "ESPHealth")
Toggle("ESP", "Tracer", "ESPTracer")

Toggle("Movement", "Speed Hack", "SpeedEnabled", function() UN.State.Modules.Movement:Apply() end)
Toggle("Movement", "Infinite Jump", "InfiniteJump")
Toggle("Movement", "NoClip", "NoClipEnabled")
Toggle("Movement", "Jump Power", "JumpEnabled", function() UN.State.Modules.Movement:Apply() end)
Slider("Movement", "Speed", 16, 100, "SpeedValue")
Slider("Movement", "Jump", 50, 200, "JumpValue")

Toggle("AntiCheat", "Enable Spoof", "AntiCheatEnabled", function(v) if v then UN.State.Modules.AntiCheat:Init() end end)
Toggle("AntiCheat", "Anti Kick", "AntiKick")
Toggle("AntiCheat", "Anti Screenshot", "AntiScreenshot")

--// Close / toggle
local closeBtn = Instance.new("TextButton", mainFrame)
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 2)
closeBtn.Text = "X"
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.BorderSizePixel = 0
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
local guiOpen = false
closeBtn.MouseButton1Click:Connect(function()
    guiOpen = not guiOpen
    mainFrame.Visible = guiOpen
end)
UN.TrackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
        guiOpen = not guiOpen
        mainFrame.Visible = guiOpen
    end
end))

--// Unload All button
local unloadBtn = Instance.new("TextButton", mainFrame)
unloadBtn.Size = UDim2.new(0, 110, 0, 28)
unloadBtn.Position = UDim2.new(1, -120, 1, -34)
unloadBtn.Text = "Unload All"
unloadBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
unloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
unloadBtn.BorderSizePixel = 0
Instance.new("UICorner", unloadBtn).CornerRadius = UDim.new(0, 6)
unloadBtn.MouseButton1Click:Connect(function() Shutdown() end)

function Shutdown()
    if UN.State.Unloaded then return end
    UN.State.Unloaded = true

    for _, conn in ipairs(UN.State.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    if UN.State.RenderConn then pcall(function() UN.State.RenderConn:Disconnect() end) end

    for k in pairs(UN.Config) do
        if k:find("Enabled") then UN.Config[k] = false end
    end

    if UN.State.Modules.ESP then pcall(function() UN.State.Modules.ESP:Cleanup() end) end
    pcall(function() screenGui:Destroy() end)
    print("[UN] Universal Hub unloaded.")
end

--// Main loop
UN.State.RenderConn = RunService.RenderStepped:Connect(function()
    if UN.State.Unloaded then return end
    local M = UN.State.Modules
    if M.Aimbot then M.Aimbot:Update() end
    if M.ESP then M.ESP:Update() end
    if M.Movement then M.Movement:Update() end
end)

print("[UN] Universal Hub loaded. Press RightControl to toggle GUI.")
