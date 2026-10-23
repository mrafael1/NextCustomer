extends GdUnitTestSuite
## The live machine data (#77, build spec 1.2): data/balance/machine.tres, referenced from the
## balance. Its rarity lists follow the approved table (product_rarity.json with Carrier bag and
## Tea bags moved to RARE, R3b), its odds are the approved draw's, and its shift lists fit the
## run. These values are tuned between playtests, so tuning updates this test.

const BALANCE := "res://data/balance/balance.tres"
const MACHINE := "res://data/balance/machine.tres"
const STARTER := "res://data/decks/starter.tres"
const RARITY_TABLE := "res://docs/art/mockups/machine_77_src/product_rarity.json"
## R3b (decided with the user): these leave the Legendary list for the Rare one.
const R3B_RARE: Array[String] = ["tea_bags", "carrier_bag"]
## draw77.js ODDS, per Regular level (COMMON, RARE, LEGENDARY).
const ODDS := [[75, 22, 3], [65, 28, 7], [55, 33, 12], [45, 37, 18]]

var _balance: BalanceDefinition
var _machine: MachineDefinition


func before() -> void:
	_balance = load(BALANCE)
	_machine = load(MACHINE)


func test_the_balance_uses_the_machine_file() -> void:
	assert_object(_balance.machine).is_same(_machine)
	assert_int(_machine.prizes_per_visit).is_equal(3)
	assert_int(_machine.register_cap).is_equal(3)
	assert_int(_machine.shelf_min_copies).is_equal(2)
	assert_bool(_machine.bonus_after_inspection).is_true()
	assert_bool(_machine.new_arrival_first_visit).is_true()
	assert_array(Array(_machine.bonus_extra_shifts)).is_empty()


## The approved odds; every level rolls something, drop 1 too (its floor leaves a positive sum).
func test_the_odds_levels_are_the_approved_ones() -> void:
	assert_int(_machine.odds_levels.size()).is_equal(ODDS.size())
	assert_int(_machine.max_level()).is_equal(3)
	for index: int in _machine.odds_levels.size():
		var level: MachineOddsLevel = _machine.odds_levels[index]
		var weights: Array = [level.common_weight, level.rare_weight, level.legendary_weight]
		assert_array(weights).is_equal(ODDS[index])
		assert_bool(weights.all(func(weight: int) -> bool: return weight >= 0)).is_true()
		for drop: int in _machine.prizes_per_visit:
			var rolled: PackedInt32Array = level.weights(drop)
			assert_int(rolled[0] + rolled[1] + rolled[2]).is_greater(0)
		assert_int(level.first_drop_min_rarity).is_equal(1 if index == 3 else 0)


## Every listed product is a plain stockable product (a staple or an aisle item), every listed
## coupon is in the coupon pool, every listed upgrade in the upgrade pool, and nothing is in two
## lists.
func test_the_rarity_lists_hold_the_right_kinds() -> void:
	var stockable: Array[CardDefinition] = RunStock.staples(_balance)
	for aisle: AisleDefinition in _balance.aisles:
		stockable.append_array(aisle.base_cards + aisle.capsule_cards)
	for card: CardDefinition in _machine.rare_products + _machine.legendary_products:
		var where: String = String(card.id)
		assert_bool(card.is_product()).override_failure_message(where).is_true()
		assert_int(card.tier).override_failure_message(where).is_equal(CardDefinition.Tier.PLAIN)
		assert_bool(stockable.has(card)).override_failure_message(where).is_true()
	for card: CardDefinition in _machine.rare_coupons + _machine.legendary_coupons:
		(
			assert_bool(_balance.coupon_pool.has(card))
			. override_failure_message(String(card.id))
			. is_true()
		)
	for upgrade: UpgradeDefinition in _machine.rare_upgrades + _machine.legendary_upgrades:
		(
			assert_bool(_balance.upgrade_pool.has(upgrade))
			. override_failure_message(String(upgrade.id))
			. is_true()
		)
	for lists: Array in [
		[_machine.rare_products, _machine.legendary_products],
		[_machine.rare_coupons, _machine.legendary_coupons],
		[_machine.rare_upgrades, _machine.legendary_upgrades],
	]:
		var seen: Dictionary = {}
		for list: Array in lists:
			for item: Resource in list:
				assert_bool(seen.has(item)).override_failure_message(str(item.get("id"))).is_false()
				seen[item] = true


## The product rarities are the approved table with R3b: Carrier bag and Tea bags are RARE, so the
## fresh stock has no Legendary product. Coupons and registers follow the approved draw's tiers.
func test_the_rarities_follow_the_approved_table_with_r3b() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RARITY_TABLE))
	var rare: Array = table["tiers"]["rare"].duplicate()
	rare.append_array(R3B_RARE)
	var legendary: Array = table["tiers"]["legendary"].filter(
		func(id: String) -> bool: return not R3B_RARE.has(id)
	)
	assert_array(_ids(_machine.rare_products)).contains_exactly_in_any_order(rare)
	assert_array(_ids(_machine.legendary_products)).contains_exactly_in_any_order(legendary)
	assert_array(_ids(_machine.rare_coupons)).contains_exactly_in_any_order(
		["repeat", "two_for_one", "multipack"]
	)
	assert_array(_ids(_machine.legendary_coupons)).is_equal(["opening_deal"])
	assert_array(_ids(_machine.rare_upgrades)).contains_exactly_in_any_order(
		["coupon_engine", "category_engine"]
	)
	assert_array(_ids(_machine.legendary_upgrades)).is_equal(["slot_engine"])
	var fresh: RunStock = RunStock.starting(_balance)
	for card: CardDefinition in fresh.cards:
		if card.is_product():
			assert_int(_machine.product_rarity(card)).is_less(MachinePrize.Rarity.LEGENDARY)


