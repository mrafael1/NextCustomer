extends RefCounted
## Shared helpers of the opening-time setup suites (start_setup_rules_test, start_setup_save_test,
## start_setup_swap_test, start_store_test): live data, the named derived streams the game uses,
## and runs set up and dealt as StartChoice does (v1.32: sealed aisle boosters).

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


## A new run in SELECT (nothing dealt).
static func run(shown: ProfileState, seed_value: int) -> RunState:
	return StartSetupRules.setup_run(
		seed_value,
		balance(),
		recipe(),
		shown,
		EventLogService.derived_stream(seed_value, EventLogService.STOCK_AISLES_STREAM)
	)


## A new run dealt as StartChoice deals it, its boosters sealed (null if the deal was refused).
static func dealt(shown: ProfileState, seed_value: int) -> RunState:
	var made: RunState = run(shown, seed_value)
	return made if deal(made, shown) == &"" else null


## A new run dealt, PICK 2 OF 3 (if any) keeping the seeded pair, and every booster opened, so
## swaps and RESTOCK are open (null if the deal was refused).
static func locked(shown: ProfileState, seed_value: int) -> RunState:
	var made: RunState = dealt(shown, seed_value)
	if made == null:
		return null
	if made.start_setup.picking():
		var pair: Array[int] = [0, 1]
		StartSetupRules.pick_boosters(made, shown, pair, pick_rng(made))
	open_all(made)
	return made


## Opens every booster that can be opened.
static func open_all(shown: RunState) -> void:
	for index: int in shown.start_setup.boosters.size():
		StartSetupRules.open_booster(shown, index)


## Deals the run's setup on the game's streams; returns deal's reason.
static func deal(shown: RunState, owner: ProfileState) -> StringName:
	return StartSetupRules.deal(
		shown, owner, deck_rng(shown), booster_streams(shown), extra_rng(shown)
	)


static func deck_rng(shown: RunState) -> RandomNumberGenerator:
	return EventLogService.derived_stream(shown.run_seed, EventLogService.STARTING_DECK_STREAM)


## One booster stream per aisle of the data, as StartChoice.deal passes them.
static func booster_streams(shown: RunState) -> Dictionary[StringName, RandomNumberGenerator]:
	var streams: Dictionary[StringName, RandomNumberGenerator] = {}
	for aisle: AisleDefinition in shown.balance.aisles:
		streams[aisle.id] = EventLogService.derived_stream(
			shown.run_seed, EventLogService.START_BOOSTER_STREAM % aisle.id
		)
	return streams


static func extra_rng(shown: RunState) -> RandomNumberGenerator:
	return EventLogService.derived_stream(
		shown.run_seed, EventLogService.START_BOOSTER_EXTRA_STREAM
	)


static func pick_rng(shown: RunState) -> RandomNumberGenerator:
	return EventLogService.derived_stream(shown.run_seed, EventLogService.START_BOOSTER_PICK_STREAM)


static func restock_rng(shown: RunState, index: int) -> RandomNumberGenerator:
	var aisle: StringName = shown.start_setup.boosters[index].aisle
	return EventLogService.derived_stream(
		shown.run_seed, EventLogService.START_RESTOCK_STREAM % aisle
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


## Whether `card` (any tier) is a product of aisle `aisle_id`.
static func of_aisle(card: CardDefinition, aisle_id: StringName) -> bool:
	var aisle: AisleDefinition = balance().aisle_of(card)
	return aisle != null and aisle.id == aisle_id


## Whether every item of `items` is in `others`.
static func all_in(items: Array, others: Array) -> bool:
	for item: Variant in items:
		if not others.has(item):
			return false
	return true


static func json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))
