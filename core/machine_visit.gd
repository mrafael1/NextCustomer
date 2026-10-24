class_name MachineVisit
extends RefCounted
## One visit to the RECEIPT REWARDS machine (#77, build spec 2.2): the shift's ticket, the
## inspection's bonus ticket or a STAMP DAY, the chute chosen, the prizes drawn and what was done
## with them. RewardMachine fills it in and appends it to the shift's ShiftRecord.visits at the
## pick or bin; to_dictionary is the form the run save and the event log use.

enum Kind { TICKET, BONUS, STAMP_DAY }

## Kind names, as saved.
const KIND_NAMES: Array[String] = ["ticket", "bonus", "stamp_day"]
## RewardMachine.Chute names, as saved and logged.
const CHUTE_NAMES: Array[String] = ["new_items", "coupons", "register", "upgrades"]
const NO_CHUTE := -1

var kind: Kind = Kind.TICKET
## RewardMachine.Chute, or NO_CHUTE before the choice.
var chute: int = NO_CHUTE
## BONUS: the inspection id it was earned by, or "" for a bonus extra shift.
var why: String = ""
## TICKET or BONUS (v0.53): a BOOSTED visit (REGISTER and UPGRADES lit; v0.47), decided when it
## starts.
var boosted: bool = false
## The prizes in reveal order (rarity ascending, drop order within a rarity).
var prizes: Array[MachinePrize] = []
## The reveal index of each drop, in drop order.
var drop_order: PackedInt32Array = PackedInt32Array()
## The reveal index picked, or -1.
var picked: int = -1
var binned: bool = false
## The cart card swapped out for the pick at the deck limit, or null.
var replaced: CardDefinition
## UPGRADES: [instance_id, from card id, to card id] per upgraded copy.
var upgraded: Array = []
## The draw held its chute's guarantee.
var guarantee_held: bool = false
## STAMP DAY only: the REGISTER odds card the draw was made from (for the event log; not saved).
var stamp_day_odds: MachineOddsCard


func _init(visit_kind: Kind = Kind.TICKET, visit_why: String = "") -> void:
	kind = visit_kind
	why = visit_why


## The prize picked, or null.
func picked_prize() -> MachinePrize:
	return prizes[picked] if picked >= 0 and picked < prizes.size() else null


## Sets the prizes from a draw (drop order): sorts them into reveal order and keeps drop_order.
func set_drawn(drawn: Array[MachinePrize]) -> void:
	var order: Array[int] = []
	for index: int in drawn.size():
		order.append(index)
	order.sort_custom(
		func(a: int, b: int) -> bool:
			if drawn[a].rarity != drawn[b].rarity:
				return drawn[a].rarity < drawn[b].rarity
			return a < b
	)
	prizes = []
	drop_order = PackedInt32Array()
	drop_order.resize(drawn.size())
	for reveal: int in order.size():
		prizes.append(drawn[order[reveal]])
		drop_order[order[reveal]] = reveal


## The prizes in drop order.
func in_drop_order() -> Array[MachinePrize]:
	var found: Array[MachinePrize] = []
	found.resize(prizes.size())
	for drop: int in drop_order.size():
		found[drop] = prizes[drop_order[drop]]
	return found


func to_dictionary() -> Dictionary:
	return {
		"kind": KIND_NAMES[kind],
		"chute": CHUTE_NAMES[chute] if chute >= 0 and chute < CHUTE_NAMES.size() else "",
		"why": why,
		"boosted": boosted,
		"prizes": prizes.map(func(prize: MachinePrize) -> Dictionary: return prize.to_dictionary()),
		"drop_order": Array(drop_order),
		"picked": picked,
		"binned": binned,
		"replaced": String(replaced.id) if replaced != null else "",
		"upgraded": upgraded.duplicate(true),
		"guarantee_held": guarantee_held,
	}


## Reads to_dictionary's form (as parsed from JSON). Null when a field is missing or wrong, an id
## doesn't resolve, drop_order isn't an order of the prizes, or the pick is out of range.
static func from_dictionary(data: Dictionary, lookup: ContentLookup) -> MachineVisit:
	var reader: SaveReader = SaveReader.new(data, lookup)
	var kind_index: int = KIND_NAMES.find(reader.text("kind"))
	var visit: MachineVisit = MachineVisit.new(maxi(kind_index, 0) as Kind, reader.text("why"))
	var chute_text: String = reader.text("chute")
	visit.chute = CHUTE_NAMES.find(chute_text)
	visit.boosted = reader.flag("boosted")
	for prize_data: Dictionary in reader.dictionaries("prizes"):
		var prize: MachinePrize = MachinePrize.from_dictionary(prize_data, lookup)
		if prize == null:
			return null
		visit.prizes.append(prize)
	visit.drop_order = PackedInt32Array(reader.wholes("drop_order"))
	visit.picked = reader.whole("picked", -1)
	visit.binned = reader.flag("binned")
	visit.replaced = reader.card("replaced")
	visit.guarantee_held = reader.flag("guarantee_held")
	var upgraded_copies: Variant = _upgraded(data.get("upgraded"))
	var bad_chute: bool = visit.chute == NO_CHUTE and not chute_text.is_empty()
	if not reader.ok or kind_index == -1 or bad_chute or upgraded_copies == null:
		return null
	visit.upgraded = upgraded_copies
	return visit if visit._is_consistent() else null


## The upgraded copies as saved: [[instance id, from id, to id], ...]; null when malformed.
static func _upgraded(value: Variant) -> Variant:
	if not value is Array:
		return null
	var found: Array = []
	for entry: Variant in value:
		if not entry is Array or (entry as Array).size() != 3:
			return null
		var pair: Array = entry
		if not SaveReader.is_whole(pair[0]) or not pair[1] is String or not pair[2] is String:
			return null
		found.append([int(pair[0]), pair[1], pair[2]])
	return found


func _is_consistent() -> bool:
	if drop_order.size() != prizes.size() or picked >= prizes.size():
		return false
	if binned and picked >= 0:
		return false
	if boosted and kind == Kind.STAMP_DAY:
		return false
	var seen: Dictionary = {}
	for reveal: int in drop_order:
		if reveal >= prizes.size() or seen.has(reveal):
			return false
		seen[reveal] = true
	return true
