# 02 — ROBLOX_PLATFORM.md

> Everything you need to know about the platform you're building on. Stats are as of Q1 2026 unless noted.

---

## TL;DR

Roblox is the largest user-generated gaming platform in the world. **380+ million monthly active users, 144 million daily active users, $4.88 billion in 2025 revenue.** It paid creators **$1.5 billion in 2025.** It is officially betting on AI-assisted development to enable solo creators to compete with studios. The platform's discovery algorithm in 2026 rewards short-session return rate over raw concurrent users.

If you build a game with a tight loop, a daily return reason, and a clip-worthy moment — and you ship in 2026 with AI as your dev partner — the door is genuinely open.

---

## Platform scale (Q1 2026)

| Metric | Value | Notes |
|---|---|---|
| Monthly Active Users (MAU) | 380M – 381.8M | Up from 200M in 2022 |
| Daily Active Users (DAU) | ~144M | +69% YoY in Q4 2025 |
| All-time peak concurrent platform users | 47.4M | Aug 23, 2025, during Steal a Brainrot × Grow a Garden event |
| Total experiences on the platform | 44M+ | ~7M "active" |
| Hours played in 2024 | 73.5B | And growing |
| Q4 2025 revenue | $1.4B | +43% YoY |
| Full-year 2025 revenue | $4.88B | |
| Creator payouts 2025 | $1.5B | First time crossing $1B in a single year |
| Top 10 creators avg earnings 2025 | $38.5M | Outliers, not the median |
| Top 1,000 creators avg earnings 2025 | $1.3M | Still outliers |
| Median paid creator | Mid-4-figures/year | The realistic baseline for a working solo creator |
| Roblox market cap | ~$48B | |

---

## Audience demographics

This is **the** most misunderstood thing about Roblox. The "kids' platform" image is outdated.

### Age breakdown (2024 data, latest available)

| Age | Share |
|---|---|
| Under 13 | ~40% |
| 13–16 | ~16% |
| 17–24 | ~25% |
| 25+ | ~19% |

**~28% of players are 17+, and the 18–34 cohort is growing at >50% YoY** — double the rate of younger users. Roblox's official strategy in 2026 is to court this older audience aggressively (see "Incubator/Jumpstart" below).

### Gender

Roughly **52% male, 39% female, 9% unspecified** — meaningfully more balanced than most gaming platforms.

### Geography

| Region | Share of DAU |
|---|---|
| US & Canada | ~17% |
| Asia-Pacific & rest of world | ~60% |
| Europe | ~22% |

**Latin America is enormous and underserved by English-only games.** *Steal a Brainrot* outperforms *Grow a Garden* in Latin America. Spanish/Portuguese localization is a real lever.

### Device split

| Platform | Share |
|---|---|
| Mobile (phone/tablet) | ~80% |
| Desktop | ~17% |
| Console (Xbox, PS, etc.) | ~3% |

**Build for mobile first.** A game that runs at 60fps on a $200 Android phone with one-thumb controls is a game that can succeed. A game that requires keyboard + mouse will die on the discovery algorithm.

---

## DAU/MAU "stickiness" ratio

Roblox's platform-wide DAU/MAU is **~21% (Q4 2025)**. Translation: about 1 in 5 monthly users plays daily. This is **extremely high** for any digital platform — comparable to top social apps.

For your individual game, a healthy DAU/MAU ratio is:
- **15%** = okay
- **25%** = strong
- **40%+** = your game has serious habit-formation hooks (typical of top simulators)

---

## The 2026 algorithm shift (this is critical)

**Roblox's discovery algorithm in 2026 has shifted its primary weight from concurrent users (CCU) to short-session return rate.** The signal Roblox cares most about is: *did the player come back to your game within 24 hours for a second, shorter session?* A 45-minute session followed by no return scores worse than two 12-minute sessions in the same day.

What this means concretely:

1. **Short core loops win.** A loop that takes 30 minutes to feel rewarding will not perform on the algorithm. Aim for **<10 minutes from "I logged in" to "I felt a reward."**
2. **Daily-return mechanics are not optional.** Login bonuses, daily quests, energy regen, restocking shops, limited-time events — pick at least two.
3. **CCU still matters for events.** Coordinated launches, partner events, and viral moments still move CCU and that still drives the trending charts. But you cannot CCU your way to sustained discovery anymore.

There is also a third signal Roblox publicly highlighted in 2026: **Intentional Co-Play Days** — when a player joins your game *because a friend invited them*. This is heavily weighted. Make the in-game friend invite flow obvious and frictionless.

The four signals Roblox explicitly weights in 2026:
- Daily active spenders in your experience
- New + returning user activation
- Session time among paying users
- Whether your game is in a player's top 3 daily

Source: Roblox Creator Rewards docs (the formula that replaced Engagement-Based Payouts in July 2025).

---

## Revenue economy: how money flows

### The pipeline

```
Player buys Robux (USD → Robux)
        ↓
Player spends Robux in your game (Game Pass, Dev Product, Paid Access)
        ↓
Roblox takes a platform fee (~30–70% depending on transaction type)
        ↓
You earn Robux (creator share)
        ↓
You convert via DevEx (Robux → USD)
        ↓
DevEx rate (post Sept 2025 increase): ~$0.0038 per Robux earned
```

### What that math looks like

- A player buys a 100-Robux Game Pass.
- After Roblox's fee, you get ~70 Robux.
- 70 Robux × $0.0038 = ~**$0.27 per sale** as the developer.
- 1,000 sales = ~$270.
- 10,000 sales = ~$2,700.

This is why volume matters: tycoons and simulators win because their progression naturally creates many small purchases per player rather than one big one.

### Three revenue streams

