--[[
    SpongeHUB - Universal Items Loader
    Loads the universal modules (works on ANY game) from GitHub.
    Paste into any executor and run (no GameId check needed).
]]

local repo = "gabeczkag/SpongeHUB"
local base = "scripts/UnversalItems/"

--// UniversalHub.luau itself pulls in Utils + all modules via #include,
--// so we only need to load these two files explicitly.
local files = {
    "Utils.luau",
    "UniversalHub.luau",
}

local function getSha()
    local ok, json = pcall(function()
        return game:HttpGet("https://api.github.com/repos/" .. repo .. "/commits/main")
    end)
    if ok then
        return (json:match('"sha"%s*:%s*"([a-f0-9]+)"'))
    end
    return nil
end

local sha = getSha()
if not sha then
    warn("[UN] Failed to reach GitHub API (rate limited?). Aborting.")
    return
end

for _, file in ipairs(files) do
    local url = "https://raw.githubusercontent.com/" .. repo .. "/" .. sha .. "/" .. base .. file
    local ok, src = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and src and #src > 0 then
        local fn, err = loadstring(src)
        if fn then
            local s, e = pcall(fn)
            if not s then warn("[UN] Error in " .. file .. ": " .. tostring(e)) end
        else
            warn("[UN] Could not compile " .. file .. ": " .. tostring(err))
        end
    else
        warn("[UN] Could not fetch " .. file)
    end
end

print("[UN] Universal modules loader finished.")
