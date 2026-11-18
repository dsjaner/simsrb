--[[
	HUD — always-on screen elements:
	  • top-left: pesos, day & clock, mood
	  • bottom-left: the six need bars
	  • bottom-centre: current action + progress + "Itigil" (stop) button
	  • top-centre: toast notifications
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Theme = require(script.Parent.Theme)

local create = Theme.create
local player = Players.LocalPlayer

local HUD = {}

local toastHolder: Frame
local needFills: { [string]: Frame } = {}
local needValues: { [string]: TextLabel } = {}
local pesosLabel: TextLabel
local clockLabel: TextLabel
local moodLabel: TextLabel
local actionFrame: Frame
local actionLabel: TextLabel
local actionFill: Frame

local function buildStatusCard(gui: ScreenGui)
	local card = Theme.panel({
		Name = "Status",
		Size = UDim2.fromOffset(270, 104),
		Position = UDim2.fromOffset(12, 12),
		Parent = gui,
	})
	Theme.label({
		Text = "🏠 " .. Config.GameName,
		Font = Theme.fontTitle,
		TextSize = 20,
		TextColor3 = Theme.yellow,
		Size = UDim2.new(1, -24, 0, 24),
		Position = UDim2.fromOffset(12, 8),
		Parent = card,
	})
	pesosLabel = Theme.label({
		Text = "₱0",
		Font = Theme.fontBold,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(140, 230, 140),
		Size = UDim2.new(1, -24, 0, 24),
		Position = UDim2.fromOffset(12, 34),
		Parent = card,
	})
	clockLabel = Theme.label({
		Text = "",
		TextSize = 15,
		TextColor3 = Theme.textDim,
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 60),
		Parent = card,
	})
	moodLabel = Theme.label({
		Text = "★ Ayos lang",
		Font = Theme.fontBold,
		TextSize = 15,
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 80),
		Parent = card,
	})
end

local function buildNeeds(gui: ScreenGui)
	local rowHeight = 30
	local panel = Theme.panel({
		Name = "Needs",
		Size = UDim2.fromOffset(270, 40 + rowHeight * #Config.NeedOrder),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Parent = gui,
	})
	Theme.label({
		Text = "Pangangailangan",
		Font = Theme.fontTitle,
		TextSize = 17,
		TextColor3 = Theme.yellow,
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 8),
		Parent = panel,
	})
	for i, id in Config.NeedOrder do
		local info = Config.Needs[id]
		local y = 34 + (i - 1) * rowHeight
		Theme.label({
			Text = info.icon .. " " .. info.label,
			TextSize = 14,
			Size = UDim2.fromOffset(110, 20),
			Position = UDim2.fromOffset(12, y),
			Parent = panel,
		})
		local bar = create("Frame", {
			BackgroundColor3 = Color3.fromRGB(20, 16, 14),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(110, 14),
			Position = UDim2.fromOffset(120, y + 3),
			Parent = panel,
		}, { Theme.corner(7) })
		local fill = create("Frame", {
			BackgroundColor3 = info.color,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = bar,
		}, { Theme.corner(7) })
		needFills[id] = fill
		needValues[id] = Theme.label({
			Text = "100",
			TextSize = 13,
			TextColor3 = Theme.textDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(30, 20),
			Position = UDim2.fromOffset(230, y),
			Parent = panel,
		})
	end
end

local function buildActionBar(gui: ScreenGui, onCancel: () -> ())
	actionFrame = Theme.panel({
		Name = "Action",
		Size = UDim2.fromOffset(380, 64),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Visible = false,
		Parent = gui,
	})
	actionLabel = Theme.label({
		Text = "",
		Font = Theme.fontBold,
		TextSize = 16,
		Size = UDim2.new(1, -120, 0, 22),
		Position = UDim2.fromOffset(14, 8),
		Parent = actionFrame,
	})
	local bar = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(20, 16, 14),
		BorderSizePixel = 0,
		Size = UDim2.new(1, -120, 0, 14),
		Position = UDim2.fromOffset(14, 38),
		Parent = actionFrame,
	}, { Theme.corner(7) })
	actionFill = create("Frame", {
		BackgroundColor3 = Theme.yellow,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	}, { Theme.corner(7) })
	local stop = Theme.button({
		Text = "Itigil",
		BackgroundColor3 = Theme.red,
		Size = UDim2.fromOffset(88, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Parent = actionFrame,
	})
	stop.Activated:Connect(onCancel)
end

local function refreshNeeds()
	for _, id in Config.NeedOrder do
		local value = player:GetAttribute("Need_" .. id) or 100
		local fill = needFills[id]
		fill.Size = UDim2.fromScale(math.clamp(value / 100, 0, 1), 1)
		fill.BackgroundColor3 = if value < 25 then Color3.fromRGB(230, 60, 60) else Config.Needs[id].color
		needValues[id].Text = tostring(math.floor(value + 0.5))
	end
	local mood = Config.getMood(Util.averageNeeds(player, Config.NeedOrder))
	moodLabel.Text = "★ " .. mood.label
	moodLabel.TextColor3 = mood.color
end

local function refreshAction()
	local verb = player:GetAttribute("CurrentAction")
	actionFrame.Visible = verb ~= nil
	if verb then
		actionLabel.Text = verb .. "..."
		actionFill.Size = UDim2.fromScale(player:GetAttribute("ActionProgress") or 0, 1)
	end
end

function HUD.notify(text: string, kind: string?)
	local color = Theme.toast[kind or "info"] or Theme.toast.info
	local toast = create("TextLabel", {
		Text = text,
		Font = Theme.fontBold,
		TextSize = 16,
		TextWrapped = true,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.08,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = toastHolder,
	}, { Theme.corner(10), Theme.padding(10) })
	task.delay(5, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
	-- keep at most 5 toasts
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 5 then
		toasts[1]:Destroy()
	end
end

function HUD.init(gui: ScreenGui, onCancel: () -> ())
	buildStatusCard(gui)
	buildNeeds(gui)
	buildActionBar(gui, onCancel)

	toastHolder = create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(420, 400),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Parent = gui,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	player.AttributeChanged:Connect(function(name)
		if name:sub(1, 5) == "Need_" then
			refreshNeeds()
		elseif name == "Pesos" then
			pesosLabel.Text = Util.formatPesos(player:GetAttribute("Pesos"))
		elseif name == "CurrentAction" or name == "ActionProgress" then
			refreshAction()
		end
	end)
	refreshNeeds()
	refreshAction()
	pesosLabel.Text = Util.formatPesos(player:GetAttribute("Pesos"))

	task.spawn(function()
		while gui.Parent do
			local t = Lighting.ClockTime
			local day = ReplicatedStorage:GetAttribute("Day") or 1
			clockLabel.Text = string.format("Araw %d · %s · %s", day, Util.formatClock(t), Util.timeOfDay(t))
			task.wait(0.5)
		end
	end)
end

return HUD
