# 06 — LUAU_REFERENCE.md

> The code reference for Claude (and you). Luau patterns that work in production. Anti-exploit. DataStore. RemoteEvents. Performance. The patterns that survive a few thousand concurrent players.

---

## What Luau is (and isn't)

**Luau** is Roblox's flavor of Lua — a typed, performance-tuned superset of Lua 5.1. It is **not Lua, not JavaScript, not TypeScript.** Code written for any other Lua dialect will mostly work, but Luau-specific features (type annotations, `task` library, generalized for-in iteration) are what you should use.

When Claude writes Roblox code, it writes **strict Luau with type annotations**. This catches bugs in Studio before runtime.

```lua
-- ✅ Strict Luau with types
local function applyDamage(target: Player, amount: number): boolean
    if amount < 0 or amount > 1000 then return false end
    -- ...
    return true
end

-- ❌ Untyped Lua-style (works but loses safety)
local function applyDamage(target, amount)
    -- ...
end
```

---

## The platform model (must understand before writing code)

### Server vs. Client — the trust boundary

Every Roblox game runs on:

- **One server** per game session. Authoritative. The server is the source of truth.
- **Many clients**, one per player. Display + input only. **Clients lie.**

The trust boundary:

| What lives where | Server | Client |
|---|---|---|
| Player currency | ✅ Source of truth | ❌ Display only |
| Inventory | ✅ Source of truth | ❌ Display only |
| Game state | ✅ Source of truth | ❌ Display only |
| Anti-cheat | ✅ Validates | ❌ Don't trust |
| User input | ❌ Don't trust raw | ✅ Captured here |
| UI / visual feedback | ❌ Server has no UI | ✅ Renders here |
| Sound / particle effects | Sometimes | ✅ Renders here |

**The single rule:** *clients request, servers decide, results replicate back.*

### The Roblox services you'll use most

