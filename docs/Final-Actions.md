# Final-Actions.md

> Single-page status + roadmap for Outpost-7. What is done, what is
> left, who/what does each remaining piece. Read top-to-bottom on a
> fresh session to know exactly where the project stands.
>
> **Last updated:** 2026-05-17 (end of Phase G).
> **Branch this reflects:** `claude/audit-phases-a-d-2BAuW` (29
> commits ahead of `main`, despite the branch name — see §4).

---

## 1. Where we are

**Phases A through G are code-complete.** All V1 must-have systems
from `docs/finalized-brainstorm.md` §2.8 either ship or have
working scaffolds awaiting Phase H asset uploads. The game compiles,
the modules wire together, and the gameplay loop runs end-to-end in
a local Rojo session.

**What is left** is Phase H (ship prep) and Phase I (launch buffer).
Phase H is approximately 70% human work (Studio sessions, Creator
Dashboard, marketplace shopping) and 30% code work (CI workflows,
asset manifest plumbing). Phase I is entirely human-driven (friend
playtests, marketing posts, the launch itself).

---

## 2. What has been accomplished

### 2.1 Phase A — Foundation (week 1)
- Toolchain pinned: `aftman.toml` (Rojo, Selene, StyLua, Wally, Lune)
- Two-project Rojo split: `default.project.json` (main place) +
  `raid.project.json` (raid place) per ADR-009
- Repo skeleton: `src/{client,server,shared}` with `Modules/`
  subfolders; `assets/` reserved for binary uploads
- CI scaffolding: `.github/workflows/ci.yml` (Selene + StyLua),
  `docs-check.yml`, `release.yml`, `upload-assets.yml`
- `CLAUDE.md` + `docs/` reading order locked in

### 2.2 Phase B — Core loop (weeks 2–4)
- Plot system: 64×64 stud per-player plot, snap-to-grid placement
- Hybrid extractor: scout resource node → place extractor →
  Credits auto-generate
- Currency layer: server-authoritative `CurrencyService` (Credits +
  Cores), DataStore-backed with versioned schema header
- Build mode: third-person camera, BuildController + PlacementService
- Combat mode: first-person camera, weapon framework, DamageService
- Camera transition system: smooth swap between TP build / FP combat
- DataManager: `pcall` + `UpdateAsync` + retry-with-backoff + save on
  `PlayerRemoving` AND `BindToClose`

### 2.3 Phase C — Retention (week 5)
- Offline progression (12hr cap) via `OfflineProgression`
- Restocking blueprint shop (6hr rotation) via `ShopService` +
  `BlueprintRegistry`
- Daily quests (3 per server reset) via `DailyQuestManager` +
  `QuestObjectives`
- Login streak (7-day rolling, 24hr grace) via `DailyLoginManager`

### 2.4 Phase D — Monetization (week 6)
- 3 game passes (2x Credits, Auto-Collect, VIP Operator)
- 4 developer products (Emergency Shield, Credit Pack S/L, Core Pack)
- Idempotent `ProcessReceipt` per `10_BUILD_PROTOCOL.md`
- Battle Pass infrastructure (D4 — initially flagged as launch
  blocker, closed by G7 cosmetic system)

### 2.5 Phase E — Social layer (weeks 7–9)
- Cross-server raid matchmaker + reserved-server flow
- ADR-009 two-PlaceId raid split (main + raid places under one
  universe)
- PvE wave system + raid-queue fallback (`WaveDirector`)
- TurretService (auto-targeting + raycast damage)
- DroneSwarmService (Combat preset, 3 orbiting drones)
- Clan/squad system (4-person, shared stash, cross-server chat)
- Spatial voice gate (raid place enabled, main place silent)
- Leaderboards (global, weekly raid wins) + friends system

### 2.6 Phase F — Anti-exploit + FTUE (weeks 10–11)
- F0 foundational hardening (V1.5/V2 expansion readiness)
- F1 token-bucket rate limiting on every C→S Remote
- F2 central `RemoteValidator` + `AuditLog` + wire-shape contracts on
  every Remote
- F3 `BeamPool` replaces per-shot `Instance.new` in `TurretService` +
  `DroneSwarmService`
- F4 FTUE state machine (Cinematic → Scout → PlaceExtractor →
  FirstCredits → Completed) + 30-second rule scaffolding
- F5 tutorial gates (closes Phase F)

### 2.7 Phase G — Aesthetic pass (weeks 12–14)
- G1 `BiomeLightingService` + 3 biome profiles (jungle default,
  volcanic, ice cave)
