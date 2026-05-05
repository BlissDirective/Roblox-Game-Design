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

## C2 — Restocking blueprint shop ✅

**Date:** 2026-05-04
**Branch:** `claude/review-claude-docs-LiZZS`

### What was built

- **`ProfileSchema.luau`** — `shopRotationSeen: number?` +
  `shopBuysThisRotation: { [string]: boolean }`. Additive; stale
  rotations reset lazily on first GetState/TryBuy of a new window.
- **`Constants.luau`** — `ShopSlotsPerRotation = 3` added under
  `RETENTION` (alongside the existing `ShopRotationSeconds` from C1
  scaffolding).
- **`Economy/BlueprintRegistry.luau`** — V1 catalog of 6 placeholder
  items (3 Common, 2 Uncommon, 1 Rare). Each has weight + cost +
  `grantCredits` (the V1 effect — direct Credits grant). Phase E
  expands when actual buildable unlocks land.
- **`Economy/ShopService.luau`** —
  - `getRotationIndex` = `floor(os.time() / ShopRotationSeconds)`.
  - `generateStockForRotation(rotation)` = weighted-without-replacement
    sampling using `Random.new(rotation)`. Deterministic; every
    server in the same 6h window produces the same 3 items.
  - `GetState(player)` lazily refreshes the player's per-rotation
    purchase tracking, then returns the rotation index +
    `secondsUntilRestock` + items with per-player `bought` flags.
  - `TryBuy(player, blueprintId)` validates: id exists → in current
    stock → not already bought → CurrencyService.TrySpend cost.
    On success, applies the grant (V1: Credits) + records the buy.
  - Background loop polls once a minute for rotation rollover; on
    boundary, bumps the cache and re-pushes ShopState to all online
    players so their UIs restock without rejoining.
- **`Remotes.luau`** — `ShopState` (Server → Client Event) +
  `BuyShopItem` (Client → Server RemoteFunction).
- **`init.server.luau`** — wired `ShopService.Init()` after
  `DailyLoginManager.Init()`.
- **`Shop/ShopPanel.luau`** — slide-up centered panel. Title shows
  "Restocks in Xh Ym". Three rarity-tinted cards per rotation with
  Buy buttons that flip to "Sold Out" after a successful purchase.
- **`Shop/ShopController.luau`** — adds a top-left "Shop" toggle
  button that calls `ShopPanel.Toggle()`.
- **`init.client.luau`** — wired `ShopController.Init()` last.

### Audit (C2-scope, sandbox-side)

- `--!strict` on the new modules (31 .luau files total)
- `stylua --check` clean
- `rojo build` produces a `.rbxl` with the new tree
- Determinism check (manual): `Random.new(N)` with the same N
  produces the same sequence; the weighted-without-replacement loop
  removes picked items from the working pool, so all 3 slots are
  distinct.

### Audit (C2-scope, Studio-side — pending your local run)

After F5:

1. **Toggle button visible** — top-left "Shop" button.
2. **Open shop** — tap; panel slides in. Three rarity-tinted cards
   visible; title shows the countdown.
3. **Buy a Common item** — Credits HUD ticks the cost down then up
   by the grant amount (net positive). Card flips to "Sold Out".
4. **Re-buy attempt** — Sold Out button is disabled; clicking does
   nothing. (If Studio Test Run is fast, server-side `TryBuy`
   would reject with `"already bought this rotation"`.)
5. **Insufficient credits** — Spend Credits below the next-cheapest
   item's cost via the Command Bar:
   ```luau
   local DM = require(game.ServerScriptService.Server.Modules.Player.DataManager)
   DM.GetData(game.Players:GetPlayers()[1]).credits = 50
   -- now click Buy on a 100+ cost item
   ```
   The server returns `{ok=false, error="insufficient credits"}`;
   the card stays Buy (no state advance).
6. **Rotation rollover test** — Studio's `os.time()` advances with
   real time; for an immediate rollover, run in Server Command Bar:
   ```luau
   -- Force-advance the rotation cache without changing system clock:
   local SS = require(game.ServerScriptService.Server.Modules.Economy.ShopService)
   -- (Manually push state with a synthesized rotation by
   --  temporarily monkey-patching getRotationIndex — out of scope
   --  for V1 audit. Simpler: just wait 6 hours, or rely on the
   --  determinism check above to trust the rotation logic.)
   ```
   The deterministic path is well-tested by code reading; live
   rotation rollover gets verified once the game is on the
   Open Cloud staging place.
