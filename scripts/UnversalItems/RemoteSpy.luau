--[[
    SpongeHUB - Universal Remote Spy
    Hooks FireServer / InvokeServer (and RemoteEvent/Function creation)
    to log what the game communicates. Useful to verify which changes are
    local-only vs. sent to the server (so you know what a real bypass needs).

    Requires Utils.luau (and UI.luau for the panel).
]]

local UN = getgenv().UN
assert(UN, "[RSpy] Load Utils.luau first!")

local RunService = UN.RunService
local RemoteSpy = {}
UN.State.RemoteLog = UN.State.RemoteLog or {}
local RemoteLog = UN.State.RemoteLog
local MAX_ENTRIES = 250
local Active = false

local function push(kind, remote, method, args)
    local argStr = {}
    for i = 1, (args and #args or 0) do
        local ok, s = pcall(tostring, args[i])
        argStr[i] = ok and s or "?"
        if #argStr[i] > 80 then argStr[i] = argStr[i]:sub(1, 80) .. "..." end
    end
    table.insert(RemoteLog, 1, {
        time = math.floor(os.clock()),
        kind = kind,
        name = remote and remote.Name or "?",
        method = method,
        args = table.concat(argStr, " | "),
    })
    while #RemoteLog > MAX_ENTRIES do
        table.remove(RemoteLog)
    end
end

function RemoteSpy:Init()
    if Active then return end
    Active = true

    --// Hook remote calls (FireServer / InvokeServer)
    pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            if (method == "FireServer" or method == "InvokeServer") then
                local okCls = pcall(function() return self.ClassName end)
                local cls = okCls and self.ClassName or ""
                if cls:find("Remote") then
                    push(self.ClassName, self, method, args)
                end
            end
            return oldNamecall(self, ...)
        end)
    end)

    --// Hook remote creation via Instance.new
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

UN.RegisterModule("RemoteSpy", RemoteSpy)

--// UI panel with a live log box
local UI = UN.State.Modules.UI
if UI then
    local mod = UI:Add_Module("RemoteSpy")
    mod:Section("Remote Spy")
    mod:Button("Start Spy", function() RemoteSpy:Init() end)
    mod:Button("Clear Log", function()
        for i = #RemoteLog, 1, -1 do RemoteLog[i] = nil end
    end)
    local box = mod:LogBox(220)

    --// Refresh the log box each frame
    UN.TrackConnection(RunService.RenderStepped:Connect(function()
        if not box or not box.Parent then return end
        local lines = {}
        for i = 1, math.min(40, #RemoteLog) do
            local e = RemoteLog[i]
            lines[i] = ("[%s] %s.%s(%s)"):format(e.kind, e.name, e.method, e.args)
        end
        box.Text = table.concat(lines, "\n")
    end))
else
    warn("[RSpy] UI module not loaded; logging to UN.State.RemoteLog only.")
end

print("[UN] RemoteSpy module loaded.")
