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

## D3 — Pass effects wired ⏳

_Pending. Awaiting your decision on Auto-Collect's V1 effect (A / B / C
options surfaced at Phase D kickoff)._

## D4 — Battle Pass scaffolding ⏳

_Pending._

## D5 — Monetization UI ⏳

_Pending._
