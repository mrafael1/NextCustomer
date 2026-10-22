extends GdUnitTestSuite
## The TOY MACHINES' draw (#63, full build plan 7.1; CapsuleDraw): the key item first with no
## RNG use, then at random without duplicates, nothing from an empty machine, and the same
## stream and state give the same capsules. Uses the live aisles.

const BAKERY := "res://data/aisles/bakery.tres"
const COLD_CASES := "res://data/aisles/cold_cases.tres"
const BALANCE := "res://data/balance/balance.tres"


func test_the_key_item_comes_first_without_using_the_rng() -> void:
	var aisle: AisleDefinition = load(BAKERY)
	var unlocked: Dictionary[StringName, int] = {}
	var rng: RandomNumberGenerator = _rng(5)
	var state: int = rng.state
	assert_str(String(CapsuleDraw.draw(aisle, unlocked, rng).id)).is_equal("baguette")
	assert_int(rng.state).is_equal(state)


func test_a_locked_key_item_comes_first_even_after_other_unlocks() -> void:
	var aisle: AisleDefinition = load(BAKERY)
	var unlocked: Dictionary[StringName, int] = {&"scone": 0, &"croissant": 1}
	var rng: RandomNumberGenerator = _rng(6)
	var state: int = rng.state
	assert_str(String(CapsuleDraw.draw(aisle, unlocked, rng).id)).is_equal("baguette")
	assert_int(rng.state).is_equal(state)


## Each item once, from that aisle only; then the machine is empty and draws nothing, with no
## RNG use.
func test_every_item_comes_out_once_then_the_machine_is_empty() -> void:
	var aisle: AisleDefinition = load(BAKERY)
	var unlocked: Dictionary[StringName, int] = {}
	var rng: RandomNumberGenerator = _rng(7)
	var drawn: Array[String] = []
	for _draw: int in range(aisle.capsule_cards.size()):
		assert_bool(CapsuleDraw.is_empty(aisle, unlocked)).is_false()
		var card: CardDefinition = CapsuleDraw.draw(aisle, unlocked, rng)
		assert_bool(aisle.capsule_cards.has(card)).is_true()
		assert_bool(drawn.has(String(card.id))).is_false()
		drawn.append(String(card.id))
		unlocked[card.id] = 0
	assert_int(drawn.size()).is_equal(8)
	assert_bool(CapsuleDraw.is_empty(aisle, unlocked)).is_true()
	assert_array(CapsuleDraw.items_left(aisle, unlocked)).is_empty()
	var state: int = rng.state
	assert_object(CapsuleDraw.draw(aisle, unlocked, rng)).is_null()
	assert_int(rng.state).is_equal(state)


## After the key item, one randi_range per draw among the items left (in data order).
func test_a_later_draw_is_one_randi_range_among_the_items_left() -> void:
	var aisle: AisleDefinition = load(BAKERY)
	var unlocked: Dictionary[StringName, int] = {&"baguette": 0, &"iced_bun": 0}
	var left: Array[CardDefinition] = CapsuleDraw.items_left(aisle, unlocked)
	assert_int(left.size()).is_equal(6)
	var expected: RandomNumberGenerator = _rng(8)
	var index: int = expected.randi_range(0, left.size() - 1)
	var rng: RandomNumberGenerator = _rng(8)
	assert_object(CapsuleDraw.draw(aisle, unlocked, rng)).is_same(left[index])
	assert_int(rng.state).is_equal(expected.state)


func test_the_same_stream_and_state_give_the_same_capsules() -> void:
	var aisle: AisleDefinition = load(BAKERY)
	assert_array(_sequence(aisle, 11)).is_equal(_sequence(aisle, 11))


func test_the_capsule_count_is_every_aisles_capsules() -> void:
	assert_int(CapsuleDraw.capsule_count(load(BALANCE))).is_equal(30)
	var cold: AisleDefinition = load(COLD_CASES)
	var none: Dictionary[StringName, int] = {}
	assert_int(CapsuleDraw.items_left(cold, none).size()).is_equal(2)


func _sequence(aisle: AisleDefinition, seed_value: int) -> Array[String]:
	var unlocked: Dictionary[StringName, int] = {}
	var rng: RandomNumberGenerator = _rng(seed_value)
	var drawn: Array[String] = []
	while not CapsuleDraw.is_empty(aisle, unlocked):
		var card: CardDefinition = CapsuleDraw.draw(aisle, unlocked, rng)
		unlocked[card.id] = 0
		drawn.append(String(card.id))
	return drawn


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
