--// SpongeHUB - Murder Mystery 2 Script
--// Anti-Cheat Spoof | Role-Based Aimbot | ESP
--// Uses SpongeHUB Universal Items modules (see scripts/UnversalItems).
--// The loader pre-processes the #include directives below and inlines them.

--#include Utils.luau
--#include UI.luau
--#include Aimbot.luau
--#include ESP.luau
--#include PlayerMovement.luau
--#include AntiCheat.luau

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--// Configuration
local Config = {
    -- Aimbot
    AimbotEnabled = false,
    AimbotFOV = 120,
    AimbotSmoothing = 2,
    AimbotTargetPart = "Head",
    AimbotTeamCheck = true,
    SilentAimEnabled = false,

    -- ESP
    ESPEnabled = false,
    ESPMurdererColor = Color3.fromRGB(255, 0, 0),
    ESPSheriffColor = Color3.fromRGB(0, 100, 255),
    ESPInnocentColor = Color3.fromRGB(0, 255, 0),
    ESPTracerEnabled = false,
    ESPBoxEnabled = true,
    ESPNameEnabled = true,
    ESPRoleEnabled = true,
    ESPDistanceEnabled = true,
    ESPHealthEnabled = true,

    -- Anti-Cheat
    AntiCheatSpoof = true,
    SpoofName = true,
    SpoofPosition = false,
    AntiKick = true,
    AntiScreenshot = true,

    -- Misc
    NoClipEnabled = false,
    SpeedHack = false,
    CustomSpeed = 16,
    JumpPower = 50,
    InfiniteJump = false,
    FlickKnife = false,
}

--// State
local State = {
    LocalRole = "Innocent",
    Murderer = nil,
    Sheriff = nil,
    Detective = nil,
    AimbotTarget = nil,
    FOVCircle = nil,
    ESPObjects = {},
    Connections = {},
    Unloaded = false,
    Detected = false,
}

--// Services References
local Remotes = {}

--// ============================================
--// UTILITY FUNCTIONS
--// ============================================

