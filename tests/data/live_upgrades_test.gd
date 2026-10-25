extends GdUnitTestSuite
## Tests on the live data/upgrades/ files (plan section 3.8). Unlike the fixture-based upgrade
## tests, these expected values are updated when upgrade numbers are tuned.

const UPGRADE_DIR := "res://data/upgrades"
const CARDS_DIR := "res://data/cards"
const BALANCE := "res://data/balance/balance.tres"


func test_placeholder_upgrades_match_the_plan() -> void:
	var coupon_engine: UpgradeDefinition = _upgrade("coupon_engine")
	assert_int(coupon_engine.type).is_equal(UpgradeDefinition.Type.COUPON_ENGINE)
	assert_str(coupon_engine.type_label()).is_equal("Coupon Engine")
	var first_coupon: FirstCouponMultiplierRule = coupon_engine.rules[0]
	assert_int(first_coupon.factor).is_equal(2)

	var category_engine: UpgradeDefinition = _upgrade("category_engine")
	assert_int(category_engine.type).is_equal(UpgradeDefinition.Type.CATEGORY_ENGINE)
	var distinct_tags: DistinctTagBonusRule = category_engine.rules[0]
	assert_int(distinct_tags.bonus_per_tag).is_equal(3)
	assert_str(category_engine.condition_text).is_not_empty()

	var extra_redraw: UpgradeDefinition = _upgrade("extra_redraw")
	assert_int(extra_redraw.type).is_equal(UpgradeDefinition.Type.ECONOMY)
	assert_int(extra_redraw.extra_redraws).is_equal(1)
	assert_array(extra_redraw.rules).is_empty()
	# Only the Extra redraw adds redraws.
	assert_int(coupon_engine.extra_redraws + category_engine.extra_redraws).is_equal(0)


func test_live_upgrades_score_the_plan_examples() -> void:
	var coupon: Array[UpgradeDefinition] = [_upgrade("coupon_engine")]
	assert_int(Scoring.score(_row("bread,final_markdown"), coupon).total).is_equal(13)
	assert_int(Scoring.score(_row("bread,repeat"), coupon).total).is_equal(15)
	var category: Array[UpgradeDefinition] = [_upgrade("category_engine")]
	assert_int(Scoring.score(_row("bread,banana"), category).total).is_equal(19)


## Loyalty levels (#108, v0.61): Coupon engine, Category engine, Extra redraw and Slot engine go up
## to LV 3 (LV 2 and LV 3 files linked by next_level, with the LV 1 icon), each level a step up;
## Big basket and Rule bender have no levels. A level scores and sets the shift's limits like any
## perk.
func test_perk_levels_match_the_plan() -> void:
	var numbers: Dictionary[String, Array] = {
		"coupon_engine": [2, 3, 4],
		"category_engine": [3, 4, 5],
		"extra_redraw": [1, 2, 3],
		"slot_engine": [2, 3, 4],
	}
	for family: String in numbers:
		var upgrade: UpgradeDefinition = _upgrade(family)
		var found: Array = []
		while upgrade != null:
			assert_str(upgrade.icon_ref).override_failure_message(family).is_equal(
				_upgrade(family).icon_ref
			)
			found.append(_level_number(upgrade))
			assert_int(upgrade.level_number()).is_equal(found.size())
			upgrade = upgrade.next_level
		assert_array(found).override_failure_message(family).is_equal(numbers[family])
	for family: String in ["big_basket", "rule_bender"]:
		assert_object(_upgrade(family).next_level).override_failure_message(family).is_null()
	var row: String = "bread,final_markdown"
	var totals: Array[int] = []
	for id: String in ["coupon_engine", "coupon_engine_lv2", "coupon_engine_lv3"]:
		var perks: Array[UpgradeDefinition] = [_upgrade(id)]
		totals.append(Scoring.score(_row(row), perks).total)
	assert_array(totals).is_equal([13, 17, 21])
	var balance: BalanceDefinition = load(BALANCE)
	var top: Array[UpgradeDefinition] = [_upgrade("extra_redraw_lv3")]
	var limits: ShiftLimits = ShiftLimits.for_shift(balance, top, 0)
	assert_int(limits.redraws).is_equal(balance.base_redraws + 3)


