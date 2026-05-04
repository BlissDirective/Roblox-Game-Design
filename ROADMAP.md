# Outpost-7 — Roadmap

> Source of truth: `docs/finalized-brainstorm.md` §2.8 (V1 must-haves) and §2.9 (V1.5 / V2 deferred).
> This file is the human-readable mirror. Update when scope shifts.

---

## V1.0 — Ship target

The minimum lovable game. Everything below must be live before public launch.

### Phase A — Foundation
- [ ] A1: Project scaffolding (this commit)
- [ ] A2: DataStore + ProfileSchema (versioned saves, retry, BindToClose)
- [ ] A3: Shared scaffolds (Remotes, Constants, Types, Enums)
- [ ] A4: Bootstrap wiring + boot health check

### Phase B — Core loop (build + collect)
- [ ] B1: World generation — biome, plot, resource nodes
- [ ] B2: Currency tick + multipliers
- [ ] B3: Server-validated placement
- [ ] B4: Build mode UI (snap-to-grid preview)
- [ ] B5: TP↔FP camera

### Phase C — Retention
- [ ] C1: Daily login (7-day rolling streak)
- [ ] C2: Restocking shop (6h rotation)
- [ ] C3: Daily quests (3 from a 30+ pool)
- [ ] C4: Offline progression (12h cap)

### Phase D — Monetization
- [ ] D1: Game Passes (2x Credits, Auto-Collect, VIP)
- [ ] D2: Dev Products (currency packs)
- [ ] D3: Battle Pass (free + premium tracks)
- [ ] D4: Shop UI panels

### Phase E — Social + PvP
- [ ] E1: Raid matchmaking + reserved-server launch
- [ ] E2: Wave defense (alien predator AI)
- [ ] E3: Clans (4-person squads + stash)
- [ ] E4: Spatial voice (raid-only)
- [ ] E5: Leaderboards (OrderedDataStore)

### Phase F — Anti-exploit + FTUE
- [ ] F1: Token-bucket rate limiter
- [ ] F2: Audit log + trust boundary helpers
- [ ] F3: Receipt idempotency ledger
- [ ] F4: 30-second first-run sequence

### Phase G — Aesthetic
- [ ] G1: Bioluminescent jungle pass
- [ ] G2: Synthwave music (5+ tracks)
- [ ] G3: Per-biome ambient + VFX

### Phase H — Ship prep
- [ ] H1: 3 thumbnails + game icon
- [ ] H2: Closed beta (5–20 testers)
- [ ] H3: Analytics dashboards live (PlayFab or GameAnalytics)
- [ ] H4: Open Cloud release pipeline green

### Phase I — Launch
- [ ] I1: Public launch
- [ ] I2: TikTok / YT Shorts promotion
- [ ] I3: Weekly LiveOps cadence locked in

---

## V1.5 — Post-launch retention enhancers

Gated behind `Constants.FEATURES.*` flags. Lands in `main` behind a flag; flipped on per release.

- [ ] Trading marketplace (player-to-player blueprint trading)
- [ ] Seasonal events (limited-time biomes / cosmetics)
- [ ] Clan wars (cross-clan persistent rivalry meta)
- [ ] Skill trees (per-operator perk progression)
- [ ] Friend-only co-op mode (PvE-only sessions)

---

## V2 — Major expansion

- [ ] New biome: Volcanic
- [ ] New biome: Ice
- [ ] Vehicle system (rovers, dropships)
- [ ] PvE story missions (narrative campaign layer)
- [ ] Mod tools / community-made base templates

---

## Cadence

| Cadence | What |
|---|---|
| Weekly | Bug fix release, balance tweaks, quest pool refresh |
| Bi-weekly | New blueprint, new daily quest pack |
| Monthly | New cosmetic drop, leaderboard reset |
| Seasonal (12 weeks) | Battle Pass season rollover |

---

## Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-05-03 | Open Cloud Place Publishing API for CI deploy | Headless, no Studio needed, official path. See `docs/playbooks/PUBLISHING.md`. |
| 2026-05-03 | Single `main` branch, feature flags > feature branches | Avoid long-lived branches; ship V1.5 work behind `Constants.FEATURES.*` |
| 2026-05-03 | Hybrid module organization (domain folders for known-large areas) | See `docs/REPO_STRUCTURE.md` §3 |
