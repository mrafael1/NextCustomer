class_name SimBuilds
extends RefCounted
## Builds for the balance simulator (plan section 8), decided with the user (#40): the build
## files of data/builds (BuildDefinition, plan section 3.8), measured from a deck's cards.
##
## A run's **main build** is the build its final deck fits most strongly: the highest measure
## divided by min_count among the builds it fits (ties go to the earlier build), or NO_BUILD.
## Every run has exactly one, so the shares of won runs add up to 100% (the 40% bar).
##
## A build's **key cards** are the cards that count towards its measure on their own
## (BuildDefinition.count of the card alone): the cards printing a tag build's tag, the coupons
## for Coupon specialist, and any product for the copy and tag-variety builds.

const NO_BUILD := "no build"

var builds: Array[BuildDefinition] = []


func _init(build_list: Array[BuildDefinition]) -> void:
	builds = build_list.duplicate()


## Every build file in `folder`, in file name order. In an exported pack (the simulator's
## release runner) a folder lists its text resources as "<name>.tres.remap".
static func load_folder(folder: String) -> Array[BuildDefinition]:
	var found: Array[BuildDefinition] = []
	var files: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(folder):
		files.append(file.trim_suffix(".remap"))
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			var build: BuildDefinition = load(folder.path_join(file)) as BuildDefinition
			if build != null:
				found.append(build)
	return found


func ids() -> Array[String]:
	var result: Array[String] = []
	for build: BuildDefinition in builds:
		result.append(String(build.id))
	return result


func find(id: String) -> BuildDefinition:
	for build: BuildDefinition in builds:
		if String(build.id) == id:
			return build
	return null


## The main build's id, or NO_BUILD when the deck fits none.
func main_build(deck: Array[CardDefinition]) -> String:
	var best: BuildDefinition = null
	var best_strength: float = 0.0
	for build: BuildDefinition in builds:
		if not build.fits(deck):
			continue
		var strength: float = float(build.count(deck)) / maxf(build.min_count, 1)
		if best == null or strength > best_strength:
			best = build
			best_strength = strength
	return String(best.id) if best != null else NO_BUILD


## The ids of every build the deck fits, in build order (viability's formation check, #42: a
## build strategy's target build fits the final deck).
func fitted(deck: Array[CardDefinition]) -> PackedStringArray:
	var ids_found: PackedStringArray = PackedStringArray()
	for build: BuildDefinition in builds:
		if build.fits(deck):
			ids_found.append(String(build.id))
	return ids_found


static func is_key_card(build: BuildDefinition, card: CardDefinition) -> bool:
	var alone: Array[CardDefinition] = [card]
	return build.count(alone) > 0


## Per build id: the chance that a later NEW ITEMS draw (not a run's first; its products, of any
## tier, and its coupon, #108) from this stock at odds level 0 on a CLASSIC visit shows at least one
## of the build's key cards (#77). Read from the machine's exact odds card (MachineOdds.card's
## in_draw, each prize's chance to be in the draw): the key cards' chances summed, capped at 1 (the
## expected count of key cards shown, an upper bound of the chance when several key cards are
## stocked). `_samples` and `_offer_seed` are kept for the --offer-samples option until S1 (nothing
## is sampled now).
func key_offer_chance(
	balance: BalanceDefinition, stock: RunStock, _samples: int, _offer_seed: int
) -> Dictionary[String, float]:
	var context: MachineContext = MachineContext.new()
	context.machine = balance.machine
	context.balance = balance
	for card: CardDefinition in stock.cards:
		if card.is_product() and card.tier == CardDefinition.Tier.PLAIN:
			context.products.append(card)
	context.coupons = balance.coupon_pool.duplicate()
	context.upgrade_pool = balance.upgrade_pool.duplicate()
	context.first_offer_pool = balance.first_offer_pool.duplicate()
	context.deck = Deck.new(null)
	var by_id: Dictionary[String, CardDefinition] = {}
	for card: CardDefinition in context.products + context.coupons:
		by_id[String(card.id)] = card
	# A BIG or GOLDEN card drawn counts as its plain card.
	if balance.machine != null:
		for chain: ItemUpgradeDefinition in balance.machine.item_upgrades:
			for tier: CardDefinition in chain.tiers():
				if tier != null and by_id.has(String(chain.product.id)):
					by_id[String(tier.id)] = chain.product
	var chances: Dictionary[String, float] = {}
	for build: BuildDefinition in builds:
		chances[String(build.id)] = 0.0
	if balance.machine == null:
		return chances
	var odds: MachineOddsCard = MachineOdds.card(RewardMachine.Chute.NEW_ITEMS, context, 0)
	for build: BuildDefinition in builds:
		var shown: float = 0.0
		for key: String in odds.in_draw:
			var card: CardDefinition = by_id.get(key.get_slice(":", 1))
			if card != null and is_key_card(build, card):
				shown += float(odds.in_draw[key])
		chances[String(build.id)] = minf(shown, 1.0)
	return chances
