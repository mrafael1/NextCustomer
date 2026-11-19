extends GdUnitTestSuite
## The Dairy aisle's renames (v1.44: the Cold cases aisle's id is `dairy`, and Frozen peas is a
## Fruit & veg capsule item): AisleRename's deep rename, and the profile's saved form (format 8),
## whose older versions read with their aisle ids renamed and Frozen peas unlocked. The run
## save's side is start_setup_save_test's. (Here and not in profile_state_test, which is at the
## lint's limit of public methods.)

const BALANCE := "res://data/balance/balance.tres"


func test_an_old_aisle_id_reads_under_its_name_of_today() -> void:
	assert_str(AisleRename.id_now("cold_cases")).is_equal("dairy")
	for id: String in ["dairy", "pantry", "cold_cases_big", "Cold cases", ""]:
		assert_str(AisleRename.id_now(id)).is_equal(id)
	var balance: BalanceDefinition = load(BALANCE)
	var ids: Array = balance.aisles.map(func(aisle: AisleDefinition) -> String: return aisle.id)
	# Every old id is gone from the data and names an aisle of today.
	for old: String in AisleRename.RENAMED:
		assert_bool(ids.has(old)).override_failure_message(old).is_false()
		assert_bool(ids.has(AisleRename.RENAMED[old])).override_failure_message(old).is_true()
	# Every moved product is a capsule item now, and no aisle's base product.
	for id: StringName in AisleRename.MOVED_TO_CAPSULES:
		var homes: int = 0
		for aisle: AisleDefinition in balance.aisles:
			for card: CardDefinition in aisle.base_cards:
				assert_str(String(card.id)).is_not_equal(String(id))
			for card: CardDefinition in aisle.capsule_cards:
				homes += 1 if card.id == id else 0
		assert_int(homes).override_failure_message(String(id)).is_equal(1)


## The deep rename: values and dictionary keys, at any depth of arrays and dictionaries; other
## strings (a longer id holding the old one), numbers, flags and nulls are kept, and so is the
## order. The value passed in is never changed.
func test_the_deep_rename_reaches_nested_keys_and_values() -> void:
	var saved: Dictionary = {
		"listed_aisles": ["cold_cases", "pantry"],
		"cold_cases": {"cold_cases": "cold_cases", "cards": ["cheese", ["cold_cases", 3.0]]},
		"start_setup":
		{
			"stock_aisles": ["pantry", "cold_cases"],
			"boosters": [{"aisle": "cold_cases", "cards": ["cheese"], "opened": true}],
			"swap_offers": {"cold_cases": ["butter"], "pantry": []},
		},
		"kept": ["cold_cases_big", "Cold cases", "start_booster_cold_cases"],
		"count": 2,
		"none": null,
		7: "cold_cases",
	}
	var untouched: Dictionary = saved.duplicate(true)
	var result: Dictionary = AisleRename.renamed(saved)
	(
		assert_dict(result)
		. is_equal(
			{
				"listed_aisles": ["dairy", "pantry"],
				"dairy": {"dairy": "dairy", "cards": ["cheese", ["dairy", 3.0]]},
				"start_setup":
				{
					"stock_aisles": ["pantry", "dairy"],
					"boosters": [{"aisle": "dairy", "cards": ["cheese"], "opened": true}],
					"swap_offers": {"dairy": ["butter"], "pantry": []},
				},
				"kept": ["cold_cases_big", "Cold cases", "start_booster_cold_cases"],
				"count": 2,
				"none": null,
				7: "dairy",
			}
		)
	)
	assert_array(result.keys()).is_equal(
		["listed_aisles", "dairy", "start_setup", "kept", "count", "none", 7]
	)
	assert_dict(saved).is_equal(untouched)
	# A copy: changing the result leaves the source alone.
	(result["listed_aisles"] as Array).append("bakery")
	assert_array(saved["listed_aisles"]).is_equal(["cold_cases", "pantry"])
	assert_str(AisleRename.renamed("cold_cases")).is_equal("dairy")
	assert_array(AisleRename.renamed(["cold_cases", 1, true])).is_equal(["dairy", 1, true])
	assert_int(AisleRename.renamed(4)).is_equal(4)
	assert_object(AisleRename.renamed(null)).is_null()


