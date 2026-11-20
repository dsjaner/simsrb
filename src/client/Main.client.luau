--[[
	Bahay Buhay — client entry point.
	Builds the HUD, menus and build mode, and cancels actions when the player moves.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Theme = require(script.Parent:WaitForChild("UI"):WaitForChild("Theme"))
local HUD = require(script.Parent.UI.HUD)
local Menus = require(script.Parent.UI.Menus)
local BuildMode = require(script.Parent:WaitForChild("BuildMode"))
local SpinWheel = require(script.Parent.UI:WaitForChild("SpinWheel"))

-- wait for the server to finish loading our save
if not player:GetAttribute("Loaded") then
	player:GetAttributeChangedSignal("Loaded"):Wait()
end

local gui = Instance.new("ScreenGui")
gui.Name = "BahayBuhayHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function cancelAction()
	if player:GetAttribute("CurrentAction") then
		Remotes.CancelAction:FireServer()
	end
end

HUD.init(gui, cancelAction)
Menus.init(gui)
BuildMode.init(gui, HUD.notify)

Remotes.Notify.OnClientEvent:Connect(function(text, kind)
	HUD.notify(text, kind)
end)

--------------------------------------------------------------------------
-- Side buttons
--------------------------------------------------------------------------
local buttons = Theme.create("Frame", {
	Name = "Buttons",
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(90, 5 * 74),
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Parent = gui,
}, {
	Theme.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function sideButton(order: number, icon: string, text: string, onClick: () -> ())
	local button = Theme.button({
		Text = "",
		LayoutOrder = order,
		Size = UDim2.fromOffset(90, 66),
		BackgroundColor3 = Theme.bg,
		BackgroundTransparency = Theme.panelTransparency,
		Parent = buttons,
	})
	Theme.stroke().Parent = button
	Theme.label({ Text = icon, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 38), Parent = button })
	Theme.label({
		Text = text,
		Font = Theme.fontBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 40),
		Parent = button,
	})
	button.Activated:Connect(onClick)
end

sideButton(1, "🏠", "Bahay", function()
	Remotes.GoHome:FireServer()
end)
sideButton(2, "🔨", "Gawa (B)", BuildMode.toggle)
sideButton(3, "📊", "Kasanayan", function()
	Menus.toggle("skills")
end)
sideButton(4, "❤️", "Relasyon", function()
	Menus.toggle("relationships")
end)
sideButton(5, "🪪", "Ako", function()
	Menus.toggle("identity")
end)

-- First time here? Spin the wheel of fate.
if not player:GetAttribute("IdentitySeen") then
	SpinWheel.show(gui, function()
		Remotes.IdentitySeen:FireServer()
	end)
end

--------------------------------------------------------------------------
-- Moving or jumping cancels the current action (works on keyboard, gamepad and touch)
--------------------------------------------------------------------------
local lastCancel = 0
local function requestCancel()
	if os.clock() - lastCancel > 0.5 then
		lastCancel = os.clock()
		cancelAction()
	end
end

UserInputService.JumpRequest:Connect(function()
	-- ignore the first moments of an action so a held key doesn't instantly cancel it
	if (player:GetAttribute("ActionProgress") or 0) > 0.02 then
		requestCancel()
	end
end)

RunService.RenderStepped:Connect(function()
	if not player:GetAttribute("CurrentAction") then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 and (player:GetAttribute("ActionProgress") or 0) > 0.02 then
		requestCancel()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
		Menus.closeAll()
	end
end)
