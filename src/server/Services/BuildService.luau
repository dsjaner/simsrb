--[[
	BuildService — buying, placing and selling furniture on your own lot.
	The client sends lot-relative coordinates; the server validates everything
	(ownership, bounds, money, limits) before spawning the model.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(ReplicatedStorage.Shared.Models)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(script.Parent.Remotes)
local LotService = require(script.Parent.LotService)
local StationService = require(script.Parent.StationService)

local BuildService = {}

local function isFiniteNumber(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function BuildService.spawn(lot, id: string, x: number, y: number, z: number, rotation: number): Model?
	if not Config.FurnitureById[id] or not Models.has(id) then
		return nil
	end
	local model = Models.build(id)
	model:SetAttribute("FurnitureId", id)
	if lot.owner then
		model:SetAttribute("OwnerUserId", lot.owner.UserId)
	end
	model:SetAttribute("DisplayName", Config.FurnitureById[id].name)
	model:PivotTo(lot.origin * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotation), 0))
	model.Parent = lot.furniture
	StationService.make(model)
	return model
end

-- Furniture → plain table for saving (lot-relative, so it loads on any lot).
function BuildService.serialize(player: Player): { any }
	local lot = LotService.get(player)
	local list = {}
	if not lot then
		return list
	end
	for _, model in lot.furniture:GetChildren() do
		local id = model:GetAttribute("FurnitureId")
		if id and model:IsA("Model") then
			local rel = lot.origin:ToObjectSpace(model:GetPivot())
			local _, ry, _ = rel:ToOrientation()
			table.insert(list, {
				id = id,
				x = math.floor(rel.X * 100 + 0.5) / 100,
				y = math.floor(rel.Y * 100 + 0.5) / 100,
				z = math.floor(rel.Z * 100 + 0.5) / 100,
				r = (math.floor(math.deg(ry) / 90 + 0.5) * 90) % 360,
			})
		end
	end
	return list
end

function BuildService.load(player: Player, furniture: { any }?)
	local lot = LotService.get(player)
	if not lot then
		return
	end
	lot.furniture:ClearAllChildren()
	for _, item in furniture or Config.StarterFurniture do
		BuildService.spawn(lot, item.id, item.x, item.y, item.z, item.r or 0)
	end
end

function BuildService.count(player: Player): number
	local lot = LotService.get(player)
	return if lot then #lot.furniture:GetChildren() else 0
end

local function place(player: Player, id: any, x: any, y: any, z: any, rotation: any): (boolean, string)
	if type(id) ~= "string" or not Config.FurnitureById[id] then
		return false, "Hindi kilalang gamit."
	end
	if not (isFiniteNumber(x) and isFiniteNumber(y) and isFiniteNumber(z) and isFiniteNumber(rotation)) then
		return false, "Maling posisyon."
	end
	local lot = LotService.get(player)
	if not lot then
		return false, "Wala kang lote."
	end
	local half = Config.LotHalfSize
	if math.abs(x) > half or math.abs(z) > half or y < -0.5 or y > Config.MaxBuildHeight then
		return false, "Sa loob lang ng lote mo pwedeng maglagay."
	end
	if #lot.furniture:GetChildren() >= Config.MaxFurniturePerLot then
		return false, "Puno na ang bahay mo! Magbenta muna ng gamit."
	end
	local item = Config.FurnitureById[id]
	local pesos = player:GetAttribute("Pesos") or 0
	if pesos < item.price then
		return false, "💸 Kulang ang pera mo para sa " .. item.name .. "."
	end

	x = math.floor(x * 2 + 0.5) / 2
	z = math.floor(z * 2 + 0.5) / 2
	rotation = (math.floor(rotation / 90 + 0.5) * 90) % 360

	player:SetAttribute("Pesos", pesos - item.price)
	BuildService.spawn(lot, id, x, y, z, rotation)
	return true, "🛒 Nabili mo ang " .. item.name .. " (" .. Util.formatPesos(item.price) .. ")"
end

local function sell(player: Player, model: any): (boolean, string)
	local lot = LotService.get(player)
	if not lot or typeof(model) ~= "Instance" or model.Parent ~= lot.furniture then
		return false, "Hindi mo ito pwedeng ibenta."
	end
	if model:GetAttribute("InUseBy") then
		return false, "May gumagamit pa nito."
	end
	local item = Config.FurnitureById[model:GetAttribute("FurnitureId")]
	local refund = if item then math.floor(item.price * Config.SellRefund) else 0
	model:Destroy()
	player:SetAttribute("Pesos", (player:GetAttribute("Pesos") or 0) + refund)
	return true, "💰 Naibenta sa halagang " .. Util.formatPesos(refund)
end

function BuildService.init()
	Remotes.PlaceFurniture.OnServerInvoke = function(player, id, x, y, z, rotation)
		local ok, msg = place(player, id, x, y, z, rotation)
		return ok, msg
	end
	Remotes.SellFurniture.OnServerInvoke = function(player, model)
		local ok, msg = sell(player, model)
		return ok, msg
	end
end

return BuildService
