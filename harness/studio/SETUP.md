# Studio host setup (owner does this once)

The Studio Operator agent drives Roblox Studio through the built-in Studio
MCP server for everything scriptable and through computer use for
screenshots and dialogs. Studio runs on Windows/macOS only, so the "Studio
host" must be one of:

| Option | When | Notes |
|---|---|---|
| **A. Grok Bot cloud computer (if it is a Windows desktop)** | Preferred if available | Studio + MCP + agent on one machine; no tunnel. Confirm the cloud computer can run a GPU-less Windows desktop app; Studio needs ~4 GB RAM and a DirectX-capable renderer (software rendering is acceptable for audits). |
| **B. A dedicated Windows VM or spare PC you own** | If A is Linux-only | The agent reaches it over remote desktop (its computer-use target) *and* the MCP endpoint over a private network (Tailscale). Never your daily machine. |

Either way: **this machine is logged into the harness bot account, never
your own.**

## 1. Roblox side (Creator Dashboard, as the owner)

1. Create the **staging experience** as a separate experience under the
   group that owns Outpost-7 (its own universe; two places: main + raid,
   mirroring production). Record `STAGING_UNIVERSE_ID`,
   `STAGING_PLACE_ID`, `STAGING_RAID_PLACE_ID` as GitHub variables.
   (`release.yml` already takes `STAGING_PLACE_ID`; the raid staging place
   is optional in V1.)
2. Create the **harness bot account** (`Outpost7Builder` or similar). No
   Robux, no payment method, no group membership. Unique password and
   authenticator-app 2FA; store both only in your password manager.
3. Staging experience → **Collaborators** → add the bot account with
   **Edit**. Do **not** add it to the group. Do not touch production's
   collaborators.
4. Staging experience → Game Settings → Security → *Enable Studio Access
   to API Services* = On (staging has its own DataStores; production is
   untouched).

## 2. Studio on the host

1. Install Roblox Studio (latest; the built-in MCP server ships in
   builds since Feb 2026).
2. Log in as the **bot account**. With Grok Bot, do this yourself through
   the "take over" hand-off so the agent never sees the credentials.
3. File → Studio Settings → Beta Features → **MCP Server** = On. Restart
   Studio. Output window should show `[MCP] Server listening on
   http://localhost:3004/mcp`.
4. Plugins: **Rojo** (official, from the Creator Store) only. No others.
5. Open the staging **main** place once from *File → Open from Roblox* so
   it appears in Recent.
6. Optional but recommended: Studio Settings → Rendering → *Graphics Mode
   = Automatic*, *Quality Level 10* (screenshots then match what a
   mid-range phone shows).

## 3. Agent side (Grok Bot Studio Operator)

- Option A: the MCP client on the same machine registers
  `http://localhost:3004/mcp`.
- Option B: install Tailscale on both machines; the agent registers
  `http://<studio-host-tailscale-ip>:3004/mcp`. Bind Studio's MCP to
  localhost only and expose it through a Tailscale serve rule restricted
  to the agent's node; never a public port, never a public tunnel.
- Give the agent a **read-only** clone of the repo on the host (a deploy
  key with read access). It pulls `harness/studio/*.luau` from there; it
  never pushes from the host.

## 4. What the audit does to the place

`audit_element.luau` creates `Workspace.HarnessAudit` (a pad far from the
plots at `Constants.WORLD`-safe coordinates), inserts the element via
`InsertService:LoadAsset(id)` (group-owned asset in a group-owned
experience), measures it, and prints a JSON report. `screenshot_rig.luau`
positions the camera. `CONFIG.cleanup = true` destroys the pad. **The
Operator never saves the place** after an audit; the staging place is
published by CI from the repo, so anything left in it is overwritten on
the next release anyway.

## 5. Saving from Studio

Not part of the loop in V1. If a future step needs "Save to Roblox"
(e.g. committing a Studio-authored `.rbxm` for a rigged character), the
owner adds an explicit line here first. Until then the answer is no.

## 6. Verification you should do before the first dry run

- [ ] Bot account cannot open the production experience (try it; it
      should be denied).
- [ ] Bot account has no Robux and no payment method.
- [ ] MCP `run_code` with `print(game.Name, game.PlaceId)` returns the
      staging place.
- [ ] `audit_element.luau` with a known asset id (any group-owned Decal
      will do) prints `HARNESS_AUDIT` JSON.
- [ ] A screenshot from the agent lands in the owner's chat.
