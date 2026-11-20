--[[
	TravelService — provincial buses connecting the three cities in the shared world.

	Each route has buses that shuttle between two terminals on a schedule:
	  boarding (dwell) → fare collected at departure → drive the road → arrive → repeat.
	Passengers sit together (they can chat!) and may get surprise trip events,
	weighted by their Swerte (luck): coins, a generous ninong, a pickpocket...
	Press Space (jump) to get off.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(ReplicatedStorage.Shared.Models)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(script.Parent.Remotes)
local NeedsService = require(script.Parent.NeedsService)
local ActionService = require(script.Parent.ActionService)

local TravelService = {}

local LANE_OFFSET = 5
local routePoints: { [string]: { Vector3 } } = {}
local folder: Folder
local rng = Random.new()

type Path = { points: { Vector3 }, cumulative: { number }, total: number }

--------------------------------------------------------------------------
-- Path helpers
--------------------------------------------------------------------------
local function laneOf(points: { Vector3 }, offset: number): { Vector3 }
	local out = {}
	for i, p in points do
		local a = points[math.max(1, i - 1)]
		local b = points[math.min(#points, i + 1)]
		local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		if dir.Magnitude < 1e-3 then
			dir = Vector3.new(1, 0, 0)
		end
		local right = dir.Unit:Cross(Vector3.yAxis)
		out[i] = p + right * offset
	end
	return out
end

local function reversed(points: { Vector3 }): { Vector3 }
	local out = {}
	for i = #points, 1, -1 do
		table.insert(out, points[i])
	end
	return out
end

local function makePath(points: { Vector3 }): Path
	local cumulative = { 0 }
	for i = 2, #points do
		cumulative[i] = cumulative[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	return { points = points, cumulative = cumulative, total = cumulative[#points] }
end

local function sample(path: Path, distance: number): (Vector3, Vector3)
	local pts, cum = path.points, path.cumulative
	distance = math.clamp(distance, 0, path.total)
	for i = 2, #pts do
		if distance <= cum[i] or i == #pts then
			local segLen = cum[i] - cum[i - 1]
			local t = if segLen > 0 then (distance - cum[i - 1]) / segLen else 0
			local dir = pts[i] - pts[i - 1]
			return pts[i - 1]:Lerp(pts[i], t), if dir.Magnitude > 0 then dir.Unit else Vector3.new(1, 0, 0)
		end
	end
	return pts[#pts], Vector3.new(1, 0, 0)
end

local function flatLook(pos: Vector3, dir: Vector3): CFrame
	-- keep the bus level-ish on slopes: only pitch slightly with the road
	return CFrame.lookAt(pos, pos + dir)
end

--------------------------------------------------------------------------
-- Passengers
--------------------------------------------------------------------------
local function occupantPlayer(seat: Seat): Player?
	local humanoid = seat.Occupant
	return humanoid and Players:GetPlayerFromCharacter(humanoid.Parent) or nil
end

local function unseat(seat: Seat)
	local humanoid = seat.Occupant
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	if humanoid then
		humanoid.Sit = false
		humanoid.Jump = true
	end
end

local function pickEvent(player: Player)
	local swerte = player:GetAttribute("Swerte") or 2
	local goodMult = Config.SwerteEffects.goodEventMult[swerte] or 1
	local badMult = Config.SwerteEffects.badEventMult[swerte] or 1
	local total = 0
	for _, e in Config.TripEvents do
		total += e.weight * (if e.good then goodMult else badMult)
	end
	local roll = rng:NextNumber() * total
	for _, e in Config.TripEvents do
		roll -= e.weight * (if e.good then goodMult else badMult)
		if roll <= 0 then
			return e
		end
	end
	return Config.TripEvents[1]
end

local function applyEvent(player: Player, event)
	local text = event.text
	if event.pesos then
		local amount = rng:NextInteger(event.pesos[1], event.pesos[2])
		local pesos = player:GetAttribute("Pesos") or 0
		if amount < 0 then
			amount = -math.min(-amount, pesos)
			if amount == 0 then
				-- nothing to steal: turn it into a near-miss
				Remotes.notify(player, "😅 Muntik ka nang madukutan, pero wala ka namang pera. Haha!", "info")
				return
			end
		end
		player:SetAttribute("Pesos", pesos + amount)
		text = string.format(text, Util.formatPesos(math.abs(amount)))
	end
	if event.effects then
		for need, delta in event.effects do
			NeedsService.add(player, need, delta)
		end
	end
	Remotes.notify(player, text, if event.good then "good" else "bad")
end

--------------------------------------------------------------------------
-- Bus loop
--------------------------------------------------------------------------
local function runBus(cfg, points: { Vector3 }, index: number)
	local forward = makePath(laneOf(points, LANE_OFFSET))
	local backward = makePath(laneOf(reversed(points), LANE_OFFSET))

	local bus = Models.build("Bus", cfg.color, "")
	bus.Name = cfg.id .. "Bus" .. index
	bus.Parent = folder
	local seats: { Seat } = {}
	for _, d in bus:GetDescendants() do
		if d:IsA("Seat") and d.Name == "BusSeat" then
			table.insert(seats, d)
		end
	end
	local routeLabel = bus:FindFirstChild("RouteLabel", true) :: TextLabel?
	local promptPart = bus:FindFirstChild("PromptPart", true) :: BasePart

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sumakay"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart

	local atA = index % 2 == 1
	local moving = false
	local destination = cfg.b

	prompt.Triggered:Connect(function(player)
		if moving then
			Remotes.notify(player, "🚌 Umaandar na ang bus. Hintayin ang susunod na biyahe.", "warn")
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then
			return
		end
		for _, seat in seats do
			if not seat.Occupant then
				ActionService.stop(player, "cancel")
				seat:Sit(humanoid)
				local city = Config.city(destination)
				Remotes.notify(player, string.format("🚌 Sumakay ka sa bus papuntang %s %s. Pamasahe: %s (babayaran pag-alis). Space para bumaba.",
					city.icon, city.name, Util.formatPesos(cfg.fare)), "info")
				return
			end
		end
		Remotes.notify(player, "Puno na ang bus! Hintayin ang susunod.", "warn")
	end)

	while bus.Parent do
		local path = if atA then forward else backward
		destination = if atA then cfg.b else cfg.a
		local destCity = Config.city(destination)
		if routeLabel then
			routeLabel.Text = "→ " .. destCity.name:upper()
		end
		prompt.ObjectText = string.format("Bus papuntang %s (%s)", destCity.name, Util.formatPesos(cfg.fare))
		prompt.Enabled = true

		-- park at the terminal facing the way we'll leave
		local startPos, startDir = sample(path, 0)
		bus:PivotTo(flatLook(startPos, startDir))
		moving = false
		task.wait(cfg.dwellSeconds)

		-- collect fares
		moving = true
		prompt.Enabled = false
		local riders: { [Player]: boolean } = {}
		for _, seat in seats do
			local player = occupantPlayer(seat)
			if player then
				local pesos = player:GetAttribute("Pesos") or 0
				if pesos >= cfg.fare then
					player:SetAttribute("Pesos", pesos - cfg.fare)
					riders[player] = true
					Remotes.notify(player, "🎫 Nagbayad ka ng " .. Util.formatPesos(cfg.fare) .. ". Aalis na ang bus!", "info")
				else
					unseat(seat)
					Remotes.notify(player, "💸 Kulang ang pamasahe mo. Pinababa ka ng konduktor.", "bad")
				end
			end
		end

		-- drive
		local elapsed = 0
		local nextRoll = 1
		while elapsed < cfg.tripSeconds and bus.Parent do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt
			local pos, dir = sample(path, elapsed / cfg.tripSeconds * path.total)
			local current = bus:GetPivot()
			local target = flatLook(pos, dir)
			local rotation = current.Rotation:Lerp(target.Rotation, math.min(1, dt * 3))
			bus:PivotTo(CFrame.new(pos) * rotation)

			local threshold = Config.TripEventRolls[nextRoll]
			if threshold and elapsed / cfg.tripSeconds >= threshold then
				nextRoll += 1
				for _, seat in seats do
					local player = occupantPlayer(seat)
					if player and riders[player] and rng:NextNumber() < Config.TripEventChance then
						applyEvent(player, pickEvent(player))
					end
				end
			end
		end

		-- arrive
		for _, seat in seats do
			local player = occupantPlayer(seat)
			if player and riders[player] then
				Remotes.notify(player, string.format("📍 Nakarating ka na sa %s %s! Pindutin ang Space para bumaba.",
					destCity.icon, destCity.name), "good")
			end
		end
		atA = not atA
	end
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------

-- Called by WorldBuilder with the road's centre-line points (terminal A → terminal B).
function TravelService.addRoute(routeId: string, points: { Vector3 })
	routePoints[routeId] = points
end

function TravelService.init()
	folder = Instance.new("Folder")
	folder.Name = "Buses"
	folder.Parent = workspace
	for _, cfg in Config.Routes do
		local points = routePoints[cfg.id]
		if points then
			for i = 1, cfg.buses do
				task.spawn(runBus, cfg, points, i)
			end
		else
			warn("[Bahay Buhay] No road built for route " .. cfg.id)
		end
	end
end

return TravelService
