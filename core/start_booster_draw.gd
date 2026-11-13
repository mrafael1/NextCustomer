class_name StartBoosterDraw
extends RefCounted
## Draws the opening-time aisle boosters (start screen YOUR STORE, full build plan 7.2, v1.32) for
## StartSetupRules: which products an aisle's booster deals from (pool) and one booster drawn on
## a caller-owned named stream (draw). Pure and static; the copy counts are the caller's.


## The products aisle `aisle_id`'s booster deals from: its items for the profile (RunStock.items:
## base cards and unlocked capsules) that have an item-tier chain in the run recipe's chains
## (StartingDeck.chains_for: capsules only with random_capsules), data order. Built from the aisle
## itself, not the run's stock, so PICK 2 OF 3's extra aisle (not stocked yet) deals the same way.
static func pool(
	run: RunState, profile: ProfileState, aisle_id: StringName
) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	var chains: Array[ItemUpgradeDefinition] = StartingDeck.chains_for(run.starter, run.balance)
	for aisle: AisleDefinition in run.balance.aisles:
		if aisle.id != aisle_id:
			continue
		for card: CardDefinition in RunStock.items(aisle, profile.unlocked_items):
			if (
				card.is_product()
				and chains.any(
					func(chain: ItemUpgradeDefinition) -> bool: return chain.product == card
				)
			):
				found.append(card)
	return found


## One booster of aisle `aisle_id` drawn on `rng` from `options` (plain products): place by place,
## start_booster_size places, the last start_booster_hit_slots of them hit places. A hit place
## first rolls its rarity (one randi_range(1, 100): RARE at or below
## start_booster_hit_rare_percent; commons don't roll); then the product is drawn weighted by its
## CardDefinition.draw_weight (one randi_range over the total weight; 0 never) among the options
## still below the recipe's copy_max in `copies` (updated by the caller) and not in the booster
## yet; a RARE place draws among those whose chain has a BIG tier and takes that tier (never
## GOLDEN), or, with none, a plain card. The booster comes up short when no option is left.
static func draw(
	balance: BalanceDefinition,
	recipe: DeckDefinition,
	aisle_id: StringName,
	options: Array[CardDefinition],
	copies: Dictionary[CardDefinition, int],
	rng: RandomNumberGenerator
) -> StartBooster:
	var booster: StartBooster = StartBooster.new(aisle_id)
	var size: int = maxi(balance.start_booster_size, 0)
	var hit_from: int = size - clampi(balance.start_booster_hit_slots, 0, size)
	var table: Array[ItemUpgradeDefinition] = []
	if balance.machine != null:
		table = balance.machine.item_upgrades
	var taken: Array[CardDefinition] = []
	for place: int in size:
		var hit: bool = place >= hit_from
		var rare: bool = hit and rng.randi_range(1, 100) <= balance.start_booster_hit_rare_percent
		var open: Array[CardDefinition] = []
		for card: CardDefinition in options:
			var product: CardDefinition = card.product_card()
			if taken.has(product) or int(copies.get(product, 0)) >= recipe.copy_max:
				continue
			if card.draw_weight > 0 and not open.has(card):
				open.append(card)
		if rare:
			var bigs: Array[CardDefinition] = []
			for card: CardDefinition in open:
				if big_of(table, card) != null:
					bigs.append(card)
			if bigs.is_empty():
				rare = false
			else:
				open = bigs
		if open.is_empty():
			break
		var pick: CardDefinition = _weighted(open, rng)
		taken.append(pick.product_card())
		booster.cards.append(big_of(table, pick) if rare else pick)
		if hit:
			booster.hits += 1
	return booster


## `card`'s BIG tier in `table`'s chains, or null.
static func big_of(table: Array[ItemUpgradeDefinition], card: CardDefinition) -> CardDefinition:
	var big: CardDefinition = ItemUpgrades.tier_step(table, card, 1)
	return big if big != null and big.tier == CardDefinition.Tier.BIG else null


## One of `cards` drawn on `rng` by draw_weight (one randi_range over the total weight).
static func _weighted(cards: Array[CardDefinition], rng: RandomNumberGenerator) -> CardDefinition:
	var total: int = 0
	for card: CardDefinition in cards:
		total += card.draw_weight
	var roll: int = rng.randi_range(1, total)
	for card: CardDefinition in cards:
		roll -= card.draw_weight
		if roll <= 0:
			return card
	return cards[cards.size() - 1]


## Adds `cards` to the copy counts `copies` (by product: a BIG tier counts as its product).
static func count(copies: Dictionary[CardDefinition, int], cards: Array[CardDefinition]) -> void:
	for card: CardDefinition in cards:
		copies[card.product_card()] = int(copies.get(card.product_card(), 0)) + 1