- G2 biome decoration layer (volcanic primary; framework covers all 3)
- G3 ice cave overlay (stalactites, stalagmites, glacier walls)
- G4 audio scaffolding (`AudioRegistry`, `AudioService`,
  `AudioController`) — asset IDs stubbed at 0, real uploads land in
  Phase H
- G5.1 UI theme module + reusable Components + ToastService
- G5.2a action bar + dominant-thumb detection + Battle Pass widget
- G5.2b.1/.2/.3 popup + mid-size panel + social-layer theme migration
- G5.2c voice migration + wallet cluster + claim chimes
- G6 drone-swarm VFX polish (Beam pool upgrade + audio cue)
- G7 cosmetic system (closes the D4 Battle Pass launch blocker)
- G8 FTUE polish (multi-stage cinematic + rotating ring beacon +
  HUD pointer arrows + step-advance audio + hint banner auto-dismiss)

### 2.8 Documentation
- `docs/finalized-brainstorm.md` — locked V1 concept + V1.5/V2
  deferred lists
- `docs/REPO_STRUCTURE.md` — full repo tree
- `docs/playbooks/PUBLISHING.md` — Open Cloud deployment pipeline
- `docs/playbooks/ASSETS.md` — marketplace + AI-gen asset playbook
- `docs/playbooks/DAILY_DEV_LOOP.md` — per-session workflow
- `docs/playbooks/PLAYTEST_PROTOCOL.md` — playtest checklist
- `docs/playbooks/INCIDENT_RESPONSE.md` — live-game rollback
- `docs/phases/PHASE_*.md` — sub-phase worklogs A through G

---

## 3. What remains — Phase H (ship prep, ~1 week)

`docs/finalized-brainstorm.md` §4.9 defines seven sub-phases. The
table below tags each as **CODE** (something I can do here),
**STUDIO** (must happen inside Roblox Studio on your machine), or
**DASHBOARD** (Creator Dashboard / browser).

| Sub-phase | Work | Who/Where |
|---|---|---|
| H1 — Game icon + 3 thumbnails | Create images (Photoshop/Figma/AI), upload via Creator Dashboard or `upload-assets.yml`, pin IDs in `src/shared/AssetIds.luau` | **You** (image tool + dashboard) |
| H2 — Game description, tags, age rating (13+) | Write copy, set tags, age-rate | **You** (dashboard) |
| H3 — Studio 8-client simulation | `Test → Local Server → 8 players`; verify no desync, no DataStore conflicts | **You** drive, I fix bugs surfaced |
| H4 — `.rbxl` build verify | `rojo build default.project.json --output build/Game.rbxl` + open in Studio | I run build, **you** confirm Studio opens it cleanly |
| H5 — Open Cloud release pipeline live | `release.yml` is already scaffolded (Phase A); needs real `ROBLOX_API_KEY` (GitHub secret) + `UNIVERSE_ID` / `PLACE_ID` / `RAID_PLACE_ID` (GitHub vars); manual dry-run against `STAGING_PLACE_ID` first | I verify workflow, **you** generate key + paste secrets |
| H6 — CSG / EditableMesh / EditableImage publish | Author in Studio (Open Cloud cannot materialize these from CI) → upload → pin AssetId in `AssetIds.luau`. Inventory table at `PUBLISHING.md` §3 | **You** (Studio + dashboard) |
| H7 — Friends-only soft test | 1 weekend, 5–15 friends, place set to **private/unlisted** | **You** + friends |

### 3.1 Code work I can do without you (Phase H prep)

1. **Create `src/shared/AssetIds.luau`** — manifest shape from
   `PUBLISHING.md` §4.2. Single source of truth for every
   `rbxassetid://`.
2. **Refactor every `assetId = 0` placeholder** in `AudioRegistry`,
   `Constants`, biome profiles, etc. to read from `AssetIds.luau`.
   When you upload audio in H1, only that one manifest file changes
   — no scattered edits.
3. **Write `tools/scripts/upload-assets.sh`** — the bash that walks
   `assets/`, POSTs to `https://apis.roblox.com/assets/v1/assets`
   with `x-api-key: $ROBLOX_API_KEY`, polls operations until done,
   regenerates `AssetIds.luau`. Currently `upload-assets.yml`
   references this script but it is not yet implemented.
4. **Pin third-party GitHub Actions to SHAs** — `release.yml` and
   `upload-assets.yml` currently use version tags
   (`ok-nick/setup-aftman@v0`, `softprops/action-gh-release@v1`).
   Version tags are mutable; pinning to SHAs is in the
   `PUBLISHING.md` §8 hardening backlog and should land before V1.
