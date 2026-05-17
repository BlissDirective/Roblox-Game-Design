--!strict
--[[
	Outpost-7 — cosmetic item catalog (shared).

	Phase G7. V1 ships catalog entries for 4 of the 8 slots per
	`Constants.COSMETIC.Slots` (skin, helmet_decal, drone_trail,
	nameplate_flair). Remaining 4 (emote, banner, vehicle_paint,
	mount_cosmetic) are V1.5/V2 reservations — schema supports them
	but no V1 items.

	Cosmetic types V1:
	  - Skin (3): combatant (default), recon, heavy_defender
	  - Helmet decals (4): default + 3 unlockable
	  - Drone trails (4): default + 3 unlockable
	  - Nameplate flairs (3): default + 2 unlockable

	V1 visuals are placeholder color tints + simple geometric decals.
	Phase G art queue replaces with the operator BodyParts per
	ASSETS.md §4.2 + neon trail VFX per §4.5.

	Schema (`Cosmetic`):
	  id           — stable string key, lowercase + underscore
	  slot         — which slot it occupies (one of Constants.COSMETIC.Slots)
	  displayName  — UI label
	  description  — short tooltip text
	  source       — string tag for the unlock source ("default", "battle_pass:tier5", "vip_pass", "achievement", ...)
	  rarity       — "common" | "uncommon" | "rare" | "legendary" — drives badge color
	  color        — primary color used for placeholder visuals (real assets land in Phase G art queue)
	  accentColor  — secondary color for trim / accent
	  iconAssetId  — Roblox asset id for the cosmetics-panel thumbnail; placeholder 0 until Phase H
--]]

local CosmeticRegistry = {}

export type Rarity = "common" | "uncommon" | "rare" | "legendary"

export type Cosmetic = {
	id: string,
	slot: string,
	displayName: string,
	description: string,
	source: string,
	rarity: Rarity,
	color: Color3,
	accentColor: Color3,
	iconAssetId: number,
}