## Every upgrade's icon_ref (v0.50: the perk's glyph on a LOYALTY prize ticket) names a texture
## that loads, or is empty (the ticket shows the perk's initials); Big basket's is the "+1 slot"
## ticket, Extra redraw's the redraw arrow.
func test_every_icon_ref_loads() -> void:
	var named: int = 0
	for file_name: String in DirAccess.get_files_at(UPGRADE_DIR):
		if file_name.get_extension() != "tres":
			continue
		var upgrade: UpgradeDefinition = load(UPGRADE_DIR.path_join(file_name))
		if upgrade.icon_ref.is_empty():
			continue
		named += 1
		var texture: Texture2D = load(upgrade.icon_ref) as Texture2D
		assert_object(texture).override_failure_message(file_name).is_not_null()
	assert_int(named).is_greater_equal(3)
	assert_str(_upgrade("big_basket").icon_ref).is_equal("res://art/icons/plus_slot.png")
	assert_str(_upgrade("extra_redraw").icon_ref).is_equal("res://art/icons/redraw_arrow.png")


## Every upgrade a run can be offered (balance.upgrade_pool) has its own perk icon (#59 subset,
## v0.52: Coupon engine, Slot engine and Extra coupon slot joined the earlier three; Extra coupon
## slot left in v0.56), no two the
## same, so no LOYALTY ticket falls back to initials.
func test_every_pool_upgrade_has_its_own_icon() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var icons: Dictionary[String, StringName] = {}
	for upgrade: UpgradeDefinition in balance.upgrade_pool:
		var message: String = "%s: %s" % [upgrade.id, upgrade.icon_ref]
		assert_str(upgrade.icon_ref).override_failure_message(message).is_not_empty()
		(
			assert_bool(ResourceLoader.exists(upgrade.icon_ref))
			. override_failure_message(message)
			. is_true()
		)
		assert_bool(icons.has(upgrade.icon_ref)).override_failure_message(message).is_false()
		icons[upgrade.icon_ref] = upgrade.id
	assert_int(icons.size()).is_equal(balance.upgrade_pool.size())
	assert_str(_upgrade("coupon_engine").icon_ref).is_equal(
		"res://art/icons/perk_coupon_engine.png"
	)
	assert_str(_upgrade("slot_engine").icon_ref).is_equal("res://art/icons/perk_slot_engine.png")


## Two pool upgrades' icons of the same size differ in more than a recoloured header: past their
## top HEADER_ROWS rows, at least MIN_DIFFERENT_SHARE of the pixels differ. Extra coupon slot's
## icon was once Big basket's +1 ticket with only its band recoloured, and on a LOYALTY prize the
## two sat side by side, small. Since it left (plan v0.46) no two pool icons share a size, so
## this guards the next one that does.
func test_pool_upgrade_icons_differ_past_a_header() -> void:
	const HEADER_ROWS := 3
	const MIN_DIFFERENT_SHARE := 0.15
	var balance: BalanceDefinition = load(BALANCE)
	var images: Dictionary[String, Image] = {}
	for upgrade: UpgradeDefinition in balance.upgrade_pool:
		images[upgrade.id] = (load(upgrade.icon_ref) as Texture2D).get_image()
	var ids: Array[String] = images.keys()
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var a: Image = images[ids[i]]
			var b: Image = images[ids[j]]
			if a.get_size() != b.get_size():
				continue
			var different: int = 0
			var total: int = 0
			for y: int in range(HEADER_ROWS, a.get_height()):
				for x: int in a.get_width():
					total += 1
					if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
						different += 1
			(
				assert_float(float(different) / total)
				. override_failure_message(
					"%s vs %s: %d of %d" % [ids[i], ids[j], different, total]
				)
				. is_greater_equal(MIN_DIFFERENT_SHARE)
			)


## The number a level of a perk steps up: its multiplier, its bonus per tag or its redraws.
static func _level_number(upgrade: UpgradeDefinition) -> int:
	if upgrade.rules.is_empty():
		return upgrade.extra_redraws
	var rule: UpgradeRule = upgrade.rules[0]
	if rule is DistinctTagBonusRule:
		return (rule as DistinctTagBonusRule).bonus_per_tag
	return int(rule.get("factor"))


static func _upgrade(id: String) -> UpgradeDefinition:
	return load("%s/%s.tres" % [UPGRADE_DIR, id])


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [CARDS_DIR, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
