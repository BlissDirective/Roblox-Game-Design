# RAID_PROTOCOL.md

> The match-based PvP raid flow. `MessagingService` topic keys, raid snapshot
> rules, reserved-server lifecycle, reward distribution.

**Status:** Stub. Populated by Phase E1.

---

## Match flow (planned, fills in during Phase E)

1. Client → `RaidMatchmaker:Queue` Remote.
2. Matchmaker server (elected via `MemoryStoreService` sentinel) pairs queue
   entries.
3. `TeleportService:ReserveServer` allocates a raid instance.
4. `RaidSnapshot` loads target's base into the reserved server. Target's
   live server is **untouched**.
5. 5-minute round timer; rewards distributed on completion via
   `RaidRewardService` (loads `config/balance/raid_rewards.json`).
6. Empty queue → `WaveDirector` fires NPC alien wave fallback within 10s.

## Critical invariants

- Defender's authoritative DataStore profile is **never** written by raid
  servers. Raid outcomes affect the defender via a single
  `RaidRewardService` call routed through the defender's home server.
- Snapshot fidelity: positions, ids, currency-at-time. No live drone state.
- Voice chat (`Voice.VoiceGate`) enables only inside the reserved server.
