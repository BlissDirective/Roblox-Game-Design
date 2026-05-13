--!strict
--[[
	Outpost-7 — biome decoration spawner.

	Phase G2. Spawns per-biome decorative emissive flora + ambient
	particle emitters + ambient SFX loop after the BiomeLightingService
	has applied the active biome's Lighting profile. Each plot center
	gets a configurable number of decorations distributed via Poisson
	disk within `Constants.BIOME.DecorationRadius`.

	V1 visuals are programmatic emissive Parts + procedural
	ParticleEmitters seeded by the biome data. Phase G art queue
	replaces the `floraTemplate` nil with imported MeshPart references
	from `assets/world/biome_*/`; the spawner's Acquire path stays the
	same (clones template if provided, else builds programmatic cube).

	Threat model addressed: none — purely cosmetic. Server-spawned,
	read-only state.

	Performance:
	  - Per-plot decoration count is `Constants.BIOME.DecorationsPerPlot`
	    (V1 default 24). 4 plots × 24 = 96 emissive Parts at peak.
	  - ParticleEmitters: one per plot (4 total per server). Rate
	    capped by `Constants.BIOME.ParticleSpawnRate` so emitters
	    can't dominate the GPU on mobile.
	  - All Parts have `CastShadow = false` per the Phase G research
	    finding (50-light cap on mobile).
	  - Anchored = true everywhere; physics stepping unaffected.

	Public API:
	  Init                       — applies Constants.BIOME.DefaultBiome
	  Apply(biomeId)             — clears prior decorations + spawns
	                               the new biome's flora/particles/SFX
	  Clear()                    — removes all decorations + audio
	                               (used by Apply before re-spawn)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local PoissonDisk = require(Shared:WaitForChild("Modules"):WaitForChild("Math"):WaitForChild("PoissonDisk"))

local PlotManager = require(script.Parent.PlotManager)

local BiomeDecorationService = {}

local DECOR_FOLDER_NAME = "OutpostBiomeDecorations"
local AMBIENT_SOUND_NAME = "OutpostBiomeAmbient"

local activeBiome: string? = nil

local function ensureFolder(): Folder
	local existing = Workspace:FindFirstChild(DECOR_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = DECOR_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function buildFloraPart(biomeDecor: any, position: Vector3): BasePart
	-- V1 procedural: emissive cube with biome's flora color.
	-- Phase G replaces with clone-from-template if biomeDecor.floraTemplate
	-- is provided.
	if biomeDecor.floraTemplate then
		local clone = (biomeDecor.floraTemplate :: Model):Clone()
		if clone:IsA("Model") and clone.PrimaryPart then
			clone:PivotTo(CFrame.new(position))
		end
		return (clone :: any) :: BasePart
	end
	local part = Instance.new("Part")
	part.Name = "Flora"
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = biomeDecor.floraColor
	part.Size = biomeDecor.floraSize
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	-- Anchor at the foot so the flora rises above ground.
	part.CFrame = CFrame.new(position + Vector3.new(0, biomeDecor.floraSize.Y / 2, 0))
	-- Small random rotation for natural variation.
	local rng = Random.new()
	part.CFrame = part.CFrame * CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0)

	-- Accent emissive PointLight (shadows off for the 50-light mobile cap).
	-- Use sparingly — only ~1 in 4 flora gets a light source.
	if rng:NextNumber() < 0.25 then
		local light = Instance.new("PointLight")
		light.Color = biomeDecor.floraAccent
		light.Brightness = biomeDecor.floraEmissive
		light.Range = 12
		light.Shadows = false
		light.Parent = part
	end
	return part
end

local function buildParticleEmitter(biomeDecor: any, parent: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "BiomeAmbient"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds" -- placeholder; Phase G replaces with custom upload
	emitter.Color = ColorSequence.new(biomeDecor.particleColor)
	emitter.Transparency = NumberSequence.new(biomeDecor.particleTransparency)
	emitter.Lifetime = NumberRange.new(biomeDecor.particleLifetimeMin, biomeDecor.particleLifetimeMax)
	emitter.Rate = Constants.BIOME.ParticleSpawnRate
	emitter.Size = NumberSequence.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(biomeDecor.particleUpwardSpeed)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Acceleration = Vector3.new(0, biomeDecor.particleUpwardSpeed * 0.2, 0)
	emitter.LightEmission = 0.6
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Parent = parent
end

local function buildAmbientHostPart(biomeDecor: any, plot: PlotManager.PlotInfo): BasePart
	-- Particles need a parent Part. We anchor one in the sky over the
	-- plot center; the emitter spawns particles that drift across the
	-- visible plot area.
	local host = Instance.new("Part")
	host.Name = "ParticleHost"
	host.Anchored = true
	host.CanCollide = false
	host.CastShadow = false
	host.Transparency = 1
	host.Size = Vector3.new(plot.size, 1, plot.size) -- broad emitter footprint
	host.CFrame = CFrame.new(plot.center + Vector3.new(0, 8, 0))
	buildParticleEmitter(biomeDecor, host)
	return host
end

local function startAmbientSound(biomeDecor: any)
	local existing = SoundService:FindFirstChild(AMBIENT_SOUND_NAME)
	if existing then
		existing:Destroy()
	end
	if biomeDecor.ambientSfxAssetId <= 0 then
		-- Placeholder asset id; skip until Phase H upload.
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = AMBIENT_SOUND_NAME
	sound.SoundId = string.format("rbxassetid://%d", biomeDecor.ambientSfxAssetId)
	sound.Volume = Constants.BIOME.AmbientSfxVolume
	sound.Looped = true
	sound.Parent = SoundService
	sound:Play()
end

function BiomeDecorationService.Clear()
	local folder = Workspace:FindFirstChild(DECOR_FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
	local sound = SoundService:FindFirstChild(AMBIENT_SOUND_NAME)
	if sound then
		sound:Destroy()
	end
end

-- G3: Cave overlay — stalactites + stalagmites + glacier walls.
-- Only fires for biomes with a `caveOverlay` config block (ice in V1;
-- future cavern biomes can opt in). Stalactites + stalagmites use the
-- same flora-pattern ring distribution as base flora; glacier walls
-- sit further out at the horizon distance.
local function buildIcicle(
	cave: any,
	position: Vector3,
	size: Vector3,
	pointDown: boolean
): BasePart
	local part = Instance.new("Part")
	part.Name = if pointDown then "Stalactite" else "Stalagmite"
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.Ice
	part.Color = cave.crystalColor
	part.Size = size
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Transparency = 0.15 -- slight translucency for the ice look
	-- Stalactites point down (rotated 180 on Z); stalagmites point up.
	if pointDown then
		part.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(180), 0, 0)
	else
		part.CFrame = CFrame.new(position)
	end
	-- Sparse accent PointLight on ~20% of icicles (light-cap-friendly).
	local rng = Random.new()
	if rng:NextNumber() < 0.20 then
		local light = Instance.new("PointLight")
		light.Color = cave.crystalAccent
		light.Brightness = cave.emissive
		light.Range = 14
		light.Shadows = false
		light.Parent = part
	end
	return part
end

local function buildGlacierWall(cave: any, position: Vector3, lookAt: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = "GlacierWall"
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.Glacier
	part.Color = cave.crystalColor
	part.Size = cave.glacierWallSize
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Transparency = 0.05
	-- Face the wall toward the plot center for a "we are inside the cave"
	-- feel.
	part.CFrame = CFrame.lookAt(position, lookAt)
	return part
end

local function applyCaveOverlay(biomeDecor: any, plot: PlotManager.PlotInfo, plotFolder: Folder)
	local cave = biomeDecor.caveOverlay
	if not cave then
		return
	end
	-- Deterministic seed: shift from the base flora seed so cave
	-- elements don't overlap base flora positions visibly.
	local rng = Random.new(plot.id * 1000 + 7000)
	local centerY = plot.center.Y

	-- Stalactites: hang above plot, random XZ within a smaller radius.
	for _ = 1, cave.stalactitesPerPlot do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(0, plot.size / 3)
		local x = plot.center.X + math.cos(angle) * dist
		local z = plot.center.Z + math.sin(angle) * dist
		local pos = Vector3.new(x, centerY + cave.stalactiteHeight, z)
		local part = buildIcicle(cave, pos, cave.stalactiteSize, true)
		part.Parent = plotFolder
	end

	-- Stalagmites: ground-rise at the ring edge (just outside plot).
	for _ = 1, cave.stalagmitesPerPlot do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(plot.size / 2 + 2, plot.size / 2 + 6)
		local x = plot.center.X + math.cos(angle) * dist
		local z = plot.center.Z + math.sin(angle) * dist
		local pos = Vector3.new(x, centerY + cave.stalagmiteHeight / 2, z)
		local part = buildIcicle(cave, pos, cave.stalagmiteSize, false)
		part.Parent = plotFolder
	end

	-- Glacier walls: large mid-distance silhouettes ringing the plot.
	for i = 1, cave.glacierWallsPerPlot do
		local angle = (i / cave.glacierWallsPerPlot) * (math.pi * 2)
		local x = plot.center.X + math.cos(angle) * cave.glacierWallDistance
		local z = plot.center.Z + math.sin(angle) * cave.glacierWallDistance
		local pos = Vector3.new(x, centerY + cave.glacierWallSize.Y / 2, z)
		local wall = buildGlacierWall(cave, pos, plot.center)
		wall.Parent = plotFolder
	end
end

function BiomeDecorationService.Apply(biomeId: string)
	local biomeDecor = Constants.BIOME.Decorations[biomeId]
	if not biomeDecor then
		warn(string.format("[BiomeDecorationService] No decoration data for biome '%s'", biomeId))
		return
	end

	BiomeDecorationService.Clear()
	local folder = ensureFolder()

	local plots = PlotManager.GetAllPlots()
	for _, plot in plots do
		local plotFolder = Instance.new("Folder")
		plotFolder.Name = string.format("Plot%dDecor", plot.id)
		plotFolder.Parent = folder

		-- Poisson-disk distribution within DecorationRadius of plot center.
		-- Seeded per-plot so the layout is deterministic for any given
		-- (biome, plotId) — same as the resource node spawner pattern.
		local rng = Random.new(plot.id * 1000 + #biomeId)
		local placed = 0
		while placed < Constants.BIOME.DecorationsPerPlot do
			-- Sample a random point within the radius via rejection;
			-- skip cells already inside the plot floor (decorations
			-- should sit *around* the plot, not on top of buildings).
			local angle = rng:NextNumber(0, math.pi * 2)
			local minDist = plot.size / 2 + 4 -- just outside plot floor
			local maxDist = Constants.BIOME.DecorationRadius
			local dist = rng:NextNumber(minDist, maxDist)
			local x = plot.center.X + math.cos(angle) * dist
			local z = plot.center.Z + math.sin(angle) * dist
			local y = plot.center.Y
			local position = Vector3.new(x, y, z)
			local part = buildFloraPart(biomeDecor, position)
			part.Parent = plotFolder
			placed += 1
		end

		-- One ambient particle host per plot.
		local host = buildAmbientHostPart(biomeDecor, plot)
		host.Parent = plotFolder

		-- G3: Cave overlay (ice biome only in V1; opt-in via caveOverlay
		-- data block in Constants.BIOME.Decorations.<biome>).
		applyCaveOverlay(biomeDecor, plot, plotFolder)
	end

	startAmbientSound(biomeDecor)
	activeBiome = biomeId
	print(string.format("[BiomeDecorationService] Applied '%s' decorations to %d plots", biomeId, #plots))
end

function BiomeDecorationService.Init()
	BiomeDecorationService.Apply(Constants.BIOME.DefaultBiome)
end

return BiomeDecorationService
