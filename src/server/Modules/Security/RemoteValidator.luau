--!strict
--[[
	Outpost-7 — central wire-shape Remote validator.

	Phase F2. Primitive validators applied at every Client→Server
	Remote handler entry, *before* domain validation in the service
	module. Each primitive returns `(ok: boolean, sanitizedValue: T?,
	error: string?)`. Failure path: handler returns
	`{ ok = false, error = "invalid <field>" }` to client AND records
	to `AuditLog` for Phase H pre-launch monitoring.

	**Validation lives in two layers.** This module owns layer 1.
	  Layer 1 (this module): wire-shape — type, length, range, table
	    structure. Generic across Remotes; same checks for any string
	    input regardless of which Remote receives it.
	  Layer 2 (service modules): domain — character class for clan
	    names, "is this a valid quest ID for today's set", etc.
	    Lives in the service's TryX method.

	Threat model addressed:
	  - Modded client sending a 1MB string in a "blueprintId" field
	    (memory exhaustion attempt)
	  - Float / NaN / Infinity sent where integer expected
	  - Negative numbers sent where positive expected
	  - Deep nested tables in future structured payloads (stack
	    overflow during recursive walks)
	  - Type confusion (Vector3 sent where number expected, etc.)

	Public API (each returns `(ok, sanitizedValue?, error?)`):
	  IsString(value, minLen?, maxLen?)
	  IsInteger(value, min?, max?)
	  IsNumber(value, min?, max?)
	  IsBoolean(value)
	  IsOption(value, allowedSet)            — enum-style; allowedSet is
	                                          { [string]: true } or array
	  IsUserId(value)                        — positive integer in
	                                          MaxUserIdValue range
	  IsTable(value, maxDepth?, maxKeys?)    — depth + key count check
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local RemoteValidator = {}

local function isFinite(n: number): boolean
	-- NaN never equals itself; Infinity > MaxAmountValue. Both rejected.
	return n == n and n ~= math.huge and n ~= -math.huge
end

function RemoteValidator.IsString(value: any, minLen: number?, maxLen: number?): (boolean, string?, string?)
	if typeof(value) ~= "string" then
		return false, nil, "not a string"
	end
	local len = #value
	local floor = minLen or 0
	local ceiling = maxLen or Constants.VALIDATION.MaxClanIdLength -- generic ceiling
	if len < floor then
		return false, nil, string.format("string too short (< %d)", floor)
	end
	if len > ceiling then
		return false, nil, string.format("string too long (> %d)", ceiling)
	end
	return true, value, nil
end

function RemoteValidator.IsInteger(value: any, minVal: number?, maxVal: number?): (boolean, number?, string?)
	if typeof(value) ~= "number" then
		return false, nil, "not a number"
	end
	if not isFinite(value) then
		return false, nil, "non-finite (NaN/Inf)"
	end
	if value ~= math.floor(value) then
		return false, nil, "not an integer"
	end
	if minVal and value < minVal then
		return false, nil, string.format("below min (%s)", tostring(minVal))
	end
	if maxVal and value > maxVal then
		return false, nil, string.format("above max (%s)", tostring(maxVal))
	end
	return true, value, nil
end

function RemoteValidator.IsNumber(value: any, minVal: number?, maxVal: number?): (boolean, number?, string?)
	if typeof(value) ~= "number" then
		return false, nil, "not a number"
	end
	if not isFinite(value) then
		return false, nil, "non-finite (NaN/Inf)"
	end
	if minVal and value < minVal then
		return false, nil, string.format("below min (%s)", tostring(minVal))
	end
	if maxVal and value > maxVal then
		return false, nil, string.format("above max (%s)", tostring(maxVal))
	end
	return true, value, nil
end

function RemoteValidator.IsBoolean(value: any): (boolean, boolean?, string?)
	if typeof(value) ~= "boolean" then
		return false, nil, "not a boolean"
	end
	return true, value, nil
end

function RemoteValidator.IsOption(value: any, allowedSet: any): (boolean, any?, string?)
	if typeof(value) ~= "string" then
		return false, nil, "option must be a string"
	end
	-- Accept either { [option]: true } or { option1, option2, ... }.
	if typeof(allowedSet) == "table" then
		-- Set-style check first (cheap O(1)).
		if allowedSet[value] == true then
			return true, value, nil
		end
		-- Array-style fallback.
		for _, candidate in allowedSet do
			if candidate == value then
				return true, value, nil
			end
		end
	end
	return false, nil, "option not in allowed set"
end

function RemoteValidator.IsUserId(value: any): (boolean, number?, string?)
	-- UserIds are positive integers in the JS-safe range.
	return RemoteValidator.IsInteger(value, 1, Constants.VALIDATION.MaxUserIdValue)
end

local function tableDepth(t: any, maxDepth: number, currentDepth: number, maxKeys: number): (boolean, string?)
	if typeof(t) ~= "table" then
		return true, nil
	end
	if currentDepth > maxDepth then
		return false, "table too deep"
	end
	local keyCount = 0
	for _, v in t do
		keyCount += 1
		if keyCount > maxKeys then
			return false, "too many keys"
		end
		local ok, err = tableDepth(v, maxDepth, currentDepth + 1, maxKeys)
		if not ok then
			return false, err
		end
	end
	return true, nil
end

function RemoteValidator.IsTable(value: any, maxDepth: number?, maxKeys: number?): (boolean, any?, string?)
	if typeof(value) ~= "table" then
		return false, nil, "not a table"
	end
	local depth = maxDepth or Constants.VALIDATION.MaxTableDepth
	local keys = maxKeys or Constants.VALIDATION.MaxTableKeys
	local ok, err = tableDepth(value, depth, 1, keys)
	if not ok then
		return false, nil, err
	end
	return true, value, nil
end

return RemoteValidator
