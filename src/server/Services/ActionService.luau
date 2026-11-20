--[[
	ActionService — runs timed interactions (sleeping, cooking, working, chatting…).

	Flow: StationService (prompt/menu) → ActionService.start(player, station, actionId)
	      → character is positioned at the station's UsePoint
	      → every tick: needs change, pay & skill xp accumulate, progress updates
	      → finishes after `duration`, or is cancelled (player moves / jumps / presses Itigil).

	Replicated state lives in player attributes:
	  CurrentAction (string verb) and ActionProgress (0..1).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(script.Parent.Remotes)
local Overhead = require(script.Parent.Overhead)
local NeedsService = require(script.Parent.NeedsService)

local ActionService = {}

type ActiveAction = {
	id: string,
	def: any,
	station: Model?,
	elapsed: number,
	paidFraction: number,
	xpFraction: number,
	xpMult: number,
	seat: Seat?,
	lying: boolean,
	effectMult: number,
	payMult: number,
}

local active: { [Player]: ActiveAction } = {}
local TICK = 0.25
local FISH = { "bangus", "tilapia", "galunggong", "lapu-lapu", "tamban", "dilis", "tulingan" }

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------
local function getParts(player: Player)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil
	end
	return humanoid, root
end

local function skillLevel(player: Player, skill: string?): number
	if not skill then
		return 0
	end
	return Config.skillLevel(player:GetAttribute("Skill_" .. skill))
end

local function addSkillXp(player: Player, skill: string, xp: number)
	local key = "Skill_" .. skill
	local before = player:GetAttribute(key) or 0
	local after = before + xp
	player:SetAttribute(key, after)
	local oldLevel, newLevel = Config.skillLevel(before), Config.skillLevel(after)
	if newLevel > oldLevel then
		local info = Config.Skills[skill]
		Remotes.notify(player, string.format("%s Tumaas ang %s mo! Level %d na.", info.icon, info.label, newLevel), "good")
	end
end

local function addRelationship(player: Player, npcId: string, amount: number)
	local key = "Rel_" .. npcId
	local before = player:GetAttribute(key) or 0
	local after = math.clamp(before + amount, 0, 100)
	player:SetAttribute(key, after)
	local oldLabel, newLabel = Config.relationshipLabel(before), Config.relationshipLabel(after)
	local npc = Config.NPCById[npcId]
	if npc and oldLabel ~= newLabel and after > before then
		Remotes.notify(player, string.format("❤️ %s mo na si %s!", newLabel, npc.name), "good")
	end
end

local function otherPlayerNearby(player: Player, position: Vector3, radius: number): boolean
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			local root = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - position).Magnitude <= radius then
				return true
			end
		end
	end
	return false
end

local function standOffset(humanoid: Humanoid, root: BasePart): number
	return humanoid.HipHeight + root.Size.Y / 2
end

local function stationUsable(station: Model, player: Player): (boolean, string?)
	local userId = station:GetAttribute("InUseBy")
	if userId and userId ~= player.UserId and Players:GetPlayerByUserId(userId) then
		local npcId = station:GetAttribute("NpcId")
		if npcId then
			return false, "Abala pa si " .. Config.NPCById[npcId].name .. ". Hintay lang."
		end
		return false, "May gumagamit pa nito. Hintay lang."
	end
	return true
end

-- Move the character into position for the action.
local function positionCharacter(state: ActiveAction, humanoid: Humanoid, root: BasePart)
	local station = state.station
	local point = station and station:FindFirstChild("UsePoint", true) :: BasePart?

	if point and point:IsA("Seat") then
		state.seat = point
		point:Sit(humanoid)
		return
	end

	root.Anchored = true
	if state.def.pose == "lie" then
		state.lying = true
		humanoid.PlatformStand = true
		local base: CFrame
		if point then
			base = point.CFrame
		else
			-- lie down right where you are (e.g. passing out)
			local yaw = select(2, root.CFrame:ToOrientation())
			local groundY = root.Position.Y - standOffset(humanoid, root)
			base = CFrame.new(root.Position.X, groundY, root.Position.Z) * CFrame.Angles(0, yaw, 0)
		end
		root.CFrame = base * CFrame.new(0, 1, 0) * CFrame.Angles(math.pi / 2, 0, 0)
	elseif point then
		root.CFrame = point.CFrame + Vector3.new(0, standOffset(humanoid, root), 0)
	elseif station then
		local target = station:GetPivot().Position
		local pos = root.Position
		local flat = Vector3.new(target.X, pos.Y, target.Z)
		if (flat - pos).Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(pos, flat)
		end
	end
end

local function restoreCharacter(player: Player, state: ActiveAction)
	local humanoid, root = getParts(player)
	if not humanoid or not root then
		return
	end
	if state.seat then
		local weld = state.seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		humanoid.Sit = false
		return
	end
	if state.lying then
		humanoid.PlatformStand = false
		local yaw = select(2, root.CFrame:ToOrientation())
		root.CFrame = CFrame.new(root.Position + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, yaw, 0)
	end
	root.Anchored = false
end

local function runDoneHook(player: Player, state: ActiveAction)
	local def = state.def
	if def.doneHook == "VideokeScore" then
		local score = math.clamp(math.random(55, 92) + skillLevel(player, "Pagkanta") * 2, 0, 100)
		local comment = if score >= 95
			then "PERFECT! Pang-concert ang boses mo! 🎉"
			elseif score >= 80 then "Ang galing! Palakpakan!"
			elseif score >= 65 then "Pwede na! Next song!"
			else "Medyo sintunado... pero masaya naman!"
		Remotes.notify(player, string.format("🎤 Videoke score: %d — %s", score, comment), "good")
		if score >= 95 then
			NeedsService.add(player, "Fun", 10)
		end
	elseif def.doneHook == "Fishing" then
		local fish = FISH[math.random(1, #FISH)]
		Remotes.notify(player, "🐟 Nakahuli ka ng " .. fish .. "! Naibenta mo sa palengke.", "good")
	end
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------
function ActionService.isActive(player: Player): boolean
	return active[player] ~= nil
end

function ActionService.currentActionId(player: Player): string?
	local state = active[player]
	return state and state.id
end

-- True while the current action is raising this need (so it doesn't also decay).
function ActionService.isBoosting(player: Player, needId: string): boolean
	local state = active[player]
	return state ~= nil and (state.def.effects[needId] or 0) > 0
end

function ActionService.stop(player: Player, reason: string?)
	local state = active[player]
	if not state then
		return
	end
	active[player] = nil

	if state.station and state.station.Parent then
		state.station:SetAttribute("InUseBy", nil)
	end
	player:SetAttribute("CurrentAction", nil)
	player:SetAttribute("ActionProgress", nil)
	Overhead.setBubble(player, nil)
	restoreCharacter(player, state)

	if reason == "done" then
		local def = state.def
		if def.relationship and state.station then
			local npcId = state.station:GetAttribute("NpcId")
			if npcId then
				addRelationship(player, npcId, def.relationship)
			end
		end
		runDoneHook(player, state)
		if def.doneMessages then
			Remotes.notify(player, def.doneMessages[math.random(1, #def.doneMessages)], "good")
		end
	end
end

local function begin(player: Player, actionId: string, station: Model?): (boolean, string?)
	local def = Config.Actions[actionId]
	if not def then
		return false, "Hindi kilalang gawain."
	end
	local humanoid, root = getParts(player)
	if not humanoid or not root then
		return false, nil
	end

	if def.profession and player:GetAttribute("Profession") ~= def.profession then
		local prof = Config.Professions[def.profession]
		return false, "💼 Hindi ito ang trabaho mo. Mag-apply muna bilang " .. prof.label .. " sa PESO Office."
	end

	if def.hours and not Util.inHours(Lighting.ClockTime, def.hours) then
		return false, string.format(
			"⏰ Hindi pa pwede ngayon. Bukas mula %s hanggang %s.",
			Util.formatHour(def.hours[1]),
			Util.formatHour(def.hours[2])
		)
	end

	if station then
		local ok, msg = stationUsable(station, player)
		if not ok then
			return false, msg
		end
	end

	local cityId = station and station:GetAttribute("City")
	local cost = Config.scaledCost(def, cityId)
	local pesos = player:GetAttribute("Pesos") or 0
	if cost > pesos then
		return false, "💸 Kulang ang pera mo! Kailangan mo ng " .. Util.formatPesos(cost) .. "."
	end

	if active[player] then
		ActionService.stop(player, "switch")
	end

	if cost > 0 then
		player:SetAttribute("Pesos", pesos - cost)
	end

	local level = skillLevel(player, def.skill)
	local state: ActiveAction = {
		id = actionId,
		def = def,
		station = station,
		elapsed = 0,
		paidFraction = 0,
		xpFraction = 0,
		seat = nil,
		lying = false,
		effectMult = if def.skillBoost then 1 + level * Config.SkillEffectBonus else 1,
		payMult = NeedsService.getMood(player).payMult
			* (if def.payBoost then 1 + level * Config.SkillPayBonus else 1)
			* Config.city(cityId).payMult,
		xpMult = Config.xpMultiplier(player, def.skill),
	}
	active[player] = state

	if station then
		station:SetAttribute("InUseBy", player.UserId)
	end
	player:SetAttribute("CurrentAction", def.verb or def.label)
	player:SetAttribute("ActionProgress", 0)
	Overhead.setBubble(player, def.bubble)
	positionCharacter(state, humanoid, root)
	return true, nil
end

function ActionService.start(player: Player, station: Model, actionId: string)
	local ok, msg = begin(player, actionId, station)
	if not ok and msg then
		Remotes.notify(player, msg, "warn")
	end
	return ok
end

-- Actions not tied to an object (e.g. passing out from exhaustion).
function ActionService.startSpecial(player: Player, actionId: string)
	local ok, msg = begin(player, actionId, nil)
	if not ok and msg then
		Remotes.notify(player, msg, "warn")
	end
	return ok
end

local function step(player: Player, state: ActiveAction, dt: number)
	local humanoid, root = getParts(player)
	if not humanoid or not root then
		ActionService.stop(player, "cancel")
		return
	end
	if state.station and not state.station.Parent then
		ActionService.stop(player, "cancel")
		return
	end
	if state.seat and humanoid.SeatPart ~= state.seat then
		-- give Seat:Sit a moment to weld before treating it as "stood up"
		if state.elapsed > 0.75 then
			ActionService.stop(player, "cancel")
			return
		end
	end

	local def = state.def
	local frac = math.min(dt, def.duration - state.elapsed) / def.duration
	state.elapsed += dt

	for needId, amount in def.effects do
		local mult = if amount > 0 then state.effectMult else 1
		NeedsService.add(player, needId, amount * frac * mult)
	end
	if def.socialNearby and otherPlayerNearby(player, root.Position, 18) then
		NeedsService.add(player, "Social", def.socialNearby * frac)
	end

	if def.pay then
		state.paidFraction += def.pay * frac * state.payMult
		local whole = math.floor(state.paidFraction)
		if whole > 0 then
			state.paidFraction -= whole
			player:SetAttribute("Pesos", (player:GetAttribute("Pesos") or 0) + whole)
			player:SetAttribute("EarnedToday", (player:GetAttribute("EarnedToday") or 0) + whole)
		end
	end

	if def.skill and def.skillXp then
		state.xpFraction += def.skillXp * frac * state.xpMult
		if state.xpFraction >= 1 then
			local whole = math.floor(state.xpFraction)
			state.xpFraction -= whole
			addSkillXp(player, def.skill, whole)
		end
	end

	player:SetAttribute("ActionProgress", math.clamp(state.elapsed / def.duration, 0, 1))
	if state.elapsed >= def.duration then
		ActionService.stop(player, "done")
	end
end

function ActionService.init()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local now = os.clock()
			local dt = now - last
			last = now
			for player, state in active do
				step(player, state, dt)
			end
		end
	end)

	Remotes.CancelAction.OnServerEvent:Connect(function(player)
		ActionService.stop(player, "cancel")
	end)
	Players.PlayerRemoving:Connect(function(player)
		ActionService.stop(player, "leave")
	end)
end

return ActionService
