# Security Policy

## Reporting a vulnerability

If you discover an exploit, anti-cheat bypass, DataStore corruption vector, or other security issue in Outpost-7, **do not open a public GitHub issue.**

Instead, report it privately by:

1. Opening a [private security advisory](https://github.com/BlissDirective/Roblox-Game-Design/security/advisories/new) on GitHub, **or**
2. Emailing the maintainer directly (contact in repo profile).

Please include:

- A clear description of the issue
- Steps to reproduce (place version, client platform, exact actions)
- Impact assessment (what an attacker could do)
- A suggested fix if you have one

You can expect:

- Acknowledgement within **72 hours**
- A status update within **7 days**
- Public disclosure (with credit, if you want it) only **after** a fix has shipped to the live experience

---

## Scope

In scope:
- Server-side validation bypasses (e.g., placing buildables off-plot, granting yourself currency, double-claiming rewards)
- DataStore corruption / loss vectors
- Remote spam that crashes the server or other clients
- Receipt double-grant / `ProcessReceipt` idempotency failures
- Raid snapshot leaks (seeing the target's real base)
- Voice chat / matchmaking abuse

Out of scope:
- Client-side performance issues without security impact
- Visual glitches
- Roblox-platform-level issues (report those to Roblox)
- Social engineering of other players

---

## Hall of fame

Reporters who responsibly disclose will be credited here once a fix ships.

*(empty for now — V1.0 not yet launched)*
