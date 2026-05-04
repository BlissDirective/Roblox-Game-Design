# 11 — ASSET_PIPELINE.md

> A menu of AI-assisted tools for the parts of game development that aren't code: 3D models, animations, maps, textures, and the in-Studio AI tooling that ties them together. This is a **neutral options list**, not an opinionated stack — the right pick depends on your aesthetic taste, your budget, and what you're actually building.

---

## Why this doc exists

`01_AGENT.md` says Claude writes the code while the human handles aesthetics. That left a gap: *how* does a beginner solo dev actually produce art for their game? The traditional answer was "learn Blender, learn Maya, hire someone." The 2026 answer is "pick a few AI tools, learn the workflow, and curate ruthlessly."

This doc covers the tools, what each is good for, and how the output flows back into Roblox Studio (usually as MeshParts, animations, or imported scenes via Rojo). It does **not** tell you which one to use. That's a taste decision and you should run a free trial of 2–3 in each category before committing.

A note on the field's volatility: every tool below is real and was active as of early 2026, but the AI asset space is moving fast. Some prices have shifted; some "free" tiers have tightened; some tools have shipped Roblox-specific features since this was written. Treat URLs and exact prices as starting points, not gospel — verify current state on the vendor's site.

---

## Roblox's own first-party AI (start here)

Before reaching for third-party tools, know what Roblox itself ships. These are inside Studio, free, and integrated with the rest of the engine.

### Roblox Studio Assistant

The plain-language AI assistant baked into Studio. Type a prompt; it scaffolds Luau, places parts, generates terrain, suggests fixes. Best used for boilerplate and small targeted tasks. Not a full-game generator.

In April 2026, Roblox added a "Planning Mode" upgrade — Assistant now analyzes your game, asks clarifying questions, builds an editable plan, and can use playtesting tools to verify its own work. This is closer to an agentic copilot than a code-completer.

### Cube 3D / Mesh Generation

Roblox's first-party text-to-mesh tool. In Studio's Assistant panel, type `/generate <prompt>` (e.g., `/generate medieval wooden chair`) and it returns a MeshPart with textures applied automatically.

- Open-source foundation model. Available on GitHub and Hugging Face for off-platform fine-tuning.
- Single-object only — no full scenes yet. Works best on simple objects (furniture, props, weapons). Organic shapes (creatures, characters) tend to be blobby.
- Good for filler/background props and rapid prototyping. For hero assets the player sees up close, you'll still want hand-modeled or third-party AI tools with more control.

### Procedural Model Generation / 4D Generation

Announced 2025–2026 alongside Cube 3D. Generates **interactive, multi-part** models — not just geometry but functional assemblies (e.g., a car you can actually drive). Open beta as of early 2026; expect rough edges. Worth keeping an eye on as it matures, because it eliminates one of the more painful seams in the AI-asset workflow (mesh → rig → behavior).

### Texture Generator

Beta tool that produces PBR maps (diffuse, normal, roughness) from a text prompt at 1024×1024. Integrates directly onto MeshParts. Useful for retexturing imported meshes without leaving Studio.

**Verdict on Roblox's own stack:** if you can do what you need with the in-Studio tools, do it. Lower friction, no third-party rate limits, and it's free.

---

## 3D modeling — making the meshes

Pick by aesthetic and by where in the pipeline you want to spend time.

### Meshy (`meshy.ai`)

Text-to-3D and image-to-3D. Generates a textured mesh in ~60 seconds, exports to FBX/OBJ/GLB/USDZ/STL/BLEND. Free tier exists; paid plans for commercial use and higher volumes. Has a documented Roblox workflow (low-poly mode, 4-bone-per-vertex rigging compliance, single UV set within 0–1).

- Strengths: fast, broad style range, handles low-poly mode well for mobile-friendly Roblox output.
- Weaknesses: complex prompts can produce warped geometry; fine details often miss; characters less reliable than props.

### Sloyd (`sloyd.ai`)

Parametric, game-ready models. Less "describe anything in plain English" and more "pick a template, tweak the parameters." Has a Roblox-specific path — characters fit Roblox's avatar specs and can be rigged in Studio directly. Pro tier lets you resell generated assets as Marketplace items.

- Strengths: Roblox-native style, predictable output, character templates that play nice with R15.
- Weaknesses: less creative range than pure-text-to-3D tools — you're working within their template library.

### Tripo / Rodin

Both are text/image-to-3D character generators with strong character output relative to general-purpose tools. If you're building an RPG or anything character-driven, worth comparing alongside Meshy.

### Spline AI (`spline.design`)

Stylized assets, props, and simple environments. Geared toward web/3D-design workflows but exports work for Roblox.

### Luma (`lumalabs.ai`)

