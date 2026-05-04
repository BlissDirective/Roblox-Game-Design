# 10 — BUILD_PROTOCOL.md

> The workflow protocol Claude Code follows during Phase 3 (build). This sits on top of `01_AGENT.md` — that file defines *who Claude is*; this file defines *how Claude operates* once a concept is locked and code starts shipping.

---

## Relationship to other docs

- `01_AGENT.md` — Claude's identity, engineering principles, communication style. **Does not change.** This file does not override it.
- `finalized-brainstorm.md` — The completed concept worksheet. This protocol assumes Steps 1–8 are filled in and Step 7 (the North Star sentence) is locked.
- `06_LUAU_REFERENCE.md` / `07_PROJECT_STRUCTURE.md` — Code patterns and file layout. Reference these instead of restating them here.

If anything in this file conflicts with `01_AGENT.md`, `01_AGENT.md` wins.

---

## Mission

**Build a fully deployable Roblox game from the locked concept in `finalized-brainstorm.md`, autonomously, in phases, with the human in the loop only for taste decisions and high-stakes calls.**

The implicit thesis: a solo dev with this stack should ship a real, playable, monetized V1 in 4–8 weeks. Not a perfect game. A *real* one — that 50 humans can play, that has clean monetization, that has a daily-return reason, that runs on a phone.

---

## Inputs the agent expects from brainstorm.md

Before starting Phase 3, Claude verifies `finalized-brainstorm.md` contains:

| Field | Required? | Where to find it |
|---|---|---|
| North Star sentence | ✅ Yes | Step 7 |
| Genre + retention-genre blend | ✅ Yes | Step 4 (chosen concept) |
| One-sentence loop | ✅ Yes | Step 4 |
| Daily-return mechanics (≥2) | ✅ Yes | Step 4 |
| Clippable spectacle moment | ✅ Yes | Step 4 |
| Social interaction layer | ✅ Yes | Step 4 |
| Monetization stack (V1) | ✅ Yes | Step 4 / Step 8 |
| V1 must-haves list | ✅ Yes | Step 8 |
| V1.5 deferred list | ✅ Yes | Step 8 |
| Aesthetic preference | ⚠️ Optional | Step 1 |
| Time budget | ⚠️ Optional but helpful | Step 1 |

**If any required field is missing or vague, Claude pauses and asks targeted clarifying questions — maximum three at a time.** Do not ask 15 questions in one round; that overwhelms the user. Ask three, get answers, ask three more if still needed.

**If all required fields are present, Claude proceeds without asking permission.**

---

## Hardcoded assumptions (don't ask)

These are settled. Don't burn turns confirming:

- **Language:** Luau (with type annotations, strict mode). Use `.luau` file extension, not `.lua`.
- **File structure:** As defined in `07_PROJECT_STRUCTURE.md` — `src/server/`, `src/client/`, `src/shared/`, with `Modules/` subfolders.
- **Sync tool:** Rojo. `default.project.json` at project root.
- **Source control:** Git. Commit per sub-phase.
- **MCP:** Built-in Roblox Studio MCP server (per `08_MCP_SETUP.md`).
- **Trust model:** Server-authoritative everything. No exceptions.
- **DataStore pattern:** `pcall` + `UpdateAsync` + retry-with-backoff + save-on-`PlayerRemoving`-and-`BindToClose`.
- **Target platform priority:** Mobile first (80% of audience), then desktop, then console.

---

## The phase protocol

### Why phases matter

Long Claude Code sessions degrade after ~2–3 hours of continuous work. Context fills up. Mistakes compound. The phase protocol exists to **force fresh context windows at clean checkpoints** so quality stays high across the full build.

### Phase structure

Each phase is **one major capability**. Each phase has 2–5 sub-phases. Each sub-phase ends with a Git commit and a brief written summary.

### The default phase plan (Claude proposes this at kickoff; human approves before starting)

**Phase A — Foundation (1 session)**
- A1: Project scaffolding (Rojo config, folder structure, `.gitignore`, `CLAUDE.md`)
- A2: `DataManager` module + DataStore wrapper with retry/backoff
- A3: `Remotes.luau`, `Constants.luau`, `Types.luau` shared scaffolding
- A4: Server bootstrap (`init.server.luau`) + client bootstrap (`init.client.luau`) — empty but wired
- ✅ **Audit:** Studio loads place, no errors in output, DataStore round-trips work

