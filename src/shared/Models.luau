--[[
	Models — procedural builders for every 3D object in Bahay Buhay.
	No uploaded meshes or decals are needed: everything is made from parts.

	Conventions:
	  • Each builder returns a Model whose pivot (PrimaryPart "Base") is at floor level, centre.
	  • Local +Z is the FRONT of the object (where the player stands to use it).
	  • A part named "UsePoint" marks where the character goes. If it is a Seat,
	    the character sits on it; otherwise the character stands on it facing its LookVector.
	  • A part named "PromptPart" (optional) is where the ProximityPrompt is attached.
	  • Lights tagged "NightLight" are switched on at night by the server.

	Usage: Models.build("Kalan") → Model
]]

local CollectionService = game:GetService("CollectionService")

local Util = require(script.Parent.Util)

local Models = {}
local Builders = {}

local C = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local MAT = Enum.Material
local PI = math.pi

local Palette = {
	bamboo = C(201, 170, 104),
	bambooDark = C(150, 118, 64),
	wood = C(124, 84, 48),
	woodDark = C(84, 54, 32),
	nipa = C(168, 134, 78),
	nipaDark = C(130, 100, 56),
	sawali = C(214, 186, 128),
	white = C(242, 242, 238),
	metal = C(190, 192, 196),
	chrome = C(228, 230, 235),
	dark = C(35, 35, 40),
	leaf = C(64, 145, 58),
	leafDark = C(44, 110, 44),
	flagRed = C(206, 17, 38),
	flagBlue = C(0, 56, 168),
	flagYellow = C(252, 209, 22),
}
Models.Palette = Palette

local BANDERITAS_COLORS = {
	C(230, 57, 70), C(252, 209, 22), C(0, 120, 215), C(46, 196, 108), C(255, 120, 190), C(255, 150, 40),
}

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------
local function newModel(name: string, stationId: string?): Model
	local model = Instance.new("Model")
	model.Name = name
	local base = Util.part({
		Name = "Base",
		Size = V(1, 0.2, 1),
		CFrame = CF(0, 0, 0),
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Parent = model,
	})
	model.PrimaryPart = base
	if stationId then
		model:SetAttribute("StationId", stationId)
	end
	return model
end

local function P(model: Instance, props: { [string]: any }): BasePart
	props.Parent = model
	return Util.part(props)
end

-- Vertical cylinder standing on y0.
local function vcyl(model, x, y0, z, height, diameter, color, material, extra)
	local props = {
		Shape = Enum.PartType.Cylinder,
		Size = V(height, diameter, diameter),
		CFrame = CF(x, y0 + height / 2, z) * ANG(0, 0, PI / 2),
		Color = color,
		Material = material or MAT.Wood,
	}
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return P(model, props)
end

local function ball(model, cf, diameter, color, material)
	return P(model, {
		Shape = Enum.PartType.Ball,
		Size = V(diameter, diameter, diameter),
		CFrame = cf,
		Color = color,
		Material = material or MAT.SmoothPlastic,
	})
end