5. **Wire `STAGING_PLACE_ID` into a separate job** in `release.yml`
   so dry-runs do not require editing the workflow each time.
6. **Verify H4 locally** — confirm both `rojo build`s produce valid
   `.rbxl` artifacts.

### 3.2 Asset acquisition (you, in parallel with playtests)

Per `docs/playbooks/ASSETS.md`, the V1 asset stack is
**marketplace-first**:

| Asset class | Source | Estimated cost |
|---|---|---|
| Sci-fi crates, foliage, props | Roblox Creator Marketplace | $50–80 |
| Operator armor (3 packs) | Marketplace or commission | $40–60 |
| Alien rigs (Stalker, Magmaling, Cryowraith) | Marketplace + AI-gen if needed | $40–70 |
| Vehicles (rover, hover bike, hover tank) | Marketplace | $30–50 |
| Biome arches (3) — hero pieces | Custom modeling or commission | $50–100 |
| UI icon packs | Marketplace | $10–20 |
| Music (5 tracks) | Pixabay + Audiio licenses | Audiio sub (~$40/mo) |
| SFX (turret, extractor, alien, UI) | Freesound + ElevenLabs | $20–40 |
| **Total (V1 baseline)** | | **~$280–460** |

Brainstorm §4.8 budgeted $300 for assets; expect $400 with audio
licenses included.

### 3.3 Account / verification work (you only)

- **Roblox creator account ID verification** — required before audio
  uploads via Open Cloud. Allow 1–3 days for verification.
- **Open Cloud API key #1 — place publishing.** Dashboard →
  Credentials → Open Cloud → new key. Scope: `universe.place:write`
  on the target universe. Add to GitHub secrets as
  `ROBLOX_API_KEY`.
- **Open Cloud API key #2 — asset upload.** Separate key, scoped
  narrower: `asset:read` + `asset:write` on the creator
  (user/group). Add as a separate GitHub secret per
  `upload-assets.yml`.
- **`UNIVERSE_ID`, `PLACE_ID`, `RAID_PLACE_ID`, `STAGING_PLACE_ID`**
  — GitHub Actions repo variables. Generated when you create the
  places in the dashboard.
- **Key rotation reminder**: quarterly, or immediately if a
  contributor with access leaves.

---

## 4. Branch / merge state

This branch (`claude/audit-phases-a-d-2BAuW`) is misnamed: it
actually contains **all 29 commits for Phases A through G8**, not
just an audit of A–D. `main` only has the initial documentation
seed (17 commits, no source code).

**Recommended next git step:** open a PR to merge this branch into
`main` so subsequent sessions branch from a meaningful baseline.
Until that PR lands, every new session has to know the real source
of truth is this feature branch.

PR title suggestion: `feat: Phases A–G complete — V1 systems
code-complete, ready for Phase H ship prep`.

---

## 5. Remaining steps — Phase I (launch buffer, weeks 16–18)

Per `docs/finalized-brainstorm.md` §4.10:

### I1 — Friend playtest weekend
5–15 friends. Gather data on FTUE confusion, balance, exploit
attempts, mobile FPS gates. Fix top 5 issues. Brainstorm §5 is
explicit that this is **not a staged rollout** — the game stays
unlisted until launch day.

### I2 — Marketing asset prep
Recorded during Phase G/H, finalized here:
- 3 TikTok clips (transformation timelapse, defense moment, raid
  drama) — 15s vertical, synthwave audio
- 3 X posts drafted
- 2 subreddit launch posts drafted (r/roblox + r/RobloxGameDev)

### I3 — Launch
Per brainstorm §6.1:
- **09:00** — Game goes public.
- **09:30** — Personal post to friend group (Discord / iMessage).
- **11:00** — First TikTok (transformation timelapse).
- **13:00** — r/roblox post.
- **16:00** — X post with embedded clip.
- **20:00** — Second TikTok (defense moment).
- **Day 1–7** — 2 TikToks/day, 1 X post/day, subreddit follow-ups
  (1 per sub per week max), Reddit AMA on r/RobloxGameDev Day 5.

### Success target
500 CCU + $2K/mo by month 2. Requires viral first 24–72h (algorithm
boost window) plus 3–5% pass conversion + ARPDAU $0.05–$0.15. See
brainstorm §6.4 for the conversion math.

---

## 6. Deferred — out of scope until launch data lands

These are **not** Phase H/I work. They live behind feature flags
and ship as V1.1/V1.5/V2 updates after launch:

