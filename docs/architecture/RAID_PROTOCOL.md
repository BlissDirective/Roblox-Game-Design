# RAID_PROTOCOL.md

> The match-based PvP raid flow. MemoryStore key names, MessagingService
> topics, snapshot rules, reserved-server lifecycle, reward routing.
>
> **Status:** Phase E1 — infrastructure layer (queue, match, reserve, timer,
> outcome relay). E2 fills in the actual raid gameplay (waves attacking
> the snapshot during the round).
>
> **Place topology (per ADR-009):** Two PlaceIds in the same Universe.
> `default.project.json` builds the **main** `.rbxl` (public servers,
> matchmaker, all retention systems). `raid.project.json` builds the
> **raid** `.rbxl` (reserved-server-only round runner). Both bootstraps
> live in `src/server/init.server.luau` and branch on
> `game.PrivateServerId` — the deployment topology guarantees the right
> branch fires (main place servers are public, raid place servers are
> reserved). `Constants.RAID.MainPlaceId` / `RaidPlaceId` are 0
> placeholders until Phase H.

---

## Architecture in one paragraph

An attacker queues from the main place. A leader-elected matchmaker
(one server per universe per `MatchmakerSentinelTtl` seconds) pairs them
with a random raidable target — V1 only matches against currently-online
defenders, so the match payload is delivered via MessagingService to both
home servers. The defender's home captures a snapshot of its `baseLayout +
credits-at-time` and writes it to `MemoryStoreService.SortedMap.OutpostRaidSnapshots`.
The attacker's home polls for the snapshot, then `ReserveServerAsync` +
`TeleportToPrivateServer` puts the attacker into a raid place reserved
instance. The raid place runs a 5-minute round, then publishes a single
`outpost.raid.outcome` MessagingService payload. Both home servers listen;
whichever holds the attacker / defender Player object applies the
authoritative profile mutation. **The raid server never writes either
profile directly** (ADR-008).

---

## MemoryStoreService keys

| Key (SortedMap) | TTL | Writers | Readers |
|---|---|---|---|
| `OutpostRaidQueue` | `Constants.RAID.QueueEntryTtl` (90s) | Attacker's home (on enqueue) | Matchmaker leader |
| `OutpostRaidableTargets` | `Constants.RAID.TargetsTtlSeconds` (90s) | Every main server (heartbeat every 30s) | Matchmaker leader |
| `OutpostRaidSnapshots` | `Constants.RAID.SnapshotTtl` (180s) | Defender's home (on match) | Attacker's home (poll) → Raid server (load on attacker arrival) |

| Key (HashMap) | TTL | Writers | Readers |
|---|---|---|---|
| `OutpostRaidSentinels[raid.matchmaker.leader]` | `Constants.RAID.MatchmakerSentinelTtl` (15s) | Whichever server claims it via `UpdateAsync` (writes its own JobId) | Each matchmaker tick (re-claims own lease or yields to current leader) |

## MessagingService topics

| Topic | Direction | Payload | Listener |
|---|---|---|---|
| `outpost.raid.matched` | leader → home servers | `{ attackerUserId, defenderUserId, snapshotId, matchedAt }` | `RaidMatchmaker.ExecuteMatchOnHome` (every main server) |
| `outpost.raid.outcome` | raid server → home servers | `{ attackerUserId, defenderUserId, attackerWon, attackerCreditsDelta, defenderCreditsDelta, endedAt }` | `RaidRewardService.handleOutcome` (every main place server) |

Both topics are universe-wide. Listeners filter by `Players:GetPlayerByUserId`.

## Match flow (sequence)

```
Attacker (main A)        Defender (main B)        Leader (main C)        Raid place (R)
       │                          │                       │                      │
       ├── RaidQueue("queue") ──▶ MemoryStore queueMap                            │
       │                          ├── targetsMap heartbeat ──▶ MemoryStore        │
       │                                                  │                      │
       │                                                  ├── claim sentinel ◀── │
       │                                                  ├── pull queue+targets │
       │                                                  ├── pair               │
       │                                                  ├── publish "matched"  │
       │ ◀───────────────── outpost.raid.matched ──────── │                      │
       │                          │                       │                      │
       │                          ├── Capture+Store snapshot ──▶ MemoryStore     │
       │ ◀── poll ────── snapshot ──── (returns) ──────────────────────────────  │
       │                                                                         │
       ├── ReserveServerAsync ──────────────────────────────────────────▶        │
       ├── TeleportToPrivateServer ──────────────────────────────────────▶ R     │
       │                                                                         │
       │                                                          ┌─────────────▶│
       │                                                          │   round runs │
       │                                                          │   for        │
       │                                                          │   roundSecs  │
       │                                                          └──────────────│
       │                                                                         │
       │ ◀───────────────── outpost.raid.outcome ─────────────────────────────  │
       │                          │ ◀── outcome ──────────────────────────────  │
       │                                                                         │
       ├── apply attacker side                                                   │
       │                          ├── apply defender side                        │
       │                                                                         │
       ◀── Teleport home ──────────────────────────────────────────────────────  │
