local mm2 = 142823291
local repo = "gabeczkag/SpongeHUB"
local path = "scripts/mm2/Script.luau"

if game.GameId == mm2 then
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