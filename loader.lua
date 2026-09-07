local repo = "gabeczkag/SpongeHUB"
local mm2Ids = {66654135, 142823291}
local mm2Path = "scripts/mm2/Script.luau"
local universalLoaderPath = "scripts/UnversalItems/loader.luau"
local includeBase = "scripts/UnversalItems/"

--// Fetch raw file from repo at latest main commit (bypasses GitHub raw cache)
local function getSha()
    local ok, json = pcall(function()
        return game:HttpGet("https://api.github.com/repos/" .. repo .. "/commits/main")
    end)
    if ok then
        local sha = json:match('"sha"%s*:%s*"([a-f0-9]+)"')
        if sha and #sha >= 8 then return sha end
    end
    return nil
end

local sha = getSha()

local function fetch(path)
    if not sha then return nil, "no sha" end
    local ok, src = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/" .. repo .. "/" .. sha .. "/" .. path)
    end)
    if ok and src and #src > 0 then
        return src
    end
    return nil, "fetch failed: " .. tostring(src)
end

--// Preprocessor: replaces "#include Name.luau" (also "--#include ...") lines
--// with the fetched file contents (resolved via includeBase unless it has a slash).
--// Runs recursively so included files can include others too.
local function preprocess(text)
    local out = {}
    for line in text:gmatch("([^\n]*)\n?") do
        local name = line:match("^%s*%-*%s*#include%s+\"?([%w%._/]+)\"?%s*$")
        if name then
            local path = name:find("/") and name or (includeBase .. name)
            local ok, src = pcall(fetch, path)
            if ok and src then
                --// Recursively preprocess the included file
                local processed = preprocess(src)
                table.insert(out, "--// [include] " .. name)
                for _, l in ipairs(processed) do
                    table.insert(out, l)
                end
                table.insert(out, "--// [end include] " .. name)
            else
                table.insert(out, "--// [include FAILED: " .. name .. "]")
                warn("[SpongeHUB] #include failed: " .. name .. " (" .. tostring(src) .. ")")
            end
        else
            table.insert(out, line)
        end
    end
    return out
end

local function runScript(path)
    local src, err = fetch(path)
    if not src then
        warn("[SpongeHUB] Failed to fetch " .. path .. ": " .. tostring(err))
        return false
    end
    local lines = preprocess(src)
    local final = table.concat(lines, "\n")
    local fn, lerr = loadstring(final)
    if not fn then
        warn("[SpongeHUB] Compile error in " .. path .. ": " .. tostring(lerr))
        return false
    end
    local ok, rerr = pcall(fn)
    if not ok then
        warn("[SpongeHUB] Runtime error in " .. path .. ": " .. tostring(rerr))
        return false
    end
    return true
end

local function isMm2(id)
    for _, v in ipairs(mm2Ids) do
        if id == v then return true end
    end
    return false
end

if isMm2(game.GameId) then
    if not sha then
        warn("[SpongeHUB] Could not reach GitHub API. Aborting.")
    else
        runScript(mm2Path)
    end
else
    print("[SpongeHUB] GameID " .. tostring(game.GameId) .. " is not Murder Mystery 2.")
    print("[SpongeHUB] Launching Universal Items (works on any game)...")
    if not sha then
        warn("[SpongeHUB] Could not reach GitHub API. Aborting.")
    else
        runScript(universalLoaderPath)
    end
end
