# PHASE C — Retention Mechanics

> Per-sub-phase worklog. Updated by Claude Code at the end of each
> sub-phase per `10_BUILD_PROTOCOL.md` (Plan → Confirm → Build → Verify
> → Commit → Report).

**Goal (per `finalized-brainstorm.md` §4.4):** All four daily-return
mechanics functional and audited.

**Phase audit gate:** Time-shift test (artificially set `os.time()`
forward, verify streak/cooldown logic). All four mechanics fire rewards
correctly without overlap or double-grant.

---

## Phase research pass (run at kickoff)

Four parallel searches recorded findings:

- **`os.time()` returns UTC unconditionally**; `os.date("!...")` reads
  it as UTC. All time logic stays server-side — clients never send a
  date. Manipulating system clock is the canonical exploit and is
  defeated by server-only `os.time()`.
- **Offline-progression patterns** are well-established: `lastJoinAt`
  → `now - lastJoinAt` capped at threshold × per-second income.
- **Daily-quest deterministic seeding**: `Random.new(daySeed)` where
  `daySeed = day-of-year` (or simpler: `os.time() // 86400`) gives
  every player on every server the same 3 quests for that UTC day.
- **Daily-login exploit prevention**: server-side `os.time()` only;
  no grace-period special features in Roblox — it's a tunable in our
  code.

No architectural surprises. No new ADRs needed.

---

## C1 — Daily login + 7-day streak ✅

**Date:** 2026-05-04
**Branch:** `claude/review-claude-docs-LiZZS`

### What was built

- **`ProfileSchema.luau`** — added `lastDailyClaim: string?`
  (UTC `"YYYY-MM-DD"`) and `dailyStreak: number` (default 0). Both
  additive; `Reconcile()` fills defaults into older saves.
- **`Constants.luau`** — new `RETENTION` section:
  - `DailyRewards`: 1→500, 2→750, 3→1000, 4→1500, 5→2000, 6→3000,
    7→5000, 14→15000, 30→50000. Non-milestone days past 7 default
    to day-7's value.
  - `StreakGraceDays = 1` (yesterday's claim continues the streak;
    anything older resets to day 1).
  - `ShopRotationSeconds = 21600` (C2 placeholder)
  - `OfflineProgressionCapSeconds = 43200` (C4 placeholder)
- **`Retention/DailyLoginManager.luau`** — public API
  `GetState`, `TryClaim`, `Init`. Streak rules: today = no-op,
  yesterday = streak += 1, older = reset to 1. Reward via
  `Constants.RETENTION.DailyRewards[day]` with day-7 fallback.
  All time arithmetic uses `os.time()` server-side; `daysBetween`
  parses `"YYYY-MM-DD"` strings via `os.time({...})` with UTC noon
  anchor for DST-safety.
- **`Remotes.luau`** — registered `DailyLoginState` (Server → Client
  Event) and `ClaimDailyReward` (Client → Server RemoteFunction).
- **`init.server.luau`** — wired `DailyLoginManager.Init()` after
  `BuildRestorer.Init()`.
- **`Retention/DailyLoginPopup.luau`** — centered modal with title
  ("Daily Login — Streak N"), reward line, Claim button. Listens to
  `DailyLoginState`; invokes `ClaimDailyReward` on tap. Shows
  immediate "+N ✓" feedback while waiting for the server-pushed
  state update that hides the popup.
- **`init.client.luau`** — wired `DailyLoginPopup.Init()`.
- **`REMOTES_REGISTRY.md`** + **`DATA_SCHEMA.md`** — updated for the
  two new Remotes and the two new schema fields.

### Audit (C1-scope, sandbox-side)

- `--!strict` on the new modules
- `stylua --check` clean
- `rojo build` produces a `.rbxl` with the new tree

### Audit (C1-scope, Studio-side — pending your local run)

After F5:

1. **Initial state.** A new profile shows the popup: "Daily Login —
   Streak 0", "Day 1: +500 Credits".
2. **Claim.** Tap **Claim**. Button reads `+500 ✓` briefly, then the
   popup closes. HUD ticks from current to current+500.
3. **Re-claim attempt (same day).** Stop play, F5 again. The popup
   does **not** reappear (server `DailyLoginState` fires with
   `canClaim = false`).
4. **Time-shift test (advance 1 day).** In the Server Command Bar:
   ```luau
   local DM = require(game.ServerScriptService.Server.Modules.Player.DataManager)
   local p = game.Players:GetPlayers()[1]
   DM.GetData(p).lastDailyClaim = os.date("!%Y-%m-%d", os.time() - 86400)
   ```
   Then re-trigger the state push:
   ```luau
   require(game.ServerScriptService.Server.Modules.Retention.DailyLoginManager).Init()
   -- or rejoin
   ```
   On rejoin, expect popup with "Streak 1" → claiming advances to
   day 2 (+750 credits).
5. **Streak break test.** Set `lastDailyClaim` to 3 days ago, then
   set `dailyStreak = 5`. On rejoin → claim → expect day 1 reset
   (+500 credits, streak now 1, not 6).
6. **Server-side enforcement test.** From a client Command Bar:
   ```luau
   game.ReplicatedStorage.OutpostRemotes.ClaimDailyReward:InvokeServer()
   ```
   First call grants; second within the same UTC day returns
   `{ ok = false, error = "already claimed today" }`.

### Tech debt / deferred

- **Visuals are debug-grade.** Phase G replaces with neon-tactical
  popup (synthwave palette, spring-tween entry, milestone-day
  variants for 7/14/30).
- **No "Day 7 cosmetic" reward.** Per brainstorm §2.4 the day-7
  reward should also include a unique cosmetic (drone skin / turret
  skin / armor). C1 grants only Credits; the cosmetic grant lands
  in Phase D with the cosmetic registry.
- **No popup-closed callback.** If the player closes the popup
  without claiming (no close button currently — only Claim), the
  state stays "canClaim = true" until next join. Acceptable for V1
  since there's no way to dismiss without claiming.
- **No timezone consideration.** Resets at UTC midnight regardless
  of player's local timezone — a player in UTC+12 effectively gets
  a noon reset. Standard Roblox practice; revisit if data shows
  retention pain in non-UTC regions.

### What's next

C2 — restocking blueprint shop. 6h rotation seeded by date so all
players see the same stock. `Economy/ShopService` +
`Economy/BlueprintRegistry`. New schema fields: `shopRotationSeen`,
`shopBuysThisRotation`. Two new Remotes: `ShopState` (Server → Client)
and `BuyShopItem` (Client → Server RemoteFunction).

---

## C2 — Restocking blueprint shop ⏳

_Pending._

## C3 — Daily quests ⏳

_Pending._

## C4 — Offline progression ⏳

_Pending._
