local mm2Ids = {66654135, 142823291}
local repo = "gabeczkag/SpongeHUB"
local path = "scripts/mm2/Script.luau"

local function isMm2(id)
	for _, v in ipairs(mm2Ids) do
		if id == v then return true end
	end
	return false
end

if isMm2(game.GameId) then
	local ok, script = pcall(function()
		local commitJson = game:HttpGet("https://api.github.com/repos/" .. repo .. "/commits/main")
		local sha = commitJson:match('"sha"%s*:%s*"([a-f0-9]+)"')
		return game:HttpGet("https://raw.githubusercontent.com/" .. repo .. "/" .. sha .. "/" .. path)
	end)
	if ok then
		loadstring(script)()
	else
		warn("[SpongeHUB] Failed to load script:", script)
	end
else
	print("The GameID is Invalid")
	print(game.GameId)
end