extends GdUnitTestSuite
## The upgrade swap (#77 machine v2's B5) on the real shift screen: the shift after an UPGRADES
## pick, once the camera is back in the store (MachineFlow.returned, then upgrade_after_ms), each
## upgraded copy with an item on screen swaps in place: its new art, a white flash masked to its
## sprite, a gold sunburst behind it centred on the sprite, a pop to swap_pop_scale and a gold
## "BANANA › GOLDEN" tag that rises in above the sprite, holds and fades; a copy not on screen is
## skipped, and the monitor's brief still says "<Item> is <TIER> now". Reduced motion: the tag
## only, at once. Layout asserts on-screen geometry (memory: UI tests check layout). Clicks and
## times are driven directly (headless runs deliver no input).

const SCREEN := "res://ui/shift_screen.tscn"
const BANANA := "res://data/cards/banana.tres"
const MILK := "res://data/cards/milk.tres"
const EPSILON := 0.001

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_upgrade_swap_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The tag's line names the product and the new tier.
func test_the_lines_name_the_item_and_its_tier() -> void:
	var golden: CardDefinition = _step(load(BANANA), 2)
	assert_int(golden.tier).is_equal(CardDefinition.Tier.GOLDEN)
	assert_str(UpgradeSwap.tier_line(golden)).is_equal("BANANA › GOLDEN")
	var big: CardDefinition = _step(load(MILK), 1)
	assert_str(UpgradeSwap.tier_line(big)).is_equal("MILK › BIG")


## Both visits upgrading the same copy (PLAIN › BIG, then BIG › GOLDEN) make one swap from its
## first art to its last: one pair per copy, in the first pair's place, so one tag and one line.
func test_a_copy_upgraded_twice_swaps_once() -> void:
	var plain: CardDefinition = load(BANANA)
	var big: CardDefinition = _step(plain, 1)
	var golden: CardDefinition = _step(plain, 2)
	var milk: CardDefinition = load(MILK)
	var first: CardInstance = CardInstance.new(plain, 7)
	var other: CardInstance = CardInstance.new(milk, 8)
	var pairs: Array = [
		[first, CardInstance.new(big, 7)],
		[other, CardInstance.new(_step(milk, 1), 8)],
		[CardInstance.new(big, 7), CardInstance.new(golden, 7)],
	]
	var collapsed: Array = UpgradeSwap.collapse(pairs)
	assert_int(collapsed.size()).is_equal(2)
	assert_object((collapsed[0][0] as CardInstance).definition).is_same(plain)
	assert_object((collapsed[0][1] as CardInstance).definition).is_same(golden)
	assert_int((collapsed[1][1] as CardInstance).instance_id).is_equal(8)
	assert_str(UpgradeSwap.tier_line((collapsed[0][1] as CardInstance).definition)).is_equal(
		"BANANA › GOLDEN"
	)


