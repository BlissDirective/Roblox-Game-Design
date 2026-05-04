--!strict
--[[
	Outpost-7 — shared type definitions.

	Consumers `require` this module purely for the `export type`
	declarations; the returned table stays empty by convention.

	Phase A3: ships Result<T>. Subsequent phases append types as their
	systems require shared shape (PublicProfile, BaseLayout, Quest,
	Blueprint, Buildable, …). When this file gets large, sub-types move
	to src/shared/Modules/Schemas/ and are re-exported here.
--]]

-- Generic success/failure return for Remotes and any operation that can
-- fail in a typed way. Lighter than throwing; readable at the call site:
--
--     local result: Types.Result<number> = SomeService.try()
--     if result.ok then
--         use(result.value)
--     else
--         warn(result.error)
--     end
export type Result<T> = {
	ok: true,
	value: T,
} | {
	ok: false,
	error: string,
}

return {}
