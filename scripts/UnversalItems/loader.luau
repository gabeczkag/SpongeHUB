--[[
    SpongeHUB - Universal Items Loader
    Loads the universal modules (works on ANY game) from GitHub.
    Paste into any executor and run (no GameId check needed).
]]

local repo = "gabeczkag/SpongeHUB"
local base = "scripts/UnversalItems/"
local hubPath = base .. "UniversalHub.luau"

--// UniversalHub.luau pulls in Utils + all modules (incl. RemoteSpy) via #include,
--// so we only need to load it explicitly, and preprocess the includes below.

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

local function fetch(path)
    local ok, src = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/" .. repo .. "/" .. sha .. "/" .. path)
    end)
    if ok and src and #src > 0 then
        return src
    end
    return nil
end

--// Preprocessor: replace "#include Name.luau" lines with the fetched file
--// contents (resolved via base unless it has a slash). Runs recursively.
local function preprocess(text, depth)
    depth = depth or 0
    local out = {}
    for line in text:gmatch("([^\n]*)\n?") do
        local name = line:match("^%s*%-*%s*#include%s+\"?([%w%._/]+)\"?%s*$")
        if name then
            local path = name:find("/") and name or (base .. name)
            local src = fetch(path)
            if src and depth < 6 then
                out[#out + 1] = "--// [include] " .. name
                for _, l in ipairs(preprocess(src, depth + 1)) do
                    out[#out + 1] = l
                end
                out[#out + 1] = "--// [end include] " .. name
            else
                warn("[UN] #include failed: " .. name)
                out[#out + 1] = "--// [include FAILED: " .. name .. "]"
            end
        else
            out[#out + 1] = line
        end
    end
    return out
end

local src = fetch(hubPath)
if not src then
    warn("[UN] Could not fetch UniversalHub.luau")
    return
end

local final = table.concat(preprocess(src), "\n")
local fn, err = loadstring(final)
if not fn then
    warn("[UN] Could not compile UniversalHub.luau: " .. tostring(err))
    return
end
local ok, rerr = pcall(fn)
if not ok then
    warn("[UN] Runtime error in UniversalHub.luau: " .. tostring(rerr))
end

print("[UN] Universal modules loader finished.")
