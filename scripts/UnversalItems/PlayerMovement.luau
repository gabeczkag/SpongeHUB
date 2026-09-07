--[[
    SpongeHUB - Universal Player Movement
    Speed, JumpPower, NoClip, Infinite Jump. Game-agnostic.
    Requires Utils.luau loaded first.
]]

local UN = getgenv().UN
assert(UN, "[Movement] Load Utils.luau first!")

local Players = UN.Players
local RunService = UN.RunService
local UserInputService = UN.UserInputService
local LocalPlayer = UN.LocalPlayer

local Movement = {}

function Movement:Apply()
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if UN.Config.SpeedEnabled then
        humanoid.WalkSpeed = UN.Config.SpeedValue
    else
        humanoid.WalkSpeed = 16
    end

    if UN.Config.JumpEnabled then
        humanoid.JumpPower = UN.Config.JumpValue
    else
        humanoid.JumpPower = 50
    end
end

function Movement:EnableNoClip()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

function Movement:Init()
    --// Apply speed/jump on character (re)spawn
    UN.TrackConnection(LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        self:Apply()
        if UN.Config.NoClipEnabled then
            task.spawn(function()
                while UN.Config.NoClipEnabled and not UN.State.Unloaded do
                    self:EnableNoClip()
                    RunService.Heartbeat:Wait()
                end
            end)
        end
    end))

    --// Infinite Jump
    UN.TrackConnection(UserInputService.JumpRequest:Connect(function()
        if UN.Config.InfiniteJump and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end))

    self:Apply()
end

function Movement:Update()
    if UN.Config.SpeedEnabled or UN.Config.JumpEnabled then
        self:Apply()
    end
    if UN.Config.NoClipEnabled then
        self:EnableNoClip()
    end
end

UN.RegisterModule("Movement", Movement)

local UI = UN.State.Modules.UI
if UI then
    local mod = UI:Add_Module("Movement")
    mod:Section("Movement")
    mod:Toggle("Speed Hack", "SpeedEnabled", function() Movement:Apply() end)
    mod:Toggle("Infinite Jump", "InfiniteJump")
    mod:Toggle("NoClip", "NoClipEnabled")
    mod:Toggle("Jump Power", "JumpEnabled", function() Movement:Apply() end)
    mod:Slider("Speed", 16, 200, "SpeedValue", function() Movement:Apply() end)
    mod:Slider("Jump", 50, 300, "JumpValue", function() Movement:Apply() end)
else
    warn("[Movement] UI module not loaded; skipping controls.")
end

print("[UN] PlayerMovement module loaded.")