## A version 7 profile (before the Dairy aisle) reads with the Cold cases aisle's id renamed in
## its list, its saved pair and its run-only aisle, and with Frozen peas (a base product it owned
## from the start, a Fruit & veg capsule item now) unlocked at run index -1, after the items it
## drew: not a new figurine, and no draw counted. Saved again, it writes format 8, which reads
## back the same.
func test_a_version_7_profile_reads_with_dairy_and_frozen_peas() -> void:
	assert_int(ProfileState.BEFORE_DAIRY_VERSION).is_equal(7)
	var old: Dictionary = {
		"format_version": 7.0,
		"coins": 2.0,
		"run_count": 5.0,
		"unlocked_items": [["cream", 2.0], ["baguette", 4.0]],
		"new_figurines": ["baguette"],
		"last_list": ["cold_cases", "bakery"],
		"stock_pair": ["pantry", "cold_cases"],
		"stock_run_only": "cold_cases",
		"capsule_seed": "12",
		"capsule_draws": 2.0,
	}
	var untouched: Dictionary = old.duplicate(true)
	var read: ProfileState = ProfileState.from_dictionary(old)
	assert_object(read).is_not_null()
	assert_dict(old).is_equal(untouched)
	assert_array(read.last_list).is_equal([&"dairy", &"bakery"])
	assert_array(read.stock_pair).is_equal([&"pantry", &"dairy"])
	assert_str(String(read.stock_run_only)).is_equal("dairy")
	assert_array(read.unlocked_items.keys()).is_equal([&"cream", &"baguette", &"frozen_peas"])
	assert_int(read.unlocked_items[&"cream"]).is_equal(2)
	assert_int(read.unlocked_items[&"baguette"]).is_equal(4)
	assert_int(read.unlocked_items[&"frozen_peas"]).is_equal(-1)
	assert_array(read.new_figurines).is_equal([&"baguette"])
	assert_int(read.capsule_draws).is_equal(2)
	assert_int(read.coins).is_equal(2)
	# The Fruit & veg machine no longer holds it, and the book counts it.
	var balance: BalanceDefinition = load(BALANCE)
	assert_int(read.owned_capsules(balance)).is_equal(3)
	for aisle: AisleDefinition in balance.aisles:
		for card: CardDefinition in CapsuleDraw.items_left(aisle, read.unlocked_items):
			assert_str(String(card.id)).is_not_equal("frozen_peas")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(read.to_dictionary()))
	assert_int(int(saved["format_version"])).is_equal(8)
	assert_array(saved["last_list"]).is_equal(["dairy", "bakery"])
	assert_array(saved["unlocked_items"]).is_equal(
		[["cream", 2.0], ["baguette", 4.0], ["frozen_peas", -1.0]]
	)
	var again: ProfileState = ProfileState.from_dictionary(saved)
	assert_object(again).is_not_null()
	assert_dict(again.to_dictionary()).is_equal(read.to_dictionary())


## Every older version takes the same path (a version 1 profile with no unlocked item at all),
## and an older profile that already names Frozen peas keeps its own entry.
func test_every_older_profile_owns_frozen_peas_once() -> void:
	for version: int in range(1, ProfileState.BEFORE_DAIRY_VERSION + 1):
		var read: ProfileState = ProfileState.from_dictionary(
			{"format_version": float(version), "last_list": ["cold_cases"]}
		)
		assert_object(read).override_failure_message(str(version)).is_not_null()
		assert_dict(read.unlocked_items).is_equal({&"frozen_peas": -1})
		assert_array(read.last_list).is_equal([&"dairy"])
		assert_array(read.new_figurines).is_empty()
		assert_int(read.capsule_draws).is_equal(0)
	var held: ProfileState = ProfileState.from_dictionary(
		{"format_version": 7.0, "unlocked_items": [["frozen_peas", 3.0], ["cream", 4.0]]}
	)
	assert_array(held.unlocked_items.keys()).is_equal([&"frozen_peas", &"cream"])
	assert_int(held.unlocked_items[&"frozen_peas"]).is_equal(3)


## A version 8 profile is read as it is: Frozen peas stays locked until its capsule is drawn, and
## nothing is renamed (it never wrote the old id).
func test_a_version_8_profile_reads_as_it_is() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.run_count = 5
	profile.unlocked_items = {&"cream": 2, &"baguette": 4}
	profile.last_list.assign([&"dairy", &"bakery"])
	profile.stock_pair.assign([&"pantry", &"dairy"])
	profile.stock_run_only = &"dairy"
	var saved: Dictionary = JSON.parse_string(JSON.stringify(profile.to_dictionary()))
	assert_int(int(saved["format_version"])).is_equal(8)
	var read: ProfileState = ProfileState.from_dictionary(saved)
	assert_object(read).is_not_null()
	assert_array(read.unlocked_items.keys()).is_equal([&"cream", &"baguette"])
	assert_bool(read.unlocked_items.has(&"frozen_peas")).is_false()
	assert_array(read.last_list).is_equal([&"dairy", &"bakery"])
	assert_dict(read.to_dictionary()).is_equal(profile.to_dictionary())
	# The old id in a version 8 file is not an aisle's: it is kept as written, never renamed.
	saved["last_list"] = ["cold_cases"]
	saved["stock_run_only"] = "cold_cases"
	var odd: ProfileState = ProfileState.from_dictionary(saved)
	assert_array(odd.last_list).is_equal([&"cold_cases"])
	assert_str(String(odd.stock_run_only)).is_equal("cold_cases")
	assert_bool(odd.unlocked_items.has(&"frozen_peas")).is_false()
