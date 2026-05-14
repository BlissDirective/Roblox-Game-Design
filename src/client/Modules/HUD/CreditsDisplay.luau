--!strict
--[[
	Outpost-7 — Credits HUD readout.

	Phase B4 (original). Phase G5 theme migration.

	Top-right ScreenGui pill showing the player's current Credits.
	Server-authoritative — listens to `Remotes.CreditsChanged` and
	never trusts a local value. On every value change, the pill flashes
	the highlight color briefly (HudPill:FlashHighlight) for a
	"something just changed" visual cue.

	Theming: routed through `Components.HudPill` + the `accent` palette
	slot. Biome swap re-tints automatically via the Components
	Theme.Changed subscription.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudFormat = require(Shared:WaitForChild("Modules"):WaitForChild("Lib"):WaitForChild("HudFormat"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))

local CreditsDisplay = {}

local pill: any = nil

local function setText(value: number)
	if pill then
		pill:SetText(string.format("%s Credits", HudFormat.Abbreviated(value)))
		pill:FlashHighlight()
	end
end

local function build()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("CreditsHud")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CreditsHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	pill = Components.HudPill({
		parent = gui,
		name = "CreditsPill",
		size = UDim2.fromOffset(220, 56),
		position = UDim2.new(1, -240, 0, 16),
		text = "0 Credits",
		strokeSlot = "accent",
		textSlot = "textPrimary",
	})
end

function CreditsDisplay.Init()
	build()
	local remote = Remotes.CreditsChanged :: RemoteEvent
	remote.OnClientEvent:Connect(function(newCredits: number)
		setText(newCredits)
	end)
end

return CreditsDisplay
