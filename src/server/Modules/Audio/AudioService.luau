--!strict
--[[
	Outpost-7 — server-side audio dispatcher.

	Phase G4. Thin facade over the AudioCue Remote: gameplay code calls
	`AudioService.PlayAll(cueId, opts)` / `.PlayToPlayer(player, cueId, opts)`
	/ `.PlayAtPosition(cueId, position, opts)` and the service fans the
	cue out to the relevant clients. AudioController on each client
	does the actual Sound playback.

	Threat model: cosmetic. Cues are advisory — a malicious client that
	listens to AudioCue gains no advantage (the visible turret-fire
	beam + projectile path is the actual gameplay signal). Server is
	NOT authoritative for what plays on a given client; it's authoritative
	for *what got broadcast*. AudioController treats missing cueIds as
	no-ops, so a future Remote-spoofing exploiter can play any audio
	already in the registry — same blast radius as Roblox's default
	`SoundService:PlayLocalSound`.

	V1 scope: no per-server mix state, no occlusion, no ducking. Music
	state is broadcast as cue-with-loopId; the client is responsible for
	crossfading when it gets a new loopId for an existing category.

	Public API:
	  Init                                — no-op for V1 (no listeners
	                                        on the server side; surface
	                                        reserved for future hooks)
	  PlayAll(cueId, opts?)               — broadcast to every client
	                                        on this server
	  PlayToPlayer(player, cueId, opts?)  — single-target
	  PlayAtPosition(cueId, position, opts?) — 3D positional; broadcast
	                                          to all (clients within
	                                          rollOff range hear it)
	  PlayToPlayers(players, cueId, opts?) — multi-target (free for clan
	                                         events, etc.)
	  SwitchMusic(loopId, cueId, opts?)    — replace the current music
	                                         loop on every client (uses
	                                         the Constants.AUDIO.MusicCrossfadeSeconds)
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local AudioRegistry = require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("AudioRegistry"))

local AudioService = {}

export type Options = {
	position: Vector3?, -- spatial origin (3D positional only)
	volume: number?, -- per-call gain multiplier (cue.volume × call.volume × category × master)
	pitch: number?, -- PlaybackSpeed override
	targetPart: BasePart?, -- attach Sound to this part for follow-through audio (e.g., a moving alien)
	attachTo: Instance?, -- alternative: any parent (Workspace.Camera, character HRP, etc.)
	loopId: string?, -- music track identifier; used by AudioController to crossfade
}

local function ensureCue(cueId: string): AudioRegistry.AudioCue?
	local cue = AudioRegistry.Get(cueId)
	if not cue then
		warn(string.format("[AudioService] Unknown cueId '%s'", cueId))
		return nil
	end
	return cue
end

local function serializeOpts(opts: Options?): { [string]: any }
	-- Remotes can't carry function values; flatten to a plain dict.
	-- Returns an empty table when opts is nil so the client always
	-- sees a table arg (no nil-check explosion in AudioController).
	if not opts then
		return {}
	end
	local out: { [string]: any } = {}
	if opts.position then
		out.position = opts.position
	end
	if opts.volume then
		out.volume = opts.volume
	end
	if opts.pitch then
		out.pitch = opts.pitch
	end
	if opts.targetPart then
		out.targetPart = opts.targetPart
	end
	if opts.attachTo then
		out.attachTo = opts.attachTo
	end
	if opts.loopId then
		out.loopId = opts.loopId
	end
	return out
end

function AudioService.PlayAll(cueId: string, opts: Options?)
	if not ensureCue(cueId) then
		return
	end
	Remotes.AudioCue:FireAllClients(cueId, serializeOpts(opts))
end

function AudioService.PlayToPlayer(player: Player, cueId: string, opts: Options?)
	if not ensureCue(cueId) then
		return
	end
	-- Defensive: avoid firing to a player who's mid-disconnect.
	if player.Parent ~= Players then
		return
	end
	Remotes.AudioCue:FireClient(player, cueId, serializeOpts(opts))
end

function AudioService.PlayToPlayers(players: { Player }, cueId: string, opts: Options?)
	if not ensureCue(cueId) then
		return
	end
	local payload = serializeOpts(opts)
	for _, player in players do
		if player.Parent == Players then
			Remotes.AudioCue:FireClient(player, cueId, payload)
		end
	end
end

function AudioService.PlayAtPosition(cueId: string, position: Vector3, opts: Options?)
	if not ensureCue(cueId) then
		return
	end
	-- Merge position into opts; broadcast to all clients (3D attenuation
	-- handles the audibility check). Mobile streaming radius is the
	-- ceiling — clients far away simply hear silence at the rolloff
	-- distance.
	local payload = serializeOpts(opts)
	payload.position = position
	Remotes.AudioCue:FireAllClients(cueId, payload)
end

function AudioService.SwitchMusic(loopId: string, cueId: string, opts: Options?)
	-- Music switching uses a stable loopId so the client crossfades
	-- between the OLD music sound (whatever loopId was active) and the
	-- NEW (this loopId). Server doesn't track music state; client owns
	-- the active-track ledger and reacts to the loopId change.
	if not ensureCue(cueId) then
		return
	end
	local payload = serializeOpts(opts)
	payload.loopId = loopId
	Remotes.AudioCue:FireAllClients(cueId, payload)
end

function AudioService.Init()
	-- No-op surface for V1. Reserved for future per-server hooks
	-- (e.g., resubscribing to WaveDirector start/end events for music
	-- transitions — currently wired directly from those services).
end

return AudioService
