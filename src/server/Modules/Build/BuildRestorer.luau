--!strict
--[[
	Outpost-7 — base layout replay on plot allocation.

	Phase B3. When a player is allocated a plot, walk their saved
	`baseLayout` and re-apply each placement via PlacementService in
	**trusted** mode (skip affordability + skip persist-back —
	both already paid; both already saved).

	Failures during restore log a warn and skip the entry rather than
	erroring out. Plausible failure cases:
	  - `unknown buildable` — schema drift between saves and the
	    current registry (e.g. a buildable was renamed in code).
	  - `cell outside plot` — plot dimensions changed in Constants
	    since the save was written.
	  - `cell already occupied` — duplicate save entries (corrupt
	    layout). The first placement wins; the duplicate is dropped.
	  - `no resource node at cell` — node spawner seed changed and
	    the node that justified the extractor isn't there. The
	    extractor doesn't restore.
	The player keeps a partial restore in any of these cases. We log
	for diagnostics; Phase F1 may add a "saved buildings dropped on
	restore" telemetry event.
--]]

local Players = game:GetService("Players")

local PlotManager = require(script.Parent.Parent.World.PlotManager)
local BaseSerializer = require(script.Parent.BaseSerializer)
local PlacementService = require(script.Parent.PlacementService)

type PlotInfo = PlotManager.PlotInfo

local BuildRestorer = {}

-- Fires after Restore completes (success-or-fail) for a player.
-- C4's OfflineProgression subscribes so it can read the now-registered
-- extractor income to compute the offline grant. Subsequent phases can
-- subscribe for similar "post-restore" hooks.
local onRestoreComplete = Instance.new("BindableEvent")
BuildRestorer.OnRestoreComplete = onRestoreComplete.Event

function BuildRestorer.Restore(player: Player, plot: PlotInfo): (number, number)
	local saved = BaseSerializer.Get(player)
	if #saved == 0 then
		-- Still fire the signal so OfflineProgression's "0 income →
		-- no popup" path runs cleanly instead of waiting forever.
		onRestoreComplete:Fire(player, plot, 0, 0)
		return 0, 0
	end

	local successCount = 0
	local failCount = 0
	for _, entry in saved do
		local result = PlacementService.TryPlace(player, entry.id, entry.x, entry.z, true)
		if result.ok then
			successCount += 1
		else
			failCount += 1
			warn(
				string.format(
					"[BuildRestorer] Plot%d: failed to restore %s at (%d,%d) for %s — %s",
					plot.id,
					entry.id,
					entry.x,
					entry.z,
					player.Name,
					result.error
				)
			)
		end
	end

	print(
		string.format(
			"[BuildRestorer] Plot%d for %s: restored %d/%d",
			plot.id,
			player.Name,
			successCount,
			successCount + failCount
		)
	)
	onRestoreComplete:Fire(player, plot, successCount, failCount)
	return successCount, failCount
end

local function onPlayerJoined(player: Player)
	local plot = PlotManager.WaitForPlot(player)
	if not plot then
		-- Server full or player left during allocation.
		return
	end
	if not player:IsDescendantOf(Players) then
		return
	end
	BuildRestorer.Restore(player, plot)
end

function BuildRestorer.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerJoined, player)
	end)
	-- Catch any players already present (script reload during dev).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerJoined, player)
	end
end

return BuildRestorer