Photogrammetry and capture-based — turn real-world objects (with a phone video) into 3D meshes. Useful if you have a specific real-world reference (a building, a vehicle, a sculpture) you want in the game.

### Blender + BlenderGPT plugin

Blender is still the free, professional-standard 3D tool. The BlenderGPT plugin lets you drive it with natural-language prompts. Worth knowing about if you eventually want full control — but it's a months-long learning curve. For a first project, you can ship without ever opening Blender.

### 3DAIStudio (`3daistudio.com`)

Specifically markets itself as a Roblox-targeted asset generator with quad remeshing for Roblox-friendly topology. Worth a free-trial comparison if Meshy's Roblox output isn't clean enough for you.

---

## Animation — making the rigs move

Animation is where most beginners stall. The tools below sit at different points on the "easy but limited" ↔ "powerful but complex" axis.

### Studio's built-in Animation Editor

Roblox Studio ships with a keyframe-based Animation Editor. For simple animations (idle bob, attack swing, victory pose), this is enough. Free, no export workflow — animations live as Asset IDs you reference in scripts.

### Mixamo (`mixamo.com`, free, owned by Adobe)

Library of pre-made motion-capture animations applied to whatever rig you upload. The classic "free animation" workflow.

- Strength: thousands of mocap animations, free, fast.
- **Watch out:** the Roblox-rig-to-Mixamo round-trip is finicky. Expect to use Blender as a middle step (export Roblox rig → Mixamo → re-import via Blender → Studio). The Roblox Developer Forum has multi-year threads on rig export bugs and R15 compatibility issues. Plan a half-day to get the workflow set up the first time.

### Cascadeur (`cascadeur.com`)

Standalone AI-assisted physics-based animation tool. AutoPosing (set a few key controllers, AI fills in the rest of the body), AutoPhysics (physics-aware corrections), AI Inbetweening (fill frames between keyframes).

