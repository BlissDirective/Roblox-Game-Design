--!strict
--[[
	Outpost-7 — Cores HUD readout.

	Phase D5 (original). Phase G5 theme migration.

	Top-right ScreenGui pill showing the player's current Cores (premium
	currency). Server-authoritative — listens to `Remotes.CoresChanged`.
	Sits to the left of the CreditsHud pill.

	Theming: routed through `Components.HudPill` + the `secondary`
	palette slot — distinguishes the premium currency from the credits
	pill at a glance across all biome themes.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudFormat = require(Shared:WaitForChild("Modules"):WaitForChild("Lib"):WaitForChild("HudFormat"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))

local CoresDisplay = {}

local pill: any = nil

local function setText(value: number)
	if pill then
		pill:SetText(string.format("%s Cores", HudFormat.Abbreviated(value)))
		pill:FlashHighlight()
	end
end

local function build()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("CoresHud")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CoresHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	pill = Components.HudPill({
		parent = gui,
		name = "CoresPill",
		size = UDim2.fromOffset(220, 56),
		position = UDim2.new(1, -470, 0, 16),
		text = "0 Cores",
		strokeSlot = "secondary",
		textSlot = "textPrimary",
	})
end

function CoresDisplay.Init()
	build()
	local remote = Remotes.CoresChanged :: RemoteEvent
	remote.OnClientEvent:Connect(function(newCores: number)
		setText(newCores)
	end)
end

return CoresDisplay
