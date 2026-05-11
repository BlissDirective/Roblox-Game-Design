--!strict
--[[
	Outpost-7 — cosmetic ownership + equip + apply service.

	Phase G7. Closes the D4 BattlePass launch-blocker tech debt:
	cosmetic-marked BP tiers grant items here instead of placeholder
	Credits/Cores. Per the user's G7 design call (2026-05-05):
	  - 8-slot maximalist scope (V1 catalog covers 4 slots; 4 reserved
	    for V1.5/V2)
	  - Additive BP rewards (cr/cores + cosmetic at 6 milestone tiers)
	  - VIP pass unlock-only + toast (not auto-equip)
	  - Combatant skin auto-equipped on first join

	Server is the single writer of `profile.cosmeticsOwned` and
	`profile.equippedCosmetics`. EquipCosmetic Remote validates:
	  1. Slot is a known Constants.COSMETIC.Slots value
	  2. cosmeticId is in CosmeticRegistry
	  3. cosmetic.slot matches the slot arg (no cross-slot cheats)
	  4. Player owns the cosmetic

	Apply path (V1 placeholder — Phase G art queue replaces):
	  - skin: rebuild character with a body-color tint matching the
	    cosmetic. Real BodyParts swap is Phase G+H asset pipeline.
	  - helmet_decal: apply Decal to Head BasePart (placeholder color
	    tint until real decals upload).
	  - drone_trail: stored on profile only; DroneSwarmService reads
	    via `GetEquippedTrailColor` and overrides the preset color.
	  - nameplate_flair: stored on profile; Phase G chat/HUD module
	    reads (V1 ships no visible application — UI surfacing in G5).

	Public API:
	  Init                            — wires PlayerAdded grants + Remote
	  GrantCosmetic(player, id)       — non-yielding; idempotent
	  TryEquip(player, slot, id)      — non-yielding; returns Result
	  GetEquippedTrailColor(player)   — non-yielding; for DroneSwarmService
	  ApplyToCharacter(player)        — applies all equipped cosmetics
	                                    to the current character
	  PushStateToPlayer(player)       — fires CosmeticState Remote
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CosmeticRegistry =
	require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("CosmeticRegistry"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local AntiExploit = require(script.Parent.Parent.Security.AntiExploit)
local AuditLog = require(script.Parent.Parent.Security.AuditLog)
local RemoteValidator = require(script.Parent.Parent.Security.RemoteValidator)

local CosmeticService = {}

export type State = {
	owned: { [string]: number }, -- cosmeticId -> acquiredAt
	equipped: { [string]: string }, -- slot -> cosmeticId
}

export type Result = {
	ok: true,
	state: State,
} | {
	ok: false,
	error: string,
}

export type UnlockToast = {
	cosmeticId: string,
	source: string,
}

local function pushStateToClient(player: Player)
	local data = DataManager.GetData(player)
	if not data then
		return
	end
	local remote = Remotes.CosmeticState :: RemoteEvent
	remote:FireClient(player, {
		owned = data.cosmeticsOwned,
		equipped = data.equippedCosmetics,
	} :: State)
end

local function fireUnlockToast(player: Player, cosmeticId: string)
	local def = CosmeticRegistry.Get(cosmeticId)
	if not def then
		return
	end
	local remote = Remotes.CosmeticUnlocked :: RemoteEvent
	remote:FireClient(player, {
		cosmeticId = cosmeticId,
		source = def.source,
	} :: UnlockToast)
end

-- Apply cosmetic to the character. V1 placeholder: BodyColors tint for
-- skin; Decal for helmet. Real BodyParts swap is Phase G art queue.
local function applyCosmeticToCharacter(player: Player, slot: string, cosmeticId: string)
	local character = player.Character
	if not character then
		return
	end
	local def = CosmeticRegistry.Get(cosmeticId)
	if not def then
		return
	end

	if slot == Constants.COSMETIC.Slots.Skin then
		-- V1 placeholder: tint BodyColors via the operator's parts.
		-- Phase G replaces with BodyParts swap from imported MeshParts.
		local bodyColors = character:FindFirstChildOfClass("BodyColors")
		if not bodyColors then
			bodyColors = Instance.new("BodyColors")
			bodyColors.Parent = character
		end
		local primaryBrickColor = BrickColor.new(def.color)
		bodyColors.HeadColor = primaryBrickColor
		bodyColors.TorsoColor = primaryBrickColor
		bodyColors.LeftArmColor = primaryBrickColor
		bodyColors.RightArmColor = primaryBrickColor
		bodyColors.LeftLegColor = primaryBrickColor
		bodyColors.RightLegColor = primaryBrickColor
	elseif slot == Constants.COSMETIC.Slots.HelmetDecal then
		-- V1 placeholder: spawn a thin colored Part on the head ridge
		-- as a "decal" stand-in. Phase G replaces with Decal + uploaded
		-- texture from the asset pipeline.
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local existing = head:FindFirstChild("OutpostHelmetDecal")
			if existing then
				existing:Destroy()
			end
			if cosmeticId ~= "decal_default" then
				local decalPart = Instance.new("Part")
				decalPart.Name = "OutpostHelmetDecal"
				decalPart.Size = Vector3.new(0.8, 0.15, 0.15)
				decalPart.Color = def.color
				decalPart.Material = Enum.Material.Neon
				decalPart.CanCollide = false
				decalPart.Massless = true
				decalPart.CFrame = head.CFrame * CFrame.new(0, 0.5, -0.3)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = decalPart
				weld.Part1 = head
				weld.Parent = decalPart
				decalPart.Parent = head
			end
		end
	end
	-- drone_trail + nameplate_flair: no character-side application;
	-- DroneSwarmService reads trail at fire time; nameplate is HUD-only.
end

function CosmeticService.ApplyToCharacter(player: Player)
	local data = DataManager.GetData(player)
	if not data then
		return
	end
	for slot, cosmeticId in data.equippedCosmetics do
		applyCosmeticToCharacter(player, slot, cosmeticId)
	end
end

-- Returns the equipped drone trail's color, OR nil if the player has
-- the default trail (caller falls back to preset color). Called by
-- DroneSwarmService per-shot.
function CosmeticService.GetEquippedTrailColor(player: Player): Color3?
	local data = DataManager.GetData(player)
	if not data then
		return nil
	end
	local equippedId = data.equippedCosmetics[Constants.COSMETIC.Slots.DroneTrail]
	if not equippedId or equippedId == "trail_default" then
		return nil
	end
	local def = CosmeticRegistry.Get(equippedId)
	if not def then
		return nil
	end
	return def.color
end

local function ownedCount(data: any): number
	local n = 0
	for _ in data.cosmeticsOwned do
		n += 1
	end
	return n
end

function CosmeticService.GrantCosmetic(player: Player, cosmeticId: string): boolean
	local def = CosmeticRegistry.Get(cosmeticId)
	if not def then
		warn(string.format("[CosmeticService] Unknown cosmetic id %s for grant", cosmeticId))
		return false
	end
	local data = DataManager.GetData(player)
	if not data then
		return false
	end
	if data.cosmeticsOwned[cosmeticId] then
		return false -- idempotent re-grant
	end
	if ownedCount(data) >= Constants.COSMETIC.MaxOwnedCosmetics then
		warn(string.format("[CosmeticService] %s inventory cap hit; refusing %s", player.Name, cosmeticId))
		return false
	end
	data.cosmeticsOwned[cosmeticId] = os.time()
	fireUnlockToast(player, cosmeticId)
	pushStateToClient(player)
	print(string.format("[CosmeticService] %s unlocked %s (%s)", player.Name, cosmeticId, def.source))
	return true
end

function CosmeticService.TryEquip(player: Player, slot: string, cosmeticId: string): Result
	local data = DataManager.GetData(player)
	if not data then
		return { ok = false, error = "no profile" }
	end
	-- Validate slot.
	local slotKnown = false
	for _, slotValue in Constants.COSMETIC.Slots do
		if slotValue == slot then
			slotKnown = true
			break
		end
	end
	if not slotKnown then
		return { ok = false, error = "unknown slot" }
	end
	-- Validate cosmetic + ownership + slot match.
	local def = CosmeticRegistry.Get(cosmeticId)
	if not def then
		return { ok = false, error = "unknown cosmetic" }
	end
	if def.slot ~= slot then
		return { ok = false, error = "cosmetic does not fit slot" }
	end
	if not data.cosmeticsOwned[cosmeticId] then
		return { ok = false, error = "cosmetic not owned" }
	end
	data.equippedCosmetics[slot] = cosmeticId
	applyCosmeticToCharacter(player, slot, cosmeticId)
	pushStateToClient(player)
	print(string.format("[CosmeticService] %s equipped %s in slot %s", player.Name, cosmeticId, slot))
	return { ok = true, state = { owned = data.cosmeticsOwned, equipped = data.equippedCosmetics } }
end

function CosmeticService.PushStateToPlayer(player: Player)
	pushStateToClient(player)
end

local function ensureDefaults(player: Player)
	local data = DataManager.GetData(player)
	if not data then
		return
	end
	for slot, cosmeticId in Constants.COSMETIC.Defaults do
		-- Grant ownership (idempotent — GrantCosmetic short-circuits if owned).
		if not data.cosmeticsOwned[cosmeticId] then
			CosmeticService.GrantCosmetic(player, cosmeticId)
		end
		-- Equip if slot empty (preserves player's manual equip on rejoin).
		if not data.equippedCosmetics[slot] then
			data.equippedCosmetics[slot] = cosmeticId
		end
	end
end

function CosmeticService.Init()
	-- Wire EquipCosmetic Remote.
	local equipRemote = Remotes.EquipCosmetic :: RemoteFunction
	equipRemote.OnServerInvoke = function(player: Player, slot: any, cosmeticId: any): Result
		if not AntiExploit.RateCheck(player, "EquipCosmetic") then
			AuditLog.Record(player, "rate_limited", "EquipCosmetic")
			return { ok = false, error = "rate-limited" }
		end
		local slotOk = RemoteValidator.IsString(slot, 1, 32)
		local idOk = RemoteValidator.IsString(cosmeticId, 1, 64)
		if not (slotOk and idOk) then
			AuditLog.Record(player, "validation_failed", "EquipCosmetic: slot/id invalid")
			return { ok = false, error = "invalid slot or cosmetic id" }
		end
		return CosmeticService.TryEquip(player, slot, cosmeticId)
	end

	-- Grant defaults + apply on join + on respawn.
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			DataManager.WaitForData(player)
			if not player:IsDescendantOf(Players) then
				return
			end
			ensureDefaults(player)
			pushStateToClient(player)
			-- Apply on first character spawn (which usually fires
			-- before/around this point — connect for future respawns).
			if player.Character then
				CosmeticService.ApplyToCharacter(player)
			end
		end)
		player.CharacterAdded:Connect(function()
			task.wait(0.1) -- let BodyColors / Head settle
			if player:IsDescendantOf(Players) then
				CosmeticService.ApplyToCharacter(player)
			end
		end)
	end)
	-- Existing players (Studio reload during dev).
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			ensureDefaults(player)
			pushStateToClient(player)
			if player.Character then
				CosmeticService.ApplyToCharacter(player)
			end
		end)
	end
end

return CosmeticService
