--!strict
--[[
	Outpost-7 — PvE wave lifecycle.

	Phase E2. Owns per-player active wave state in the main place.
	Two trigger paths:
	  1. **Wave clock** — every `Constants.COMBAT.WaveClockSeconds`,
	     fire a wave for every online player who has a plot. Approximates
	     the brainstorm's "by night, the jungle moves" cadence; Phase G
	     swaps to a real day/night cycle.
	  2. **Queue-deadline fallback** — `RaidMatchmaker` deadline-pop
	     calls `StartFallbackWave(player)` so the player gets a PvE
	     consolation when no raid match landed.

	Wave lifecycle:
	  - StartWave(player, opts) — picks the alien count for the wave
	    via `Constants.COMBAT.AliensPerWaveBase + (N-1) × Scale`
	    (capped at `AliensPerWaveCap`). Spawns aliens staggered over
	    `WaveSpawnWindowSeconds`. Each alien gets the player as its
	    target via AlienAI.Drive.
	  - End conditions: all aliens dead, OR `WaveDurationSeconds`
	    elapsed, OR player character died (Humanoid.Died).
	  - On end: profile.wavesSurvived increments only if the player
	    survived (alien-kill-all OR timer-expiry-with-player-alive
	    both count as survived). Player-died counts as a loss; no
	    increment. Emits `wave_survived` to QuestObjectives so future
	    quest entries can hook.

	Public API:
	  Init                   — wires PlayerAdded + wave-clock loop
	  StartWave(player)      — main-place wave for this player; returns
	                           ok bool (false if a wave is already
	                           active for them or no plot)
	  StartFallbackWave(p)   — same as StartWave but tags the
	                           WaveStarted payload with `reason =
	                           "queue_deadline"` for client UX
	  IsWaveActive(player)   — non-yielding check
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AlienRegistry =
	require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("AlienRegistry"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local PlotManager = require(script.Parent.Parent.World.PlotManager)
local QuestObjectives = require(script.Parent.Parent.Retention.QuestObjectives)
local AlienPool = require(script.Parent.AlienPool)
local AlienAI = require(script.Parent.AlienAI)

type ActiveAlien = AlienPool.ActiveAlien

local WaveDirector = {}

export type StartInfo = {
	waveNumber: number,
	alienCount: number,
	endsAt: number,
	reason: string, -- "clock" | "queue_deadline" | "manual"
}

export type EndResult = {
	waveNumber: number,
	survived: boolean,
	aliensRemaining: number,
}

type ActiveWave = {
	player: Player,
	waveNumber: number,
	startedAt: number,
	endsAt: number,
	aliens: { ActiveAlien },
	controllers: { AlienAI.Controller },
	ended: boolean,
}

-- Per-player current wave (only one wave at a time per player; new
-- StartWave calls while a wave is active are rejected with a warn).
local activeWaves: { [Player]: ActiveWave } = {}

local function pickSpawnPosition(plot: PlotManager.PlotInfo, rng: Random): Vector3
	-- Spawn on the plot perimeter ring. Pick an edge then a point along it.
	local size = Constants.WORLD.PlotSize
	local pad = Constants.COMBAT.SpawnRingPadding
	local edge = rng:NextInteger(1, 4)
	local along = rng:NextNumber(-size / 2, size / 2)
	local outer = size / 2 + pad
	local localOffset: Vector3
	if edge == 1 then
		localOffset = Vector3.new(along, 0, -outer)
	elseif edge == 2 then
		localOffset = Vector3.new(along, 0, outer)
	elseif edge == 3 then
		localOffset = Vector3.new(-outer, 0, along)
	else
		localOffset = Vector3.new(outer, 0, along)
	end
	return plot.center + localOffset + Vector3.new(0, 3, 0)
end

local function alienCountForWave(wave: number): number
	local raw = Constants.COMBAT.AliensPerWaveBase + (wave - 1) * Constants.COMBAT.AliensPerWaveScale
	return math.min(raw, Constants.COMBAT.AliensPerWaveCap)
end

local function endWave(wave: ActiveWave, survived: boolean)
	if wave.ended then
		return
	end
	wave.ended = true
	-- Stop AI + release all aliens.
	for _, controller in wave.controllers do
		controller:Stop()
	end
	local aliensRemaining = 0
	for _, alien in wave.aliens do
		if alien.humanoid.Health > 0 then
			aliensRemaining += 1
		end
		AlienPool.Release(alien.model)
	end

	if survived then
		local data = DataManager.GetData(wave.player)
		if data then
			data.wavesSurvived += 1
			QuestObjectives.Emit("wave_survived", wave.player, 1)
		end
	end

	local result: EndResult = {
		waveNumber = wave.waveNumber,
		survived = survived,
		aliensRemaining = aliensRemaining,
	}
	if wave.player:IsDescendantOf(Players) then
		local remote = Remotes.WaveEnded :: RemoteEvent
		remote:FireClient(wave.player, result)
	end

	activeWaves[wave.player] = nil

	print(
		string.format(
			"[WaveDirector] %s wave %d ended: survived=%s, remaining=%d",
			wave.player.Name,
			wave.waveNumber,
			tostring(survived),
			aliensRemaining
		)
	)
end

local function watchWave(wave: ActiveWave)
	-- Player-character-died watcher.
	local diedConnection: RBXScriptConnection?
	local function bindCharacter(character: Model)
		if diedConnection then
			diedConnection:Disconnect()
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			diedConnection = humanoid.Died:Connect(function()
				endWave(wave, false)
			end)
		end
	end
	if wave.player.Character then
		bindCharacter(wave.player.Character)
	end
	local addedConnection = wave.player.CharacterAdded:Connect(bindCharacter)

	-- All-aliens-dead + timer watchers in a single loop.
	task.spawn(function()
		while not wave.ended do
			task.wait(0.5)
			if wave.ended then
				break
			end
			-- Timer expiry: player survived.
			if os.time() >= wave.endsAt then
				endWave(wave, true)
				break
			end
			-- All-aliens-dead: count alive.
			local aliveCount = 0
			for _, alien in wave.aliens do
				if alien.humanoid.Health > 0 then
					aliveCount += 1
				end
			end
			if aliveCount == 0 and #wave.aliens > 0 then
				endWave(wave, true)
				break
			end
		end
		if diedConnection then
			diedConnection:Disconnect()
		end
		addedConnection:Disconnect()
	end)
end

local function startWaveInternal(player: Player, reason: string): boolean
	if activeWaves[player] then
		warn(string.format("[WaveDirector] Wave already active for %s; ignoring %s", player.Name, reason))
		return false
	end
	local plot = PlotManager.GetPlot(player)
	if not plot then
		warn(string.format("[WaveDirector] %s has no plot; cannot start wave", player.Name))
		return false
	end
	local data = DataManager.GetData(player)
	if not data then
		return false
	end

	local waveNumber = data.wavesSurvived + 1 -- next wave to attempt
	local count = alienCountForWave(waveNumber)
	local def = AlienRegistry.Get("stalker")
	if not def then
		warn("[WaveDirector] Stalker def missing")
		return false
	end

	local rng = Random.new()
	local now = os.time()
	local wave: ActiveWave = {
		player = player,
		waveNumber = waveNumber,
		startedAt = now,
		endsAt = now + Constants.COMBAT.WaveDurationSeconds,
		aliens = {},
		controllers = {},
		ended = false,
	}
	activeWaves[player] = wave

	-- Push StartInfo before any spawn so the client HUD lights up first.
	local startInfo: StartInfo = {
		waveNumber = waveNumber,
		alienCount = count,
		endsAt = wave.endsAt,
		reason = reason,
	}
	local startedRemote = Remotes.WaveStarted :: RemoteEvent
	startedRemote:FireClient(player, startInfo)

	-- Stagger spawns across WaveSpawnWindowSeconds. Avoids the bulk-spawn
	-- ping spike footgun.
	task.spawn(function()
		local windowMs = Constants.COMBAT.WaveSpawnWindowSeconds * 1000
		local intervalMs = if count > 0 then windowMs / count else 0
		for _ = 1, count do
			if wave.ended or not player:IsDescendantOf(Players) then
				break
			end
			local position = pickSpawnPosition(plot, rng)
			local alien = AlienPool.Acquire(def, position)
			if alien then
				alien.targetUserId = player.UserId
				local controller = AlienAI.Drive(alien)
				table.insert(wave.aliens, alien)
				table.insert(wave.controllers, controller)
			end
			task.wait(intervalMs / 1000)
		end
	end)

	watchWave(wave)

	print(
		string.format(
			"[WaveDirector] %s wave %d started: count=%d, reason=%s, endsAt=%d",
			player.Name,
			waveNumber,
			count,
			reason,
			wave.endsAt
		)
	)
	return true
end

function WaveDirector.StartWave(player: Player): boolean
	return startWaveInternal(player, "manual")
end

function WaveDirector.StartFallbackWave(player: Player): boolean
	return startWaveInternal(player, "queue_deadline")
end

function WaveDirector.IsWaveActive(player: Player): boolean
	return activeWaves[player] ~= nil
end

local function waveClockLoop()
	-- Stagger first tick by half the clock to avoid every server firing
	-- their first wave at the exact same moment.
	task.wait(Constants.COMBAT.WaveClockSeconds / 2)
	while true do
		for _, player in Players:GetPlayers() do
			if not activeWaves[player] then
				startWaveInternal(player, "clock")
			end
		end
		task.wait(Constants.COMBAT.WaveClockSeconds)
	end
end

function WaveDirector.Init()
	AlienPool.Init()
	-- Cleanup on player leave: kill their active wave so aliens return
	-- to the pool instead of leaking.
	Players.PlayerRemoving:Connect(function(player)
		local wave = activeWaves[player]
		if wave then
			endWave(wave, false)
		end
	end)
	-- Brainstorm §2.1 fallback hook: when a queued raid attacker hits
	-- their deadline without a match, fire a PvE wave instead. Decoupled
	-- via the RaidMatchmaker.OnDeadlinePop signal (no require cycle).
	-- Required late so the matchmaker's BindableEvent exists.
	local RaidMatchmaker = require(script.Parent.Parent.Raid.RaidMatchmaker)
	RaidMatchmaker.OnDeadlinePop:Connect(function(player: Player)
		WaveDirector.StartFallbackWave(player)
	end)
	task.spawn(waveClockLoop)
end

return WaveDirector
