# 07 — PROJECT_STRUCTURE.md

> The exact file structure, naming conventions, and tooling setup for the project. This is opinionated — there is one right way for a solo dev. Follow it.

---

## Why this matters

Your project will grow from "one currency manager" to ~30 modules across server / client / shared. If files are scattered and naming is inconsistent, Claude wastes tokens looking for things, and you spend nights chasing bugs that are really just "I have two files named the same thing in different folders."

This doc locks in:
- Repo layout
- File naming
- Module organization
- Rojo configuration
- Git setup
- The development loop

---

## Tools you will install (one-time)

| Tool | Purpose | How |
|---|---|---|
| **Roblox Studio** | The 3D editor + runtime | Download from `roblox.com/create` |
| **Visual Studio Code** (or Cursor) | Your code editor | Download from `code.visualstudio.com` |
| **Rojo** | Filesystem ↔ Studio sync | Install via Aftman or `cargo install rojo` |
| **Git** | Version control | Install from `git-scm.com` |
| **Claude Code** | Your AI dev partner | Install per Anthropic's docs |
| **Roblox Studio MCP** | Live bridge between Claude Code and Studio | Built-in (Feb 2026+). See `08_MCP_SETUP.md`. |
| **Luau LSP** (VS Code extension) | Type-checking, autocomplete | Marketplace |
| **Selene** *(optional)* | Luau linter | `cargo install selene` |
| **StyLua** *(optional)* | Luau formatter | `cargo install stylua` |

---

## Repository layout (the canonical structure)

```
my-game/
├── .git/
├── .gitignore
├── README.md                      ← project intro for future-you
├── CLAUDE.md                      ← copy of 01_AGENT.md (Claude Code reads this)
├── default.project.json           ← Rojo config
├── aftman.toml                    ← tool-version pinning (optional)
├── selene.toml                    ← linter config (optional)
├── stylua.toml                    ← formatter config (optional)
│
├── docs/                          ← these reference markdown files
│   ├── 00_START_HERE.md
│   ├── 01_AGENT.md                ← keep in sync with CLAUDE.md
│   ├── 02_ROBLOX_PLATFORM.md
│   ├── 03_GAME_GENRES.md
│   ├── 04_VIRAL_MECHANICS.md
│   ├── 05_MONETIZATION.md
│   ├── 06_LUAU_REFERENCE.md
│   ├── 07_PROJECT_STRUCTURE.md
│   ├── 08_MCP_SETUP.md
│   └── 09_BRAINSTORM.md
│
├── src/
│   ├── server/                    → ServerScriptService
│   │   ├── init.server.luau       ← bootstrap that requires + inits modules
│   │   └── Modules/               → ModuleScripts (server-only logic)
│   │       ├── DataManager.luau
│   │       ├── CurrencyManager.luau
│   │       ├── UpgradeManager.luau
│   │       ├── DailyLoginManager.luau
│   │       ├── GamePassManager.luau
│   │       ├── LeaderboardManager.luau
│   │       ├── AntiExploit.luau
│   │       └── ReplicationManager.luau
│   │
│   ├── client/                    → StarterPlayerScripts
│   │   ├── init.client.luau       ← client bootstrap
│   │   └── Modules/               → client-only modules
│   │       ├── HudController.luau
│   │       ├── ShopController.luau
│   │       ├── NotificationController.luau
│   │       ├── CameraController.luau
│   │       └── HudFormat.luau     ← number formatting, etc.
│   │
│   └── shared/                    → ReplicatedStorage
│       ├── Remotes.luau           ← all RemoteEvent / RemoteFunction definitions
│       ├── Constants.luau         ← config values used by both server and client
│       ├── Types.luau             ← shared type definitions
│       └── Modules/
│           ├── Signal.luau        ← lightweight event class
│           ├── Promise.luau       ← optional, if you need async chaining
│           └── ItemRegistry.luau  ← shared item / pet / unit definitions
│
├── assets/                        ← .rbxm / .rbxmx model files
│   ├── ui/
│   ├── effects/
│   └── characters/
│
├── place/                         ← built place files (gitignored output)
│   └── game.rbxlx
│
└── scripts/                       ← workflow utility scripts (optional)
    └── build.sh
```

### Why this layout

- **Single `src/` folder** that Rojo maps to the Roblox tree. Easy to grep, easy to git diff.
- **`server/`, `client/`, `shared/` separation** mirrors the trust boundary. If you accidentally put `MarketplaceService:PromptGamePassPurchase` in `server/`, it won't work — it's a client-side API. The folder structure forces correct thinking.
- **`Modules/` subfolder under each context** — makes it obvious which file is the bootstrap (`init.server.luau`) and which is library code (everything in `Modules/`).
- **`docs/` mirrors what you have now.** `CLAUDE.md` is a copy of `01_AGENT.md` so Claude Code auto-loads it without you having to point.
- **`assets/` for binary models** that Rojo can sync. You'll pull these from the Creator Marketplace or build them yourself in Studio and export.

