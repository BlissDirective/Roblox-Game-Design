# INCIDENT_RESPONSE.md

> Runbook for live-ops issues: DataStore corruption, exploit reports,
> monetization bugs. **Read top-to-bottom before V1 launch.**

**Status:** Stub. Filled during Phase H. The skeleton below names the four
incident classes and the immediate first move for each.

---

## Severity definitions

| Tier | Description | First-response time |
|---|---|---|
| **SEV-1** | Game unplayable / players losing real money / mass save loss | Within 15 min |
| **SEV-2** | Specific feature broken, workaround exists | Within 2 hr |
| **SEV-3** | Cosmetic / minor balance / single-player edge case | Next dev session |

## Incident classes

### 1. DataStore corruption / save loss

1. Halt new logins (close server, or set a `Constants.MAINTENANCE` gate).
2. Read affected players' last-known-good versions via Open Cloud Datastores
   API.
3. Restore from versioned history; do not overwrite blind.

### 2. Exploit report (currency / item duplication)

1. Reproduce in Studio with a 2-client test if possible.
2. Patch + redeploy via `release.yml` per `playbooks/PUBLISHING.md`.
3. Ledger-audit (`PurchaseLedger`, `CreditsLedger`, `ClanStashLedger`) for the
   affected window. Roll back illicit gains where ledgered.

### 3. `ProcessReceipt` failure (real money charged, no item granted)

1. Cross-reference Roblox developer dashboard receipts against
   `PurchaseLedger`. Anything in dashboard but missing from ledger gets
   manually granted via a one-shot script, then ledgered.
2. Postmortem before the next release.

### 4. Voice chat moderation incident

1. Roblox handles moderation upstream. File the report through the platform.
2. If reports spike, gate `Voice.VoiceGate` behind verified-account.

---

## Postmortem template

Every SEV-1 and SEV-2 gets a postmortem issue using the **bug_report**
template, tagged `postmortem`. Required sections: timeline, blast radius,
root cause, fix, prevention.