1. **Creator Rewards** (formerly Engagement-Based Payouts) — passive payment based on player engagement signals. Realistic ranges:
   - 50 DAU, ~45 min sessions → $200–500/mo
   - 200 DAU, ~60 min → $1,000–3,000/mo
   - 1,000 DAU, ~75 min → $5,000–15,000/mo
2. **Game Passes & Developer Products** — direct purchases. Detailed in `05_MONETIZATION.md`.
3. **Paid Access (since Sept 2024)** — charge a one-time entry fee. Up to 70% revenue share. Best for premium-feel niche games; bad for mass-market.

### Premium Payouts (subscription split)

Roblox Premium subscribers generate a separate payout pool based on time spent in your experience. It's small per user but stacks with everything else.

---

## What Roblox itself is investing in (2026)

The platform's roadmap signals where the floor and ceiling are. Pay attention to these:

### Built-in MCP server

Since **February 2026**, Roblox Studio ships with a built-in MCP (Model Context Protocol) server. Open `Studio Settings → Beta Features → enable MCP Server`. It listens on `localhost:3004`. This is what lets Claude Code, Cursor, Codex, etc. talk directly to Studio — write scripts, create instances, run playtests, read console output. This is the spine of the AI-development workflow. (Full setup in `08_MCP_SETUP.md`.)

### Luau Assist (in-Studio AI)

Roblox's built-in AI assistant trained specifically on Luau and the Roblox API. Over **50% of new Studio sessions involve at least one AI interaction**, and **70% of Luau Assist generations come from accounts under 2 years old** — the platform is designing the tooling for new and AI-leveraged creators.

Use it for: quick API lookups, autocomplete, leaderstats boilerplate, RemoteEvent wiring patterns.
Use Claude Code for: architecture, full systems, debugging across files, complex business logic.

They are complementary, not redundant.

### Incubator and Jumpstart programs (March 2026)

Roblox launched two funded programs to support "novel games" — experiences that push beyond traditional Roblox formula. They explicitly named **RPGs, strategy games, and shooters** as underrepresented genres with high player demand. The 18–34 audience growing 50%+ YoY is the target.

If your concept fits a novel genre and is not the 4,000th tycoon, this is worth investigating once you have a prototype. Apply through Creator Hub.

### Higher-fidelity tooling

- **SLIM** (Scalable Lightweight Interactive Models) — detailed environments that scale across devices
- **Texture Streaming** — higher-res textures without front-loading memory
- **Spatial Voice** — voice chat in-experience. By end of 2026, expected to be baseline for top social/RPG games. Top social games with voice chat keep players longer.

---

## Top games as of Q1 2026 (what you're competing with)

Long-tenure giants:

| Game | All-time visits | Genre | Key insight |
|---|---|---|---|
| Brookhaven RP | ~78B | Town/city/social | Free-form social hangout. Bought by Voldex 2025. |
| Blox Fruits | ~58B | Anime RPG | Deep progression. Owns the anime RPG niche. |
| Steal a Brainrot | ~57B | Tycoon/social | First game to surpass 25M CCU. Built in 4 months. |
| Adopt Me! | ~50B+ | Pet/social | Trading economy. Long-tenured top earner. |
| Grow a Garden | New (Mar 2025) | Idle/farming | Built by 16-year-old in days. 22.3M peak CCU. Idle progression while offline. |

Recent breakouts (2026):

| Game | Lane | Why it broke |
|---|---|---|
| 99 Nights in the Forest | Horror survival | Built tension over 99-night arc. Atmospheric, not jump-scare. ~442K CCU. |
| Escape Tsunami for Brainrots! | Brainrot meme/disaster | Rode the brainrot moment. |
| RIVALS | Competitive FPS | Targeted the underserved competitive FPS audience. |
| Fisch | Fishing × RPG × hangout | Genre-blender. ~1.5B visits. |

The lesson: **the chart in 2026 looks very different from the chart in 2025.** Old games hold their long-tenure spots, but new lanes (horror, FPS, genre-blends) are punching through.

---

## What does NOT work in 2026

- **Pay-to-win.** Players punish it with negative reviews and bounce. Roblox actively discourages it in monetization docs.
- **Long onboarding.** Players who don't see fun in the first 30 seconds leave forever. Your D1 retention dies in those 30 seconds.
- **Reskinned tycoons.** The "X but with Y theme" tycoon market is saturated. The top 1–2 in each sub-niche take 80%+ of revenue.
- **Forced ads / aggressive popups.** Players close them and leave.
- **Desktop-only design.** 80% of your audience is on mobile. Period.
- **No clippable moment.** If TikTokers can't make 15-second hype clips of your game, organic discovery is much harder.

---

## What DOES work in 2026

- **Sub-10-minute core loops** with visible progress
- **Daily return mechanics** (login bonus, restocking shop, daily quest, energy)
- **Social hooks** (visible friend leaderboards, co-op or PvP interaction, trading)
- **Live events** (limited-time, FOMO-driven, exclusive rewards)
- **Genre-blending** (simulator + RPG, social + survival, etc.)
- **Visible spectacle** (a moment that's naturally clip-worthy)
- **Mobile-first controls** (one-thumb playable on a phone)
- **Latin American friendliness** (or full multi-language localization)
- **Voice chat** for social genres
- **Cosmetic-first monetization** with optional convenience purchases

---

## Useful links

- Roblox Creator Hub: `https://create.roblox.com`
- Charts (top playing now): `https://www.roblox.com/charts/top-playing-now`
- Creator docs: `https://create.roblox.com/docs`
- Creator Rewards docs: `https://create.roblox.com/docs/production/monetization/engagement-based-payouts`
- Studio MCP docs: `https://create.roblox.com/docs/studio/mcp`
- Developer Forum: `https://devforum.roblox.com`

---

**Next: `03_GAME_GENRES.md` — picking the right lane.**