**Phase B — Core Loop (1–2 sessions)**
- B1: The single defining mechanic of the game (the "one-sentence loop" from brainstorm)
- B2: Currency + progression
- B3: First persistent state (saves and loads correctly)
- B4: Minimal client UI to display state
- ✅ **Audit:** Two-client playtest. Both players can perform the loop. State persists across rejoin.

**Phase C — Retention Mechanics (1 session)**
- C1: Daily login system
- C2: Second daily-return mechanic (per brainstorm — restocking shop, daily quests, offline progression, etc.)
- C3: Streak tracking + visible reward on login
- ✅ **Audit:** Time-shift test (force date change, verify streak/cooldown logic). Verify rewards land correctly.

**Phase D — Monetization (1 session)**
- D1: Game Pass infrastructure (3–5 passes per `05_MONETIZATION.md` recommended stack)
- D2: Developer Product infrastructure (1–2 products to start)
- D3: Receipt processing (`ProcessReceipt`) — must be idempotent
- D4: Pass effects wired into game state (multiplier passes apply correctly, etc.)
- ✅ **Audit:** Test purchase flow in Studio. Verify pass effects apply. Verify receipt processing handles duplicate calls.

**Phase E — Social Layer (1 session)**
- E1: The social interaction mechanic from brainstorm (PvP, leaderboard, trading, co-op bonus, etc.)
- E2: Friend invite UX (visible button, reward both players)
- E3: Visible flex / leaderboard surface
- ✅ **Audit:** Multi-client playtest. Social mechanic creates the intended emotional moment.

**Phase F — Anti-Exploit + Polish (1 session)**
- F1: `AntiExploit.luau` rate limiting on all Remotes
- F2: Validation pass on every RemoteEvent argument
- F3: Performance audit (object pooling, `task.wait` audit, unnecessary `Instance.new` calls)
- F4: First-run FTUE polish (the 30-second rule)
- ✅ **Audit:** Try to break it. Send malformed Remote calls. Spam Remotes. Check server doesn't crash, doesn't grant unauthorized state.

**Phase G — Aesthetic Pass (1 session, heavily human-driven)**
- G1: Lighting / atmosphere (Future tech, time of day, fog if relevant)
- G2: Audio (background music, key sound effects)
- G3: UI polish (consistent fonts, colors, animations)
- G4: Camera + character feel
- ✅ **Audit:** Vibe check with you and 2–3 friends. Does it feel like a real game?

**Phase H — Ship (1 session)**
- H1: Game settings (icon, thumbnails, description, tags)
- H2: Test on Studio's 8-client sim
- H3: Publish to Roblox as private/unlisted for closed beta
- H4: Closed beta with 5–20 friends/Discord folks
- H5: Iterate based on beta data (not in this phase — triggers V1.1)

The phases above are the **default**. Claude can propose modifications to fit the specific concept (e.g., a horror game might fold E into A, or a strategy game might split B across two phases). Human approves the modified plan before Phase A starts.

### Sub-phase rhythm (the inner loop)

For every sub-phase:

1. **Plan** — State the goal in one sentence. List files to be created/modified. Identify any architectural decisions that need confirmation.
2. **Confirm** — If architectural decision needed, ask. Otherwise proceed.
3. **Build** — Write code. Test as you go via MCP `run_code`.
4. **Verify** — Run the audit specific to this sub-phase. Record what was verified.
5. **Commit** — Git commit with a descriptive message: `feat(phaseB1): core loop tick + currency`
6. **Report** — Brief written summary (10–20 lines max). What was built, what was verified, any tech debt logged, what's next.

The Plan→Confirm→Build→Verify→Commit→Report cycle is the unit of work. Don't skip steps to save time.

---

## Autonomy + escalation rules

### Claude proceeds autonomously on:

- Module-level architectural choices within a sub-phase scope
- Variable naming, function signatures, internal data structures
- Error handling patterns
- Performance optimizations
- Test setup and execution
- Bug fixes within the current sub-phase
- Refactors that don't change external interfaces
- Adding type annotations
- Writing/updating in-code comments
- Routine Studio operations (creating folders, setting properties, inserting standard models)

### Claude escalates to the human BEFORE acting on:

🛑 **Anything affecting real money flow.** Any change to Game Pass IDs, Dev Product IDs, prices, or `ProcessReceipt` logic. Test purchases are fine; live IDs are not.

🛑 **DataStore schema changes after Phase A.** New fields are usually fine; renaming or removing fields requires a migration plan. Pause and discuss.

🛑 **Anything that could violate Roblox Terms of Service.** Includes: unmoderated user-generated content, off-platform redirects, copyrighted IP usage, content age-inappropriate for the audience tier, anything resembling gambling for under-13s.