local function CreateInstance(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            inst[k] = v
        end
    end
    if props and props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local RoleCache = {}
local LastRoleRefresh = 0

local function GetRole(player)
    if not player then return "Innocent" end
    local cached = RoleCache[player.Name]
    if cached then return cached end

    local char = player.Character
    if not char then return "Innocent" end

    --// Fallback heuristic: murderer typically holds a knife tool, sheriff a gun tool
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") then
            local n = tostring(item.Name):lower()
            if n:find("knife") or n:find("kni") or n:find("dagger") or n:find("blade") or n == "murderer" then
                RoleCache[player.Name] = "Murderer"
                return "Murderer"
            end
            if n:find("gun") or n:find("revolver") or n:find("pistol") or n:find("smith") then
                RoleCache[player.Name] = "Sheriff"
                return "Sheriff"
            end
        end
        if item:IsA("BasePart") then
            local n = tostring(item.Name):lower()
            if n:find("knife") or n:find("dagger") then
                RoleCache[player.Name] = "Murderer"
                return "Murderer"
            end
        end
    end

    return "Innocent"
end

local PlayerDataRemote = nil

local function FindPlayerDataRemote()
    if PlayerDataRemote and PlayerDataRemote.Parent then
        return PlayerDataRemote
    end
    local direct = game.ReplicatedStorage:FindFirstChild("GetPlayerData")
    if direct and direct:IsA("RemoteFunction") then
        PlayerDataRemote = direct
        return PlayerDataRemote
    end
    for _, child in ipairs(game.ReplicatedStorage:GetDescendants()) do
        if child.Name == "GetPlayerData" and child:IsA("RemoteFunction") then
            PlayerDataRemote = child
            return PlayerDataRemote
        end
    end
    return nil
end

local function RefreshRolesFromRemote()
    local remote = FindPlayerDataRemote()
    if not remote then return false end
    local ok, data = pcall(function()
        return remote:InvokeServer()
    end)
    if not ok or type(data) ~= "table" then return false end
    local changed = false
    for name, info in pairs(data) do
        if type(name) == "string" and type(info) == "table" and info.Role then
            local roleStr = tostring(info.Role):lower()
            local role = "Innocent"
            if roleStr:find("murder") then
                role = "Murderer"
            elseif roleStr:find("sheriff") or roleStr:find("hero") then
                role = "Sheriff"
            end
            if RoleCache[name] ~= role then
                RoleCache[name] = role
                changed = true
            end
        end
    end
    return changed
end

local function ScanRoles()
    --// Throttle the expensive remote invoke
    local now = os.clock()
    if now - LastRoleRefresh > 0.75 then
        LastRoleRefresh = now
        RefreshRolesFromRemote()
    end

    State.LocalRole = GetRole(LocalPlayer)
    State.Murderer = nil
    State.Sheriff = nil

    --// Feed roles into the universal Aimbot (MM2 mode)
    local UN = getgenv().UN
    if UN then
        UN.State.MM2Roles = UN.State.MM2Roles or {}
        for k in pairs(UN.State.MM2Roles) do UN.State.MM2Roles[k] = nil end
        UN.State.MM2Roles[LocalPlayer.Name] = State.LocalRole
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local role = GetRole(player)
            if role == "Murderer" then
                State.Murderer = player
            elseif role == "Sheriff" then
                State.Sheriff = player
            end
            if UN then UN.State.MM2Roles[player.Name] = role end
        end
    end

    --// Enable universal MM2 aimbot behavior
    if UN then
        UN.Config.AimbotMM2Mode = true
    end
end

local function GetCharacterParts(player)
    if not player or not player.Character then return nil end
    local char = player.Character
    return {
        Head = char:FindFirstChild("Head"),
        HumanoidRootPart = char:FindFirstChild("HumanoidRootPart"),
        Humanoid = char:FindFirstChildOfClass("Humanoid"),
        Torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"),
    }
end

local function IsAlive(player)
    local parts = GetCharacterParts(player)
    if not parts or not parts.Humanoid then return false end
    return parts.Humanoid.Health > 0
end

local function DistanceTo(pos)
    local localChar = LocalPlayer.Character
    if not localChar then return math.huge end
    local hrp = localChar:FindFirstChild("HumanoidRootPart")
    if not hrp then return math.huge end
    return (hrp.Position - pos).Magnitude
end

local function WorldToScreen(pos)
    local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function DrawCircle()
    local circle = Drawing and Drawing.new("Circle")
    if circle then
        circle.Visible = false
        circle.Radius = Config.AimbotFOV
        circle.Color = Color3.fromRGB(255, 255, 255)
        circle.Thickness = 1
        circle.Filled = false
        circle.Transparency = 0.5
        circle.NumSides = 60
    end
    return circle
end

--// ============================================
--// ANTI-CHEAT SPOOF
--// ============================================

local AntiCheat = {}

function AntiCheat.Init()
    if not Config.AntiCheatSpoof then return end

    --// Hook remote fires to randomize timing
    local oldFire
    pcall(function()
        oldFire = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if Config.AntiKick and method == "Kick" then
                warn("[SpongeHUB] Kick attempt blocked")
                return nil
            end

            if Config.AntiScreenshot and (
                method:lower():find("screenshot")
                or tostring(self):lower():find("screenshot")
            ) then
                return nil
            end

            return oldFire(self, ...)
        end)
    end)

    --// Spoof player name if needed
    if Config.SpoofName then
        pcall(function()
            local namecall
            namecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if method == "GetPlayers" or method == "FindFirstChild" then
                    return oldFire(self, ...)
                end
                return oldFire(self, ...)
            end)
        end)
    end

    --// Random delay to avoid pattern detection
    task.spawn(function()
        while Config.AntiCheatSpoof do
            task.wait(math.random(30, 90))
            pcall(function()
                LocalPlayer:SetAttribute("Heartbeat", tick())
            end)
        end
    end)

    --// Prevent character resetting suspiciously
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                    if humanoid.WalkSpeed ~= 16 and not Config.SpeedHack then
                        task.wait(0.1)
                        humanoid.WalkSpeed = 16
                    end
                end)
            end
        end
    end)

    --// Method name obfuscation
    pcall(function()
        local mt = getrawmetatable(game)
        if mt and mt.__namecall then
            local oldNC = mt.__namecall
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}

                --// Block suspicious remote calls
                if Config.AntiCheatSpoof then
                    if method == "FireServer" then
                        local remoteName = tostring(self.Name):lower()
                        if remoteName:find("ban") or remoteName:find("kick") or remoteName:find("report") then
                            return nil
                        end
                    end
                end

                return oldNC(self, ...)
            end)
        end
    end)

    print("[SpongeHUB] Anti-Cheat Spoof initialized")
end

--// ============================================
--// ESP SYSTEM
--// ============================================

local ESP = {}

function ESP:GetRoleColor(player)
    local role = GetRole(player)
    if role == "Murderer" then
        return Config.ESPMurdererColor, role
    elseif role == "Sheriff" then
        return Config.ESPSheriffColor, role
    else
        return Config.ESPInnocentColor, role
    end
end

function ESP:CreateDrawing(className, props)
    local success, obj = pcall(function()
        return Drawing.new(className)
    end)
    if not success or not obj then return nil end
    for k, v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    return obj
end