Every game uses these. Always reference them via `game:GetService(...)`, never via `game.Workspace` or similar (the latter breaks if the service hasn't loaded).

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService") -- Game Passes & Dev Products
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService") -- client-side only
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ServerStorage = game:GetService("ServerStorage") -- server-only objects
local Workspace = game:GetService("Workspace")
```

### Where things live in the Data Model

The "Explorer" tree in Studio is the runtime structure of your game. Memorize this:

| Service | Purpose |
|---|---|
| `Workspace` | The 3D world. Anything visible to players is here at runtime. |
| `ReplicatedStorage` | Shared between server and client. Use for: shared modules, RemoteEvents, RemoteFunctions, asset templates. |
| `ServerScriptService` | Server-only `Script` and `ModuleScript` files. **All your game logic lives here.** |
| `ServerStorage` | Server-only assets. Templates not yet placed in Workspace. NPCs in pools. Hidden game state. |
| `StarterPlayer / StarterPlayerScripts` | `LocalScript`s and modules that get copied to each player on join. **All your client logic lives here.** |
| `StarterGui` | UI that gets copied to each player on join. |
| `StarterPack` | Tools (e.g., a sword) automatically given to each player on join. |
| `ReplicatedFirst` | Loaded before the player even sees the loading screen. Use for the loading screen itself. |
| `Teams` | Built-in team support if you need it. |
| `SoundService` | Global sound configuration. |
| `Lighting` | Time of day, atmosphere, visual environment. |

---

## Project file structure (high level)

This is what your filesystem-side project looks like with Rojo. (Full detail in `07_PROJECT_STRUCTURE.md`.)

```
my-game/
├── default.project.json
├── CLAUDE.md            (← copy of 01_AGENT.md so Claude Code loads it)
├── docs/                (← these reference .md files)
└── src/
    ├── server/          (→ ServerScriptService)
    │   ├── CurrencyManager.server.luau
    │   ├── DataManager.server.luau
    │   └── Modules/
    │       └── Economy.luau
    ├── client/          (→ StarterPlayerScripts)
    │   ├── HudController.client.luau
    │   └── Modules/
    │       └── HudFormat.luau
    └── shared/          (→ ReplicatedStorage)
        ├── Remotes.luau
        ├── Constants.luau
        └── Types.luau
```

File naming with Rojo:
- `Foo.server.luau` → `Script` (runs on server)
- `Foo.client.luau` → `LocalScript` (runs on client)
- `Foo.luau` → `ModuleScript` (required by other scripts)

---

## The ten Luau commandments (the "always-do" list)

Claude follows these without being asked. You should learn them by osmosis.

### 1. `pcall` every DataStore call

DataStore calls fail. They throttle. They time out. An unprotected call crashes the thread and corrupts saves.

```lua
-- ❌ BAD: silent corruption when this fails
local data = DataStore:GetAsync(key)

-- ✅ GOOD: protected with retry + backoff
local function safeGet(store, key, attempts: number?)
    attempts = attempts or 3
    for i = 1, attempts do
        local success, result = pcall(function()
            return store:GetAsync(key)
        end)
        if success then return true, result end
        task.wait(2 ^ i) -- exponential backoff
    end
    return false, nil
end
```

### 2. `UpdateAsync` for player data, not `SetAsync`

`SetAsync` blindly overwrites. If the same player has two server sessions (rare but real), one save wins and one is lost. `UpdateAsync` gives you a function that receives current data and returns new data atomically.

```lua
-- ✅ GOOD: atomic update
DataStore:UpdateAsync(playerKey, function(currentData)
    currentData = currentData or { coins = 100 }
    currentData.coins += 50
    return currentData
end)
```

### 3. Save on `PlayerRemoving` AND on `BindToClose`

```lua
local function savePlayer(player: Player) -- defined elsewhere

Players.PlayerRemoving:Connect(savePlayer)

game:BindToClose(function()
    -- Server is shutting down. Save everyone.
    for _, player in Players:GetPlayers() do
        savePlayer(player)
    end
    -- Wait long enough for saves to flush
    task.wait(2)
end)
```

Without `BindToClose`, server-shutdown saves can fail silently.

### 4. Rate-limit DataStore writes to ≤1 write per 6 seconds per key

Roblox enforces this. Exceeding it triggers silent throttle failures. Save on join, leave, and shutdown — never every coin tick.

If you must save mid-session (long sessions, high-stakes data), debounce to once per 60–120 seconds.

### 5. Server-authoritative game state. Always.

Anything that can be cheated, must live on the server.

```lua
-- ❌ BAD: trusting the client to send currency amounts
RemoteEvent.OnServerEvent:Connect(function(player, coinAmount)
    playerCoins[player.UserId] += coinAmount -- exploiter sends 999999
end)

-- ✅ GOOD: client requests an action; server decides
RemoteEvent.OnServerEvent:Connect(function(player, actionType)
    if actionType == "claimDailyReward" then
        local today = os.date("!*t").day
        if lastClaim[player.UserId] ~= today then
            playerCoins[player.UserId] += 500
            lastClaim[player.UserId] = today
        end
    end
end)
```

### 6. Validate every RemoteEvent argument

The client can send anything. Type, range, and intent.

```lua
RemoteEvent.OnServerEvent:Connect(function(player, action, amount)
    -- Validate types
    if type(action) ~= "string" then return end
    if type(amount) ~= "number" then return end

    -- Validate range
    if amount < 0 or amount > 1000 then return end

    -- Validate intent (does this player have permission?)
    if not isAuthorized(player, action) then return end

    -- Now it's safe to act
end)
```

### 7. Use `task.spawn` and `task.wait`, not `coroutine.wrap` and `wait`

The legacy `wait()` is throttled to ≥0.03s and inaccurate. Use `task.wait()`.
The legacy `coroutine.wrap` doesn't yield to Roblox's scheduler the same way. Use `task.spawn`.

```lua
-- ✅ GOOD
task.spawn(function()
    while true do
        task.wait(1)
        for _, player in Players:GetPlayers() do
            -- per-second income tick
        end
    end
end)
```

### 8. `Instance:Destroy()`, not `Instance.Parent = nil`

`Destroy` cleans up signal connections. Parent-to-nil leaks them. Memory leaks at 200 CCU = a server that stutters and dies.

```lua
-- ✅ GOOD
projectile:Destroy()

-- ❌ BAD: leaks any :Connect signals on this instance
projectile.Parent = nil
```

### 9. Modules over monolithic scripts

A `Script` should be 5–30 lines: requires modules, wires them up, starts the loop. The actual logic lives in `ModuleScript`s.

```lua
-- src/server/init.server.luau (or Main.server.luau)
local CurrencyManager = require(script.Parent.Modules.CurrencyManager)
local UpgradeManager = require(script.Parent.Modules.UpgradeManager)
local DataManager = require(script.Parent.Modules.DataManager)

DataManager.Init()
CurrencyManager.Init()
UpgradeManager.Init()
```

### 10. Object-pool anything spawned in bulk

`Instance.new` in a tight loop is the #1 cause of mobile frame drops. Pre-create instances, hide them, reuse.

```lua
-- Build a pool of 50 hit-effect particles at startup
-- When you need one: pop from pool, position, show
-- When done: hide, return to pool
-- Never call Instance.new() at runtime in hot paths.
```

---

## Core systems: ready-to-use templates

These are the systems every tycoon/simulator/idle game needs. Claude will write game-specific versions, but these are the canonical patterns.

### DataStore wrapper (with retry, session lock, versioning)

`src/server/Modules/DataManager.luau`

```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataManager = {}

local STORE_NAME = "PlayerData_v1"
local CURRENT_SCHEMA_VERSION = 1
local store = DataStoreService:GetDataStore(STORE_NAME)

export type PlayerData = {
    _version: number,
    coins: number,
    incomeRate: number,
    rebirths: number,
    lastDailyClaim: string?,
    streak: number,
    -- extend as needed
}

local DEFAULT_DATA: PlayerData = {
    _version = CURRENT_SCHEMA_VERSION,
    coins = 100,
    incomeRate = 1,
    rebirths = 0,
    lastDailyClaim = nil,
    streak = 0,
}

-- In-memory cache
local cache: {[number]: PlayerData} = {}
local sessionLock: {[number]: boolean} = {}

local function migrate(data: any): PlayerData
    -- Apply per-version migrations here as schema evolves
    if not data._version or data._version < 1 then
        data._version = 1
    end
    -- Future: if data._version < 2 then ... end
    return data
end

local function safeCall(operation: () -> any): (boolean, any)
    local attempts = 3
    for i = 1, attempts do
        local success, result = pcall(operation)
        if success then return true, result end
        task.wait(2 ^ i)
    end
    return false, nil
end

function DataManager.LoadPlayer(player: Player)
    if sessionLock[player.UserId] then return end
    sessionLock[player.UserId] = true

    local key = tostring(player.UserId)
    local success, data = safeCall(function()
        return store:GetAsync(key)
    end)

    if success and data then
        cache[player.UserId] = migrate(data)
    else
        cache[player.UserId] = table.clone(DEFAULT_DATA)
    end
end

function DataManager.SavePlayer(player: Player)
    local data = cache[player.UserId]
    if not data then return end

    local key = tostring(player.UserId)
    safeCall(function()
        store:UpdateAsync(key, function(_currentRemote)
            -- Always save the latest cached version (server is authoritative)
            return data
        end)
    end)
end

function DataManager.GetData(player: Player): PlayerData?
    return cache[player.UserId]
end

function DataManager.UpdateField(player: Player, field: string, value: any)
    local data = cache[player.UserId]
    if not data then return end
    (data :: any)[field] = value
end

function DataManager.Init()
    Players.PlayerAdded:Connect(DataManager.LoadPlayer)
    Players.PlayerRemoving:Connect(function(player)
        DataManager.SavePlayer(player)
        cache[player.UserId] = nil
        sessionLock[player.UserId] = nil
    end)

    game:BindToClose(function()
        for _, player in Players:GetPlayers() do
            DataManager.SavePlayer(player)
        end
        task.wait(2) -- let saves flush
    end)
end

return DataManager
```

### Currency manager with passive income

`src/server/Modules/CurrencyManager.luau`

```lua
--!strict
local Players = game:GetService("Players")
local DataManager = require(script.Parent.DataManager)

local CurrencyManager = {}

local TICK_RATE = 1 -- seconds

local function tickIncome()
    while true do
        task.wait(TICK_RATE)
        for _, player in Players:GetPlayers() do
            local data = DataManager.GetData(player)
            if data then
                data.coins += data.incomeRate
                -- (replication to client happens via leaderstats or a ValueObject — see ReplicationManager)
            end
        end
    end
end

function CurrencyManager.Add(player: Player, amount: number): boolean
    if amount <= 0 then return false end
    local data = DataManager.GetData(player)
    if not data then return false end
    data.coins += amount
    return true
end

function CurrencyManager.TrySpend(player: Player, amount: number): boolean
    if amount <= 0 then return false end
    local data = DataManager.GetData(player)
    if not data then return false end
    if data.coins < amount then return false end
    data.coins -= amount
    return true
end

function CurrencyManager.Init()
    task.spawn(tickIncome)
end

return CurrencyManager
```

### RemoteEvent: Game Pass purchase verification

`src/server/Modules/GamePassManager.luau`

```lua
--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local DataManager = require(script.Parent.DataManager)

local GamePassManager = {}

-- Define your passes once, in one place
local PASSES = {
    DOUBLE_CASH = { id = 0000000, multiplier = 2 },
    VIP = { id = 0000000, multiplier = 1.2, badge = "VIP" },
    AUTO_COLLECT = { id = 0000000 },
}

local function ownsPass(player: Player, passId: number): boolean
    local success, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
    end)
    return success and owns or false