```

## Critical invariants

1. **Single authoritative writer per profile.** Only the home server
   currently holding a player's `Player` object writes their profile.
   The raid server is *never* an authoritative writer. (ADR-008)
2. **Snapshot fidelity (V1 minimum).** baseLayout (positions + ids) and
   credits-at-snapshot. No live drone state, no live currency mutation.
3. **Outcome idempotency.** The reward relay dedupes on
   `(attackerUserId, defenderUserId, endedAt)` for 10 minutes per
   home server (see `RaidRewardService.seenOutcomes`).
4. **Online-target-only (V1).** Raids fire only when the matchmaker
   leader can pair an attacker with an online defender. Offline
   targets are deferred to V1.5+ (would require a `PendingRaidRewards`
   DataStore for the defender-side reward).
5. **Voice gates only inside the raid place.** E4 wires the gate via
   the place-level `VoiceChatService` config. The main place's voice
   stays disabled.

## Failure modes & recovery

| Failure | Effect | Recovery |
|---|---|---|
| MemoryStore queue write fails | Enqueue returns `{ ok = false, error = "queue write failed" }`; client UI shows error | User retries via the button |
| No viable target found | Attacker stays queued; deadline pop after `QueueDeadlineSeconds` (30s) sets state.error = "deadline" | E2's PvE wave fallback runs in main place when attacker's `error == "deadline"` |
| Defender goes offline mid-raid | `outpost.raid.outcome` arrives at no defender home; defender side is dropped | Acceptable for V1; V1.5+ persists pending reward via DataStore |
| Snapshot poll times out (5s) | Attacker queue state set to `error = "snapshot unavailable"`; no teleport | User retries via the button |
| `ReserveServerAsync` fails | Logged warn; queue state set to `error = "snapshot unavailable"` | User retries; no real-money side effects |
| Raid server crashes mid-round | No outcome published; both sides receive nothing | Acceptable for V1 (5-min round, low stakes per round); F1 may add a `RoundExpiry` watchdog |
| Outcome arrives twice (MessagingService at-least-once) | Dedupe set drops the duplicate | Built into `handleOutcome` |

## V1 placeholder values (Phase G/E2 tunes)

| Constant | V1 value | Comment |
|---|---|---|
| `AttackerWinCredits` | 1000 | Flat win reward. Phase G replaces with banded curve from `config/balance/raid_rewards.json`. |
| `AttackerLossCredits` | 100 | Consolation for a lost raid (or one bailed mid-round). |
| `DefenderRaidedCredits` | 250 | Asynchronous defense reward. Phase G ties to base value-at-snapshot. |
| `RoundSeconds` | 300 | 5 min per brainstorm §2.1. |
| `RaidPlaceId` | 0 | REPLACE_BEFORE_LAUNCH at Phase H. |
