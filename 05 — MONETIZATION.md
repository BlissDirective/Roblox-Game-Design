# 05 — MONETIZATION.md

> How money actually flows in Roblox in 2026. Game Passes, Developer Products, Creator Rewards, pricing strategy, and the math.

---

## TL;DR

Roblox monetization in 2026 has matured. **Pay-to-win is dead** — players punish it with bad reviews and the algorithm punishes the bad reviews. The winners use **fair, transparent monetization** that enhances the experience without breaking the free game. Three streams stack: **Game Passes** (one-time perks), **Developer Products** (consumables), and **Creator Rewards** (passive engagement-based payouts). Build all three.

The DevEx rate (Robux → USD) is **~$0.0038 per Robux** as of post-September 2025. After Roblox's platform cut, expect to net roughly **$0.27 per 100-Robux pass sold** as the developer.

---

## The three revenue streams

### 1. Creator Rewards (formerly Engagement-Based Payouts)

**What it is:** Roblox pays you a share of a global creator pool based on engagement signals from your game. This is **passive** — players don't directly pay you. The platform pays you out of the Robux they earn from Premium subscriptions and Robux purchases across the platform.

**The 2025 formula update (effective July 2025) rewards:**
- Daily active spenders in your experience
- New + returning user activation
- Session time among paying users
- Whether your game is in players' top 3 daily

**73% of developers earn more under this formula.** **171% more developers cross the minimum payout threshold.** The system is friendlier to mid-sized games than the old EBP formula.

**Practical implication:** Build for **paying-player engagement**, not raw player count. A game with 200 DAU that includes 20 spenders will out-earn a game with 1,000 DAU and zero spenders on Creator Rewards.

**Realistic ranges:**
- 50 DAU, ~45 min sessions → $200–500/mo
- 200 DAU, ~60 min sessions → $1,000–3,000/mo
- 1,000 DAU, ~75 min sessions → $5,000–15,000/mo
- 10,000+ DAU → $30,000+/mo (if monetization is healthy)

### 2. Game Passes

**What they are:** One-time purchases that unlock a permanent perk for that player on that game. Think "VIP forever."

**Pricing window:** Most successful Game Passes sit between **49 and 999 Robux**. The sweet spot for high-volume sales is **49–199 Robux** — low enough that an impulse-buyer says yes.

**The roles each pass plays:**

| Pass type | Typical price | Conversion role |
|---|---|---|
| Starter pack | 49–75 Robux | Cheap impulse for new players. Includes a small currency boost + cosmetic. |
| 2x cash / multiplier | 99–199 Robux | The classic. Players who like the game grind less. |
| VIP | 199–399 Robux | Status + small permanent boost + visible badge. |
| Auto-collect / quality-of-life | 199–399 Robux | Convenience. Loved by working adults / engaged players. |
| Premium / ultimate | 499–999 Robux | Whale tier. Stacked perks. |
| Ultra-premium / exclusive area | 999–1,999 Robux | Sells less often but high revenue per sale. |

**Don't make it pay-to-win.** Multipliers are fine because they accelerate progress, not change the win condition. Selling "infinite weapons" or "auto-win buttons" tanks ratings and triggers Roblox moderation.

**Tiered passes drive more revenue than single passes.** A player who buys the 99-Robux Starter Pack is 30–50% more likely to buy the 199-Robux VIP than a cold prospect. Build a ladder.

### 3. Developer Products (consumables)

**What they are:** Things players can buy multiple times. Currency packs, temporary boosts, single-use items, gacha pulls, etc.

**Why they matter:** Game Passes are one-and-done. Developer Products generate **recurring revenue** from engaged players — the whales of the simulator/tycoon world.

**Common types:**

| Product | Typical price | Notes |
|---|---|---|
| Currency pack (small) | 49–99 Robux | 1,000 in-game coins |
| Currency pack (medium) | 199 Robux | 5,500 coins (10% bonus) |
| Currency pack (large) | 499 Robux | 15,000 coins (20% bonus) |
| Temporary boost (2x for 30 min) | 25–49 Robux | Highest-converting. Sense of urgency. |
| Skip / refresh | 49 Robux | "Skip 1 hour cooldown" |
| Loot crate | 99–199 Robux | Randomized rewards. **Be careful with gambling regulation.** |

**On loot crates:** They are extremely lucrative but increasingly regulated globally. Roblox itself has been pressured on this. If you build them: clearly publish odds, never disguise them as something else, and keep them age-appropriate.

### 4. Paid Access (since Sept 2024)

**What it is:** Charge a one-time entry fee to play the game at all. Up to 70% revenue share to the developer (vs. ~70% Robux platform fee on other transactions). The math is much better when it works.

