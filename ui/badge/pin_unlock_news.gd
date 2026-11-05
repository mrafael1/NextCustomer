class_name PinUnlockNews
extends RefCounted
## The badge pins a run's end unlocked (#122; the achievement unlock mock-up of 2026-11-05,
## docs/art/mockups/achievement_unlock.html, look A), for the results' unlock cards (PinReveal):
## one card per pin, in catalogue order (ProfileState.record_run's order), each with the profile's
## pin count once it is owned (5 pins are owned from the start, so the first unlock reads 6 / 8),
## and the next milestone still locked ("Next: Repack · Win a run"; none once every pin is owned).
## Decks and card variants have unlock code but no locked content yet, so they get no card.

const NEXT_TEXT := "Next: %s · %s"

var cards: Array[Card] = []
## The next locked pin with a milestone and that milestone, or "" once every one is owned.
var next_text: String = ""


## One unlock card: the pin, its catalogue index (its face colour, PinFace.colour_index), the
## owned pins once it is owned and the catalogue's pin count.
class Card:
	var pin: PinDefinition
	var index: int = 0
	var owned: int = 0
	var total: int = 0

	func _init(
		card_pin: PinDefinition, card_index: int, owned_count: int, total_count: int
	) -> void:
		pin = card_pin
		index = card_index
		owned = owned_count
		total = total_count

	## The milestone met, as the badge screen states it ("Finish a run").
	func milestone() -> String:
		return "" if pin.unlock_condition == null else pin.unlock_condition.summary()


## Records the ended `run` on `profile` (ProfileState.record_run: its unlocks and coins) and
## returns the news of the pins it unlocked.
static func record(
	run: RunState, profile: ProfileState, catalogue: CatalogueDefinition
) -> PinUnlockNews:
	return of(profile.record_run(run, catalogue), profile, catalogue)


## The news of the unlocked `ids` (any order; ids that aren't pins are left out), read on the
## profile that now owns them.
static func of(
	ids: Array[StringName], profile: ProfileState, catalogue: CatalogueDefinition
) -> PinUnlockNews:
	var news: PinUnlockNews = PinUnlockNews.new()
	var owned: int = 0
	var fresh: Array[int] = []
	for index: int in range(catalogue.pins.size()):
		var pin: PinDefinition = catalogue.pins[index]
		if profile.has_pin(pin):
			owned += 1
		if ids.has(pin.id):
			fresh.append(index)
		elif news.next_text.is_empty() and not profile.has_pin(pin):
			news.next_text = NEXT_TEXT % [pin.display_name, pin.unlock_condition.summary()]
	var total: int = catalogue.pins.size()
	for place: int in range(fresh.size()):
		var count: int = owned - fresh.size() + place + 1
		news.cards.append(Card.new(catalogue.pins[fresh[place]], fresh[place], count, total))
	return news


func is_empty() -> bool:
	return cards.is_empty()
