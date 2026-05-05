# PHASE D — Monetization

> Per-sub-phase worklog. Updated by Claude Code at the end of each
> sub-phase per `10_BUILD_PROTOCOL.md`.

**Goal (per `finalized-brainstorm.md` §4.5):** Real money flows. All
passes purchasable. Battle pass infrastructure live (content can fill
in V1.1). **Idempotent `ProcessReceipt`** — duplicate receipt firings
must not double-grant.

**Phase audit gate:** Test purchase flow in Studio (sandbox). Verify
pass effects apply immediately and on rejoin. Verify duplicate
`ProcessReceipt` calls (Roblox can fire twice) only credit once.

**🛑 Real money flow escalation:** per `10_BUILD_PROTOCOL.md`, any
change to Game Pass IDs, Dev Product IDs, prices, or `ProcessReceipt`
logic requires human approval before merging. V1 dev uses placeholder
ID `0` everywhere; real IDs land at Phase H.

---

## Phase research pass (run at kickoff)

Four parallel searches recorded findings:

- **`ProcessReceipt` has no time-based retry** — only re-runs on the
  next purchase or rejoin. Idempotency via a
  `(playerId, productId, purchaseId)` ledger is the canonical pattern.
- **`UserOwnsGamePassAsync` caches stale data** after mid-session
  purchases (long-standing Roblox bug; still open as of Dec 2025).
  → ADR-006 documents the workaround: local per-session ownership
  cache, authoritative via `PromptGamePassPurchaseFinished`.
- **Never process purchases via `PromptProductPurchaseFinished`** —
  always use the `ProcessReceipt` callback.
- **Battle pass standard:** 30 tiers, free + premium tracks,
  XP-driven. Roblox now ships a "Season passes package" feature kit
  but for V1 we hand-roll for control; may swap to platform kit in V1.5.

---

## D1 — Game Pass infrastructure ✅

**Date:** 2026-05-04
**Branch:** `claude/review-claude-docs-LiZZS`

### Architectural decision (logged before code)

**ADR-006** — Local per-session ownership cache; trust
`PromptGamePassPurchaseFinished(wasPurchased=true)` over re-querying
`UserOwnsGamePassAsync` for mid-session purchases. Cache is primed
once per pass on player join via `UserOwnsGamePassAsync` (the only
time we trust the API).

### What was built

- **`Constants.MONETIZATION`** — new section with two tables:
  - `GamePasses`: DoubleCredits (199 R$), AutoCollect (299 R$),
    VipOperator (499 R$). Each entry has `key`, placeholder
    `id = 0`, `displayName`, `description`, `priceRobux`. Comments
    mark `-- REPLACE_BEFORE_LAUNCH` per the protocol's real-money-
    flow escalation rule.
  - `DevProducts`: EmergencyShield (49 R$), CreditPackSmall (99 R$),
    CreditPackLarge (499 R$), CorePack (199 R$). Each entry stores
    its grant amount (`grantCredits` / `grantCores`) for D2's
    ProcessReceipt path.
- **`Monetization/GamePassService.luau`** — single chokepoint for
  ownership queries. Public API: `Owns(player, passKey)`,
  `Prompt(player, passKey)`, `OnOwnershipChanged: RBXScriptSignal`,
  `Init`. Per ADR-006:
  - On `PlayerAdded`: prime cache via `UserOwnsGamePassAsync` (one
    call per pass; pcall-wrapped; defaults to `false` on failure).
  - On `MarketplaceService.PromptGamePassPurchaseFinished` with
    `wasPurchased=true`: set cache to `true` directly, skipping the
    stale `UserOwnsGamePassAsync` re-query. Fires
    `OnOwnershipChanged` so D3's `PassEffects` can react.
  - On `PlayerRemoving`: clears the per-player ownership map.
  - Placeholder IDs (`0`) short-circuit to "not owned"; `Prompt`
    warns and refuses if the pass has a placeholder ID.
- **`Monetization/MonetizationService.luau`** — top-level
  orchestrator. Currently just calls `GamePassService.Init()`;
  D2–D5 add `DevProductService`, `PassEffects`, `BattlePassService`
  in init order here so the monetization stack's internal
  dependencies stay inside one module.
