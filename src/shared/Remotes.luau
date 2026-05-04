--!strict
-- Outpost-7 — shared RemoteEvent / RemoteFunction registry.
--
-- Phase A1 scaffold: returns an empty table.
-- Phase A3 implements `getOrCreate` and the typed registry.
-- Subsequent phases register their Remotes here so the trust boundary stays
-- visible in one file.

local Remotes = {}

return Remotes
