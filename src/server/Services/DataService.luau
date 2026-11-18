--[[
	DataService — loads and saves player progress with DataStoreService.

	Saved: pesos, needs, skills, relationships, furniture layout.
	In Studio, enable Game Settings → Security → "Enable Studio Access to API Services"
	to test saving. Without it the game still runs; progress just isn't saved.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[Bahay Buhay] DataStore unavailable, progress will not be saved:", result)
	end
end

local canSave: { [Player]: boolean } = {}

local function key(player: Player): string
	return "player_" .. player.UserId
end

function DataService.defaultProfile()
	local needs = {}
	for _, id in Config.NeedOrder do
		needs[id] = 85
	end
	return {
		Version = 1,
		Pesos = Config.StartingPesos,
		Needs = needs,
		Skills = {},
		Relationships = {},
		Furniture = nil, -- nil = give starter furniture
		DaysPlayed = 0,
	}
end

function DataService.load(player: Player)
	local data = nil
	local success = false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(key(player))
			end)
			if ok then
				data = result
				success = true
				break
			end
			warn(string.format("[Bahay Buhay] Load failed for %s (attempt %d): %s", player.Name, attempt, tostring(result)))
			if RunService:IsStudio() then
				break -- usually "API access not enabled"; don't make testers wait
			end
			task.wait(attempt * 1.5)
		end
	end
	canSave[player] = success

	local profile = DataService.defaultProfile()
	local isNew = true
	if type(data) == "table" then
		isNew = false
		profile.Pesos = tonumber(data.Pesos) or profile.Pesos
		profile.DaysPlayed = tonumber(data.DaysPlayed) or 0
		if type(data.Needs) == "table" then
			for id in profile.Needs do
				profile.Needs[id] = tonumber(data.Needs[id]) or profile.Needs[id]
			end
		end
		profile.Skills = if type(data.Skills) == "table" then data.Skills else {}
		profile.Relationships = if type(data.Relationships) == "table" then data.Relationships else {}
		profile.Furniture = if type(data.Furniture) == "table" then data.Furniture else nil
	end
	return profile, isNew
end

-- Push a profile into player attributes (the live source of truth while playing).
function DataService.apply(player: Player, profile)
	player:SetAttribute("Pesos", profile.Pesos)
	player:SetAttribute("DaysPlayed", profile.DaysPlayed)
	for _, id in Config.NeedOrder do
		player:SetAttribute("Need_" .. id, profile.Needs[id])
	end
	for id in Config.Skills do
		player:SetAttribute("Skill_" .. id, tonumber(profile.Skills[id]) or 0)
	end
	for _, npc in Config.NPCs do
		player:SetAttribute("Rel_" .. npc.id, tonumber(profile.Relationships[npc.id]) or 0)
	end
end

function DataService.collect(player: Player, furniture: { any })
	local profile = DataService.defaultProfile()
	profile.Pesos = player:GetAttribute("Pesos") or 0
	profile.DaysPlayed = player:GetAttribute("DaysPlayed") or 0
	for _, id in Config.NeedOrder do
		profile.Needs[id] = math.floor((player:GetAttribute("Need_" .. id) or 85) * 10) / 10
	end
	for id in Config.Skills do
		profile.Skills[id] = player:GetAttribute("Skill_" .. id) or 0
	end
	for _, npc in Config.NPCs do
		profile.Relationships[npc.id] = player:GetAttribute("Rel_" .. npc.id) or 0
	end
	profile.Furniture = furniture
	return profile
end

function DataService.save(player: Player, furniture: { any })
	if not store or not canSave[player] or not player:GetAttribute("Loaded") then
		return
	end
	local profile = DataService.collect(player, furniture)
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function()
			return profile
		end)
	end)
	if not ok then
		warn("[Bahay Buhay] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.release(player: Player)
	canSave[player] = nil
end

return DataService
