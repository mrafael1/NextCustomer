class_name SimRunRecord
extends RefCounted
## What one simulated run did, as plain data: simulator processes write it as JSON and the
## merge reads it back for SimSummary.

var run_seed: int = 0
var won: bool = false
## One ShiftRecord.to_dictionary() per played shift, in order.
var shifts: Array[Dictionary] = []
## Card ids of the deck at the end of the run.
var final_deck: PackedStringArray = PackedStringArray()
## Per card id, over the played shifts: hands that held the card, best rows that used it, and
## hands whose best total needed it (SimHandBest.is_needed).
var drawn: Dictionary[String, int] = {}
var in_best: Dictionary[String, int] = {}
var needed: Dictionary[String, int] = {}
## Redraws made over the run.
var redraws: int = 0


static func from_dictionary(data: Dictionary) -> SimRunRecord:
	var record: SimRunRecord = SimRunRecord.new()
	record.run_seed = int(data["run_seed"])
	record.won = bool(data["won"])
	for shift: Dictionary in data["shifts"]:
		var entry: Dictionary = shift.duplicate()
		for key: String in ["shift", "quota", "total"]:
			entry[key] = int(entry[key])
		record.shifts.append(entry)
	record.final_deck = PackedStringArray(data["final_deck"])
	for id: String in data["drawn"]:
		record.drawn[id] = int(data["drawn"][id])
	for id: String in data["in_best"]:
		record.in_best[id] = int(data["in_best"][id])
	for id: String in data["needed"]:
		record.needed[id] = int(data["needed"][id])
	record.redraws = int(data["redraws"])
	return record


func to_dictionary() -> Dictionary:
	return {
		"run_seed": run_seed,
		"won": won,
		"shifts": shifts,
		"final_deck": final_deck,
		"drawn": drawn,
		"in_best": in_best,
		"needed": needed,
		"redraws": redraws,
	}


func count_hand(hand: Array[CardInstance], best: SimHandBest) -> void:
	var seen: Array[CardDefinition] = []
	for card: CardInstance in hand:
		if seen.has(card.definition):
			continue
		seen.append(card.definition)
		var id: String = String(card.definition.id)
		drawn[id] = drawn.get(id, 0) + 1
		if best.uses(card.definition):
			in_best[id] = in_best.get(id, 0) + 1
		if best.is_needed(card.definition):
			needed[id] = needed.get(id, 0) + 1
