--!strict
--[[
	Outpost-7 — UI theme module.

	Phase G5. Central palette + motion lookup. All UI controllers
	(HUD, panels, toasts, buttons) read colors from `Theme.GetActive()`
	instead of inlining `Color3.fromRGB(...)` literals. When the active
	biome changes, `Theme.SetActive(biomeId)` flips the palette + fires
	`Theme.Changed` so subscribers re-tint their instances live.

	Themes:
	  industrial  — raid place + base of main place (gunmetal + warning orange)
	  jungle      — bioluminescent magenta/teal (matches G1 jungle lighting)
	  ice         — icy blue palette
	  volcanic    — ember orange + cool teal balance

	Slot keys (per Constants.UI.Slots):
	  background  — root screen / underlying frame
	  panel       — modal panel fill
	  textPrimary — body text on dark surfaces
	  textMuted   — caption / disabled / less-emphatic
	  accent      — primary CTA / strokes / currency
	  secondary   — secondary CTA / premium currency
	  danger      — destructive / error
	  highlight   — celebratory / unlock / streak

	Note: this module is `shared` so both server (for any read-only
	color reference like Cosmetic preview) and client can require it.
	Server never calls `SetActive` — biome theme swap originates from
	`BiomeLightingService` on the server but fires a single
	BindableEvent that the client mirrors via the
	`Theme.SetActiveSignal` ReplicatedStorage hook (see ApplySync
	helper). V1 ships the simpler model: the client subscribes to the
	`OutpostBiomeApplied` StringValue under ReplicatedStorage, updated
	by BiomeLightingService.Apply.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local Theme = {}

export type Palette = {
	background: Color3,
	panel: Color3,
	textPrimary: Color3,
	textMuted: Color3,
	accent: Color3,
	secondary: Color3,
	danger: Color3,
	highlight: Color3,
}

export type ThemeId = "industrial" | "jungle" | "ice" | "volcanic"

local PALETTES: { [string]: Palette } = {
	industrial = {
		background = Color3.fromRGB(28, 30, 34),
		panel = Color3.fromRGB(38, 40, 44),
		textPrimary = Color3.fromRGB(230, 230, 220),
		textMuted = Color3.fromRGB(140, 140, 130),
		accent = Color3.fromRGB(255, 150, 50),
		secondary = Color3.fromRGB(180, 200, 120),
		danger = Color3.fromRGB(220, 60, 60),
		highlight = Color3.fromRGB(255, 200, 80),
	},
	jungle = {
		background = Color3.fromRGB(20, 24, 32),
		panel = Color3.fromRGB(28, 32, 40),
		textPrimary = Color3.fromRGB(220, 240, 200),
		textMuted = Color3.fromRGB(150, 160, 170),
		accent = Color3.fromRGB(120, 220, 180),
		secondary = Color3.fromRGB(220, 130, 240),
		danger = Color3.fromRGB(255, 88, 88),
		highlight = Color3.fromRGB(255, 100, 200),
	},
	ice = {
		background = Color3.fromRGB(18, 24, 36),
		panel = Color3.fromRGB(28, 36, 48),
		textPrimary = Color3.fromRGB(220, 235, 250),
		textMuted = Color3.fromRGB(140, 160, 180),
		accent = Color3.fromRGB(120, 200, 240),
		secondary = Color3.fromRGB(180, 220, 255),
		danger = Color3.fromRGB(255, 100, 120),
		highlight = Color3.fromRGB(200, 240, 255),
	},
	volcanic = {
		background = Color3.fromRGB(22, 22, 28),
		panel = Color3.fromRGB(32, 32, 38),
		textPrimary = Color3.fromRGB(230, 224, 210),
		textMuted = Color3.fromRGB(150, 150, 160),
		accent = Color3.fromRGB(255, 120, 60),
		secondary = Color3.fromRGB(100, 200, 220),
		danger = Color3.fromRGB(255, 70, 70),
		highlight = Color3.fromRGB(255, 200, 100),
	},
}

-- Biome id → theme id mapping. Identity for the 3 V1 biomes; explicit
-- so a future biome could map to an existing theme (e.g., V1.5 night-
-- jungle reusing `jungle`).
local BIOME_TO_THEME: { [string]: ThemeId } = {
	jungle = "jungle",
	ice = "ice",
	volcanic = "volcanic",
}

local active: ThemeId = Constants.UI.BaseTheme :: ThemeId

-- Cross-runtime signal. Server fires SetActive when the biome changes;
-- client mirrors via a ReplicatedStorage StringValue (server writes,
-- client subscribes). BindableEvent here covers same-runtime
-- subscribers (e.g., a client component listening to its own client-
-- side SetActive after the StringValue handler dispatches).
local changedSignal: BindableEvent = Instance.new("BindableEvent")
Theme.Changed = changedSignal.Event

local THEME_VALUE_NAME = "OutpostActiveTheme"

local function ensureReplicatedThemeValue(): StringValue
	local existing = ReplicatedStorage:FindFirstChild(THEME_VALUE_NAME)
	if existing and existing:IsA("StringValue") then
		return existing
	end
	local sv = Instance.new("StringValue")
	sv.Name = THEME_VALUE_NAME
	sv.Value = active
	-- Server writes; clients read + Changed-subscribe. No Remote needed
	-- because the value is push-replicated by Roblox.
	sv.Parent = ReplicatedStorage
	return sv
end

function Theme.GetActiveId(): ThemeId
	return active
end

function Theme.GetActive(): Palette
	return PALETTES[active]
end

function Theme.Get(themeId: ThemeId): Palette?
	return PALETTES[themeId]
end

function Theme.SetActive(themeId: ThemeId)
	if not PALETTES[themeId] then
		warn(string.format("[Theme] Unknown theme '%s'; ignoring", tostring(themeId)))
		return
	end
	if themeId == active then
		return
	end
	active = themeId
	-- Server-side: push replication via the shared StringValue so
	-- clients receive the swap without a per-Remote round trip.
	if RunService:IsServer() then
		local sv = ensureReplicatedThemeValue()
		sv.Value = themeId
	end
	changedSignal:Fire(themeId)
end

-- BiomeLightingService calls this. Always evaluates raid-place vs
-- main-place because the raid place always renders industrial regardless
-- of the snapshot biome.
function Theme.SetActiveFromBiome(biomeId: string)
	if game.PrivateServerId ~= "" then
		Theme.SetActive("industrial")
		return
	end
	local mapped = BIOME_TO_THEME[biomeId]
	if not mapped then
		warn(string.format("[Theme] Unknown biome '%s'; staying on %s", tostring(biomeId), active))
		return
	end
	Theme.SetActive(mapped)
end

-- Easing string → Roblox enum resolution helper. Used by Components
-- to translate Constants.UI.Motion's string easing names into
-- TweenInfo args.
function Theme.EasingStyleFor(name: string): Enum.EasingStyle
	if name == "Linear" then
		return Enum.EasingStyle.Linear
	elseif name == "QuadIn" or name == "QuadOut" then
		return Enum.EasingStyle.Quad
	elseif name == "CubicIn" or name == "CubicOut" then
		return Enum.EasingStyle.Cubic
	elseif name == "BackOut" or name == "BackIn" then
		return Enum.EasingStyle.Back
	end
	return Enum.EasingStyle.Quad
end

function Theme.EasingDirectionFor(name: string): Enum.EasingDirection
	if string.find(name, "Out", 1, true) then
		return Enum.EasingDirection.Out
	elseif string.find(name, "In", 1, true) then
		return Enum.EasingDirection.In
	end
	return Enum.EasingDirection.Out
end

-- Client-side subscriber: mirrors the ReplicatedStorage StringValue
-- into the local `active` + fires Changed. Call ONCE from
-- HudController.Init / init.client.luau (idempotent — repeated calls
-- just re-attach the connection without leaking).
function Theme.BindClientReplication()
	if not RunService:IsClient() then
		return
	end
	-- WAIT for the server-replicated StringValue (server creates it
	-- eagerly at module load — see bottom of file). 10s timeout
	-- guards against the case where the server never loads the Theme
	-- module (shouldn't happen — every server boot pulls it via
	-- BiomeLightingService).
	local sv = ReplicatedStorage:WaitForChild(THEME_VALUE_NAME, 10)
	if not sv or not sv:IsA("StringValue") then
		warn("[Theme] OutpostActiveTheme not present after 10s; staying on default theme")
		return
	end
	if PALETTES[sv.Value] then
		active = sv.Value :: ThemeId
		changedSignal:Fire(active)
	end
	sv:GetPropertyChangedSignal("Value"):Connect(function()
		if PALETTES[sv.Value] then
			active = sv.Value :: ThemeId
			changedSignal:Fire(active)
		end
	end)
end

-- Server side: eagerly create the replicated StringValue at module
-- load time. Guarantees clients can WaitForChild on it regardless of
-- BiomeLightingService.Init ordering (raid place inits theme too via
-- SetActiveFromBiome → SetActive, but on first boot of any server,
-- this load-time create races with the client's WaitForChild and we
-- want the server to win).
if RunService:IsServer() then
	ensureReplicatedThemeValue()
end

return Theme