- **`init.server.luau`** — wired `MonetizationService.Init()` last
  in the chain (after `OfflineProgression.Init()`).

### Audit (D1-scope, sandbox-side)

- 40 `.luau` files — `--!strict` on all
- `stylua --check` clean
- `rojo build` produces a `.rbxl` with the new tree
- `Constants.MONETIZATION.GamePasses` ID = 0 across all entries
  (verified — no real IDs accidentally hard-coded yet)

### Audit (D1-scope, Studio-side — pending your local run)

After F5:

1. **Boot output** is silent on monetization — no errors, no warns
   (placeholder IDs short-circuit cleanly).
2. **Owns() returns false for all passes by default** — verify in
   Server Command Bar:
   ```luau
   local GP = require(game.ServerScriptService.Server.Modules.Monetization.GamePassService)
   local p = game.Players:GetPlayers()[1]
   for _, key in {"DoubleCredits", "AutoCollect", "VipOperator"} do
       print(key, GP.Owns(p, key))
   end
   ```
   All three should return `false`.
3. **OnOwnershipChanged fires when the cache flips** — manually
   trigger via Command Bar (simulating ADR-006's authoritative path
   without needing real IDs):
   ```luau
   local GP = require(game.ServerScriptService.Server.Modules.Monetization.GamePassService)
   GP.OnOwnershipChanged:Connect(print)
   -- Currently no public setter; Phase D3 will wire PassEffects to
   -- this. The signal is exercised by the real
   -- PromptGamePassPurchaseFinished path once IDs are populated.
   ```
4. **Prompt warns on placeholder IDs**:
   ```luau
   GP.Prompt(p, "DoubleCredits")
   -- expect: warn "Pass DoubleCredits has placeholder ID — REPLACE_BEFORE_LAUNCH"
   ```

### Tech debt / deferred

- **Real Pass IDs** — placeholders (0) until Phase H. Replacing them
  is a single-line edit per pass in `Constants.MONETIZATION`; per
  protocol, that change escalates to human approval before merge.
- **`OnOwnershipChanged` has no current subscribers** — D3 wires
  `PassEffects`. Until then, the signal exists but fires into the
  void.
- **No client-side pass display.** D5 builds the pass panel that
  reads catalog from `Constants.MONETIZATION.GamePasses` (will need
  to either move to shared, or expose via a Remote — D5 decision).
- **No mid-session ownership-loss handling.** Roblox doesn't refund
  passes mid-session, but in theory a moderator action could revoke.
  Our cache stays "owned" until rejoin in that case. Acceptable; F1
  may add a defensive periodic re-check.

### What's next

D2 — Developer Product infrastructure.
**`Monetization/PurchaseLedger.luau`** + `Monetization/DevProductService.luau`
+ `MarketplaceService.ProcessReceipt` callback. The ledger keys on
`(playerId, productId, purchaseId)` and lives on
`profile.Data.purchaseHistory: { [purchaseId]: true }` so it
round-trips through DataStore. Idempotency is the audit gate.

---

## D2 — Dev Product infrastructure + PurchaseLedger ✅

**Date:** 2026-05-04
**Branch:** `claude/review-claude-docs-LiZZS`

### What was built

- **`ProfileSchema.luau`** — `purchaseHistory: { [string]: boolean }`
  field. Keys are Roblox-issued `PurchaseId` strings; values always
  `true`. Additive; older saves get `{}` from defaults via Reconcile.
- **`Monetization/PurchaseLedger.luau`** — thin façade over
  `profile.Data.purchaseHistory`. Public API: `HasPurchase`,
  `RecordPurchase`. Defensive nil-fill on read in case Reconcile
  hasn't run.
