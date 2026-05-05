--!strict
--[[
	Outpost-7 — damage chokepoint.

	Phase E2. Single entry point for "X damages Y" — both player → alien
	(via future turret raycasts in E2.5 / Phase G) and alien → player
	(via melee on touch). Funneling damage here means F1's anti-exploit
	pass has one place to add rate limiting, and analytics in Phase H
	have one place to instrument.

	V1 surface is intentionally narrow: just `ApplyToHumanoid` which
	wraps `humanoid:TakeDamage`. Phase F adds:
	  - sourceTrust check (e.g., reject damage where the source isn't
	    a registered Combat actor)
	  - per-source-per-target rate limiting
	  - audit log for "credits-impacting" damage events (defender
	    raids etc.)

	Public API:
	  ApplyToHumanoid(target, amount, sourceLabel)  — applies + emits
	                                                  to QuestObjectives
--]]

local QuestObjectives = require(script.Parent.Parent.Retention.QuestObjectives)

local DamageService = {}

local function findOwningPlayer(humanoid: Humanoid): Player?
	local model = humanoid.Parent
	if not model then
		return nil
	end
	local Players = game:GetService("Players")
	return Players:GetPlayerFromCharacter(model :: any)
end

function DamageService.ApplyToHumanoid(target: Humanoid, amount: number, sourceLabel: string): boolean
	if amount <= 0 or target.Health <= 0 then
		return false
	end
	target:TakeDamage(amount)

	-- Emit a quest event for player-targeting damage so a future
	-- "take_damage" objective can hook in. Aliens taking damage
	-- (player → alien) emit a different event (E2.5 / G's turret
	-- service handles that path).
	local player = findOwningPlayer(target)
	if player then
		QuestObjectives.Emit("damage_taken", player, math.floor(amount))
	end
	return true
end

return DamageService