end

function GamePassManager.ApplyPasses(player: Player)
    local data = DataManager.GetData(player)
    if not data then return end

    local multiplier = 1
    if ownsPass(player, PASSES.DOUBLE_CASH.id) then
        multiplier *= PASSES.DOUBLE_CASH.multiplier
    end
    if ownsPass(player, PASSES.VIP.id) then
        multiplier *= PASSES.VIP.multiplier
    end

    data.incomeRate = 1 * multiplier  -- base 1 × all multipliers
end

function GamePassManager.Init()
    Players.PlayerAdded:Connect(function(player)
        -- Wait until DataManager has loaded
        task.wait(2)
        GamePassManager.ApplyPasses(player)
    end)

    -- Re-check passes after a player buys one mid-session
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _passId, wasPurchased)
        if wasPurchased then
            GamePassManager.ApplyPasses(player)
        end
    end)
end

return GamePassManager
```

### Daily login bonus

`src/server/Modules/DailyLoginManager.luau`

```lua
--!strict
local Players = game:GetService("Players")
local DataManager = require(script.Parent.DataManager)
local CurrencyManager = require(script.Parent.CurrencyManager)

local DailyLoginManager = {}

local REWARDS = {
    [1] = 500,
    [2] = 750,
    [3] = 1000,
    [4] = 1500,
    [5] = 2000,
    [6] = 3000,
    [7] = 5000,
    [14] = 15000,
    [30] = 50000,
}

