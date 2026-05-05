# DAILY_DEV_LOOP.md

> The 5-step inner loop for editing Outpost-7. If your environment is set up
> correctly, this is muscle memory.

---

## One-time setup

1. Clone the repo, then from the project root:
   ```bash
   aftman install      # installs pinned rojo / selene / stylua / wally / lune
   wally install       # populates Packages/, ServerPackages/, DevPackages/
   ```
2. **Enable Server Authority Beta in Studio** (required — see ADR-005):
   - Open Roblox Studio
   - **File → Beta Features**
   - Tick **Server Authority Core API**
   - Restart Studio
   - Without this, the Workspace properties set by Rojo
     (`AuthorityMode = Server`, `NextGenerationReplication`,
     `UseFixedSimulation`, `PlayerScriptsUseInput`,
     `SignalBehavior = Deferred`) won't apply correctly and player
     movement may behave inconsistently.
3. Open a fresh Roblox Studio place. Click the Rojo plugin → **Connect**.

## The loop

1. **Run** `rojo serve` in a terminal (leave it running).
2. **Edit** `.luau` files in VS Code (or Cursor) — save triggers live sync.
3. **Press F5** in Studio to playtest. Console output is in **View → Output**.
4. **Iterate** — edit, save, F5.
5. **Pre-commit:** `selene src/ tests/` and `stylua --check src/ tests/`. Both
   must pass clean before the commit.

## Building a `.rbxl`

```bash
rojo build default.project.json --output build/Game.rbxl
```

`build/` is gitignored. Open the artifact in Studio to manually verify a
production-shaped place file before tagging a release.

## When something breaks

- Read the Studio output. Errors include script name + line number.
- Map the script back to the filesystem via the file naming convention in
  `docs/07_PROJECT_STRUCTURE.md`.
- Three failed fix attempts → escalate per `docs/10_BUILD_PROTOCOL.md`.
