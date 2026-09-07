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

function Aimbot:GetClosestPlayer()
    local closest, closestDist = nil, UN.Config.AimbotFOV
    local mousePos = UN.UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and UN.IsAlive(player) then
            if not (UN.Config.AimbotTeamCheck and UN.IsTeammate(LocalPlayer, player)) then
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
    if not UN.Config.AimbotEnabled then
        UN.State.AimbotTarget = nil
        return
    end

    local target = self:GetClosestPlayer()
    UN.State.AimbotTarget = target

    if target and UN.IsAlive(target) then
        local parts = UN.GetCharacterParts(target)
        local targetPart = parts and parts[UN.Config.AimbotTargetPart]
        if targetPart then
            local aimPos = targetPart.Position
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

UN.RegisterModule("Aimbot", Aimbot)
print("[UN] Aimbot module loaded.")
