# config/

> Game balance and content data. Separated from `src/shared/Constants.luau`
> on purpose: **Constants = code-shaped tunables** (rate limits, tick rates,
> feature flags). **`config/` = content-shaped data** (quest pools, blueprint
> catalogs, balance curves) that grows fast and gets tweaked without a code
> review.

**Status:** Stub. Subfolders fill during Phases B–G.

---

## Loading from Luau

JSON files here are loaded at runtime via
`src/shared/Modules/Config/ConfigLoader.luau`, which wraps
`HttpService:JSONDecode` with caching. Do not call `JSONDecode` directly
elsewhere — go through the loader so the cache stays consistent and
hot-reload (when added) works.

## Folder map

| Folder | Owner phase | Examples |
|---|---|---|
| `balance/` | B–F | `currency_curve.json`, `upgrade_costs.json`, `wave_scaling.json`, `raid_rewards.json`, `battle_pass_tiers.json` |
| `content/` | B–E | `quests_pool.json`, `blueprints.json`, `drone_swarms.json`, `biomes.json` |
| `content/battle_pass_seasons/` | D | `season_01.json`, `season_02.json`, … |
| `monetization/` | D | `game_passes.json`, `dev_products.json` |

## Validation

JSON shapes are validated by `tools/content-validators/*` before commit.
Adding a new content file? Add a validator entry first.
