--[[
	NeedsService — needs decay over time, mood, low-need warnings and consequences.
	Needs are stored as player attributes ("Need_Hunger" …) so the client UI can read them directly.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(script.Parent.Remotes)
local Overhead = require(script.Parent.Overhead)

local NeedsService = {}

local actions -- ActionService, injected via bind() to avoid a circular require
local warned: { [Player]: { [string]: boolean } } = {}

function NeedsService.bind(actionService)
	actions = actionService
end

function NeedsService.get(player: Player, id: string): number
	return player:GetAttribute("Need_" .. id) or 100
end

function NeedsService.set(player: Player, id: string, value: number)
	player:SetAttribute("Need_" .. id, math.clamp(value, 0, 100))
end

function NeedsService.add(player: Player, id: string, delta: number)
	NeedsService.set(player, id, NeedsService.get(player, id) + delta)
end

function NeedsService.getMood(player: Player)
	return Config.getMood(Util.averageNeeds(player, Config.NeedOrder))
end

local function checkWarnings(player: Player)
	local state = warned[player]
	if not state then
		state = {}
		warned[player] = state
	end
	for _, id in Config.NeedOrder do
		local value = NeedsService.get(player, id)
		if value < 20 and not state[id] then
			state[id] = true
			Remotes.notify(player, Config.Needs[id].icon .. " " .. Config.Needs[id].lowText, "warn")
		elseif value > 35 then
			state[id] = nil
		end
	end
end

local function applyConsequences(player: Player)
	local busy = actions and actions.isActive(player)
	local currentId = actions and actions.currentActionId(player)

	-- Bagsak sa pagod: fall asleep on the spot
	if NeedsService.get(player, "Energy") <= 0 and not busy and actions then
		Remotes.notify(player, "😵 Bumagsak ka sa sobrang pagod! Nakatulog ka sa sahig.", "bad")
		actions.startSpecial(player, "Nahimatay")
	end

	-- Naihi sa salawal
	if NeedsService.get(player, "Bladder") <= 0 and currentId ~= "MagCR" then
		NeedsService.set(player, "Bladder", 100)
		NeedsService.set(player, "Hygiene", 0)
		NeedsService.add(player, "Fun", -15)
		Remotes.notify(player, "😳 Naku! Hindi ka umabot sa CR... Nakakahiya! Maligo ka na.", "bad")
	end

	-- Walk slower when hungry or exhausted
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local tired = NeedsService.get(player, "Energy") < 12 or NeedsService.get(player, "Hunger") < 10
		humanoid.WalkSpeed = if tired then Config.TiredWalkSpeed else Config.WalkSpeed
	end
end

function NeedsService.tick(dt: number)
	for _, player in Players:GetPlayers() do
		if not player:GetAttribute("Loaded") then
			continue
		end
		for _, id in Config.NeedOrder do
			if not (actions and actions.isBoosting(player, id)) then
				NeedsService.add(player, id, -Config.Needs[id].decayPerMinute / 60 * dt)
			end
		end
		local mood = NeedsService.getMood(player)
		player:SetAttribute("Mood", mood.label)
		Overhead.setMoodColor(player, mood.color)
		checkWarnings(player)
		applyConsequences(player)
	end
end

function NeedsService.start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			NeedsService.tick(now - last)
			last = now
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		warned[player] = nil
	end)
end

return NeedsService