## Back in the store after the glide, upgrade_after_ms later: the hand's Banana swaps (old art
## held until then), the off-screen Milk is skipped; the flash, sunburst, pop and tag at their
## times and places; everything cleared at the end.
func test_an_upgraded_item_on_screen_swaps_in_place() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.profile.set_reduced_motion(false)
	var banana: CardInstance = screen.run.debug_add_to_hand(load(BANANA))
	screen._refresh()
	var golden: CardDefinition = _step(banana.definition, 2)
	var milk: CardDefinition = load(MILK)
	var away: CardInstance = CardInstance.new(milk, 99999)
	var pairs: Array = [
		[banana, CardInstance.new(golden, banana.instance_id)],
		[away, CardInstance.new(_step(milk, 1), away.instance_id)],
	]
	var flow: MachineFlow = screen._machine
	flow.shown_swaps = pairs
	screen._refresh()
	var item: ItemView = _item_of(screen, banana)
	assert_object(item).is_not_null()
	UpgradeSwap.hold_old(pairs, screen.item_views())
	assert_object(item.sprite().texture).is_same(ArtStyle.item_sprite(banana.definition))
	# The glide back ends; the swap waits upgrade_after_ms (the flow's clock driven here).
	flow.set_process(false)
	flow._start_return(false)
	flow._end_return()
	assert_object(flow.swap).is_null()
	# Planning waits until the swap starts (a card moved meanwhile would swap on a new view).
	assert_bool(screen._busy()).is_true()
	var wait_s: float = flow.view.tuning.upgrade_after_ms / 1000.0
	assert_float(wait_s).is_greater(0.0)
	flow._process(wait_s - 0.01)
	assert_object(flow.swap).is_null()
	assert_bool(screen._busy()).is_true()
	flow._process(0.02)
	assert_object(flow.swap).is_not_null()
	assert_bool(screen._busy()).is_false()
	flow.set_process(true)
	var swap: UpgradeSwap = flow.swap
	assert_int(swap.count()).is_equal(1)  # The Milk has no item on screen.
	assert_object(swap.view(0)).is_same(item)
	assert_bool(swap.get_parent() == screen._overlay).is_true()
	swap.set_process(false)
	var tuning: PlanningTuning = swap.tuning
	swap.show_at(0.01)
	var sprite: TextureRect = item.sprite()
	assert_object(sprite.texture).is_same(ArtStyle.item_sprite(golden))
	var flash: TextureRect = swap.flash(0)
	assert_object(flash).is_not_null()
	assert_bool(flash.get_parent() == sprite).is_true()
	assert_vector(flash.size).is_equal(sprite.size)
	assert_float(flash.modulate.a).is_greater(0.5)
	var shine: Sunburst = swap.shine(0)
	assert_bool(shine.get_parent() == item).is_true()
	assert_int(shine.get_index()).is_equal(0)  # Behind the sprite.
	assert_float(shine.size.x).is_equal(float(tuning.swap_shine_px))
	var centre: Vector2 = sprite.get_global_rect().get_center()
	var shine_centre: Vector2 = shine.get_global_transform() * (shine.size / 2.0)
	assert_float(shine_centre.distance_to(centre)).is_less(1.5)
	# The pop's top, then the flash gone.
	swap.show_at(tuning.swap_pop_ms / 2000.0)
	assert_float(sprite.scale.x).is_equal_approx(tuning.swap_pop_scale, 0.01)
	swap.show_at(tuning.swap_flash_ms / 1000.0 + EPSILON)
	assert_bool(flash.visible).is_false()
	# The tag risen in, above the sprite, centred on it, on screen.
	var settled: float = (
		(tuning.swap_tag_delay_ms + maxi(tuning.swap_tag_in_ms, tuning.swap_tag_rise_ms)) / 1000.0
	)
	swap.show_at(settled + 0.05)
	var tag: Label = swap.tag(0)
	assert_str(tag.text).is_equal("BANANA › GOLDEN")
	assert_bool(tag.visible).is_true()
	assert_float(tag.modulate.a).is_equal(1.0)
	await _frames(1)
	var tag_rect: Rect2 = tag.get_global_rect()
	var art: Rect2 = sprite.get_global_rect()
	assert_float(tag_rect.end.y).is_less_equal(art.position.y)
	assert_float(tag_rect.get_center().x).is_equal_approx(art.get_center().x, 1.0)
	assert_bool(screen.get_viewport_rect().encloses(tag_rect)).is_true()
	var font: Font = tag.get_theme_font("font")
	var tag_size: int = tag.get_theme_font_size("font_size")
	var width: float = font.get_string_size(tag.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x
	assert_float(width).is_less_equal(tag_rect.size.x)
	# The end: the parts gone, the sprite at rest, the new art kept.
	swap.show_at(swap.length())
	assert_bool(is_instance_valid(flash) and flash.get_parent() != null).is_false()
	assert_float(sprite.scale.x).is_equal(1.0)
	assert_object(sprite.texture).is_same(ArtStyle.item_sprite(golden))
	await _frames(2)


## Reduced motion: no flash, sunburst or pop; the tag shows at once, held, then gone.
func test_reduced_motion_shows_only_the_tag() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var banana: CardInstance = screen.run.debug_add_to_hand(load(BANANA))
	screen._refresh()
	var golden: CardDefinition = _step(banana.definition, 1)
	var pairs: Array = [[banana, CardInstance.new(golden, banana.instance_id)]]
	var swap: UpgradeSwap = UpgradeSwap.new()
	screen._overlay.add_child(swap)
	swap.set_process(false)
	assert_int(swap.play(pairs, screen.item_views(), true)).is_equal(1)
	var item: ItemView = swap.view(0)
	assert_object(swap.flash(0)).is_null()
	assert_object(swap.shine(0)).is_null()
	assert_bool(swap.tag(0).visible).is_true()
	assert_float(swap.tag(0).modulate.a).is_equal(1.0)
	assert_float(item.sprite().scale.x).is_equal(1.0)
	assert_object(item.sprite().texture).is_same(ArtStyle.item_sprite(golden))
	await _frames(1)
	var tag_rect: Rect2 = swap.tag(0).get_global_rect()
	assert_float(tag_rect.end.y).is_less_equal(item.sprite().get_global_rect().position.y)
	swap.show_at(swap.tuning.swap_tag_hold_ms / 1000.0)
	assert_bool(swap.tag(0).visible).is_true()
	swap.show_at(swap.length())
	await _frames(2)


func _step(card: CardDefinition, steps: int) -> CardDefinition:
	var balance: BalanceDefinition = load("res://data/balance/balance.tres")
	return ItemUpgrades.tier_step(balance.machine.item_upgrades, card, steps)


static func _item_of(screen: ShiftScreen, card: CardInstance) -> ItemView:
	for view: ItemView in screen.item_views():
		if view.card.instance_id == card.instance_id:
			return view
	return null


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
