extends GdUnitTestSuite
## The mix highlight on the real shift screen at 1280x720 (#105 piece 3, mock-up readability v3
## section 4, option A; PlanningEffects, MixModel, ItemView, DeckView). The belt holds Eggs, Bread,
## Milk and Frozen peas; the hand baskets Soup, Cereal, Batteries, Strawberries and Coffee.
## Hovering a family glyph (a belt ticket's, the monitor's) lights that family's belt and basket
## items and greys the rest (the calm grey on the sprite and the ticket, and on the greyed belt
## items' stickers; no sticker drains, a lit item's keep their colour); one in the Cart lights the
## Cart's cells. Hovering a belt item lights what it
## works with: brackets on itself, a check on a pair that pays now, a dashed outline on a broad Food
## match, a "!" on a penalty pair, every mark on screen, inside its item's bracket box and off its
## ticket; a basket item's hover does the same in the hand and on the belt, its brackets ending at
## the rim. A picked card keeps its highlight while nothing else is hovered. In the count nothing
## lights and no hover does anything. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
const ROW_IDS: Array[String] = ["eggs", "bread", "milk", "frozen_peas"]
const HAND_IDS: Array[String] = ["soup", "cereal", "batteries", "strawberries", "coffee"]
const L := MixModel.Look

var _folder: String = ""
var _window_size: Vector2i
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_mix_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	_runner = null
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The Breakfast glyph on Milk's ticket lights Eggs, Bread, Milk, Cereal and Coffee and greys
## the rest; the monitor's glyph lights its family; hiding the tip puts every item back.
func test_a_glyph_lights_its_family_on_the_belt_and_in_the_baskets() -> void:
	var screen: ShiftScreen = await _screen()
	var tips: GlyphTips = screen._glyph_tips
	var glyph: FamilyGlyph = _glyph(_belt(screen, "milk").sticker().glyphs(), "Breakfast")
	tips.show_tip(glyph)
	assert_str(screen._effects.lit_family()).is_equal("Breakfast")
	_assert_looks(
		screen,
		{
			"eggs": L.LIT,
			"bread": L.LIT,
			"milk": L.LIT,
			"frozen_peas": L.GREY,
			"soup": L.GREY,
			"cereal": L.LIT,
			"batteries": L.GREY,
			"strawberries": L.GREY,
			"coffee": L.LIT,
		}
	)
	_assert_stickers(screen)
	tips.hide_tip()
	assert_str(screen._effects.lit_family()).is_empty()
	_assert_all_plain(screen)
	# The monitor's glyph (belt slot 1's item, Eggs): its family lights.
	var shown: Array[Node] = screen._monitor.find_children("*", "FamilyGlyph", true, false)
	assert_array(shown).is_not_empty()
	var monitor_glyph: FamilyGlyph = shown[0] as FamilyGlyph
	tips.show_tip(monitor_glyph)
	assert_str(screen._effects.lit_family()).is_equal(monitor_glyph.family)
	for item: ItemView in screen.item_views():
		var in_family: bool = _tags(item).has(monitor_glyph.family)
		assert_int(item.mix_look).override_failure_message(item.card.definition.id).is_equal(
			L.LIT if in_family else L.GREY
		)
	tips.hide_tip()
	_assert_all_plain(screen)


## A glyph in the open Cart lights the Cart's cells of its family (not the counter's items).
func test_a_glyph_in_the_cart_lights_its_cells() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_deck_button_pressed()
	await get_tree().create_timer(0.4).timeout
	var view: DeckView = screen._deck_view
	var glyph: FamilyGlyph = null
	for found: Node in view.find_children("*", "FamilyGlyph", true, false):
		if (found as FamilyGlyph).is_visible_in_tree():
			glyph = found as FamilyGlyph
			break
	assert_object(glyph).is_not_null()
	screen._glyph_tips.show_tip(glyph)
	assert_str(view.mix_family).is_equal(glyph.family)
	assert_str(screen._effects.lit_family()).is_empty()
	var lit: int = 0
	for cell: DeckCell in view.cells():
		var in_family: bool = cell.item().tags().has(glyph.family)
		lit += 1 if in_family else 0
		assert_int(cell.mix_look).override_failure_message(cell.card.id).is_equal(
			L.LIT if in_family else L.GREY
		)
		var drawn: Rect2 = cell.get_global_rect()
		assert_bool(SCREEN_RECT.encloses(drawn)).override_failure_message(str(drawn)).is_true()
	assert_int(lit).is_greater(0)
	screen._glyph_tips.hide_tip()
	assert_str(view.mix_family).is_empty()
	for cell: DeckCell in view.cells():
		assert_int(cell.mix_look).is_equal(L.NONE)
	view._close()


