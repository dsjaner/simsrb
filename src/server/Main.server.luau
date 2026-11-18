--[[
	Bahay Buhay — a Filipino-themed life simulation.
	Server entry point: builds the world and wires all services together.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local Services = script.Parent:WaitForChild("Services")
local Remotes = require(Services.Remotes)
local Overhead = require(Services.Overhead)
local NeedsService = require(Services.NeedsService)
local ActionService = require(Services.ActionService)
local StationService = require(Services.StationService)
local LotService = require(Services.LotService)
local BuildService = require(Services.BuildService)
local DataService = require(Services.DataService)
local TimeService = require(Services.TimeService)
local NPCService = require(Services.NPCService)
local WorldBuilder = require(Services.WorldBuilder)

NeedsService.bind(ActionService)

-- 1) World
StationService.init()
WorldBuilder.build()
LotService.init()
NPCService.init()
TimeService.init()

-- 2) Systems
ActionService.init()
NeedsService.start()
BuildService.init()

--------------------------------------------------------------------------
-- Players
--------------------------------------------------------------------------
local function teleportHome(player: Player)
	local lot = LotService.get(player)
	local character = player.Character
	if lot and character then
		ActionService.stop(player, "cancel")
		character:PivotTo(LotService.spawnCFrame(lot))
	end
end

local function onCharacterAdded(player: Player, character: Model)
	task.spawn(Overhead.attach, character)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.WalkSpeed = Config.WalkSpeed
	end
	character:WaitForChild("HumanoidRootPart", 10)
	task.wait() -- let the default spawn finish before moving the character
	teleportHome(player)
end

local function onPlayerAdded(player: Player)
	player.CameraMaxZoomDistance = 90

	local profile, isNew = DataService.load(player)
	if not player.Parent then
		return -- left while loading
	end
	DataService.apply(player, profile)

	local lot = LotService.assign(player)
	if lot then
		BuildService.load(player, profile.Furniture)
	end

	player:SetAttribute("Loaded", true)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end

	task.delay(3, function()
		if not player.Parent then
			return
		end
		if isNew then
			Remotes.notify(player, "🏠 Mabuhay! Maligayang pagdating sa Barangay Bahay Buhay!", "good")
			Remotes.notify(player, "May " .. Util.formatPesos(Config.StartingPesos) .. " kang puhunan. Alagaan ang sarili, magtrabaho, at pagandahin ang bahay mo!", "info")
		else
			Remotes.notify(player, "🏠 Maligayang pagbabalik, " .. player.DisplayName .. "!", "good")
		end
		if not lot then
			Remotes.notify(player, "Puno na ang mga lote sa barangay. Makikitira ka muna sa plaza!", "warn")
		end
	end)
end

local function savePlayer(player: Player)
	DataService.save(player, BuildService.serialize(player))
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	ActionService.stop(player, "leave")
	savePlayer(player) -- must happen before the lot is cleared
	LotService.release(player)
	DataService.release(player)
end)

Remotes.GoHome.OnServerEvent:Connect(function(player)
	if LotService.get(player) then
		teleportHome(player)
	else
		Remotes.notify(player, "Wala kang sariling lote.", "warn")
	end
end)

-- Autosave
task.spawn(function()
	while true do
		task.wait(Config.AutosaveSeconds)
		for _, player in Players:GetPlayers() do
			task.spawn(savePlayer, player)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			savePlayer(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.2)
	end
end)

--------------------------------------------------------------------------
-- Every morning: bills, relationship decay, greeting
--------------------------------------------------------------------------
TimeService.onMorning(function(day)
	for _, player in Players:GetPlayers() do
		if not player:GetAttribute("Loaded") then
			continue
		end
		player:SetAttribute("DaysPlayed", (player:GetAttribute("DaysPlayed") or 0) + 1)
		player:SetAttribute("EarnedToday", 0)

		local bill = Config.BillBase + Config.BillPerFurniture * BuildService.count(player)
		local pesos = player:GetAttribute("Pesos") or 0
		local paid = math.min(bill, pesos)
		player:SetAttribute("Pesos", pesos - paid)

		Remotes.notify(player, string.format("☀️ Magandang umaga! Araw %d na.", day), "info")
		if paid < bill then
			Remotes.notify(player, "⚠️ Kulang ang pambayad sa kuryente at tubig! Magtrabaho ka na.", "bad")
			NeedsService.add(player, "Fun", -15)
		else
			Remotes.notify(player, "🧾 Bayad na ang kuryente at tubig: " .. Util.formatPesos(bill), "info")
		end

		for _, npc in Config.NPCs do
			local key = "Rel_" .. npc.id
			player:SetAttribute(key, math.max(0, (player:GetAttribute(key) or 0) - Config.RelationshipDailyDecay))
		end
	end
end)

print(string.format("[%s v%s] Handa na ang barangay!", Config.GameName, Config.Version))
