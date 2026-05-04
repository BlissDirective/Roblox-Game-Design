--!strict
--[[
	Outpost-7 — versioned PlayerData schema.

	Phase A2: ships v1.0 with the minimum fields needed to verify
	round-trip persistence. Later phases add fields freely; ProfileStore's
	`:Reconcile()` merges new template defaults into older saves on load,
	so additive changes need no migration.

	Renaming, removing, or retyping a field requires:
	  1. Bump CURRENT_SCHEMA_VERSION
	  2. Add a migrator under MIGRATIONS keyed by the source version
	  3. Log the change in docs/architecture/DATA_SCHEMA.md
	  4. Escalate per docs/10_BUILD_PROTOCOL.md (schema changes after
	     Phase A require human approval before merge)
--]]

local ProfileSchema = {}

ProfileSchema.CURRENT_SCHEMA_VERSION = 1

export type PlayerData = {
	_version: number,
	credits: number,
	cores: number,
	firstJoinAt: number?,
	lastJoinAt: number?,
	sessionsPlayed: number,
}

ProfileSchema.DEFAULT_DATA = {
	_version = 1,
	credits = 0,
	cores = 0,
	firstJoinAt = nil,
	lastJoinAt = nil,
	sessionsPlayed = 0,
} :: PlayerData

-- Each migrator mutates a profile in place from version K to version K+1.
-- v1.0 has no migrators yet — the table is intentionally empty.
local MIGRATIONS: { [number]: (any) -> () } = {
	-- [1] = function(data) data.newField = 0 end,  -- example: v1 -> v2
}

function ProfileSchema.Migrate(data: any): PlayerData
	local version: number = if typeof(data._version) == "number" then data._version else 0
	while version < ProfileSchema.CURRENT_SCHEMA_VERSION do
		local migrator = MIGRATIONS[version]
		if not migrator then
			break
		end
		migrator(data)
		version += 1
	end
	data._version = ProfileSchema.CURRENT_SCHEMA_VERSION
	return data
end

return ProfileSchema
