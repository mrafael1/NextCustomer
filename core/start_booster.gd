class_name StartBooster
extends RefCounted
## One of the opening-time board's aisle boosters (start screen YOUR STORE, full build plan 7.2,
## v1.32): its aisle and the cards dealt into it, the commons first, then its `hits` hit cards
## (the last places; a hit card may be RARE, its chain's BIG tier). `opened`: the player opened it
## (opening only reveals; the contents are fixed at the deal). `sold_out`: PICK 2 OF 3 left it out,
## so its cards never count. `restocked`: the run's RESTOCK dealt it again (it is sealed again
## until opened).

var aisle: StringName = &""
var cards: Array[CardDefinition] = []
var hits: int = 0
var opened: bool = false
var sold_out: bool = false
var restocked: bool = false


func _init(
	booster_aisle: StringName = &"", booster_cards: Array[CardDefinition] = [], hit_count: int = 0
) -> void:
	aisle = booster_aisle
	cards = booster_cards.duplicate()
	hits = hit_count


## Whether place `index` holds a hit card.
func is_hit(index: int) -> bool:
	return index >= cards.size() - hits and index >= 0 and index < cards.size()


## Whether place `index` holds a RARE hit card (a BIG tier).
func is_rare(index: int) -> bool:
	return is_hit(index) and cards[index].tier == CardDefinition.Tier.BIG


## How many RARE cards the booster holds.
func rare_count() -> int:
	var count: int = 0
	for index: int in cards.size():
		if is_rare(index):
			count += 1
	return count


func copy() -> StartBooster:
	var other: StartBooster = StartBooster.new(aisle, cards, hits)
	other.opened = opened
	other.sold_out = sold_out
	other.restocked = restocked
	return other


func to_dictionary() -> Dictionary:
	var ids: Array[String] = []
	for card: CardDefinition in cards:
		ids.append(String(card.id))
	return {
		"aisle": String(aisle),
		"cards": ids,
		"hits": hits,
		"opened": opened,
		"sold_out": sold_out,
		"restocked": restocked,
	}