local function rewardForDay(day: number): number
    return REWARDS[day] or REWARDS[7] -- default to day 7 reward for any day past 7 if no milestone
end

local function todayString(): string
    return os.date("!%Y-%m-%d") :: string
end

local function yesterdayString(): string
    return os.date("!%Y-%m-%d", os.time() - 86400) :: string
end

function DailyLoginManager.TryClaim(player: Player): (boolean, number?, number?)
    local data = DataManager.GetData(player)
    if not data then return false end

    local today = todayString()
    if data.lastDailyClaim == today then
        return false -- already claimed
    end

    -- Check streak continuity
    if data.lastDailyClaim == yesterdayString() then
        data.streak += 1
    else
        data.streak = 1 -- reset streak
    end

    data.lastDailyClaim = today
    local reward = rewardForDay(data.streak)
    CurrencyManager.Add(player, reward)

    return true, reward, data.streak
end

function DailyLoginManager.Init()
    Players.PlayerAdded:Connect(function(player)
        task.wait(3) -- let DataManager load
        -- The client will call a RemoteFunction to actually claim;
        -- this Init just wires the event handler.
    end)
end

return DailyLoginManager
```

### Client-server communication: Remotes

`src/shared/Remotes.luau`

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getOrCreate(name: string, className: string): Instance
    local existing = ReplicatedStorage:FindFirstChild(name)
    if existing then return existing end
    local new = Instance.new(className)
    new.Name = name
    new.Parent = ReplicatedStorage
    return new
end

local Remotes = {
    -- Server → Client (notifications)
    CoinChanged = getOrCreate("CoinChanged", "RemoteEvent"),
    DailyRewardGranted = getOrCreate("DailyRewardGranted", "RemoteEvent"),

    -- Client → Server (requests)
    RequestUpgrade = getOrCreate("RequestUpgrade", "RemoteEvent"),
    RequestDailyClaim = getOrCreate("RequestDailyClaim", "RemoteFunction"),
}

return Remotes
```

### Anti-exploit: server-side validation gate

