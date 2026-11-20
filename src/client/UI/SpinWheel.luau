--[[
	SpinWheel — "Ikot ng Kapalaran", the first thing a new player sees.
	The server has already rolled the result (so it can't be re-rolled by rejoining);
	this screen lets the player press "Iikot!" and watch four reels land on their life:
	  Bayan (hometown) · Yaman (wealth) · Swerte (luck) · DNA (talent)
	The odds are shown under each reel.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Theme)

local create = Theme.create
local player = Players.LocalPlayer

local SpinWheel = {}

local function percent(weight: number, total: number): string
	return string.format("%d%%", math.floor(weight / total * 100 + 0.5))
end

-- Build the reel definitions: { title, options = {label...}, odds = {text...}, result = index }
local function reels()
	local list = {}
	local cityLabels, cityOdds, cityTotal = {}, {}, 0
	for _, id in Config.CityOrder do
		cityTotal += Config.Cities[id].weight
	end
	local resultCity = 1
	for i, id in Config.CityOrder do
		local c = Config.Cities[id]
		cityLabels[i] = c.icon .. " " .. c.name
		cityOdds[i] = c.name .. " " .. percent(c.weight, cityTotal)
		if id == player:GetAttribute("Hometown") then
			resultCity = i
		end
	end
	table.insert(list, { title = "📍 Bayan", options = cityLabels, odds = cityOdds, result = resultCity })
	for _, metric in Config.MetricOrder do
		local m = Config.Metrics[metric]
		local labels, odds, total = {}, {}, 0
		for _, t in m.tiers do
			total += t.weight
		end
		for i, t in m.tiers do
			labels[i] = t.label
			odds[i] = t.label .. " " .. percent(t.weight, total)
		end
		table.insert(list, {
			title = m.icon .. " " .. m.label,
			options = labels,
			odds = odds,
			result = player:GetAttribute(metric) or 2,
		})
	end
	return list
end

function SpinWheel.show(gui: ScreenGui, onDone: () -> ())
	local overlay = create("Frame", {
		Name = "SpinWheel",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = gui,
	})
	local panel = Theme.panel({
		Size = UDim2.new(0, 720, 0, 430),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 51,
		Parent = overlay,
	})
	create("UISizeConstraint", { MaxSize = Vector2.new(720, 430) }).Parent = panel
	local uiScale = create("UIScale", { Name = "Scale" })
	uiScale.Parent = panel

	local function text(props)
		props.ZIndex = 52
		props.Parent = props.Parent or panel
		return Theme.label(props)
	end

	text({
		Text = "🎡 Ikot ng Kapalaran",
		Font = Theme.fontTitle,
		TextSize = 30,
		TextColor3 = Theme.yellow,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 14),
	})
	text({
		Text = "Hindi mo pinipili kung saan ka isisilang. Ang mahalaga ay kung ano ang gagawin mo.",
		TextSize = 15,
		TextColor3 = Theme.textDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -40, 0, 36),
		Position = UDim2.fromOffset(20, 52),
	})

	local defs = reels()
	local reelLabels = {}
	local reelWidth = 160
	local startX = (720 - (#defs * reelWidth + (#defs - 1) * 12)) / 2
	for i, def in defs do
		local x = startX + (i - 1) * (reelWidth + 12)
		local frame = create("Frame", {
			BackgroundColor3 = Theme.bgLight,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(reelWidth, 190),
			Position = UDim2.fromOffset(x, 100),
			ZIndex = 52,
			Parent = panel,
		}, { Theme.corner(12) })
		text({
			Text = def.title,
			Font = Theme.fontBold,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 26),
			Position = UDim2.fromOffset(0, 8),
			Parent = frame,
		})
		local window = create("Frame", {
			BackgroundColor3 = Color3.fromRGB(20, 16, 14),
			BorderSizePixel = 0,
			Size = UDim2.new(1, -16, 0, 56),
			Position = UDim2.fromOffset(8, 40),
			ZIndex = 52,
			Parent = frame,
		}, { Theme.corner(10), Theme.stroke(Theme.yellow, 2) })
		reelLabels[i] = text({
			Text = "?",
			Font = Theme.fontTitle,
			TextSize = 20,
			TextWrapped = true,
			TextColor3 = Theme.text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			Parent = window,
		})
		text({
			Text = table.concat(def.odds, "\n"),
			TextSize = 13,
			TextColor3 = Theme.textDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -8, 0, 80),
			Position = UDim2.fromOffset(4, 104),
			Parent = frame,
		})
	end

	local summary = text({
		Text = "",
		Font = Theme.fontBold,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -40, 0, 44),
		Position = UDim2.fromOffset(20, 300),
	})

	local button = Theme.button({
		Text = "Iikot!",
		TextSize = 22,
		Font = Theme.fontTitle,
		BackgroundColor3 = Theme.red,
		Size = UDim2.fromOffset(220, 52),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		ZIndex = 52,
		Parent = panel,
	})

	-- fit small (phone) screens
	local function rescale()
		local view = workspace.CurrentCamera.ViewportSize
		local scale = math.min(1, (view.X - 24) / 720, (view.Y - 24) / 430)
		uiScale.Scale = math.max(scale, 0.45)
	end
	rescale()
	local resizeConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	local state = "ready"
	button.Activated:Connect(function()
		if state == "ready" then
			state = "spinning"
			button.Text = "..."
			for i, def in defs do
				task.spawn(function()
					local spins = 14 + i * 7
					for n = 1, spins do
						reelLabels[i].Text = def.options[(n % #def.options) + 1]
						task.wait(0.05 + n / spins * 0.08)
					end
					reelLabels[i].Text = def.options[def.result]
					reelLabels[i].TextColor3 = Theme.yellow
					local pop = TweenService:Create(reelLabels[i], TweenInfo.new(0.25, Enum.EasingStyle.Back), { TextSize = 24 })
					pop:Play()
				end)
			end
			task.wait(4.6) -- the slowest reel takes ~3.8s
			local city = Config.city(player:GetAttribute("Hometown"))
			local papa = Config.Professions[player:GetAttribute("Papa")]
			local mama = Config.Professions[player:GetAttribute("Mama")]
			local talent = Config.Skills[player:GetAttribute("Talent")]
			summary.Text = string.format(
				"Isinilang ka sa %s. Si Papa ay %s at si Mama ay %s. Likas kang magaling sa %s.",
				city.name,
				papa and papa.label:lower() or "?",
				mama and mama.label:lower() or "?",
				talent and talent.label:lower() or "?"
			)
			button.Text = "Simulan ang Buhay!"
			button.BackgroundColor3 = Theme.green
			state = "done"
		elseif state == "done" then
			state = "closed"
			resizeConn:Disconnect()
			overlay:Destroy()
			onDone()
		end
	end)
end

return SpinWheel
