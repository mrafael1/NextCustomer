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


## Every build file in `folder`, in file name order.
static func load_folder(folder: String) -> Array[BuildDefinition]:
	var found: Array[BuildDefinition] = []
	var files: PackedStringArray = DirAccess.get_files_at(folder)
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


static func is_key_card(build: BuildDefinition, card: CardDefinition) -> bool:
	var alone: Array[CardDefinition] = [card]
	return build.count(alone) > 0


## Per build id: the share of later reward offers (not a run's first) from this stock that
## show at least one of the build's key cards, over `samples` offers made with their own seeded
## RNGs (RewardOffer.make, as the game makes them).
func key_offer_chance(
	balance: BalanceDefinition, stock: RunStock, samples: int, offer_seed: int
) -> Dictionary[String, float]:
	var seen: Dictionary[String, int] = {}
	for build: BuildDefinition in builds:
		seen[String(build.id)] = 0
	for index: int in range(samples):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash("key_offers:%d:%d" % [offer_seed, index])
		var offer: Array[CardDefinition] = RewardOffer.make(rng, balance, stock.cards, false)
		for build: BuildDefinition in builds:
			if offer.any(func(card: CardDefinition) -> bool: return is_key_card(build, card)):
				seen[String(build.id)] += 1
	var chances: Dictionary[String, float] = {}
	for id: String in seen:
		chances[id] = float(seen[id]) / maxf(samples, 1)
	return chances
