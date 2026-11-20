--[[
	WorldBuilder — builds the shared world at server start: three cities in ONE map.

	   Baybay Alon (x≈0) ══ highway ══ Metro Dakila (x≈3000) ══ mountain road ══ San Bukid (x≈6000, up on a plateau)

	Baybay Alon close-up (top view, +X east, +Z north):

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

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(ReplicatedStorage.Shared.Models)
local Util = require(ReplicatedStorage.Shared.Util)
local StationService = require(script.Parent.StationService)
local TravelService = require(script.Parent.TravelService)

local WorldBuilder = {}

local C = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local MAT = Enum.Material

local root: Folder
local world: Folder -- folder of the city currently being built
local currentCity = "BaybayAlon"

local function beginCity(cityId: string)
	currentCity = cityId
	world = Instance.new("Folder")
	world.Name = cityId
	world.Parent = root
end

local function part(props)
	props.Parent = props.Parent or world
	return Util.part(props)
end

-- Build a model, place it, and make it interactive if it's a station.
-- Every model remembers which city it's in (prices and pay depend on it).
local function place(id: string, cf: CFrame, ...): Model
	local model = Models.build(id, ...)
	model:PivotTo(cf)
	model:SetAttribute("City", currentCity)
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


--------------------------------------------------------------------------
-- Shared helpers for roads between cities
--------------------------------------------------------------------------
local function strip(a: Vector3, b: Vector3, width: number, thickness: number, color: Color3, material: Enum.Material, name: string?)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	return part({
		Name = name,
		Size = V(width, thickness, len + 0.5),
		CFrame = CFrame.lookAt(mid, b) * CF(0, -thickness / 2, 0),
		Color = color,
		Material = material,
	})
end

local function disc(p: Vector3, diameter: number, thickness: number, color: Color3, material: Enum.Material)
	part({
		Shape = Enum.PartType.Cylinder,
		Size = V(thickness, diameter, diameter),
		CFrame = CF(p - V(0, thickness / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = material,
	})
end

-- Road surface (top at the given points), dashed centre line, and a wide strip of ground under it.
local function roadPath(points: { Vector3 }, width: number, groundWidth: number, groundColor: Color3)
	local asphalt = C(60, 60, 64)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		strip(a - V(0, 0.2, 0), b - V(0, 0.2, 0), groundWidth, 2, groundColor, MAT.Grass)
		strip(a, b, width, 0.2, asphalt, MAT.Asphalt, "Kalsada")
		local len = (b - a).Magnitude
		local frame = CFrame.lookAt(a, b)
		for d = 6, len - 6, 14 do
			part({ Size = V(0.4, 0.02, 5), CFrame = frame * CF(0, 0.01, -d), Color = C(250, 220, 80), Material = MAT.SmoothPlastic, CanCollide = false })
		end
		if i > 1 then
			disc(a - V(0, 0.2, 0), groundWidth, 2, groundColor, MAT.Grass)
			disc(a, width, 0.2, asphalt, MAT.Asphalt)
		end
	end
end

-- Welcome arch over the road, facing +X or -X travellers.
local function arch(pos: Vector3, text: string, color: Color3)
	for _, z in { -14, 14 } do
		part({ Size = V(2.5, 14, 2.5), CFrame = CF(pos + V(0, 7, z)), Color = color, Material = MAT.Concrete })
	end
	local beam = part({ Size = V(2, 4, 31), CFrame = CF(pos + V(0, 15, 0)), Color = color, Material = MAT.Concrete })
	Util.surfaceText(beam, Enum.NormalId.Left, text, C(255, 245, 220))
	Util.surfaceText(beam, Enum.NormalId.Right, text, C(255, 245, 220))
end

local function facingRoad(pos: Vector3, roadZ: number): CFrame
	return Util.facing(pos, V(pos.X, pos.Y, roadZ))
end

--------------------------------------------------------------------------
-- Baybay Alon additions (Phase 0): jobs, terminal, pier
--------------------------------------------------------------------------
local function buildBaybayExtras()
	place("BusTerminal", facingRoad(V(195, 0.2, 20), 0), "TERMINAL · BIYAHENG METRO DAKILA")
	place("Building", Util.facing(V(112, 0.2, -62), V(112, 0.2, 0)), 18, 12, 8, C(220, 230, 240), "PESO OFFICE", "PESO")
	place("Building", facingRoad(V(95, 0.2, 32), 0), 16, 12, 7, C(245, 245, 245), "RURAL HEALTH UNIT", "RHU")
	place("Building", facingRoad(V(145, 0.2, 30), 0), 18, 12, 8, C(250, 230, 150), "PAARALANG BAYBAY ALON", "Paaralan")
	place("ConstructionSite", facingRoad(V(170, 0.2, -40), 0))
	place("Palayan", facingRoad(V(225, 0.2, -45), 0), 11)
	place("Kalabaw", CF(240, 0.2, -66) * CFrame.Angles(0, 0.8, 0))
	place("Pantalan", CF(-150, 0.2, -90) * CFrame.Angles(0, math.pi / 2, 0))
	arch(V(260, 0.2, 0), "BAYBAY ALON · MAGANDANG BIYAHE!", C(40, 110, 170))
end

--------------------------------------------------------------------------
-- Highway: Baybay Alon ⇄ Metro Dakila
--------------------------------------------------------------------------
local HIGHWAY = {
	V(190, 0.2, 0), V(900, 0.2, 0), V(1150, 0.2, 70), V(1750, 0.2, 70), V(2000, 0.2, 0), V(2790, 0.2, 0),
}
local MOUNTAIN = {
	V(3210, 0.2, 0), V(3300, 0.2, 0), V(3700, 4.2, 0), V(4100, 12.2, 90), V(4600, 24.2, 90),
	V(5000, 32.2, -60), V(5450, 40.2, -60), V(5700, 40.2, 0), V(5790, 40.2, 0),
}

local function buildHighway()
	local grass = C(98, 160, 72)
	roadPath({ V(150, 0.2, 0), table.unpack(HIGHWAY) }, 22, 180, grass)
	local rng = Random.new(5)
	for i = 1, #HIGHWAY - 1 do
		local a, b = HIGHWAY[i], HIGHWAY[i + 1]
		local len = (b - a).Magnitude
		local side = CFrame.lookAt(a, b)
		for d = 60, len - 40, 110 do
			local sx = if rng:NextNumber() < 0.5 then -1 else 1
			local pos = (side * CF(sx * rng:NextNumber(30, 70), 0, -d)).Position
			place("CoconutTree", CF(V(pos.X, a.Y, pos.Z)), rng:NextInteger(1, 9999))
		end
		for d = 100, len - 50, 220 do
			local pos = (side * CF(14, 0, -d)).Position
			place("StreetLamp", Util.facing(V(pos.X, a.Y, pos.Z), (side * CF(0, 0, -d)).Position))
		end
	end
	for i, x in { 600, 1450, 2300 } do
		place("Bundok", CF(x, 0, if i % 2 == 0 then 260 else -240), V(320, 90, 220), C(80, 140, 70))
	end
	TravelService.addRoute("Highway", HIGHWAY)
end

local function buildMountainRoad()
	roadPath(MOUNTAIN, 18, 160, C(90, 150, 70))
	local rng = Random.new(9)
	for i = 1, #MOUNTAIN - 1 do
		local a, b = MOUNTAIN[i], MOUNTAIN[i + 1]
		local len = (b - a).Magnitude
		local frame = CFrame.lookAt(a, b)
		for d = 80, len - 60, 160 do
			local sx = if rng:NextNumber() < 0.5 then -1 else 1
			local pos = (frame * CF(sx * rng:NextNumber(30, 60), 0, -d)).Position
			place("CoconutTree", CF(pos - V(0, 0.2, 0)), rng:NextInteger(1, 9999))
		end
	end
	for i, x in { 3600, 4100, 4600, 5100, 5500 } do
		local h = 120 + i * 25
		place("Bundok", CF(x, 0, 230 + i * 10), V(360, h, 260), C(60, 120, 60))
		place("Bundok", CF(x + 150, 0, -250 - i * 8), V(340, h * 0.9, 240), C(70, 130, 65))
	end
	TravelService.addRoute("Bundok", MOUNTAIN)
end

--------------------------------------------------------------------------
-- Metro Dakila
--------------------------------------------------------------------------
local function buildMetro()
	local O = Config.Cities.MetroDakila.origin
	local function at(x, y, z)
		return O + V(x, y, z)
	end
	part({ Name = "Semento", Size = V(470, 2, 600), CFrame = CF(at(0, -1, 0)), Color = C(150, 150, 145), Material = MAT.Pavement })
	road(CF(at(0, 0.1, 0)), V(470, 0.2, 24), false)
	arch(at(-232, 0, 0), "MALIGAYANG PAGDATING SA METRO DAKILA", C(170, 40, 50))

	place("BusTerminal", facingRoad(at(-205, 0.2, -20), O.Z), "TERMINAL · BIYAHENG BAYBAY ALON")
	place("BusTerminal", facingRoad(at(205, 0.2, 20), O.Z), "TERMINAL · BIYAHENG SAN BUKID")

	-- north side (face the avenue)
	place("Building", facingRoad(at(-150, 0.2, 48), O.Z), 30, 20, 16, C(245, 245, 245), "DAKILA GENERAL HOSPITAL", "Ospital")
	place("Building", facingRoad(at(-30, 0.2, 48), O.Z), 26, 22, 14, C(230, 200, 160), "DAKILA MALL")
	place("Tower", facingRoad(at(30, 0.2, 48), O.Z), 24, 20, 12, C(90, 100, 120), "BPO", "DAKILATECH SOLUTIONS")
	place("Building", facingRoad(at(120, 0.2, 48), O.Z), 36, 22, 14, C(200, 170, 130), "PAMANTASAN NG DAKILA")
	-- south side
	place("Building", facingRoad(at(-150, 0.2, -48), O.Z), 20, 14, 9, C(220, 230, 240), "PESO OFFICE", "PESO")
	place("ConstructionSite", facingRoad(at(-30, 0.2, -48), O.Z))
	place("Palengke", facingRoad(at(30, 0.2, -40), O.Z), 7)
	place("SariSari", facingRoad(at(100, 0.2, -45), O.Z))
	place("Karinderya", facingRoad(at(168, 0.2, -42), O.Z))
	place("Jeepney", CF(at(-100, 0.2, -18)) * CFrame.Angles(0, math.pi / 2, 0), "AVENIDA - PALENGKE")

	-- skyline
	local rng = Random.new(21)
	for _, spot in { { -200, 120 }, { 200, 120 }, { -200, -120 }, { 200, -120 }, { -120, 205 }, { 0, 215 }, { 120, 205 }, { -120, -205 }, { 0, -215 }, { 120, -205 } } do
		local pos = at(spot[1], 0.2, spot[2])
		place("Tower", facingRoad(pos, O.Z), rng:NextInteger(20, 30), rng:NextInteger(18, 26), rng:NextInteger(8, 22),
			Color3.fromHSV(rng:NextNumber(0.5, 0.65), rng:NextNumber(0.05, 0.25), rng:NextNumber(0.55, 0.85)))
	end
	for x = -180, 180, 60 do
		for _, z in { -14, 14 } do
			place("StreetLamp", facingRoad(at(x + (if z > 0 then 30 else 0), 0.2, z), O.Z))
		end
	end
end

--------------------------------------------------------------------------
-- San Bukid (on a plateau, y = 40)
--------------------------------------------------------------------------
local function buildBukid()
	local O = Config.Cities.SanBukid.origin
	local function at(x, y, z)
		return O + V(x, y, z)
	end
	part({ Name = "Lupa", Size = V(470, 2, 600), CFrame = CF(at(0, -1, 0)), Color = C(104, 165, 70), Material = MAT.Grass })
	road(CF(at(0, 0.1, 0)), V(470, 0.2, 16), false)
	arch(at(-232, 0, 0), "MALIGAYANG PAGDATING SA SAN BUKID", C(60, 120, 60))
	place("BusTerminal", facingRoad(at(-205, 0.2, -20), O.Z), "TERMINAL · BIYAHENG METRO DAKILA")

	-- north side
	place("Simbahan", facingRoad(at(-160, 0, 40), O.Z))
	place("Building", facingRoad(at(-40, 0.2, 45), O.Z), 16, 12, 7, C(245, 245, 245), "RURAL HEALTH UNIT", "RHU")
	place("Building", facingRoad(at(30, 0.2, 48), O.Z), 26, 16, 8, C(250, 230, 150), "PAARALANG SAN BUKID", "Paaralan")
	place("Building", facingRoad(at(120, 0.2, 45), O.Z), 16, 12, 7, C(220, 230, 240), "PESO OFFICE", "PESO")
	place("SariSari", facingRoad(at(180, 0.2, 42), O.Z))
	-- south side: rice fields and work
	for i, x in { -150, -110, 110, 150 } do
		place("Palayan", facingRoad(at(x, 0.2, -50), O.Z), 30 + i)
	end
	place("Palengke", facingRoad(at(-25, 0.2, -42), O.Z), 3)
	place("ConstructionSite", facingRoad(at(35, 0.2, -50), O.Z))
	place("Jeepney", CF(at(-80, 0.2, 12)) * CFrame.Angles(0, math.pi / 2, 0), "SAN BUKID - BAYAN")
	place("Kalabaw", CF(at(-130, 0, -76)) * CFrame.Angles(0, 0.4, 0))
	place("Kalabaw", CF(at(125, 0, -78)) * CFrame.Angles(0, -1.1, 0))

	local rng = Random.new(33)
	for _ = 1, 14 do
		local x, z = rng:NextNumber(-220, 220), rng:NextNumber(-280, 280)
		if math.abs(z) > 150 or math.abs(x) > 200 then
			place("CoconutTree", CF(at(x, 0, z)), rng:NextInteger(1, 9999))
		end
	end
	for _, spot in { { -150, 300 }, { 120, 320 }, { -60, -320 }, { 170, -300 } } do
		place("Bundok", CF(at(spot[1], 0, spot[2])), V(300, 140, 200), C(60, 125, 60))
	end
	local tops = {}
	for i, x in { -40, 40 } do
		local lamp = place("StreetLamp", facingRoad(at(x, 0.2, if i == 1 then -11 else 11), O.Z))
		tops[i] = (lamp:FindFirstChild("Top") :: BasePart).Position
	end
	local flags = Models.build("Banderitas", tops[1], tops[2], 3, 77)
	flags.Parent = world
end

function WorldBuilder.build()
	root = Instance.new("Folder")
	root.Name = "Kapuluan"
	root.Parent = workspace
	beginCity("BaybayAlon")

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
	buildBaybayExtras()

	beginCity("Highway")
	buildHighway()
	beginCity("MetroDakila")
	buildMetro()
	beginCity("Bundok")
	buildMountainRoad()
	beginCity("SanBukid")
	buildBukid()
end

return WorldBuilder
