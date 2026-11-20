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
	local cityId = model:GetAttribute("City")
	for i, actionId in cfg.actions do
		local def = Config.Actions[actionId]
		local cost = Config.scaledCost(def, cityId)
		local price = ""
		if cost > 0 then
			price = "  ·  " .. Util.formatPesos(cost)
		elseif def.pay then
			price = "  ·  Sweldo ~" .. Util.formatPesos(def.pay * Config.city(cityId).payMult)
		end
		if def.profession and player:GetAttribute("Profession") ~= def.profession then
			price ..= "  ·  🔒 " .. Config.Professions[def.profession].label
		end
		local hours = if def.hours
			then string.format("  ·  %s–%s", Util.formatHour(def.hours[1]), Util.formatHour(def.hours[2]))
			else ""
		local affordable = cost <= pesos
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

-- "Ako" — your own private identity. Nobody else can see this (only your age is public).
local function renderIdentity()
	local rows = {
		{ "📍 Bayang sinilangan", Config.city(player:GetAttribute("Hometown")).name },
		{ "🏠 Tirahan", Config.city(player:GetAttribute("HomeCity")).name },
		{ "🎂 Edad", tostring(player:GetAttribute("Age") or "?") .. " taong gulang" },
	}
	for _, metric in Config.MetricOrder do
		local m = Config.Metrics[metric]
		table.insert(rows, { m.icon .. " " .. m.label, Config.tierLabel(metric, player:GetAttribute(metric)) })
	end
	local talent = Config.Skills[player:GetAttribute("Talent")]
	table.insert(rows, { "✨ Likas na galing", if talent then talent.icon .. " " .. talent.label else "?" })
	local papa = Config.Professions[player:GetAttribute("Papa")]
	local mama = Config.Professions[player:GetAttribute("Mama")]
	table.insert(rows, { "👨 Papa", if papa then papa.label else "?" })
	table.insert(rows, { "👩 Mama", if mama then mama.label else "?" })
	local edu = Config.Education[player:GetAttribute("Education") or "none"]
	table.insert(rows, { "🎓 Edukasyon", if edu then edu.label else "?" })
	local prof = Config.Professions[player:GetAttribute("Profession")]
	table.insert(rows, { "💼 Trabaho", if prof then prof.icon .. " " .. prof.label else "Wala pa" })

	local panel = Theme.panel({
		Name = "SidePanel",
		Size = UDim2.fromOffset(340, 60 + #rows * 28 + 30),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -110, 0.5, 0),
		Parent = gui,
	})
	Theme.label({
		Text = "🪪 Ako",
		Font = Theme.fontTitle,
		TextSize = 20,
		TextColor3 = Theme.yellow,
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 10),
		Parent = panel,
	})
	for i, row in rows do
		local y = 44 + (i - 1) * 28
		Theme.label({ Text = row[1], TextSize = 14, TextColor3 = Theme.textDim, Size = UDim2.new(0.5, -12, 0, 24), Position = UDim2.fromOffset(12, y), Parent = panel })
		Theme.label({ Text = row[2], Font = Theme.fontBold, TextSize = 14, Size = UDim2.new(0.5, -12, 0, 24), Position = UDim2.new(0.5, 0, 0, y), Parent = panel })
	end
	Theme.label({
		Text = "🔒 Ikaw lang ang nakakakita nito. Edad lang ang nakikita ng iba.",
		TextSize = 12,
		TextColor3 = Theme.textDim,
		TextWrapped = true,
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.new(0, 12, 1, -32),
		Parent = panel,
	})
	return panel
end

function Menus.toggle(kind: string)
	if sidePanelKind == kind then
		closeSide()
		return
	end
	closeSide()
	sidePanelKind = kind
	sidePanel = if kind == "skills"
		then renderSkills()
		elseif kind == "identity" then renderIdentity()
		else renderRelationships()
end

