class_name SimRunRecord
extends RefCounted
## What one simulated run did, as plain data: simulator processes write it as JSON and the
## merge reads it back for SimSummary.

var run_seed: int = 0
var won: bool = false
## One ShiftRecord.to_dictionary() per played shift (its machine visits too), in order, plus
## "best": the shift's exact best total (the played total, unless the strategy plays sensible
## rows), and "hand": the card ids of its hand at checkout.
var shifts: Array[Dictionary] = []
## The exact best total and the hand's card ids at checkout of each shift played so far
## (SimPlayer fills them in, then the shifts' "best" and "hand").
var best_totals: PackedInt32Array = PackedInt32Array()
var hands: Array[Array] = []
## Card ids of the deck at the end of the run.
var final_deck: PackedStringArray = PackedStringArray()
## Per card id, over the played shifts: hands that held the card, played rows that used it,
## and hands whose exact best total needed it (SimHandBest.is_needed).
var drawn: Dictionary[String, int] = {}
var in_best: Dictionary[String, int] = {}
var needed: Dictionary[String, int] = {}
## Redraws made over the run.
var redraws: int = 0
## The final deck's main build (SimBuilds), every build it fits, and the coins the run paid
## (CoinPayout): in all, and its overtime coins.
var main_build: String = ""
var fitted_builds: PackedStringArray = PackedStringArray()
var coins: int = 0
var overtime_coins: int = 0
## The machine at the end of the run (#77): the registers picked from it and the final deck's
## BIG and GOLDEN copies by card id.
var registers: int = 0
var tier_copies: Dictionary[String, int] = {}


static func from_dictionary(data: Dictionary) -> SimRunRecord:
	var record: SimRunRecord = SimRunRecord.new()
	record.run_seed = int(data["run_seed"])
	record.won = bool(data["won"])
	for shift: Dictionary in data["shifts"]:
		var entry: Dictionary = shift.duplicate()
		for key: String in ["shift", "quota", "total", "best"]:
			entry[key] = int(entry.get(key, entry["total"]))
		entry["visits"] = _visits(entry.get("visits", []))
		record.shifts.append(entry)
	record.final_deck = PackedStringArray(data["final_deck"])
	for id: String in data["drawn"]:
		record.drawn[id] = int(data["drawn"][id])
	for id: String in data["in_best"]:
		record.in_best[id] = int(data["in_best"][id])
	for id: String in data["needed"]:
		record.needed[id] = int(data["needed"][id])
	record.redraws = int(data["redraws"])
	record.main_build = String(data["main_build"])
	record.fitted_builds = PackedStringArray(data.get("fitted_builds", []))
	record.coins = int(data["coins"])
	record.overtime_coins = int(data["overtime_coins"])
	record.registers = int(data.get("registers", 0))
	var copies: Dictionary = data.get("tier_copies", {})
	for id: String in copies:
		record.tier_copies[id] = int(copies[id])
	return record


## A shift's visits (MachineVisit.to_dictionary) with their numbers whole again after JSON.
static func _visits(visits: Array) -> Array:
	var found: Array = []
	for visit: Dictionary in visits:
		var entry: Dictionary = visit.duplicate(true)
		entry["picked"] = int(entry.get("picked", -1))
		entry["drop_order"] = (entry.get("drop_order", []) as Array).map(
			func(value: Variant) -> int: return int(value)
		)
		for prize: Dictionary in entry.get("prizes", []):
			prize["rarity"] = int(prize.get("rarity", 0))
		for copy: Array in entry.get("upgraded", []):
			if not copy.is_empty():
				copy[0] = int(copy[0])
		found.append(entry)
	return found


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
		"main_build": main_build,
		"fitted_builds": fitted_builds,
		"coins": coins,
		"overtime_coins": overtime_coins,
		"registers": registers,
		"tier_copies": tier_copies,
	}


## `played` is the row the shift checked out, `best` the exact best (the same for best rows).
func count_hand(hand: Array[CardInstance], played: SimHandBest, best: SimHandBest) -> void:
	var seen: Array[CardDefinition] = []
	for card: CardInstance in hand:
		if seen.has(card.definition):
			continue
		seen.append(card.definition)
		var id: String = String(card.definition.id)
		drawn[id] = drawn.get(id, 0) + 1
		if played.uses(card.definition):
			in_best[id] = in_best.get(id, 0) + 1
		if best.is_needed(card.definition):
			needed[id] = needed.get(id, 0) + 1
