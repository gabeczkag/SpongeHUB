--[[
    SpongeHUB - Universal Aimbot
    Works on any game: aims camera at nearest player within FOV.
    Requires Utils.luau loaded first.
]]

local UN = getgenv().UN
assert(UN, "[Aimbot] Load Utils.luau first!")

local Camera = UN.Camera
local Players = UN.Players
local LocalPlayer = UN.LocalPlayer

local Aimbot = {}

--// FOV circle (Drawing) shown at screen center
local FOVCircle = nil
pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Visible = false
    FOVCircle.Thickness = 1
    FOVCircle.NumSides = 60
    FOVCircle.Filled = false
end)

function Aimbot:UpdateFOV()
    if not FOVCircle then return end
    if not UN.Config.AimbotEnabled or not UN.Config.AimbotShowFOV then
        FOVCircle.Visible = false
        return
    end
    local r, g, b = UN.Config.AimbotFOVColor:match("(%d+),%s*(%d+),%s*(%d+)")
    r, g, b = tonumber(r) or 255, tonumber(g) or 80, tonumber(b) or 80
    FOVCircle.Color = Color3.fromRGB(r, g, b)
    FOVCircle.Radius = UN.Config.AimbotFOV
    FOVCircle.Position = UN.UserInputService:GetMouseLocation()
    FOVCircle.Visible = true
end

function Aimbot:RemoveFOV()
    pcall(function() if FOVCircle then FOVCircle:Remove() end end)
end
UN.AddUnload(function() Aimbot:RemoveFOV() end)

function Aimbot:GetClosestPlayer()
    local closest, closestDist = nil, UN.Config.AimbotFOV
    local mousePos = UN.UserInputService:GetMouseLocation()
    local targetTeam = UN.Config.AimbotTargetTeam
    local mm2 = UN.Config.AimbotMM2Mode
    local localRole = (mm2 and UN.State.MM2Roles and UN.State.MM2Roles[LocalPlayer.Name]) or nil

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and UN.IsAlive(player) then
            local skip = false

            --// Standard team check (same team -> skip)
            if UN.Config.AimbotTeamCheck and UN.IsTeammate(LocalPlayer, player) then
                skip = true
            end

            --// Target team filter (universal)
            if not skip and targetTeam ~= "All" then
                local role = UN.State.MM2Roles and UN.State.MM2Roles[player.Name]
                if targetTeam == "Murderer" and role ~= "Murderer" then
                    skip = true
                elseif targetTeam == "Sheriff" and role ~= "Sheriff" then
                    skip = true
                elseif targetTeam == "Innocent" and role == "Murderer" then
                    skip = true
                end
            end

            --// MM2 mode: Sheriff only aims at Murderer, Murderer aims at anyone, others none
            if not skip and mm2 and localRole then
                if localRole == "Sheriff" then
                    if (UN.State.MM2Roles and UN.State.MM2Roles[player.Name]) ~= "Murderer" then
                        skip = true
                    end
                elseif localRole ~= "Murderer" then
                    skip = true
                end
            end

            if not skip then
                local parts = UN.GetCharacterParts(player)
                local targetPart = parts and parts[UN.Config.AimbotTargetPart]
                if targetPart then
                    local screenPos, onScreen = UN.WorldToScreen(targetPart.Position)
                    if onScreen then
                        local dist = (mousePos - screenPos).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            closest = player
                        end
                    end
                end
            end
        end
    end
    return closest
end

function Aimbot:Update()
    self:UpdateFOV()

    if not UN.Config.AimbotEnabled then
        UN.State.AimbotTarget = nil
        return
    end

    --// Optional hold-to-aim keybind (None = always active)
    local key = UN.Config.AimbotKey
    if key and key ~= "None" then
        local ok, down = pcall(function()
            return UN.UserInputService:IsKeyDown(Enum.KeyCode[key])
        end)
        if not (ok and down) then
            UN.State.AimbotTarget = nil
            return
        end
    end

    local target = self:GetClosestPlayer()
    UN.State.AimbotTarget = target

    if target and UN.IsAlive(target) then
        local parts = UN.GetCharacterParts(target)
        local targetPart = parts and parts[UN.Config.AimbotTargetPart]
        if targetPart then
            local aimPos = targetPart.Position

            if UN.Config.AimbotSilentAim then
                --// Silent aim: snap character flat face toward target (no camera move)
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local delta = aimPos - root.Position
                    local flat = Vector3.new(delta.X, 0, delta.Z)
                    if flat.Magnitude > 0.001 then
                        local tgt = CFrame.new(root.Position, root.Position + flat.Unit)
                        local cur = CFrame.new(root.Position, root.Position + Vector3.new(
                            root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z))
                        root.CFrame = cur:Lerp(tgt, 1 / 4)
                    end
                end
            else
                --// Regular aim: rotate camera from its own position
                local camPos = Camera.CFrame.Position
                local direction = (aimPos - camPos).Unit
                local desired = CFrame.new(camPos, camPos + direction)
                local smooth = math.clamp(UN.Config.AimbotSmoothing, 0.1, 20)
                Camera.CFrame = Camera.CFrame:Lerp(desired, 1 / (smooth * 2))

                --// Rotate character flat toward target
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local delta = aimPos - root.Position
                    local flat = Vector3.new(delta.X, 0, delta.Z)
                    if flat.Magnitude > 0.001 then
                        local cur = CFrame.new(root.Position, root.Position + Vector3.new(
                            root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z))
                        local tgt = CFrame.new(root.Position, root.Position + flat.Unit)
                        root.CFrame = cur:Lerp(tgt, 1 / (smooth * 3))
                    end
                end
            end
        end
    end
end

UN.RegisterModule("Aimbot", Aimbot)

--// Register in the static UI
local UI = UN.State.Modules.UI
if UI then
    local mod = UI:Add_Module("Aimbot")

    mod:Section("General")
    mod:Toggle("Enable Aimbot", "AimbotEnabled")
    mod:Toggle("Show FOV Circle", "AimbotShowFOV")
    mod:Toggle("Silent Aim (face snap)", "AimbotSilentAim")
    mod:Keybind("Aimbot Key (hold)", "AimbotKey")

    mod:Section("Targeting")
    mod:Toggle("Team Check", "AimbotTeamCheck")
    mod:Toggle("MM2 Mode (roles)", "AimbotMM2Mode")
    mod:Dropdown("Target Team", {"All", "Murderer", "Sheriff", "Innocent"}, "AimbotTargetTeam")
    mod:Dropdown("Target Part", {"Head", "HumanoidRootPart", "Torso", "UpperTorso"}, "AimbotTargetPart")

    mod:Section("Tuning")
    mod:Slider("FOV", 30, 800, "AimbotFOV")
    mod:Slider("Smoothing", 1, 20, "AimbotSmoothing")
    mod:Dropdown("FOV Color", {"255, 80, 80", "80, 255, 80", "80, 80, 255", "255, 255, 80"}, "AimbotFOVColor")
else
    warn("[Aimbot] UI module not loaded; skipping controls.")
end

print("[UN] Aimbot module loaded.")

