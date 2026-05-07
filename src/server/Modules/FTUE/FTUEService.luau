--!strict
--[[
	Outpost-7 — First-Time User Experience state machine.

	Phase F4. The brainstorm §4.7 / CLAUDE.md "30-second rule":
	  - 0–5s   cinematic (intro camera; auto-skips after 5s or on ack)
	  - 5–15s  scout (highlighted node within 40 studs; player walks)
	  - 15–20s place_extractor (starter grant; player places)
	  - 20–25s first_credits (CurrencyService tick fires)
	  - 25s    completed (ftueCompleted = true, overlay clears)

	Server is authoritative on step transitions. Client owns the
	cinematic visual (camera tween, intro text) and the `FTUEStepAck`
	for the cinematic step only. Subsequent steps auto-advance via
	`QuestObjectives.OnEmit` subscription on `place_extractor` and
	`earn_credits` events.

	Resume semantics:
	  - On join: read `profile.ftueCompleted`. true → push nil state +
	    return. false → resume from `profile.ftueStep` or start fresh
	    (cinematic).
	  - Step persists in profile so a mid-FTUE crash / disconnect
	    resumes from the last checkpoint.
	  - Step "completed" is sticky; profile.ftueCompleted = true and
	    profile.ftueStep = nil after final transition.

	Trust boundary:
	  - Server tracks step + advances; client cannot forge advancement.
	  - FTUEStepAck validates the acked step matches the player's
	    current step AND that the step is one of the client-ownable
	    steps (cinematic only in V1).
	  - Starter grant (50 credits) is granted once via the StarterCredits
	    flag on transition to "scout"; insurance check (`credits <
	    StarterCredits`) prevents double-grant on resume mid-flow.

	Public API:
	  Init                              — wires PlayerAdded, QuestObjectives subscriptions
	  GetState(player)                  — non-yielding read for diagnostics
	  StartForPlayer(player)            — internal; called on join for first-timers
	  AdvanceStep(player, fromStep)     — internal; transitions if from matches current
	  PushStateToPlayer(player)         — fires FTUEState Remote
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local CurrencyService = require(script.Parent.Parent.Economy.CurrencyService)
local PlotManager = require(script.Parent.Parent.World.PlotManager)
local QuestObjectives = require(script.Parent.Parent.Retention.QuestObjectives)

local FTUEService = {}

export type State = {
	step: string,
	hint: string, -- UI overlay copy; Phase G replaces with proper localized strings
	cinematicSeconds: number?, -- for "cinematic" step
	targetCellX: number?, -- for "scout" step
	targetCellZ: number?, -- for "scout" step
}

export type AckResult = {
	ok: true,
	state: State?,
} | {
	ok: false,
	error: string,
}

local STEPS = Constants.FTUE.Steps

-- Per-player step-timeout tracking. Each step has a max window;
-- if the player doesn't auto-advance within it, server force-skips.
-- Avoids stuck-FTUE for AFK / confused players.
local stepTimeouts: { [Player]: number } = {}

local function pickScoutNode(player: Player): (number?, number?)
	-- Find the closest unclaimed node on the player's plot.
	-- Falls back to the first available node if none within
	-- ScoutNodeMaxDistance (defensive — Poisson-disk node spawner
	-- guarantees ≥1 node per plot).
	local plot = PlotManager.GetPlot(player)
	if not plot then
		return nil, nil
	end
	local origin = plot.center
	local closestDistSq = math.huge
	local closestX, closestZ
	for _, node in plot.nodes:GetChildren() do
		if not node:IsA("BasePart") then
			continue
		end
		if node:GetAttribute("Claimed") then
			continue
		end
		local dx = node.Position.X - origin.X
		local dz = node.Position.Z - origin.Z
		local distSq = dx * dx + dz * dz
		if distSq < closestDistSq then
			closestDistSq = distSq
			closestX = node:GetAttribute("CellX")
			closestZ = node:GetAttribute("CellZ")
		end
	end
	return closestX, closestZ
end

local function buildState(player: Player, step: string): State
	if step == STEPS.Cinematic then
		return {
			step = step,
			hint = "Outpost-7 // Initializing colony...",
			cinematicSeconds = Constants.FTUE.CinematicSeconds,
		}
	end
	if step == STEPS.Scout then
		local cellX, cellZ = pickScoutNode(player)
		return {
			step = step,
			hint = "Walk to the highlighted resource node.",
			targetCellX = cellX,
			targetCellZ = cellZ,
		}
	end
	if step == STEPS.PlaceExtractor then
		return {
			step = step,
			hint = "Open the build palette and place an Extractor on the node.",
		}
	end
	if step == STEPS.FirstCredits then
		return {
			step = step,
			hint = "Wait for your first Credits to flow in.",
		}
	end
	return {
		step = step,
		hint = "Welcome to Outpost-7.",
	}
end

local function pushStateForStep(player: Player, step: string?)
	local remote = Remotes.FTUEState :: RemoteEvent
	if not step or step == STEPS.Completed then
		remote:FireClient(player, nil) -- clears overlay
		return
	end
	remote:FireClient(player, buildState(player, step))
end

function FTUEService.PushStateToPlayer(player: Player)
	local data = DataManager.GetData(player)
	if not data then
		pushStateForStep(player, nil)
		return
	end
	if data.ftueCompleted then
		pushStateForStep(player, nil)
		return
	end
	pushStateForStep(player, data.ftueStep)
end

function FTUEService.GetState(player: Player): State?
	local data = DataManager.GetData(player)
	if not data or data.ftueCompleted or not data.ftueStep then
		return nil
	end
	return buildState(player, data.ftueStep)
end

local function setStepTimeout(player: Player)
	stepTimeouts[player] = os.clock() + Constants.FTUE.StepTimeoutSeconds
end

-- Force-completes the FTUE if a step has been stuck past
-- StepTimeoutSeconds. Defensive against AFK / confused / disconnected-
-- mid-cinematic players.
local function checkTimeouts()
	local now = os.clock()
	for player, deadline in stepTimeouts do
		if now >= deadline and player:IsDescendantOf(Players) then
			local data = DataManager.GetData(player)
			if data and not data.ftueCompleted then
				print(string.format("[FTUEService] %s timed out at step %s — force-completing", player.Name, tostring(data.ftueStep)))
				data.ftueStep = nil
				data.ftueCompleted = true
				stepTimeouts[player] = nil
				pushStateForStep(player, nil)
			else
				stepTimeouts[player] = nil
			end
		end
	end
end

function FTUEService.AdvanceStep(player: Player, fromStep: string)
	local data = DataManager.GetData(player)
	if not data or data.ftueCompleted then
		return
	end
	if data.ftueStep ~= fromStep then
		-- Out-of-order ack / event — ignore. The state machine only
		-- advances forward and only from the current step.
		return
	end
	local nextStep: string? = nil
	if fromStep == STEPS.Cinematic then
		nextStep = STEPS.Scout
		-- Starter grant on entry to Scout step. Insurance check prevents
		-- double-grant on resume mid-flow.
		if data.credits < Constants.FTUE.StarterCredits then
			CurrencyService.Add(player, Constants.FTUE.StarterCredits - data.credits)
		end
	elseif fromStep == STEPS.Scout then
		-- Server auto-advances Scout → PlaceExtractor when the player
		-- approaches the highlighted node. F4 V1 short-circuits this:
		-- transition fires on the place_extractor QuestObjectives event
		-- directly (no walk-detection needed; placing is the implicit
		-- proof of arrival).
		nextStep = STEPS.PlaceExtractor
	elseif fromStep == STEPS.PlaceExtractor then
		nextStep = STEPS.FirstCredits
	elseif fromStep == STEPS.FirstCredits then
		nextStep = STEPS.Completed
	end

	if not nextStep then
		return
	end

	if nextStep == STEPS.Completed then
		data.ftueStep = nil
		data.ftueCompleted = true
		stepTimeouts[player] = nil
		pushStateForStep(player, nil)
		print(string.format("[FTUEService] %s completed FTUE", player.Name))
		return
	end

	data.ftueStep = nextStep
	setStepTimeout(player)
	pushStateForStep(player, nextStep)
	print(string.format("[FTUEService] %s advanced %s -> %s", player.Name, fromStep, nextStep))
end

function FTUEService.StartForPlayer(player: Player)
	local data = DataManager.GetData(player)
	if not data then
		return
	end
	if data.ftueCompleted then
		pushStateForStep(player, nil)
		return
	end
	-- Resume-or-start logic: if mid-FTUE (ftueStep set), resume; else
	-- start at cinematic.
	if not data.ftueStep then
		data.ftueStep = STEPS.Cinematic
	end
	setStepTimeout(player)
	pushStateForStep(player, data.ftueStep)
end

function FTUEService.Init()
	-- Step ack Remote (client owns cinematic step only).
	local ackRemote = Remotes.FTUEStepAck :: RemoteFunction
	ackRemote.OnServerInvoke = function(player: Player, step: any): AckResult
		if typeof(step) ~= "string" then
			return { ok = false, error = "invalid step" }
		end
		-- Only the cinematic step is client-acked; other steps
		-- auto-advance from server-observed events.
		if step ~= STEPS.Cinematic then
			return { ok = false, error = "step not client-ackable" }
		end
		FTUEService.AdvanceStep(player, step)
		return { ok = true, state = FTUEService.GetState(player) }
	end

	-- Auto-advance on extractor placement (Scout -> PlaceExtractor
	-- collapses; PlaceExtractor -> FirstCredits via the same event
	-- because placing always grants implicitly via the income tick
	-- that fires within 1s).
	QuestObjectives.OnEmit(function(event: string, player: Player, _amount: number)
		if event == "place_extractor" then
			-- Short-circuit Scout if the player skipped straight to placing.
			local data = DataManager.GetData(player)
			if data and not data.ftueCompleted then
				if data.ftueStep == STEPS.Scout then
					FTUEService.AdvanceStep(player, STEPS.Scout)
				end
				if data.ftueStep == STEPS.PlaceExtractor then
					FTUEService.AdvanceStep(player, STEPS.PlaceExtractor)
				end
			end
		elseif event == "earn_credits" then
			local data = DataManager.GetData(player)
			if data and not data.ftueCompleted and data.ftueStep == STEPS.FirstCredits then
				FTUEService.AdvanceStep(player, STEPS.FirstCredits)
			end
		end
	end)

	-- Push state on join (after profile loads). For first-timers this
	-- starts the FTUE; for returning players it pushes nil to clear.
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			DataManager.WaitForData(player)
			if not player:IsDescendantOf(Players) then
				return
			end
			-- Brief delay so PlotManager allocation + ResourceNodeSpawner
			-- have finished (Scout step needs a valid node to highlight).
			task.wait(1)
			if not player:IsDescendantOf(Players) then
				return
			end
			FTUEService.StartForPlayer(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		stepTimeouts[player] = nil
	end)

	-- Step-timeout watchdog. 5s cadence is fine — StepTimeoutSeconds
	-- (60s) is the SLA, not the polling interval.
	task.spawn(function()
		while true do
			task.wait(5)
			checkTimeouts()
		end
	end)
end

return FTUEService
