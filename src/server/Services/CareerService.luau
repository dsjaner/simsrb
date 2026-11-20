--[[
	CareerService — the PESO (Public Employment Service Office) job board.
	Players pick one of the 10 professions; education gates some of them.
	A profession's job can only be done in the cities listed for it, so where
	you live vs. where you work becomes a real decision (commute or move).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)

local CareerService = {}

local lastChange: { [Player]: number } = {}
local CHANGE_COOLDOWN = 30

function CareerService.init()
	Remotes.ChooseProfession.OnServerEvent:Connect(function(player, professionId)
		local prof = type(professionId) == "string" and Config.Professions[professionId]
		if not prof then
			return
		end
		if player:GetAttribute("Profession") == professionId then
			Remotes.notify(player, "Ito na ang trabaho mo ngayon.", "info")
			return
		end
		if not Config.meetsEducation(player:GetAttribute("Education"), prof.education) then
			local need = Config.Education[prof.education]
			Remotes.notify(player, "🔒 Kailangan mo ng " .. (need and need.label or prof.education) .. " para maging " .. prof.label .. ".", "warn")
			return
		end
		local now = os.clock()
		if lastChange[player] and now - lastChange[player] < CHANGE_COOLDOWN then
			Remotes.notify(player, "Kakapalit mo lang ng trabaho. Sandali lang.", "warn")
			return
		end
		lastChange[player] = now
		player:SetAttribute("Profession", professionId)

		local places = {}
		for _, cityId in prof.cities do
			table.insert(places, Config.city(cityId).name)
		end
		Remotes.notify(player, string.format("%s Natanggap ka bilang %s! Pwede kang magtrabaho sa: %s.",
			prof.icon, prof.label, table.concat(places, ", ")), "good")
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastChange[player] = nil
	end)
end

return CareerService