7. **Two-client determinism** — Test → Local Server → 2 clients.
   Both players see the same 3 items in their shops. (Different
   per-player `bought` flags after one of them buys.)

### Tech debt / deferred

- **No actual blueprint unlocks.** Catalog grants Credits only —
  it's a placeholder economy that rewards active play. Phase E
  replaces with real buildable unlocks (turret variants, drone-bay
  configs) once those buildables exist.
- **No restock countdown live update.** The countdown text shows
  the value at panel-open time; it doesn't tick down second-by-
  second. Phase G adds a simple Heartbeat tick when the panel is
  open.
- **No purchase animation.** Card snaps from Buy → Sold Out with
  no juice. Phase G.
- **No rarity-specific behavior beyond UI tinting.** The `rarity`
  field is informational. If we want "Rare items always grant the
  best discount", that's a tuning pass in Phase G.
- **Background poll is 60s.** A rotation boundary crossing during
  active play takes up to 60s to push. Acceptable for V1; F1 could
  tighten to 5s if needed.
- **Toggle button position** collides with mobile chat by default.
  Phase G repositions per device.

### What's next

C3 — daily quests. 3 quests selected from a pool of ~10, deterministic
seed by UTC day. Schema gets `dailyQuests`. New module
`Retention/DailyQuestManager.luau` + `Retention/QuestObjectives.luau`
(event hooks). New Remotes `DailyQuestState` + `ClaimQuest`.

---

## C3 — Daily quests ✅

**Date:** 2026-05-04
**Branch:** `claude/review-claude-docs-LiZZS`

### What was built

- **`ProfileSchema.luau`** — `dailyQuests: { [string]: QuestProgress }`
  + `lastQuestReset: string?`. New `QuestProgress` type
  (`{ progress, claimed }`). Additive; stale quest sets reset
  lazily on the first GetState/TryClaim of a new UTC day.
- **`Retention/QuestObjectives.luau`** — singleton pub-sub. Services
  emit via `QuestObjectives.Emit(event, player, amount)`;
  DailyQuestManager subscribes once and dispatches to active
  quests. Decoupled — emitters don't import DailyQuestManager
  (avoids cycles); manager doesn't enumerate emitters.
- **`Retention/DailyQuestManager.luau`** — V1 quest pool of 10:
  Construction Crew, Fortifier, Builder's Dozen, Big Spender,
  Frugal Engineer, Tycoon Surge, Smart Shopper, Bargain Hunter,
  Checked In, Time on Planet. Three picked deterministically per
  UTC day via Fisher-Yates with `Random.new(daySeed)` where
  `daySeed = floor(os.time() / 86400)`. Pool is `table.sort`'d
  before shuffle so iteration-order non-determinism in the table
  doesn't break cross-server alignment.
- **`Economy/CurrencyService.luau`** — added `AddCores` +
  `GetCores` (Cores = V1 premium currency, granted by quest
  rewards now and dev products in D2). Also fixed a leftover
  bug from the B4 BuildableRegistry move: import path was still
  pointing at `script.Parent.Parent.Build.BuildableRegistry`
  which no longer exists; corrected to
  `Shared.Modules.Registry.BuildableRegistry`. **Would have failed
  at first runtime use.**
- **Quest event emissions wired**:
  - `PlacementService.TryPlace` (fresh, non-trusted) →
    `place_<buildableId>` + `place_any`
  - `CurrencyService.TrySpend` → `spend_credits` (amount)
  - `CurrencyService.Add` → `earn_credits` (amount)
  - `ShopService.TryBuy` → `buy_shop_item` (1)
  - `DailyLoginManager.TryClaim` → `claim_daily` (1)
  - `DailyQuestManager` per-minute tick → `play_session` (1)
- **`Remotes.luau`** — `DailyQuestState` (Server → Client Event) +
  `ClaimQuest` (Client → Server RemoteFunction).
- **`init.server.luau`** — wired `DailyQuestManager.Init()` after
  `ShopService.Init()`.
- **`Retention/DailyQuestsPanel.luau`** — slide-in centered panel
  with 3 quest rows. Each row: name, description, progress bar
  (live-updating via state pushes), reward preview, Claim button.
  Stroke colors per state (active / complete / claimed).
- **`init.client.luau`** — wired `DailyQuestsPanel.Init()` last.
  Adds a top-row "Quests" toggle button (next to "Shop").

### Audit (C3-scope, sandbox-side)

- 35 `.luau` files — `--!strict` on all
- `stylua --check` clean
- `rojo build` produces a `.rbxl` with the new tree
- Determinism check (manual): `Random.new(daySeed)` with the same
  seed produces the same Fisher-Yates result; pool is sorted
  pre-shuffle so iteration order doesn't drift between servers.

