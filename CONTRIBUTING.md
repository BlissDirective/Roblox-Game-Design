# Contributing to Outpost-7

This is a solo project, but it's structured so a future-you (or a contributor) can onboard cleanly. If that's you, read this top-to-bottom once.

---

## 1. Onboard

```bash
git clone https://github.com/BlissDirective/Roblox-Game-Design.git
cd Roblox-Game-Design

# Toolchain
aftman install        # rojo, selene, stylua, wally, lune
wally install         # shared deps

# Live-sync
rojo serve            # then connect from Studio's Rojo plugin
```

Read in this order:

1. `CLAUDE.md`
2. `docs/01_AGENT.md`
3. `docs/10_BUILD_PROTOCOL.md`
4. `docs/finalized-brainstorm.md` (the locked concept)
5. `docs/REPO_STRUCTURE.md` (where things live)
6. `docs/playbooks/PUBLISHING.md` (how a release ships)

---

## 2. The build protocol

Every change follows: **Plan → Confirm → Build → Verify → Commit → Report**. Detail in `docs/10_BUILD_PROTOCOL.md`. Skipping it is how V1s don't ship.

- **Phase-tagged commits.** `[A2] DataManager: add UpdateAsync retry-with-backoff`
- **One sub-phase per PR.** Don't combine A2 and A3 in one branch.
- **Audit before commit.** Functional, persistence, multi-client, hostile, performance — checklist in PR template.

---

## 3. Code standards

| Rule | Tool |
|---|---|
| `--!strict` at top of every module | manual + selene |
| Types on every public function | manual |
| `task.spawn` / `task.wait` only — never legacy `wait()` / `coroutine.wrap` | selene |
| `game:GetService("X")` only — never `game.X` | selene |
| Tabs, 4-wide, LF | stylua + editorconfig |
| 120-col soft limit | stylua |
| PascalCase modules + functions, camelCase locals | manual |

Run before commit:

```bash
./tools/scripts/format.sh   # stylua src/
./tools/scripts/lint.sh     # selene src/
```

CI re-runs both on every PR.

---

## 4. Branch + commit conventions

- **Single `main` branch.** No long-lived feature branches; gate V1.5/V2 work behind `Constants.FEATURES.*`.
- **Topic branches** named `phase/<id>-<slug>` (e.g. `phase/A2-datamanager`).
- **Commit prefix** is the phase id: `[A2] ...`, `[B1] ...`, etc.
- **Squash-merge** topic branches into `main`.

---

## 5. Tests

- Unit tests live in `tests/unit/`, mirroring `src/`.
- Integration tests live in `tests/integration/` and run inside Studio's Test Server.
- Toggle the runner by flipping `Constants.RUN_TESTS = true`.
- Critical-path coverage required before merging A-phase work: DataStore round-trip, ProcessReceipt idempotency, Remote rate limiting, raid snapshot isolation.

---

## 6. Releases

The pipeline is described in `docs/playbooks/PUBLISHING.md`. TL;DR:

1. Bump `CHANGELOG.md` with the phase entries that ship in this version.
2. Tag the commit `v0.x.y`.
3. Push the tag → `release.yml` builds with `rojo build` and publishes via Open Cloud.

**Never** publish from Studio's "Publish to Roblox" if you can avoid it. Studio's publish bypasses CI — divergence between source-of-truth and live game is how exploits sneak in. The one exception: CSG / EditableMesh / EditableImage / SurfaceAppearance / BaseWrap edits, which the Open Cloud API does not yet handle and require a one-off Studio publish.

---

## 7. Reporting issues

Use the GitHub issue templates. Bug reports need: repro steps, place version (from `CHANGELOG.md`), client (mobile / PC / console), and a screenshot or repro video if the bug is visual.

---

## 8. Security

See `SECURITY.md`. Do **not** open a public issue for an exploit or vuln — email instead.
