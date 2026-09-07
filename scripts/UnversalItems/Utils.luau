--[[
    SpongeHUB - Universal Library (Utils)
    Shared helpers for all UniversalItems modules.
    Load this first. Registers getgenv().UN
]]

local UN = getgenv().UN or {}
getgenv().UN = UN

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

UN.Players = Players
UN.RunService = RunService
UN.UserInputService = UserInputService
UN.Camera = Camera
UN.LocalPlayer = LocalPlayer

UN.Config = UN.Config or {
    AimbotEnabled = false,
    AimbotFOV = 150,
    AimbotSmoothing = 5,
    AimbotTeamCheck = false,
    AimbotTargetTeam = "All",      -- "All" | "Murderer" | "Sheriff" | "Innocent"
    AimbotMM2Mode = false,          -- when true, uses MM2 roles (Sheriff->Murderer etc.)
    AimbotShowFOV = true,           -- draw FOV circle
    AimbotSilentAim = false,        -- snap character face toward target
    AimbotTargetPart = "HumanoidRootPart",
    AimbotFOVColor = "255, 80, 80", -- "r, g, b" string
    AimbotKey = "None",             -- keybind to hold for aimbot (None = always on)

    ESPEnabled = false,
    ESPBox = true,
    ESPName = true,
    ESPHealth = true,
    ESPTracer = false,

    SpeedEnabled = false,
    SpeedValue = 32,
    JumpEnabled = false,
    JumpValue = 70,
    NoClipEnabled = false,
    InfiniteJump = false,

    AntiCheatEnabled = false,
    AntiKick = true,
    AntiScreenshot = true,
}

UN.State = UN.State or {
    Modules = {},
    Connections = {},
    RenderConn = nil,
    Unloaded = false,
    AimbotTarget = nil,
}

function UN.IsAlive(player)
    local char = player and player.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

function UN.GetCharacterParts(player)
    if not player or not player.Character then return nil end
    local char = player.Character
    return {
        Head = char:FindFirstChild("Head"),
        HumanoidRootPart = char:FindFirstChild("HumanoidRootPart"),
        Humanoid = char:FindFirstChildOfClass("Humanoid"),
        Torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"),
    }
end

function UN.WorldToScreen(pos)
    if not Camera then return Vector2.new(0, 0), false end
    local ok, screen = pcall(function()
        return Camera:WorldToViewportPoint(pos)
    end)
    if ok then
        return Vector2.new(screen.X, screen.Y), screen.Z > 0
    end
    return Vector2.new(0, 0), false
end

function UN.IsTeammate(a, b)
    local ok, res = pcall(function()
        return a.Team and b.Team and a.Team == b.Team
    end)
    return ok and res
end

function UN.RegisterModule(name, tbl)
    UN.State.Modules[name] = tbl
end

function UN.TrackConnection(conn)
    if conn then
        table.insert(UN.State.Connections, conn)
    end
    return conn
end

--// Unload system: modules register cleanup callbacks here; UI/Hub call UnloadAll
UN.UnloadCallbacks = UN.UnloadCallbacks or {}
UN.Unloaded = false

function UN.AddUnload(fn)
    if type(fn) == "function" then
        table.insert(UN.UnloadCallbacks, fn)
    end
end

function UN.UnloadAll()
    if UN.Unloaded then return end
    UN.Unloaded = true

    for _, conn in ipairs(UN.State.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    if UN.State.RenderConn then
        pcall(function() UN.State.RenderConn:Disconnect() end)
    end

    for _, cb in ipairs(UN.UnloadCallbacks) do
        pcall(cb)
    end

    --// Reset all toggle-style config keys
    for k, v in pairs(UN.Config) do
        if type(v) == "boolean" then UN.Config[k] = false end
    end

    pcall(function()
        if UN.State.Modules.ESP then UN.State.Modules.ESP:Cleanup() end
    end)
    print("[UN] Unloaded.")
end

print("[UN] Universal library loaded.")
