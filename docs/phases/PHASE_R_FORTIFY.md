# Phase R — Make the verbs real

> Inserted between Phase G (aesthetic) and Phase H (ship prep) per
> `Fable5-Game-To-Fruition.md` §6. The audit found the three North-Star
> verbs — build, **fortify**, **raid** — only half-implemented: aliens
> ignored the base (§4.2), the raid round was an empty timer (§4.1), and
> the player had no weapon (§4.3). Phase R closes those before ship prep.
>
> Build order (user-approved 2026-07-13): **R1 Fortify → R3 Weapon →
> R2 Raid → R4 Shield/loose-ends.**

---

## R1 — Fortify (structure combat)

**Goal:** walls, turrets, and extractors stop being decoration. The swarm
assaults the base; structures have HP and breach; the player repairs.

### R1a — server-authoritative core (this commit)

**Delivered:**

- **`StructureHealthService`** (new) — authoritative HP per structure,
  mirrored to Part `CurrentHp`/`MaxHp` attributes. Owns `Damage`,
  destruction, `Repair`, and the wave-loss policy. AlienAI is the sole
  damage source in V1 PvE (R2/R3 add the raid attacker weapon).
- **Structure HP** in `BuildableRegistry` (`maxHp`): wall 300, turret 250,
  extractor 150 — walls are the perimeter meant to soak the swarm; an
  unwalled extractor is genuinely at risk.
- **Alien retargeting** (`AlienAI`): march on the nearest structure, chew
  through walls/turrets within `AlienStructureAttackRange`, press on to the
  extractors, fall back to hunting the player only when the base is bare.
- **Wave-loss modes** (`Constants.COMBAT.WaveLossMode`, switchable
  soft/medium/hard, default **medium**):
  - walls/turrets at 0 HP → always destroyed (the breach is the drama);
  - extractor at 0 HP → `soft` disable, `medium` disable + capped credit
    skim, `hard` destroy + capped skim.
- **Repair** (`RepairStructure` Remote): cost `max(RepairCostMin,
  missingHp × RepairCostPerHp)`, server-validated (ownership + reach +
  affordability), re-enables a disabled extractor.
- **World**: `PlotCount` 4→8 (`PlotGridCols` = 4-wide strip) per audit §4.5.
- **Bug fixes**: `part.SetAttribute` → `part:SetAttribute` in
  `BuildableRegistry` + `ResourceNodeSpawner` (audit §4.7 never-run class).

**Not in R1a (→ R1b):** client damage-state visuals (cracked/breached
emissive states off the `StructureHealth` push) and the hold-to-repair input
affordance. Until R1b, repair is exercisable via the `RepairStructure`
Remote / command bar.

### R1a audit gate (run in Studio — pending)

1. **Placement + HP:** place a wall; confirm `MaxHp`/`CurrentHp` attributes
   appear on the Part and equal 300.
2. **Breach:** trigger a wave (`WaveDirector.StartWave`), watch aliens path
   to the wall, attack it (`CurrentHp` ticks down ~20/sec/alien), and destroy
   it, then press on to the extractor behind.
3. **Extractor down (medium):** let an extractor reach 0 HP — confirm income
   stops (currency tick no longer credits it) and a capped credit skim fires.
   Flip `WaveLossMode` to `soft` (no skim, disable only) and `hard`
   (destroyed + skim) and re-verify each.
4. **Repair:** call `RepairStructure` for the downed extractor within reach —
   confirm the cost is spent, HP restores to full, and income resumes.
5. **Persistence:** rejoin — structures restore at full HP (V1 does not
   persist mid-wave damage); a hard-mode-destroyed structure does NOT restore.
6. **8 plots:** confirm 8 plots build in a 4×2 strip and 8 players each get one.

---

## R3 — Weapon (next)

One server-validated hitscan rifle: client intent → server re-raycast from
the character (reach/rate validated via existing token buckets) →
`DamageService` → `BeamPool` tracer. Works in PvE defense and R2 raids.

## R2 — Raid (after R3)

Render `snapshot.baseLayout` into the raid place (reuse `BuildRestorer`);
attacker damages structures with the R3 weapon; extraction loot model caps
the steal at a % of `creditsAtSnapshot`; snapshot turrets/drones fight back.
Feed real results into the existing outcome relay.

## R4 — Shield + loose ends

Emergency Shield (`shieldedUntil` + matchmaker filter + HUD), 2× Credits into
offline grants, `PlacementResult` toast, quest pool → 30 incl. combat/raid
objectives.
