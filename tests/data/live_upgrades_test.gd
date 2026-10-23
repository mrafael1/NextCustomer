extends GdUnitTestSuite
## Tests on the live data/upgrades/ files (plan section 3.8). Unlike the fixture-based upgrade
## tests, these expected values are updated when upgrade numbers are tuned.

const UPGRADE_DIR := "res://data/upgrades"
const CARDS_DIR := "res://data/cards"


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
## v0.52: Coupon engine, Slot engine and Extra coupon slot joined the earlier three), no two the
## same, so no LOYALTY ticket falls back to initials.
func test_every_pool_upgrade_has_its_own_icon() -> void:
	var balance: BalanceDefinition = load("res://data/balance/balance.tres")
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
	assert_str(_upgrade("extra_coupon_slot").icon_ref).is_equal(
		"res://art/icons/perk_extra_coupon_slot.png"
	)


static func _upgrade(id: String) -> UpgradeDefinition:
	return load("%s/%s.tres" % [UPGRADE_DIR, id])


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [CARDS_DIR, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
