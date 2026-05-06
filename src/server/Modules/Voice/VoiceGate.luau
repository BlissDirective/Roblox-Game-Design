--!strict
--[[
	Outpost-7 — spatial voice gate.

	Phase E4. Brainstorm §2.6: voice chat is enabled during raids only.
	The actual enable lives at the place level — `raid.project.json`
	sets `VoiceChatService.EnableDefaultVoice = true`; the main
	`default.project.json` inherits the platform default (off). This
	matches ADR-009's two-PlaceId split: voice opts in per-place via
	build configuration, not runtime toggle.

	Server-side VoiceGate is a defensive verifier + state-push:
	  - On boot in the raid place, confirms `VoiceChatService.EnableDefaultVoice`
	    is the value we expect; logs once per state flip.
	  - On player join, pushes `VoiceState` so the client HUD can
	    render a mic indicator. Per-account voice availability is read
	    via the yielding `VoiceChatService:IsVoiceEnabledForUserIdAsync`
	    so we can surface "voice unavailable for this user" instead of
	    misleading the client into showing "voice active" when their
	    account can't actually transmit.
	  - On main place, pushes `VoiceState { inRaidPlace = false }` so
	    the client clears any stale indicator.

	Trust boundary: the client never sends a voice Remote. The mic
	hardware is controlled by Roblox's native voice UI; our state push
	is render-only.

	Phase H prerequisite: enable voice chat at the universe level in
	the Roblox Creator Dashboard (this can NOT be Rojo-configured).
	Until that's flipped, V1 dev sees `EnableDefaultVoice = true` set
	on the raid place but Roblox refuses to actually open mics —
	`IsVoiceEnabledForUserIdAsync` returns false universe-wide.

	Public API:
	  Init  — wires PlayerAdded + verify loop; safe to call in either
	          place (branches on game.PrivateServerId)
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VoiceChatService = game:GetService("VoiceChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local VoiceGate = {}

export type State = {
	enabled: boolean, -- place-level VoiceChatService.EnableDefaultVoice
	userVoiceAvailable: boolean, -- this player's account has voice permission
	inRaidPlace: boolean, -- whether the indicator should render
}

local IS_RAID_PLACE = false -- determined in Init

local function isPlaceVoiceEnabled(): boolean
	-- EnableDefaultVoice is the property our place files configure.
	-- Wrapped in pcall because the property name has changed across
	-- Roblox releases — defensive read avoids hard-failing if a
	-- future rename ships before we update the project files.
	local ok, value = pcall(function()
		return (VoiceChatService :: any).EnableDefaultVoice
	end)
	if ok and typeof(value) == "boolean" then
		return value
	end
	return false
end

local function isUserVoiceAvailable(player: Player): boolean
	-- Yielding API; pcall-wrapped. Returns false on any error so the
	-- HUD shows a muted indicator rather than a misleading active one.
	local ok, value = pcall(function()
		return VoiceChatService:IsVoiceEnabledForUserIdAsync(player.UserId)
	end)
	if not ok then
		return false
	end
	return value == true
end

local function buildState(player: Player): State
	if not IS_RAID_PLACE then
		return { enabled = false, userVoiceAvailable = false, inRaidPlace = false }
	end
	local placeEnabled = isPlaceVoiceEnabled()
	local userAvailable = if placeEnabled then isUserVoiceAvailable(player) else false
	return {
		enabled = placeEnabled,
		userVoiceAvailable = userAvailable,
		inRaidPlace = true,
	}
end

local function pushStateToPlayer(player: Player)
	local state = buildState(player)
	local remote = Remotes.VoiceState :: RemoteEvent
	remote:FireClient(player, state)
end

-- Optional: 2026-Feb diagnostic. Logs the chat group ids the player is
-- in at the moment of raid round start. Useful for "why doesn't my
-- friend hear me" troubleshooting once raids are live.
local function logChatGroupDiagnostic(player: Player)
	if not Constants.VOICE.UseChatGroupDiagnostic then
		return
	end
	local ok, groups = pcall(function()
		return VoiceChatService:GetChatGroupsAsync({ player })
	end)
	if not ok then
		warn(string.format("[VoiceGate] GetChatGroupsAsync failed for %s: %s", player.Name, tostring(groups)))
		return
	end
	if typeof(groups) == "table" then
		print(string.format("[VoiceGate] %s chat groups: %s", player.Name, tostring(#groups)))
	end
end

local lastObservedEnabled: boolean? = nil
local function verifyLoop()
	while true do
		task.wait(Constants.VOICE.VerifyIntervalSeconds)
		local current = isPlaceVoiceEnabled()
		if current ~= lastObservedEnabled then
			lastObservedEnabled = current
			print(
				string.format(
					"[VoiceGate] EnableDefaultVoice = %s (raidPlace=%s)",
					tostring(current),
					tostring(IS_RAID_PLACE)
				)
			)
		end
	end
end

function VoiceGate.Init()
	IS_RAID_PLACE = game.PrivateServerId ~= ""
	-- Initial log so the boot output records the gate's view of voice.
	lastObservedEnabled = isPlaceVoiceEnabled()
	print(
		string.format(
			"[VoiceGate] Init: raidPlace=%s, EnableDefaultVoice=%s",
			tostring(IS_RAID_PLACE),
			tostring(lastObservedEnabled)
		)
	)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			-- Brief delay: in the raid place, the player has just teleported
			-- in and `IsVoiceEnabledForUserIdAsync` may still be priming.
			task.wait(0.5)
			if player:IsDescendantOf(Players) then
				pushStateToPlayer(player)
				if IS_RAID_PLACE then
					logChatGroupDiagnostic(player)
				end
			end
		end)
	end)
	-- Existing players (Studio reload during dev).
	for _, player in Players:GetPlayers() do
		task.spawn(pushStateToPlayer, player)
	end

	task.spawn(verifyLoop)
end

return VoiceGate