🛑 **Scope expansion beyond V1 must-haves.** If Claude finds itself wanting to add "just one more system" not in `finalized-brainstorm.md` Step 8, **stop and ask.** Scope creep is the #1 reason V1s don't ship.

🛑 **Any decision that would meaningfully shape the player's first 30 seconds.** FTUE is taste-critical. Layout of starter UI, first-quest design, opening camera angle, first reward feel — these need human input.

🛑 **Aesthetic direction.** Color palette, lighting mood, character style, UI font choices, audio mood. Claude can propose 2–3 options; human picks.

🛑 **Any irrecoverable error.** A bug Claude has tried 3 times to fix without progress. State this honestly: *"I've tried X, Y, Z, none worked. Here's what I observed. Suggesting we [pause / try a different architecture / get a second opinion]."*

🛑 **Anything Claude is genuinely uncertain about.** Better to ask once than build wrong for 2 hours.

### Claude proactively surfaces (without blocking):

- Tech debt being logged for later (so it doesn't get forgotten)
- Tradeoffs that were made and why
- Things that worked but feel suboptimal
- Patterns observed during the build that might affect later phases

These don't require human approval but should be in the sub-phase report.

---

## Per-phase research protocol

At the **start of each phase** (not each sub-phase), Claude does a brief research pass — 2–4 web searches max, 5–10 minutes of effort. Goals:

- Verify any APIs being used haven't been deprecated since training cutoff
- Check for current best practices specific to the phase's domain
- Look for recent (last 6 months) Developer Forum threads on the systems being built
- Check Roblox's official docs for any new features that might simplify the work

Research output is recorded as a brief note in the phase kickoff message: *"Research surfaced: X is now deprecated, replaced by Y. Z has a new idiomatic pattern as of Q1 2026. Proceeding with current best practices."*

**Don't research at every sub-phase.** That burns time. Phase-level research is the right cadence.

---

## Audit and test patterns

Each sub-phase has an audit. Audits are not unit tests in the traditional sense — they're **functional verifications that the system does what it's supposed to do, end-to-end.**

### Audit types

**Functional audit** — Run the system in Studio, verify the visible behavior matches spec. Used after most sub-phases.

**Persistence audit** — Save state, leave, rejoin, verify state restored. Used for any sub-phase touching DataStore.

**Multi-client audit** — Studio's 2-or-more-client sim. Used for any sub-phase touching networking or RemoteEvents.

**Hostile audit** — Try to break it. Send malformed Remote args. Spam events. Inject obviously-cheating values. Used at end of each phase, mandatory at end of Phase F.

**Performance audit** — Run the MicroProfiler (Studio's built-in). Look for frame time spikes, memory growth, garbage collection patterns. Used at end of Phases B, E, F.

**FTUE audit** — Fresh test account joins. Stopwatch starts. Does the player see something interesting in 30 seconds? First reward in 60? Used at end of Phases B and G.

### What audit failure means

If an audit fails, **do not commit. Do not proceed.** Diagnose, fix, re-audit. If three fix attempts fail, escalate to human per the rules above.

Don't paper over a failed audit by lowering the bar. The point of the audit is to catch the bug now, when one sub-phase is in flight, not later when it's compounded with five other sub-phases.

---

## Git protocol

### Commit per sub-phase

Format:
```
<type>(phase<X><N>): <short description>
```

Examples:
- `feat(phaseA1): rojo scaffolding + bootstrap scripts`
- `feat(phaseB2): currency tick + passive income`
- `fix(phaseC1): daily login streak reset on missed day`
- `refactor(phaseD3): extract receipt validation`

### Push policy

- Commit locally after every sub-phase.
- **Do NOT push to the default branch automatically.**
- After each phase (multiple sub-phases), Claude provides a phase summary.
- Human reviews summary, runs the game themselves if relevant, says "good — push it" or "wait, let's discuss X."
- On approval, Claude squash-merges the phase work into the default branch with a clear summary commit message.

### Branch convention

- `main` = always deployable, all approved phases
- `phase/<X>-<name>` = work-in-progress phase branch (e.g., `phase/B-core-loop`)
- After phase approval and squash merge, the phase branch can be deleted

For a solo dev, this is more git ceremony than strictly necessary, but the discipline pays off when V2 work needs to revert a problem from V1.

---

## Iteration discipline (the anti-perfectionism rule)

The phrase "iterate until 100% flawless" is dangerous. It causes endless polishing of things that don't matter yet. Replace it with this:

> **Each phase ships when it passes its audits and serves its purpose. "Good enough for the current phase, with known tech debt logged for V1.1" beats "perfect" every time. Real player data after launch is more valuable than another iteration in the dark.**

When Claude is tempted to over-iterate on something:

- Is this blocking a later phase? → Fix now.
- Is this a known issue but not blocking? → Log to `TECH_DEBT.md`, move on.
- Is this aesthetic / "feel" / taste? → Surface to human for decision.
- Is Claude unsure if it's good enough? → Ship it. The humans who play it will tell us.

The rare exception: anything in the **trust boundary** (server-side currency, DataStore integrity, anti-exploit). These need to be right the first time — exploits in week 1 destroy the game's reputation. Polish is optional; security is not.

---

## Multiple-paths-to-success principle

For any meaningful decision, Claude considers at least 2 alternatives before committing. Briefly. In one or two sentences. Not as a performance — as a real check.

Examples:

- "Going with `UpdateAsync` here. Alternative: `SetAsync` is simpler but loses concurrent-write safety. Worth the extra complexity."
- "Going with a single Remote for the shop. Alternative: separate Remote per shop type. Saved that for V2 if we add shop variety."
- "Going with object pooling for projectiles. Alternative: `Instance.new` per shot, simpler. Pooling matters here because mobile."

This is not "show your work for everything." It's "make sure you considered the alternative for choices that will hurt later if wrong."

---

## Phase summary format (for human review)

After each phase, Claude produces a summary in this exact shape:

```markdown
## Phase <X>: <Name> — Summary

**Goal:** <one sentence>

**Sub-phases completed:**
- <X1>: <what was built> ✅
- <X2>: <what was built> ✅
- <X3>: <what was built> ✅

**Audits run:**
- <type>: <result>
- <type>: <result>

**Architectural decisions made:**
- <decision> — chose <option> over <alternative> because <reason>

**Tech debt logged:**
- <item> — <severity> — <when to address>

**Open questions / requests for human input:**
- <question or request, if any>

**What's next:** Phase <X+1>: <name>. Estimated <N> sub-phases.

**Ready to push to main?** [awaiting your call]
```

This format keeps reviews fast. The human reads ~30 lines, decides yes/no/discuss, and the project moves.

---

## When to abandon the protocol

The protocol serves the goal, not the other way around. If during the build something significant changes — concept needs revision, a system fundamentally doesn't work as designed, the audience signal from beta is loud and clear — pause the protocol. Re-do `finalized-brainstorm.md`. Re-plan phases.

Sticking to a flawed plan because the protocol said so is worse than re-planning.

---

## Kickoff prompt (use this exact text to start Phase 3)

Once `finalized-brainstorm.md` Steps 1–8 are filled in and the North Star is locked, paste this into Claude Code:

```
We are starting Phase 3 — build mode.

Read in this order:
1. docs/01_AGENT.md (your identity and principles)
2. docs/10_BUILD_PROTOCOL.md (this build workflow)
3. docs/finalized-brainstorm.md (the locked concept)

Verify all required fields are present in finalized-brainstorm.md per the input
checklist in 10_BUILD_PROTOCOL.md. If anything is missing, ask up to 3
clarifying questions, otherwise proceed.

Once verified:
1. Do the Phase A research pass (per the per-phase research protocol).
2. Propose the full phase plan, customized to this specific concept
   (the default in 10_BUILD_PROTOCOL.md is the starting point — modify
   as needed for the genre/scope).
3. Wait for my approval of the phase plan.
4. Once approved, begin Phase A — sub-phase A1.

Do not write any production code until the phase plan is approved.
You may run small exploratory snippets via MCP run_code if needed for
the research pass.
```

---

## What this protocol does NOT cover

- The actual code (that's `06_LUAU_REFERENCE.md` and the templates within it)
- File layout details (that's `07_PROJECT_STRUCTURE.md`)
- MCP setup (that's `08_MCP_SETUP.md`)
- Concept selection (that's `finalized-brainstorm.md`)
- Engineering principles (those are `01_AGENT.md`)

This file is **only the workflow protocol.** Everything else has its own home.

---

## Final note on autonomy

The autonomy this protocol grants Claude is meaningful — multi-hour sessions building real systems with minimal interruption. With that autonomy comes a responsibility to **be honest about uncertainty.** A Claude that proceeds confidently when it's actually unsure is worse than one that pauses to ask.

The bar for "I should proceed" is: *I have at least one clear path forward, and if it doesn't work, I have a fallback, and the worst-case downside is recoverable via Git.*

If any of those three aren't true, escalate.

---

**End of build protocol.**
