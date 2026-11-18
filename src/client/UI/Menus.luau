--[[
	Menus — the station choice menu ("Ano ang gagawin mo?") and the
	Kasanayan (skills) and Relasyon (relationships) panels.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Theme = require(script.Parent.Theme)

local create = Theme.create
local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Menus = {}

local gui: ScreenGui
local stationPanel: Frame?
local sidePanel: Frame?
local sidePanelKind: string?

local function effectSummary(def): string
	local parts = {}
	for _, id in Config.NeedOrder do
		local amount = def.effects[id]
		if amount and amount ~= 0 then
			table.insert(parts, string.format("%s%d %s", if amount > 0 then "+" else "", amount, Config.Needs[id].label))
		end
	end
	return table.concat(parts, "  ")
end

local function closeStation()
	if stationPanel then
		stationPanel:Destroy()
		stationPanel = nil
	end
end

function Menus.openStation(model: Model, stationId: string)
	closeStation()
	local cfg = Config.Stations[stationId]
	if not cfg then
		return
	end
	local rowHeight = 58
	local panel = Theme.panel({
		Name = "StationMenu",
		Size = UDim2.fromOffset(400, 64 + rowHeight * #cfg.actions + 50),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = gui,
	})
	stationPanel = panel
	Theme.label({
		Text = model:GetAttribute("DisplayName") or cfg.title,
		Font = Theme.fontTitle,
		TextSize = 22,
		TextColor3 = Theme.yellow,
		Size = UDim2.new(1, -24, 0, 28),
		Position = UDim2.fromOffset(12, 10),
		Parent = panel,
	})
	Theme.label({
		Text = "Ano ang gagawin mo?",
		TextSize = 14,
		TextColor3 = Theme.textDim,
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 38),
		Parent = panel,
	})

	local pesos = player:GetAttribute("Pesos") or 0
	for i, actionId in cfg.actions do
		local def = Config.Actions[actionId]
		local price = ""
		if def.cost and def.cost > 0 then
			price = "  ·  " .. Util.formatPesos(def.cost)
		elseif def.pay then
			price = "  ·  Sweldo ~" .. Util.formatPesos(def.pay)
		end
		local hours = if def.hours
			then string.format("  ·  %s–%s", Util.formatHour(def.hours[1]), Util.formatHour(def.hours[2]))
			else ""
		local affordable = (def.cost or 0) <= pesos
		local button = Theme.button({
			Text = "",
			Size = UDim2.new(1, -24, 0, rowHeight - 8),
			Position = UDim2.fromOffset(12, 64 + (i - 1) * rowHeight),
			BackgroundColor3 = if affordable then Theme.bgLight else Color3.fromRGB(70, 40, 40),
			Parent = panel,
		})
		Theme.label({
			Text = def.bubble .. "  " .. def.label .. price .. hours,
			Font = Theme.fontBold,
			TextSize = 15,
			Size = UDim2.new(1, -20, 0, 22),
			Position = UDim2.fromOffset(10, 4),
			Parent = button,
		})
		Theme.label({
			Text = effectSummary(def),
			TextSize = 12,
			TextColor3 = Theme.textDim,
			Size = UDim2.new(1, -20, 0, 18),
			Position = UDim2.fromOffset(10, 26),
			Parent = button,
		})
		button.Activated:Connect(function()
			Remotes.RequestAction:FireServer(model, actionId)
			closeStation()
		end)
	end

	local close = Theme.button({
		Text = "Isara",
		Size = UDim2.fromOffset(120, 36),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Parent = panel,
	})
	close.Activated:Connect(closeStation)

	-- close automatically if the player walks away
	task.spawn(function()
		while stationPanel == panel do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or not model.Parent or (root.Position - model:GetPivot().Position).Magnitude > 22 then
				closeStation()
				break
			end
			task.wait(0.3)
		end
	end)
end

--------------------------------------------------------------------------
-- Side panels
--------------------------------------------------------------------------
local function closeSide()
	if sidePanel then
		sidePanel:Destroy()
		sidePanel = nil
		sidePanelKind = nil
	end
end

local function sideFrame(title: string, rows: number): (Frame, Frame)
	local panel = Theme.panel({
		Name = "SidePanel",
		Size = UDim2.fromOffset(320, 60 + rows * 48),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -110, 0.5, 0),
		Parent = gui,
	})
	Theme.label({
		Text = title,
		Font = Theme.fontTitle,
		TextSize = 20,
		TextColor3 = Theme.yellow,
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 10),
		Parent = panel,
	})
	local list = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, -50),
		Position = UDim2.fromOffset(12, 44),
		Parent = panel,
	}, { create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	return panel, list
end

local function meterRow(list: Frame, order: number, left: string, right: string, fraction: number, color: Color3)
	local row = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = order, Parent = list })
	Theme.label({ Text = left, Font = Theme.fontBold, TextSize = 15, Size = UDim2.new(0.65, 0, 0, 20), Parent = row })
	Theme.label({
		Text = right,
		TextSize = 13,
		TextColor3 = Theme.textDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0.35, 0, 0, 20),
		Position = UDim2.fromScale(0.65, 0),
		Parent = row,
	})
	local bar = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(20, 16, 14),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.fromOffset(0, 26),
		Parent = row,
	}, { Theme.corner(5) })
	create("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
		Parent = bar,
	}, { Theme.corner(5) })
end

local function renderSkills()
	local panel, list = sideFrame("📊 Kasanayan", #Config.SkillOrder)
	for i, id in Config.SkillOrder do
		local info = Config.Skills[id]
		local xp = player:GetAttribute("Skill_" .. id) or 0
		local level = Config.skillLevel(xp)
		local progress = if level >= Config.MaxSkillLevel then 1 else (xp % Config.XpPerLevel) / Config.XpPerLevel
		meterRow(list, i, info.icon .. " " .. info.label, "Level " .. level, progress, Theme.yellow)
	end
	return panel
end

local function renderRelationships()
	local panel, list = sideFrame("❤️ Relasyon", #Config.NPCs)
	for i, npc in Config.NPCs do
		local value = player:GetAttribute("Rel_" .. npc.id) or 0
		meterRow(list, i, npc.name, Config.relationshipLabel(value), value / 100, Color3.fromRGB(240, 100, 140))
	end
	return panel
end

function Menus.toggle(kind: string)
	if sidePanelKind == kind then
		closeSide()
		return
	end
	closeSide()
	sidePanelKind = kind
	sidePanel = if kind == "skills" then renderSkills() else renderRelationships()
end

function Menus.init(screenGui: ScreenGui)
	gui = screenGui
	Remotes.OpenMenu.OnClientEvent:Connect(function(model, stationId)
		if typeof(model) == "Instance" and model:IsA("Model") then
			Menus.openStation(model, stationId)
		end
	end)
	-- keep an open side panel live
	player.AttributeChanged:Connect(function(name)
		if sidePanelKind and (name:sub(1, 6) == "Skill_" or name:sub(1, 4) == "Rel_") then
			local kind = sidePanelKind
			closeSide()
			Menus.toggle(kind)
		end
	end)
end

function Menus.closeAll()
	closeStation()
	closeSide()
end

return Menus