---

## File naming conventions

### File extensions (Rojo's contract)

| Filename ends in | Becomes a | Lives in |
|---|---|---|
| `Foo.server.luau` | `Script` (runs on server) | server/ |
| `Foo.client.luau` | `LocalScript` (runs on client) | client/ |
| `Foo.luau` | `ModuleScript` (require'd by others) | server/Modules, client/Modules, shared/, etc. |
| `init.server.luau` | the parent folder becomes a `Script` | server/ |
| `init.client.luau` | the parent folder becomes a `LocalScript` | client/ |
| `init.luau` | the parent folder becomes a `ModuleScript` | shared/Modules/Foo/init.luau |

Use `.luau`, not `.lua`. Both work, but `.luau` is the modern extension and gets better IDE support.

### Module naming

- **PascalCase** for files (`DataManager.luau`, `CurrencyManager.luau`)
- **PascalCase** for module table return (`local DataManager = {}`)
- **camelCase** for functions and variables (`local function loadPlayer(player)`)
- **UPPER_SNAKE** for constants (`local TICK_RATE = 1`)
- **Singular** for managers and controllers (`UpgradeManager`, not `UpgradesManager`)
- **Plural** for collections (`local activePlayers = {}`)

### Boolean naming

- Prefix with `is`, `has`, `can`, `should`: `isActive`, `hasPass`, `canPurchase`, `shouldSave`.
- Functions returning booleans: `function ownsPass(...)` or `function isAuthorized(...)`.

---

## Module organization patterns

### Pattern 1: The Singleton Manager

Most server systems are singletons. One DataManager. One CurrencyManager. One per game.

```lua
--!strict
local Players = game:GetService("Players")

local DataManager = {}

local cache: {[number]: any} = {}

function DataManager.Init()
    Players.PlayerAdded:Connect(...)
end

function DataManager.GetData(player: Player)
    return cache[player.UserId]
end

return DataManager
```

The `Init()` function is called once at startup. After that, other modules call the public functions.

### Pattern 2: The Class-like Module

For per-instance data (e.g., a Boss type, a Pet type):

```lua
--!strict
local Pet = {}
Pet.__index = Pet

export type Pet = typeof(setmetatable({} :: {
    id: string,
    name: string,
    multiplier: number,
}, Pet))

function Pet.new(id: string, name: string, multiplier: number): Pet
    local self = setmetatable({}, Pet)
    self.id = id
    self.name = name
    self.multiplier = multiplier
    return self
end

function Pet:applyTo(player: Player)
    -- ...
end

return Pet
```

### Pattern 3: The Pure Library

Stateless utility functions:

```lua
--!strict
local NumberFormat = {}

function NumberFormat.WithCommas(n: number): string
    -- ...
end

function NumberFormat.Abbreviated(n: number): string
    -- 1500 → "1.5K", 2_500_000 → "2.5M"
end

return NumberFormat
```

### Pattern 4: The Bootstrap Script

This is the only kind of `Script` / `LocalScript` you should have. They `require` modules and start them.

```lua
--!strict
-- src/server/init.server.luau
local DataManager = require(script.Modules.DataManager)
local CurrencyManager = require(script.Modules.CurrencyManager)
local UpgradeManager = require(script.Modules.UpgradeManager)
local GamePassManager = require(script.Modules.GamePassManager)
local DailyLoginManager = require(script.Modules.DailyLoginManager)
local AntiExploit = require(script.Modules.AntiExploit)

DataManager.Init()
CurrencyManager.Init()
UpgradeManager.Init()
GamePassManager.Init()
DailyLoginManager.Init()
AntiExploit.Init()

print("[Server] Bootstrap complete.")
```

---

## Rojo: filesystem ↔ Studio sync

Rojo is the bridge that lets you write code in VS Code while it appears live in Studio.

### Install (one-time)

**Option A: Aftman** (recommended — pins versions per project)

```bash
# Install aftman from https://github.com/LPGhatguy/aftman
aftman init
aftman add rojo-rbx/rojo
aftman install
```

**Option B: cargo**

```bash
cargo install rojo
```

**Option C: standalone binary** — download from `https://github.com/rojo-rbx/rojo/releases`.

### `default.project.json` (canonical config)

```json
{
  "name": "MyGame",
  "tree": {
    "$className": "DataModel",
    "ServerScriptService": {
      "$path": "src/server"
    },
    "ReplicatedStorage": {
      "$path": "src/shared"
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "$path": "src/client"
      }
    },
    "Workspace": {
      "$properties": {
        "FilteringEnabled": true,
        "StreamingEnabled": true
      }
    },
    "Lighting": {
      "$properties": {
        "Technology": "Future"
      }
    }
  }
}
```

This says:
- Everything in `src/server/` mirrors into `ServerScriptService`
- Everything in `src/shared/` mirrors into `ReplicatedStorage`
- Everything in `src/client/` mirrors into `StarterPlayerScripts`
- Workspace gets sane defaults

### Studio plugin

Install once via the Rojo command palette in VS Code, OR download the plugin from `https://github.com/rojo-rbx/rojo/releases` and drop into Studio's plugins folder.

### The dev loop

```bash
# In your project root, in a terminal
rojo serve
```

Then in Roblox Studio:
1. Open a fresh place
2. Click the Rojo plugin icon → **Connect**
3. Studio is now live-syncing with your filesystem

Now: edit a `.luau` file in VS Code → save → see the change in Studio within milliseconds.

### Building a place file (for publishing)

```bash
rojo build -o place/game.rbxlx
```

Then open `place/game.rbxlx` in Studio and **Publish to Roblox**. (You publish manually — Rojo doesn't push to the live game.)

---

## Git setup

### `.gitignore`

```gitignore
# Rojo build outputs
place/

# Studio temp files
*.rbxlx.lock
sourcemap.json

# Tool installs (managed by aftman per-project)
.aftman/

# OS junk
.DS_Store
Thumbs.db

# Editor
.vscode/
.idea/

# Logs
*.log
```

### Branch strategy (solo)

For a solo project, keep it simple:

- `main` = always shippable
- Work directly on `main` for small changes
- For larger features, branch (`feat/upgrade-system`) and merge when done

You're not coordinating with anyone. Don't over-engineer the workflow.

### Commit hygiene

Even solo, write commits like another human will read them:

```
✅ Good: "feat(currency): add rebirth multiplier to passive income"
✅ Good: "fix(datastore): handle nil cache after disconnect race"
❌ Bad:  "stuff"
❌ Bad:  "wip"
```

Future-you will thank present-you when debugging in 6 months.

---

## VS Code workspace setup

### `.vscode/settings.json`

```json
{
  "files.associations": {
    "*.luau": "luau"
  },
  "luau-lsp.fflags.enableNewSolver": true,
  "luau-lsp.types.roblox": true,
  "[luau]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "JohnnyMorganz.stylua"
  }
}
```

### Extensions to install

- **Luau LSP** (`JohnnyMorganz.luau-lsp`) — type-checking and autocomplete
- **Rojo** (`evaera.vscode-rojo`) — Rojo integration
- **StyLua** (`JohnnyMorganz.stylua`) — auto-format
- **GitLens** — git history inline
- **Better Comments** — colored comment tags (TODO, FIXME, NOTE)

---

## The development loop (memorize)

1. **`rojo serve`** in a terminal (keep it running)
2. **Open VS Code** with your project
3. **Open Roblox Studio**, blank place, click Rojo → Connect
4. **Edit a file** in VS Code, save
5. **Press F5 in Studio** to playtest
6. Read the output console (View → Output)
7. **Iterate**

When something breaks:
- Read the Studio output. The error includes the script name and line number.
- Match it back to your filesystem path via the file naming convention.
- Fix in VS Code, save, re-test.

Ask Claude Code to fix things by pasting the error message + the relevant file. Claude can also use the MCP server to *read* the file directly and *write* the fix — see `08_MCP_SETUP.md`.

---

## When the project gets bigger

At ~50 modules, consider these patterns:

### Sub-folders by domain

```
server/Modules/
├── Economy/
│   ├── CurrencyManager.luau
│   ├── UpgradeManager.luau
│   └── ShopManager.luau
├── Player/
│   ├── DataManager.luau
│   ├── DailyLoginManager.luau
│   └── ProfileManager.luau
├── Combat/  (if applicable)
└── World/
```

### Service locator (later, optional)

A central registry of services so modules don't `require` each other into a tangled web. Look at `Knit` or `Matter` (popular Roblox frameworks). Don't bring these in for V1 — they add complexity. Bring them in if you outgrow simple `require` chains.

### Type definitions in `shared/Types.luau`

As types repeat across modules, centralize them.

```lua
-- src/shared/Types.luau
export type PlayerData = {
    coins: number,
    rebirths: number,
    -- ...
}

export type Upgrade = {
    id: string,
    cost: number,
    effect: string,
}

return {} -- the module exists only for the types it exports
```

---

## What NOT to do

- **Don't use Roblox Studio's built-in script editor.** It's fine for quick tweaks. For real development, write in VS Code with Rojo. Studio's editor has no Git, no extensions, no multi-file search, no proper type checking.
- **Don't write your code in a single `Script`.** Modules. Always.
- **Don't put server logic in `ReplicatedStorage`.** It replicates to clients. Server-only logic lives in `ServerScriptService`.
- **Don't commit `place/` or built `.rbxlx` files.** They're build artifacts.
- **Don't store API keys or sensitive constants in `shared/`.** Server-only or env-managed.

---

**Next: `08_MCP_SETUP.md` — wiring Claude Code to your live Roblox Studio session.**
