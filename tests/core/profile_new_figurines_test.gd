extends GdUnitTestSuite
## The profile's new figurines (v1.30, the FIGURINE BOOK button's NEW tag): a draw adds its item,
## the rollback of a failed save takes it off again, the book marks items seen, the debug reset
## clears them, the saved form keeps them in draw order, and a profile saved before format 6
## (with no such field) reads unchanged with nothing new.

const BALANCE := "res://data/balance/balance.tres"


func test_a_draw_adds_its_figurine_and_the_undo_takes_it_off() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var profile: ProfileState = ProfileState.new()
	profile.coins = 3
	profile.set_capsule_seed(1)
	var first: CardDefinition = _draw(profile, balance, &"bakery")
	var second: CardDefinition = _draw(profile, balance, &"pantry")
	assert_array(profile.new_figurines).is_equal([first.id, second.id])
	assert_bool(profile.new_figurines.has(first.id)).is_true()
	var draws: int = profile.capsule_draws
	var third: CardDefinition = _draw(profile, balance, &"snacks")
	profile.undo_capsule(third, 1, draws)
	assert_array(profile.new_figurines).is_equal([first.id, second.id])
	assert_bool(profile.new_figurines.has(third.id)).is_false()


func test_marking_seen_takes_items_off_and_says_whether_anything_changed() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.new_figurines.assign([&"baguette", &"sugar_cubes", &"crisps"])
	assert_bool(profile.mark_figurines_seen([&"sugar_cubes"])).is_true()
	assert_array(profile.new_figurines).is_equal([&"baguette", &"crisps"])
	assert_bool(profile.mark_figurines_seen([&"sugar_cubes", &"milk"])).is_false()
	assert_bool(profile.mark_figurines_seen([&"baguette", &"crisps"])).is_true()
	assert_array(profile.new_figurines).is_empty()


func test_the_debug_reset_clears_them() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.unlocked_items[&"baguette"] = 0
	profile.new_figurines.append(&"baguette")
	profile.reset_collection()
	assert_array(profile.new_figurines).is_empty()


func test_the_saved_form_keeps_them_in_draw_order() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.unlocked_items[&"zucchini"] = 0
	profile.unlocked_items[&"apple"] = 1
	profile.new_figurines.assign([&"zucchini", &"apple"])
	var text: String = JSON.stringify(profile.to_dictionary(), "", true)
	var read: ProfileState = ProfileState.from_dictionary(JSON.parse_string(text))
	assert_object(read).is_not_null()
	assert_array(read.new_figurines).is_equal([&"zucchini", &"apple"])
	var bad: Dictionary = profile.to_dictionary()
	bad["new_figurines"] = "apple"
	assert_object(ProfileState.from_dictionary(bad)).is_null()


## A format 5 profile (before v1.30) reads with every field as it was and nothing new; saved
## again, it writes format 6 with an empty list.
func test_an_older_profile_reads_unchanged_with_nothing_new() -> void:
	var old: Dictionary = {
		"format_version": 5.0,
		"coins": 4.0,
		"run_count": 7.0,
		"unlocked_items": [["baguette", 2.0], ["crisps", 3.0]],
		"last_list": ["bakery"],
		"seen": ["capsule_machine"],
		"settings": {"reduced_motion": true},
		"capsule_seed": "99",
		"capsule_draws": 2.0,
		"unlocked_pins": ["repack"],
		"worn_pins": ["repack"],
		"pins_bought": 1.0,
	}
	var read: ProfileState = ProfileState.from_dictionary(old)
	assert_object(read).is_not_null()
	assert_array(read.new_figurines).is_empty()
	assert_int(read.coins).is_equal(4)
	assert_int(read.run_count).is_equal(7)
	assert_array(read.unlocked_items.keys()).is_equal([&"baguette", &"crisps"])
	assert_int(read.capsule_seed).is_equal(99)
	assert_int(read.capsule_draws).is_equal(2)
	assert_array(read.worn_pins).is_equal([&"repack"])
	assert_bool(read.reduced_motion()).is_true()
	var saved: Dictionary = read.to_dictionary()
	assert_int(saved["format_version"]).is_equal(6)
	assert_array(saved["new_figurines"]).is_empty()


static func _draw(
	profile: ProfileState, balance: BalanceDefinition, aisle_id: StringName
) -> CardDefinition:
	var aisle: AisleDefinition = null
	for found: AisleDefinition in balance.aisles:
		if found.id == aisle_id:
			aisle = found
	var stream: RandomNumberGenerator = EventLogService.capsule_stream(
		profile.capsule_seed, profile.capsule_draws
	)
	return profile.draw_capsule(aisle, 1, 0, stream)
