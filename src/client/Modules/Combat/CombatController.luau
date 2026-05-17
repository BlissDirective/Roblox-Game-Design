--!strict
--[[
	Outpost-7 — wave HUD overlay (client).

	Phase E2. Listens to `WaveStarted` and `WaveEnded` Remotes and
	renders a top-center wave indicator with a 1Hz countdown.

	UI is placeholder per the rest of the V1 client surface — Phase G
	replaces with the neon-tactical theme + wave alarm SFX.

	Public API:
	  Init  — wires Remote listeners + builds UI
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local CombatController = {}

type StartInfo = {
	waveNumber: number,
	alienCount: number,
	endsAt: number,
	reason: string,
}

type EndResult = {
	waveNumber: number,
	survived: boolean,
	aliensRemaining: number,
}

local activeStart: StartInfo? = nil

local function ensureScreenGui(): ScreenGui
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local gui = pg:FindFirstChild("OutpostCombat")
	if gui and gui:IsA("ScreenGui") then
		return gui
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "OutpostCombat"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg
	return gui :: ScreenGui
end

local function reasonLabel(reason: string): string
	if reason == "queue_deadline" then
		return "no match — fallback"
	elseif reason == "clock" then
		return "night cycle"
	end
	return reason
end

local function buildWaveBanner(start: StartInfo): TextLabel
	local gui = ensureScreenGui()
	local banner = gui:FindFirstChild("WaveBanner")
	if banner and banner:IsA("TextLabel") then
		return banner
	end

	local label = Instance.new("TextLabel")
	label.Name = "WaveBanner"
	label.Size = UDim2.fromOffset(360, 56)
	label.Position = UDim2.new(0.5, -180, 0, 8)
	label.BackgroundColor3 = Color3.fromRGB(40, 12, 16)
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.fromRGB(255, 220, 120)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = string.format("Wave %d — %ds", start.waveNumber, math.max(0, start.endsAt - os.time()))

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 90, 60)
	stroke.Parent = label

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label

	label.Parent = gui
	return label
end

local function showResultToast(result: EndResult)
	local gui = ensureScreenGui()
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.fromOffset(360, 64)
	toast.Position = UDim2.new(0.5, -180, 0, 80)
	toast.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	toast.BorderSizePixel = 0
	toast.TextColor3 = Color3.fromRGB(220, 220, 235)
	toast.TextScaled = true
	toast.Font = Enum.Font.GothamBold
	if result.survived then
		toast.Text = string.format("Wave %d survived", result.waveNumber)
	else
		toast.Text = string.format("Wave %d failed", result.waveNumber)
	end

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = if result.survived then Color3.fromRGB(80, 200, 160) else Color3.fromRGB(220, 80, 90)
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
end

local function clearBanner()
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local gui = pg:FindFirstChild("OutpostCombat")
	if not gui then
		return
	end
	local banner = gui:FindFirstChild("WaveBanner")
	if banner then
		banner:Destroy()
	end
end

function CombatController.Init()
	local startedRemote = Remotes.WaveStarted :: RemoteEvent
	startedRemote.OnClientEvent:Connect(function(info: any)
		if typeof(info) ~= "table" then
			return
		end
		activeStart = info :: StartInfo
		local banner = buildWaveBanner(activeStart)

		-- 1Hz countdown until the banner is replaced or removed.
		task.spawn(function()
			while activeStart and activeStart.endsAt > os.time() do
				if not banner.Parent then
					return
				end
				banner.Text = string.format(
					"Wave %d (%s) — %ds — %d aliens",
					activeStart.waveNumber,
					reasonLabel(activeStart.reason),
					math.max(0, activeStart.endsAt - os.time()),
					activeStart.alienCount
				)
				task.wait(1)
			end
		end)
	end)

	local endedRemote = Remotes.WaveEnded :: RemoteEvent
	endedRemote.OnClientEvent:Connect(function(result: any)
		if typeof(result) ~= "table" then
			return
		end
		activeStart = nil
		clearBanner()
		showResultToast(result :: EndResult)
	end)
end

return CombatController
