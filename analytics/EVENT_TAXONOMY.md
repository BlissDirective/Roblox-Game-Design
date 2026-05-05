# EVENT_TAXONOMY.md

> Every analytics event the game emits, with payload schema and firing
> conditions. The contract between client/server emitters and the
> `analytics/dashboards/` consumers.

**Status:** Stub. Populated as `Server.Analytics.AnalyticsService` is built
out in Phase B onward.

---

## Naming convention

`<domain>_<verb>_<object>` — snake_case, past tense.
Examples: `economy_earned_credits`, `raid_completed_round`,
`monetization_purchased_pass`.

## Schema

| Event | Domain | Fired when | Required props | Phase |
|---|---|---|---|---|
| _(none yet)_ | | | | |

## Conventions

- Every event payload includes `player_id`, `session_id`, `server_id`,
  `event_ts` (server time), and `event_version` (schema version per event).
- Events are buffered server-side and flushed in batches via
  `Server.Analytics.EventBuffer`. Never fire from the client directly —
  clients lie.
- Adding a new event: row in this table + buffer registration + a row in
  `FUNNELS.md` if it's part of a tracked funnel.
