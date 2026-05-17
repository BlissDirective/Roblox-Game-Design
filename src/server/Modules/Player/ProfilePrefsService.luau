--!strict
--[[
	Outpost-7 — UI preference push handler.

	Phase G5. Owns the `UiPrefsUpdate` Remote. Client sends a payload
	like `{ dominantThumb = "left" }`; server validates the enum,
	rate-checks the call, writes to `profile.uiPrefs.dominantThumb`.
	No response — this is fire-and-forget. The persisted value is
	loaded by the client on the next session via DataManager and
	applied to the action bar layout.

	Validation rules:
	- payload must be a table
	- dominantThumb (optional): must be "left" or "right"
	- unknown fields are silently dropped (no echo back, no error —
	  client just doesn't see them stick)

	V1.5+ may extend this Remote with more uiPrefs fields
	(colorblindMode, hudScale, etc.). Each new field needs its own
	validator block in the switch below.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local DataManager = require(script.Parent.DataManager)
local AntiExploit = require(script.Parent.Parent.Security.AntiExploit)

local ProfilePrefsService = {}

local VALID_THUMB: { [string]: boolean } = {
	left = true,
	right = true,
}

local function handleUpdate(player: Player, payload: any)
	if not AntiExploit.RateCheck(player, "UiPrefsUpdate") then
		return
	end
	if type(payload) ~= "table" then
		return
	end
	local data = DataManager.GetData(player)
	if not data then
		return
	end
	if not data.uiPrefs then
		data.uiPrefs = { dominantThumb = nil }
	end
	local thumb = payload.dominantThumb
	if thumb ~= nil then
		if type(thumb) == "string" and VALID_THUMB[thumb] then
			data.uiPrefs.dominantThumb = thumb
		end
		-- Invalid values silently dropped per docstring.
	end
end

local function pushStateToClient(player: Player)
	local data = DataManager.WaitForData(player)
	if not data then
		return
	end
	if not data.uiPrefs then
		data.uiPrefs = { dominantThumb = nil }
	end
	local remote = Remotes.UiPrefsState :: RemoteEvent
	remote:FireClient(player, { dominantThumb = data.uiPrefs.dominantThumb })
end

function ProfilePrefsService.Init()
	local updateRemote = Remotes.UiPrefsUpdate :: RemoteEvent
	updateRemote.OnServerEvent:Connect(handleUpdate)

	-- Push state on PlayerAdded after profile load. Catches already-
	-- connected players too (script reload during dev).
	Players.PlayerAdded:Connect(function(player)
		task.spawn(pushStateToClient, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(pushStateToClient, player)
	end
end

return ProfilePrefsService