function ESP:CreateESPForPlayer(player)
    if player == LocalPlayer then return end

    local espGroup = {
        BoxOutline = nil,
        Box = nil,
        Name = nil,
        Role = nil,
        Distance = nil,
        HealthBar = nil,
        HealthBarOutline = nil,
        Tracer = nil,
        TracerOutline = nil,
        Arrow = nil,
        Player = player,
    }

    --// Box ESP
    if Config.ESPBoxEnabled then
        espGroup.BoxOutline = self:CreateDrawing("Square", {
            Thickness = 3,
            Color = Color3.fromRGB(0, 0, 0),
            Filled = false,
            Transparency = 0.5,
        })
        espGroup.Box = self:CreateDrawing("Square", {
            Thickness = 1,
            Filled = false,
            Transparency = 1,
        })
    end

    --// Name ESP
    if Config.ESPNameEnabled then
        espGroup.Name = self:CreateDrawing("Text", {
            Size = 14,
            Color = Color3.fromRGB(255, 255, 255),
            Center = true,
            Outline = true,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Transparency = 1,
        })
    end

    --// Role ESP
    if Config.ESPRoleEnabled then
        espGroup.Role = self:CreateDrawing("Text", {
            Size = 12,
            Color = Color3.fromRGB(255, 255, 255),
            Center = true,
            Outline = true,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Transparency = 1,
        })
    end

    --// Distance ESP
    if Config.ESPDistanceEnabled then
        espGroup.Distance = self:CreateDrawing("Text", {
            Size = 11,
            Color = Color3.fromRGB(200, 200, 200),
            Center = true,
            Outline = true,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Transparency = 1,
        })
    end

    --// Health Bar
    if Config.ESPHealthEnabled then
        espGroup.HealthBarOutline = self:CreateDrawing("Line", {
            Thickness = 3,
            Color = Color3.fromRGB(0, 0, 0),
            Transparency = 0.6,
        })
        espGroup.HealthBar = self:CreateDrawing("Line", {
            Thickness = 1,
            Color = Color3.fromRGB(0, 255, 0),
            Transparency = 1,
        })
    end

    --// Tracer
    if Config.ESPTracerEnabled then
        espGroup.TracerOutline = self:CreateDrawing("Line", {
            Thickness = 3,
            Color = Color3.fromRGB(0, 0, 0),
            Transparency = 0.5,
        })
        espGroup.Tracer = self:CreateDrawing("Line", {
            Thickness = 1,
            Transparency = 1,
        })
    end

    State.ESPObjects[player] = espGroup
end

function ESP:RemoveESPForPlayer(player)
    local espGroup = State.ESPObjects[player]
    if espGroup then
        for k, v in pairs(espGroup) do
            if typeof(v) == "Drawing" then
                pcall(function() v:Remove() end)
            end
        end
        State.ESPObjects[player] = nil
    end
end

function ESP:UpdateESP()
    if not Config.ESPEnabled then return end

    local localChar = LocalPlayer.Character
    if not localChar then return end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end
    local localHumanoid = localChar:FindFirstChildOfClass("Humanoid")
    if not localHumanoid then return end

    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)

    for player, espGroup in pairs(State.ESPObjects) do
        if player.Parent == Players and player ~= LocalPlayer then
            local char = player.Character
            local parts = GetCharacterParts(player)

            if char and parts and parts.Humanoid and parts.HumanoidRootPart and parts.Head then
                if IsAlive(player) then
                    local hrp = parts.HumanoidRootPart
                    local head = parts.Head
                    local humanoid = parts.Humanoid
                    local pos = hrp.Position

                    local color, role = self:GetRoleColor(player)

                    --// Distance
                    local dist = (localRoot.Position - pos).Magnitude

                    --// Box dimensions
                    local topPos = head.Position + Vector3.new(0, 0.5, 0)
                    local bottomPos = pos - Vector3.new(0, 3, 0)

                    local topScreen, topOnScreen = WorldToScreen(topPos)
                    local bottomScreen, bottomOnScreen = WorldToScreen(bottomPos)

                    local headScreen = WorldToScreen(head.Position + Vector3.new(0, 1, 0))
                    local feetScreen = WorldToScreen(pos - Vector3.new(0, 3, 0))

                    if topOnScreen and bottomOnScreen then
                        local boxHeight = math.abs(topScreen.Y - bottomScreen.Y)
                        local boxWidth = boxHeight * 0.55
                        local boxLeft = topScreen.X - boxWidth / 2
                        local boxTop = topScreen.Y

                        --// Box
                        if espGroup.Box then
                            espGroup.Box.Position = Vector2.new(boxLeft, boxTop)
                            espGroup.Box.Size = Vector2.new(boxWidth, boxHeight)
                            espGroup.Box.Color = color
                            espGroup.Box.Visible = true
                        end
                        if espGroup.BoxOutline then
                            espGroup.BoxOutline.Position = Vector2.new(boxLeft - 1, boxTop - 1)
                            espGroup.BoxOutline.Size = Vector2.new(boxWidth + 2, boxHeight + 2)
                            espGroup.BoxOutline.Visible = true
                        end

                        --// Name
                        if espGroup.Name then
                            espGroup.Name.Position = Vector2.new(topScreen.X, boxTop - 18)
                            espGroup.Name.Text = player.DisplayName
                            espGroup.Name.Color = Color3.fromRGB(255, 255, 255)
                            espGroup.Name.Visible = true
                        end

                        --// Role
                        if espGroup.Role then
                            espGroup.Role.Position = Vector2.new(topScreen.X, boxTop - 34)
                            if role == "Murderer" then
                                espGroup.Role.Text = "[ MURDERER ]"
                                espGroup.Role.Color = Config.ESPMurdererColor
                            elseif role == "Sheriff" then
                                espGroup.Role.Text = "[ SHERIFF ]"
                                espGroup.Role.Color = Config.ESPSheriffColor
                            else
                                espGroup.Role.Text = "[ INNOCENT ]"
                                espGroup.Role.Color = Config.ESPInnocentColor
                            end
                            espGroup.Role.Visible = true
                        end

                        --// Distance
                        if espGroup.Distance then
                            espGroup.Distance.Position = Vector2.new(topScreen.X, boxTop + boxHeight + 4)
                            espGroup.Distance.Text = string.format("[%dm]", math.floor(dist))
                            espGroup.Distance.Visible = true
                        end

                        --// Health Bar
                        if espGroup.HealthBar and espGroup.HealthBarOutline then
                            local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                            local hbX = boxLeft - 6
                            local hbTop = boxTop
                            local hbHeight = boxHeight

                            espGroup.HealthBarOutline.From = Vector2.new(hbX, hbTop)
                            espGroup.HealthBarOutline.To = Vector2.new(hbX, hbTop + hbHeight)
                            espGroup.HealthBarOutline.Visible = true

                            espGroup.HealthBar.From = Vector2.new(hbX, hbTop + hbHeight * (1 - healthPercent))
                            espGroup.HealthBar.To = Vector2.new(hbX, hbTop + hbHeight)
                            espGroup.HealthBar.Color = Color3.fromRGB(
                                255 * (1 - healthPercent),
                                255 * healthPercent,
                                0
                            )
                            espGroup.HealthBar.Visible = true
                        end

                        --// Tracer
                        if espGroup.Tracer and espGroup.TracerOutline then
                            local bottomLine = Vector2.new(
                                Camera.ViewportSize.X / 2,
                                Camera.ViewportSize.Y
                            )
                            espGroup.TracerOutline.From = bottomLine
                            espGroup.TracerOutline.To = Vector2.new(topScreen.X, boxTop + boxHeight)
                            espGroup.TracerOutline.Visible = true

                            espGroup.Tracer.From = bottomLine
                            espGroup.Tracer.To = Vector2.new(topScreen.X, boxTop + boxHeight)
                            espGroup.Tracer.Color = color
                            espGroup.Tracer.Visible = true
                        end
                    else
                        self:SetESPVisibility(espGroup, false)
                    end
                else
                    self:SetESPVisibility(espGroup, false)
                end
            else
                self:SetESPVisibility(espGroup, false)
            end
        else
            self:RemoveESPForPlayer(player)
        end
    end