- Pricing (verify current rates): **Free** for non-commercial use, but free tier exports only to `.casc` (Cascadeur's proprietary format) — not usable for Roblox. **Indie ($96/year)** unlocks FBX/DAE/USD export and is required if your game earns under $100k/year. **Pro ($396/year)** for higher revenue tiers.
- Strength: realistic physics-grounded motion (fight scenes, falls, jumps) that would take a human animator hours done in minutes.
- Weakness: macOS support only on M1/M2 (no older Intel Macs); a real learning curve.

### DeepMotion Animate 3D (`deepmotion.com`)

Video-to-animation AI motion capture. Upload a video of a human moving; get back an FBX animation that can be retargeted to a Roblox rig. Has an explicit Roblox-default-character path that skips the Blender middle step.

- Strength: quickest path from "I want my character to do this specific thing" → in-game animation, especially for one-off custom motions.
- Weakness: paid (subscription model); face-tracking not available for Roblox characters.

### Roblox AI animation generation (Studio Assistant)

Roblox's own Assistant can produce simple animations from text prompts as part of its broader scripting/scaffolding capability. Quality is uneven and the feature set is evolving — useful for blocking-out ideas, not yet for hero-quality animations.

---

## Map / world building

The biggest payoff vs. effort lever for a solo dev. A tight, atmospheric map with curated free-marketplace assets often beats a sprawling original-art map nobody finishes.

### Studio's Terrain Tool + Toolbox

The native path. Studio's terrain sculpting handles natural environments. The Toolbox has thousands of free user-uploaded models. The skill here is **curation, not creation** — pick 5–10 cohesive assets and use them consistently, instead of dumping 50 random Toolbox items.

**Watch out for unsafe free models.** Toolbox assets sometimes contain malicious scripts (auto-rename Workspace, force-teleport, hidden RemoteEvents). Always check imported models for embedded scripts before placing them in your game.

### Rebirth AI (`userebirth.com`)

Studio plugin that connects Studio to a browser dashboard. Type prompts; the AI writes Luau, builds parts, modifies UI, and executes inside your live Studio session. Markets itself for full-game generation, not just maps, but is genuinely useful for "build me a starter cave system" or "lay out a town square with 5 shops."

- Pricing: 5 free credits on signup, paid plans scale with usage. Verify current pricing.
- Strength: lives inside your Studio session with full hierarchy context; meaningful project-aware code completion and asset placement.
- Overlap warning: this is a competitor to the Claude Code + MCP workflow this project is built around. They can coexist (e.g., use Rebirth for fast scene blocking, Claude Code for systems architecture and complex logic), but if you're already happy with Claude Code, you may not need a second AI tool. Try the free credits before committing.

### Lemonade AI

Studio-native plugin in the same category as Rebirth. Smaller scope, often used for in-context tweaks (modify this part, fix this script). User reports vary widely on quality vs. Rebirth — try both.

### Forge AI (`forge.loopmobile.io`)

Another Studio-native AI copilot, **unrelated to the "Roblox Forge" marketing term used in some 2026 articles**. Bills itself as Roblox-specific Luau + 3D generation, $19/month flat. Worth a look if you want a single-subscription alternative to Rebirth.

---

## How outputs flow back into Studio

Most third-party tools produce assets you import manually. The standard paths:

| Asset type | Format from AI tool | How to bring into Studio |
|---|---|---|
| 3D mesh (single object) | FBX, OBJ, or GLB | Studio: **Workspace → right-click → Import 3D**, or **Home tab → Import 3D** |
| Bulk meshes | FBX (multi-mesh) | Studio: **View → Asset Manager → Import** (auto-splits into separate MeshParts) |
| Animation | FBX | Studio: **Animation Editor → Import** with the rig selected |
| Texture | PNG or PBR map set | Apply to MeshPart's `TextureID` or use Studio's Texture tool |
| Whole scene | `.rbxm` / `.rbxmx` | Drop into `assets/` folder; Rojo syncs into Studio |

If you're using Rojo (and per `07_PROJECT_STRUCTURE.md`, you should be), keep imported binary assets in the `assets/` folder so they get synced and version-controlled alongside your code.

---

## Roblox's mesh constraints (must-respect on import)

Whatever tool generates the mesh, Roblox enforces these limits. Tools like Meshy and Sloyd often handle these for you, but verify on import:

- **Maximum texture resolution:** 1024×1024 per mesh.
- **One material per mesh** (use texture atlases if your model has multiple surface types).
- **Single UV set within 0–1 coordinate space.**
- **Scale:** 1 stud ≈ 0.28 meters. Scale meshes accordingly.
- **Orientation:** characters face positive Z, stand upright on positive Y.
- **Rigging:** max 4 bone influences per vertex; bone transforms frozen at scale 1,1,1 / rotation 0,0,0; root joint at origin.
- **Polycount target:** mobile-first means lean. Aim for low-poly or use the "Low Poly Mode" option that most AI tools expose. Heavy meshes tank framerate on phones, where 80% of your audience is.

Always set `CollisionFidelity` on imported MeshParts to `Box` or `Hull` for physics performance — the visual mesh and the collision mesh don't need to match.

---

## A starter workflow (one suggested path, not the only one)

If you have no idea where to begin, here's a minimal flow that gets you to a playable prototype with custom-feeling assets:

1. **Block out the game** in Studio with default Parts. Don't worry about looks; just confirm the loop works.
2. **Generate hero props with Cube 3D** (`/generate` in Studio Assistant) for the 5–10 objects the player interacts with most. Free, in-Studio, no friction.
3. **Generate background props with Meshy** (or 3DAIStudio) for visual variety. Bulk-generate a small library of 20–30 assets in a consistent style.
4. **Map with Rebirth AI or Studio's terrain tool**, using your prop library as the building blocks.
5. **Pull animations from Mixamo** for any humanoid character motion you can find a match for. Use Cascadeur for the 1–2 custom motions Mixamo doesn't have.
6. **Polish with Studio's Animation Editor** for short bespoke animations (button presses, opening doors, victory poses).
7. **Pull SFX from Studio's audio library** (free, vetted) and music from a CC0 source. Audio is a topic for a separate doc — don't underweight it; horror and atmosphere games live or die on sound design.

---

## What this doc deliberately doesn't tell you

- **Which tool to pick.** That's a taste decision and depends on your aesthetic, budget, and what you're actually building. Try free trials.
- **A complete audio pipeline.** Audio AI tools (music generation, SFX generation, voice synth) deserve their own treatment. For V1, stick to Studio's audio library and CC0 sources.
- **The "best" workflow.** There isn't one. The team that ships *Steal a Brainrot* and the team that ships *99 Nights in the Forest* used very different aesthetic stacks.
- **Long-term tool stability.** Every tool above could change pricing, shut down, or be acquired in 6 months. Build with portable formats (FBX, OBJ, GLB) so you can swap tools without rebuilding assets.

---

## Useful links

- Roblox Cube 3D & Studio Assistant: `https://create.roblox.com/docs/studio/ai`
- Meshy: `https://www.meshy.ai`
- Sloyd: `https://www.sloyd.ai/use-case/roblox-developers`
- Cascadeur: `https://cascadeur.com`
- Mixamo: `https://www.mixamo.com`
- DeepMotion Animate 3D: `https://www.deepmotion.com/companion-tools/roblox`
- Rebirth AI: `https://userebirth.com`
- Forge AI: `https://forge.loopmobile.io`
- Blender (free, standard): `https://www.blender.org`
- BlenderGPT plugin: search current GitHub releases — exact URL has changed over time.

---

**End of asset pipeline doc.** Pick 1–2 tools per category, learn them, ship with them. Don't try to learn all of these.
