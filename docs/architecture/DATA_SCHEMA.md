# DATA_SCHEMA.md

> Versioned `PlayerData` schema and migration log. Source of truth for what's
> persisted per player. Read before touching `DataManager` or `ProfileSchema`.

**Status:** Live. v1.0 ships in Phase A2 with the minimum fields needed to
audit round-trip persistence. Subsequent phases add fields freely (additive
changes are safe — `ProfileStore:Reconcile()` merges defaults).

---

## Current schema version

`v1.0` — implemented in `src/server/Modules/Player/ProfileSchema.luau`.

```luau
{
    _version    = 1,             -- schema version, bumped per migration
    credits     = 0,             -- soft currency (Phase B fills the curve)
    cores       = 0,             -- premium currency (Phase D)
    firstJoinAt = nil :: number?, -- os.time() of first profile creation
    lastJoinAt  = nil :: number?, -- os.time() of most recent load
    sessionsPlayed = 0,          -- ++ on every successful LoadPlayer
    baseLayout  = {},            -- persistent placed-buildings list (B3)
    -- Phase C1 — Retention / daily login:
    lastDailyClaim = nil :: string?, -- "YYYY-MM-DD" UTC of last claim
    dailyStreak    = 0,              -- consecutive days claimed (1..N)
    -- Phase C2 — Retention / restocking shop:
    shopRotationSeen     = nil :: number?, -- last rotation index seen
    shopBuysThisRotation = {},             -- { [blueprintId]: true } bought-this-rotation flags
    -- Phase C3 — Retention / daily quests:
    dailyQuests          = {},             -- { [questId]: { progress = 0, claimed = false } }
    lastQuestReset       = nil :: string?, -- "YYYY-MM-DD" UTC of last quest roll
    -- Phase D2 — Monetization / receipt idempotency:
    purchaseHistory      = {},             -- { [purchaseId: string]: true } — keys are Roblox PurchaseIds
    -- Phase E1 — Raid stats:
    raidWins        = 0, -- offensive raids won
    raidLosses      = 0, -- offensive raids lost (incl. mid-round bails)
    raidsDefended   = 0, -- successful defenses (attacker bailed or — once E2 ships — was killed by snapshot defenders)
    raidsRaided     = 0, -- total times this player has been the defender of a raid
}
```

### Raid stat fields (E1)

Counters mutated only by `RaidRewardService` on the home server that
holds the player's profile. The raid server never writes these
directly (ADR-008). E5's weekly leaderboard reads `raidWins` for the
"weekly raid wins" board; the global Credits board uses `credits`.

### `dailyQuests[id].vipOnly` (D3)

The 4th-rolled daily quest each UTC day is flagged `vipOnly = true`
at reset. Non-VIP players don't see this entry in
`DailyQuestManager.GetState`; `TryClaim` rejects with
`"VIP Operator required"` if a modded client tries to claim it
directly. VIP ownership can flip mid-session — `DailyQuestManager`
subscribes to `GamePassService.OnOwnershipChanged` for the
`VipOperator` key and re-pushes state. Older `QuestProgress` entries
without the field default to "not vipOnly" via the standard nil-
check pattern.

### Battle Pass fields (D4)

```luau
battlePassXP        : number              -- accumulated this season
battlePassTier      : number              -- derived from XP (capped at MaxTier)
battlePassClaimed   : { [string]: { free, premium } }   -- key = tostring(tier)
battlePassSeasonId  : string?             -- season-reset detector
```

`BattlePassClaimEntry` is a separate exported type
(`{ free: boolean, premium: boolean }`). String tier keys avoid
Lua/JSON integer-key edge cases on DataStore round-trip.

**Premium ownership is not a profile field** — it lives in Roblox's
GamePass system and is read on demand via
`GamePassService.Owns(player, "BattlePassPremium")`. This makes
premium ownership sticky across season transitions: a player who
bought premium in S1 still has it in S2 without any per-season
profile bookkeeping.

Season transition: when `data.battlePassSeasonId !=
Constants.BATTLE_PASS.SeasonId`, `BattlePassService` lazily
resets `battlePassXP`, `battlePassTier`, and `battlePassClaimed`
on the next `GetState`/`GrantXP`/`TryClaim`. Unclaimed rewards
from the previous season are lost (standard battle-pass behavior;
the social pressure to log in and claim drives retention).

### `purchaseHistory` shape (D2)

Keyed by Roblox-issued `PurchaseId` (string, unique per receipt).
`MarketplaceService.ProcessReceipt` consults this via
`Server.Monetization.PurchaseLedger.HasPurchase` before applying
any product effect; if seen, the callback returns `PurchaseGranted`
without re-granting. This makes Roblox's at-least-once retry
semantics safe.

The history grows monotonically over a player's lifetime. At ~50
chars per UUID-style `PurchaseId`, a heavy spender with 1,000
lifetime purchases adds ~50KB to their save — well under DataStore's
4MB-per-key limit. Pruning entries older than ~13 months (Roblox's
refund window) is a Phase F+ optimization if needed.

The bookkeeping fields (`firstJoinAt`, `lastJoinAt`, `sessionsPlayed`) exist
specifically so the A2 audit can verify a value mutated mid-session
round-trips through DataStore on rejoin.

### `baseLayout` shape (B3)

```luau
type SerializedBuilding = {
    id: string,  -- buildable id from BuildableRegistry
    x: number,   -- snap-grid cell X
    z: number,   -- snap-grid cell Z
}

baseLayout: { SerializedBuilding }
```

Every entry is a single placed building. The list is mutated in place by
`Server.Build.BaseSerializer` (`Append` on placement, `Remove` on
removal, `Clear` on plot wipe). `Server.Build.BuildRestorer` replays the
list on plot allocation by calling `PlacementService.TryPlace` in
**trusted mode** (skips affordability + persistence).

Future shape evolution:
- Adding a field (e.g., `r` for rotation in Phase B4) is **additive** —
  drop the new field with a default in `BuildableRegistry` for entries
  saved before the field existed.
- Renaming `id` / `x` / `z` requires a migration.

## Migration log

| From | To | Reason | Migrator | Audited |
|---|---|---|---|---|
| (none yet) | | | | |

---

## Field add/remove protocol

- **Adding a field:** safe. Default it in `ProfileSchema.DEFAULT_DATA`, no
  migration needed. Older saves auto-fill on next `LoadPlayer` via
  `ProfileStore:Reconcile()`.
- **Removing a field:** soft-deprecate first (stop writing, leave reads
  ignoring). Hard-remove in a versioned migration once the deprecation has
  shipped.
- **Renaming a field:** never rename in place. Add new, dual-write for one
  release, migrate old saves, drop old in next release.
- **Type-changing a field:** versioned migration only.

Per `10_BUILD_PROTOCOL.md`: any rename / remove / retype after Phase A
escalates to human approval before merging.

## How migrations run

1. `ProfileStore:StartSessionAsync` returns a profile.
2. `profile:Reconcile()` merges any new template defaults — handles
   *additive* schema changes invisibly.
3. `ProfileSchema.Migrate(profile.Data)` walks the `MIGRATIONS` table from
   `_version` up to `CURRENT_SCHEMA_VERSION` — handles *structural* schema
   changes (renames, removes, retypes).
4. `_version` is stamped to current.

Migrations run lazily on first load after a schema bump. There is **no**
batch sweep — players who never log in stay on their old version until they do.
