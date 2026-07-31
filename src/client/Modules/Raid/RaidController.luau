--!strict
--[[
	Outpost-7 — raid queue UI controller.

	Phase E1. Minimal V1 queue surface: a "Queue for Raid" button that
	invokes `Remotes.RaidQueue` and a status label that follows server-
	pushed `RaidQueueState` updates. When the round ends, a brief
	results banner pops on `RaidEnded`.

	UI is intentionally placeholder-tier (Phase G replaces with the
	neon-tactical theme). The button + label live in the same HUD
	row as Store / Battle Pass for now; F4 / G repositions per device.

	Public API:
	  Init  — wires Remote listeners + builds UI
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Enums = require(Shared:WaitForChild("Enums"))

local ModeController = require(script.Parent.Parent.Core.ModeController)

local RaidController = {}

type QueueState = {
	queued: boolean,
	matched: boolean,
	deadlineAt: number?,
	error: string?,
}

local function ensureScreenGui(): ScreenGui
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local gui = pg:FindFirstChild("OutpostRaid")
	if gui and gui:IsA("ScreenGui") then
		return gui
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "OutpostRaid"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg
	return gui :: ScreenGui
end

local currentState: QueueState = { queued = false, matched = false }

local function describe(state: QueueState): string
	if state.error then
		return string.format("Queue: %s", state.error)
	end
	if state.matched then
		return "Match found — teleporting…"
	end
	if state.queued then
		if state.deadlineAt then
			local secs = math.max(0, state.deadlineAt - os.time())
			return string.format("Searching… (%ds)", secs)
		end
		return "Searching…"
	end
	return "Queue for Raid"
end

local function buildUI()
	local gui = ensureScreenGui()
	local btn = Instance.new("TextButton")
	btn.Name = "RaidQueueButton"
	btn.Size = UDim2.fromOffset(168, 40)
	btn.Position = UDim2.new(0, 432, 0, 8)
	btn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	btn.BorderSizePixel = 0
	btn.TextColor3 = Color3.fromRGB(220, 220, 235)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.Text = describe(currentState)
	btn.AutoButtonColor = true

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(220, 80, 90)
	stroke.Parent = btn

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	btn.Parent = gui

	local function refresh()
		btn.Text = describe(currentState)
	end

	-- 1Hz refresh while queued so the deadline countdown ticks.
	task.spawn(function()
		while btn.Parent do
			task.wait(1)
			if currentState.queued and currentState.deadlineAt then
				refresh()
			end
		end
	end)

	btn.MouseButton1Click:Connect(function()
		local action = if currentState.queued then "cancel" else "queue"
		local remote = Remotes.RaidQueue :: RemoteFunction
		local ok, result = pcall(function()
			return remote:InvokeServer(action)
		end)
		if not ok then
			warn(string.format("[RaidController] RaidQueue invoke failed: %s", tostring(result)))
			return
		end
		if typeof(result) == "table" and result.ok and typeof(result.state) == "table" then
			currentState = result.state
			refresh()
		end
	end)

	return refresh
end

function RaidController.Init()
	local refresh = buildUI()

	-- R2: when a raid round begins (raid place), drop into Combat mode so the
	-- camera goes first-person and the weapon is enabled for the assault.
	local startedRemote = Remotes.RaidStarted :: RemoteEvent
	startedRemote.OnClientEvent:Connect(function()
		ModeController.SetMode(Enums.Mode.Combat)
	end)

	-- R2b: live raid HUD — loot banked, extractors smashed, round timer.
	local function ensureProgressLabel(): TextLabel
		local gui = ensureScreenGui()
		local existing = gui:FindFirstChild("RaidProgress")
		if existing and existing:IsA("TextLabel") then
			return existing
		end
		local label = Instance.new("TextLabel")
		label.Name = "RaidProgress"
		label.Size = UDim2.fromOffset(360, 40)
		label.Position = UDim2.new(0.5, -180, 0, 8)
		label.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
		label.BorderSizePixel = 0
		label.TextColor3 = Color3.fromRGB(255, 220, 120)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(220, 80, 90)
		stroke.Parent = label
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = label
		label.Parent = gui
		return label
	end

	-- R4: Emergency Shield indicator — a countdown while the colony is
	-- raid-immune. Server pushes shieldedUntil on join + on purchase.
	local shieldedUntil = 0
	local shieldRemote = Remotes.ShieldState :: RemoteEvent
	shieldRemote.OnClientEvent:Connect(function(until_: any)
		if typeof(until_) == "number" then
			shieldedUntil = until_
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local gui = ensureScreenGui()
			local existing = gui:FindFirstChild("ShieldIndicator")
			local secs = shieldedUntil - os.time()
			if secs > 0 then
				local label = if existing and existing:IsA("TextLabel") then existing else nil
				if not label then
					label = Instance.new("TextLabel")
					label.Name = "ShieldIndicator"
					label.Size = UDim2.fromOffset(180, 32)
					label.Position = UDim2.new(0, 16, 0, 96)
					label.BackgroundColor3 = Color3.fromRGB(18, 30, 40)
					label.BorderSizePixel = 0
					label.TextColor3 = Color3.fromRGB(120, 220, 255)
					label.TextScaled = true
					label.Font = Enum.Font.GothamBold
					local corner = Instance.new("UICorner")
					corner.CornerRadius = UDim.new(0, 6)
					corner.Parent = label
					label.Parent = gui
				end
				label.Text = string.format("🛡 Shielded %d:%02d", math.floor(secs / 60), secs % 60)
			elseif existing then
				existing:Destroy()
			end
		end
	end)

	local progressRemote = Remotes.RaidProgress :: RemoteEvent
	progressRemote.OnClientEvent:Connect(function(p: any)
		if typeof(p) ~= "table" then
			return
		end
		local secs = math.max(0, (p.endsAt or os.time()) - os.time())
		ensureProgressLabel().Text = string.format(
			"Loot: %d  |  Extractors %d/%d  |  %d:%02d",
			p.extracted or 0,
			p.extractorsDown or 0,
			p.totalExtractors or 0,
			math.floor(secs / 60),
			secs % 60
		)
	end)

	local stateRemote = Remotes.RaidQueueState :: RemoteEvent
	stateRemote.OnClientEvent:Connect(function(state: any)
		if typeof(state) ~= "table" then
			return
		end
		currentState = state :: QueueState
		refresh()
	end)

	-- Brief results toast on RaidEnded — both attacker (in raid place
	-- before teleport) and defender (in main place via reward relay)
	-- receive this. UI is purposely placeholder.
	local endedRemote = Remotes.RaidEnded :: RemoteEvent
	endedRemote.OnClientEvent:Connect(function(outcome: any)
		if typeof(outcome) ~= "table" then
			return
		end
		local gui = ensureScreenGui()
		-- Clear the R2b live raid HUD, if present.
		local progressLabel = gui:FindFirstChild("RaidProgress")
		if progressLabel then
			progressLabel:Destroy()
		end
		local toast = Instance.new("TextLabel")
		toast.Size = UDim2.fromOffset(360, 64)
		toast.Position = UDim2.new(0.5, -180, 0, 80)
		toast.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
		toast.BorderSizePixel = 0
		toast.TextColor3 = Color3.fromRGB(220, 220, 235)
		toast.TextScaled = true
		toast.Font = Enum.Font.GothamBold

		local isAttacker = Players.LocalPlayer.UserId == outcome.attackerUserId
		if isAttacker then
			toast.Text = if outcome.attackerWon
				then string.format("Raid won — +%d credits", outcome.attackerCreditsDelta)
				else string.format("Raid failed — +%d credits", outcome.attackerCreditsDelta)
		else
			local stolen = outcome.defenderCreditsStolen or 0
			if stolen > 0 then
				toast.Text = string.format("Colony raided! -%d stolen (+%d)", stolen, outcome.defenderCreditsDelta)
			else
				toast.Text = string.format("Colony defended! +%d credits", outcome.defenderCreditsDelta)
			end
		end

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = if isAttacker then Color3.fromRGB(220, 80, 90) else Color3.fromRGB(80, 200, 160)
		stroke.Parent = toast

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = toast

		toast.Parent = gui
		task.delay(5, function()
			if toast.Parent then
				toast:Destroy()
			end
		end)
	end)
end

return RaidController
