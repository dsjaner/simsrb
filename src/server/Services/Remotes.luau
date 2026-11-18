--[[
	Remotes — creates every RemoteEvent / RemoteFunction the game uses.
	The client waits for ReplicatedStorage.Remotes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local EVENTS = {
	"OpenMenu", -- server → client (stationModel, stationId)
	"RequestAction", -- client → server (stationModel, actionId)
	"CancelAction", -- client → server ()
	"Notify", -- server → client (text, kind)
	"GoHome", -- client → server ()
}
local FUNCTIONS = {
	"PlaceFurniture", -- (id, x, y, z, rotation) → ok, message
	"SellFurniture", -- (model) → ok, message
}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

for _, name in EVENTS do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	Remotes[name] = remote
end
for _, name in FUNCTIONS do
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = folder
	Remotes[name] = remote
end

folder.Parent = ReplicatedStorage

-- kind: "info" | "good" | "warn" | "bad"
function Remotes.notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

function Remotes.notifyAll(text: string, kind: string?)
	Remotes.Notify:FireAllClients(text, kind or "info")
end

return Remotes
