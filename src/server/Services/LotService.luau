--[[
	LotService — six residential lots (with a bahay kubo each) around the plaza.
	Each joining player is given a free lot; it is cleared when they leave.

	Lot model layout (in workspace.Lots):
	  LotN (Model, attribute OwnerUserId)
	    ├─ Origin    invisible part; its CFrame is the lot's coordinate frame (+Z faces the road)
	    ├─ Furniture folder of placed furniture models
	    └─ … plot, fence, house, sign
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Models = require(ReplicatedStorage.Shared.Models)
local Util = require(ReplicatedStorage.Shared.Util)

local LotService = {}

export type Lot = {
	index: number,
	origin: CFrame,
	model: Model,
	furniture: Folder,
	owner: Player?,
}

local lots: { Lot } = {}

-- Lot centres and the direction toward the road they face.
local LOT_LAYOUT = {
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

	for index, layout in LOT_LAYOUT do
		-- lookAt makes -Z face the target; we want +Z to face the road.
		local origin = CFrame.lookAt(layout.pos, layout.pos - layout.toRoad)
		local model = Models.build("Lot")
		model.Name = "Lot" .. index
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

		model:SetAttribute("LotIndex", index)
		model.Parent = folder

		lots[index] = { index = index, origin = origin, model = model, furniture = furniture, owner = nil }
	end
end

function LotService.assign(player: Player): Lot?
	for _, lot in lots do
		if lot.owner == nil then
			lot.owner = player
			lot.model:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("LotIndex", lot.index)
			setSign(lot, "Bahay ni " .. player.DisplayName)
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
