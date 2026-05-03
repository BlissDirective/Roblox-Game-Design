# 00 — START HERE

> **The single source of truth for this Roblox project. Read this first. Every time.**

---

## What this folder is

This is the knowledge base for a solo Roblox game project being built with Claude Code as the primary engineering partner. Every `.md` file here is reference material that Claude (and you) should consult before making decisions, writing code, or shipping anything.

The goal: build a **highly-played, highly-monetized Roblox game** as a solo developer, using AI to compress what used to take a team of 5 into the work of 1 person + 1 model.

---

## The 10 files in this bundle (and when to read each)

| # | File | Read when... |
|---|------|--------------|
| 00 | **START_HERE.md** | Every session. This is the index. |
| 01 | **AGENT.md** | Loaded by Claude Code at the start of every session. Defines Claude's role. |
| 02 | **ROBLOX_PLATFORM.md** | Need to know who plays Roblox, what genres dominate, what the platform pays. |
| 03 | **GAME_GENRES.md** | Brainstorming concepts. Picking a niche. Comparing tycoon vs simulator vs RPG. |
| 04 | **VIRAL_MECHANICS.md** | Designing the hook. Understanding what made *Steal a Brainrot* and *Grow a Garden* explode. |
| 05 | **MONETIZATION.md** | Deciding on Game Passes, pricing, Robux→USD math, Creator Rewards strategy. |
| 06 | **LUAU_REFERENCE.md** | Writing or reviewing any code. Anti-exploit patterns. DataStore. RemoteEvents. |
| 07 | **PROJECT_STRUCTURE.md** | Setting up the repo. File naming. Rojo. Where things live. |
| 08 | **MCP_SETUP.md** | First-time setup. Connecting Claude Code to Roblox Studio. Troubleshooting. |
| 09 | **BRAINSTORM.md** | Phase 2 — picking what to actually build. |

---

## The current state of you (April 2026)

You are:
- **A total beginner.** Never opened Roblox Studio.
- **Solo.** No team. No collaborators (yet).
- **Working with Claude Code.** Not a junior dev — a senior engineer + CTO + design lead in one model.
- **Genre-open.** No locked-in concept. Research-first decision.

This means every doc is written assuming **zero prior Roblox knowledge**. When something looks like jargon (Luau, RemoteEvent, DataStore, Rojo, MCP, CCU, DAU), it's defined the first time it's used.

---

## The 4-phase plan

### Phase 1 — Knowledge (DONE when you read these docs)
You and Claude get on the same page about the platform, the economics, the engineering, and what wins.

### Phase 2 — Concept (THIS IS NEXT)
Use `09_BRAINSTORM.md` as a worksheet. Generate 5–10 concepts. Score them. Pick one.

### Phase 3 — Build
- Set up Roblox Studio + Claude Code + MCP (see `08_MCP_SETUP.md`)
- Build the prototype — core loop only, no polish
- Playtest with 1–5 real humans (friends, Discord)
- Iterate until 20%+ of testers say "I'd play this again tomorrow"

### Phase 4 — Ship
- Polish, monetize, publish
- Promote on TikTok / YouTube Shorts (free traffic)
- Read analytics. Iterate weekly.
- Layer in retention systems (daily login, events, FOMO)

---

## What "winning" actually looks like (be honest)

The article that kicked this project off mentions $38.5M/year top-10 creators. That is **not the realistic target for a first solo game**. Here is the honest progression:

| Tier | Game | Realistic monthly revenue |
|------|------|---------------------------|
| **First game, month 1** | Anything that ships | $0 – $200 |
| **Iterated, month 3–6** | Has retention loops, daily logins | $200 – $2,000 |
| **Established (12+ mo)** | Steady audience, weekly updates | $2,000 – $10,000 |
| **Top 10% within genre** | Proper LiveOps, social hooks | $10,000 – $100,000+ |
| **Viral breakout** | Right concept × right cultural moment | $100,000+ /month |

Top 0.1% outcomes (Steal a Brainrot, Grow a Garden) are real but not plannable. They are residue of: a solid loop + a cultural moment + visible spectacle + viral clipability. You can build the first three. The fourth is partly luck.

**What you can plan for:** ship something that ~5,000 DAU enjoy and that returns ~$1,500–$5,000/month. That is a real career-changer for one person and is very achievable in 2026 with this stack.

---

## The North Star (one sentence)

> **Build a game with a sub-10-minute satisfying loop, a daily-return reason, a clippable spectacle moment, and a clean monetization layer that doesn't break the free experience.**

Every design decision, every Game Pass, every system Claude writes — measure it against that sentence.

---

## How to actually use this in Claude Code

When you start a Claude Code session in your project folder, the workflow is:

1. **Claude Code automatically reads `AGENT.md`** (also commonly `CLAUDE.md` — see that file).
2. You point Claude at whichever doc is relevant: *"Read 04_VIRAL_MECHANICS.md and 03_GAME_GENRES.md, then propose 5 concepts."*
3. Claude works. You review. You ship.

These docs are designed to be **referenced, not memorized.** Update them as you learn. Treat them as living documents.

---

## Update log

| Date | Change |
|------|--------|
| 2026-04-28 | Initial bundle created. Phase 1 complete. |

---

**Next file to read: `01_AGENT.md`**