- **`Monetization/DevProductService.luau`** — sets
  `MarketplaceService.ProcessReceipt` (the **only** registered
  callback per Roblox's "set once" rule). Receipt flow:
  1. Resolve player from `receipt.PlayerId`. Not in this server →
     `NotProcessedYet` (Roblox retries on next join).
  2. `WaitForData` so the profile + ledger are ready.
  3. **Idempotency check**: `PurchaseLedger.HasPurchase` →
     `PurchaseGranted` if already seen.
  4. Resolve product key from `receipt.ProductId` via
     `Constants.MONETIZATION.DevProducts`. Unknown ID →
     `NotProcessedYet` (deployment drift; Roblox retries).
  5. Apply effect (`grantCredits` + `grantCores`). If no effect
     wired (e.g., Emergency Shield, deferred to Phase E) →
     `NotProcessedYet` so Roblox keeps retrying until we ship.
  6. `PurchaseLedger.RecordPurchase(purchaseId)` only after
     successful apply.
  7. Return `PurchaseGranted`.
- **`MonetizationService.luau`** — wired `DevProductService.Init()`
  after `GamePassService.Init()`.

### Crash safety / atomicity

The grant (`CurrencyService.Add`) and the ledger record live in
the same `profile.Data` table. ProfileStore's auto-save flushes
them together on a single DataStore write. If the server crashes
between grant and flush, **both** revert; the next ProcessReceipt
retry re-grants from a clean slate, producing the correct net
effect (player gets the purchase exactly once).

### Audit (D2-scope, sandbox-side)

- 42 `.luau` files — `--!strict` on all
- `stylua --check` clean
- `rojo build` produces a `.rbxl` with the new tree
- ProfileSchema's `DEFAULT_DATA.purchaseHistory = {}` round-trips
  through Reconcile (verified by code reading)

### Audit (D2-scope, Studio-side — pending your local run)

Live ProcessReceipt requires real product IDs (Phase H), but the
idempotency path can be exercised manually:

```luau
-- Server Command Bar:
local DPS = require(game.ServerScriptService.Server.Modules.Monetization.DevProductService)
local p = game.Players:GetPlayers()[1]

-- Synthesize a receipt with a fake PurchaseId. ProductId 0 → falls
-- through to "unknown product" path; that's expected for placeholder
-- IDs. To exercise the granted path, temporarily set a real ProductId
-- in Constants and a fake one matching here:
local fakeReceipt = {
    PlayerId      = p.UserId,
    ProductId     = 0,                      -- match a Constants entry
    PurchaseId    = "test-receipt-001",
    PlaceIdWherePurchased = game.PlaceId,
    CurrencySpent = 99,
    CurrencyType  = Enum.CurrencyType.Robux,
}

print(DPS.ProcessReceipt(fakeReceipt))   -- expect: NotProcessedYet (unknown product 0)
print(DPS.ProcessReceipt(fakeReceipt))   -- same; not idempotent yet because not granted

-- Idempotency exercise (after temporarily wiring a real product
-- match):
print(DPS.ProcessReceipt(fakeReceipt))   -- → PurchaseGranted, applies effect
print(DPS.ProcessReceipt(fakeReceipt))   -- → PurchaseGranted (idempotent skip; no double-grant)
-- Verify in Output: "[DevProductService] Idempotent skip: <Name> already had purchase test-receipt-001"
```

The full audit gate is **two ProcessReceipt invocations with the
same PurchaseId result in exactly one grant** — observable via
HUD credits delta.

### Tech debt / deferred

- **Real Product IDs at Phase H.** Single-line edit per product in
  `Constants.MONETIZATION.DevProducts`. Protocol-escalates.
- **Emergency Shield effect** is deferred to Phase E (raid system
  needs to exist for "raid immunity timer" to mean anything). Until
  then, ProcessReceipt for that product returns `NotProcessedYet`
  and Roblox keeps retrying — **acceptable** because we'd rather
  hold a real-money receipt open than burn it on a non-existent
  effect. **Important**: don't ship Emergency Shield to prod
  before Phase E lands or every purchase will retry indefinitely.
  Tracked.
- **No history pruning.** Lifetime purchases accumulate. Heavy
  spender at 1,000 lifetime purchases ≈ 50KB; well under the 4MB
  DataStore limit. Phase F+ may prune entries past Roblox's ~13-
  month refund window.
- **No client-side purchase confirmation UI.** The default Roblox
  prompt closes after purchase. D5 may add an in-game "Thanks"
  toast that listens for an effect-applied event.

### What's next

D3 — pass effects wired. With Auto-Collect locked at +50%
(Option B from the Phase D kickoff Q), `PassEffects.luau` will
subscribe to `GamePassService.OnOwnershipChanged` and call
`CurrencyService.SetMultiplier` with the multiplicative composition:
`product(passes the player owns) * passOwnership[key].multiplier`.
DoubleCredits (×2.0) + AutoCollect (×1.5) → ×3.0 stack. VIP
Operator's effects (cosmetic skin, +1 quest slot, blueprints)
land alongside.

---

## D3 — Pass effects wired ✅

**Date:** 2026-05-04
**Branch:** `claude/review-claude-docs-LiZZS`

### Decision applied

Auto-Collect locked at **+50% income while online** (Option B from
the Phase D kickoff Q). Composes multiplicatively with 2× Credits:
both passes owned → `2.0 × 1.5 = 3.0` total multiplier on the
`CurrencyService` tick. `CurrencyService.SetMultiplier` clamps to
(0, 10] defensively so even a future bug-stacked 6-pass combo
can't push us past the cap.

### What was built

- **`Constants.MONETIZATION.GamePasses`** — added `multiplier`
  field on `DoubleCredits` (2.0) and `AutoCollect` (1.5). VIP
  Operator has no multiplier (its effect is the +1 quest slot,
  handled in `DailyQuestManager` directly).
- **`Monetization/PassEffects.luau`** — single chokepoint for
  income-multiplier composition. Subscribes to
  `GamePassService.OnOwnershipChanged`; on every flip,
  `RecomputeFor(player)` walks the GamePasses table, multiplies
  in any owned pass's `multiplier`, and writes via
  `CurrencyService.SetMultiplier`. Initial prime on join fires
  once per pass (3 events for V1) — each triggers a recompute,
  trivially cheap. Defensive seed loop for already-present
  players covers Studio script-reload during dev.
- **`MonetizationService.Init`** — wires `PassEffects.Init()`
  after `GamePassService.Init()` so the subscription is in place
  before the first prime fires.
- **`ProfileSchema.QuestProgress`** — added optional
  `vipOnly: boolean?`. Additive; older entries default
  not-vipOnly. Documented in `DATA_SCHEMA.md`.
- **`Retention/DailyQuestManager.luau`** — refactored from 3 to 4
  rolls per day. The 4th-rolled quest is flagged `vipOnly = true`
  at `ensureFreshDay`. `GetState` filters out vipOnly entries
  unless the player owns `VipOperator` (read via
  `GamePassService.Owns`). `TryClaim` enforces the same gate as
  defense-in-depth against a modded client. Subscribes to
  `GamePassService.OnOwnershipChanged` so VIP toggles mid-session
  push fresh state immediately.

### Audit (D3-scope, sandbox-side)

- 43 `.luau` files — `--!strict` on all
- `stylua --check` clean
- `rojo build` produces a `.rbxl` with the new tree
- Multiplier composition cap verified by code inspection: max
  product of declared multipliers is 2.0 × 1.5 = 3.0; well under
  the SetMultiplier clamp ceiling of 10

### Audit (D3-scope, Studio-side — pending your local run)

After F5:

1. **Default state** — no passes owned. CurrencyService multiplier
   is 1.0; income tick produces base rate (1 credit/sec per
   extractor).
2. **Force-grant a pass** in the Server Command Bar (sim-only,
   doesn't actually charge real Robux):
   ```luau
   local GP = require(game.ServerScriptService.Server.Modules.Monetization.GamePassService)
   local CS = require(game.ServerScriptService.Server.Modules.Economy.CurrencyService)
   local p = game.Players:GetPlayers()[1]

   -- Synthesize ownership directly via the OnOwnershipChanged path
   -- (mimics what PromptGamePassPurchaseFinished does):
   -- (Cannot mutate the private cache from here; instead, call the
   --  real internal flow by invoking the private setOwned via a
   --  Studio-only helper. For V1, simplest: temporarily edit
   --  Constants.MONETIZATION.GamePasses.DoubleCredits.id to a real
   --  Pass ID and run the prompt flow. Or test PassEffects directly:)
   local PE = require(game.ServerScriptService.Server.Modules.Monetization.PassEffects)
   PE.RecomputeFor(p)  -- with no passes owned, multiplier = 1.0
   ```
3. **Live prompt test** (requires real Pass IDs in
   `Constants.MONETIZATION` — Phase H):
   - Player owns DoubleCredits → multiplier = 2.0; income visibly
     doubles (1/sec → 2/sec per extractor).
   - Player additionally owns AutoCollect → multiplier = 3.0;
     income triples vs. base (1/sec → 3/sec per extractor).
4. **VIP quest slot test** (requires real VIP ID):
   - Default state: Quests panel shows 3 quest rows.
   - Player buys VIP via prompt → on
     `PromptGamePassPurchaseFinished(true)`,
     `GamePassService.OnOwnershipChanged` fires →
     `DailyQuestManager` re-pushes state → panel auto-refreshes
     to 4 rows.
   - `TryClaim` with the 4th questId before owning VIP returns
     `{ ok = false, error = "VIP Operator required" }`.

### Tech debt / deferred

- **VIP cosmetic effects** (armor skin, drone trail) deferred to
  Phase G — no skin/cosmetic system exists yet. The pass description
  still mentions them; ship-blocking question for Phase G/H.
- **VIP-only blueprints** in the shop (per brainstorm §2.7)
  deferred. Will land in Phase E or G with a `vipOnly` flag on
  blueprint catalog entries; ShopService.GetState would filter the
  same way DailyQuestManager does.
- **Multiplier doesn't yet apply to the offline-progression grant**
  (C4 OfflineProgression reads raw `incomePerSecond`). Wire when
  a player rejoins and ownership has been primed — could be done
  by reading `multipliers[player]` directly, but currently
  CurrencyService doesn't expose a getter. Add
  `CurrencyService.GetMultiplier` and read in `OfflineProgression`.
  **Tracked**: ship before Phase D closes (D5 worklog) or in F1.

### What's next

D4 — Battle Pass scaffolding. ProfileSchema gets `battlePassXP`,
`battlePassTier`, `battlePassClaimed` (per-tier flags), and
`battlePassPremium`. New module `Monetization/BattlePass/{BattlePassService,BattlePassXP,ClaimService}.luau`.
XP grant rules wire into `QuestObjectives` so quest claims and
raid wins (Phase E) automatically advance battle pass progress.

---

## D4 — Battle Pass scaffolding ✅

**Date:** 2026-05-04
**Branch:** `claude/review-claude-docs-LiZZS`

### Tactical decisions made (surfaced for your audit)

1. **Premium track ships as a GamePass**, not a per-season DevProduct.
   One-time purchase covers all seasons. Simpler V1 implementation;
   lower lifetime revenue per payer than industry-standard per-season
   DevProducts. Framework supports a swap (read profile flag instead
   of `GamePassService.Owns`); revisit at V1.5 if revenue model needs
   to shift.
2. **V1 tier rewards are placeholder Credits/Cores** because the
   cosmetic system isn't built yet (Phase G). **Important:** this
   technically violates the brainstorm §2.7 "cosmetic-only" rule.
   Phase G must replace tier rewards with real cosmetics
   (operator skins, drone trails, nameplate flairs) before launch
   to honor the no-pay-to-win invariant.

### What was built

- **`ProfileSchema`** — added `battlePassXP`, `battlePassTier`,
  `battlePassClaimed: { [string]: BattlePassClaimEntry }`,
  `battlePassSeasonId`. Plus the `BattlePassClaimEntry` type
  (`{ free, premium }`). String tier keys avoid Lua/JSON integer-
  key edge cases on DataStore round-trip. **Premium ownership is
  not a profile field** — read on demand via `GamePassService.Owns`.
- **`Constants.MONETIZATION.GamePasses.BattlePassPremium`** — new
  4th GamePass entry (799 R$, placeholder ID 0).
- **`Constants.BATTLE_PASS`** — new section: `SeasonId = "S1"`,
  `MaxTier = 30`, `XpPerTier = 1000` (linear curve), `XpRewards`
  (event → XP map, currently `quest_claimed = 100`,
  `claim_daily = 25`), `*RewardCreditsPerTier` / `*RewardCoresPerTier`
  formulas for free + premium tracks.
- **`Monetization/BattlePass/BattlePassService.luau`** — the core.
  Public API: `GetState`, `GrantXP`, `TryClaim`, `GetTierReward`,
  `Init`. Lazy season reset on `ensureFreshSeason` (XP/tier/claimed
  wiped when `SeasonId` flips). `tierForXP` derives tier from XP,
  capped at `MaxTier`. State pushes to client on every XP change
  + claim + premium ownership flip.
- **`Monetization/BattlePass/BattlePassXP.luau`** — subscribes
  to `QuestObjectives.OnEmit`. On whitelisted events (`quest_claimed`,
  `claim_daily`), grants XP via `BattlePassService.GrantXP`. Per-event
  amounts read from `Constants.BATTLE_PASS.XpRewards`. Phase E adds
  `raid_won`, `wave_survived`.
- **`Monetization/BattlePass/ClaimService.luau`** — wires the
  `ClaimBattlePassTier` RemoteFunction to `BattlePassService.TryClaim`
  with type checks at the wire boundary.
- **`DailyQuestManager.TryClaim`** — emits `quest_claimed` after
  successful claim so `BattlePassXP` can grant battle pass progress.
- **`MonetizationService.Init`** — wires `BattlePassService.Init`,
  `BattlePassXP.Init`, `BattlePassClaimService.Init` after
  `PassEffects.Init`.
- **Remotes**: `BattlePassState` (Server → Client Event) +
  `ClaimBattlePassTier` (Client → Server RemoteFunction).

### XP-to-tier math (V1 cadence sanity)

At `XpPerTier = 1000` and `quest_claimed = 100` XP per claim,
30 tiers = 30,000 XP. A player who claims all 3 daily quests + the
daily login (3×100 + 25 = 325 XP/day) reaches tier 30 in ~92 days.
Active raid players (Phase E adds `raid_won` XP) and holders of
the +1 quest slot (VIP) close to ~30 days. Tunable in Phase G after
playtest data shows where the curve actually lands.

### Audit (D4-scope, sandbox-side)

- 47 `.luau` files — `--!strict` on all (gained 3 from D4: BattlePass
  service, XP, ClaimService)
- `stylua --check` clean
- `rojo build` produces a `.rbxl` with the new tree
- Composition cap holds: max multiplier (D3) × max tier reward (D4)
  is bounded by the explicit per-tier formulas; no unbounded grant
  paths

### Audit (D4-scope, Studio-side — pending your local run)

After F5, with no real Pass IDs (placeholder 0):

1. **Default state.** `BattlePassState` arrives on join showing
   `xp = 0`, `tier = 0`, `premiumOwned = false`, 30 tier views.
2. **Manual XP grant** in Server Command Bar:
   ```luau
   local BPS = require(game.ServerScriptService.Server.Modules.Monetization.BattlePass.BattlePassService)
   local p = game.Players:GetPlayers()[1]
   BPS.GrantXP(p, 1000)   -- expect tier-up 0 → 1 in Output
   BPS.GrantXP(p, 5000)   -- 6000 XP total → tier 6
   ```
3. **Claim path** (free track):
   ```luau
   print(BPS.TryClaim(p, 1, "free"))   -- ok=true, +100 credits
   print(BPS.TryClaim(p, 1, "free"))   -- already claimed (free)
   print(BPS.TryClaim(p, 7, "free"))   -- tier not yet reached
   print(BPS.TryClaim(p, 1, "premium")) -- "Premium track required"
   ```
4. **Quest claim → BP XP cascade**: claim a daily quest via
   `DailyQuestManager.TryClaim`; verify Output shows
   `[BattlePassService] <Name> tier-up: ...` if the +100 XP crossed
   a 1000-boundary.
5. **Season reset** (manual sim):
   ```luau
   local DM = require(game.ServerScriptService.Server.Modules.Player.DataManager)
   DM.GetData(p).battlePassSeasonId = "S0-old"
   print(BPS.GetState(p))   -- ensureFreshSeason wipes XP/tier/claimed
   ```

### Tech debt / deferred

- **Tier rewards are placeholders** (Phase G replaces with cosmetics).
  **Don't ship to prod** until G lands or it's pay-to-win-ish.
- **Premium-purchase model is GamePass not DevProduct**. V1.5 may
  swap if revenue model needs shifting.
- **No client-side BP panel UI** — D5 builds it. Until then,
  `BattlePassState` pushes into a void on the client.
- **No XP-source attribution.** `GrantXP` doesn't track whether XP
  came from quests, login, or future raids. If Phase G wants
  per-source XP charts, add `event` parameter.
- **No retroactive XP grant on premium purchase.** If a player buys
  premium late in the season, they unlock premium claim on
  already-reached tiers (correct), but they don't get a "make-up"
  XP injection. Standard battle-pass behavior.
- **BattlePassXP doesn't grant XP for `earn_credits` / `play_session`
  / `place_*` events.** Only `quest_claimed` and `claim_daily` are
  whitelisted. This is intentional — XP should reward meaningful
  retention loops, not raw activity. Phase G may add minor weights
  for `play_session` if data shows it boosts engagement.

### What's next

D5 — monetization UI. Pass display panel (extends Shop-style
panel with "Owned" badges), Battle Pass progress bar + tier view,
Cores HUD readout (paired with `CoresChanged` Remote — adds in D5).
Closes Phase D.

---

## D5 — Monetization UI ✅ — closes Phase D

**Date:** 2026-05-04
**Branch:** `claude/review-claude-docs-LiZZS`

### What was built

#### Server (closing the D3 tech debt + new replication paths)

- **`CurrencyService.GetMultiplier(player)`** — public accessor for
  the per-player multiplier (returns 1 on miss). Closes the D3 tech
  debt where `OfflineProgression` couldn't read the value.
- **`OfflineProgression.GrantOnJoin`** — now multiplies `elapsed *
  incomePerSecond * GetMultiplier(player)` so 2× Credits +
  Auto-Collect owners get the same ×3.0 boost on offline grants
  that they get on the live tick.
- **`CurrencyService.AddCores`** — fires the new `CoresChanged`
  Remote on every grant (so the HUD reads live).
- **`CurrencyService.Init`** PlayerAdded — now pushes initial
  `CoresChanged` alongside `CreditsChanged` so the HUD has a
  starting value before any grant fires.
- **`MonetizationService.Init`** — added inline `pushOwnershipState`
  function that builds a `{ [passKey]: boolean }` snapshot via
  `GamePassService.Owns` per pass, fires `Remotes.OwnershipState`
  to the affected client. Subscribes to `GamePassService.OnOwnershipChanged`
  for delta pushes; PlayerAdded primes ~1s after join (lets the
  initial `UserOwnsGamePassAsync` prime cycle complete first).

#### Remotes

- **`CoresChanged`** (Server → Client Event) — companion to
  `CreditsChanged`.
- **`OwnershipState`** (Server → Client Event) — full GamePass
  ownership map per push.

#### Client

- **`HUD/CoresDisplay.luau`** — top-right readout next to
  `CreditsDisplay`. Listens to `CoresChanged`. Same visual style
  with amber stroke (vs. teal Credits) for quick value-type
  distinction.
- **`HUD/HudController`** — wires `CoresDisplay.Init()`.
- **`Shop/GamePassPanel.luau`** — combined pass + product store.
  ScrollingFrame with two sections ("GAME PASSES", "PRODUCTS").
  Iterates `Constants.MONETIZATION.{GamePasses, DevProducts}`.
  GamePass cards show "Owned" (greyed) or "Buy 199 R$" — Buy invokes
  `MarketplaceService:PromptGamePassPurchase`. DevProduct cards
  always show Buy → `PromptProductPurchase`. Listens to
  `OwnershipState` and rebuilds when open.
- **`Shop/BattlePassPanel.luau`** — XP header (progress bar +
  "Tier N / 30 — X / 1000 XP" label) + 30-row scrolling tier list.
  Each row shows tier badge (filled green at-or-below current tier),
  Free + Premium track buttons. Buttons display the reward when
  not yet reached, "Claim {reward}" when claimable, "Claimed"
  when done. Premium gate: button disabled until `state.premiumOwned`.
- **`Shop/MonetizationController.luau`** — adds two HUD toggle
  buttons: "Store" (x=208, teal stroke) → opens `GamePassPanel`;
  "Battle Pass" (x=320, amber stroke) → opens `BattlePassPanel`.
- **`init.client.luau`** — wires `MonetizationController.Init()`
  last in the chain.

### Audit (D5-scope, sandbox-side)

- 51 `.luau` files — `--!strict` on all
- `stylua --check` clean
- `rojo build` produces a `.rbxl` with the new tree

### Audit (D5-scope, Studio-side — pending your local run)

After F5:

1. **Cores HUD readout visible** top-right next to Credits, both
   showing 0 initially.
2. **Grant cores via Command Bar:**
   ```luau
   local CS = require(game.ServerScriptService.Server.Modules.Economy.CurrencyService)
   CS.AddCores(game.Players:GetPlayers()[1], 50)
   ```
   HUD updates to "50 Cores".
3. **Open Store** → 4 GamePass cards + 4 DevProduct cards visible,
   prices shown in R$.
4. **Click Buy** on a GamePass → console warn:
   `[GamePassPanel] DoubleCredits has placeholder ID — REPLACE_BEFORE_LAUNCH`
   (Phase H replaces with real IDs).
5. **Open Battle Pass** → XP bar at 0%, 30 tier rows visible.
   Grant XP via Command Bar:
   ```luau
   local BPS = require(game.ServerScriptService.Server.Modules.Monetization.BattlePass.BattlePassService)
   BPS.GrantXP(game.Players:GetPlayers()[1], 5500)
   ```
   Bar advances; tier 5 + earlier rows turn green; tier 5's Free
   button reads "Claim 500 ¢"; click it → tier reward applied,
   button flips to "Claimed", HUD credits +500.
6. **Premium gate** — Premium buttons remain disabled until
   ownership flips. Cannot test the live flip without real Pass
   IDs (Phase H).
7. **Offline grant + multiplier (D3 tech debt fix)** — manually
   `data.lastJoinAt = os.time() - 600` + set `multipliers[p] = 3.0`
   in CurrencyService → rejoin → "+M Credits" payload should be
   3× what it would have been without the multiplier.

### Tech debt / deferred

- **5 toggle buttons in the top row** (Shop, Quests, Store, Battle
  Pass) plus the Build palette bottom-center are V1 mobile-tight.
  Phase G repositions per device (likely a hamburger menu on
  mobile, expanded row on desktop).
- **No purchase-confirmation toast.** The default Roblox prompt
  closes after success; the client doesn't currently display
  "+50K Credits granted!" feedback. CreditsChanged fires and the
  HUD ticks but there's no narrative beat. F4 / G adds.
- **No icons** in the pass / product / battle-pass cards — all
  text. Phase G with the asset pipeline.
- **BattlePassPanel re-renders on every state push.** With 30 tier
  rows that's a meaningful instance churn on each XP grant. V1 is
  fine (1 push per quest claim ≤ 3-4 times/day per player); F1+
  may diff-patch.

### Phase D status

**All five sub-phases shipped.** Server enforces every gate,
clients render. Phase D audit gate per `10_BUILD_PROTOCOL.md`:
test purchase flow in Studio, verify pass effects apply
immediately + on rejoin, verify duplicate `ProcessReceipt` calls
only credit once. Per-mechanic recipes are in their respective
sub-phase entries above.

**Phase D commits:**
- `982fa11` D1 — Game Pass infrastructure + ADR-006
- `17c144a` D2 — Dev Product infrastructure + idempotent PurchaseLedger
- `a1345b8` D3 — pass effects wired
- `205bbd5` D4 — Battle Pass scaffolding
- `<this commit>` D5 — monetization UI

### What's next

Phase E — Social Layer. Per `finalized-brainstorm.md` §4.6 this is
the **highest-risk phase** (raids + clans + voice chat + leaderboards
+ friends, weeks 7–9). Pre-committed Soft V1 fallback exists per
§3.3 if E slips past Week 12. Research pass at Phase E kickoff:
MessagingService cross-server matchmaking, MemoryStoreService
sentinel patterns, TeleportService:ReserveServer flow, Spatial
Voice 2026 status, OrderedDataStore for leaderboards.