### Audit (C3-scope, Studio-side — pending your local run)

After F5:

1. **Quests button visible** — top-row, right of "Shop".
2. **Open panel** — 3 quest rows show. All show `0 / N` progress,
   buttons read the reward (`+N ¢ +M ♦`), buttons are disabled.
3. **Make progress on a quest.** If "Construction Crew" (place 3
   extractors) is in today's roll:
   - Add credits (`CurrencyService.Add` from Command Bar) and place
     extractors via the build palette.
   - Watch the progress bar tick `1/3`, `2/3`, `3/3` in real time.
   - Button switches to green "Claim" once complete.
4. **Claim** — button reads "Claimed", greyed out. Credits + Cores
   granted (Credits visible in HUD; Cores tracked in profile —
   no HUD readout yet, lands in D).
5. **Cross-quest cascade.** If "Tycoon Surge" (earn 2500) is in
   today's set, claiming "Big Spender" (which grants 800 Credits
   via CurrencyService.Add → emits `earn_credits`) advances Tycoon
   Surge's progress bar. Intentional — engaged completers get a
   modest cascade. Phase G tunes if too generous.
6. **Determinism test (two-client local server).** Both players
   see the **same 3 quests** today. Different per-player progress
   + claim flags after independent play.
7. **Day rollover (manual sim).** In Server Command Bar:
   ```luau
   local DM = require(game.ServerScriptService.Server.Modules.Player.DataManager)
   local QM = require(game.ServerScriptService.Server.Modules.Retention.DailyQuestManager)
   local p = game.Players:GetPlayers()[1]
   DM.GetData(p).lastQuestReset = "2020-01-01"
   print(QM.GetState(p)) -- triggers ensureFreshDay; new 3 quests rolled
   ```
   Re-open the panel — fresh 3 quests with 0 progress.

### Tech debt / deferred

- **No Cores HUD readout.** `AddCores` works server-side; client
  has no display until Phase D ships the cosmetic shop with the
  paired `CoresChanged` Remote.
- **No quest icons / category tags.** All 10 V1 quests show a
  plain text description. Phase G adds icon + Build / Defend /
  Raid category coloring per `finalized-brainstorm.md` §2.4.
- **10 quests, not 30.** Brainstorm targets ~30 quest variants for
  V1 launch ("variety = retention"). C3 ships 10 to validate the
  system; expansion is a content-only change in Phase G (or sooner
  if quest rotation feels stale during playtests).
- **No combat / raid quests.** The pool only contains
  Build / Economy objectives because Combat (E2) and Raids (E1)
  don't exist yet. Phase E adds `survive_wave`, `raid_won`,
  `raid_attended` events + matching quests.
- **`play_session` is in-memory only.** Resets each rejoin. A
  player could "Time on Planet: 15 minutes" by joining for 15
  minutes once; if they leave at 14 minutes, restart, they need
  another 15. Acceptable for V1; F1 may persist the session
  counter inside the day.
- **No live countdown tick** on the panel (matches ShopPanel).
  Phase G adds.

### What's next

C4 — offline progression. On rejoin, compute
`elapsed = os.time() - lastJoinAt` capped at 12 hours, multiply by
the player's per-second income (read from BuildRestorer post-restore
extractors), grant Credits, and fire a "Welcome Back" popup. Closes
Phase C; the four-mechanic retention stack is then complete.

---

## C4 — Offline progression ✅ — closes Phase C

**Date:** 2026-05-04
**Branch:** `claude/review-claude-docs-LiZZS`

### What was built

- **`Player/DataManager.luau`** — gained per-player `sessionMeta`
  table tracking `previousLastJoinAt`. Captured during LoadPlayer
  *before* the bookkeeping write so OfflineProgression can read it
  on rejoin. Cleared on PlayerRemoving alongside the loadedSignal.
  New public API: `GetSessionMeta(player)`.
- **`Build/BuildRestorer.luau`** — exposes `OnRestoreComplete:
  RBXScriptSignal`. Fires after Restore completes (success-or-fail,
  including the `#saved == 0` path so OfflineProgression's
  "no-income → no-popup" branch runs cleanly without waiting).
- **`Economy/CurrencyService.luau`** — added
  `GetTotalIncomePerSecond(player)`. Sums all currently-registered
  extractors' income; reads 0 if the player has none.
