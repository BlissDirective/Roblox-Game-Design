--!strict
--[[
	Outpost-7 — Server Authority Beta runtime bootstrap.

	Phase B1. ADR-005 adopts Server Authority Beta for V1. The Beta-only
	Workspace properties aren't in Rojo's reflection database yet, so
	default.project.json can't set them — we apply them at runtime.

	Each property write is pcall-wrapped: if the runtime doesn't know
	the property (Beta disabled in Studio, or property renamed in a
	future release), the apply skips it and logs which properties
	didn't take. The server still boots with sane defaults.

	This is the single chokepoint for SA Beta enablement. If Roblox
	disables the Beta, comment out the Apply() call in init.server.luau
	and the rest of the codebase keeps running on the manual
	server-authoritative pattern from 06_LUAU_REFERENCE.md (per ADR-005's
	rollback plan).
--]]

local Workspace = game:GetService("Workspace")

local ServerAuthorityBootstrap = {}

local function tryEnum(propName: string, enumName: string, enumValue: string): boolean
	local enumGroup = (Enum :: any)[enumName]
	if not enumGroup then
		return false
	end
	local value = enumGroup[enumValue]
	if not value then
		return false
	end
	local ok = pcall(function()
		(Workspace :: any)[propName] = value
	end)
	return ok
end

local function tryScalar(propName: string, value: any): boolean
	local ok = pcall(function()
		(Workspace :: any)[propName] = value
	end)
	return ok
end

function ServerAuthorityBootstrap.Apply()
	-- Property names per Roblox Studio Team's 2026 Beta announcement.
	-- Each entry is { propName, applyFn } where applyFn returns true on
	-- success. Order matches dependency direction (auth model first).
	local applied: { [string]: boolean } = {
		AuthorityMode = tryEnum("AuthorityMode", "AuthorityMode", "Server"),
		SignalBehavior = tryEnum("SignalBehavior", "SignalBehavior", "Deferred"),
		UseFixedSimulation = tryScalar("UseFixedSimulation", true),
		PlayerScriptsUseInput = tryScalar("PlayerScriptsUseInput", true),
	}

	-- NextGenerationReplication: docs at the time of the Beta launch
	-- showed both bool and enum signatures. Try bool first, fall back
	-- to enum so this module survives either schema.
	local ngrApplied = tryScalar("NextGenerationReplication", true)
	if not ngrApplied then
		ngrApplied = tryEnum("NextGenerationReplication", "NextGenerationReplication", "Enabled")
	end
	applied.NextGenerationReplication = ngrApplied

	local okCount = 0
	local total = 0
	for _, ok in applied do
		total += 1
		if ok then
			okCount += 1
		end
	end

	print(string.format("[ServerAuthorityBootstrap] Applied %d/%d SA Beta Workspace properties.", okCount, total))
	if okCount < total then
		print("[ServerAuthorityBootstrap] Skipped (Beta may be disabled in Studio, or property renamed):")
		for name, ok in applied do
			if not ok then
				print("  - " .. name)
			end
		end
	end
end

return ServerAuthorityBootstrap