--------------------------------------------------------------------------
-- PESO job board
--------------------------------------------------------------------------
function Menus.openCareer()
	closeStation()
	local rowHeight = 50
	local panel = Theme.panel({
		Name = "CareerMenu",
		Size = UDim2.fromOffset(560, 70 + rowHeight * #Config.ProfessionOrder + 54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = gui,
	})
	local uiScale = create("UIScale", {})
	uiScale.Parent = panel
	local view = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.clamp(math.min((view.X - 24) / 560, (view.Y - 24) / panel.Size.Y.Offset), 0.45, 1)
	stationPanel = panel

	Theme.label({
		Text = "💼 PESO — Public Employment Service Office",
		Font = Theme.fontTitle,
		TextSize = 20,
		TextColor3 = Theme.yellow,
		Size = UDim2.new(1, -24, 0, 28),
		Position = UDim2.fromOffset(12, 10),
		Parent = panel,
	})
	local edu = Config.Education[player:GetAttribute("Education") or "none"]
	Theme.label({
		Text = "Edukasyon mo: " .. (if edu then edu.label else "?") .. "  ·  Pumili ng trabaho. Sa mga nakalistang bayan lang ito pwedeng gawin.",
		TextSize = 13,
		TextColor3 = Theme.textDim,
		TextWrapped = true,
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 38),
		Parent = panel,
	})
	local current = player:GetAttribute("Profession")
	for i, id in Config.ProfessionOrder do
		local prof = Config.Professions[id]
		local job = Config.Actions[prof.job]
		local unlocked = Config.meetsEducation(player:GetAttribute("Education"), prof.education)
		local icons = {}
		for _, cityId in prof.cities do
			table.insert(icons, Config.city(cityId).icon)
		end
		local button = Theme.button({
			Text = "",
			Size = UDim2.new(1, -24, 0, rowHeight - 6),
			Position = UDim2.fromOffset(12, 70 + (i - 1) * rowHeight),
			BackgroundColor3 = if id == current then Color3.fromRGB(40, 110, 60)
				elseif unlocked then Theme.bgLight
				else Color3.fromRGB(60, 45, 45),
			Parent = panel,
		})
		Theme.label({
			Text = prof.icon .. "  " .. prof.label .. (if id == current then "  ✓" else ""),
			Font = Theme.fontBold,
			TextSize = 15,
			Size = UDim2.new(0.55, 0, 0, 20),
			Position = UDim2.fromOffset(10, 4),
			Parent = button,
		})
		local hours = if job and job.hours
			then string.format("%s–%s", Util.formatHour(job.hours[1]), Util.formatHour(job.hours[2]))
			else "Kahit anong oras"
		Theme.label({
			Text = string.format("~%s/shift  ·  %s  ·  %s", Util.formatPesos(job and job.pay or 0), hours, table.concat(icons, " ")),
			TextSize = 12,
			TextColor3 = Theme.textDim,
			Size = UDim2.new(1, -20, 0, 18),
			Position = UDim2.fromOffset(10, 24),
			Parent = button,
		})
		local need = Config.Education[prof.education]
		Theme.label({
			Text = if unlocked then "Bukas" else "🔒 " .. (if need then need.label else prof.education),
			TextSize = 12,
			TextColor3 = if unlocked then Color3.fromRGB(140, 230, 140) else Color3.fromRGB(240, 150, 140),
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(0.45, -10, 0, 20),
			Position = UDim2.new(0.55, 0, 0, 4),
			Parent = button,
		})
		button.Activated:Connect(function()
			if unlocked then
				Remotes.ChooseProfession:FireServer(id)
				closeStation()
			end
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
end

function Menus.init(screenGui: ScreenGui)
	gui = screenGui
	Remotes.OpenCareer.OnClientEvent:Connect(Menus.openCareer)
	Remotes.OpenMenu.OnClientEvent:Connect(function(model, stationId)
		if typeof(model) == "Instance" and model:IsA("Model") then
			Menus.openStation(model, stationId)
		end
	end)
	-- keep an open side panel live
	player.AttributeChanged:Connect(function(name)
		local identityField = name == "Profession" or name == "Age" or name == "HomeCity" or name == "Education"
		if sidePanelKind and (name:sub(1, 6) == "Skill_" or name:sub(1, 4) == "Rel_" or identityField) then
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
