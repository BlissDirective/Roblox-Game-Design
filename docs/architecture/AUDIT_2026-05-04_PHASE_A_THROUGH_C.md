# Audit — Phases A1 through C4

> Comprehensive cross-cutting audit run on **2026-05-04**, immediately
> after Phase C closed (commit `bd4ae7c`). Scope: every commit on
> `claude/review-claude-docs-LiZZS` except the two infrastructure
> commits that pre-existed Phase A.

**Bottom line:** the codebase is structurally healthy. Two real
findings, both doc-drift; no code bugs; one latent runtime bug already
surfaced and fixed during Phase C3 work. All static checks pass.

---

## 1. Inventory

| Metric | Value |
|---|---|
| Phase commits | 9 (`A1` → `C4`) |
| Infra commits on branch | 2 (CI fix, `wally.lock`) |
| `.luau` files in `src/` | **38** |
| Server modules | 16 |
| Client modules | 14 |
| Shared modules | 8 |
| Lines of Luau (incl. blanks/comments) | ~5,143 |
| Built `.rbxl` size | 93 KB |

### Phase commits in chronological order

| Phase | SHA | Title |
|---|---|---|
| A1 | `f3c685c` | rojo scaffolding + bootstraps + doc skeletons |
| A2 | `fab0c9f` | DataManager + ProfileSchema (ProfileStore-backed) |
| A3 | `4bdac8c` | shared scaffolds — Constants, Types, Remotes, Enums |
| A4 | `be3de51` | bootstrap wiring + audit harness + Phase A checklist |
| B1 | `80bedb4` | world scaffold + node spawner + placement Remote |
| B2 | `389eacc` | currency tick + extractor income + CreditsChanged |
| B3 | `67abbe1` | persistent base state — BaseSerializer + BuildRestorer |
| B4 | `cf84a34` | build mode UI — palette, ghost preview, credits HUD |
| B5 | `ebb7491` | TP↔FP camera transition + mode state machine |
| C1 | `94faf80` | daily login bonus + 7-day streak |
| C2 | `8e63afc` | restocking blueprint shop |
| C3 | `29ac845` | daily quests + cross-service event bus |
| C4 | `bd4ae7c` | offline progression — closes Phase C |

---

## 2. Findings

### 🟢 Healthy

| Check | Result |
|---|---|
| `--!strict` on every `.luau` (38/38) | ✅ |
| `stylua --check` across `src/` + `tests/` | ✅ exit 0 |
| `rojo build` | ✅ produces 93 KB `.rbxl` |
| `default.project.json` | ✅ valid JSON |
| `wally.lock` committed | ✅ pinned `lm-loleris/profilestore@1.0.3` |
| Module headers — only `--!strict`, no `--!nonstrict` / `--!nocheck` slipped in | ✅ |
| No `TODO` / `FIXME` / `HACK` markers — tech debt is captured in worklogs instead | ✅ |
| `warn()` calls — all 4 are intentional (multiplier clamp, restoration failure, mode validation, type docstring) | ✅ |

### Trust boundary

Every Client → Server Remote has a server-side handler that validates
inputs:

| Remote | Direction | Handler | Validation |
|---|---|---|---|
| `PlaceBuilding` | C → S | `PlacementService.onRemote` | `typeof` + integer cells + sanity bounds + 5-step `TryPlace` chain |
| `ClaimDailyReward` | C → S (Function) | `DailyLoginManager.OnServerInvoke` | server-side `os.time()`; "already claimed today" via `lastDailyClaim` field; client never sends a date |
| `BuyShopItem` | C → S (Function) | `ShopService.OnServerInvoke` | `typeof` + valid blueprint id + in-stock + not-already-bought + `CurrencyService.TrySpend` |
| `ClaimQuest` | C → S (Function) | `DailyQuestManager.OnServerInvoke` | `typeof` + quest in today's set + objective met + not-already-claimed |

Server → Client Remotes (`CreditsChanged`, `DailyLoginState`,
`ShopState`, `DailyQuestState`, `WelcomeBack`) are notification-only;
clients render but never accept them as source of truth.

### Schema consistency

```
ProfileSchema field           Consumer count
─────────────────────────────────────────────
credits                       10 usages
cores                          2 usages   (AddCores/GetCores)
firstJoinAt                    2 usages
lastJoinAt                     2 usages
sessionsPlayed                 3 usages
baseLayout                     3 usages
lastDailyClaim                 4 usages
dailyStreak                    6 usages
shopRotationSeen               2 usages
shopBuysThisRotation           4 usages
dailyQuests                    4 usages
lastQuestReset                 2 usages
```

Every declared field has callers — no dead fields.

### Remotes alignment

