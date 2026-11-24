extends GdUnitTestSuite
## A maxed perk's gilded box (alpha feedback v1.48, mock-up maxed_perk.html A): its light
## (GildedSweep) and every maxed perk's gilded icon. The reach on the loyalty card is in
## upgrade_ui_test.

const UPGRADES := "res://data/upgrades"


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


## The gilded box's light sweeps for SWEEP_LENGTH every SWEEP_PERIOD; reduced motion keeps the box
## still: no wipe, no sweep.
func test_the_gilded_light_sweeps_and_stays_still_under_reduced_motion() -> void:
	var lv2: UpgradeDefinition = load(UPGRADES.path_join("coupon_engine_lv2.tres"))
	var lv3: UpgradeDefinition = load(UPGRADES.path_join("coupon_engine_lv3.tres"))
	var light: GildedSweep = GildedSweep.new(LoyaltyCard.BOX_SIZE)
	light._clock = 0.1
	assert_bool(light.is_sweeping()).is_true()
	light._clock = GildedSweep.SWEEP_LENGTH + 0.1
	assert_bool(light.is_sweeping()).is_false()
	light._clock = GildedSweep.SWEEP_PERIOD + 0.1
	assert_bool(light.is_sweeping()).is_true()
	light.free()
	var card: LoyaltyCard = LoyaltyCard.new()
	card.reduced_motion = func() -> bool: return true
	add_child(card)
	var single: Array[UpgradeDefinition] = [lv2]
	card.show_upgrades(1, single)
	var maxed: Array[UpgradeDefinition] = [lv3]
	card.show_upgrades(1, maxed)
	var still: GildedSweep = LoyaltyCard.gilded_sweep(card.box(0))
	assert_bool(still.is_reaching()).is_false()
	assert_bool(still.has_old_face()).is_false()
	still._clock = 0.1
	await _frames(2)
	assert_bool(still._drawn).is_false()
	card.queue_free()


## Every perk that can reach the top level has a gilded icon (art/perks_gilded/, pixel_art.py's
## perk map) that its maxed box shows on both faces.
func test_every_maxed_perk_has_a_gilded_icon() -> void:
	var checked: int = 0
	for file: String in DirAccess.get_files_at(UPGRADES):
		if not file.ends_with(".tres"):
			continue
		var upgrade: UpgradeDefinition = load(UPGRADES.path_join(file))
		if not LoyaltyCard.is_maxed(upgrade):
			continue
		checked += 1
		var path: String = LoyaltyCard.gilded_icon_path(upgrade.icon_ref)
		assert_bool(ResourceLoader.exists(path)).override_failure_message(file).is_true()
		for chip: bool in [true, false]:
			var icon: Texture2D = LoyaltyCard.face_icon(upgrade, chip)
			assert_object(icon).override_failure_message(file).is_not_null()
			assert_str(icon.resource_path).override_failure_message(file).is_equal(path)
	assert_int(checked).is_greater(0)


## Another perk's maxed box moving into a box that held a lower perk doesn't reach max: only
## the same perk levelling up in its box does.
func test_only_the_same_perk_reaches_max() -> void:
	var lv2: UpgradeDefinition = load(UPGRADES.path_join("coupon_engine_lv2.tres"))
	var other: UpgradeDefinition = load(UPGRADES.path_join("bulk_deal_lv3.tres"))
	var card: LoyaltyCard = LoyaltyCard.new()
	add_child(card)
	var single: Array[UpgradeDefinition] = [lv2]
	card.show_upgrades(1, single)
	var moved: Array[UpgradeDefinition] = [other]
	card.show_upgrades(1, moved)
	var light: GildedSweep = LoyaltyCard.gilded_sweep(card.box(0))
	assert_object(light).is_not_null()
	assert_bool(light.is_reaching()).is_false()
	assert_bool(light.has_old_face()).is_false()
	card.queue_free()
	await _frames(2)