## Hovering Eggs: its brackets, Bread checked (Eggs' ×2 lands on it now), Milk lit (it counts
## Eggs as Breakfast), Coffee lit (its next Breakfast), the Food items faint under a dashed
## outline (Eggs' "×2 next Food"), Batteries grey. Every mark is on screen, inside its item's
## bracket box and off its ticket. Eggs has #71 links, yet the lit items keep every sticker in
## colour and the greyed ones' take the calm grey, as for a glyph.
func test_hovering_a_belt_item_lights_what_it_works_with() -> void:
	var screen: ShiftScreen = await _screen()
	var eggs: ItemView = _belt(screen, "eggs")
	eggs.hovered.emit(eggs)
	_assert_looks(
		screen,
		{
			"eggs": L.SELF,
			"bread": L.NOW,
			"milk": L.LIT,
			"frozen_peas": L.FAINT,
			"soup": L.FAINT,
			"cereal": L.FAINT,
			"batteries": L.GREY,
			"strawberries": L.FAINT,
			"coffee": L.LIT,
		}
	)
	assert_int(eggs.relation).is_equal(ItemView.Relation.FOCUS)
	var frame: Rect2 = eggs.get_global_transform() * eggs.brackets()
	assert_bool(SCREEN_RECT.encloses(frame)).is_true()
	_assert_mark(_belt(screen, "bread"), L.NOW)
	_assert_mark(_belt(screen, "frozen_peas"), L.FAINT)
	_assert_mark(_hand(screen, "soup"), L.FAINT)
	_assert_stickers(screen)
	for item: ItemView in screen.item_views():
		if item.mix_look in [L.SELF, L.LIT]:
			assert_bool(item._mix_mark == null or not item._mix_mark.visible).is_true()
	screen._effects.unfocus()
	_assert_all_plain(screen)


## Hovering the Soup in its basket: its brackets round its art down to the rim, the belt's Frozen
## peas marked with the penalty "!" (Soup pays nothing beside Frozen), Eggs faint (its next Food),
## the rest grey; leaving puts it all back.
func test_hovering_a_basket_item_lights_the_belt_and_the_hand() -> void:
	var screen: ShiftScreen = await _screen()
	var soup: ItemView = _hand(screen, "soup")
	soup.hovered.emit(soup)
	_assert_looks(
		screen,
		{
			"eggs": L.FAINT,
			"bread": L.GREY,
			"milk": L.GREY,
			"frozen_peas": L.PENALTY,
			"soup": L.SELF,
			"cereal": L.GREY,
			"batteries": L.GREY,
			"strawberries": L.GREY,
			"coffee": L.GREY,
		}
	)
	assert_int(soup.relation).is_equal(ItemView.Relation.FOCUS)
	var frame: Rect2 = soup.brackets()
	assert_bool(frame.has_area()).is_true()
	assert_float(frame.end.y).is_equal(ItemView.BASKET_RIM_Y)
	assert_bool(SCREEN_RECT.encloses(soup.get_global_transform() * frame)).is_true()
	_assert_mark(_belt(screen, "frozen_peas"), L.PENALTY)
	_assert_mark(_belt(screen, "eggs"), L.FAINT)
	# A hand hover is the mix only: no ticket ring, no receipt explanation.
	assert_object(screen._effects.focused_card()).is_same(soup.card)
	assert_bool(screen._stage.planning_layer.ticket_ring().has_area()).is_false()
	soup.unhovered.emit(soup)
	await get_tree().create_timer(screen._effects.tuning.unfocus_delay_s * 2.0 + 0.05).timeout
	assert_object(screen._effects.focused_card()).is_null()
	_assert_all_plain(screen)