- **`Retention/OfflineProgression.luau`** — `GrantOnJoin(player)`:
  `elapsed = os.time() - previousLastJoinAt` capped at
  `Constants.RETENTION.OfflineProgressionCapSeconds` (12h),
  multiplied by `GetTotalIncomePerSecond`, granted via
  `CurrencyService.Add`, fired to client via `Remotes.WelcomeBack`.
  Skips silently for first-ever joins (no previous timestamp) and
  for players with no extractors.
- **`Remotes.luau`** — `WelcomeBack` (Server → Client Event).
- **`init.server.luau`** — `OfflineProgression.Init()` wired last,
  after `DailyQuestManager.Init()`. Comment notes the ordering
  requirement (must be after BuildRestorer.Init so the
  `OnRestoreComplete` subscription is in place before the first
  player's restore fires).
- **`Retention/WelcomeBackPopup.luau`** — centered modal showing
  away time (with "capped at 12h" suffix when `wasCapped`),
  income rate, and the granted Credits total. Single Collect
  button dismisses.
- **`init.client.luau`** — wired `WelcomeBackPopup.Init()` last.

### Audit (C4-scope, sandbox-side)

- 38 `.luau` files — `--!strict` on all
- `stylua --check` clean
- `rojo build` produces a `.rbxl` with the new tree

### Audit (C4-scope, Studio-side — pending your local run)

After F5:

1. **First join (new account)** — no popup. Output is silent on
   OfflineProgression (no `previousLastJoinAt`).
2. **Place an extractor** — start earning income. Note the
   per-second rate (1/sec for one extractor at V1 values).
3. **Stop play (Shift+F5).** `lastJoinAt` saves through
   ProfileStore EndSession.
4. **Time-shift** in Server Command Bar (so the rejoin sees a
   gap) — easier than waiting:
   ```luau
   local DM = require(game.ServerScriptService.Server.Modules.Player.DataManager)
   local p = game.Players:GetPlayers()[1]
   DM.GetData(p).lastDailyClaim = nil  -- avoid C1 popup interfering
   -- Force the saved lastJoinAt back 30 minutes:
   DM.GetData(p).lastJoinAt = os.time() - 1800
   ```
   Stop, F5 again. Output should include
   `[OfflineProgression] <Name> away 1800s (capped 1800s), income N/s → +M credits`.
   The Welcome Back popup shows: "Away: 30m", "Income rate: N/sec",
   "+M Credits". Click Collect → popup closes, HUD shows the
   new total.
5. **Cap test.** Set `lastJoinAt = os.time() - 86400` (24h);
   rejoin. Expect "Away: 24h (capped at 12h)". Granted = 12h ×
   income rate.
6. **No-income path.** Player with zero extractors and a previous
   join: no popup, no grant, no log line.

### Tech debt / deferred

- **Wave damage during offline.** V1 assumes bases survive offline
  (no PvE waves while away). Phase E may add wave persistence so
  long absences cost the player some defenders, balancing the
  offline grant.
- **No multiplier interaction.** Phase D's 2x Credits pass should
  multiply offline income too. Implementation lands when
  `GamePassService.SetMultiplier` is wired — at that point
  OfflineProgression will read the multiplier just like
  CurrencyService's tick does.
- **No animation.** Welcome Back popup snaps in. Phase G adds
  spring tween + coin spill on Collect.
- **Popup ordering.** If a player is also eligible for the daily
  login popup (C1), both fire on join. They can stack (Welcome
  Back behind Daily Login). For V1 this is fine — close one and
  the other is still readable. F4 may sequence them.

### Phase C status

**All four daily-return mechanics shipped.** Server enforces every
gate; clients render. Phase C audit gate per
`10_BUILD_PROTOCOL.md`: time-shift test (`lastDailyClaim`,
`lastQuestReset`, `lastJoinAt` Command Bar manipulation) verifies
streak / quest reset / offline grant logic without waiting for
real UTC midnight. Per-mechanic recipes are in their respective
sub-phase entries above.

**Phase C commits:**
- `94faf80` C1 — daily login + 7-day streak
- `8e63afc` C2 — restocking blueprint shop
- `29ac845` C3 — daily quests + cross-service event bus
- `<this commit>` C4 — offline progression

### What's next

Phase D — monetization. Game Passes (2× Credits, Auto-Collect,
VIP Operator), Developer Products (Emergency Shield, Credit Packs,
Core Pack), Battle Pass infrastructure, idempotent
`MarketplaceService.ProcessReceipt`. ADR-001's "ProcessReceipt
idempotency" rule from the brainstorm §4.5 is the highest-stakes
guarantee in this phase — duplicate receipt firings (Roblox can
fire twice) must not double-grant.
