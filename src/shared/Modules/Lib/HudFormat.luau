--!strict
--[[
	Outpost-7 — number formatting for HUD display.

	Phase B4. Number formatting that survives mobile-screen real estate
	limits (a 5-digit number tail-spills off the credits readout on iPhone
	SE). Two formatters — `Abbreviated` for HUD displays and
	`WithCommas` for verbose places like leaderboards.

	Both are pure functions over numbers; no rounding policy is shared.
	Abbreviated rounds toward zero (truncation). Phase G aesthetic pass
	may swap for banker's rounding if "0.9K → 1K" jumps look bad.
--]]

local HudFormat = {}

local SUFFIXES = { "", "K", "M", "B", "T" }

function HudFormat.Abbreviated(n: number): string
	if n < 1000 and n > -1000 then
		return tostring(math.floor(n))
	end
	local abs = math.abs(n)
	local sign = if n < 0 then "-" else ""
	local i = 0
	local v = abs
	while v >= 1000 and i < #SUFFIXES - 1 do
		v = v / 1000
		i += 1
	end
	if v == math.floor(v) then
		return string.format("%s%d%s", sign, v, SUFFIXES[i + 1])
	end
	return string.format("%s%.1f%s", sign, v, SUFFIXES[i + 1])
end

function HudFormat.WithCommas(n: number): string
	local s = tostring(math.floor(n))
	local k
	repeat
		s, k = (s:gsub("^(-?%d+)(%d%d%d)", "%1,%2"))
	until k == 0
	return s
end

return HudFormat
