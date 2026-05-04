# Changelog

All notable changes to Outpost-7 are tracked here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/) once V1.0 ships.

Pre-launch: each Phase A–I sub-phase gets its own entry under `[Unreleased]`.

---

## [Unreleased]

### Added
- Phase A1 — Project scaffolding
  - Full repo tree per `docs/REPO_STRUCTURE.md`
  - Aftman toolchain pinned (rojo, selene, stylua, wally, lune)
  - Wally manifest scaffold
  - Rojo `default.project.json` mapping `src/` + `assets/` into the DataModel
  - Selene + StyLua configs
  - GitHub Actions CI (lint + format + `rojo build`)
  - GitHub Actions release workflow using Open Cloud Place Publishing API
  - GitHub Actions assets workflow (manual trigger; uploads via Open Cloud Assets API)
  - PR / issue templates, CODEOWNERS, dependabot
  - VS Code workspace config (Luau LSP + StyLua format-on-save)
  - Empty bootstraps: `src/server/init.server.luau`, `src/client/init.client.luau`
  - Empty shared scaffolds: `Remotes.luau`, `Constants.luau`, `Types.luau`, `Enums.luau`, `AssetIds.luau`
  - `tools/scripts/{build,lint,format,publish,upload-assets,new-module}.sh`
  - `docs/playbooks/PUBLISHING.md` (full Open Cloud deploy workflow documented)
  - `docs/playbooks/{DAILY_DEV_LOOP,PLAYTEST_PROTOCOL,INCIDENT_RESPONSE}.md` (stubs)
  - `docs/architecture/{DATA_SCHEMA,REMOTES_REGISTRY,RAID_PROTOCOL,ECONOMY_TUNING,DECISIONS}.md` (stubs)
  - `docs/phases/PHASE_{A..I}_*.md` (worklog stubs)

---

## [0.0.0] — 2026-05-03

Initial knowledge base committed (Phase 1 docs).
