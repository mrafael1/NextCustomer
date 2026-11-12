extends GdUnitTestSuite
## The Family sticker on the real shift screen (v1.28, FamilyStickerFlow): on the belt it wears a
## family tag on its art's bottom left (the family it gives now, pre-filled; its glyph inside it,
## a light focus ring) and its ticket reads that family; the item after it shows the family as a
## gained glyph on its ticket. A click on the tag opens the Price gun's family picker above it, at
## 1280x720 and 1920x1080: inside the window, clear of the register column, the receipt and the
## monitor, titled with the next item, its eight chips inside the card and apart, the current
## family focused (a teal ring), the next item's own family dimmed.
## A chip picks it (the item gains it, logged and saved; the focus back on the tag); Escape closes
## with nothing changed. A sticker in the hand wears no tag. The real saves and logs are never
## touched.

const SCREEN := "res://ui/shift_screen.tscn"
const STICKER := "res://data/cards/family_sticker.tres"
const POTATOES := "res://data/cards/potatoes.tres"
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The tag, the gained glyph and the picker's layout in both windows; a chip picks.
func test_the_picker_opens_over_the_sticker_and_picks(
	window: Vector2i, _test_parameters := [[WINDOWS[0]], [WINDOWS[1]]]
) -> void:
	get_tree().root.size = window
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var cards: Array[CardInstance] = await _belt(screen)
	var sticker: CardInstance = cards[0]
	var view: ItemView = screen._row_views[0]
	var tag: Button = FamilyStickerFlow.tag_of(view)
	assert_object(tag).is_not_null()
	assert_bool(tag.is_visible_in_tree()).is_true()
	assert_int(tag.focus_mode).is_equal(Control.FOCUS_ALL)
	var window_rect: Rect2 = screen.get_viewport_rect()
	assert_bool(window_rect.encloses(tag.get_global_rect())).is_true()
	# On the sticker's art, a little out over its bottom left corner at most: its left half, clear
	# of the sticker stack on the art's right; its glyph inside it; a light focus ring.
	var art: Rect2 = view.sprite().get_global_rect()
	var tag_rect: Rect2 = tag.get_global_rect()
	assert_bool(art.grow(12.0).encloses(tag_rect)).is_true()
	assert_float(tag_rect.get_center().x).is_less(art.get_center().x)
	var glyph: FamilyGlyph = tag.find_children("*", "FamilyGlyph", true, false)[0] as FamilyGlyph
	var glyph_rect: Rect2 = glyph.get_global_rect()
	assert_bool(tag_rect.encloses(glyph_rect)).override_failure_message(str(glyph_rect)).is_true()
	assert_float(absf(glyph_rect.get_center().x - tag_rect.get_center().x)).is_less_equal(1.0)
	var ring: StyleBoxFlat = tag.get_theme_stylebox("focus") as StyleBoxFlat
	assert_object(ring.border_color).is_equal(FamilyStickerFlow.FOCUS_RING)
	# Pre-filled: Potatoes (Produce) gains the first family it lacks, shown on its ticket.
	var given: String = FamilySticker.given(run.preview(), 0)
	assert_str(given).is_equal("Breakfast")
	assert_str(String(tag.get_meta("family"))).is_equal(given)
	_assert_gained(screen._row_views[1], given)
	assert_str(view.sticker().summary().text).is_equal("Next joins %s" % given)
	tag.pressed.emit()
	await _frames(3)
	var picker: PriceGunPicker = screen._pins.stickers.picker()
	assert_object(picker).is_not_null()
	_assert_picker_layout(screen, picker, tag, "%s" % window)
	# Above the tag (the page's "pop above"), titled with the next item.
	assert_float(picker.card().get_global_rect().end.y).is_less(tag.get_global_rect().position.y)
	var title: Label = picker.find_child("Title", true, false) as Label
	assert_str(title.text).is_equal(FamilyStickerFlow.TITLE_ITEM % "Potatoes")
	assert_int(picker.chips().size()).is_equal(8)
	var focused: Button = picker.focused_chip()
	assert_object(focused).is_not_null()
	assert_str(String(focused.name)).is_equal("Chip%s" % given)
	var focus_ring: StyleBoxFlat = focused.get_theme_stylebox("focus") as StyleBoxFlat
	assert_object(focus_ring.border_color).is_equal(PriceGunPicker.FOCUS_RING)
	# Potatoes is Produce already: its chip dimmed, saying so; the others not.
	for chip: Button in picker.chips():
		var held: bool = chip.name == "ChipProduce"
		assert_bool(is_equal_approx(chip.modulate.a, PriceGunPicker.HELD_ALPHA)).is_equal(held)
	assert_str(_chip(picker, "Produce").tooltip_text).contains("Potatoes is Produce already")
	_chip(picker, "Snack").pressed.emit()
	await _frames(3)
	assert_object(screen._pins.stickers.picker()).is_null()
	assert_str(FamilySticker.chosen(run, sticker)).is_equal("Snack")
	assert_bool(run.preview().tags[1].has("Snack")).is_true()
	var new_tag: Button = FamilyStickerFlow.tag_of(screen._row_views[0])
	assert_str(String(new_tag.get_meta("family"))).is_equal("Snack")
	_assert_gained(screen._row_views[1], "Snack")
	assert_str(screen._row_views[0].sticker().summary().text).is_equal("Next joins Snack")
	assert_object(get_viewport().gui_get_focus_owner()).is_same(new_tag)
	assert_str(String(_last_event("family_sticker")["family"])).is_equal("Snack")
	var saved: RunSave = SaveService.new(_folder).load_run(ContentLookup.new(run.balance))
	assert_str(FamilySticker.chosen(saved.run, saved.run.row[0])).is_equal("Snack")


