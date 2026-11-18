--[[
	TimeService — day/night cycle. One in-game day lasts Config.DayLengthMinutes.
	Switches on lamps and parols at night and fires onMorning callbacks at 6 AM.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local TimeService = {}

local morningCallbacks = {}
local nightOn: boolean? = nil

function TimeService.onMorning(callback: (day: number) -> ())
	table.insert(morningCallbacks, callback)
end

local function setNightLights(on: boolean)
	if nightOn == on then
		return
	end
	nightOn = on
	for _, part in CollectionService:GetTagged("NightLight") do
		for _, child in part:GetChildren() do
			if child:IsA("Light") then
				child.Enabled = on
			end
		end
	end
end

function TimeService.init()
	Lighting.ClockTime = Config.StartClockTime
	ReplicatedStorage:SetAttribute("Day", 1)

	local hoursPerSecond = 24 / (Config.DayLengthMinutes * 60)
	local day = 1

	-- newly placed parols should match the current state
	CollectionService:GetInstanceAddedSignal("NightLight"):Connect(function(part)
		for _, child in part:GetChildren() do
			if child:IsA("Light") then
				child.Enabled = nightOn == true
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local previous = Lighting.ClockTime
		local now = previous + hoursPerSecond * dt
		if now >= 24 then
			now -= 24
		end
		Lighting.ClockTime = now

		if previous < Config.MorningHour and now >= Config.MorningHour then
			day += 1
			ReplicatedStorage:SetAttribute("Day", day)
			for _, callback in morningCallbacks do
				task.spawn(callback, day)
			end
		end
		setNightLights(now >= 18 or now < 6)
	end)
end

return TimeService
