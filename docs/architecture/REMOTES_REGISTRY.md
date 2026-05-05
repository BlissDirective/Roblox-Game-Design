# REMOTES_REGISTRY.md

> Every `RemoteEvent` and `RemoteFunction` exposed by the server. Each row
> lives in `src/shared/Remotes.luau`; this doc records the **trust model** and
> **rate limit** so the table stays auditable.

**Status:** Stub. Phase A3 sets up the typed registry; subsequent phases append
rows as Remotes are introduced.

---

## Registry

| Remote | Direction | Args (validated server-side) | Rate limit (per player) | Phase introduced | Notes |
|---|---|---|---|---|---|
| `PlaceBuilding` | Client → Server (Event) | `(buildableId: string, cellX: integer, cellZ: integer)` — buildableId must exist in BuildableRegistry; cells must fall in player's plot bounds | `RATE_LIMITS.Placement` (60/sec — placement bursts during build mode) | B1 | Server validates plot allocation, buildable id, cell bounds, occupancy, node requirement (extractor only). Affordability via `CurrencyService.TrySpend` since B2. Reach raycast deferred to F1. No paired result event yet — failures are silent. B4 may add a `PlacementResult` event for UI feedback. |
| `CreditsChanged` | Server → Client (Event) | `(newCredits: number)` — fired only to the affected client | n/a (server-driven) | B2 | Notification only — clients use it to refresh HUD display. Server is the source of truth (`DataManager.GetData(player).credits`). Fires from `CurrencyService` on income tick, `TrySpend`, `Add`, and on initial profile load. |
| `CoresChanged` | Server → Client (Event) | `(newCores: number)` — fired only to the affected client | n/a (server-driven) | D5 | Same shape and contract as `CreditsChanged`. Fires from `CurrencyService.AddCores` (quest claims, BP tier claims, Core Pack purchases). Initial value pushed on join from `CurrencyService.Init`'s PlayerAdded handler. |
| `DailyLoginState` | Server → Client (Event) | `(state: DailyLoginManager.State)` — fired only to the affected client | n/a (server-driven) | C1 | Push of current claim eligibility + streak + reward. Client renders the popup off this. Fires on join (after profile load) and after every successful claim. |
| `ClaimDailyReward` | Client → Server (Function) | `()` | `RATE_LIMITS.Default` (server-side `os.time` makes per-Remote rate limiting redundant — at most one successful claim per UTC day) | C1 | Server validates with `os.time()` only — clients never send a date, so system-clock manipulation can't unlock extra claims. Returns `DailyLoginManager.ClaimResult` (`ok = true, reward, day` or `ok = false, error`). |
| `ShopState` | Server → Client (Event) | `(state: ShopService.State)` — fired only to the affected client | n/a (server-driven) | C2 | Push of current 6h rotation + 3 item slots + per-player `bought` flags + `secondsUntilRestock`. Fires on join (after profile load), after every successful BuyShopItem, and on rotation boundary crossings (server-side polled once per minute). |
| `BuyShopItem` | Client → Server (Function) | `(blueprintId: string)` | `RATE_LIMITS.Default` (further gated by per-rotation per-item one-shot enforcement) | C2 | Server validates: blueprint id exists, item is in current rotation's stock, not already bought this rotation, affordable via `CurrencyService.TrySpend`. Returns `ShopService.BuyResult`. |
| `DailyQuestState` | Server → Client (Event) | `(state: DailyQuestManager.State)` — fired only to the affected client | n/a (server-driven) | C3 | Push of today's 3 active quests + per-quest progress + claim flags + `secondsUntilReset`. Fires on join, on every quest progress advance, after every successful ClaimQuest, and on UTC day rollovers. |
| `ClaimQuest` | Client → Server (Function) | `(questId: string)` | `RATE_LIMITS.Default` (further gated by per-quest one-shot — already-claimed quests reject) | C3 | Server validates: quest id is in today's set, objective.target met, not already claimed. Grants Credits + Cores via `CurrencyService.Add` + `CurrencyService.AddCores`. Returns `DailyQuestManager.ClaimResult`. |
| `WelcomeBack` | Server → Client (Event) | `(payload: OfflineProgression.WelcomeBack)` — fired only to the affected client | n/a (server-driven) | C4 | One-shot per join when offline progression accrued any Credits. Skipped silently for new players or players with no extractors. Fired after BuildRestorer.OnRestoreComplete so the income calc can read newly-registered extractors. |
| `BattlePassState` | Server → Client (Event) | `(state: BattlePassService.State)` — fired only to the affected client | n/a (server-driven) | D4 | Push of seasonId, current XP, derived tier, premium-owned flag, and per-tier claim view (30 entries). Fired on join, on every GrantXP, after every successful ClaimBattlePassTier, and when premium ownership flips. |
| `ClaimBattlePassTier` | Client → Server (Function) | `(tier: number, track: "free" \| "premium")` | `RATE_LIMITS.Default` (further gated by per-tier-per-track one-shot) | D4 | Server validates: tier in `[1, MaxTier]`, tier ≤ player's current tier, premium track requires `BattlePassPremium` GamePass ownership, not-already-claimed for this `(tier, track)` pair. Returns `BattlePassService.ClaimResult`. |
| `OwnershipState` | Server → Client (Event) | `(ownership: { [passKey: string]: boolean })` — fired only to the affected client | n/a (server-driven) | D5 | Server-replicated GamePass ownership map for the pass shop's "Owned" badges. Avoids the `UserOwnsGamePassAsync` staleness bug per ADR-006 — server's local cache is the source of truth, and `MonetizationService` rebuilds the map from `GamePassService.Owns` per pass on every flip. Push initial state ~1s after join (lets the prime cycle complete) + on every `OnOwnershipChanged`. |

---

## Conventions

- Every inbound (Client → Server) Remote passes through
  `Security.AntiExploit:RateCheck` + `Security.RemoteValidator` before any
  game-state mutation.
- Default rate limit: **10 calls/sec/player**. Per-Remote overrides live in
  `Constants.RATE_LIMITS` and are documented in this table.
- Outbound (Server → Client) Remotes are notification-only. Clients never trust
  outbound payloads as sources of truth — they're display hints.
- Adding a Remote: add row here in the same PR that adds the registry entry,
  or CI fails the docs check.
