--!strict
--[[
	Outpost-7 — offline progression grant on rejoin.

	Phase C4. After BuildRestorer re-applies the player's saved layout
	(extractors registered with CurrencyService), compute:

	    elapsed = os.time() - previousLastJoinAt
	    capped  = min(elapsed, OfflineProgressionCapSeconds)   -- 12h
	    income  = sum(registered extractor income, per second)
	    granted = floor(capped * income)

	Grant Credits server-side via CurrencyService.Add and push a
	WelcomeBack notice to the client for the popup. New players
	(no previousLastJoinAt) and players with no extractors get a
	silent skip — no popup, no grant.

	The 12h cap exists per finalized-brainstorm.md §2.4: it
	prevents whales from never logging in. Tunable in
	`Constants.RETENTION.OfflineProgressionCapSeconds`.

	Public API:
	  GrantOnJoin(player)  — internal; wired to BuildRestorer.OnRestoreComplete
	  Init                 — connects the signal
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local CurrencyService = require(script.Parent.Parent.Economy.CurrencyService)
local BuildRestorer = require(script.Parent.Parent.Build.BuildRestorer)

local OfflineProgression = {}

export type WelcomeBack = {
	elapsedSeconds: number,
	cappedSeconds: number,
	incomePerSecond: number,
	grantedCredits: number,
	wasCapped: boolean,
}

function OfflineProgression.GrantOnJoin(player: Player)
	local data = DataManager.GetData(player)
	if not data then
		return
	end
	local meta = DataManager.GetSessionMeta(player)
	if not meta or not meta.previousLastJoinAt then
		-- First-ever join. Nothing to grant.
		return
	end

	local now = os.time()
	local elapsed = now - meta.previousLastJoinAt
	if elapsed <= 0 then
		return
	end

	local cap = Constants.RETENTION.OfflineProgressionCapSeconds
	local capped = math.min(elapsed, cap)
	local incomePerSecond = CurrencyService.GetTotalIncomePerSecond(player)
	if incomePerSecond <= 0 then
		-- No extractors → no offline income. No popup either; the
		-- player has nothing to "welcome back" about.
		return
	end

	-- D5: apply the player's pass multiplier to the offline grant
	-- (closes D3 tech debt). Players with 2× Credits + Auto-Collect
	-- get ×3.0 offline income, same as live tick.
	local multiplier = CurrencyService.GetMultiplier(player)
	local granted = math.floor(capped * incomePerSecond * multiplier)
	if granted <= 0 then
		return
	end

	CurrencyService.Add(player, granted)

	local payload: WelcomeBack = {
		elapsedSeconds = elapsed,
		cappedSeconds = capped,
		incomePerSecond = incomePerSecond,
		grantedCredits = granted,
		wasCapped = elapsed > cap,
	}
	local remote = Remotes.WelcomeBack :: RemoteEvent
	remote:FireClient(player, payload)

	print(
		string.format(
			"[OfflineProgression] %s away %ds (capped %ds), income %d/s → +%d credits",
			player.Name,
			elapsed,
			capped,
			incomePerSecond,
			granted
		)
	)
end

function OfflineProgression.Init()
	BuildRestorer.OnRestoreComplete:Connect(function(player: Player)
		OfflineProgression.GrantOnJoin(player)
	end)
end

return OfflineProgression