## Escape closes the picker with nothing changed, the focus back on the tag; a sticker taken back
## to the hand wears no tag.
func test_escape_closes_and_the_hand_has_no_tag() -> void:
	get_tree().root.size = WINDOWS[0]
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var cards: Array[CardInstance] = await _belt(screen)
	var tag: Button = FamilyStickerFlow.tag_of(screen._row_views[0])
	tag.pressed.emit()
	await _frames(2)
	var picker: PriceGunPicker = screen._pins.stickers.picker()
	var escape: InputEventAction = InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	picker._unhandled_key_input(escape)
	await _frames(2)
	assert_object(screen._pins.stickers.picker()).is_null()
	assert_dict(run.sticker_families).is_empty()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(tag)
	assert_bool(run.remove(cards[0])).is_true()
	screen._refresh()
	await _frames(2)
	for view: ItemView in screen.item_views():
		if view.card == cards[0]:
			assert_object(FamilyStickerFlow.tag_of(view)).is_null()


## The picker's card inside the window, clear of the register column, the receipt and the
## monitor, its notch by the tag; its chips inside the card and apart.
func _assert_picker_layout(
	screen: ShiftScreen, picker: PriceGunPicker, tag: Control, what: String
) -> void:
	var card: Rect2 = picker.card().get_global_rect()
	var message: String = "%s card %s" % [what, card]
	(
		assert_bool(screen.get_viewport_rect().encloses(card))
		. override_failure_message(message)
		. is_true()
	)
	var stage: Vector2 = screen._stage.get_global_rect().position
	assert_float(card.position.x).is_greater(stage.x + ShiftStage.COLUMN_RECT.end.x)
	var receipt: Rect2 = screen._receipt.get_global_rect()
	assert_bool(card.intersects(receipt)).override_failure_message(message).is_false()
	var monitor: Rect2 = screen._stage.monitor.get_global_rect()
	assert_bool(card.intersects(monitor)).override_failure_message(message).is_false()
	var target: Rect2 = tag.get_global_rect()
	var tip: Vector2 = picker.notch_tip()
	assert_float(tip.x).is_between(card.position.x, card.end.x)
	var near: float = PriceGunPicker.GAP + 0.5
	if card.position.y >= target.get_center().y:
		assert_float(tip.y - target.end.y).is_between(-0.5, near)
	else:
		assert_float(target.position.y - tip.y).is_between(-0.5, near)
	var chips: Array[Button] = picker.chips()
	for index: int in range(chips.size()):
		var rect: Rect2 = chips[index].get_global_rect()
		var chip_message: String = "%s chip %d" % [what, index]
		assert_bool(card.encloses(rect)).override_failure_message(chip_message).is_true()
		for other: int in range(index + 1, chips.size()):
			assert_bool(rect.intersects(chips[other].get_global_rect())).is_false()


## The ticket of `view` shows `family` as its gained glyph, inside the ticket.
func _assert_gained(view: ItemView, family: String) -> void:
	var glyph: FamilyGlyph = view.sticker().gained()
	assert_object(glyph).is_not_null()
	assert_str(String(glyph.name)).is_equal(PriceSticker.GAINED_NAME % family)
	assert_str(glyph.tip_text).contains("Family sticker")
	assert_bool(glyph.is_visible_in_tree()).is_true()


static func _chip(picker: PriceGunPicker, family: String) -> Button:
	for chip: Button in picker.chips():
		if chip.name == "Chip%s" % family:
			return chip
	return null


## A Family sticker then Potatoes on the belt (debug copies in the hand, placed).
func _belt(screen: ShiftScreen) -> Array[CardInstance]:
	var run: RunState = screen.run
	for card: CardInstance in run.row.duplicate():
		run.remove(card)
	var sticker: CardInstance = run.debug_add_to_hand(load(STICKER))
	var potatoes: CardInstance = run.debug_add_to_hand(load(POTATOES))
	assert_bool(run.place(sticker, 0)).is_true()
	assert_bool(run.place(potatoes, 1)).is_true()
	screen._refresh()
	await _frames(3)
	return [sticker, potatoes]


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(3)
	screen.run.start_shift()
	screen.run.inspections = []
	screen._refresh()
	await _frames(2)
	return screen


func _last_event(type: String) -> Dictionary:
	var lines: PackedStringArray = EventLogWriter.join_logs(_folder).split("\n", false)
	for index: int in range(lines.size() - 1, -1, -1):
		var event: Dictionary = JSON.parse_string(lines[index])
		if event["type"] == type:
			return event
	return {}


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