local function usePoint(model, cf)
	return P(model, {
		Name = "UsePoint",
		Size = V(1, 0.2, 1),
		CFrame = cf,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
end

-- A seat that doubles as the UsePoint. Seats face their -Z.
local function seatPoint(model, cf, size, color, material, visible)
	return P(model, {
		ClassName = "Seat",
		Name = "UsePoint",
		Size = size or V(2, 0.3, 2),
		CFrame = cf,
		Color = color or Palette.wood,
		Material = material or MAT.Wood,
		Transparency = if visible == false then 1 else 0,
	})
end

local function promptPart(model, cf)
	return P(model, {
		Name = "PromptPart",
		Size = V(1, 1, 1),
		CFrame = cf,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
end

local function nightLight(part: BasePart, range: number, brightness: number, color: Color3?, spot: boolean?)
	local light: Light
	if spot then
		local s = Instance.new("SpotLight")
		s.Face = Enum.NormalId.Bottom
		s.Angle = 110
		light = s
	else
		light = Instance.new("PointLight")
	end
	light.Range = range
	light.Brightness = brightness
	light.Color = color or C(255, 214, 150)
	light.Shadows = false
	light.Enabled = false
	light.Parent = part
	CollectionService:AddTag(part, "NightLight")
	return light
end

-- Builds a wall along local X with rectangular openings (doors/windows).
-- frame: CFrame at the wall's bottom-centre. openings: { {c=centreX, w=width, bottom=y, top=y} }
local function wall(model, frame: CFrame, length, height, thick, openings, color, material)
	table.sort(openings, function(a, b)
		return a.c < b.c
	end)
	local function piece(x0, x1, y0, y1)
		if x1 - x0 < 0.05 or y1 - y0 < 0.05 then
			return
		end
		P(model, {
			Size = V(x1 - x0, y1 - y0, thick),
			CFrame = frame * CF((x0 + x1) / 2, (y0 + y1) / 2, 0),
			Color = color,
			Material = material,
		})
	end
	local cursor = -length / 2
	for _, o in openings do
		local x0, x1 = o.c - o.w / 2, o.c + o.w / 2
		piece(cursor, x0, 0, height)
		piece(x0, x1, 0, o.bottom)
		piece(x0, x1, o.top, height)
		cursor = x1
	end
	piece(cursor, length / 2, 0, height)
end

-- Two sloped thatch panels meeting at a ridge along local X, plus gable triangles.
local function gableRoof(model, centre: CFrame, width, depth, rise, overhang, color, material, closeGables)
	local halfRun = depth / 2
	local angle = math.atan2(rise, halfRun)
	local span = halfRun + overhang
	local length = span / math.cos(angle)
	local cy = rise - (span / 2) * math.tan(angle)
	for _, side in { 1, -1 } do
		P(model, {
			Name = "Bubong",
			Size = V(width + overhang * 2, 0.8, length),
			CFrame = centre * CF(0, cy, side * span / 2) * ANG(side * angle, 0, 0),
			Color = color,
			Material = material,
		})
	end
	P(model, {
		Name = "Ridge",
		Size = V(width + overhang * 2 + 0.4, 0.8, 1.4),
		CFrame = centre * CF(0, rise + 0.15, 0),
		Color = Palette.nipaDark,
		Material = material,
	})
	if closeGables then
		for _, sx in { 1, -1 } do
			local x = sx * (width / 2 - 0.25)
			P(model, {
				ClassName = "WedgePart",
				Size = V(0.5, rise, halfRun),
				CFrame = centre * CF(x, rise / 2, halfRun / 2) * ANG(0, PI, 0),
				Color = Palette.sawali,
				Material = MAT.Fabric,
			})
			P(model, {
				ClassName = "WedgePart",
				Size = V(0.5, rise, halfRun),
				CFrame = centre * CF(x, rise / 2, -halfRun / 2),
				Color = Palette.sawali,
				Material = MAT.Fabric,
			})
		end
	end
end

-- Pennant-shaped triangle pointing down, hanging from `top` (lookAt along the rope).
local function pennant(parent, top: CFrame, height, halfWidth, color)
	P(parent, {
		ClassName = "WedgePart",
		Size = V(0.06, height, halfWidth),
		CFrame = top * CF(0, -height / 2, -halfWidth / 2) * ANG(0, 0, PI),
		Color = color,
		Material = MAT.Fabric,
		CanCollide = false,
		CastShadow = false,
	})
	P(parent, {
		ClassName = "WedgePart",
		Size = V(0.06, height, halfWidth),
		CFrame = top * CF(0, -height / 2, halfWidth / 2) * ANG(0, PI, PI),
		Color = color,
		Material = MAT.Fabric,
		CanCollide = false,
		CastShadow = false,
	})
end

local function bench(model, cf: CFrame, length)
	P(model, { Size = V(length, 0.3, 1.2), CFrame = cf * CF(0, 1.6, 0), Color = Palette.wood, Material = MAT.WoodPlanks })
	for _, sx in { -1, 1 } do
		P(model, { Size = V(0.3, 1.45, 1), CFrame = cf * CF(sx * (length / 2 - 0.5), 0.725, 0), Color = Palette.woodDark })
	end
end

--------------------------------------------------------------------------
-- FURNITURE
--------------------------------------------------------------------------
function Builders.Banig()
	local m = newModel("Banig", "Banig")
	P(m, { Name = "Mat", Size = V(4.2, 0.2, 7), CFrame = CF(0, 0.1, 0), Color = C(214, 186, 120), Material = MAT.Fabric })
	for i = -1, 1 do
		P(m, {
			Size = V(4.22, 0.22, 0.35),
			CFrame = CF(0, 0.11, i * 2),
			Color = if i == 0 then C(200, 50, 60) else C(40, 130, 90),
			Material = MAT.Fabric,
		})
	end
	P(m, { Name = "Unan", Size = V(2.6, 0.6, 1.2), CFrame = CF(0, 0.5, 2.8), Color = Palette.white, Material = MAT.Fabric })
	usePoint(m, CF(0, 0.2, 0)) -- lying down: head goes toward +Z (the pillow)
	return m
end

function Builders.Kama()
	local m = newModel("Kama", "Kama")
	for _, x in { -2.3, 2.3 } do
		for _, z in { -3.8, 3.8 } do
			vcyl(m, x, 0, z, 1.6, 0.45, Palette.bambooDark)
		end
	end
	vcyl(m, -2.3, 1.6, 3.8, 1.6, 0.45, Palette.bambooDark)
	vcyl(m, 2.3, 1.6, 3.8, 1.6, 0.45, Palette.bambooDark)
	P(m, { Size = V(5, 0.3, 8), CFrame = CF(0, 1.6, 0), Color = Palette.bamboo, Material = MAT.WoodPlanks })
	P(m, { Size = V(5, 0.25, 0.3), CFrame = CF(0, 3.0, 3.8), Color = Palette.bamboo, Material = MAT.Wood })
	P(m, { Name = "Kutson", Size = V(4.6, 0.5, 7.4), CFrame = CF(0, 2.0, 0), Color = C(120, 170, 210), Material = MAT.Fabric })
	P(m, { Name = "Unan", Size = V(3, 0.6, 1.2), CFrame = CF(0, 2.5, 3), Color = Palette.white, Material = MAT.Fabric })
	P(m, { Name = "Kumot", Size = V(4.7, 0.1, 3.5), CFrame = CF(0, 2.28, -1.8), Color = C(230, 120, 80), Material = MAT.Fabric })
	usePoint(m, CF(0, 2.25, 0))
	return m
end

function Builders.Kalan()
	local m = newModel("Kalan", "Kalan")
	P(m, { Name = "Counter", Size = V(5, 3, 2.4), CFrame = CF(0, 1.5, 0), Color = Palette.wood, Material = MAT.WoodPlanks })
	P(m, { Size = V(5.2, 0.2, 2.6), CFrame = CF(0, 3.1, 0), Color = C(205, 205, 200), Material = MAT.Marble })
	P(m, { Name = "Stove", Size = V(3, 0.4, 1.6), CFrame = CF(0, 3.4, -0.1), Color = Palette.dark, Material = MAT.Metal })
	for _, x in { -0.7, 0.7 } do
		vcyl(m, x, 3.6, -0.1, 0.08, 0.8, C(20, 20, 20), MAT.Metal)
	end
	vcyl(m, -0.7, 3.65, -0.1, 0.9, 1.1, C(170, 170, 176), MAT.Metal) -- kaldero
	vcyl(m, -0.7, 4.55, -0.1, 0.1, 1.15, C(140, 140, 146), MAT.Metal)
	P(m, { Name = "Kawali", Size = V(1.2, 0.2, 1.2), CFrame = CF(0.7, 3.75, -0.1), Color = C(30, 30, 30), Material = MAT.Metal })
	P(m, { Size = V(1, 0.1, 0.15), CFrame = CF(1.6, 3.8, -0.1), Color = Palette.woodDark })
	vcyl(m, 2.1, 3.2, 0.6, 1.2, 0.5, C(210, 60, 40), MAT.SmoothPlastic) -- bote ng toyo/suka
	usePoint(m, CFrame.lookAt(V(0, 0.2, 2.8), V(0, 0.2, 0)))
	return m
end

function Builders.Hapag()
	local m = newModel("Hapag", "Hapag")
	P(m, { Name = "Mesa", Size = V(6, 0.3, 3.2), CFrame = CF(0, 2.85, 0), Color = Palette.wood, Material = MAT.WoodPlanks })
	for _, x in { -2.7, 2.7 } do
		for _, z in { -1.4, 1.4 } do
			P(m, { Size = V(0.3, 2.7, 0.3), CFrame = CF(x, 1.35, z), Color = Palette.woodDark })
		end
	end
	-- bench players sit on (faces the table, -Z)
	seatPoint(m, CF(0, 1.6, 2.4), V(5, 0.3, 1.2), Palette.wood, MAT.WoodPlanks)
	for _, x in { -2.2, 2.2 } do
		P(m, { Size = V(0.3, 1.45, 1), CFrame = CF(x, 0.725, 2.4), Color = Palette.woodDark })
	end
	bench(m, CF(0, 0, -2.4), 5)
	-- food
	vcyl(m, 0, 3.0, 0, 0.4, 1.1, Palette.white, MAT.SmoothPlastic)
	ball(m, CF(0, 3.4, 0), 0.9, Palette.white)
	vcyl(m, 1.7, 3.0, 0.3, 0.12, 1.3, Palette.white, MAT.SmoothPlastic)
	P(m, { Size = V(0.8, 0.2, 0.6), CFrame = CF(1.7, 3.2, 0.3), Color = C(110, 60, 30) })
	vcyl(m, -1.8, 3.0, -0.4, 1, 0.6, C(200, 230, 255), MAT.Glass, { Transparency = 0.35 })
	return m
end

function Builders.Paliguan()
	local m = newModel("Paliguan", "Paliguan")
	P(m, { Size = V(5, 0.2, 5), CFrame = CF(0, 0.1, 0), Color = C(120, 180, 200), Material = MAT.Slate })
	P(m, { Size = V(5, 6, 0.3), CFrame = CF(0, 3.2, -2.35), Color = C(225, 225, 215), Material = MAT.Concrete })
	P(m, { Size = V(0.3, 6, 5), CFrame = CF(2.35, 3.2, 0), Color = C(225, 225, 215), Material = MAT.Concrete })
	vcyl(m, -1, 0.2, -1.2, 1.6, 1.6, C(40, 110, 220), MAT.SmoothPlastic) -- timba
	vcyl(m, -1, 1.72, -1.2, 0.05, 1.4, C(120, 190, 240), MAT.Glass, { Transparency = 0.3 })
	vcyl(m, 0.7, 0.2, -1.4, 0.7, 0.7, C(240, 90, 140), MAT.SmoothPlastic) -- tabo
	P(m, { Size = V(0.2, 0.2, 0.6), CFrame = CF(0.7, 0.7, -0.85), Color = C(240, 90, 140) })
	vcyl(m, 1.6, 0.2, 1.4, 2.2, 1.8, C(60, 130, 200), MAT.SmoothPlastic) -- drum ng tubig
	usePoint(m, CF(0, 0.2, 0.8))
	return m
end

function Builders.Inidoro()
	local m = newModel("Inidoro", "Inidoro")
	vcyl(m, 0, 0, 0, 1.2, 1.4, Palette.white, MAT.SmoothPlastic)
	seatPoint(m, CF(0, 1.35, 0.1) * ANG(0, PI, 0), V(1.6, 0.25, 1.8), Palette.white, MAT.SmoothPlastic)
	P(m, { Name = "Tangke", Size = V(1.8, 1.8, 0.8), CFrame = CF(0, 2, -1.0), Color = Palette.white, Material = MAT.SmoothPlastic })
	P(m, { Size = V(0.4, 0.12, 0.12), CFrame = CF(0.6, 2.6, -0.55), Color = Palette.metal, Material = MAT.Metal })
	P(m, { Size = V(0.6, 0.6, 0.6), CFrame = CF(-1.4, 0.3, 0.4), Color = C(40, 110, 220) }) -- tabo sa CR
	return m
end

function Builders.TV()
	local m = newModel("TV", "TV")
	P(m, { Name = "Cabinet", Size = V(4, 2.4, 2), CFrame = CF(0, 1.2, 0), Color = Palette.wood, Material = MAT.WoodPlanks })
	P(m, { Name = "Kahon", Size = V(3, 2.4, 2.2), CFrame = CF(0, 3.6, 0), Color = C(70, 70, 75), Material = MAT.SmoothPlastic })
	P(m, { Name = "Screen", Size = V(2.3, 1.8, 0.1), CFrame = CF(-0.2, 3.65, 1.12), Color = C(60, 120, 150), Material = MAT.Neon })
	for i, x in { 1.15, 1.15 } do
		vcyl(m, x, 3.9 - i * 0.55, 1.12, 0.12, 0.3, C(30, 30, 30), MAT.SmoothPlastic)
	end
	P(m, { Size = V(0.08, 1.8, 0.08), CFrame = CF(-0.4, 5.5, 0) * ANG(0, 0, 0.4), Color = Palette.metal, Material = MAT.Metal })
	P(m, { Size = V(0.08, 1.8, 0.08), CFrame = CF(0.4, 5.5, 0) * ANG(0, 0, -0.4), Color = Palette.metal, Material = MAT.Metal })
	-- bangkô (stool) to sit on
	seatPoint(m, CF(0, 1.4, 6), V(1.8, 0.3, 1.8), Palette.wood, MAT.Wood)
	for _, x in { -0.7, 0.7 } do
		for _, z in { 5.3, 6.7 } do
			P(m, { Size = V(0.25, 1.25, 0.25), CFrame = CF(x, 0.625, z), Color = Palette.woodDark })
		end
	end
	promptPart(m, CF(0, 2, 2))
	return m
end

function Builders.Videoke()
	local m = newModel("Videoke", "Videoke")
	P(m, { Name = "Cabinet", Size = V(3, 3.2, 1.8), CFrame = CF(0, 1.6, 0), Color = C(30, 30, 35) })
	P(m, { Name = "Monitor", Size = V(3, 2.2, 1.6), CFrame = CF(0, 4.3, 0), Color = C(40, 40, 45) })
	P(m, { Name = "Screen", Size = V(2.6, 1.8, 0.1), CFrame = CF(0, 4.3, 0.81), Color = C(150, 80, 220), Material = MAT.Neon })
	P(m, { Size = V(2.6, 0.15, 0.05), CFrame = CF(0, 2.9, 0.92), Color = C(255, 80, 160), Material = MAT.Neon })
	P(m, { Size = V(2.6, 0.15, 0.05), CFrame = CF(0, 2.6, 0.92), Color = C(80, 200, 255), Material = MAT.Neon })
	for _, x in { -2.4, 2.4 } do
		P(m, { Name = "Speaker", Size = V(1.4, 3.4, 1.4), CFrame = CF(x, 1.7, 0), Color = C(25, 25, 25) })
		for _, y in { 1.0, 2.5 } do
			P(m, {
				Shape = Enum.PartType.Cylinder,
				Size = V(0.1, 1, 1),
				CFrame = CF(x, y, 0.71) * ANG(0, PI / 2, 0),
				Color = C(70, 70, 75),
				Material = MAT.Metal,
			})
		end
	end
	vcyl(m, 0, 0, 3, 4.2, 0.15, Palette.metal, MAT.Metal) -- mic stand
	ball(m, CF(0, 4.35, 2.9), 0.45, C(40, 40, 40), MAT.Metal)
	usePoint(m, CFrame.lookAt(V(0, 0.2, 3.8), V(0, 0.2, 0)))
	return m
end

function Builders.Duyan()
	local m = newModel("Duyan", "Duyan")
	vcyl(m, 0, 0, -5.2, 6, 0.7, Palette.bambooDark)
	vcyl(m, 0, 0, 5.2, 6, 0.7, Palette.bambooDark)
	local colors = { C(230, 80, 70), C(250, 200, 60), C(60, 160, 220) }
	P(m, { Size = V(2.6, 0.15, 3.2), CFrame = CF(0, 2.0, 0), Color = colors[1], Material = MAT.Fabric })
	local run, rise = 3.1, 2.3
	local len = math.sqrt(run * run + rise * rise)
	local angle = math.atan2(rise, run)
	P(m, { Size = V(2.4, 0.15, len), CFrame = CF(0, 2.0 + rise / 2, 1.6 + run / 2) * ANG(-angle, 0, 0), Color = colors[2], Material = MAT.Fabric })
	P(m, { Size = V(2.4, 0.15, len), CFrame = CF(0, 2.0 + rise / 2, -1.6 - run / 2) * ANG(angle, 0, 0), Color = colors[3], Material = MAT.Fabric })
	usePoint(m, CF(0, 2.1, 0))
	return m
end

function Builders.Bentilador()
	local m = newModel("Bentilador", "Bentilador")
	vcyl(m, 0, 0, 0, 0.3, 1.6, C(60, 60, 70), MAT.SmoothPlastic)
	vcyl(m, 0, 0.3, 0, 3.2, 0.25, Palette.metal, MAT.Metal)
	P(m, { Size = V(0.8, 0.8, 1.2), CFrame = CF(0, 3.8, 0), Color = C(60, 60, 70) })
	P(m, {
		Name = "Cage",
		Shape = Enum.PartType.Cylinder,
		Size = V(0.5, 2.6, 2.6),
		CFrame = CF(0, 3.8, 0.9) * ANG(0, PI / 2, 0),
		Color = C(80, 140, 220),
		Transparency = 0.65,
		Material = MAT.SmoothPlastic,
	})
	for i = 0, 2 do
		P(m, {
			Size = V(0.12, 1.1, 0.05),
			CFrame = CF(0, 3.8, 0.9) * ANG(0, 0, i * 2 * PI / 3) * CF(0, 0.55, 0),
			Color = C(60, 120, 210),
		})
	end
	usePoint(m, CFrame.lookAt(V(0, 0.2, 4), V(0, 0.2, 0)))
	return m
end

function Builders.Altar()
	local m = newModel("Altar", "Altar")
	P(m, { Size = V(4, 2.6, 1.6), CFrame = CF(0, 1.3, 0), Color = Palette.woodDark, Material = MAT.WoodPlanks })
	P(m, { Size = V(4.1, 0.1, 1.7), CFrame = CF(0, 2.65, 0), Color = Palette.white, Material = MAT.Fabric })
	P(m, { Size = V(4.1, 1.2, 0.08), CFrame = CF(0, 2.1, 0.85), Color = Palette.white, Material = MAT.Fabric })
	P(m, { Size = V(0.25, 1.8, 0.25), CFrame = CF(0, 3.6, -0.4), Color = C(205, 170, 80), Material = MAT.Metal })
	P(m, { Size = V(1, 0.25, 0.25), CFrame = CF(0, 4.0, -0.4), Color = C(205, 170, 80), Material = MAT.Metal })
	for _, x in { -1.4, 1.4 } do
		vcyl(m, x, 2.7, 0.2, 0.8, 0.25, Palette.white, MAT.SmoothPlastic)
		local flame = ball(m, CF(x, 3.65, 0.2), 0.25, C(255, 180, 60), MAT.Neon)
		local light = Instance.new("PointLight")
		light.Range = 8
		light.Brightness = 1
		light.Color = C(255, 190, 110)
		light.Parent = flame
	end
	for _, x in { -0.8, 0.8 } do
		ball(m, CF(x, 2.95, 0.3), 0.4, C(255, 255, 255))
	end
	usePoint(m, CFrame.lookAt(V(0, 0.2, 3), V(0, 0.2, 0)))
	return m
end

function Builders.Halaman()
	local m = newModel("Halaman", "Halaman")
	vcyl(m, 0, 0, 0, 1.4, 1.6, C(176, 92, 52), MAT.Slate)
	vcyl(m, 0, 1.38, 0, 0.05, 1.4, C(80, 55, 35), MAT.Ground)
	local rng = Random.new(7)
	for _ = 1, 5 do
		ball(m, CF(rng:NextNumber(-0.5, 0.5), rng:NextNumber(1.9, 2.6), rng:NextNumber(-0.5, 0.5)), 1.1, Palette.leaf, MAT.Grass)
	end
	for _ = 1, 9 do
		ball(m, CF(rng:NextNumber(-0.8, 0.8), rng:NextNumber(2.0, 3.0), rng:NextNumber(-0.8, 0.8)), 0.32, C(255, 255, 250))
	end
	usePoint(m, CFrame.lookAt(V(0, 0.2, 2.6), V(0, 0.2, 0)))
	return m
end

function Builders.Parol()
	local m = newModel("Parol", "Parol")
	vcyl(m, 0, 0, 0, 7.2, 0.3, Palette.bambooDark)
	P(m, { Size = V(0.2, 0.2, 2), CFrame = CF(0, 7.1, 0.9), Color = Palette.bambooDark })
	P(m, { Size = V(0.05, 0.7, 0.05), CFrame = CF(0, 6.7, 1.7), Color = C(30, 30, 30) })
	local centre = CF(0, 5.4, 1.7)
	local core = ball(m, centre, 1, C(255, 220, 100), MAT.Neon)
	for i = 0, 4 do
		P(m, {
			Size = V(0.55, 1.7, 0.3),
			CFrame = centre * ANG(0, 0, i * 2 * PI / 5) * CF(0, 0.95, 0),
			Color = if i % 2 == 0 then C(230, 40, 50) else C(255, 200, 40),
			Material = MAT.Neon,
		})
	end
	for _, sx in { -1, 1 } do
		P(m, {
			Size = V(0.15, 2.2, 0.05),
			CFrame = centre * CF(sx * 0.35, -2.0, 0) * ANG(0, 0, sx * 0.15),
			Color = C(230, 40, 50),
			Material = MAT.Neon,
			CanCollide = false,
		})
	end
	nightLight(core, 16, 2, C(255, 200, 120))
	return m
end

function Builders.Aparador()
	local m = newModel("Aparador", "Aparador")
	P(m, { Size = V(4, 6.5, 2), CFrame = CF(0, 3.25, 0), Color = Palette.wood, Material = MAT.WoodPlanks })
	P(m, { Size = V(4.3, 0.3, 2.2), CFrame = CF(0, 6.65, 0), Color = Palette.woodDark })
	P(m, { Size = V(0.08, 6, 0.05), CFrame = CF(0, 3.3, 1.02), Color = Palette.woodDark })
	for _, x in { -0.3, 0.3 } do
		P(m, { Size = V(0.12, 0.5, 0.12), CFrame = CF(x, 3.4, 1.08), Color = C(205, 170, 80), Material = MAT.Metal })
	end
	P(m, { Name = "Salamin", Size = V(1.4, 4, 0.05), CFrame = CF(-1, 3.6, 1.03), Color = C(200, 220, 230), Material = MAT.Glass, Reflectance = 0.4 })
	usePoint(m, CFrame.lookAt(V(0, 0.2, 3), V(0, 0.2, 0)))
	return m
end

--------------------------------------------------------------------------
-- PUBLIC PLACES
--------------------------------------------------------------------------
function Builders.SariSari()
	local m = newModel("SariSari", "SariSari")
	P(m, { Name = "Body", Size = V(14, 9, 10), CFrame = CF(0, 4.5, 0), Color = C(232, 222, 190), Material = MAT.Concrete })
	P(m, { Size = V(14.1, 3, 10.1), CFrame = CF(0, 1.5, 0), Color = C(90, 150, 120), Material = MAT.Concrete })
	P(m, { Name = "Loob", Size = V(9, 3.6, 0.2), CFrame = CF(0, 4.5, 5.05), Color = C(45, 32, 25) })
	for i = 0, 11 do
		P(m, { Size = V(0.12, 3.6, 0.12), CFrame = CF(-4.4 + i * 0.8, 4.5, 5.3), Color = C(60, 95, 60), Material = MAT.Metal })
	end
	P(m, { Size = V(9.2, 0.12, 0.12), CFrame = CF(0, 6.3, 5.3), Color = C(60, 95, 60), Material = MAT.Metal })
	P(m, { Name = "Counter", Size = V(10, 0.3, 1.4), CFrame = CF(0, 2.6, 5.7), Color = Palette.wood, Material = MAT.WoodPlanks })
	-- hanging "tingi" sachets
	local rng = Random.new(3)
	for i = 0, 10 do
		P(m, {
			Size = V(0.5, 1.5, 0.05),
			CFrame = CF(-4 + i * 0.8, 5.6, 5.45),
			Color = Color3.fromHSV(rng:NextNumber(), 0.75, 0.95),
			Material = MAT.SmoothPlastic,
			CanCollide = false,
		})
	end
	-- glass candy jars on the counter
	for i, x in { -3, -1.8, 1.8, 3 } do
		vcyl(m, x, 2.75, 5.7, 0.9, 0.8, C(220, 240, 255), MAT.Glass, { Transparency = 0.4 })
		vcyl(m, x, 2.8, 5.7, 0.5, 0.65, Color3.fromHSV(i / 5, 0.7, 0.95), MAT.SmoothPlastic)
	end
	-- corrugated GI roof (yero)
	P(m, { Name = "Yero", Size = V(15, 0.3, 13), CFrame = CF(0, 9.4, 1) * ANG(0.08, 0, 0), Color = C(150, 140, 130), Material = MAT.CorrodedMetal })
	local sign = P(m, { Name = "Karatula", Size = V(12, 2, 0.3), CFrame = CF(0, 7.6, 5.3), Color = C(252, 220, 70) })
	Util.surfaceText(sign, Enum.NormalId.Back, "SARI-SARI STORE NI ALING NENA", C(160, 20, 30))
	bench(m, CF(-4.5, 0, 8.2), 4.5)
	usePoint(m, CFrame.lookAt(V(0, 0, 7.2), V(0, 0, 0)))
	promptPart(m, CF(0, 3, 6.5))
	return m
end

function Builders.Monobloc(color: Color3?)
	local m = newModel("Monobloc")
	local col = color or Palette.white
	P(m, { ClassName = "Seat", Name = "Upuan", Size = V(1.8, 0.25, 1.8), CFrame = CF(0, 1.6, 0), Color = col, Material = MAT.SmoothPlastic })
	P(m, { Size = V(1.8, 2, 0.25), CFrame = CF(0, 2.7, 0.85) * ANG(-0.12, 0, 0), Color = col, Material = MAT.SmoothPlastic })
	for _, x in { -0.75, 0.75 } do
		for _, z in { -0.75, 0.75 } do
			P(m, { Size = V(0.22, 1.5, 0.22), CFrame = CF(x, 0.75, z), Color = col, Material = MAT.SmoothPlastic })
		end
	end
	return m
end

function Builders.Karinderya()
	local m = newModel("Karinderya", "Karinderya")
	P(m, { Name = "Counter", Size = V(10, 3, 2.5), CFrame = CF(0, 1.5, 0), Color = C(240, 240, 235), Material = MAT.SmoothPlastic })
	P(m, { Size = V(10.1, 0.6, 2.6), CFrame = CF(0, 0.3, 0), Color = Palette.flagBlue })
	P(m, { Name = "Salamin", Size = V(9.5, 1.6, 2.2), CFrame = CF(0, 3.8, 0), Color = C(200, 230, 240), Material = MAT.Glass, Transparency = 0.6 })
	local ulam = { C(110, 60, 30), C(200, 80, 40), C(80, 140, 60), C(220, 200, 150), C(50, 25, 25) }
	for i = 1, 5 do
		local x = -4.4 + (i - 1) * 2.2
		vcyl(m, x, 3.0, 0, 0.9, 1.5, C(175, 175, 180), MAT.Metal)
		vcyl(m, x, 3.88, 0, 0.05, 1.3, ulam[i], MAT.SmoothPlastic)
	end
	for _, x in { -6, 6 } do
		for _, z in { -3.5, 3.5 } do
			vcyl(m, x, 0, z, 8, 0.35, Palette.metal, MAT.Metal)
		end
	end
	P(m, { Name = "Trapal", Size = V(13, 0.2, 8.5), CFrame = CF(0, 8.1, 0), Color = C(40, 110, 200), Material = MAT.Fabric })
	P(m, { Size = V(13.05, 0.22, 1.2), CFrame = CF(0, 8.1, 0), Color = C(250, 250, 250), Material = MAT.Fabric })
	local sign = P(m, { Name = "Karatula", Size = V(8, 1.6, 0.2), CFrame = CF(0, 7, 4.2), Color = C(210, 40, 45) })
	Util.surfaceText(sign, Enum.NormalId.Back, "KARINDERYA · TURO-TURO", C(255, 240, 200))
	-- dining area with monobloc chairs
	for _, x in { -4, 4 } do
		P(m, { Size = V(3, 0.2, 3), CFrame = CF(x, 2.6, 8.5), Color = Palette.white, Material = MAT.SmoothPlastic })
		vcyl(m, x, 0, 8.5, 2.5, 0.3, Palette.white, MAT.SmoothPlastic)
		for _, dz in { -2.2, 2.2 } do
			local chair = Builders.Monobloc(if x < 0 then C(240, 70, 70) else Palette.white)
			chair:PivotTo(CF(x, 0, 8.5 + dz) * (if dz < 0 then ANG(0, PI, 0) else CFrame.identity))
			chair.Parent = m
		end
	end
	usePoint(m, CFrame.lookAt(V(0, 0, 3.6), V(0, 0, 0)))
	promptPart(m, CF(0, 3, 2))
	return m
end

function Builders.BasketballRing()
	local m = newModel("BasketballRing", "Basketball")
	P(m, { Size = V(0.8, 11, 0.8), CFrame = CF(0, 5.5, -2), Color = C(40, 60, 140), Material = MAT.Metal })
	P(m, { Size = V(0.6, 0.6, 2.4), CFrame = CF(0, 10.5, -0.8), Color = C(40, 60, 140), Material = MAT.Metal })
	P(m, { Name = "Board", Size = V(6, 3.6, 0.2), CFrame = CF(0, 11.5, 0.4), Color = Palette.white })
	for _, spec in {
		{ V(2, 0.12, 0.05), CF(0, 12.2, 0.52) },
		{ V(2, 0.12, 0.05), CF(0, 10.9, 0.52) },
		{ V(0.12, 1.4, 0.05), CF(-1, 11.55, 0.52) },
		{ V(0.12, 1.4, 0.05), CF(1, 11.55, 0.52) },
	} do
		P(m, { Size = spec[1], CFrame = spec[2], Color = Palette.flagRed })
	end
	local centre = V(0, 10.4, 1.4)
	for i = 0, 11 do
		local a = i / 12 * 2 * PI
		P(m, {
			Size = V(0.12, 0.12, 0.55),
			CFrame = CF(centre + V(math.cos(a) * 0.9, 0, math.sin(a) * 0.9)) * ANG(0, -a, 0),
			Color = C(240, 110, 30),
			Material = MAT.Metal,
			CanCollide = false,
		})
	end
	vcyl(m, 0, 9.3, 1.4, 1.1, 1.6, Palette.white, MAT.Fabric, { Transparency = 0.6, CanCollide = false })
	usePoint(m, CFrame.lookAt(V(0, 0, 9), V(0, 0, 0)))
	promptPart(m, CF(0, 3, 4))
	return m
end

function Builders.Jeepney(routeText: string?)
	local m = newModel("Jeepney", "Jeepney")
	local W = 6.4
	local silver = Palette.chrome
	P(m, { Name = "Chassis", Size = V(W - 0.6, 0.8, 19), CFrame = CF(0, 1.6, 0), Color = C(50, 50, 55), Material = MAT.Metal })
	-- passenger cabin (rear)
	P(m, { Name = "Body", Size = V(W, 4.2, 11.5), CFrame = CF(0, 4.1, 2.75), Color = silver, Material = MAT.Metal, Reflectance = 0.15 })
	P(m, { Size = V(W + 0.05, 1.4, 10.5), CFrame = CF(0, 5.2, 2.9), Color = C(30, 35, 40), Material = MAT.Glass })
	for i, col in { Palette.flagRed, Palette.flagYellow, Palette.flagBlue } do
		P(m, { Size = V(W + 0.1, 0.35, 11.5), CFrame = CF(0, 2.8 + i * 0.35, 2.75), Color = col })
	end
	P(m, { Size = V(3, 0.3, 1.2), CFrame = CF(0, 1.3, 9), Color = Palette.metal, Material = MAT.DiamondPlate })
	-- driver's cab (hollow so the driver is visible)
	for _, sx in { -1, 1 } do
		P(m, { Size = V(0.3, 2, 3.5), CFrame = CF(sx * (W / 2 - 0.15), 3, -4.75), Color = Palette.flagRed })
		P(m, { Size = V(0.2, 2.2, 3.5), CFrame = CF(sx * (W / 2 - 0.15), 5.1, -4.75), Color = C(160, 200, 220), Material = MAT.Glass, Transparency = 0.5 })
	end
	P(m, { Size = V(W, 1.6, 0.3), CFrame = CF(0, 2.8, -6.35), Color = Palette.flagRed })
	P(m, { Name = "Windshield", Size = V(W - 0.4, 2.6, 0.1), CFrame = CF(0, 4.9, -6.4), Color = C(160, 200, 220), Material = MAT.Glass, Transparency = 0.5 })
	-- hood, grill, lights, ornaments
	P(m, { Name = "Hood", Size = V(W - 0.8, 1.8, 3), CFrame = CF(0, 2.9, -8), Color = silver, Material = MAT.Metal, Reflectance = 0.2 })
	P(m, { Size = V(W - 1.4, 1.2, 0.1), CFrame = CF(0, 2.8, -9.55), Color = Palette.metal, Material = MAT.DiamondPlate })
	for _, sx in { -1, 1 } do
		P(m, {
			Shape = Enum.PartType.Cylinder,
			Size = V(0.15, 0.9, 0.9),
			CFrame = CF(sx * 2, 3.1, -9.6) * ANG(0, PI / 2, 0),
			Color = C(255, 250, 220),
			Material = MAT.Neon,
		})
		P(m, { Name = "Kabayo", Size = V(0.3, 1, 0.9), CFrame = CF(sx * 1.4, 4.3, -8.8), Color = silver, Material = MAT.Metal, Reflectance = 0.3 })
		P(m, { Size = V(0.1, 2.5, 0.1), CFrame = CF(sx * 2.6, 5.2, -9.2), Color = silver, Material = MAT.Metal })
	end
	-- roof and route sign
	P(m, { Name = "Roof", Size = V(W + 0.6, 0.4, 15.2), CFrame = CF(0, 6.4, 1.1), Color = silver, Material = MAT.Metal })
	local sign = P(m, { Name = "Ruta", Size = V(5, 1.1, 0.3), CFrame = CF(0, 7.15, -6.2), Color = Palette.white })
	Util.surfaceText(sign, Enum.NormalId.Front, routeText or "BAYAN - PALENGKE", Palette.flagBlue)
	-- wheels
	for _, sx in { -1, 1 } do
		for _, z in { -6.6, 6.2 } do
			P(m, {
				Shape = Enum.PartType.Cylinder,
				Size = V(1, 2.6, 2.6),
				CFrame = CF(sx * (W / 2 - 0.2), 1.3, z),
				Color = C(25, 25, 25),
				Material = MAT.SmoothPlastic,
			})
		end
	end
	-- driver seat (left-hand drive) and steering wheel
	seatPoint(m, CF(-1.6, 2.4, -4.6), V(1.8, 0.3, 1.8), C(120, 30, 30), MAT.Fabric)
	P(m, {
		Shape = Enum.PartType.Cylinder,
		Size = V(0.15, 1.3, 1.3),
		CFrame = CF(-1.6, 3.9, -5.8) * ANG(0, PI / 2, 0),
		Color = C(30, 30, 30),
	})
	promptPart(m, CF(-W / 2 - 1, 3, -4.75))
	return m
end

function Builders.Palengke(variant: number?)
	local m = newModel("Palengke", "Palengke")
	local rng = Random.new(variant or 1)
	P(m, { Name = "Mesa", Size = V(8, 2.8, 3.5), CFrame = CF(0, 1.4, 0), Color = Palette.wood, Material = MAT.WoodPlanks })
	for _, x in { -4.2, 4.2 } do
		for _, z in { -2, 2 } do
			vcyl(m, x, 0, z, 8, 0.4, Palette.bambooDark)
		end
	end
	P(m, {
		Name = "Trapal",
		Size = V(9.5, 0.25, 5.8),
		CFrame = CF(0, 8, 0) * ANG(-0.1, 0, 0),
		Color = Color3.fromHSV(rng:NextNumber(), 0.7, 0.9),
		Material = MAT.Fabric,
	})
	local produce = {
		{ C(250, 200, 50), 0.7 }, -- mangga
		{ C(220, 40, 40), 0.55 }, -- kamatis
		{ C(110, 50, 140), 0.6 }, -- talong
		{ C(240, 220, 90), 0.5 }, -- saging
	}
	for i, x in { -2.6, 0, 2.6 } do
		vcyl(m, x, 2.8, 0.5, 0.2, 2.3, Palette.bamboo, MAT.Fabric) -- bilao
		local item = produce[((i + (variant or 1)) % #produce) + 1]
		for _ = 1, 6 do
			ball(m, CF(x + rng:NextNumber(-0.6, 0.6), 3.2 + rng:NextNumber(0, 0.25), 0.5 + rng:NextNumber(-0.6, 0.6)), item[2], item[1])
		end
	end
	-- fresh fish on ice
	P(m, { Size = V(2.4, 0.2, 1), CFrame = CF(0, 2.9, -1.1), Color = C(235, 245, 255), Material = MAT.Ice })
	for i = 0, 3 do
		P(m, { Size = V(0.9, 0.25, 0.35), CFrame = CF(-0.8 + i * 0.55, 3.1, -1.1) * ANG(0, 0.3, 0), Color = C(170, 180, 190), Material = MAT.Metal })
	end
	P(m, { Name = "Timbangan", Size = V(1, 0.8, 1), CFrame = CF(3.2, 3.2, -1.1), Color = C(200, 40, 40) })
	usePoint(m, CFrame.lookAt(V(0, 0, -3.3), V(0, 0, 0))) -- vendor stands behind the table
	return m
end

function Builders.Bangka()
	local m = newModel("Bangka", "Bangka")
	P(m, { Name = "Katawan", Size = V(2.6, 1.4, 9), CFrame = CF(0, 0.5, 0), Color = Palette.white, Material = MAT.Wood })
	P(m, { Size = V(2.65, 0.4, 9), CFrame = CF(0, 0, 0), Color = Palette.flagBlue })
	P(m, { ClassName = "WedgePart", Size = V(2.6, 1.4, 3), CFrame = CF(0, 0.5, -6) * ANG(0, 0, PI), Color = Palette.white, Material = MAT.Wood })
	P(m, { ClassName = "WedgePart", Size = V(2.6, 1.4, 3), CFrame = CF(0, 0.5, 6) * ANG(0, PI, PI), Color = Palette.white, Material = MAT.Wood })
	P(m, { Size = V(2.7, 0.3, 0.6), CFrame = CF(0, 1.1, -3), Color = Palette.flagRed })
	-- katig (bamboo outriggers) and crossbars
	for _, sx in { -1, 1 } do
		P(m, {
			Shape = Enum.PartType.Cylinder,
			Size = V(14, 0.6, 0.6),
			CFrame = CF(sx * 5.5, 0.1, 0) * ANG(0, PI / 2, 0),
			Color = Palette.bamboo,
			Material = MAT.Wood,
		})
	end
	for _, z in { -3, 3 } do
		P(m, {
			Shape = Enum.PartType.Cylinder,
			Size = V(11.5, 0.35, 0.35),
			CFrame = CF(0, 1.3, z),
			Color = Palette.bambooDark,
			Material = MAT.Wood,
		})
	end
	seatPoint(m, CF(0, 1.35, 1.5), V(2.2, 0.3, 1.2), Palette.wood, MAT.WoodPlanks)
	P(m, { Name = "Pamingwit", Size = V(0.12, 0.12, 6), CFrame = CF(0.9, 2.4, -1.5) * ANG(0.35, 0.2, 0), Color = C(110, 75, 40), CanCollide = false })
	promptPart(m, CF(0, 2, 0))
	return m
end

function Builders.Simbahan()
	local m = newModel("Simbahan", "Simbahan")
	local stone = C(196, 168, 126)
	local stoneLight = C(214, 190, 150)
	P(m, { Name = "Nave", Size = V(28, 20, 40), CFrame = CF(0, 10, -20), Color = stone, Material = MAT.Sandstone })
	P(m, { Name = "Fachada", Size = V(32, 26, 3), CFrame = CF(0, 13, 1.5), Color = stoneLight, Material = MAT.Sandstone })
	-- pediment (triangle on top of the facade)
	P(m, { ClassName = "WedgePart", Size = V(3, 8, 16), CFrame = CF(-8, 30, 1.5) * ANG(0, PI / 2, 0), Color = stoneLight, Material = MAT.Sandstone })
	P(m, { ClassName = "WedgePart", Size = V(3, 8, 16), CFrame = CF(8, 30, 1.5) * ANG(0, -PI / 2, 0), Color = stoneLight, Material = MAT.Sandstone })
	-- buttresses (common on Philippine baroque churches)
	for _, x in { -15, 15 } do
		P(m, { ClassName = "WedgePart", Size = V(3, 14, 6), CFrame = CF(x, 7, 6) * ANG(0, PI, 0), Color = stone, Material = MAT.Sandstone })
	end
	-- door with arch
	P(m, { Name = "Pinto", Size = V(7, 11, 0.3), CFrame = CF(0, 6.7, 3.1), Color = C(80, 50, 30), Material = MAT.WoodPlanks })
	P(m, { Shape = Enum.PartType.Cylinder, Size = V(0.3, 7, 7), CFrame = CF(0, 12.2, 3.1) * ANG(0, PI / 2, 0), Color = C(80, 50, 30), Material = MAT.WoodPlanks })
	P(m, { Shape = Enum.PartType.Cylinder, Size = V(0.3, 4.5, 4.5), CFrame = CF(0, 20, 3.1) * ANG(0, PI / 2, 0), Color = C(80, 130, 210), Material = MAT.Glass, Transparency = 0.1 })
	for _, x in { -9, 9 } do
		P(m, { Size = V(2.4, 5, 0.3), CFrame = CF(x, 16, 3.1), Color = C(80, 130, 210), Material = MAT.Glass })
	end
	-- steps
	P(m, { Size = V(14, 0.6, 3), CFrame = CF(0, 0.3, 4.5), Color = C(170, 165, 155), Material = MAT.Concrete })
	P(m, { Size = V(12, 0.6, 1.5), CFrame = CF(0, 0.9, 3.8), Color = C(170, 165, 155), Material = MAT.Concrete })
	-- bell tower (kampanaryo)
	P(m, { Name = "Kampanaryo", Size = V(9, 34, 9), CFrame = CF(-20.5, 17, -2), Color = stone, Material = MAT.Sandstone })
	P(m, { Size = V(4, 5, 9.2), CFrame = CF(-20.5, 28, -2), Color = C(40, 35, 30) })
	P(m, { Size = V(9.2, 5, 4), CFrame = CF(-20.5, 28, -2), Color = C(40, 35, 30) })
	vcyl(m, -20.5, 26.5, -2, 2, 2, C(180, 150, 60), MAT.Metal)
	P(m, { Size = V(10, 1, 10), CFrame = CF(-20.5, 34.5, -2), Color = stoneLight, Material = MAT.Sandstone })
	P(m, { Size = V(6, 3, 6), CFrame = CF(-20.5, 36.5, -2), Color = stoneLight, Material = MAT.Sandstone })
	for _, spec in { { -20.5, 38 }, { 0, 34 } } do
		P(m, { Size = V(0.6, 4, 0.6), CFrame = CF(spec[1], spec[2] + 2, if spec[1] == 0 then 1.5 else -2), Color = Palette.white })
		P(m, { Size = V(2.6, 0.6, 0.6), CFrame = CF(spec[1], spec[2] + 2.8, if spec[1] == 0 then 1.5 else -2), Color = Palette.white })
	end
	usePoint(m, CFrame.lookAt(V(0, 0, 8), V(0, 0, 0)))
	promptPart(m, CF(0, 3, 6))
	return m
end

function Builders.Poso()
	local m = newModel("Poso", "Poso")
	local green = C(40, 110, 70)
	P(m, { Size = V(4, 0.4, 4), CFrame = CF(0, 0.2, 0), Color = C(170, 170, 165), Material = MAT.Concrete })
	vcyl(m, 0, 0.4, -0.8, 3.6, 0.9, green, MAT.Metal)
	P(m, { Name = "Spout", Size = V(0.4, 0.4, 1.2), CFrame = CF(0, 3.2, -0.1), Color = green, Material = MAT.Metal })
	P(m, { Name = "Hawakan", Size = V(0.25, 0.25, 3), CFrame = CF(0, 4.3, -1.8) * ANG(0.35, 0, 0), Color = green, Material = MAT.Metal })
	vcyl(m, 0, 0.4, 0.6, 1.2, 1.6, C(40, 110, 220), MAT.SmoothPlastic) -- timba sa ilalim
	usePoint(m, CFrame.lookAt(V(0, 0.4, 2.4), V(0, 0.4, 0)))
	return m
end

--------------------------------------------------------------------------
-- DECOR & STRUCTURES
--------------------------------------------------------------------------
function Builders.CoconutTree(seed: number?)
	local m = newModel("Niyog")
	local rng = Random.new(seed or 1)
	local height = rng:NextNumber(16, 24)
	local segments = 8
	local lean = rng:NextNumber(0.15, 0.35)
	local cf = CF(0, 0, 0) * ANG(0, rng:NextNumber(0, 2 * PI), 0)
	for i = 1, segments do
		local segLen = height / segments
		local d = 1.5 - (i / segments) * 0.5
		cf *= ANG(lean / segments, 0, 0)
		P(m, {
			Shape = Enum.PartType.Cylinder,
			Size = V(segLen + 0.3, d, d),
			CFrame = cf * CF(0, segLen / 2, 0) * ANG(0, 0, PI / 2),
			Color = if i % 2 == 0 then C(140, 112, 80) else C(125, 98, 70),
			Material = MAT.Wood,
		})
		cf *= CF(0, segLen, 0)
	end
	for i = 1, 3 do
		local a = i / 3 * 2 * PI
		ball(m, cf * CF(math.cos(a) * 0.7, -0.6, math.sin(a) * 0.7), 1.1, C(90, 120, 40))
	end
	for j = 0, 7 do
		local yaw = j / 8 * 2 * PI + rng:NextNumber(-0.15, 0.15)
		local up = rng:NextNumber(0.15, 0.4)
		local frame = cf * ANG(0, yaw, 0) * ANG(up, 0, 0)
		P(m, { Size = V(1.8, 0.15, 6.2), CFrame = frame * CF(0, 0, -3), Color = Palette.leaf, CanCollide = false })
		P(m, {
			Size = V(1.4, 0.15, 5.8),
			CFrame = frame * CF(0, 0, -6) * ANG(-0.75, 0, 0) * CF(0, 0, -2.8),
			Color = Palette.leafDark,
			CanCollide = false,
		})
	end
	return m
end

function Builders.StreetLamp()
	local m = newModel("Poste")
	vcyl(m, 0, 0, 0, 12.5, 0.5, C(40, 70, 50), MAT.Metal)
	P(m, { Size = V(0.3, 0.3, 3), CFrame = CF(0, 12.2, 1.4), Color = C(40, 70, 50), Material = MAT.Metal })
	local lamp = P(m, { Name = "Ilaw", Size = V(1.2, 0.5, 1.8), CFrame = CF(0, 11.9, 2.8), Color = C(255, 230, 170), Material = MAT.Neon })
	nightLight(lamp, 32, 3, C(255, 210, 140), true)
	P(m, { Name = "Top", Size = V(0.2, 0.2, 0.2), CFrame = CF(0, 12.6, 0), Transparency = 1, CanCollide = false })
	return m
end

-- String of fiesta flags between two world points. Returned model is in world space.
function Builders.Banderitas(a: Vector3, b: Vector3, sag: number?, seed: number?)
	local m = Instance.new("Model")
	m.Name = "Banderitas"
	local rng = Random.new(seed or 1)
	local dist = (b - a).Magnitude
	local count = math.max(2, math.floor(dist / 1.7))
	local sagDepth = sag or 2.5
	local flat = V(b.X - a.X, 0, b.Z - a.Z)
	flat = if flat.Magnitude > 0 then flat.Unit else V(1, 0, 0)
	local points = {}
	for i = 0, count do
		local t = i / count
		points[i] = a:Lerp(b, t) - V(0, 4 * sagDepth * t * (1 - t), 0)
	end
	for i = 0, count - 1 do
		local p0, p1 = points[i], points[i + 1]
		local mid = (p0 + p1) / 2
		P(m, {
			Size = V(0.06, 0.06, (p1 - p0).Magnitude),
			CFrame = CFrame.lookAt(mid, p1),
			Color = C(240, 240, 240),
			CanCollide = false,
			CastShadow = false,
		})
		pennant(m, CFrame.lookAt(mid, mid + flat), 1.3, 0.6, BANDERITAS_COLORS[rng:NextInteger(1, #BANDERITAS_COLORS)])
	end
	return m
end

function Builders.Bench()
	local m = newModel("Bangko")
	bench(m, CFrame.identity, 6)
	P(m, { Size = V(6, 1.2, 0.25), CFrame = CF(0, 2.6, 0.55), Color = Palette.wood, Material = MAT.WoodPlanks })
	return m
end

-- Open-sided hut with a nipa roof (used for the videoke area and beach cottage).
function Builders.Pavilion(width: number?, depth: number?)
	local m = newModel("Pavilion")
	local W, D = width or 14, depth or 12
	P(m, { Size = V(W, 0.4, D), CFrame = CF(0, 0.2, 0), Color = C(185, 175, 160), Material = MAT.Concrete })
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			vcyl(m, sx * (W / 2 - 0.6), 0.4, sz * (D / 2 - 0.6), 8.6, 0.7, Palette.bambooDark)
		end
	end
	gableRoof(m, CF(0, 9, 0), W, D, 4.5, 1.5, Palette.nipa, MAT.Grass, false)
	return m
end

function Builders.Shed(text: string?)
	local m = newModel("Shed")
	for _, x in { -5, 5 } do
		vcyl(m, x, 0, -1, 8, 0.5, Palette.metal, MAT.Metal)
	end
	P(m, { Size = V(12, 0.3, 5), CFrame = CF(0, 8, 0) * ANG(-0.12, 0, 0), Color = C(200, 60, 50), Material = MAT.CorrodedMetal })
	bench(m, CF(0, 0, -1), 9)
	local sign = P(m, { Size = V(8, 1.4, 0.2), CFrame = CF(0, 6.9, 2.3), Color = Palette.flagYellow })
	Util.surfaceText(sign, Enum.NormalId.Back, text or "SAKAYAN NG JEEP", Palette.flagBlue)
	return m
end

function Builders.Building(width: number, depth: number, height: number, color: Color3, text: string?)
	local m = newModel("Gusali")
	P(m, { Size = V(width, height, depth), CFrame = CF(0, height / 2, 0), Color = color, Material = MAT.Concrete })
	P(m, { Size = V(width + 1, 0.6, depth + 1), CFrame = CF(0, height + 0.3, 0), Color = C(120, 110, 100), Material = MAT.Concrete })
	P(m, { Size = V(4, 7, 0.3), CFrame = CF(0, 3.5, depth / 2 + 0.1), Color = C(70, 50, 35), Material = MAT.WoodPlanks })
	for _, x in { -width / 3, width / 3 } do
		P(m, { Size = V(4, 3, 0.2), CFrame = CF(x, height * 0.55, depth / 2 + 0.1), Color = C(150, 190, 220), Material = MAT.Glass })
	end
	if text then
		local sign = P(m, { Size = V(width * 0.7, 2, 0.3), CFrame = CF(0, height - 1.6, depth / 2 + 0.2), Color = Palette.white })
		Util.surfaceText(sign, Enum.NormalId.Back, text, Palette.flagBlue)
	end
	return m
end

function Builders.Bantayog()
	local m = newModel("Bantayog")
	P(m, { Size = V(12, 1, 12), CFrame = CF(0, 0.5, 0), Color = C(190, 185, 175), Material = MAT.Granite })
	P(m, { Size = V(8, 1, 8), CFrame = CF(0, 1.5, 0), Color = C(200, 195, 185), Material = MAT.Granite })
	P(m, { Size = V(3, 14, 3), CFrame = CF(0, 9, 0), Color = C(220, 215, 205), Material = MAT.Marble })
	P(m, { ClassName = "WedgePart", Size = V(3, 2, 1.5), CFrame = CF(0, 17, 0.75) * ANG(0, PI, 0), Color = C(220, 215, 205), Material = MAT.Marble })
	P(m, { ClassName = "WedgePart", Size = V(3, 2, 1.5), CFrame = CF(0, 17, -0.75), Color = C(220, 215, 205), Material = MAT.Marble })
	for i = 0, 3 do
		local a = i * PI / 2
		local frame = ANG(0, a, 0) * CF(0, 1.2, 5)
		P(m, { Size = V(6, 0.6, 1.4), CFrame = frame, Color = C(90, 60, 40), Material = MAT.Ground })
		for k = -2, 2 do
			ball(m, frame * CF(k * 1.1, 0.5, 0), 0.6, if k % 2 == 0 then C(230, 50, 80) else C(255, 200, 40))
		end
	end
	return m
end

-- The player's house. Floor top is at y = 4 (local).
function Builders.BahayKubo()
	local m = newModel("BahayKubo")
	local W, D, FH, WH = 30, 24, 4, 9
	-- haligi (stilts) — the open space underneath is the "silong"
	for _, x in { -W / 2 + 1, 0, W / 2 - 1 } do
		for _, z in { -D / 2 + 1, 0, D / 2 - 1 } do
			vcyl(m, x, 0, z, FH, 1.2, Palette.bambooDark)
		end
	end
	P(m, { Name = "Sahig", Size = V(W, 0.6, D), CFrame = CF(0, FH - 0.3, 0), Color = Palette.bamboo, Material = MAT.WoodPlanks })
	-- sawali walls with door and windows
	local wc, wm = Palette.sawali, MAT.Fabric
	wall(m, CF(0, FH, D / 2 - 0.25), W, WH, 0.5, {
		{ c = 0, w = 5, bottom = 0, top = 7 },
		{ c = -9, w = 5, bottom = 3, top = 6.5 },
		{ c = 9, w = 5, bottom = 3, top = 6.5 },
	}, wc, wm)
	wall(m, CF(0, FH, -D / 2 + 0.25), W, WH, 0.5, {
		{ c = -6, w = 5, bottom = 3, top = 6.5 },
		{ c = 6, w = 5, bottom = 3, top = 6.5 },
	}, wc, wm)
	for _, sx in { 1, -1 } do
		wall(m, CF(sx * (W / 2 - 0.25), FH, 0) * ANG(0, PI / 2, 0), D - 1, WH, 0.5, {
			{ c = 0, w = 5, bottom = 3, top = 6.5 },
		}, wc, wm)
	end
	-- corner posts & beams
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			vcyl(m, sx * (W / 2 - 0.3), FH, sz * (D / 2 - 0.3), WH, 0.8, Palette.bambooDark)
		end
	end
	-- propped-open window shutters (tukod)
	for _, x in { -9, 9 } do
		P(m, { Size = V(5.4, 0.2, 2.6), CFrame = CF(x, FH + 6.8, D / 2 + 1.0) * ANG(0.45, 0, 0), Color = Palette.nipa, Material = MAT.Grass })
	end
	gableRoof(m, CF(0, FH + WH, 0), W, D, 8, 2, Palette.nipa, MAT.Grass, true)
	-- hagdan (front stairs) with railing
	for i = 1, 3 do
		local top = FH - i
		P(m, { Size = V(5, top, 1.2), CFrame = CF(0, top / 2, D / 2 + (i - 0.5) * 1.2), Color = Palette.bamboo, Material = MAT.WoodPlanks })
	end
	for _, sx in { -1, 1 } do
		vcyl(m, sx * 2.6, 0, D / 2 + 3.6, 3.5, 0.3, Palette.bambooDark)
		P(m, {
			Size = V(0.25, 0.25, 4.2),
			CFrame = CF(sx * 2.6, 4.6, D / 2 + 1.8) * ANG(-0.6, 0, 0),
			Color = Palette.bambooDark,
			Material = MAT.Wood,
		})
	end
	return m
end

-- A whole residential lot: plot, bamboo fence (bakod), sign, bahay kubo, tree.
function Builders.Lot()
	local m = newModel("Lot")
	local half = 28
	P(m, { Name = "Plot", Size = V(half * 2, 0.2, half * 2), CFrame = CF(0, -0.1, 0), Color = C(112, 168, 76), Material = MAT.Grass })
	-- fence
	local function rail(fromV: Vector3, toV: Vector3)
		local mid = (fromV + toV) / 2
		for _, y in { 1.1, 2.4 } do
			P(m, {
				Size = V(0.25, 0.25, (toV - fromV).Magnitude),
				CFrame = CFrame.lookAt(mid + V(0, y, 0), toV + V(0, y, 0)),
				Color = Palette.bamboo,
				Material = MAT.Wood,
			})
		end
		local steps = math.floor((toV - fromV).Magnitude / 4)
		for i = 0, steps do
			local p = fromV:Lerp(toV, i / math.max(steps, 1))
			vcyl(m, p.X, 0, p.Z, 3, 0.4, Palette.bambooDark)
		end
	end
	rail(V(-half, 0, -half), V(half, 0, -half))
	rail(V(-half, 0, -half), V(-half, 0, half))
	rail(V(half, 0, -half), V(half, 0, half))
	rail(V(-half, 0, half), V(-5, 0, half))
	rail(V(5, 0, half), V(half, 0, half))
	-- house
	local kubo = Builders.BahayKubo()
	kubo:PivotTo(CF(0, 0, -8))
	kubo.Parent = m
	-- path from gate to stairs
	P(m, { Size = V(4, 0.1, 12), CFrame = CF(0, 0.05, 22), Color = C(150, 120, 85), Material = MAT.Ground })
	-- sign
	vcyl(m, 18, 0, 26, 5, 0.35, Palette.woodDark)
	local board = P(m, { Name = "Sign", Size = V(8, 2.5, 0.3), CFrame = CF(18, 4.6, 26.2) * ANG(0, PI, 0), Color = Palette.wood, Material = MAT.WoodPlanks })
	Util.surfaceText(board, Enum.NormalId.Front, "Bakanteng Lote", C(255, 240, 200))
	-- trees
	local tree = Builders.CoconutTree(math.random(1, 1000))
	tree:PivotTo(CF(-23, 0, 22))
	tree.Parent = m
	local tree2 = Builders.CoconutTree(math.random(1, 1000))
	tree2:PivotTo(CF(23, 0, -23))
	tree2.Parent = m
	return m
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------
function Models.has(id: string): boolean
	return Builders[id] ~= nil
end

function Models.build(id: string, ...): Model
	local builder = Builders[id]
	assert(builder, "Walang model builder para sa: " .. tostring(id))
	return builder(...)
end

return Models
