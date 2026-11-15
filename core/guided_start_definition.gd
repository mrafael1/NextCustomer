class_name GuidedStartDefinition
extends Resource
## The guided first run's scripted deal (the tutorial, data/tutorial/guided_start.tres): the
## recipe (its regulars and its fixed starter packs, a DeckDefinition in data/decks so a resume
## finds it by id), the fixed aisle boosters (StartSetupRules.deal_fixed deals them in place of
## the seeded ones) and shift 1's hand of hand_size cards in place order (place 0 first: basket 1's
## left card), whichever pack the player takes. Every hand card is in the cart: a regular or a
## booster card. Definitions are shared by reference and never changed at runtime.

@export var recipe: DeckDefinition
@export var boosters: Array[GuidedBoosterSpec] = []
@export var hand: Array[CardDefinition] = []


## The fixed boosters' aisle ids, in the definition's order (a booster without an aisle is
## skipped).
func aisle_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for spec: GuidedBoosterSpec in boosters:
		if spec != null and spec.aisle != null:
			ids.append(spec.aisle.id)
	return ids


## The cards of the fixed booster of aisle `aisle_id` (empty for none).
func booster_cards(aisle_id: StringName) -> Array[CardDefinition]:
	for spec: GuidedBoosterSpec in boosters:
		if spec != null and spec.aisle != null and spec.aisle.id == aisle_id:
			return spec.cards.duplicate()
	return []


## Why `balance` can't deal this definition, or &"" when it can (StartSetupRules.deal_fixed):
## &"recipe" (no recipe with core cards and starter packs), &"boosters" (not dealt_aisle_count
## boosters, each on its own aisle of the balance), &"cards" (a booster past start_booster_size,
## or a card that isn't a plain product of its booster's aisle, or a product twice in one
## booster) or &"hand" (not hand_size cards, or a hand card with fewer copies in the regulars and
## the boosters than the hand holds). A deal it allows passes StartSetup's load check.
func block(balance: BalanceDefinition) -> StringName:
	if recipe == null or recipe.core_cards.is_empty() or recipe.starter_packs.is_empty():
		return &"recipe"
	var aisles: Array[StringName] = aisle_ids()
	if aisles.size() != boosters.size() or aisles.size() != balance.dealt_aisle_count:
		return &"boosters"
	var cart: Array[CardDefinition] = recipe.core_cards.duplicate()
	for spec: GuidedBoosterSpec in boosters:
		var reason: StringName = _booster_block(balance, spec, aisles)
		if reason != &"":
			return reason
		cart.append_array(spec.cards)
	var fits: bool = hand.size() == balance.hand_size
	for card: CardDefinition in hand:
		fits = fits and card != null and hand.count(card) <= cart.count(card)
	return &"" if fits else &"hand"


## Why booster `spec` can't be dealt (block): &"boosters" or &"cards", or &"".
static func _booster_block(
	balance: BalanceDefinition, spec: GuidedBoosterSpec, aisles: Array[StringName]
) -> StringName:
	if aisles.count(spec.aisle.id) != 1 or not balance.aisles.has(spec.aisle):
		return &"boosters"
	if spec.cards.is_empty() or spec.cards.size() > balance.start_booster_size:
		return &"cards"
	var products: Array[CardDefinition] = []
	for card: CardDefinition in spec.cards:
		if (
			card == null
			or not card.is_product()
			or card.tier != CardDefinition.Tier.PLAIN
			or balance.aisle_of(card) != spec.aisle
			or products.has(card.product_card())
		):
			return &"cards"
		products.append(card.product_card())
	return &""


## The instance ids of `cards` (a dealt deck's cards, in deck order) that make the hand, in
## place order: for each hand card the first copy in `cards` not taken yet. Empty when a hand
## card has no copy left, so the shift deals its usual hand.
func hand_ids(cards: Array[CardInstance]) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	var taken: Array[CardInstance] = []
	for wanted: CardDefinition in hand:
		var found: CardInstance = null
		for card: CardInstance in cards:
			if card.definition == wanted and not taken.has(card):
				found = card
				break
		if found == null:
			return PackedInt32Array()
		taken.append(found)
		ids.append(found.instance_id)
	return ids
