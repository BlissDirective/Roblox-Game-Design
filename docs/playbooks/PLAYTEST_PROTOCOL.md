# PLAYTEST_PROTOCOL.md

> How closed-beta and friend-playtest sessions are run. Keeps feedback
> structured instead of "yeah it was fun, kinda."

**Status:** Stub. Filled during Phase H (Ship Prep) and Phase I (Launch).

---

## Session shapes

| Shape | When | Players | Goal |
|---|---|---|---|
| **Solo smoke test** | After every sub-phase | 1 | Audit gate per build protocol |
| **2-client multi** | Phases B, E, F | 2 | Replication / trust boundary |
| **Friend playtest** | End of E, end of G | 5–8 | Vibe + UX paper cuts |
| **Closed beta** | End of H | 5–20 | Pre-launch bug + balance signal |

## Friend-playtest checklist (Phase H4)

- [ ] FTUE stopwatch — first reward ≤ 30s on a fresh account?
- [ ] Camera transition (TP↔FP) feels smooth?
- [ ] Mobile: thumbs reach all build palette buttons without misfires?
- [ ] PvE wave 5 survivable; wave 12 dramatic?
- [ ] Daily quest UI surfaces; player understands what to do?

## Reporting

Findings file an issue using the **playtest_finding** template (in
`.github/ISSUE_TEMPLATE/`). Severity tag: `S1-blocker` / `S2-major` /
`S3-minor` / `S4-polish`.
