--[[
	BuildMode — "Gawa" mode for buying and arranging furniture on your lot.

	  Click a catalog card → a ghost preview follows your mouse (green = OK, red = not allowed)
	  Left-click / tap : ilagay (place)      R : ikot (rotate 90°)
	  X (while hovering your furniture) : ibenta (sell)
	  Q : bitawan (deselect)                  B : lumabas (exit)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(ReplicatedStorage.Shared.Models)
local Util = require(ReplicatedStorage.Shared.Util)
local Theme = require(script.Parent.UI.Theme)

local create = Theme.create
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local BuildMode = {}

local notify: (string, string?) -> () = function() end
local active = false
local selectedId: string? = nil
local ghost: Model? = nil
local ghostHighlight: Highlight? = nil
local hoverHighlight: Highlight
local hovered: Model? = nil
local rotation = 0
local pending: { x: number, y: number, z: number, valid: boolean }? = nil
local busy = false

local catalog: Frame
local hint: TextLabel
local renderConn: RBXScriptConnection? = nil

local GREEN = Color3.fromRGB(80, 230, 120)
local RED = Color3.fromRGB(240, 70, 70)

local function myLot(): Model?
	local lots = workspace:FindFirstChild("Lots")
	if not lots then
		return nil
	end
	for _, lot in lots:GetChildren() do
		if lot:GetAttribute("OwnerUserId") == player.UserId then
			return lot
		end
	end
	return nil
end

local function clearGhost()
	if ghost then
		ghost:Destroy()
	end
	ghost, ghostHighlight, selectedId, pending = nil, nil, nil, nil
end

local function makeGhost(id: string)
	clearGhost()
	local model = Models.build(id)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Transparency < 1 then
				d.Transparency = math.max(d.Transparency, 0.35)
			end
		elseif d:IsA("Light") then
			d.Enabled = false
		end
	end
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.65
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	model.Parent = workspace
	ghost, ghostHighlight, selectedId = model, highlight, id
end

local function furnitureAncestor(inst: Instance?): Model?
	while inst and inst ~= workspace do
		if inst:IsA("Model") and inst:GetAttribute("FurnitureId") then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

local function mouseRay(): RaycastResult?
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	if ghost then
		table.insert(ignore, ghost)
	end
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(ray.Origin, ray.Direction * 600, params)
end

local function update()
	local lot = myLot()
	local result = mouseRay()

	-- hover for selling
	local over = result and furnitureAncestor(result.Instance)
	if over and over:GetAttribute("OwnerUserId") ~= player.UserId then
		over = nil
	end
	hovered = if selectedId then nil else over
	hoverHighlight.Adornee = hovered
	hoverHighlight.Enabled = hovered ~= nil

	if not ghost or not lot or not result then
		pending = nil
		return
	end
	local origin = (lot:FindFirstChild("Origin") :: BasePart).CFrame
	local rel = origin:PointToObjectSpace(result.Position)
	local x = math.floor(rel.X * 2 + 0.5) / 2
	local z = math.floor(rel.Z * 2 + 0.5) / 2
	local y = rel.Y
	local half = Config.LotHalfSize
	local item = Config.FurnitureById[selectedId :: string]
	local inBounds = math.abs(x) <= half and math.abs(z) <= half and y >= -0.5 and y <= Config.MaxBuildHeight
	local affordable = (player:GetAttribute("Pesos") or 0) >= item.price
	local valid = inBounds and affordable
	ghost:PivotTo(origin * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotation), 0))
	if ghostHighlight then
		ghostHighlight.FillColor = if valid then GREEN else RED
		ghostHighlight.OutlineColor = if valid then GREEN else RED
	end
	pending = { x = x, y = y, z = z, valid = valid }
end

local function tryPlace()
	if busy or not selectedId or not pending then
		return
	end
	if not pending.valid then
		local item = Config.FurnitureById[selectedId]
		if (player:GetAttribute("Pesos") or 0) < item.price then
			notify("💸 Kulang ang pera mo para sa " .. item.name .. ".", "warn")
		else
			notify("Sa loob lang ng lote mo pwedeng maglagay.", "warn")
		end
		return
	end
	busy = true
	local id, p, r = selectedId, pending, rotation
	task.spawn(function()
		local ok, msg = Remotes.PlaceFurniture:InvokeServer(id, p.x, p.y, p.z, r)
		notify(msg, if ok then "good" else "warn")
		busy = false
	end)
