--[[
    SpongeHUB - Universal Remote Spy
    Logs FireServer / InvokeServer calls with full data-format inspection,
    and lets you re-fire or manually FireServer (e.g. to test an item/asset id
    like 1365169983) against the server.

    Requires Utils.luau (and UI.luau for the panel).
]]

local UN = getgenv().UN
assert(UN, "[RSpy] Load Utils.luau first!")

local RunService = UN.RunService
local RemoteSpy = {}
UN.State.RemoteLog = UN.State.RemoteLog or {}
local RemoteLog = UN.State.RemoteLog
local MAX_ENTRIES = 300
local Active = false

--// Full data-format serializer (types + nesting) for inspection
local function serialize(v, depth)
    depth = depth or 0
    if depth > 4 then return "..." end
    local t = typeof(v)
    if t == "nil" then
        return "nil"
    elseif t == "string" then
        return '"' .. v .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "Vector3" then
        return ("Vector3(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z)
    elseif t == "Vector2" then
        return ("Vector2(%.1f, %.1f)"):format(v.X, v.Y)
    elseif t == "CFrame" then
        local p = v.Position
        return ("CFrame(%.1f, %.1f, %.1f)"):format(p.X, p.Y, p.Z)
    elseif t == "Color3" then
        return ("Color3(%.2f, %.2f, %.2f)"):format(v.R, v.G, v.B)
    elseif t == "Instance" then
        return ("Instance<%s> %s"):format(v.ClassName, v.Name or "?")
    elseif t == "table" then
        local parts = {}
        local n = 0
        for k, val in pairs(v) do
            n = n + 1
            if n > 12 then parts[n] = "..."; break end
            parts[n] = ("[%s]=%s"):format(tostring(k), serialize(val, depth + 1))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return t .. ":" .. tostring(v)
    end
end

local function push(kind, remote, method, args)
    local entry = {
        time = math.floor(os.clock()),
        kind = kind,
        name = remote and remote.Name or "?",
        className = remote and pcall(function() return remote.ClassName end) and remote.ClassName or "?",
        method = method,
        remote = remote,           -- keep the instance for re-firing
        args = args or {},
    }
    table.insert(RemoteLog, 1, entry)
    while #RemoteLog > MAX_ENTRIES do
        table.remove(RemoteLog)
    end
end

function RemoteSpy:Init()
    if Active then return end
    Active = true

    pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            if method == "FireServer" or method == "InvokeServer" then
                local okCls = pcall(function() return self.ClassName end)
                local cls = okCls and self.ClassName or ""
                if cls:find("Remote") then
                    push(self.ClassName, self, method, args)
                end
            end
            return oldNamecall(self, ...)
        end)
    end)

    pcall(function()
        local oldNew
        oldNew = hookfunction(Instance.new, function(class, parent, ...)
            local inst = oldNew(class, parent, ...)
            if class == "RemoteEvent" or class == "RemoteFunction" then
                push(class, inst, "new", {})
            end
            return inst
        end)
    end)

    print("[RSpy] Remote Spy active. Logs in UN.State.RemoteLog + UI panel.")
end

--// Re-fire a logged call (uses the captured remote instance + args)
function RemoteSpy:Resend(index)
    local e = RemoteLog[index or 1]
    if not e then warn("[RSpy] No log entry"); return end
    if not e.remote then warn("[RSpy] No remote instance stored"); return end
    local ok, err = pcall(function()
        if e.method == "InvokeServer" then
            e.remote:InvokeServer(unpack(e.args))
        else
            e.remote:FireServer(unpack(e.args))
        end
    end)
    if ok then
        print(("[RSpy] Re-fired %s.%s (%d args)"):format(e.name, e.method, #e.args))
    else
        warn("[RSpy] Re-fire failed: " .. tostring(err))
    end
end

--// Manually FireServer to a remote found by name anywhere in the game
function RemoteSpy:FireByName(name, ...)
    local args = {...}
    local found
    pcall(function()
        for _, desc in ipairs(game:GetDescendants()) do
            if (desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction")) and desc.Name == name then
                found = desc
                break
            end
        end
    end)
    if not found then warn("[RSpy] Remote not found: " .. tostring(name)); return end
    local ok, err = pcall(function() found:FireServer(unpack(args)) end)
    if ok then
        print(("[RSpy] Fired %s with %d args"):format(name, #args))
    else
        warn("[RSpy] Fire failed: " .. tostring(err))
    end
end

UN.RegisterModule("RemoteSpy", RemoteSpy)

--// UI panel: live log + re-fire + manual fire
local UI = UN.State.Modules.UI
if UI then
    local mod = UI:Add_Module("RemoteSpy")
    mod:Section("Remote Spy")
    mod:Button("Start Spy", function() RemoteSpy:Init() end)
    mod:Button("Re-Fire Last", function() RemoteSpy:Resend(1) end)
    mod:Button("Clear Log", function()
        for i = #RemoteLog, 1, -1 do RemoteLog[i] = nil end
    end)

    mod:Section("Manual FireServer")
    mod:Input("Remote name", "RSpyRemoteName", "e.g. AddItem")
    mod:Input("Arg 1 (asset id)", "RSpyArg1", "1365169983")
    mod:Button("Fire Server", function()
        local name = UN.Config.RSpyRemoteName
        local a1 = UN.Config.RSpyArg1
        if not name or name == "" then warn("[RSpy] Type a remote name"); return end
        --// Try to coerce numeric arg
        local arg1 = tonumber(a1) or a1
        RemoteSpy:FireByName(name, arg1)
    end)
    mod:Button("Fire Asset 1365169983", function()
        local name = UN.Config.RSpyRemoteName
        if name and name ~= "" then
            RemoteSpy:FireByName(name, 1365169983)
        else
            warn("[RSpy] Set 'Remote name' first (e.g. AddItem/BuyItem/GiveItem)")
        end
    end)

    local box = mod:LogBox(260)

    UN.TrackConnection(RunService.RenderStepped:Connect(function()
        if not box or not box.Parent then return end
        local lines = {}
        for i = 1, math.min(30, #RemoteLog) do
            local e = RemoteLog[i]
            local argStr = {}
            for j = 1, #e.args do
                argStr[j] = serialize(e.args[j])
                if #argStr[j] > 60 then argStr[j] = argStr[j]:sub(1, 60) .. "..." end
            end
            lines[i] = ("[%s] %s.%s(%s)"):format(e.className, e.name, e.method, table.concat(argStr, ", "))
        end
        box.Text = table.concat(lines, "\n")
    end))
else
    warn("[RSpy] UI module not loaded; logging to UN.State.RemoteLog only.")
end

print("[UN] RemoteSpy module loaded.")
