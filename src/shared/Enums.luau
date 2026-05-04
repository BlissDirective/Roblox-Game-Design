--!strict
--[[
	Outpost-7 — string enum tables.

	These exist so modules reference Enums.Mode.Build instead of the bare
	string "Build". The string identity is intentional — they're safe to
	send over Remotes (after server validation) and easy to log.

	Phase A3: Mode (build vs combat vs raid camera/UX state) and Biome
	(the three V1 biomes per finalized-brainstorm.md §2.8). Subsequent
	phases append (ItemRarity, Channel, etc.).
--]]

local Enums = {
	-- Camera + UX mode. Phase B5 (camera transition) and the build/combat
	-- mode controllers read this.
	Mode = {
		Build = "Build",
		Combat = "Combat",
		Raid = "Raid",
	},

	-- V1 biomes per finalized-brainstorm.md §2.8 ("multiple biomes at
	-- launch"). Per-biome assets live under assets/world/biome_*.
	Biome = {
		Jungle = "Jungle", -- bioluminescent jungle (primary)
		Volcanic = "Volcanic",
		Ice = "Ice",
	},
}

return Enums
