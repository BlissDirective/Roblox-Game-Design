# HOW TO RUN — view & playtest Outpost-7

> How to turn this repo into a playable game on your own machine. There is
> **no website/dashboard** showing the game yet — it has never been published
> (every PlaceId in `Constants.luau` is a placeholder `0`; publishing happens
> in Phase H). Right now the game lives as **source code** here on GitHub; to
> see it run you assemble it into a Roblox place and play it in **Roblox
> Studio** on your computer.
>
> "Studio audit" in our docs just means: open it in Studio and play-test the
> thing to confirm it actually works.

---

## Where progress lives

- **Code:** github.com/BlissDirective/Roblox-Game-Design (browse files,
  commits, `CHANGELOG.md` in any browser).
- **Running game:** only inside Roblox Studio on your machine, after you build
  it (below). No hosted URL exists until Phase H publishing.

---

## One-time setup (~20 min)

1. **Roblox account + Studio.** Sign in / register at
   [roblox.com](https://roblox.com), then download **Roblox Studio** from
   [create.roblox.com](https://create.roblox.com). Install and log in.
2. **Get the code.** Install [Git](https://git-scm.com), then:
   ```sh
   git clone https://github.com/BlissDirective/Roblox-Game-Design.git
   cd Roblox-Game-Design
   ```
3. **Install the pinned toolchain.** Install
   [Aftman](https://github.com/LPGhatguy/aftman/releases), then from the repo
   root:
   ```sh
   aftman install
   ```
   This installs the exact `rojo`, `stylua`, and `selene` versions this project
   pins (see `aftman.toml`).
   > Bonus: this is also how you keep CI green — run `stylua src/ tests/` and
   > commit whenever the CI "Format check" step complains.

---

## Run it — Option A: quick look (build a file, open it)

```sh
rojo build default.project.json --output build/Game.rbxl
```
Double-click `build/Game.rbxl` to open it in Studio, then press **Play (F5)**.

To build the (currently placeholder) raid place too:
```sh
rojo build raid.project.json --output build/Raid.rbxl
```

## Run it — Option B: live editing (best while iterating)

```sh
rojo plugin install     # one-time: installs the Rojo Studio plugin
rojo serve default.project.json
```
In Studio: open a blank **Baseplate**, open the **Rojo** plugin panel, click
**Connect**. Code now syncs into Studio live. Press **Play (F5)**.

## Multiplayer / raid testing

Studio **Test** tab → **Clients and Servers** → set 2+ players → **Start**. This
runs a local server with multiple clients (needed to exercise raids, clan
stash, etc.).

---

## What you'll see today (and what you won't)

**Working now:**
- Your plot, resource nodes, placing extractors, Credits ticking up
- Building walls / turrets; night waves spawning and **attacking + breaching
  the base**
- **Shooting aliens** with the rifle (Combat mode); **repairing** damaged
  structures; extractors going offline when destroyed (switchable
  soft/medium/hard via `Constants.COMBAT.WaveLossMode`)

**Expect it to look rough** — colored blocks, no music, no models. That is
normal: all art/audio are placeholder `0`s until the **Phase G/H** aesthetic +
asset pass. You are validating that the *systems* work, not the looks.

**Not testable yet:**
- The raid round (still a placeholder — that's sub-phase **R2**, next up)
- Anything needing published PlaceIds (live servers, cross-server matchmaking)

---

## Studio audit gates (what to actually check)

Recipes live in `docs/phases/PHASE_*.md`. For the current work
(`PHASE_R_FORTIFY.md`):

- **R1 Fortify:** place a wall → trigger a wave → watch aliens breach it →
  confirm an extractor goes offline (and the credit skim on medium/hard) →
  repair it → rejoin and confirm state persists.
- **R3 Weapon:** in Combat mode, fire at an alien — 34 dmg/hit, dies in 3, the
  tracer renders, fire rate caps ~2.8/s under spam, and shooting your own
  walls does nothing.

File findings back into the matching `docs/phases/PHASE_*.md`.
