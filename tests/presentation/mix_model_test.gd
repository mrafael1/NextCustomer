extends GdUnitTestSuite
## The mix highlight's looks (MixModel, #105 piece 3, mock-up readability v3 section 4, option A):
## a family glyph lights its family (belt items by their scored tags, others by their printed ones)
## and greys the rest; an item lights what it works with (CardAffinity): SELF for itself, PENALTY
## first, then NOW for a belt pair paying in the order (EffectGraph), LIT, FAINT for a broad match
## alone, GREY for the rest; nothing to light gives no highlight; no graph, no NOW.

const CARDS := "res://data/cards"


## The belt Eggs, Bread, Milk and a hand Batteries: the Breakfast glyph lights the first three.
func test_a_family_lights_its_items() -> void:
	var entries: Array[MixModel.Entry] = _entries(["eggs", "bread", "milk"], ["batteries"])
	assert_array(MixModel.for_family(entries, "Breakfast")).is_equal(
		[MixModel.Look.LIT, MixModel.Look.LIT, MixModel.Look.LIT, MixModel.Look.GREY]
	)
	assert_array(MixModel.for_family(entries, "Household")).is_equal(
		[MixModel.Look.GREY, MixModel.Look.GREY, MixModel.Look.GREY, MixModel.Look.LIT]
	)
	# No item in it: no highlight.
	assert_array(MixModel.for_family(entries, "Frozen")).is_empty()
	# A belt item's scored tags count: Batteries made Breakfast on the belt lights.
	var granted: PackedStringArray = PackedStringArray(["Household", "Breakfast"])
	var tagged: MixModel.Entry = MixModel.Entry.new(_instance("batteries", 9), granted, 3)
	assert_array(MixModel.for_family([tagged] as Array[MixModel.Entry], "Breakfast")).is_equal(
		[MixModel.Look.LIT]
	)


## Hovering Bread on the belt Eggs, Bread, Milk (hand: Batteries, Strawberries): Eggs gives Bread
## its ×2 now (NOW, though only a weak Food match), Milk counts Bread (LIT), Strawberries is only
## Food for nothing (GREY), Batteries GREY. Without a graph Eggs is FAINT (its "next Food").
func test_an_item_lights_what_it_works_with() -> void:
	var entries: Array[MixModel.Entry] = _entries(
		["eggs", "bread", "milk"], ["batteries", "strawberries"]
	)
	var graph: EffectGraph = _graph(entries)
	var looks: Array[MixModel.Look] = MixModel.for_card(entries, entries[1], graph, _broad())
	(
		assert_array(looks)
		. is_equal(
			[
				MixModel.Look.NOW,
				MixModel.Look.SELF,
				MixModel.Look.LIT,
				MixModel.Look.GREY,
				MixModel.Look.GREY,
			]
		)
	)
	var dragged: Array[MixModel.Look] = MixModel.for_card(entries, entries[1], null, _broad())
	assert_int(dragged[0]).is_equal(MixModel.Look.FAINT)
	assert_bool(MixModel.greys(MixModel.Look.FAINT)).is_true()
	assert_bool(MixModel.greys(MixModel.Look.GREY)).is_true()
	for look: MixModel.Look in [
		MixModel.Look.NONE,
		MixModel.Look.SELF,
		MixModel.Look.LIT,
		MixModel.Look.NOW,
		MixModel.Look.PENALTY
	]:
		assert_bool(MixModel.greys(look)).is_false()
	# Hovering the hand's Strawberries: Eggs' next Food is faint, the rest grey.
	var berries: Array[MixModel.Look] = MixModel.for_card(entries, entries[4], graph, _broad())
	(
		assert_array(berries)
		. is_equal(
			[
				MixModel.Look.FAINT,
				MixModel.Look.GREY,
				MixModel.Look.GREY,
				MixModel.Look.GREY,
				MixModel.Look.SELF,
			]
		)
	)


## A penalty pair beats a pair paying now: Soup beside Frozen peas.
func test_a_penalty_wins() -> void:
	var entries: Array[MixModel.Entry] = _entries(["frozen_peas", "soup"], [])
	var graph: EffectGraph = _graph(entries)
	var looks: Array[MixModel.Look] = MixModel.for_card(entries, entries[1], graph, _broad())
	assert_array(looks).is_equal([MixModel.Look.PENALTY, MixModel.Look.SELF])


## Nothing it works with: no highlight at all; a focus off screen (a dragged card) still lights.
func test_nothing_to_light_is_quiet() -> void:
	var entries: Array[MixModel.Entry] = _entries(["batteries"], ["two_for_one"])
	assert_array(MixModel.for_card(entries, entries[0], null, _broad())).is_empty()
	var dragged: MixModel.Entry = MixModel.Entry.new(_instance("milk", 40), _tags("milk"))
	assert_array(MixModel.for_card(_entries(["bread"], []), dragged, null, _broad())).is_equal(
		[MixModel.Look.LIT]
	)


## Entries for `belt` (slots 0..) then `hand` (slot -1), each a new instance.
func _entries(belt: Array, hand: Array) -> Array[MixModel.Entry]:
	var entries: Array[MixModel.Entry] = []
	for index: int in range(belt.size()):
		entries.append(
			MixModel.Entry.new(_instance(belt[index], index + 1), _tags(belt[index]), index)
		)
	for index: int in range(hand.size()):
		entries.append(MixModel.Entry.new(_instance(hand[index], 20 + index), _tags(hand[index])))
	return entries


## The belt entries' scored graph.
static func _graph(entries: Array[MixModel.Entry]) -> EffectGraph:
	var row: Array[CardInstance] = []
	for entry: MixModel.Entry in entries:
		if entry.slot >= 0:
			row.append(entry.card)
	return EffectGraph.build(Scoring.score(row))


static func _instance(id: String, instance_id: int) -> CardInstance:
	return CardInstance.new(load("%s/%s.tres" % [CARDS, id]) as CardDefinition, instance_id)


static func _tags(id: String) -> PackedStringArray:
	return (load("%s/%s.tres" % [CARDS, id]) as CardDefinition).tags


static func _broad() -> PackedStringArray:
	return FamilyPalette.shared().quiet_families