**When it works:** Premium-feel niche games where the cost filters for serious players. Horror games, deep RPGs, narrative experiences.

**When it doesn't work:** Mass-market games. Games that need word-of-mouth to grow. Anything kid-targeted.

**Typical price:** 100–500 Robux (~$1.25–$6.25 USD).

### 5. Premium Payouts

Roblox Premium subscribers (paying ~$4.99/mo) generate a separate payout pool based on time spent in your experience. Per-player it's small. Across thousands of premium DAUs it adds up. Free money — make sure your game is enabled for it (default-on, but verify in Creator Hub).

---

## The math (memorize this)

### Per-transaction breakdown

When a player buys a 100-Robux Game Pass:

```
100 Robux (player paid)
  - 30 Robux (Roblox platform fee)
  = 70 Robux (creator share)
  × $0.0038 (DevEx rate post-Sept 2025)
  = ~$0.27 USD (net to developer)
```

Same math for a 199-Robux pass: ~$0.53 USD net.
Same math for a 499-Robux pass: ~$1.33 USD net.
Same math for a 999-Robux pass: ~$2.66 USD net.

### Revenue projection example

A modest tycoon hits 1,000 DAU. Realistic monetization spread:

| Stream | Daily metric | Monthly revenue |
|---|---|---|
| Creator Rewards | 1,000 DAU × ~75 min avg | ~$7,000 |
| Starter Pack (75 R$, 5% conversion) | 50 sales/day | ~$300 |
| 2x Cash (149 R$, 3% conversion) | 30 sales/day | ~$360 |
| VIP (299 R$, 1% conversion) | 10 sales/day | ~$240 |
| Currency packs (avg 99 R$) | 100 sales/day | ~$800 |
| Temporary boosts (avg 49 R$) | 200 sales/day | ~$760 |
| **Total estimate** | | **~$9,460/mo** |

That's a real number from realistic assumptions. The thing that drives it: **clean monetization that respects the player and a tight loop that brings them back daily.**

### Conversion rate benchmarks

| Metric | Bad | Average | Good | Great |
|---|---|---|---|---|
| % of DAU buying ANY pass/product | <1% | 2–4% | 5–8% | 10%+ |
| % of buyers buying again | <30% | 50% | 70% | 85%+ |

The single best predictor of monetization health is "% of first-time buyers who become repeat buyers." If repeat-purchase rate is below 50%, your monetization is broken (likely pay-to-win or value-thin).

---

## Pricing strategy: how to actually decide

### Step 1: Look at what your competitors charge

Take the top 10 games in your genre. Note every Game Pass, its price, and player reviews about value. **The median price for similar passes in your genre is your starting anchor.** If everyone charges 99–149 Robux for a 2x multiplier, pricing yours at 499 Robux feels insane — regardless of how good your game is.

### Step 2: Anchor with low-tier, lift with mid-tier

The Starter Pack at 49–75 Robux is your conversion engine. It teaches the player that buying things in this game is a normal thing to do. Once they buy once, they're 5–10x more likely to buy again.

### Step 3: Test prices on different servers

For mature games (post-launch), Roblox lets you do server-side price A/B testing. Run different prices on different shards. Track conversion + total revenue. Run until you have **at least 100 purchases per price point** for statistically meaningful results.

### Step 4: Don't change prices casually

Every price change creates confusion. Players talk. Discord servers complain. Change prices when the data says you must — not on a whim.

---

## Genre-specific monetization patterns

### Tycoon / Simulator / Idle

- **Multiplier passes** — 2x cash, 2x XP. The bread and butter.
- **Auto-collect** — passive collection while AFK. Loved by adults.
- **VIP** — small permanent boost + visible badge.
- **Pets / collectibles** — randomized loot crates with rarity tiers.
- **Currency packs** — for the impatient.
- **Temporary boosts** — 2x for 30 min. Highest conversion product type.

### RPG / Adventure

- **Cosmetic gear** — outfits, weapon skins, character recolors.
- **Inventory expansion** — bag size, bank slots.
- **Fast travel** — convenience.
- **Exclusive quests / dungeons** — limited content. Higher price.
- **Battle pass** — seasonal, recurring revenue.

### Social / Roleplay

- **Cosmetics dominate** — clothing, accessories, emotes.
- **Housing items** — furniture, decorations.
- **Custom chat effects, name colors, status icons.**
- **Premium chat features** — voice tags, reaction emojis.

### Horror / Survival

- **Cosmetic flashlights, character skins, gear.**
- **VIP servers** — play with friends only.
- **New chapter early access.**
- **Soundtracks / lore items.**

### Obby / Single-session

