# FUNNELS.md

> Funnel definitions: ordered lists of events that, taken together, measure
> a player journey. Drives FTUE optimization, purchase optimization, raid
> participation health.

**Status:** Stub. Populated alongside the events in `EVENT_TAXONOMY.md`.

---

## FTUE funnel (Phase F4 audit gate)

| Step | Event | Target % completing |
|---|---|---|
| 1. Joined | `session_started` | 100% |
| 2. First node scouted | `economy_scouted_node` | ≥ 90% |
| 3. First extractor placed | `build_placed_extractor` | ≥ 85% |
| 4. First credit collected | `economy_earned_credits` | ≥ 80% |
| 5. First wave survived | `combat_survived_wave_1` | ≥ 70% |

## Purchase funnel (Phase D audit)

| Step | Event |
|---|---|
| 1. Shop opened | `monetization_opened_shop` |
| 2. Pass viewed | `monetization_viewed_pass` |
| 3. Prompt accepted | `monetization_prompted_purchase` |
| 4. Purchase completed | `monetization_purchased_pass` |
| 5. Effect applied in-session | `monetization_applied_effect` |

## Raid funnel (Phase E audit)

| Step | Event |
|---|---|
| 1. Queued | `raid_queued` |
| 2. Match found | `raid_matched` |
| 3. Round started | `raid_round_started` |
| 4. Round ended | `raid_round_ended` |
| 5. Reward claimed | `raid_reward_claimed` |