end

function ESP:SetESPVisibility(espGroup, visible)
    for k, v in pairs(espGroup) do
        if typeof(v) == "Drawing" then
            pcall(function() v.Visible = visible end)
        end
    end
end

function ESP:Cleanup()
    for player, espGroup in pairs(State.ESPObjects) do
        self:RemoveESPForPlayer(player)
    end
    State.ESPObjects = {}
end

--// ============================================
--// AIMBOT SYSTEM
--// ============================================

local Aimbot = {}

function Aimbot:GetClosestPlayer()
    local closestPlayer = nil
    local closestDist = Config.AimbotFOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            local parts = GetCharacterParts(player)
            if parts and parts[Config.AimbotTargetPart] then
                local targetPart = parts[Config.AimbotTargetPart]
                local screenPos, onScreen = WorldToScreen(targetPart.Position)

                if onScreen then
                    local dist = (mousePos - screenPos).Magnitude
                    if dist < closestDist then
                        --// Team check
                        local teamOk = true
                        if Config.AimbotTeamCheck then
                            local localRole = GetRole(LocalPlayer)
                            local targetRole = GetRole(player)
                            if localRole == "Sheriff" then
                                teamOk = (targetRole == "Murderer")
                            elseif localRole ~= "Murderer" then
                                teamOk = false --// Innocent shouldn't aimbot
                            end
                        end

                        if teamOk then
                            closestDist = dist
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end

    return closestPlayer
end

function Aimbot:Update()
    if not Config.AimbotEnabled then
        State.AimbotTarget = nil
        return
    end

    local localRole = GetRole(LocalPlayer)

    --// Only allow aimbot for Murderer or Sheriff
    if localRole ~= "Murderer" and localRole ~= "Sheriff" then
        State.AimbotTarget = nil
        return
    end

    local target = self:GetClosestPlayer()
    State.AimbotTarget = target

    if target and IsAlive(target) then
        local parts = GetCharacterParts(target)
        if parts and parts[Config.AimbotTargetPart] then
            local targetPart = parts[Config.AimbotTargetPart]

            if Config.SilentAimEnabled then
                --// Silent Aim - snap face toward target (helps gun/knife hit)
                self:RedirectProjectile(target)
            end

            --// Aim the CAMERA from its own position (fix: was using HRP as origin)
            local aimPos = targetPart.Position
            local camPos = Camera.CFrame.Position
            local direction = (aimPos - camPos).Unit
            local desired = CFrame.new(camPos, camPos + direction)
            local smooth = math.clamp(Config.AimbotSmoothing, 0.1, 20)
            Camera.CFrame = Camera.CFrame:Lerp(desired, 1 / (smooth * 2))

            --// Also rotate the character root flat toward the target (melee/throw aim)
            local localChar = LocalPlayer.Character
            if localChar then
                local localRoot = localChar:FindFirstChild("HumanoidRootPart")
                if localRoot then
                    local delta = aimPos - localRoot.Position
                    local flat = Vector3.new(delta.X, 0, delta.Z)
                    if flat.Magnitude > 0.001 then
                        local currentFlat = CFrame.new(localRoot.Position, localRoot.Position + Vector3.new(localRoot.CFrame.LookVector.X, 0, localRoot.CFrame.LookVector.Z))
                        local targetFlat = CFrame.new(localRoot.Position, localRoot.Position + flat.Unit)
                        localRoot.CFrame = currentFlat:Lerp(targetFlat, 1 / (smooth * 3))
                    end
                end
            end
        end
    end
