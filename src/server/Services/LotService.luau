--[[
	LotService — residential lots in each of the three cities.
	Baybay Alon and San Bukid lots have a bahay kubo; Metro Dakila lots have a concrete bungalow.
	A joining player gets a free lot in their hometown if possible, otherwise any free lot.

	Lot model layout (in workspace.Lots):
	  <City>Lot<N> (Model, attributes OwnerUserId, City, LotIndex)
	    ├─ Origin    invisible part; its CFrame is the lot's coordinate frame (+Z faces the road)
	    ├─ Furniture folder of placed furniture models
	    └─ … plot, fence, house, sign
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(ReplicatedStorage.Shared.Models)
local Util = require(ReplicatedStorage.Shared.Util)

local LotService = {}

export type Lot = {
	index: number,
	city: string,
	floorY: number,
	origin: CFrame,
	model: Model,
	furniture: Folder,
	owner: Player?,
}

local lots: { Lot } = {}

-- Lot centres relative to each city's origin, and the direction toward the road.
local LOT_OFFSETS = {
	{ pos = Vector3.new(-60, 0.2, 115), toRoad = Vector3.new(0, 0, -1) },
	{ pos = Vector3.new(0, 0.2, 115), toRoad = Vector3.new(0, 0, -1) },
	{ pos = Vector3.new(60, 0.2, 115), toRoad = Vector3.new(0, 0, -1) },
	{ pos = Vector3.new(-60, 0.2, -115), toRoad = Vector3.new(0, 0, 1) },
	{ pos = Vector3.new(0, 0.2, -115), toRoad = Vector3.new(0, 0, 1) },
	{ pos = Vector3.new(60, 0.2, -115), toRoad = Vector3.new(0, 0, 1) },
}

local function setSign(lot: Lot, text: string)
	local sign = lot.model:FindFirstChild("Sign", true)
	local label = sign and sign:FindFirstChild("Label", true)
	if label then
		(label :: TextLabel).Text = text
	end
end

function LotService.init()
	local folder = Instance.new("Folder")
	folder.Name = "Lots"
	folder.Parent = workspace

	for _, cityId in Config.CityOrder do
		local city = Config.Cities[cityId]
		local style = city.house
		for n, layout in LOT_OFFSETS do
			local pos = city.origin + layout.pos
			-- lookAt makes -Z face the target; we want +Z to face the road.
			local origin = CFrame.lookAt(pos, pos - layout.toRoad)
			local model = Models.build("Lot", style)
			model.Name = cityId .. "Lot" .. n
			model:PivotTo(origin)

			Util.part({
				Name = "Origin",
				Size = Vector3.new(1, 1, 1),
				CFrame = origin,
				Transparency = 1,
				CanCollide = false,
				CanTouch = false,
				CanQuery = false,
				Parent = model,
			})
			local furniture = Instance.new("Folder")
			furniture.Name = "Furniture"
			furniture.Parent = model

			local index = #lots + 1
			model:SetAttribute("LotIndex", index)
			model:SetAttribute("City", cityId)
			model.Parent = folder

			lots[index] = {
				index = index,
				city = cityId,
				floorY = Config.HouseTypes[style].floorY,
				origin = origin,
				model = model,
				furniture = furniture,
				owner = nil,
			}
		end
	end
end

local function claim(lot: Lot, player: Player)
	lot.owner = player
	lot.model:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("LotIndex", lot.index)
	player:SetAttribute("HomeCity", lot.city)
	setSign(lot, "Bahay ni " .. player.DisplayName)
end

-- Prefer a lot in `preferredCity`; fall back to any free lot.
function LotService.assign(player: Player, preferredCity: string?): Lot?
	for _, lot in lots do
		if lot.owner == nil and lot.city == preferredCity then
			claim(lot, player)
			return lot
		end
	end
	for _, lot in lots do
		if lot.owner == nil then
			claim(lot, player)
			return lot
		end
	end
	return nil
end

function LotService.release(player: Player)
	for _, lot in lots do
		if lot.owner == player then
			lot.owner = nil
			lot.model:SetAttribute("OwnerUserId", nil)
			lot.furniture:ClearAllChildren()
			setSign(lot, "Bakanteng Lote")
		end
	end
end

function LotService.get(player: Player): Lot?
	for _, lot in lots do
		if lot.owner == player then
			return lot
		end
	end
	return nil
end

-- Where a player appears at home: in the yard, facing the house.
function LotService.spawnCFrame(lot: Lot): CFrame
	return lot.origin * CFrame.new(0, 3.5, 18)
end

function LotService.all(): { Lot }
	return lots
end

return LotService
