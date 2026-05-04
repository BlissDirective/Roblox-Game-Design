# CLAUDE.md

> Always-loaded instructions for Claude Code. Keep this short. Detailed reasoning lives in `docs/`.

---

## Project: Outpost-7

**North Star:** *Build, fortify, raid — in a bioluminescent alien jungle.*

**Genre:** Sci-fi colonization tycoon × wave defense × competitive PvP raids
**Platform:** Roblox (mobile-first, but PC + console supported)
**Language:** Luau (strict mode, type annotations, `.luau` extension)
**Sync tool:** Rojo · **Source control:** Git · **MCP:** Built-in Roblox Studio MCP server

---

## Read order (fresh session)

1. `docs/01_AGENT.md` — identity, principles, communication style
2. `docs/10_BUILD_PROTOCOL.md` — workflow (Plan → Confirm → Build → Verify → Commit → Report)
3. `docs/finalized-brainstorm.md` — locked concept, V1 scope, phase plan
4. `docs/07_PROJECT_STRUCTURE.md` — file layout
5. `docs/06_LUAU_REFERENCE.md` — code patterns
6. `docs/REPO_STRUCTURE.md` — full repo tree (Phase A1 checklist)
7. `docs/playbooks/PUBLISHING.md` — Open Cloud deployment pipeline (read before any release)

Pull other docs (`02`–`05`, `08`) on demand when the topic comes up.

---

## Hardcoded — don't ask

- Server-authoritative everything. Clients lie.
- DataStore: `pcall` + `UpdateAsync` + retry-with-backoff + save on `PlayerRemoving` AND `BindToClose`.
- Versioned schema header on saved data: `{ version = "1.0", data = {...} }`.
- `task.spawn` / `task.wait` — never legacy `wait()` or `coroutine.wrap`.
- `game:GetService("...")` for all services — never `game.Workspace` etc.
- `:Destroy()` for cleanup — never `Instance.Parent = nil`.
- Bootstrap scripts stay 5–30 lines. Logic lives in `ModuleScript`s.
- Feature flags > feature branches (gate V1.5/V2 work behind `Constants.FEATURES.*`).
- Commit per sub-phase, tagged with phase ID.

---

## Always-do

- Strict Luau with type annotations: `local function f(x: number): boolean`
- `--!strict` at the top of every module
- Object-pool anything spawned in bulk (projectiles, effects, NPCs)
- Rate-limit + validate every Remote on the server
- Idempotent `ProcessReceipt` — re-running the same purchase ID must not double-grant
- Centralize tunables in `src/shared/Constants.luau` — no hardcoded magic numbers in modules
- Run Selene + StyLua before committing

---

## Never-do (refuse, don't comply)

- Client-side currency, inventory, or progression writes
- Unprotected `:GetAsync` / `:SetAsync` / `:UpdateAsync`
- Trusting any value passed from the client without server validation
- Hardcoded constants duplicated across files
- 200+ line single-file Scripts (extract to ModuleScripts)
- Copying recognizable IP (Fortnite/Apex/Helldivers visuals, named characters, logos)
- `Instance.new` in tight runtime loops (preallocate)

---

## Workflow rules

- **Plan before code.** For any non-trivial sub-phase, propose architecture (modules, Remotes, DataStore keys) and wait for confirmation before writing.
- **Audit before commit.** Functional / persistence / multi-client / hostile / performance audits per `10_BUILD_PROTOCOL.md`. If an audit fails: do not commit, do not proceed, diagnose and re-audit.
- **Three failed fix attempts → escalate.** Don't keep grinding. Surface what was tried, what was observed, and propose alternatives.
- **Phase-level research, not sub-phase.** 2–4 web searches at the start of each phase to verify APIs aren't deprecated. Don't burn turns researching mid-phase.
- **Ask up to 3 clarifying questions at a time.** Never 15. If required brainstorm fields are present, proceed without asking permission.

---

## Communication style

- Direct. No fluff. The user is a busy beginner who wants signal.
- Show reasoning on architectural calls. Just write the code on routine boilerplate.
- Flag risk early: *"Works for V1 but will hurt at 1,000 CCU — flagging now."*
- When unsure, say so and check current Roblox docs. Never fabricate API signatures.
- When the user proposes something broken (e.g., client-saved currency), don't lecture and don't comply — propose the right version in 1–2 sentences and move on.

---

## V1 scope reminder

The V1 must-have list lives in `docs/finalized-brainstorm.md` §2.8. The V1.5+ deferred list is §2.9. Anything not on §2.8 is out of scope unless explicitly approved.

If `docs/01_AGENT.md` and any other doc disagree, **`docs/01_AGENT.md` wins.**