```lua
--!strict
-- src/server/Modules/AntiExploit.luau
local AntiExploit = {}

-- Track requests-per-player to detect spam
local requestLog: {[number]: {[string]: {number}}} = {}

function AntiExploit.RateCheck(player: Player, action: string, maxPerSecond: number): boolean
    local now = tick()
    requestLog[player.UserId] = requestLog[player.UserId] or {}
    requestLog[player.UserId][action] = requestLog[player.UserId][action] or {}
    local log = requestLog[player.UserId][action]

    -- Clean entries older than 1 second
    local cutoff = now - 1
    while #log > 0 and log[1] < cutoff do
        table.remove(log, 1)
    end

    if #log >= maxPerSecond then
        return false -- rate limited
    end

    table.insert(log, now)
    return true
end

return AntiExploit
```

Use it before any sensitive RemoteEvent action:

```lua
RemoteEvent.OnServerEvent:Connect(function(player, action)
    if not AntiExploit.RateCheck(player, "buyUpgrade", 5) then return end -- max 5/sec
    -- proceed with action
end)
```

---

## Performance: keep the game smooth

Roblox is mobile-dominant. A laggy game dies. Watch these:

### 1. Object pooling

Already covered. Pre-create, reuse, never `Instance.new` in hot paths.

### 2. Use `RunService.Heartbeat`, not `RunService.RenderStepped`, for non-visual logic

`RenderStepped` runs at the client's frame rate. `Heartbeat` runs once per physics frame on both server and client. For game logic that doesn't need pixel-perfect timing (most things), use `Heartbeat`.

### 3. Don't set properties unnecessarily

Setting `Part.CFrame = Part.CFrame` still triggers replication. Check before setting.

### 4. Use `Instance:GetAttribute()` for lightweight per-instance data

Lighter than `IntValue`/`StringValue` children. Replicates automatically.

### 5. Streaming and `StreamingEnabled`

For large open worlds, enable Workspace Streaming. The client only loads chunks near the player. Use `Workspace.StreamingEnabled = true` and configure `MinStreamRadius` / `MaxStreamRadius`.

### 6. Profile early

Use the **MicroProfiler** (Ctrl+F6 in Studio) to identify per-frame cost hotspots. Memory inspector for leaks.

### 7. `task.desynchronize()` for parallel Luau

For computationally heavy work (procgen, large pathfinding), use `task.desynchronize()` to move off the main thread, then `task.synchronize()` to come back when you need to touch the Workspace.

---

## Common gotchas (the "I just spent 4 hours debugging" list)

- **`game.Workspace` vs `game:GetService("Workspace")`** — the latter is safer; use it always.
- **A `Script` inside `StarterPlayerScripts` doesn't run.** Only `LocalScript` runs there.
- **A `LocalScript` inside `ServerScriptService` doesn't run.** Only server `Script`s run there.
- **`ReplicatedStorage` content replicates to all clients.** Don't put server secrets there.
- **`ServerStorage` is server-only.** Templates of NPCs / loot pools live here.
- **DataStore won't work in Studio by default.** Enable API Services in Game Settings → Security.
- **`HttpService` is disabled by default.** Enable in Game Settings → Security if you need outbound requests.
- **Game Passes need to be created in the Creator Hub before scripting against their IDs.**
- **`MarketplaceService:PromptGamePassPurchase` returns immediately** — listen to `PromptGamePassPurchaseFinished` to know the result.

---

## Testing your code

### Studio playtest modes

- **Play (F5)** — single-player simulation. Fast iteration.
- **Run (F8)** — runs the game without spawning your character. Server-only debugging.
- **Test → Players → 2/4/8 servers** — local multi-client simulation. Critical for testing replication.

### Common testing patterns

1. **Rubber-ducking with a friend.** First test your game with one real human. They'll find bugs you can't.
2. **Two-client local test.** Use Studio's multi-client test to verify a player can't see another player's private data, can't manipulate another's currency, etc.
3. **Force errors.** Disable DataStore mid-session. Verify your game doesn't crash, just gracefully degrades.
4. **Race conditions.** Have two clients try to buy the same one-of-a-kind item simultaneously. Server should award to one and reject the other cleanly.

---

## When you don't know an API

Roblox APIs change. New things ship monthly. When unsure:

1. **Check `https://create.roblox.com/docs`** — official docs, current.
2. **Search the Developer Forum** — `https://devforum.roblox.com`.
3. **Ask Claude to search the current Roblox docs** before writing code that uses a new API. Roblox's API surface area is large; don't fabricate signatures from memory.

---

**Next: `07_PROJECT_STRUCTURE.md` — exactly how the repo is laid out.**