end

function Aimbot:RedirectProjectile(target)
    pcall(function()
        local localChar = LocalPlayer.Character
        if not localChar then return end

        local targetParts = GetCharacterParts(target)
        if not targetParts or not targetParts.Head then return end

        --// Snap the character flat toward the target (no tilt, keeps movement smooth)
        local hrp = localChar:FindFirstChild("HumanoidRootPart")
        if hrp then
            local delta = targetParts.Head.Position - hrp.Position
            local flat = Vector3.new(delta.X, 0, delta.Z)
            if flat.Magnitude > 0.001 then
                hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + flat.Unit)
            end
        end
    end)
end

function Aimbot:UpdateFOVCircle()
    if Config.AimbotEnabled and State.FOVCircle then
        local mousePos = UserInputService:GetMouseLocation()
        State.FOVCircle.Position = mousePos
        State.FOVCircle.Radius = Config.AimbotFOV
        State.FOVCircle.Visible = true
    elseif State.FOVCircle then
        State.FOVCircle.Visible = false
    end
end

--// ============================================
--// FICK KNIFE (MURDERER)
--// ============================================

local FlickKnife = {}

function FlickKnife:ThrowAtTarget(target)
    if GetRole(LocalPlayer) ~= "Murderer" then return end
    if not IsAlive(target) then return end

    pcall(function()
        local localChar = LocalPlayer.Character
        if not localChar then return end

        local tool = localChar:FindFirstChildOfClass("Tool")
        if not tool then return end

        local targetParts = GetCharacterParts(target)
        if not targetParts or not targetParts.HumanoidRootPart then return end

        local hrp = localChar:FindFirstChild("HumanoidRootPart")
        if hrp then
            local targetPos = targetParts.HumanoidRootPart.Position
            local direction = (targetPos - hrp.Position).Unit

            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + direction)

            --// Activate tool
            tool:Activate()
        end
    end)
end

--// ============================================
--// MOVEMENT MODIFICATIONS
--// ============================================

local Movement = {}

function Movement:ApplySpeed()
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = Config.SpeedHack and Config.CustomSpeed or 16
                humanoid.JumpPower = Config.JumpPower
                humanoid.UseJumpPower = true
            end
        end
    end)
end

function Movement:EnableNoClip()
    if Config.NoClipEnabled then
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end

function Movement:InfiniteJump()
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end)
end

--// ============================================
--// GUI
--// ============================================

local GUI = {}

