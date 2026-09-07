--[[
    SpongeHUB - Universal Asset Applier
    Type an AssetID (rbxassetid, e.g. 1365169983) and apply it as:
      Skybox       - set all 6 skybox faces
      Parts        - texture/decal on every BasePart in Workspace
      Light        - set Lighting.Ambient/FogColor + skybox tint (image as "light" color)
      Give Item    - FireServer to a remote by name with the id (see RemoteSpy)

    Requires Utils.luau (and UI.luau for the panel).
]]

local UN = getgenv().UN
assert(UN, "[AA] Load Utils.luau first!")

local Lighting = game:GetService("Lighting")
local AssetApplier = {}

UN.Config.AssetID = UN.Config.AssetID or "1365169983"
UN.Config.AssetApplyMode = UN.Config.AssetApplyMode or "Skybox"
UN.Config.GiveItemRemote = UN.Config.GiveItemRemote or ""

local function assetUrl()
    local id = tonumber(UN.Config.AssetID)
    if id then return "rbxassetid://" .. id end
    return nil
end

function AssetApplier:ApplySkybox(url)
    local ok, err = pcall(function()
        for _, prop in ipairs({"SkyboxUp", "SkyboxDown", "SkyboxLeft", "SkyboxRight", "SkyboxFront", "SkyboxBack"}) do
            if not Lighting:FindFirstChildOfClass("Sky") then
                local sky = Instance.new("Sky", Lighting)
            end
            Lighting:FindFirstChildOfClass("Sky")[prop] = url
        end
    end)
    if ok then print("[AA] Skybox applied: " .. url)
    else warn("[AA] Skybox failed: " .. tostring(err)) end
end

function AssetApplier:ApplyParts(url)
    local count = 0
    pcall(function()
        local function walk(inst)
            for _, child in ipairs(inst:GetChildren()) do
                if child:IsA("BasePart") and not child:IsA("Terrain") then
                    local decal = Instance.new("Decal")
                    decal.Texture = url
                    decal.Face = Enum.NormalId.Front
                    decal.Parent = child
                    count = count + 1
                end
                walk(child)
            end
        end
        walk(workspace)
    end)
    print(("[AA] Textured %d parts with %s"):format(count, url))
end

function AssetApplier:ApplyLight(url)
    --// use the asset id to drive a colored "light" via Ambient tint
    local id = tonumber(url:match("rbxassetid://(%d+)")) or 0
    local h = (id % 360) / 360
    local color = Color3.fromHSV(h, 0.6, 0.9)
    local ok, err = pcall(function()
        Lighting.Ambient = color
        Lighting.OutdoorAmbient = color
        Lighting.FogColor = color
    end)
    if ok then print(("[AA] Light tint applied (id %d -> %s)"):format(id, tostring(color)))
    else warn("[AA] Light failed: " .. tostring(err)) end
end

function AssetApplier:GiveItem(url)
    local name = UN.Config.GiveItemRemote
    if not name or name == "" then
        warn("[AA] Set 'Give Item Remote' name (e.g. AddItem/BuyItem/GiveItem)")
        return
    end
    local id = tonumber(url:match("rbxassetid://(%d+)")) or UN.Config.AssetID
    local ok, err = pcall(function()
        --// reuse RemoteSpy's fire-by-name if loaded
        local rs = UN.State.Modules and UN.State.Modules.RemoteSpy
        if rs and rs.FireByName then
            rs:FireByName(name, id)
        else
            for _, desc in ipairs(game:GetDescendants()) do
                if (desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction")) and desc.Name == name then
                    desc:FireServer(id)
                    print(("[AA] Gave item %d via %s"):format(id, name))
                    return
                end
            end
            warn("[AA] Remote not found: " .. tostring(name))
        end
    end)
    if not ok then warn("[AA] GiveItem error: " .. tostring(err)) end
end

function AssetApplier:Apply()
    local url = assetUrl()
    if not url then warn("[AA] Invalid AssetID"); return end
    local mode = UN.Config.AssetApplyMode
    if mode == "Skybox" then
        self:ApplySkybox(url)
    elseif mode == "Parts" then
        self:ApplyParts(url)
    elseif mode == "Light" then
        self:ApplyLight(url)
    elseif mode == "Give Item" then
        self:GiveItem(url)
    else
        warn("[AA] Unknown mode: " .. tostring(mode))
    end
end

UN.RegisterModule("AssetApplier", AssetApplier)
UN.State.AssetApplier = AssetApplier
UN.AddUnload(function()
    pcall(function()
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky then sky:Destroy() end
    end)
end)

--// UI panel
local UI = UN.State.Modules.UI
if UI then
    local mod = UI:Add_Module("AssetApplier")
    mod:Section("Asset Applier")
    mod:Input("Asset ID", "AssetID", "1365169983")
    mod:Dropdown("Apply As", {"Skybox", "Parts", "Light", "Give Item"}, "AssetApplyMode")
    mod:Input("Give Item Remote", "GiveItemRemote", "AddItem/BuyItem/GiveItem")
    mod:Button("Apply Now", function() AssetApplier:Apply() end)
else
    warn("[AA] UI module not loaded; use UN.State.AssetApplier:Apply().")
end

print("[UN] AssetApplier module loaded.")