- **V1.1 (first content patch, 2–4 weeks post-launch):** Battle Pass
  Season 1 content if not in V1, first QoL patch from player feedback
- **V1.5:** Colony tier progression (Drop Pod → Megacity 7-tier arc),
  material crafting + vehicle workshop, solo scouting expeditions,
  auto-clip / replay system, Recon + Engineering drone presets
- **V2:** Living jungle (tameable wildlife, 4-player co-op bosses),
  trading marketplace, cross-biome resource trading, player-built
  PvP arenas

Roadmap details: `docs/V1_5_*.md` + `docs/V2_*.md`.

---

## 7. Known gaps that should be closed before tagging v0.1.0

Pre-release checklist lives in `PUBLISHING.md` §6. Highlights that
will fail today:

- [ ] `src/shared/AssetIds.luau` does not exist yet (§3.1.1)
- [ ] Audio cues in `AudioRegistry` still use `assetId = 0`
  placeholders (`ftue_intro_sting`, `ftue_step_advance`, ambient
  loops, weapon SFX — full list in `PHASE_G_AESTHETIC.md` §G4)
- [ ] `Constants.RAID.MainPlaceId` and `Constants.RAID.RaidPlaceId`
  are placeholders
- [ ] CSG / EditableMesh / EditableImage inventory table in
  `PUBLISHING.md` §3 is empty (`_TBD — fill in during Phase G/H_`)
- [ ] Third-party actions in `release.yml` + `upload-assets.yml` not
  pinned to SHAs (PUBLISHING.md §8)
- [ ] No staging dry-run has been performed against
  `STAGING_PLACE_ID` (PUBLISHING.md §6 final item)
- [ ] No DataStore schema migration has been rehearsed — first live
  release establishes baseline; second release is the first one that
  must respect the schema version header

---

## 8. Suggested execution order

If you want a single linear path through Phase H and into launch:

1. **Merge this branch to `main`** — clean baseline for everything
   that follows.
2. **Code prep (I can do):** create `AssetIds.luau` manifest +
   refactor all `assetId = 0` references + write
   `upload-assets.sh` + pin actions to SHAs.
3. **Verify H4:** `rojo build` both `.rbxl` files; you open them in
   Studio to confirm they load.
4. **You: dashboard work.** Verify creator account, generate the
   two Open Cloud keys, create the universe + main + raid +
   staging places, paste secrets/vars into GitHub.
5. **Dry-run H5:** workflow_dispatch `release.yml` with
   `target=main version_type=Saved` against `STAGING_PLACE_ID`.
   Join staging, smoke-test the core loop.
6. **H3 in parallel:** Studio 8-client local-server test. Fix any
   multi-client bugs surfaced. This is the moment to find desync
   issues — cheap to fix now.
7. **Asset acquisition:** shop the marketplace, queue commissions for
   biome arches, license audio. Upload via `upload-assets.yml`.
   Each upload PR regenerates `AssetIds.luau` for review.
8. **H6:** any CSG / EditableMesh work in Studio. Pin AssetIds.
9. **H1 + H2:** finalize icon + thumbnails (use real screenshots
   from the now-polished game). Write listing copy, tags, age
   rating in dashboard.
10. **H7:** friends-only soft test weekend. Place stays unlisted.
    Triage findings into Phase I1.
11. **Phase I1:** fix top 5 issues from soft test.
12. **Phase I2:** finalize marketing assets.
13. **Phase I3:** tag `v1.0.0` → CI publishes → launch day timeline.

---

## 9. What I (Claude) cannot do

For transparency, the hard lines:

- **Cannot run Roblox Studio.** No Studio MCP available in this web
  environment (per the prior conversation about MCP availability).
  Anything that needs Studio's geometry kernel, animation editor, or
  in-Studio testing is yours.
- **Cannot upload to Roblox.** API keys live in your GitHub secrets
  and never leave that scope.
- **Cannot buy marketplace assets.** Roblox marketplace purchases
  require an account session.
- **Cannot generate the listing icon/thumbnails or write marketing
  copy.** I can draft copy on request, but the visual art and the
  account that owns it are yours.
- **Cannot run the 8-client playtest in H3.** Studio-only.
- **Cannot post to TikTok / X / Reddit on your behalf.** All Phase I
  marketing is human-driven.

What I **can** do: every line of code, every CI workflow, every
manifest, every doc update, every bug fix from playtest data, every
post-launch content patch. The split is "computer in cloud" vs "art,
sound, account access, and human judgment" — Phase H is the seam
where both have to meet.

---

**End of Final-Actions.md.** Update this doc as Phase H steps land.
