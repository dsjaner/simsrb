--[[
	NPCService — the neighbours (mga kapitbahay) who wander the barangay.
	Talk to them to raise Pakikisama and build a relationship.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local StationService = require(script.Parent.StationService)

local NPCService = {}

local C = Color3.fromRGB

-- Roblox's default R15 animation ids (the same ones the stock Animate script uses).
local WALK_ANIM = "rbxassetid://507777826"
local IDLE_ANIM = "rbxassetid://507766388"

local function weldTo(head: BasePart, part: BasePart, offset: CFrame)
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.CFrame = head.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
	part.Parent = head.Parent
end

local function addAccessory(model: Model, kind: string?)
	local head = model:FindFirstChild("Head") :: BasePart?
	local torso = (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")) :: BasePart?
	if not head then
		return
	end
	if kind == "Salakot" then
		-- traditional wide farmer's hat
		weldTo(head, Util.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 3.2, 3.2), Color = C(205, 170, 100), Material = Enum.Material.Fabric }),
			CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, math.pi / 2))
		weldTo(head, Util.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 1.6, 1.6), Color = C(185, 150, 85), Material = Enum.Material.Fabric }),
			CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.pi / 2))
	elseif kind == "Bun" then
		weldTo(head, Util.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), Color = C(200, 200, 205), Material = Enum.Material.Fabric }),
			CFrame.new(0, 0.2, 0.15))
		weldTo(head, Util.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), Color = C(200, 200, 205), Material = Enum.Material.Fabric }),
			CFrame.new(0, 0.5, 0.7))
	elseif kind == "Towel" and torso then
		weldTo(torso, Util.part({ Size = Vector3.new(0.6, 0.15, 1.4), Color = C(245, 245, 245), Material = Enum.Material.Fabric }),
			CFrame.new(0.55, 1.05, 0))
		weldTo(head, Util.part({ Size = Vector3.new(1.3, 0.35, 1.3), Color = C(40, 80, 160), Material = Enum.Material.Fabric }),
			CFrame.new(0, 0.65, 0))
	elseif kind == "Apron" and torso then
		weldTo(torso, Util.part({ Size = Vector3.new(1.6, 1.8, 0.1), Color = C(255, 240, 200), Material = Enum.Material.Fabric }),
			CFrame.new(0, -0.6, -0.55))
	end
end

local function buildRig(def): Model?
	local ok, result = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = def.skin
		desc.LeftArmColor = def.skin
		desc.RightArmColor = def.skin
		desc.TorsoColor = def.shirt
		desc.LeftLegColor = def.pants
		desc.RightLegColor = def.pants
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if ok and result then
		return result
	end
	warn("[Bahay Buhay] Could not build NPC rig for " .. def.name .. ": " .. tostring(result))
	return nil
end

local function speechBubble(model: Model)
	local head = model:FindFirstChild("Head")
	if not head then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Speech"
	gui.Size = UDim2.new(8, 0, 1.6, 0)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 60
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.TextColor3 = C(40, 30, 30)
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.Parent = label
	gui.Parent = head
	return gui
end

local function say(gui: BillboardGui?, text: string)
	if not gui then
		return
	end
	(gui:FindFirstChildOfClass("TextLabel") :: TextLabel).Text = text
	gui.Enabled = true
	task.delay(4, function()
		if gui.Parent then
			gui.Enabled = false
		end
	end)
end

local function playAnimations(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local ok = pcall(function()
		local walk = Instance.new("Animation")
		walk.AnimationId = WALK_ANIM
		local idle = Instance.new("Animation")
		idle.AnimationId = IDLE_ANIM
		local walkTrack = animator:LoadAnimation(walk)
		local idleTrack = animator:LoadAnimation(idle)
		idleTrack.Looped = true
		walkTrack.Looped = true
		idleTrack:Play()
		humanoid.Running:Connect(function(speed)
			if speed > 0.5 then
				if not walkTrack.IsPlaying then
					walkTrack:Play(0.2)
				end
			elseif walkTrack.IsPlaying then
				walkTrack:Stop(0.2)
			end
		end)
	end)
	if not ok then
		warn("[Bahay Buhay] NPC animations unavailable")
	end
end

local function wander(model: Model, def, humanoid: Humanoid, root: BasePart, speech)
	local home = def.home
	local radius = 14
	local talkingTo = nil
	while model.Parent do
		local userId = model:GetAttribute("InUseBy")
		if userId then
			if talkingTo ~= userId then
				talkingTo = userId
				say(speech, def.lines[math.random(1, #def.lines)])
			end
			humanoid:MoveTo(root.Position)
			local player = Players:GetPlayerByUserId(userId)
			local otherRoot = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot then
				local pos = root.Position
				local target = Vector3.new(otherRoot.Position.X, pos.Y, otherRoot.Position.Z)
				if (target - pos).Magnitude > 0.5 then
					root.CFrame = CFrame.lookAt(pos, target)
				end
			end
			task.wait(0.5)
		else
			talkingTo = nil
			local angle = math.random() * math.pi * 2
			local dist = math.random() * radius
			humanoid:MoveTo(home + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist))
			local reached = false
			local conn = humanoid.MoveToFinished:Connect(function()
				reached = true
			end)
			local t0 = os.clock()
			while not reached and os.clock() - t0 < 8 and not model:GetAttribute("InUseBy") do
				task.wait(0.2)
			end
			conn:Disconnect()
			if math.random() < 0.25 and not model:GetAttribute("InUseBy") then
				say(speech, def.lines[math.random(1, #def.lines)])
			end
			local idleUntil = os.clock() + math.random(2, 6)
			while os.clock() < idleUntil and not model:GetAttribute("InUseBy") do
				task.wait(0.2)
			end
		end
	end
end

function NPCService.init()
	local folder = Instance.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = workspace

	for _, def in Config.NPCs do
		task.spawn(function()
			local model = buildRig(def)
			if not model then
				return
			end
			model.Name = def.name
			local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
			humanoid.DisplayName = def.name
			humanoid.WalkSpeed = def.walkSpeed or 8
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
			local animate = model:FindFirstChild("Animate")
			if animate then
				animate:Destroy()
			end
			addAccessory(model, def.accessory)

			model:SetAttribute("StationId", def.station)
			model:SetAttribute("NpcId", def.id)
			model:SetAttribute("DisplayName", def.name)
			model:PivotTo(CFrame.new(def.home + Vector3.new(0, 3, 0)))
			model.Parent = folder
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
			playAnimations(humanoid)
			local speech = speechBubble(model)
			StationService.make(model)
			wander(model, def, humanoid, root, speech)
		end)
	end
end

return NPCService
