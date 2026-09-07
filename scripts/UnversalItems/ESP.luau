--[[
    SpongeHUB - Universal ESP
    Box / Name / Health / Tracer for all players.
    Requires Utils.luau loaded first.
]]

local UN = getgenv().UN
assert(UN, "[ESP] Load Utils.luau first!")

local Players = UN.Players
local LocalPlayer = UN.LocalPlayer
local Camera = UN.Camera

local ESP = {}
ESP.Objects = {}

local function CreateDraw(kind, props)
    local d = Drawing.new(kind)
    for k, v in pairs(props or {}) do
        d[k] = v
    end
    return d
end

function ESP:CreateFor(player)
    if self.Objects[player] then return end
    self.Objects[player] = {
        Box = CreateDraw("Square", {Color = Color3.fromRGB(255, 0, 0), Thickness = 1, Filled = false, Visible = false}),
        Name = CreateDraw("Text", {Color = Color3.fromRGB(255, 255, 255), Size = 13, Center = true, Outline = true, Visible = false}),
        Health = CreateDraw("Square", {Color = Color3.fromRGB(0, 255, 0), Thickness = 1, Filled = true, Visible = false}),
        Tracer = CreateDraw("Line", {Color = Color3.fromRGB(255, 0, 0), Thickness = 1, Visible = false}),
    }
end

function ESP:RemoveFor(player)
    local obj = self.Objects[player]
    if obj then
        for _, d in pairs(obj) do pcall(function() d:Remove() end) end
        self.Objects[player] = nil
    end
end

function ESP:Cleanup()
    for player, _ in pairs(self.Objects) do
        self:RemoveFor(player)
    end
end

function ESP:Update()
    --// Redraw pass: drop ESP for players that left / are invalid so
    --// drawings don't get stuck on screen after someone leaves the game.
    for tracked, obj in pairs(self.Objects) do
        local stillHere = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p == tracked then stillHere = true; break end
        end
        if not stillHere or not UN.IsAlive(tracked) or tracked == LocalPlayer then
            self:RemoveFor(tracked)
        end
    end

    if not UN.Config.ESPEnabled then
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and UN.IsAlive(player) then
            self:CreateFor(player)
            local obj = self.Objects[player]
            local parts = UN.GetCharacterParts(player)
            local root = parts and parts.HumanoidRootPart
            if root then
                local top = UN.WorldToScreen(root.Position + Vector3.new(0, 3, 0))
                local bottom = UN.WorldToScreen(root.Position - Vector3.new(0, 3, 0))
                local onScreen = (root.Position - Camera.CFrame.Position).Magnitude < 2000
                if onScreen then
                    local h = (top.Y - bottom.Y)
                    local w = math.abs(h) * 0.6
                    local cx = (top.X + bottom.X) / 2

                    obj.Box.Size = Vector2.new(w, math.abs(h))
                    obj.Box.Position = Vector2.new(cx - w / 2, math.min(top.Y, bottom.Y))
                    obj.Box.Visible = UN.Config.ESPBox

                    obj.Name.Text = player.DisplayName
                    obj.Name.Position = Vector2.new(cx, math.min(top.Y, bottom.Y) - 16)
                    obj.Name.Visible = UN.Config.ESPName

                    if UN.Config.ESPHealth and parts.Humanoid then
                        local hp = parts.Humanoid.Health / parts.Humanoid.MaxHealth
                        obj.Health.Size = Vector2.new(3, math.abs(h) * math.clamp(hp, 0, 1))
                        obj.Health.Position = Vector2.new(cx - w / 2 - 6, math.min(top.Y, bottom.Y))
                        obj.Health.Visible = true
                    else
                        obj.Health.Visible = false
                    end

                    if UN.Config.ESPTracer then
                        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        obj.Tracer.From = screenCenter
                        obj.Tracer.To = Vector2.new(cx, math.min(top.Y, bottom.Y))
                        obj.Tracer.Visible = true
                    else
                        obj.Tracer.Visible = false
                    end
                else
                    for _, d in pairs(obj) do pcall(function() d.Visible = false end) end
                end
            end
        else
            self:RemoveFor(player)
        end
    end
end

UN.RegisterModule("ESP", ESP)

local UI = UN.State.Modules.UI
if UI then
    local mod = UI:Add_Module("ESP")
    mod:Toggle("Enable ESP", "ESPEnabled")
    mod:Toggle("Box", "ESPBox")
    mod:Toggle("Name", "ESPName")
    mod:Toggle("Health", "ESPHealth")
    mod:Toggle("Tracer", "ESPTracer")
else
    warn("[ESP] UI module not loaded; skipping controls.")
end

print("[UN] ESP module loaded.")