CosmeticRegistry.Catalog = {
	-- ============ SKIN slot ============
	skin_combatant = {
		id = "skin_combatant",
		slot = "skin",
		displayName = "Combatant Operator",
		description = "Standard frontline armor. Charcoal plating with warning-red accents.",
		source = "default",
		rarity = "common",
		color = Color3.fromRGB(26, 26, 34),
		accentColor = Color3.fromRGB(255, 56, 56),
		iconAssetId = 0,
	},
	skin_recon = {
		id = "skin_recon",
		slot = "skin",
		displayName = "Recon Operator",
		description = "Lightweight scout armor. Neon-teal accents on dark plating.",
		source = "battle_pass:tier15",
		rarity = "rare",
		color = Color3.fromRGB(34, 37, 42),
		accentColor = Color3.fromRGB(0, 224, 255),
		iconAssetId = 0,
	},
	skin_heavy_defender = {
		id = "skin_heavy_defender",
		slot = "skin",
		displayName = "Heavy Defender Operator",
		description = "VIP exoskeleton armor. Amber-glow seams and reinforced plating.",
		source = "vip_pass",
		rarity = "legendary",
		color = Color3.fromRGB(74, 82, 92),
		accentColor = Color3.fromRGB(255, 170, 51),
		iconAssetId = 0,
	},

	-- ============ HELMET DECAL slot ============
	decal_default = {
		id = "decal_default",
		slot = "helmet_decal",
		displayName = "No Decal",
		description = "Clean helmet — no insignia.",
		source = "default",
		rarity = "common",
		color = Color3.fromRGB(180, 180, 195),
		accentColor = Color3.fromRGB(180, 180, 195),
		iconAssetId = 0,
	},
	decal_chevron_red = {
		id = "decal_chevron_red",
		slot = "helmet_decal",
		displayName = "Red Chevron",
		description = "Battle-pass tier 10 unlock. Aggressive forward-facing chevron.",
		source = "battle_pass:tier10",
		rarity = "uncommon",
		color = Color3.fromRGB(255, 56, 56),
		accentColor = Color3.fromRGB(180, 30, 30),
		iconAssetId = 0,
	},
	decal_skull_amber = {
		id = "decal_skull_amber",
		slot = "helmet_decal",
		displayName = "Amber Skull",
		description = "Battle-pass tier 25 unlock. Glowing skull insignia.",
		source = "battle_pass:tier25",
		rarity = "rare",
		color = Color3.fromRGB(255, 170, 51),
		accentColor = Color3.fromRGB(180, 100, 20),
		iconAssetId = 0,
	},
	decal_op7_emblem = {
		id = "decal_op7_emblem",
		slot = "helmet_decal",
		displayName = "Outpost-7 Emblem",
		description = "Battle-pass tier 30 capstone. Official Outpost-7 emblem.",
		source = "battle_pass:tier30",
		rarity = "legendary",
		color = Color3.fromRGB(120, 220, 255),
		accentColor = Color3.fromRGB(255, 215, 100),
		iconAssetId = 0,
	},

	-- ============ DRONE TRAIL slot ============
	trail_default = {
		id = "trail_default",
		slot = "drone_trail",
		displayName = "Default Trail",
		description = "Standard drone trail — matches the swarm's preset color (red for Combat, blue for Recon, green for Engineering).",
		source = "default",
		rarity = "common",
		color = Color3.fromRGB(255, 80, 80), -- placeholder; runtime uses preset color
		accentColor = Color3.fromRGB(180, 50, 50),
		iconAssetId = 0,
	},
	trail_neon_red = {
		id = "trail_neon_red",
		slot = "drone_trail",
		displayName = "Neon Red",
		description = "Battle-pass tier 5 unlock. Aggressive blood-red trail.",
		source = "battle_pass:tier5",
		rarity = "uncommon",
		color = Color3.fromRGB(255, 30, 30),
		accentColor = Color3.fromRGB(180, 0, 0),
		iconAssetId = 0,
	},
	trail_neon_blue = {
		id = "trail_neon_blue",
		slot = "drone_trail",
		displayName = "Neon Blue",
		description = "Battle-pass tier 20 unlock. Cool electric-blue trail.",
		source = "battle_pass:tier20",
		rarity = "rare",
		color = Color3.fromRGB(30, 150, 255),
		accentColor = Color3.fromRGB(0, 100, 200),
		iconAssetId = 0,
	},
	trail_neon_gold = {
		id = "trail_neon_gold",
		slot = "drone_trail",
		displayName = "Neon Gold",
		description = "Battle-pass tier 30 capstone. Legendary gold trail.",
		source = "battle_pass:tier30",
		rarity = "legendary",
		color = Color3.fromRGB(255, 215, 100),
		accentColor = Color3.fromRGB(200, 160, 30),
		iconAssetId = 0,
	},

	-- ============ NAMEPLATE FLAIR slot ============
	flair_default = {
		id = "flair_default",
		slot = "nameplate_flair",
		displayName = "No Flair",
		description = "Plain nameplate.",
		source = "default",
		rarity = "common",
		color = Color3.fromRGB(180, 180, 195),
		accentColor = Color3.fromRGB(180, 180, 195),
		iconAssetId = 0,
	},
	flair_pioneer = {
		id = "flair_pioneer",
		slot = "nameplate_flair",
		displayName = "Pioneer",
		description = "Early-adopter reward. Indicates you played Outpost-7 in its first weeks.",
		source = "achievement:pioneer",
		rarity = "rare",
		color = Color3.fromRGB(255, 215, 100),
		accentColor = Color3.fromRGB(200, 160, 30),
		iconAssetId = 0,
	},
	flair_op7_veteran = {
		id = "flair_op7_veteran",
		slot = "nameplate_flair",
		displayName = "Outpost-7 Veteran",
		description = "Battle-pass tier 25 unlock. Marks you as a seasoned operator.",
		source = "battle_pass:tier25",
		rarity = "rare",
		color = Color3.fromRGB(120, 220, 255),
		accentColor = Color3.fromRGB(50, 130, 200),
		iconAssetId = 0,
	},
} :: { [string]: Cosmetic }

function CosmeticRegistry.Get(id: string): Cosmetic?
	return CosmeticRegistry.Catalog[id]
end

function CosmeticRegistry.IsValid(id: string): boolean
	return CosmeticRegistry.Catalog[id] ~= nil
end

-- Returns all cosmetics in a given slot. Used by the equip UI to list
-- available options per slot.
function CosmeticRegistry.GetForSlot(slot: string): { Cosmetic }
	local out: { Cosmetic } = {}
	for _, cosmetic in CosmeticRegistry.Catalog do
		if cosmetic.slot == slot then
			table.insert(out, cosmetic)
		end
	end
	return out
end

return CosmeticRegistry
