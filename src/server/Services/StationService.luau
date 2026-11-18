--[[
	StationService — turns every Model tagged "Station" into something interactive.
	A ProximityPrompt is added; triggering it either starts the single action or
	opens a choice menu on the client (e.g. the sari-sari store's list of snacks).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)
local ActionService = require(script.Parent.ActionService)

local StationService = {}

local TAG = "Station"
local MAX_USE_DISTANCE = 16

local function promptParent(model: Model): BasePart?
	local explicit = model:FindFirstChild("PromptPart", true)
	if explicit and explicit:IsA("BasePart") then
		return explicit
	end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function register(model: Instance)
	if not model:IsA("Model") or model:GetAttribute("PromptReady") then
		return
	end
	local stationId = model:GetAttribute("StationId")
	local cfg = stationId and Config.Stations[stationId]
	if not cfg or #cfg.actions == 0 then
		return
	end
	local parent = promptParent(model)
	if not parent then
		return
	end
	model:SetAttribute("PromptReady", true)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StationPrompt"
	prompt.ActionText = cfg.prompt or "Gamitin"
	prompt.ObjectText = model:GetAttribute("DisplayName") or cfg.title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = parent

	prompt.Triggered:Connect(function(player)
		if #cfg.actions == 1 then
			ActionService.start(player, model, cfg.actions[1])
		else
			Remotes.OpenMenu:FireClient(player, model, stationId)
		end
	end)
end

local function distanceOk(player: Player, model: Model): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local anchor = promptParent(model)
	if not root or not anchor then
		return false
	end
	return (root.Position - anchor.Position).Magnitude <= MAX_USE_DISTANCE
end

function StationService.init()
	for _, model in CollectionService:GetTagged(TAG) do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(register)

	Remotes.RequestAction.OnServerEvent:Connect(function(player, model, actionId)
		if typeof(model) ~= "Instance" or not model:IsA("Model") or type(actionId) ~= "string" then
			return
		end
		if not CollectionService:HasTag(model, TAG) then
			return
		end
		local cfg = Config.Stations[model:GetAttribute("StationId")]
		if not cfg or not table.find(cfg.actions, actionId) then
			return
		end
		if not distanceOk(player, model) then
			Remotes.notify(player, "Lumapit ka muna.", "warn")
			return
		end
		ActionService.start(player, model, actionId)
	end)
end

-- Convenience for other services: tag a model so it becomes interactive.
function StationService.make(model: Model)
	CollectionService:AddTag(model, TAG)
end

return StationService
