--[[
	WorldBuilder — builds Barangay Bahay Buhay at server start.

	Map (top view, +X east, +Z north):

	              [Lot1]   [Lot2]   [Lot3]                [Simbahan]
	   beach  ─────────── ring road ───────────
	   & sea  │ Karinderya   Videoke            │
	  (bangka)│        Bantayog   Basketball    │── road ── Jeepney terminal
	          │ Sari-sari    Poso               │           Palengke
	           ─────────── ring road ───────────
	              [Lot4]   [Lot5]   [Lot6]            [Barangay Hall]
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Models = require(ReplicatedStorage.Shared.Models)
local Util = require(ReplicatedStorage.Shared.Util)
local StationService = require(script.Parent.StationService)

local WorldBuilder = {}

local C = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local MAT = Enum.Material

local world: Folder

local function part(props)
	props.Parent = props.Parent or world
	return Util.part(props)
end

-- Build a model, place it, and make it interactive if it's a station.
local function place(id: string, cf: CFrame, ...): Model
	local model = Models.build(id, ...)
	model:PivotTo(cf)
	model.Parent = world
	if model:GetAttribute("StationId") then
		StationService.make(model)
	end
	return model
end

local function setupLighting()
	Lighting.Brightness = 2.4
	Lighting.Ambient = C(95, 85, 75)
	Lighting.OutdoorAmbient = C(150, 140, 125)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.GeographicLatitude = 13 -- roughly the latitude of Bicol / Luzon

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = C(215, 200, 180)
	atmosphere.Decay = C(120, 110, 140)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.18
	color.Contrast = 0.06
	color.TintColor = C(255, 248, 235)
	color.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.8
	rays.Parent = Lighting
end

local function buildGround()
	part({ Name = "Lupa", Size = V(460, 2, 600), CFrame = CF(80, -1, 0), Color = C(98, 160, 72), Material = MAT.Grass })
	-- beach & sea
	part({ Name = "Buhangin", Size = V(62, 1.6, 600), CFrame = CF(-131, -0.6, 0), Color = C(236, 214, 160), Material = MAT.Sand })
	local terrain = workspace.Terrain
	terrain:FillBlock(CF(-245, -10, 0), V(190, 4, 600), Enum.Material.Sand)
	terrain:FillBlock(CF(-245, -4, 0), V(190, 8, 600), Enum.Material.Water)
	terrain.WaterColor = C(40, 150, 170)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
end

local function road(cf: CFrame, size: Vector3, dashedAlongZ: boolean)
	part({ Name = "Kalsada", Size = size, CFrame = cf, Color = C(60, 60, 64), Material = MAT.Asphalt })
	local length = if dashedAlongZ then size.Z else size.X
	local count = math.floor(length / 8)
	for i = 0, count - 1 do
		local offset = -length / 2 + 4 + i * 8
		local local_ = if dashedAlongZ then CF(0, size.Y / 2 + 0.01, offset) else CF(offset, size.Y / 2 + 0.01, 0)
		part({
			Size = if dashedAlongZ then V(0.4, 0.02, 4) else V(4, 0.02, 0.4),
			CFrame = cf * local_,
			Color = C(250, 220, 80),
			Material = MAT.SmoothPlastic,
			CanCollide = false,
		})
	end
end

local function buildRoads()
	road(CF(0, 0.1, 65), V(150, 0.2, 20), false)
	road(CF(0, 0.1, -65), V(150, 0.2, 20), false)
	road(CF(65, 0.1, 0), V(20, 0.2, 110), true)
	road(CF(-65, 0.1, 0), V(20, 0.2, 110), true)
	road(CF(112.5, 0.1, 0), V(75, 0.2, 20), false)
	-- dirt paths from each lot's gate to the ring road
	for _, x in { -60, 0, 60 } do
		for _, z in { 81, -81 } do
			part({ Size = V(6, 0.1, 12), CFrame = CF(x, 0.05, z), Color = C(150, 120, 85), Material = MAT.Ground })
		end
	end
end

local function buildPlaza()
	part({ Name = "Plaza", Size = V(110, 0.3, 110), CFrame = CF(0, 0.15, 0), Color = C(205, 198, 185), Material = MAT.Pavement })
	local top = 0.3
	local centre = V(0, top, 0)

	-- Basketball court (full court, two rings)
	part({ Name = "Court", Size = V(26, 0.05, 46), CFrame = CF(24, top + 0.025, 0), Color = C(196, 92, 58), Material = MAT.SmoothPlastic })
	for _, spec in {
		{ V(26, 0.06, 0.3), CF(24, top + 0.03, 23) },
		{ V(26, 0.06, 0.3), CF(24, top + 0.03, -23) },
		{ V(0.3, 0.06, 46), CF(11, top + 0.03, 0) },
		{ V(0.3, 0.06, 46), CF(37, top + 0.03, 0) },
		{ V(26, 0.06, 0.3), CF(24, top + 0.03, 0) },
	} do
		part({ Size = spec[1], CFrame = spec[2], Color = C(250, 250, 250), Material = MAT.SmoothPlastic, CanCollide = false })
	end
	place("BasketballRing", Util.facing(V(24, top, -24), V(24, top, 0)))
	place("BasketballRing", Util.facing(V(24, top, 24), V(24, top, 0)))

	-- Stores
	place("SariSari", Util.facing(V(-38, top, -36), centre))
	place("Karinderya", Util.facing(V(-38, top, 36), centre))

	-- Videoke pavilion with monobloc chairs
	place("Pavilion", CF(-12, top, 40), 16, 12)
	place("Videoke", Util.facing(V(-12, top + 0.4, 44), V(-12, top, 0)))
	for i, x in { -17, -14, -10, -7 } do
		local chair = place("Monobloc", Util.facing(V(x, top + 0.4, 36), V(-12, top, 44)) * CFrame.Angles(0, math.pi, 0),
			if i % 2 == 0 then C(240, 70, 70) else Models.Palette.white)
		chair.Name = "Monobloc"
	end

	-- Bantayog (monument) at the heart of the plaza, with benches
	place("Bantayog", CF(-14, top, 0))
	for _, spec in { { -14, -12, 0 }, { -14, 12, math.pi }, { -27, 0, math.pi / 2 } } do
		place("Bench", CF(spec[1], top, spec[2]) * CFrame.Angles(0, spec[3], 0))
	end

	place("Poso", Util.facing(V(-20, top, -18), centre))

	-- Street lamps & banderitas
	local corners = { V(-52, top, -52), V(52, top, -52), V(52, top, 52), V(-52, top, 52) }
	local tops = {}
	for i, pos in corners do
		local lamp = place("StreetLamp", Util.facing(pos, centre))
		tops[i] = (lamp:FindFirstChild("Top") :: BasePart).Position
	end
	for _, pos in { V(0, top, -52), V(0, top, 52), V(-52, top, 0), V(52, top, 0) } do
		place("StreetLamp", Util.facing(pos, centre))
	end
	local seed = 1
	local function flags(a: Vector3, b: Vector3, sag: number)
		local m = Models.build("Banderitas", a, b, sag, seed)
		seed += 1
		m.Parent = world
	end
	flags(tops[1], tops[3], 5)
	flags(tops[2], tops[4], 5)
	for i = 1, 4 do
		flags(tops[i], tops[(i % 4) + 1], 3)
	end

	-- Coconut trees around the plaza edge
	local rng = Random.new(42)
	local keepOut = { V(-38, top, -36), V(-38, top, 36), V(-12, top, 40), V(24, top, 24), V(24, top, -24) }
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local pos = V(math.cos(a) * 49, top, math.sin(a) * 49)
		local clear = true
		for _, spot in keepOut do
			if (pos - spot).Magnitude < 15 then
				clear = false
			end
		end
		if clear then
			place("CoconutTree", CF(pos), rng:NextInteger(1, 9999))
		end
	end
end

local function buildEastSide()
	-- Jeepney terminal
	place("Shed", Util.facing(V(115, 0.2, 16), V(115, 0.2, 0)))
	place("Jeepney", CF(112, 0.2, 5) * CFrame.Angles(0, math.pi / 2, 0), "BAYAN - PALENGKE")
	place("Jeepney", CF(138, 0.2, 5) * CFrame.Angles(0, math.pi / 2, 0), "BARANGAY - BAYBAY")

	-- Palengke (wet & dry market)
	part({ Size = V(42, 0.2, 18), CFrame = CF(115, 0.1, -30), Color = C(170, 165, 155), Material = MAT.Concrete })
	for i, x in { 102, 115, 128 } do
		place("Palengke", CF(x, 0.2, -28), i)
	end
	local signPost = part({ Size = V(16, 2.4, 0.4), CFrame = CF(115, 10.5, -19), Color = C(30, 110, 60) })
	Util.surfaceText(signPost, Enum.NormalId.Back, "PALENGKE NG BAYAN", C(255, 240, 200))
	for _, x in { 108, 122 } do
		part({ Size = V(0.4, 10, 0.4), CFrame = CF(x, 5.2, -19), Color = Models.Palette.metal, Material = MAT.Metal })
	end

	-- Simbahan facing the road
	place("Simbahan", Util.facing(V(126, 0, 52), V(126, 0, 0)))

	-- Barangay hall
	place("Building", Util.facing(V(125, 0.2, -88), V(125, 0.2, 0)), 30, 18, 12, C(235, 225, 200), "BARANGAY HALL")

	for _, pos in { V(90, 0.2, 18), V(90, 0.2, -18), V(140, 0.2, 18), V(140, 0.2, -18) } do
		place("StreetLamp", Util.facing(pos, V(pos.X, 0.2, 0)))
	end
end

local function buildBeach()
	local rng = Random.new(7)
	for i = 0, 13 do
		local z = -130 + i * 20 + rng:NextNumber(-5, 5)
		local x = rng:NextNumber(-150, -110)
		place("CoconutTree", CF(x, 0.2, z), rng:NextInteger(1, 9999))
	end
	place("Pavilion", CF(-125, 0.2, 40), 12, 10)
	place("Bangka", CF(-172, -0.4, 10) * CFrame.Angles(0, 0.3, 0))
	place("Bangka", CF(-180, -0.4, -22) * CFrame.Angles(0, -0.2, 0))
	place("Bangka", CF(-168, -0.4, -55) * CFrame.Angles(0, 0.1, 0))
end

local function buildSpawn()
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Plaza Spawn"
	spawn.Size = V(8, 0.4, 8)
	spawn.CFrame = CF(-2, 0.5, -22)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Models.Palette.flagYellow
	spawn.Material = MAT.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = world
end

function WorldBuilder.build()
	world = Instance.new("Folder")
	world.Name = "Barangay"
	world.Parent = workspace

	-- remove the default baseplate from a fresh template, if any
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	setupLighting()
	buildGround()
	buildRoads()
	buildPlaza()
	buildEastSide()
	buildBeach()
	buildSpawn()
end

return WorldBuilder