## A picked card (Cereal) keeps its highlight after the refresh: Milk (its pair) and Coffee lit,
## Eggs faint; hovering Bread overrides it, and leaving brings the held card's back.
func test_a_held_card_keeps_its_highlight() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_hand_card_clicked(_hand(screen, "cereal"))
	await _frames(2)
	var held: Dictionary = {
		"eggs": L.FAINT,
		"bread": L.GREY,
		"milk": L.LIT,
		"frozen_peas": L.GREY,
		"soup": L.GREY,
		"cereal": L.SELF,
		"batteries": L.GREY,
		"strawberries": L.GREY,
		"coffee": L.LIT,
	}
	_assert_looks(screen, held)
	assert_bool(_hand(screen, "cereal").selected).is_true()
	var bread: ItemView = _belt(screen, "bread")
	bread.hovered.emit(bread)
	assert_int(bread.mix_look).is_equal(L.SELF)
	assert_int(_hand(screen, "cereal").mix_look).is_not_equal(L.SELF)
	screen._effects.unfocus()
	_assert_looks(screen, held)


## In the count nothing lights: every look is off after CHECKOUT, and a glyph's or an item's hover
## does nothing.
func test_nothing_lights_in_the_count() -> void:
	var screen: ShiftScreen = await _screen()
	var eggs: ItemView = _belt(screen, "eggs")
	eggs.hovered.emit(eggs)
	screen._on_checkout_pressed()
	await _frames(2)
	_assert_all_plain(screen)
	var glyph: FamilyGlyph = _glyph(_belt(screen, "milk").sticker().glyphs(), "Breakfast")
	screen._glyph_tips.show_tip(glyph)
	assert_str(screen._effects.lit_family()).is_empty()
	var milk: ItemView = _belt(screen, "milk")
	milk.hovered.emit(milk)
	_assert_all_plain(screen)
	screen._glyph_tips.hide_tip()


## Each named item's look (belt by its card id, then the hand's), and the look's grey: a greyed
## item's sprite and ticket face take the calm grey (brightness on the stand and the ticket, the
## greyed material), a lit one's stay plain.
func _assert_looks(screen: ShiftScreen, expected: Dictionary) -> void:
	var tuning: PlanningTuning = screen._effects.tuning
	for id: String in expected:
		var item: ItemView = _belt(screen, id) if ROW_IDS.has(id) else _hand(screen, id)
		var look: MixModel.Look = expected[id] as MixModel.Look
		assert_int(item.mix_look).override_failure_message(id).is_equal(look)
		var grey: bool = MixModel.greys(look)
		var brightness: float = tuning.mix_brightness if grey else 1.0
		assert_float(item._stand.modulate.r).override_failure_message(id).is_equal_approx(
			brightness, 0.001
		)
		var plain: bool = item.sprite().material == ArtStyle.pixel_material()
		assert_bool(plain).override_failure_message(id).is_equal(not grey)
		if form_has_ticket(item):
			assert_float(item.sticker().modulate.r).is_equal_approx(brightness, 0.001)
			var face_plain: bool = item.sticker().face().material == ArtStyle.pixel_material()
			assert_bool(face_plain).override_failure_message(id).is_equal(not grey)
		var on_screen: Rect2 = item.get_global_transform() * item.hit_rect()
		assert_bool(SCREEN_RECT.encloses(on_screen)).override_failure_message(id).is_true()


## The belt's stickers by their item's look: none drained (but on a denied item), a greyed item's
## in the calm grey, a lit item's plain.
func _assert_stickers(screen: ShiftScreen) -> void:
	var layer: PlanningLayer = screen._stage.planning_layer
	var seen: Array[int] = [0, 0]
	for slot: int in range(screen._row_views.size()):
		var grey: bool = MixModel.greys((screen._row_views[slot] as ItemView).mix_look)
		var brightness: float = screen._effects.tuning.mix_brightness if grey else 1.0
		for sticker: EffectSticker in layer.stack(slot):
			var message: String = "slot %d %s" % [slot, sticker.text()]
			assert_bool(sticker.is_drained()).override_failure_message(message).is_equal(
				layer.stamp(slot) != null
			)
			assert_float(sticker.modulate.r).override_failure_message(message).is_equal_approx(
				brightness, 0.001
			)
			seen[1 if grey else 0] += 1
	assert_int(seen[0]).is_greater(0)


