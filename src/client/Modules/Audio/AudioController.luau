--!strict
--[[
	Outpost-7 — client-side audio playback.

	Phase G4. Listens to the AudioCue Remote and plays the resolved
	cue via SoundService (positional via SoundService.PlayLocalSound
	for ambient; via a parented Sound for 3D positional). Also exposes
	`PlayLocal(cueId)` for purely client-side UI cues that don't need
	to round-trip through the server.

	Cue resolution: AudioRegistry.Get(cueId). Missing entries or
	assetId == 0 are no-ops (so dev builds run silent on placeholders).

	Pool: per-cue lazy pool of `Sound` instances up to
	`Constants.AUDIO.PoolSizePerCue` — Sound.Ended releases back to
	the pool. Music + ambient loops bypass the pool (single Sound per
	loopId).

	Throttle: identical cueIds fired within `cue.throttleMs` (or the
	`Constants.AUDIO.ThrottleMs` default) coalesce — the second call
	is dropped silently. This prevents 6-drone-in-one-frame stacking
	from clipping the mix.

	Music crossfade: SwitchMusic broadcasts a cue with `opts.loopId`.
	The client maintains a `currentMusic` ledger keyed by loopId; on a
	new loopId, the existing Sound tweens its Volume → 0 over
	`Constants.AUDIO.MusicCrossfadeSeconds` while the new Sound tweens
	0 → target volume.

	Public API:
	  Init                          — wire AudioCue listener
	  PlayLocal(cueId, opts?)       — client-only one-shot (UI clicks etc.)
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AudioRegistry = require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("AudioRegistry"))

local AudioController = {}

export type CueOpts = {
	position: Vector3?,
	volume: number?,
	pitch: number?,
	targetPart: BasePart?,
	attachTo: Instance?,
	loopId: string?,
}

local CUE_HOST_FOLDER = "OutpostAudioHost"
local MUSIC_HOST_FOLDER = "OutpostAudioMusic"

-- Per-cueId rolling pool of free Sound instances.
local pool: { [string]: { Sound } } = {}
-- Per-cueId last-fire timestamp (ms) for throttle coalescing.
local lastFire: { [string]: number } = {}
-- Active music tracks keyed by loopId — { sound, loopId }.
local activeMusic: { [string]: Sound } = {}

local function nowMs(): number
	return math.floor(os.clock() * 1000)
end

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function categoryVolume(category: string): number
	local v = Constants.AUDIO.CategoryVolume[category]
	if not v then
		return 1.0
	end
	return v
end

local function effectiveVolume(cue: AudioRegistry.AudioCue, callVolume: number?): number
	local call = callVolume or 1.0
	return cue.volume * call * categoryVolume(cue.category) * Constants.AUDIO.MasterVolume
end

local function rollOffEnum(modeName: string): Enum.RollOffMode
	-- Defensive map for the Constants string. Defaults to InverseTapered.
	if modeName == "Inverse" then
		return Enum.RollOffMode.Inverse
	elseif modeName == "Linear" then
		return Enum.RollOffMode.Linear
	elseif modeName == "LinearSquare" then
		return Enum.RollOffMode.LinearSquare
	end
	return Enum.RollOffMode.InverseTapered
end

local function acquireSound(cue: AudioRegistry.AudioCue): Sound?
	if cue.assetId <= 0 then
		-- Placeholder cue. No-op until Phase H upload.
		return nil
	end
	local bucket = pool[cue.id]
	if bucket and #bucket > 0 then
		local sound = table.remove(bucket) :: Sound
		return sound
	end
	-- Lazy alloc: pool already at cap? Still create — pool only caps
	-- the *reuse* count; instantaneous polyphony beyond cap is allowed.
	-- (Sounds end up parented + auto-destroyed, not pooled.)
	local sound = Instance.new("Sound")
	sound.SoundId = string.format("rbxassetid://%d", cue.assetId)
	sound.RollOffMin = cue.rollOffMin or Constants.AUDIO.Spatial.RollOffMinDistance
	sound.RollOffMax = cue.rollOffMax or Constants.AUDIO.Spatial.RollOffMaxDistance
	sound.RollOffMode = rollOffEnum(Constants.AUDIO.Spatial.RollOffMode)
	return sound
end

local function releaseSound(cueId: string, sound: Sound)
	local bucket = pool[cueId]
	if not bucket then
		bucket = {}
		pool[cueId] = bucket
	end
	if #bucket >= Constants.AUDIO.PoolSizePerCue then
		sound:Destroy()
		return
	end
	sound:Stop()
	sound.PlaybackSpeed = 1.0
	sound.Volume = 0
	sound.Parent = nil
	table.insert(bucket, sound)
end

local function throttleAllows(cue: AudioRegistry.AudioCue): boolean
	local windowMs = cue.throttleMs or Constants.AUDIO.ThrottleMs
	local now = nowMs()
	local last = lastFire[cue.id]
	if last and (now - last) < windowMs then
		return false
	end
	lastFire[cue.id] = now
	return true
end

local function playOneShot(cue: AudioRegistry.AudioCue, opts: CueOpts)
	local sound = acquireSound(cue)
	if not sound then
		return
	end
	sound.Volume = effectiveVolume(cue, opts.volume)
	sound.PlaybackSpeed = opts.pitch or cue.pitch
	sound.Looped = false

	-- Parent strategy:
	--   1. opts.targetPart / opts.attachTo: spatial follow-through
	--   2. opts.position: parent to a transient anchor at that position
	--   3. neither: SoundService (2D / global)
	local hostFolder = ensureFolder(SoundService, CUE_HOST_FOLDER)
	if opts.targetPart then
		sound.Parent = opts.targetPart
	elseif opts.attachTo then
		sound.Parent = opts.attachTo
	elseif opts.position then
		local host = Instance.new("Part")
		host.Anchored = true
		host.CanCollide = false
		host.Transparency = 1
		host.Size = Vector3.new(0.1, 0.1, 0.1)
		host.CFrame = CFrame.new(opts.position)
		host.Parent = hostFolder
		sound.Parent = host
		-- Cleanup the host part after the sound finishes.
		sound.Ended:Once(function()
			releaseSound(cue.id, sound)
			host:Destroy()
		end)
		sound:Play()
		return
	else
		sound.Parent = SoundService
	end

	sound.Ended:Once(function()
		releaseSound(cue.id, sound)
	end)
	sound:Play()
end

local function playMusic(cue: AudioRegistry.AudioCue, opts: CueOpts, loopId: string)
	-- If a sound for this loopId is already active, do nothing
	-- (idempotent — duplicate SwitchMusic with same loopId is a no-op).
	if activeMusic[loopId] then
		return
	end
	if cue.assetId <= 0 then
		return -- placeholder; no-op
	end
	local musicFolder = ensureFolder(SoundService, MUSIC_HOST_FOLDER)
	local newSound = Instance.new("Sound")
	newSound.SoundId = string.format("rbxassetid://%d", cue.assetId)
	newSound.Looped = true
	newSound.Volume = 0 -- fade in
	newSound.PlaybackSpeed = opts.pitch or cue.pitch
	newSound.Name = string.format("Music_%s", loopId)
	newSound.Parent = musicFolder
	newSound:Play()

	local targetVolume = effectiveVolume(cue, opts.volume)
	local fadeIn = TweenService:Create(
		newSound,
		TweenInfo.new(Constants.AUDIO.MusicCrossfadeSeconds, Enum.EasingStyle.Linear),
		{ Volume = targetVolume }
	)
	fadeIn:Play()

	-- Fade out all OTHER active loops.
	for otherId, otherSound in activeMusic do
		if otherId ~= loopId then
			local fadeOut = TweenService:Create(
				otherSound,
				TweenInfo.new(Constants.AUDIO.MusicCrossfadeSeconds, Enum.EasingStyle.Linear),
				{ Volume = 0 }
			)
			fadeOut:Play()
			-- Capture for later cleanup.
			local capturedId = otherId
			local capturedSound = otherSound
			task.delay(Constants.AUDIO.MusicCrossfadeSeconds + 0.1, function()
				capturedSound:Destroy()
				if activeMusic[capturedId] == capturedSound then
					activeMusic[capturedId] = nil
				end
			end)
		end
	end

	activeMusic[loopId] = newSound
end

local function handleCue(cueId: string, opts: CueOpts?)
	local cue = AudioRegistry.Get(cueId)
	if not cue then
		warn(string.format("[AudioController] Unknown cueId '%s'", cueId))
		return
	end
	if not throttleAllows(cue) then
		return
	end
	local resolved: CueOpts = opts or {}
	if cue.looped and resolved.loopId then
		playMusic(cue, resolved, resolved.loopId)
	elseif cue.looped then
		-- Looped cue without a loopId — treat as one-shot for safety;
		-- ambient loops should always carry a loopId so they can be
		-- replaced cleanly.
		warn(string.format("[AudioController] Looped cue '%s' fired without loopId; ignoring", cueId))
	else
		playOneShot(cue, resolved)
	end
end

function AudioController.PlayLocal(cueId: string, opts: CueOpts?)
	-- Bypasses the Remote — used for pure-client UI cues. Same path
	-- as a server-pushed cue but skips the network hop.
	handleCue(cueId, opts)
end

function AudioController.Init()
	Remotes.AudioCue.OnClientEvent:Connect(function(cueId: string, opts: CueOpts?)
		handleCue(cueId, opts)
	end)
	-- Defensive: warn if the local player isn't yet ready. Init is
	-- normally called after Players.LocalPlayer is set, but if the
	-- bootstrap order shifts in a future phase, surface it.
	if not Players.LocalPlayer then
		warn("[AudioController] Init called before LocalPlayer was set")
	end
end

return AudioController