## The shift lists fit the run: each is a shift with a visit after it (1 to shift count - 1), the
## STAMP DAY floors match its shifts, and no shift has both a bonus visit and a STAMP DAY. The
## BOOSTED shifts are 3, 5 and 7 (v0.47), and each shift's odds level is the approved one (1-2
## level 0, 3-4 1, 5-6 2, 7 3), never falling and always a level there is.
func test_the_shift_lists_fit_the_run() -> void:
	var last: int = _balance.quotas.size() - 1
	for shifts: PackedInt32Array in [
		_machine.boosted_shifts, _machine.stamp_day_shifts, _machine.bonus_extra_shifts
	]:
		for shift_number: int in shifts:
			assert_int(shift_number).is_between(1, last)
	assert_array(Array(_machine.boosted_shifts)).is_equal([3, 5, 7])
	var levels: Array[int] = []
	for shift_number: int in range(1, last + 1):
		levels.append(_machine.odds_level_after(shift_number))
	assert_array(levels).is_equal([0, 0, 1, 1, 2, 2, 3])
	for index: int in _machine.shift_odds_levels.size():
		var level: int = _machine.shift_odds_levels[index]
		assert_int(level).is_between(0, _machine.max_level())
		if index > 0:
			assert_int(level).is_greater_equal(_machine.shift_odds_levels[index - 1])
	assert_array(Array(_machine.stamp_day_shifts)).is_equal([2, 4, 6])
	assert_array(Array(_machine.stamp_day_floor)).is_equal([1, 2, 3])
	assert_int(_machine.stamp_day_floor.size()).is_equal(_machine.stamp_day_shifts.size())
	for shift_number: int in _machine.stamp_day_shifts:
		assert_bool(_balance.inspection_shifts.has(shift_number)).is_false()
		assert_bool(_machine.bonus_extra_shifts.has(shift_number)).is_false()
	assert_int(_machine.stamp_floor(4)).is_equal(2)
	assert_int(_machine.stamp_floor(3)).is_equal(0)


## The UPGRADES chute upgrades the live chains: the starter's 4 (#77), then Bread, Soup and the
## 14 base aisle items (v0.48).
func test_the_machine_upgrades_the_live_chains() -> void:
	var products: Array[String] = []
	for chain: ItemUpgradeDefinition in _machine.item_upgrades:
		products.append(String(chain.product.id))
	(
		assert_array(products)
		. is_equal(
			[
				"banana",
				"milk",
				"eggs",
				"coffee",
				"bread",
				"soup",
				"cheese",
				"frozen_peas",
				"butter",
				"yogurt",
				"reduced_yogurt",
				"cereal",
				"tea_bags",
				"crackers",
				"dented_can",
				"day_old_buns",
				"carrier_bag",
				"scissors",
				"batteries",
				"flickering_bulb",
			]
		)
	)


## The machine v2 tempo (#77, Q1 = A, Q2 = 2): data/balance/machine_tempo.tres sets the camera
## glide, the receipt's travel, the stub's snap, the return glide, the reduced-motion cut and the
## bonus ticket's feed; the old flight and stub fields are gone from the file.
func test_the_machine_v2_tempo_is_set() -> void:
	var path: String = "res://data/balance/machine_tempo.tres"
	var tempo: MachineTuning = load(path) as MachineTuning
	for field: String in [
		"travel_ms",
		"glide_lead_ms",
		"glide_ms",
		"lit_ramp_ms",
		"snap_lead_ms",
		"snap_ms",
		"dock_flight_ms",
		"dock_label_ms",
		"feed_ms",
		"return_glide_ms",
		"dim_ms",
		"upgrade_after_ms",
		"rm_cut_ms",
		"rm_fade_ms",
		"bonus_to_slot_ms",
		"bonus_feed_ms",
		"bonus_stamp_land_ms",
		"confirm_down_ms",
	]:
		assert_int(int(tempo.get(field))).override_failure_message(field).is_greater(0)
	for field: String in ["tear_lift_px", "tear_tilt_deg", "feed_fit", "fore_drop_px"]:
		assert_float(float(tempo.get(field))).override_failure_message(field).is_greater(0.0)
	assert_float(tempo.rm_fade_alpha).is_equal_approx(0.85, 0.0001)
	assert_float(tempo.snap_db).is_less(0.0)
	var text: String = FileAccess.get_file_as_string(path)
	for gone: String in ["\nflight_ms", "\nflight_rm_ms", "\nstub_ms", "stub_rm_ms"]:
		assert_bool(text.contains(gone)).override_failure_message(gone).is_false()
	for gone: String in ["stub_lead_ms", "stub_flight_ms", "stub_feed_ms", "stub_feed_rm_ms"]:
		assert_bool(text.contains(gone)).override_failure_message(gone).is_false()
	# v0.50 (premium machine, R1 drop): the belt, the boxes, the restock and the old reveal's
	# spacing are gone; the premium transform and the drop are set.
	for gone: String in ["lands_ms", "belt_", "restock", "box_", "reveal_start_ms", "odds_open"]:
		assert_bool(text.contains(gone)).override_failure_message(gone).is_false()
	for field: String in ["premium_ms", "premium_rm_ms", "draw_rm_ms", "land_lead_rm_ms"]:
		assert_int(int(tempo.get(field))).override_failure_message(field).is_greater(0)


func _ids(items: Array) -> Array[String]:
	var found: Array[String] = []
	for item: Resource in items:
		found.append(String(item.get("id")))
	return found
