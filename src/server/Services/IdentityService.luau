--[[
	IdentityService — "Ikot ng Kapalaran". Rolls a new player's starting life:
	hometown, Yaman (wealth), Swerte (luck), DNA (talent), a natural talent skill,
	and their parents' jobs (derived from hometown + Yaman, never shown as characters).

	The roll happens on the server once and is saved, so rejoining never re-rolls.
	The client only animates the reveal of the result.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(script.Parent.Remotes)

local IdentityService = {}

local rng = Random.new()

local function weightedPick(entries: { any }, weightOf: (any) -> number): number
	local total = 0
	for _, e in entries do
		total += weightOf(e)
	end
	local roll = rng:NextNumber() * total
	for i, e in entries do
		roll -= weightOf(e)
		if roll <= 0 then
			return i
		end
	end
	return #entries
end

function IdentityService.roll()
	local cityIndex = weightedPick(Config.CityOrder, function(id)
		return Config.Cities[id].weight
	end)
	local hometown = Config.CityOrder[cityIndex]
	local identity = { Hometown = hometown }
	for _, metric in Config.MetricOrder do
		identity[metric] = weightedPick(Config.Metrics[metric].tiers, function(t)
			return t.weight
		end)
	end
	identity.Talent = Config.SkillOrder[rng:NextInteger(1, #Config.SkillOrder)]
	local pair = Config.ParentJobs[hometown][identity.Yaman]
	if rng:NextNumber() < 0.5 then
		identity.Papa, identity.Mama = pair[1], pair[2]
	else
		identity.Papa, identity.Mama = pair[2], pair[1]
	end
	return identity
end

-- Validates a saved identity table; returns nil if anything is off (so we re-roll).
function IdentityService.sanitize(data: any)
	if type(data) ~= "table" or not Config.Cities[data.Hometown] then
		return nil
	end
	for _, metric in Config.MetricOrder do
		local tier = data[metric]
		if type(tier) ~= "number" or tier < 1 or tier > 3 then
			return nil
		end
	end
	if not Config.Skills[data.Talent] or not Config.Professions[data.Papa] or not Config.Professions[data.Mama] then
		return nil
	end
	return data
end

function IdentityService.apply(player: Player, identity)
	player:SetAttribute("Hometown", identity.Hometown)
	for _, metric in Config.MetricOrder do
		player:SetAttribute(metric, identity[metric])
	end
	player:SetAttribute("Talent", identity.Talent)
	player:SetAttribute("Papa", identity.Papa)
	player:SetAttribute("Mama", identity.Mama)
end

function IdentityService.collect(player: Player)
	local identity = { Hometown = player:GetAttribute("Hometown") }
	for _, metric in Config.MetricOrder do
		identity[metric] = player:GetAttribute(metric)
	end
	identity.Talent = player:GetAttribute("Talent")
	identity.Papa = player:GetAttribute("Papa")
	identity.Mama = player:GetAttribute("Mama")
	return IdentityService.sanitize(identity)
end

-- Story messages from the (unseen) parents right after the reveal.
local function introStory(player: Player)
	local yaman = player:GetAttribute("Yaman") or 2
	local city = Config.city(player:GetAttribute("Hometown"))
	local papa = Config.Professions[player:GetAttribute("Papa")]
	local mama = Config.Professions[player:GetAttribute("Mama")]
	Remotes.notify(player, string.format("%s Ipinanganak ka sa %s. Si Papa ay %s, si Mama ay %s.",
		city.icon, city.name, papa.label:lower(), mama.label:lower()), "info")
	task.wait(3)
	Remotes.notify(player, Config.ParentIntro[yaman], "info")
	task.wait(3)
	if not player:GetAttribute("Profession") then
		Remotes.notify(player, "💼 Wala ka pang trabaho. Pumunta sa PESO Office para mag-apply!", "warn")
	end
end

-- Morning "padala" from parents, scaled by Yaman.
function IdentityService.morningAllowance(player: Player)
	local yaman = player:GetAttribute("Yaman") or 2
	local amount = Config.YamanEffects.dailyAllowance[yaman] or 0
	if amount > 0 then
		player:SetAttribute("Pesos", (player:GetAttribute("Pesos") or 0) + amount)
		local who = if math.random() < 0.5 then "Papa" else "Mama"
		Remotes.notify(player, string.format("📱 %s: Nagpadala ako ng %s pang-gastos mo. Ingat, anak!", who, Util.formatPesos(amount)), "good")
	elseif math.random() < 0.35 then
		Remotes.notify(player, "📱 Mama: Anak, kumusta ka na? Pasensya na at wala kaming maipadala ngayon.", "info")
	end
end

function IdentityService.init()
	Remotes.IdentitySeen.OnServerEvent:Connect(function(player)
		if player:GetAttribute("IdentitySeen") then
			return
		end
		player:SetAttribute("IdentitySeen", true)
		task.spawn(introStory, player)
	end)
end

return IdentityService