end

local function trySell()
	if busy or not hovered then
		return
	end
	busy = true
	local target = hovered
	task.spawn(function()
		local ok, msg = Remotes.SellFurniture:InvokeServer(target)
		notify(msg, if ok then "good" else "warn")
		busy = false
	end)
end

local function buildCatalog(gui: ScreenGui)
	catalog = Theme.panel({
		Name = "BuildCatalog",
		Size = UDim2.new(0, 760, 0, 168),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Visible = false,
		Parent = gui,
	})
	Theme.label({
		Text = "🔨 Gawa — Mga Gamit sa Bahay",
		Font = Theme.fontTitle,
		TextSize = 18,
		TextColor3 = Theme.yellow,
		Size = UDim2.new(1, -140, 0, 24),
		Position = UDim2.fromOffset(12, 8),
		Parent = catalog,
	})
	hint = Theme.label({
		Text = "Klik: Ilagay · R: Ikot · X: Ibenta · Q: Bitawan · B: Lumabas",
		TextSize = 13,
		TextColor3 = Theme.textDim,
		Size = UDim2.new(1, -140, 0, 16),
		Position = UDim2.fromOffset(12, 32),
		Parent = catalog,
	})
	local exit = Theme.button({
		Text = "Lumabas",
		BackgroundColor3 = Theme.red,
		Size = UDim2.fromOffset(110, 34),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Parent = catalog,
	})
	exit.Activated:Connect(function()
		BuildMode.setActive(false)
	end)

	local scroller = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -24, 0, 108),
		Position = UDim2.fromOffset(12, 54),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		Parent = catalog,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, item in Config.Furniture do
		local card = Theme.button({
			Text = "",
			LayoutOrder = i,
			Size = UDim2.fromOffset(112, 96),
			Parent = scroller,
		})
		Theme.label({ Text = item.icon, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 40), Parent = card })
		Theme.label({
			Text = item.name,
			Font = Theme.fontBold,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -8, 0, 30),
			Position = UDim2.fromOffset(4, 40),
			Parent = card,
		})
		Theme.label({
			Text = Util.formatPesos(item.price),
			TextSize = 13,
			TextColor3 = Color3.fromRGB(140, 230, 140),
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 72),
			Parent = card,
		})
		card.Activated:Connect(function()
			rotation = 0
			makeGhost(item.id)
			hint.Text = item.desc .. "  ·  Klik para ilagay, R para iikot"
		end)
	end
end

function BuildMode.setActive(on: boolean)
	if on == active then
		return
	end
	if on and not myLot() then
		notify("Wala kang sariling lote para mag-ayos.", "warn")
		return
	end
	active = on
	catalog.Visible = on
	if on then
		renderConn = RunService.RenderStepped:Connect(update)
		notify("🔨 Gawa mode: pumili ng gamit sa ibaba.", "info")
	else
		if renderConn then
			renderConn:Disconnect()
			renderConn = nil
		end
		clearGhost()
		hovered = nil
		hoverHighlight.Adornee = nil
		hoverHighlight.Enabled = false
	end
end

function BuildMode.toggle()
	BuildMode.setActive(not active)
end

function BuildMode.isActive(): boolean
	return active
end

function BuildMode.init(gui: ScreenGui, notifyFn: (string, string?) -> ())
	notify = notifyFn
	buildCatalog(gui)

	hoverHighlight = Instance.new("Highlight")
	hoverHighlight.Name = "SellHover"
	hoverHighlight.FillColor = RED
	hoverHighlight.FillTransparency = 0.7
	hoverHighlight.OutlineColor = RED
	hoverHighlight.Enabled = false
	hoverHighlight.Parent = workspace

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			BuildMode.toggle()
			return
		end
		if not active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			tryPlace()
		elseif input.KeyCode == Enum.KeyCode.R then
			rotation = (rotation + 90) % 360
		elseif input.KeyCode == Enum.KeyCode.X then
			trySell()
		elseif input.KeyCode == Enum.KeyCode.Q then
			clearGhost()
		end
	end)
end

return BuildMode
