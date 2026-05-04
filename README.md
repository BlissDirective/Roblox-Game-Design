# Outpost-7

> Sci-fi colonization tycoon × wave defense × competitive PvP raids — built on Roblox, in a bioluminescent alien jungle.

**North Star:** *Build, fortify, raid.*

Solo-developer Roblox project, built with Claude Code as the primary engineering partner. See `docs/00_START_HERE.md` for the full knowledge base.

---

## Stack

| Layer | Tool |
|---|---|
| Engine | Roblox |
| Language | Luau (strict mode, `.luau`, `--!strict` everywhere) |
| Sync | [Rojo](https://rojo.space) (`src/` ↔ Roblox Studio) |
| Toolchain | [Aftman](https://github.com/LPGhatguy/aftman) (rojo · selene · stylua · wally · lune) |
| Packages | [Wally](https://wally.run) |
| Lint | [Selene](https://kampfkarren.github.io/selene/) |
| Format | [StyLua](https://github.com/JohnnyMorganz/StyLua) |
| Tests | TestEZ (in-Studio runner) |
| CI | GitHub Actions |
| Deploy | [Roblox Open Cloud Place Publishing API](https://create.roblox.com/docs/cloud/guides/usage-place-publishing) |

---

## Quickstart

```bash
# 1. Install the toolchain (one-time)
curl -fsSL https://github.com/LPGhatguy/aftman/releases/latest/download/aftman-linux.zip -o aftman.zip
unzip aftman.zip && ./aftman self-install
aftman install

# 2. Install Wally packages
wally install

# 3. Live-sync source into Studio
rojo serve
#   → open Roblox Studio → install Rojo plugin → Connect

# 4. Build a place file (headless, e.g. for CI / inspection)
./tools/scripts/build.sh
#   → produces build/Game.rbxl
```

See `docs/playbooks/DAILY_DEV_LOOP.md` for the day-to-day workflow.

---

## Deployment

`git push origin main` → GitHub Actions runs `rojo build` → Open Cloud `places/{placeId}/versions` API publishes the new version. **No Studio required** for the publish step (caveat: CSG / EditableMesh / EditableImage / SurfaceAppearance / BaseWrap edits still need a one-time Studio publish).

Required GitHub secrets / vars:
- `ROBLOX_API_KEY` (secret) — Open Cloud key with `universe-places:write` scope
- `UNIVERSE_ID` (var) — the Experience ID
- `PLACE_ID` (var) — the start place ID inside that Experience

Full pipeline: `docs/playbooks/PUBLISHING.md`.

---

## Repo layout

| Path | What |
|---|---|
| `src/` | Rojo-mapped runtime code (`server/`, `client/`, `shared/`) |
| `assets/` | Binary game content (UI templates, models, audio, icons) |
| `config/` | JSON balance + content data (curves, quests, blueprints) |
| `analytics/` | Event taxonomy, funnel definitions, KPI doc |
| `tools/` | Dev scripts (build, lint, format, publish, asset-upload) |
| `tests/` | TestEZ unit + integration specs |
| `docs/` | Knowledge base + architecture + per-phase worklog + playbooks |
| `place/` | Local build artifacts (gitignored) |
| `.github/` | CI workflows + PR/issue templates |

Full tree: `docs/REPO_STRUCTURE.md`.

---

## Status

Phase A1 complete (project scaffolding). See `CHANGELOG.md` and `ROADMAP.md` for what's next.

---

## License

MIT — see `LICENSE`.