## Every belt and basket item plain: no look, no grey, no mark.
func _assert_all_plain(screen: ShiftScreen) -> void:
	for item: ItemView in screen.item_views():
		var id: StringName = item.card.definition.id
		assert_int(item.mix_look).override_failure_message(id).is_equal(L.NONE)
		assert_int(item.relation).override_failure_message(id).is_equal(ItemView.Relation.NONE)
		assert_float(item._stand.modulate.r).override_failure_message(id).is_equal(1.0)
		assert_bool(item._mix_mark == null or not item._mix_mark.visible).is_true()
	var layer: PlanningLayer = screen._stage.planning_layer
	for slot: int in range(screen._row_views.size()):
		for sticker: EffectSticker in layer.stack(slot):
			assert_float(sticker.modulate.r).override_failure_message(str(slot)).is_equal(1.0)


## `item`'s mark of `look`: shown, on screen, inside its bracket box and off its ticket.
func _assert_mark(item: ItemView, look: MixModel.Look) -> void:
	var id: StringName = item.card.definition.id
	assert_int(item.mix_look).override_failure_message(id).is_equal(look)
	var mark: MixMark = item._mix_mark
	assert_object(mark).override_failure_message(id).is_not_null()
	assert_bool(mark.visible).override_failure_message(id).is_true()
	var to_global: Transform2D = item.get_global_transform()
	var rect: Rect2 = to_global * mark.mark_rect()
	var box: Rect2 = to_global * item._bracket_box()
	assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message("%s %s" % [id, rect]).is_true()
	(
		assert_bool(box.encloses(rect))
		. override_failure_message("%s %s in %s" % [id, rect, box])
		. is_true()
	)
	if form_has_ticket(item):
		assert_bool(rect.intersects(item.below_rect())).override_failure_message(id).is_false()


static func form_has_ticket(item: ItemView) -> bool:
	return item.form == ItemView.Form.BELT


## A new run's screen with ROW_IDS on the belt and HAND_IDS alone in the hand (the dealt hand set
## aside), under reduced motion (the looks apply at once).
func _screen() -> ShiftScreen:
	if FileAccess.file_exists(_folder.path_join(SaveService.RUN_FILE)):
		DirAccess.remove_absolute(_folder.path_join(SaveService.RUN_FILE))
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(2)
	screen._debug.set_reduced_motion(true)
	var run: RunState = screen.run
	run.deck.restore(run.deck.cards, [], run.deck.draw_pile(), run.deck.next_instance_id())
	for id: String in HAND_IDS + ROW_IDS:
		run.debug_add_to_hand(load("%s/%s.tres" % [CARDS, id]) as CardDefinition)
	for card: CardInstance in run.hand().slice(HAND_IDS.size()):
		run.place(card, run.row.size())
	screen._refresh()
	await _frames(3)
	assert_int(run.row.size()).is_equal(ROW_IDS.size())
	return screen


static func _belt(screen: ShiftScreen, id: String) -> ItemView:
	for view: CardView in screen._row_views:
		if view.card.definition.id == StringName(id):
			return view as ItemView
	return null


static func _hand(screen: ShiftScreen, id: String) -> ItemView:
	for control: Control in screen._hand_box.cards():
		var item: ItemView = control as ItemView
		if item != null and item.card.definition.id == StringName(id):
			return item
	return null


## The tags the highlight reads: a belt item's scored ones, a basket item's printed ones.
static func _tags(item: ItemView) -> PackedStringArray:
	return item.tags() if item.form == ItemView.Form.BELT else item.card.definition.tags


static func _glyph(glyphs: Array[FamilyGlyph], family: String) -> FamilyGlyph:
	for glyph: FamilyGlyph in glyphs:
		if glyph.family == family:
			return glyph
	return null


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