```
Registered in Remotes.luau:    9
Server-side reference count:   9 (matches)
Client-side reference count:   9 (matches)
Documented in REMOTES_REGISTRY: 9 rows
```

Perfect alignment between code and registry doc.

### Init ordering

Server bootstrap (`init.server.luau`) runs in this order, all reasoned:

1. `ServerAuthorityBootstrap.Apply` — must precede anything reading
   Workspace auth properties
2. `DataManager.Init` — persistence first; everything below depends
   on profile being loadable
3. `PlotManager.Init` — world structure must exist before
4. `ResourceNodeSpawner.Init` — node placement (depends on plots)
5. `CurrencyService.Init` — currency tick must be live before
6. `PlacementService.Init` — placement Remote (depends on currency
   for affordability)
7. `BuildRestorer.Init` — restoration listener (depends on
   PlacementService + PlotManager)
8. `DailyLoginManager.Init` — independent retention path
9. `ShopService.Init` — independent retention path
10. `DailyQuestManager.Init` — subscribes to `QuestObjectives`
    (which is passive, no init needed)
11. `OfflineProgression.Init` — **must** be after `BuildRestorer.Init`
    so the `OnRestoreComplete` subscription is in place before the
    first player's restore fires

Client bootstrap order is similarly correct: HUD →
Camera/Input/Mode → Build → Retention popups → Shop → Quests →
WelcomeBack.

### Resource cleanup on `PlayerRemoving`

| Module | Per-player state | Cleanup |
|---|---|---|
| `DataManager` | `profiles[player]`, `loadedSignals[player]`, `intentionalEnd[player]`, `sessionMeta[player]` | ✅ all four cleaned |
| `CurrencyService` | `extractorsByPlayer[player]`, `multipliers[player]` | ✅ both cleaned |
| `PlacementService` | `occupancy[plotId]` (keyed by plot, not player) | ✅ wiped via PlotManager.release; next allocation starts clean |
| `PlotManager` | `playerToPlot[player]`, `pendingAllocations[player]`, `player.PlotId` attribute, `player.RespawnLocation` | ✅ all cleaned via `release` |
| `DailyLoginManager` | None (state lives in `profile.Data`) | n/a |
| `ShopService` | None (state lives in `profile.Data`; `stockCache` is global) | n/a |
| `DailyQuestManager` | None (state lives in `profile.Data`) | n/a |
| `OfflineProgression` | None (stateless) | n/a |

No leaks identified.

### Cross-module dependency hygiene

- No circular requires (verified by tracing every `script.Parent.*`).
- Refactor cleanups are complete: the B4 `BuildableRegistry` move
  (server → shared) is fully reflected in callers, including the
  CurrencyService import which was found stale during C3 and fixed
  in the same commit.
- `QuestObjectives` event bus correctly decouples emitters
  (PlacementService, CurrencyService, ShopService, DailyLoginManager)
  from `DailyQuestManager`, preventing cycles.

### ADR trail

All five ADRs have proper supersession links:

| ADR | Title | Status |
|---|---|---|
| 001 | Hand-rolled DataStore wrapper, not ProfileService | ⛔ Superseded by ADR-003 |
| 002 | Feature flags > long-lived feature branches | ✅ Accepted |
| 003 | Adopt ProfileStore (Wally) as DataStore wrapper | ✅ Accepted; supersedes 001 |
| 004 | Defer Server Authority Beta to V1.5/V2 | ⛔ Superseded by ADR-005 same-day |
| 005 | Adopt Server Authority Beta for V1 | ✅ Accepted; supersedes 004 |

---

### 🟠 Findings — fixed by this audit

#### F-1 · CHANGELOG.md was stale

`[Unreleased]` listed only Phase A entries (A1–A4); missing all of
Phase B (B1–B5) and Phase C (C1–C4) — **9 missing entries**, plus
the `wally.lock` and CI-fix infrastructure commits. The `Deferred`
list also still mentioned items that had since shipped (`wally.lock`)
or been redirected (`PlayerSession`/`PlayerJoined`/`PlayerLeaving` no
longer needed given pub-sub adoption).

**Fixed in this audit's commit.** Updated to include all 9 phase
entries with linked SHAs, the 2 infrastructure commits, and an
explicit `Deferred` list re-grouped by future phase (D / E / F / G).

---

### 🟡 Tech debt — captured, deferred to specific later phases

This list reconciles the per-phase worklogs into one inventory.

**Phase D dependencies** (Monetization, expected next):
- Cores HUD readout + `CoresChanged` Remote (server-side `AddCores`
  works; no client display yet)
- 2× Credits pass multiplier doesn't yet apply to offline grant —
  `OfflineProgression.GrantOnJoin` reads `incomePerSecond`, not the
  multiplier. Wire when `GamePassService.SetMultiplier` lands

