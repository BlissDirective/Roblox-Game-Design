# tests/

> TestEZ-style unit + integration scaffolding. Mirrors `src/` layout so the
> right home for a new test is always obvious.

**Status:** Stub. Test scaffolding lands once TestEZ is wired in via
`wally.toml` (`[dev-dependencies]`) — likely Phase A2 or A4.

---

## Layout

```
tests/
├── unit/               ← per-module, mirrors src/
│   ├── shared/
│   ├── server/
│   └── client/
├── integration/        ← multi-module flows, run inside Studio Test Server
├── fixtures/           ← mock player profiles, mock DataStore responses
└── helpers/
    ├── MockPlayer.luau
    ├── MockDataStore.luau
    └── TimeShift.luau  ← for Phase C time-shift audits
```

## Critical paths to cover

Per `REPO_STRUCTURE.md` §3: `DataStore` round-trip (A2), `ProcessReceipt`
idempotency (D3), Remote rate limiting (F1), raid snapshot isolation (E1).

## Running

`tests/run-tests.server.luau` is the TestEZ entry point. Toggled by
`Constants.RUN_TESTS` (Phase A3+). Tests should never run in a published
place — gate it behind a Studio-only check.
