--[[
	Overhead — the floating parol (star) above each player that shows their mood,
	plus the emoji thought bubble that shows what they're doing.
]]

local Overhead = {}

function Overhead.attach(character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head then
		return
	end
	local old = head:FindFirstChild("Overhead")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Overhead"
	gui.Size = UDim2.new(4, 0, 2, 0)
	gui.StudsOffset = Vector3.new(0, 3.1, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0

	local star = Instance.new("TextLabel")
	star.Name = "Parol"
	star.Size = UDim2.fromScale(0.5, 1)
	star.Position = UDim2.fromScale(0.25, 0)
	star.BackgroundTransparency = 1
	star.Text = "★"
	star.TextScaled = true
	star.Font = Enum.Font.GothamBold
	star.TextColor3 = Color3.fromRGB(80, 220, 120)
	star.TextStrokeTransparency = 0.4
	star.Parent = gui

	local bubble = Instance.new("TextLabel")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.fromScale(0.42, 0.84)
	bubble.Position = UDim2.fromScale(0.78, -0.25)
	bubble.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bubble.BackgroundTransparency = 0.05
	bubble.Text = ""
	bubble.TextScaled = true
	bubble.Visible = false
	bubble.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bubble

	-- Age is the only identity detail other players can see.
	local age = Instance.new("TextLabel")
	age.Name = "Age"
	age.Size = UDim2.fromScale(1.4, 0.45)
	age.Position = UDim2.fromScale(-0.2, 1.0)
	age.BackgroundTransparency = 1
	age.Text = ""
	age.TextScaled = true
	age.Font = Enum.Font.GothamBold
	age.TextColor3 = Color3.fromRGB(255, 255, 255)
	age.TextStrokeTransparency = 0.3
	age.Parent = gui

	gui.Parent = head
end

function Overhead.setAge(player: Player, years: number?)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("Overhead")
	local label = gui and gui:FindFirstChild("Age") :: TextLabel?
	if label then
		label.Text = if years then string.format("%d taong gulang", years) else ""
	end
end

local function getGui(player: Player): BillboardGui?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	return head and head:FindFirstChild("Overhead") :: BillboardGui?
end

function Overhead.setMoodColor(player: Player, color: Color3)
	local gui = getGui(player)
	if gui then
		(gui:FindFirstChild("Parol") :: TextLabel).TextColor3 = color
	end
end

function Overhead.setBubble(player: Player, emoji: string?)
	local gui = getGui(player)
	if gui then
		local bubble = gui:FindFirstChild("Bubble") :: TextLabel
		bubble.Text = emoji or ""
		bubble.Visible = emoji ~= nil
	end
end

return Overhead
