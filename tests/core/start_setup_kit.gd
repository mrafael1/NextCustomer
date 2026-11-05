extends RefCounted
## Shared helpers of the opening-time setup suites (start_setup_rules_test, start_setup_save_test):
## live data, the named derived streams the game uses, and runs set up and locked in as
## StartChoice does.

const RECIPE := "res://data/decks/pack_starter.tres"
const BALANCE := "res://data/balance/balance.tres"


static func balance() -> BalanceDefinition:
	return load(BALANCE)


static func recipe() -> DeckDefinition:
	return load(RECIPE)


## A profile with the first `completed` aisles complete, and every machine aisle after them
## listable once any aisle is complete (as the start board test's).
static func profile(completed: int) -> ProfileState:
	var made: ProfileState = ProfileState.new()
	var data: BalanceDefinition = balance()
	for index: int in data.aisles.size():
		var aisle: AisleDefinition = data.aisles[index]
		var count: int = 0
		if index < completed:
			count = aisle.capsule_cards.size()
		elif aisle.base_cards.is_empty() and completed > 0 and completed < 3:
			count = data.aisle_listable_min
		for card: CardDefinition in aisle.capsule_cards.slice(0, count):
			made.unlocked_items[card.id] = 0
	return made


static func suggest(shown: ProfileState, seed_value: int) -> Array[StringName]:
	return StartSetupRules.suggest_aisles(
		balance(),
		shown,
		EventLogService.derived_stream(seed_value, EventLogService.STOCK_AISLES_STREAM)
	)


static func run(shown: ProfileState, seed_value: int) -> RunState:
	return StartSetupRules.setup_run(
		seed_value,
		balance(),
		recipe(),
		shown,
		EventLogService.derived_stream(seed_value, EventLogService.STOCK_AISLES_STREAM)
	)


## A new run with its suggestion locked in (null if LOCK IN was refused).
static func locked(shown: ProfileState, seed_value: int) -> RunState:
	var made: RunState = run(shown, seed_value)
	return made if lock_suggestion(made, shown) == &"" else null


## LOCK IN the run's suggestion; returns lock_in's reason.
static func lock_suggestion(shown: RunState, owner: ProfileState) -> StringName:
	var green: Array[StringName] = shown.start_setup.green_ids(shown.balance)
	return StartSetupRules.lock_in(
		shown,
		owner,
		green,
		shown.start_setup.run_only_ids(shown.balance),
		deck_rng(shown),
		basket_streams(shown, green)
	)


static func deck_rng(shown: RunState) -> RandomNumberGenerator:
	return EventLogService.derived_stream(shown.run_seed, EventLogService.STARTING_DECK_STREAM)


static func basket_streams(
	shown: RunState, green: Array[StringName]
) -> Dictionary[StringName, RandomNumberGenerator]:
	var streams: Dictionary[StringName, RandomNumberGenerator] = {}
	for source: StringName in StartSetupRules.basket_sources(shown.balance, green):
		streams[source] = EventLogService.derived_stream(
			shown.run_seed, EventLogService.START_BASKET_STREAM % source
		)
	return streams


static func restock_rng(shown: RunState, basket: int) -> RandomNumberGenerator:
	var source: StringName = shown.start_setup.baskets[basket].source
	return EventLogService.derived_stream(
		shown.run_seed, EventLogService.START_RESTOCK_STREAM % source
	)


static func regulars_rng(shown: RunState, slot: int, aisle_id: StringName) -> RandomNumberGenerator:
	return EventLogService.derived_stream(
		shown.run_seed, EventLogService.START_REGULARS_STREAM % [slot, aisle_id]
	)


static func new_packs_rng(shown: RunState) -> RandomNumberGenerator:
	return EventLogService.derived_stream(shown.run_seed, EventLogService.START_NEW_PACKS_STREAM)


## Swaps regular `slot` to its first allowed option, as StartChoice does; false when none.
static func swap(shown: RunState, owner: ProfileState, slot: int) -> bool:
	var card: CardDefinition = option(shown, owner, slot)
	if card == null:
		return false
	shown.starter.core_cards[slot] = card
	StartSetupRules.refresh_deck(shown)
	return true


## The first card `slot` can be swapped to (from `aisle` only, when given), or null.
static func option(
	shown: RunState, owner: ProfileState, slot: int, aisle: AisleDefinition = null
) -> CardDefinition:
	for done: AisleDefinition in StartSetupRules.completed(shown.balance, owner):
		if aisle != null and done != aisle:
			continue
		for card: CardDefinition in done.base_cards + done.capsule_cards:
			if StartSetupRules.can_swap(shown, owner, slot, card):
				return card
	return null


static func chain_of(aisle: AisleDefinition) -> ItemUpgradeDefinition:
	for chain: ItemUpgradeDefinition in balance().machine.item_upgrades:
		if aisle.base_cards.has(chain.product) or aisle.capsule_cards.has(chain.product):
			return chain
	return null


static func of_source(card: CardDefinition, source: StringName) -> bool:
	if source == StartSetup.STAPLES:
		return balance().staples.has(card)
	var aisle: AisleDefinition = balance().aisle_of(card)
	return aisle != null and aisle.id == source


## Whether every item of `items` is in `others`.
static func all_in(items: Array, others: Array) -> bool:
	for item: Variant in items:
		if not others.has(item):
			return false
	return true


static func json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))
