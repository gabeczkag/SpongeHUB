--[==[
    SpongeHUB - Universal Hub
    Loads all UniversalItems modules, builds a GUI, runs the main loop,
    and provides an "Unload All" button. Works on ANY game.

    Modules are pulled in with #include (resolved by the loader from
    scripts/UnversalItems/). You can add/remove includes freely, e.g.:
        --#include Aimbot.luau
        --#include ESP.luau
    The loader inlines them before running, so this file is self-contained.

    To load just this hub, run scripts/UnversalItems/loader.luau (it loads
    Utils.luau + this file), or paste this file's contents into your executor.
]==]

--#include Utils.luau
--#include UI.luau
--#include Aimbot.luau
--#include PlayerMovement.luau
--#include AntiCheat.luau
--#include ESP.luau
--#include RemoteSpy.luau

local UN = getgenv().UN
assert(UN, "[Hub] Utils.luau failed to load (check #include).")

--// Build the static UI up front so modules can register into it
if UN.State.Modules.UI then
    UN.State.Modules.UI:Create("SpongeHUB Universal")
end

local Players = UN.Players
local RunService = UN.RunService
local UserInputService = UN.UserInputService
local LocalPlayer = UN.LocalPlayer

--// Init modules that need setup
if UN.State.Modules.AntiCheat then UN.State.Modules.AntiCheat:Init() end
if UN.State.Modules.Movement then UN.State.Modules.Movement:Init() end

--// Modules above already registered their controls into the UI (UI:Add_Module).
--// Register UI teardown with the global unload system.
UN.AddUnload(function()
    if UN.State.Modules.UI then UN.State.Modules.UI:Unload() end
end)

--// Main loop: drive all registered modules
UN.State.RenderConn = RunService.RenderStepped:Connect(function()
    if UN.State.Unloaded then return end
    local M = UN.State.Modules
    if M.Aimbot then M.Aimbot:Update() end
    if M.ESP then M.ESP:Update() end
    if M.Movement then M.Movement:Update() end
end)

print("[UN] Universal Hub loaded. Press RightControl to toggle GUI.")
