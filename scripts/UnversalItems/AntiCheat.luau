--[[
    SpongeHUB - Universal Anti-Cheat Spoof
    Blocks Kick/Screenshot, randomizes remote timing, hides WalkSpeed.
    Requires Utils.luau loaded first.
]]

local UN = getgenv().UN
assert(UN, "[AntiCheat] Load Utils.luau first!")

local LocalPlayer = UN.LocalPlayer

local AntiCheat = {}

function AntiCheat:Init()
    if not UN.Config.AntiCheatEnabled then return end

    --// Block Kick / Screenshot / suspicious remotes
    pcall(function()
        hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if UN.Config.AntiKick and method == "Kick" then
                warn("[UN] Kick blocked")
                return nil
            end

            if UN.Config.AntiScreenshot and (
                method:lower():find("screenshot")
                or tostring(self):lower():find("screenshot")
            ) then
                return nil
            end

            if method == "FireServer" and UN.Config.AntiCheatEnabled then
                local remoteName = tostring(self.Name):lower()
                if remoteName:find("ban") or remoteName:find("kick") or remoteName:find("report") then
                    return nil
                end
            end

            return self[method](self, ...)
        end)
    end)

    --// Spoof WalkSpeed so server checks don't catch it
    pcall(function()
        LocalPlayer.CharacterAdded:Connect(function(char)
            local hum = char:WaitForChild("Humanoid", 5)
            if hum then
                hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                    if hum.WalkSpeed ~= 16 and not UN.Config.SpeedEnabled then
                        task.wait(0.1)
                        hum.WalkSpeed = 16
                    end
                end)
            end
        end)
    end)

    --// Random heartbeat to avoid idle-detection
    task.spawn(function()
        while UN.Config.AntiCheatEnabled and not UN.State.Unloaded do
            task.wait(math.random(30, 90))
            pcall(function()
                LocalPlayer:SetAttribute("Heartbeat", tick())
            end)
        end
    end)

    print("[UN] AntiCheat spoof active.")
end

UN.RegisterModule("AntiCheat", AntiCheat)

local UI = UN.State.Modules.UI
if UI then
    local mod = UI:Add_Module("AntiCheat")
    mod:Section("Anti-Cheat")
    mod:Toggle("Enable Spoof", "AntiCheatEnabled", function(v) if v then AntiCheat:Init() end end)
    mod:Toggle("Anti Kick", "AntiKick")
    mod:Toggle("Anti Screenshot", "AntiScreenshot")
else
    warn("[AntiCheat] UI module not loaded; skipping controls.")
end

print("[UN] AntiCheat module loaded.")