function GUI:Create()
    --// Destroy old GUI if exists
    local oldGui = LocalPlayer.PlayerGui:FindFirstChild("SpongeHUB_GUI")
    if oldGui then oldGui:Destroy() end

    local screenGui = CreateInstance("ScreenGui", {
        Name = "SpongeHUB_GUI",
        Parent = LocalPlayer.PlayerGui,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    --// Main Frame
    local mainFrame = CreateInstance("Frame", {
        Name = "MainFrame",
        Parent = screenGui,
        Size = UDim2.new(0, 340, 0, 500),
        Position = UDim2.new(0.5, -170, 0.5, -250),
        BackgroundColor3 = Color3.fromRGB(20, 20, 30),
        BorderSizePixel = 0,
        Active = true,
        Draggable = true,
    })

    CreateInstance("UICorner", {CornerRadius = UDim.new(0, 8), Parent = mainFrame})
    CreateInstance("UIStroke", {
        Color = Color3.fromRGB(100, 0, 255),
        Thickness = 2,
        Parent = mainFrame,
    })

    --// Title
    CreateInstance("TextLabel", {
        Name = "Title",
        Parent = mainFrame,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Color3.fromRGB(15, 15, 25),
        Text = "SpongeHUB - MM2",
        TextColor3 = Color3.fromRGB(150, 80, 255),
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
    })

    CreateInstance("UICorner", {CornerRadius = UDim.new(0, 8), Parent = mainFrame.Title})

    --// Role Indicator
    local roleLabel = CreateInstance("TextLabel", {
        Name = "RoleLabel",
        Parent = mainFrame,
        Size = UDim2.new(1, -20, 0, 25),
        Position = UDim2.new(0, 10, 0, 48),
        BackgroundTransparency = 1,
        Text = "Role: " .. State.LocalRole,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    --// Tabs
    local tabs = {"Aimbot", "ESP", "Anti-Cheat", "Misc"}
    local tabFrames = {}
    local tabButtons = {}

    local tabHolder = CreateInstance("Frame", {
        Name = "TabHolder",
        Parent = mainFrame,
        Size = UDim2.new(1, -10, 0, 30),
        Position = UDim2.new(0, 5, 0, 78),
        BackgroundTransparency = 1,
    })

    CreateInstance("UIListLayout", {
        Parent = tabHolder,
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 2),
    })

    for i, tabName in ipairs(tabs) do
        local tabBtn = CreateInstance("TextButton", {
            Name = tabName,
            Parent = tabHolder,
            Size = UDim2.new(1 / #tabs, -2, 1, 0),
            BackgroundColor3 = Color3.fromRGB(40, 40, 60),
            Text = tabName,
            TextColor3 = Color3.fromRGB(180, 180, 180),
            TextSize = 11,
            Font = Enum.Font.Gotham,
            BorderSizePixel = 0,
        })
        CreateInstance("UICorner", {CornerRadius = UDim.new(0, 4), Parent = tabBtn})
        tabButtons[tabName] = tabBtn

        local contentFrame = CreateInstance("ScrollingFrame", {
            Name = tabName .. "Content",
            Parent = mainFrame,
            Size = UDim2.new(1, -10, 1, -120),
            Position = UDim2.new(0, 5, 0, 112),
            BackgroundTransparency = 1,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Color3.fromRGB(100, 0, 255),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = i == 1,
        })
        CreateInstance("UIListLayout", {
            Parent = contentFrame,
            Padding = UDim.new(0, 4),
        })
        tabFrames[tabName] = contentFrame
    end

    --// Tab switching
    local selectedTab = "Aimbot"
    for tabName, tabBtn in pairs(tabButtons) do
        tabBtn.MouseButton1Click:Connect(function()
            selectedTab = tabName
            for name, frame in pairs(tabFrames) do
                frame.Visible = (name == tabName)
            end
            for name, btn in pairs(tabButtons) do
                if name == tabName then
                    btn.BackgroundColor3 = Color3.fromRGB(100, 0, 255)
                    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                else
                    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
                    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
                end
            end
        end)
    end
    --// Default tab highlight
    tabButtons["Aimbot"].BackgroundColor3 = Color3.fromRGB(100, 0, 255)
    tabButtons["Aimbot"].TextColor3 = Color3.fromRGB(255, 255, 255)

    --// Toggle/Slider helper functions
    local function CreateToggle(parent, text, configKey, callback)
        local toggleFrame = CreateInstance("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
        })

        CreateInstance("TextLabel", {
            Parent = toggleFrame,
            Size = UDim2.new(0.7, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Color3.fromRGB(220, 220, 220),
            TextSize = 12,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        local toggleBtn = CreateInstance("TextButton", {
            Parent = toggleFrame,
            Size = UDim2.new(0, 50, 0, 22),
            Position = UDim2.new(0.75, 0, 0.5, -11),
            BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 180, 80) or Color3.fromRGB(80, 30, 30),
            Text = Config[configKey] and "ON" or "OFF",
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
        })
        CreateInstance("UICorner", {CornerRadius = UDim.new(0, 4), Parent = toggleBtn})

        toggleBtn.MouseButton1Click:Connect(function()
            Config[configKey] = not Config[configKey]
            toggleBtn.BackgroundColor3 = Config[configKey]
                and Color3.fromRGB(0, 180, 80)
                or Color3.fromRGB(80, 30, 30)
            toggleBtn.Text = Config[configKey] and "ON" or "OFF"
            if callback then callback(Config[configKey]) end
        end)

        return toggleBtn
    end

    local function CreateSlider(parent, text, min, max, default, callback)
        local sliderFrame = CreateInstance("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
        })

        local label = CreateInstance("TextLabel", {
            Parent = sliderFrame,
            Size = UDim2.new(0.6, 0, 0, 18),
            BackgroundTransparency = 1,
            Text = text .. ": " .. default,
            TextColor3 = Color3.fromRGB(220, 220, 220),
            TextSize = 12,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        local sliderBar = CreateInstance("Frame", {
            Parent = sliderFrame,
            Size = UDim2.new(0.9, 0, 0, 6),
            Position = UDim2.new(0.05, 0, 0, 22),
            BackgroundColor3 = Color3.fromRGB(50, 50, 70),
            BorderSizePixel = 0,
        })
        CreateInstance("UICorner", {CornerRadius = UDim.new(0, 3), Parent = sliderBar})

        local fillPercent = (default - min) / (max - min)
        local fill = CreateInstance("Frame", {
            Parent = sliderBar,
            Size = UDim2.new(fillPercent, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(100, 0, 255),
            BorderSizePixel = 0,
        })
        CreateInstance("UICorner", {CornerRadius = UDim.new(0, 3), Parent = fill})

        local knob = CreateInstance("Frame", {
            Parent = sliderBar,
            Size = UDim2.new(0, 14, 0, 14),
            Position = UDim2.new(fillPercent, -7, 0.5, -7),
            BackgroundColor3 = Color3.fromRGB(150, 80, 255),
            BorderSizePixel = 0,
        })
        CreateInstance("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})

        local dragging = false
        sliderBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (
                input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            ) then
                local relX = math.clamp(
                    (input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X,
                    0, 1
                )
                local value = math.floor(min + (max - min) * relX)
                fill.Size = UDim2.new(relX, 0, 1, 0)
                knob.Position = UDim2.new(relX, -7, 0.5, -7)
                label.Text = text .. ": " .. value
                if callback then callback(value) end
            end
        end)
    end

    --// ==================
    --// AIMBOT TAB
    --// ==================
    local aimbotContent = tabFrames["Aimbot"]

    CreateToggle(aimbotContent, "Enable Aimbot", "AimbotEnabled")
    CreateToggle(aimbotContent, "Silent Aim", "SilentAimEnabled")
    CreateToggle(aimbotContent, "Team Check", "AimbotTeamCheck")
    CreateToggle(aimbotContent, "Flick Knife (Murderer)", "FlickKnife")
    CreateSlider(aimbotContent, "FOV", 30, 500, Config.AimbotFOV, function(v) Config.AimbotFOV = v end)
    CreateSlider(aimbotContent, "Smoothing", 1, 20, Config.AimbotSmoothing, function(v) Config.AimbotSmoothing = v end)

    --// ==================
    --// ESP TAB
    --// ==================
    local espContent = tabFrames["ESP"]

    CreateToggle(espContent, "Enable ESP", "ESPEnabled")
    CreateToggle(espContent, "Box ESP", "ESPBoxEnabled")
    CreateToggle(espContent, "Name ESP", "ESPNameEnabled")
    CreateToggle(espContent, "Role ESP", "ESPRoleEnabled")
    CreateToggle(espContent, "Distance ESP", "ESPDistanceEnabled")
    CreateToggle(espContent, "Health Bar", "ESPHealthEnabled")
    CreateToggle(espContent, "Tracer", "ESPTracerEnabled")

    --// ==================
    --// ANTI-CHEAT TAB
    --// ==================
    local antiCheatContent = tabFrames["Anti-Cheat"]

    CreateToggle(antiCheatContent, "Enable Anti-Cheat Spoof", "AntiCheatSpoof")
    CreateToggle(antiCheatContent, "Spoof Name", "SpoofName")
    CreateToggle(antiCheatContent, "Anti Kick", "AntiKick")
    CreateToggle(antiCheatContent, "Anti Screenshot", "AntiScreenshot")
    CreateToggle(antiCheatContent, "Spoof Position", "SpoofPosition")

    --// ==================
    --// MISC TAB
    --// ==================
    local miscContent = tabFrames["Misc"]

    CreateToggle(miscContent, "Speed Hack", "SpeedHack", function()
        Movement:ApplySpeed()
    end)
    CreateToggle(miscContent, "NoClip", "NoClipEnabled")
    CreateToggle(miscContent, "Infinite Jump", "InfiniteJump")
    CreateSlider(miscContent, "Speed", 16, 100, Config.CustomSpeed, function(v)
        Config.CustomSpeed = v
        Movement:ApplySpeed()
    end)
    CreateSlider(miscContent, "Jump Power", 50, 200, Config.JumpPower, function(v)
        Config.JumpPower = v
        Movement:ApplySpeed()
    end)

    --// Close button
    local closeBtn = CreateInstance("TextButton", {
        Name = "CloseBtn",
        Parent = mainFrame,
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -35, 0, 5),
        BackgroundColor3 = Color3.fromRGB(180, 40, 40),
        Text = "X",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
    })
    CreateInstance("UICorner", {CornerRadius = UDim.new(0, 15), Parent = closeBtn})

    local guiOpen = true
    closeBtn.MouseButton1Click:Connect(function()
        guiOpen = not guiOpen
        mainFrame.Visible = guiOpen
    end)

    --// Toggle GUI with RightControl
    table.insert(State.Connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
            guiOpen = not guiOpen
            mainFrame.Visible = guiOpen
        end
    end))

    --// Open the universal SpongeHUB UI (modules, target-team, unload all)
    local UN = getgenv().UN
    local uniBtn = CreateInstance("TextButton", {
        Name = "UniversalUIBtn",
        Parent = mainFrame,
        Size = UDim2.new(0, 120, 0, 28),
        Position = UDim2.new(0, 8, 1, -38),
        BackgroundColor3 = Color3.fromRGB(40, 60, 110),
        Text = "Universal UI",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
    })
    CreateInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = uniBtn})
    uniBtn.MouseButton1Click:Connect(function()
        if UN and UN.State.Modules.UI then
            UN.State.Modules.UI:Create("SpongeHUB Universal")
            UN.State.Modules.UI:Toggle()
        end
    end)

    if UN and UN.State.Modules.UI then
        UN.State.Modules.UI:Create("SpongeHUB Universal")
        --// MM2-specific panel inside the universal UI
        local mm2Mod = UN.State.Modules.UI:Add_Module("MM2")
        mm2Mod:Label("Roles update automatically.")
        mm2Mod:Button("Refresh Roles", function() ScanRoles() end)
    end

    State.Gui = screenGui
    State.RoleLabel = roleLabel

    --// Unload All button
    local unloadBtn = CreateInstance("TextButton", {
        Name = "UnloadAllBtn",
        Parent = mainFrame,
        Size = UDim2.new(0, 110, 0, 30),
        Position = UDim2.new(1, -150, 1, -38),
        BackgroundColor3 = Color3.fromRGB(120, 30, 30),
        Text = "Unload All",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
    })
    CreateInstance("UICorner", {CornerRadius = UDim.new(0, 6), Parent = unloadBtn})
    unloadBtn.MouseButton1Click:Connect(function()
        Shutdown()
    end)

    --// Global unload: stop loops, disconnect, clear ESP, destroy GUI
    function Shutdown()
        if State.Unloaded then return end
        State.Unloaded = true

        for _, conn in ipairs(State.Connections or {}) do
            pcall(function() conn:Disconnect() end)
        end
        if State.RenderConn then pcall(function() State.RenderConn:Disconnect() end) end

        --// Reset toggles to safe state
        Config.AimbotEnabled = false
        Config.ESPEnabled = false
        Config.NoClipEnabled = false
        Config.SilentAimEnabled = false
        Config.FlickKnife = false
        Config.AntiCheatSpoof = false

        pcall(function() ESP:Cleanup() end)
        if State.FOVCircle then pcall(function() State.FOVCircle:Remove() end) end
        if State.Gui then pcall(function() State.Gui:Destroy() end) end

        print("[SpongeHUB] Script unloaded.")
    end

    State.Shutdown = Shutdown
end

--// ============================================
--// MAIN LOOP
--// ============================================

local function Init()
    GUI:Create()
    AntiCheat.Init()

    --// FOV Circle
    State.FOVCircle = DrawCircle()

    --// Scan roles initially
    ScanRoles()

    --// Player connections
    table.insert(State.Connections, Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            task.wait(2)
            ScanRoles()
        end)
        task.spawn(function()
            task.wait(5)
            ScanRoles()
        end)
    end))

    table.insert(State.Connections, Players.PlayerRemoving:Connect(function(player)
        State.ESPObjects[player] = nil
    end))

    table.insert(State.Connections, LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(2)
        ScanRoles()
        Movement:ApplySpeed()

        --// Re-apply NoClip
        if Config.NoClipEnabled then
            task.spawn(function()
                while Config.NoClipEnabled do
                    Movement:EnableNoClip()
                    RunService.Heartbeat:Wait()
                end
            end)
        end
    end))

    --// ESP is handled by the universal SpongeHUB ESP module now.

    --// Main Render Loop
    local lastFlick = 0

    State.RenderConn = RunService.RenderStepped:Connect(function()
        if State.Unloaded then return end

        --// Update role indicator
        if State.RoleLabel then
            ScanRoles()
            local role = State.LocalRole
            local roleColor = Config.ESPInnocentColor
            if role == "Murderer" then
                roleColor = Config.ESPMurdererColor
            elseif role == "Sheriff" then
                roleColor = Config.ESPSheriffColor
            end
            State.RoleLabel.Text = "Role: " .. role .. " | Murderer: "
                .. (State.Murderer and State.Murderer.DisplayName or "???")
                .. " | Sheriff: "
                .. (State.Sheriff and State.Sheriff.DisplayName or "???")
            State.RoleLabel.TextColor3 = roleColor
        end

        --// Drive the universal SpongeHUB modules instead of the old built-ins
        local UN = getgenv().UN
        if UN then
            --// Sync MM2 config -> universal config
            UN.Config.ESPEnabled = Config.ESPEnabled
            UN.Config.ESPBox = Config.ESPBoxEnabled
            UN.Config.ESPName = Config.ESPNameEnabled
            UN.Config.ESPHealth = Config.ESPHealthEnabled
            UN.Config.ESPTracer = Config.ESPTracerEnabled
            UN.Config.AimbotEnabled = Config.AimbotEnabled
            UN.Config.AimbotFOV = Config.AimbotFOV
            UN.Config.AimbotSmoothing = Config.AimbotSmoothing
            UN.Config.AimbotTargetPart = Config.AimbotTargetPart
            UN.Config.SpeedEnabled = Config.SpeedHack
            UN.Config.SpeedValue = Config.CustomSpeed
            UN.Config.JumpEnabled = (Config.JumpPower and Config.JumpPower > 50)
            UN.Config.NoClipEnabled = Config.NoClipEnabled
            UN.Config.InfiniteJump = Config.InfiniteJump
            UN.Config.AimbotMM2Mode = true

            local M = UN.State.Modules
            if M.ESP then M.ESP:Update() end
            if M.Aimbot then M.Aimbot:Update() end
            if M.Movement then M.Movement:Update() end
        end

        --// Auto Flick Knife: throw at locked target when toggled (MM2 specific)
        if Config.FlickKnife and GetRole(LocalPlayer) == "Murderer" and State.AimbotTarget then
            if IsAlive(State.AimbotTarget) then
                local now = os.clock()
                if now - lastFlick > 1.2 then
                    lastFlick = now
                    FlickKnife:ThrowAtTarget(State.AimbotTarget)
                end
            end
        end
    end)

    --// Periodic role scan
    task.spawn(function()
        while task.wait(3) do
            ScanRoles()
        end
    end)

    print("[SpongeHUB] MM2 Script loaded successfully!")
    print("[SpongeHUB] Press RightControl to toggle GUI")
end

--// Initialize
Init()
