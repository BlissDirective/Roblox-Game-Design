--!strict
--[[
	Outpost-7 — quest objective event bus.

	Phase C3. Singleton pub-sub used by services that produce quest-
	relevant events (PlacementService, ShopService, DailyLoginManager,
	CurrencyService). DailyQuestManager subscribes once and dispatches
	progress to active quests whose objective.event matches.

	The decoupling is deliberate: services that emit don't need to
	require DailyQuestManager (avoids cycles), and DailyQuestManager
	doesn't need to know which services emit (each can be added or
	removed without touching the manager).

	Event shape: `(event: string, player: Player, amount: number)`.
	`amount` is the additive progress delta — usually 1 for count
	objectives, the actual sum for value objectives (e.g.
	`spend_credits` emits with amount = credits spent on that
	transaction).

	V1 events:
	  place_extractor   — count
	  place_wall        — count
	  place_any         — count (emitted alongside specific events)
	  spend_credits     — sum of credits spent
	  earn_credits      — sum of credits gained from any source
	  buy_shop_item     — count
	  claim_daily       — count (always 1)
	  play_session      — sum of session minutes (1 per minute tick)

	Phase E adds: survive_wave, raid_won, raid_attended.
--]]

local QuestObjectives = {}

export type QuestEventHandler = (event: string, player: Player, amount: number) -> ()

local handlers: { QuestEventHandler } = {}

function QuestObjectives.Emit(event: string, player: Player, amount: number)
	if amount <= 0 then
		return
	end
	for _, handler in handlers do
		task.spawn(handler, event, player, amount)
	end
end

function QuestObjectives.OnEmit(handler: QuestEventHandler)
	table.insert(handlers, handler)
end

return QuestObjectives
