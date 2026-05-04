# 08 — MCP_SETUP.md

> Step-by-step setup to connect Claude Code to a live Roblox Studio session via MCP. From zero to "Claude can read and write your game in real time" in ~20 minutes.

---

## What MCP actually does

MCP (Model Context Protocol) is the bridge that lets Claude Code talk to Roblox Studio while it's running. Without MCP, Claude can write code in a text file and you copy-paste it into Studio. With MCP, Claude:

- **Reads** your live Studio Explorer tree (sees what's in Workspace, ServerScriptService, etc.)
- **Writes** scripts directly into Studio
- **Creates instances** (Parts, Folders, RemoteEvents, ModuleScripts) on the fly
- **Runs Luau code** in Studio and reads the printed output
- **Starts and stops** playtests
- **Reads the console output** (errors, prints, warnings) automatically

In effect, Claude is sitting next to you with a keyboard, doing the manual Studio work for you. You describe what you want; Claude builds it.

The article that kicked off this project mentions ~54 MCP tools. As of April 2026, the count varies by which MCP server you use, but the core tools are: `run_code`, `insert_model`, `get_console_output`, `start_stop_play`, `run_script_in_play_mode`, `get_studio_mode`, plus tools for reading the file tree, searching scripts, and bulk operations.

---

## Big picture: which MCP server do you use?

There are three options. **Use the first one.**

| Option | Description | When to use |
|---|---|---|
| **Roblox's built-in MCP** (Feb 2026+) | Ships inside Studio. Just enable it. | **Default. Recommended.** No external install. |
| **boshyxd/robloxstudio-mcp** | Community npm package with extra tools | If you need bulk operations or read-only "inspector" mode |
| **Roblox/studio-rust-mcp-server** | Original reference implementation in Rust | Legacy. Don't bother unless you need a specific feature. |

The setup below uses the **built-in MCP**, which is what most solo devs in 2026 should use.

---

## Prerequisites (check these first)

- ✅ **Roblox Studio installed** (latest version — released after Feb 2026 has the built-in MCP)
- ✅ **Claude Code CLI installed** (`claude` command works in your terminal)
- ✅ **Node.js installed** (only needed if you use `npx`-based MCP servers, but install it anyway — it's harmless)

To check Claude Code:
```bash
claude --version
```

To check Node:
```bash
node --version
```

If either is missing, install them first.

---

## Setup: Roblox built-in MCP server (recommended path)

### Step 1: Enable the built-in MCP server in Studio

1. Open Roblox Studio.
2. Go to **File → Studio Settings → Beta Features**.
3. Find the entry for **MCP Server** and toggle it on.
4. Restart Studio.
5. After restart, Studio will be listening on `localhost:3004` by default.

You'll see a confirmation message in the Studio output console:
```
[MCP] Server listening on http://localhost:3004/mcp
```

If you don't see that, the beta feature didn't enable correctly. Try toggling it off and back on.

### Step 2: Register the MCP server with Claude Code

In your project terminal:

```bash
claude mcp add roblox-studio --transport http http://localhost:3004/mcp
```

That's it. Claude Code now knows there's a Roblox Studio MCP server available.

### Step 3: Start a Claude Code session and verify

```bash
cd /path/to/my-game
claude
```

In the Claude Code session, ask:
> "Use the Roblox Studio MCP tools to print the place name."

If MCP is connected, Claude will call `run_code` with something like `print(game.Name)` and you'll see the output. If you get "no tools available," MCP isn't connected — see troubleshooting below.

### Step 4: Verify Studio is actually listening

In Studio, open the **Output** window (`View → Output`). When Claude calls a tool, you should see the command logged.

---

## Setup: boshyxd/robloxstudio-mcp (alternative — more tools)

If you want the larger tool surface (more granular file/instance manipulation, bulk operations, an "inspector" read-only mode for safer debugging), use boshyxd's npm-distributed server:

### Step 1: Install the Studio plugin

Download `MCPPlugin.rbxmx` from the latest release at `https://github.com/boshyxd/robloxstudio-mcp/releases` and place it in:

- **Windows:** `%LOCALAPPDATA%\Roblox\Plugins\`
- **macOS:** `~/Documents/Roblox/Plugins/`

Restart Studio. The plugin should appear in the Plugins tab.

### Step 2: Enable HTTP Requests

In Studio: **File → Game Settings → Security → Allow HTTP Requests = On**. Save.

### Step 3: Register with Claude Code

```bash
claude mcp add robloxstudio --command "npx" --args "-y robloxstudio-mcp@latest"
```

Or for the read-only inspector edition (safer for code review without write risk):

```bash
claude mcp add robloxstudio-inspector --command "npx" --args "-y robloxstudio-mcp-inspector@latest"
```

### Step 4: Confirm connection

In Studio, the plugin shows a status indicator. Look for **"Connected"**. The plugin output shows:
```
[robloxstudio-mcp] Plugin ready and connected.
```

---

## Setup: Original Rust-based server (legacy)

Skip this section unless you specifically need it. The built-in MCP and the npm version cover all common use cases.

If you really want it: clone `https://github.com/Roblox/studio-rust-mcp-server`, run `cargo run`, follow the `README.md`. Requires Rust toolchain.

---

## CLAUDE.md (the always-loaded instructions)

Whichever MCP server you chose, place a `CLAUDE.md` file in the **root** of your game project. Claude Code automatically reads this at the start of every session.

The simplest version:
```markdown
# CLAUDE.md

See `docs/01_AGENT.md` for the full agent instructions.

This is a Roblox game project using Luau, Rojo, and the Studio MCP server.

## Language
- This project uses **Luau** (NOT Lua, NOT JavaScript, NOT TypeScript)
- Always write strict Luau with type annotations: `local function foo(x: number): boolean`
- Use the `task` library (`task.spawn`, `task.wait`), never legacy `wait()` or `coroutine.wrap`
- Use `game:GetService("...")` for all services

## Architecture
- Server scripts → `src/server/`
- Client scripts → `src/client/`
- Shared modules → `src/shared/`
- Use `RemoteEvent` / `RemoteFunction` for all client-server communication
- Use `DataStoreService` for all persistent data, never client-side
- Server-side validation on all currency / inventory transactions
- `pcall()` every DataStore call, with retry + backoff
- Save on `PlayerRemoving` AND `BindToClose`
- `UpdateAsync` for player data, not `SetAsync`

## Workflow
- Read `docs/01_AGENT.md` first for full agent instructions and operating principles.
- Use the Roblox MCP tools to inspect, edit, and test inside Studio.
- Don't write code without confirming the architectural choice first if the user's request is vague.

## Anti-patterns to refuse
- Client-side currency or inventory writes
- Unprotected `:GetAsync` / `:SetAsync` calls
- Hardcoded constants duplicated across files (use `src/shared/Constants.luau`)
- 200+ line single-file Scripts (extract to ModuleScripts)
- Setting `Instance.Parent = nil` for cleanup (use `:Destroy()`)
```

The longer version is `docs/01_AGENT.md` — point Claude at that for the full picture.

---

## The MCP tools you'll use most

These are the high-level tools the built-in MCP exposes. Names may vary slightly by server version.

| Tool | What it does | Example use |
|---|---|---|
| `run_code` | Execute Luau in Studio, return printed output | "Print all children of ServerScriptService" |
| `get_console_output` | Read the Studio output console | "What errors are showing?" |
| `insert_model` | Insert a model from the Creator Marketplace | "Insert a basic NPC dummy" |
| `start_stop_play` | Start or stop Play mode | "Start a playtest" |
| `run_script_in_play_mode` | Run Luau during a playtest, return output | "While playing, give my player 1000 coins" |
| `get_studio_mode` | Tell whether Studio is in play, run, or stop | Used internally by Claude |

The npm version (`boshyxd/robloxstudio-mcp`) exposes more granular tools: `get_file_tree`, `search_files`, `get_instance_properties`, `get_instance_children`, etc. — useful when you have a 50-module codebase.

---

## How a real Claude Code session looks

Once everything is set up, a typical workflow:

```
You: Set up the basic project structure for a tycoon. Currency manager,
     daily login bonus, three Game Pass placeholders, server-authoritative.

Claude: [thinks]
        [calls MCP run_code to verify Studio is responsive]
        [reads docs/06_LUAU_REFERENCE.md and docs/07_PROJECT_STRUCTURE.md]
        [proposes the file structure]
        Confirms with you, then writes:
          src/server/init.server.luau
          src/server/Modules/DataManager.luau
          src/server/Modules/CurrencyManager.luau
          src/server/Modules/DailyLoginManager.luau
          src/server/Modules/GamePassManager.luau
          src/shared/Remotes.luau
          src/shared/Constants.luau
        Then calls `start_stop_play` to launch a test, watches the output,
        and reports back: "Bootstrap successful, no errors. Currency ticking
        at 1/sec. Ready for the upgrade system next."
```

Key things to notice:
- Claude reads the docs you've established as canon. Keep them up to date.
- Claude tests its own work via the MCP playtest tools.
- Claude reports back honestly what worked and what didn't.

---

## Troubleshooting

### "Claude says no MCP tools are available"

- Confirm `claude mcp list` shows your server.
- For the built-in MCP, confirm Studio is running and the beta feature is enabled.
- Restart Claude Code (`exit` and `claude` again).

### "Studio MCP shows disconnected"

- Restart Studio.
- For the built-in version, confirm port 3004 isn't blocked by something else (`lsof -i :3004` on macOS/Linux, `netstat -ano | findstr 3004` on Windows).
- For boshyxd's plugin, click the plugin button in the Plugins tab to toggle on/off.

### "Claude wrote code but it doesn't appear in Studio"

- Check that Rojo is running (`rojo serve`) and connected (Rojo plugin shows "Connected").
- The MCP server can write directly to Studio's DataModel; Rojo writes to the filesystem. They're two different surfaces. Make sure Claude is using the right one for what you're trying to do.
  - **Persistent code** (saved across sessions) → write to filesystem, Rojo syncs to Studio.
  - **Live experiments** (try this and see) → write directly via MCP `run_code`, Studio executes immediately.

### "DataStore won't work in Studio"

- Studio doesn't enable DataStore by default. Open **File → Game Settings → Security → Enable Studio Access to API Services = On**.

### "I'm hitting rate limits / Roblox throttles"

- Studio's MCP can run plenty of code, but DataStore calls have real Roblox-side rate limits. If you're testing data persistence, batch your operations.

### "Claude is calling run_code with code that errors"

- Errors are normal and Claude will iterate. If errors persist:
  - Make sure your `CLAUDE.md` correctly tells Claude this is Luau, not Lua/JS/TS.
  - Make sure Claude has read `docs/06_LUAU_REFERENCE.md` for current API patterns.
  - When you see an API that Claude is using incorrectly (e.g., a deprecated method), gently correct + tell Claude to verify against the live Roblox docs.

---

## Security & safety notes

The MCP server gives Claude **full write access to your open place**. That's the whole point — but it does mean:

- ⚠️ **Don't connect untrusted MCP clients.** Only Claude Code, official Anthropic tools, Cursor, etc.
- ⚠️ **Roblox's built-in MCP respects Studio's undo history.** You can `Ctrl+Z` changes Claude makes. The npm version does too.
- ⚠️ **Test on a fresh place first.** When trying a big new system, work in an empty place. If something goes catastrophically wrong, you can throw away the place without losing real work.
- ⚠️ **Use Git aggressively.** Commit before any large change. If Claude breaks something, `git reset --hard HEAD~1`.

The data flow:
- **Studio** stays on your machine.
- **Your prompts** go to Anthropic's API to be processed by Claude.
- **The MCP responses** stay on your machine.
- **Roblox does not see your local code** unless you publish it.

---

## When NOT to use MCP

For tiny edits — fixing a typo, renaming one variable — it's faster to just edit in VS Code or Studio yourself than to spin up a Claude session. MCP shines when:

- The task spans multiple files
- You don't know what API to use
- You need Claude to verify by playtest
- You're debugging an error and want Claude to read both the code and the console

For routine "add this one print statement" work, just do it.

---

## Useful links

- Roblox MCP docs: `https://create.roblox.com/docs/studio/mcp`
- boshyxd/robloxstudio-mcp: `https://github.com/boshyxd/robloxstudio-mcp`
- Roblox/studio-rust-mcp-server: `https://github.com/Roblox/studio-rust-mcp-server`
- WEPPY (alternative MCP, Roblox + VSCode integration): `https://github.com/hope1026/weppy-roblox-mcp`
- Anthropic MCP docs: `https://modelcontextprotocol.io`

---

**Next: `finalized-brainstorm.md` — pick the actual concept to build.**