- **Stage skips** (carefully — don't trivialize).
- **Cosmetic trails, gear effects.**
- **VIP** — small QoL bonus.
- **Limited revenue ceiling** — the genre doesn't support deep monetization.

### Shooter / FPS

- **Cosmetics + battle pass.** That's it. Anything else is pay-to-win.

---

## Anti-patterns that will tank your game

These are dealbreakers. The 2026 Roblox player base is sophisticated and vocal.

- **Selling power that breaks balance.** "Infinite damage" sword for 999 Robux = game dies in a week.
- **Walling progression behind paywalls.** "Reach Level 30 or pay 500 Robux" = uninstall.
- **Aggressive popups in the first 60 seconds.** Tank D1 retention.
- **Misleading product descriptions.** Roblox moderation will pull these and your reputation never recovers.
- **Stacking purchases that become required.** "Buy 2x cash AND auto-collect AND VIP just to keep up" = the free game is broken.
- **Lootbox mechanics targeting under-13s without disclosure.** Both regulatory and reputational hazard.
- **Currency that you can only meaningfully earn by buying.** Defeats the free game.

The general principle: **the free game must be fun and complete. Purchases enhance, not enable.**

---

## The starter monetization stack (recommended for V1)

For your first launch, ship with this baseline:

1. **Starter Pack — 49–75 Robux**
   - Small currency boost (e.g., 1,000 starting coins instead of 100)
   - Visible cosmetic (badge, trail, name color)
   - Time-limited offer (visible only for first 24h to push conversion)

2. **2x Multiplier — 99–149 Robux**
   - The core monetization. Everything else stacks on this.
   - "2x cash forever" or "2x XP forever"

3. **VIP — 249–349 Robux**
   - Stacks with 2x (so 3x total when both owned)
   - Visible chat tag
   - Access to a VIP-only area in the map (cosmetic, not power)
   - Permanent +20% income on top

4. **One Developer Product: 30-min 5x Boost — 49 Robux**
   - The high-conversion impulse buy
   - "I want to grind right now, give me the boost"

5. **One Currency Pack: 1,000 coins — 99 Robux**
   - For impatient players

That's the V1 stack. Five products. Ship it, watch the data, iterate.

**Do NOT ship V1 with:**
- Loot crates (regulatory complexity, save for V2)
- A battle pass (requires content cadence you don't have yet)
- Multiple tiers of currency (confusing, save for later)
- Real-money entry fee (cuts traffic)

---

## Promotion and acquisition

You don't really run paid ads as a solo dev — the cost-per-acquisition rarely pencils out for a new game. The free traffic engine is:

- **TikTok / YouTube Shorts.** Showing the build process. Showing clippable moments. Reacting to gameplay.
- **Discord community.** Build a server early. Even 100 members is leverage. They become your QA, your hype squad, your distribution.
- **Cross-collaboration with other Roblox creators.** Once you're at ~5k DAU, partner with another mid-sized game on a coordinated event.
- **Influencer drops.** Once you're at ~10k DAU, send free perks to small-mid Roblox YouTubers. Their playthrough videos drive traffic.
- **Game-specific TikTok creators.** People literally make content about specific Roblox games. Find them, befriend them.

Roblox itself runs **Sponsored Games** ads (paid placement). Don't run these until your D1 retention is above 25% and your monetization is converting at >3%. Otherwise you're paying to acquire players who don't stick.

---

## When to think about LiveOps (not yet, but eventually)

Once your game is established (~5k+ DAU, retention is healthy), the real money comes from **LiveOps** — running your game like a service:

- Weekly content drops
- Limited-time events (weekly, monthly, seasonal)
- Crossover events with other games or trending culture
- Community challenges
- Battle passes / seasons
- Coordinated viral moments

Top games hire LiveOps teams. *Grow a Garden* was scaled by Splitting Point and Do Big Studios applying LiveOps discipline. As a solo dev with AI, you can run lighter LiveOps: one event per month, weekly small drops, monthly big drops.

This is what eventually pushes the established $5K/mo game to $50K/mo.

---

## The single most important monetization principle

Build a game where **a player who never spends a single Robux still has a good time.**

This sounds counterintuitive — "wait, isn't the goal money?" — but it's the difference between a game that makes $500/mo and a game that makes $5,000/mo. The free experience is what creates word-of-mouth, which creates volume, which creates Creator Rewards, which is where most of your revenue actually comes from.

The paying players are not your audience — they are the smaller set within your audience who are choosing to enhance their already-good experience.

If your free game is bad and you rely on conversion to make it tolerable, you don't have a game. You have a paywall.

---

**Next: `06_LUAU_REFERENCE.md` — the actual code patterns Claude will write.**