**Phase E dependencies** (Social Layer / raids / waves):
- Combat / raid quest events (`survive_wave`, `raid_won`,
  `raid_attended`) and matching quest pool entries
- Wave damage during offline (V1 assumes bases survive offline)
- PvP raid rate-limiting strategy

**Phase F dependencies** (Anti-exploit + FTUE):
- `AntiExploit.RateCheck` for all Remotes (currently each Remote
  enforces semantic limits — `lastDailyClaim == today` blocks daily-
  claim spam, etc. — but no per-Remote per-second token-bucket)
- Server-side reach raycast for placement (the B1 placeholder is
  still in place — comment in `PlacementService.luau` line 151)
- `PlacementResult` Remote for failed-placement toasts (currently
  silent)
- Server-enforced client mode (modded client can send
  `PlaceBuilding` while in Combat — no exploit since validation
  still passes, but the wire isn't symmetric)
- `play_session` quest progress persistence within the day (resets
  on rejoin — a player joining once for 14 minutes can't bank
  partial progress)
- `CreditsLedger` audit log
- Client-side advisory validation in `PlacementPreview` duplicates
  server logic (drift risk; possible unification via shared
  `PlacementValidator`)
- Popup ordering when Daily Login + Welcome Back both fire on join

**Phase G dependencies** (Aesthetic):
- Visuals are debug-grade across the entire UI stack
- Live countdown ticks on shop / quests panels
- Spring tweens, animations, audio
- Mobile UX collisions (Shop / Quests buttons collide with default
  Roblox mobile chat / control pad on some devices — repositioning
  needed per-device)
- Quest pool expansion (10 → 30 per brainstorm §2.4)
- Quest icons / category tags (Build / Defend / Raid)
- Rarity-driven shop item value tuning

**Phase H dependencies** (Ship Prep):
- `AssetIds.luau` manifest (lands with first first-party asset)
- `tools/scripts/*.sh` (build/lint/format/upload scripts)

---

### 🔴 Bugs

**No latent bugs found in this audit.**

The B4-era `BuildableRegistry` import path bug (CurrencyService still
referenced the pre-B4 server-side location, which would have failed
at first runtime use of `CurrencyService.RegisterExtractor` in
Studio) was already surfaced and fixed in commit `29ac845` (C3).

---

## 3. Studio audits still pending

| Phase | Audit gate | Recipe location |
|---|---|---|
| **A** | DataStore round-trip + `BindToClose` flush | `PHASE_A_FOUNDATION.md` §A4 |
| **B** | Two-client playtest of full build loop + B5 camera feel-test (go/no-go) | `PHASE_B_CORE_LOOP.md` §B4 + §B5 |
| **C** | Time-shift verification across daily login / quests / shop / offline | `PHASE_C_RETENTION.md` per sub-phase |

These all run on the user's local Studio install. Results should
land back in this repo as audit-pass / audit-fail entries appended
to the corresponding phase worklog.

---

## 4. Risks heading into Phase D

1. **Real money flows.** Phase D (`MarketplaceService`,
   `ProcessReceipt`) is the highest-stakes area in V1. ADR rules
   from `10_BUILD_PROTOCOL.md` apply: any change to Game Pass IDs,
   Dev Product IDs, prices, or `ProcessReceipt` logic escalates to
   human approval. `PurchaseLedger` for receipt idempotency is the
   single most important deliverable.
2. **Anti-exploit gap.** Phase F1 hardens. Until then, Phase D ships
   with semantic per-Remote limits but no token-bucket layer. A
   determined exploiter can spam pass-purchase prompts (Roblox
   itself rate-limits client→Roblox), but every successful purchase
   still routes through `ProcessReceipt`'s ledger so duplicate-grant
   isn't possible.
3. **Beta API churn (ADR-005).** Server Authority Beta is opt-in;
   if Roblox renames `Workspace.UseFixedSimulation` etc. between
   now and ship, `ServerAuthorityBootstrap` will log skipped
   properties and the server keeps running on the manual pattern.
   Acceptable.

---

## 5. Recommended next actions

1. **Run the deferred Studio audits** for Phases A / B / C on your
   local install. The full recipe lives in each
   `docs/phases/PHASE_*.md` file. Findings get appended to that
   file under a new `Audit run` section.
2. **Open a PR** to squash-merge the entire branch into `main`. The
   13 phase commits + 2 infrastructure commits compress into one
   "Phases A–C: foundation, build loop, retention" commit. Clean
   `main` history simplifies future cherry-picks.
3. **Kick off Phase D** (Monetization). Per the protocol, do the
   phase-level research pass first — particularly around 2026
   `MarketplaceService` API status and `ProcessReceipt` idempotency
   patterns.

---

**End of audit.**
