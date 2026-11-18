extends GdUnitTestSuite
## The MORNING ZONE's print on the belt (2026-11-18, MorningBand; in place of v1.24's pins and
## chain): the row's first 3 slots (data/balance/morning_zone.tres) wear a sunrise patch each,
## joined into one band on the belt under the items, with a small MORNING label on its painted
## strip. It shows while planning for a cart that holds a card reading MORNING and hides
## otherwise and for the count; a slot holding a MORNING item lights its patch; the label is the
## MORNING keyword's tip target, and a MORNING tooltip lights the whole band. On the real shift
## screen, on-screen geometry. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
const ZONE := "res://data/balance/morning_zone.tres"
## Tea bags and Milk are MORNING items; Potatoes in slot 2 is not; Bread in slot 4 is past the
## zone. Coffee reads it from slot 5.
const ROW: Array[String] = ["tea_bags", "potatoes", "milk", "bread", "coffee"]

var _folder: String = ""
var _window_size: Vector2i
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
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


## The zone is one band over the row's first 3 cells, from the first cell (the scanner's, at the
## belt's left end: the first slot scored) to the gap after the third, on the belt behind the
## tickets, inside the screen; the patches join; nothing is printed on slot 4. A slot holding a
## MORNING item has its strip lit, the others not.
func test_the_zone_is_printed_on_the_first_slots() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ROW)
	var zone: int = (load(ZONE) as MorningZone).slots
	assert_int(zone).is_equal(3)
	var row: RowStrip = screen._row_strip
	var tiles: Array[MorningZoneTile] = MorningBand.tiles(row)
	assert_int(tiles.size()).is_equal(zone)
	var separation: float = row.box.get_theme_constant("separation")
	# Slot 1 is the leftmost cell: the scanner's, the first scored.
	assert_float(row.slots[0].get_global_rect().position.x).is_less(
		row.slots[1].get_global_rect().position.x
	)
	for index: int in range(zone):
		var tile: MorningZoneTile = tiles[index]
		assert_int(tile.slot).is_equal(index)
		assert_bool(tile.is_visible_in_tree()).is_true()
		var cell: Rect2 = row.slots[index].get_global_rect()
		var rect: Rect2 = tile.get_global_rect()
		assert_float(rect.position.x).is_equal_approx(cell.position.x - separation / 2.0, 0.5)
		assert_float(rect.end.x).is_equal_approx(cell.end.x + separation / 2.0, 0.5)
		assert_float(rect.position.y).is_equal_approx(cell.position.y + MorningZoneTile.TOP, 0.5)
		assert_float(rect.end.y).is_equal_approx(cell.position.y + MorningZoneTile.BOTTOM, 0.5)
		assert_bool(SCREEN_RECT.encloses(rect)).is_true()
		# On the belt: over the ticket on the rail, its strip in front of the item's foot.
		var ticket: Rect2 = _ticket(screen, index)
		assert_float(rect.end.y).is_less_equal(ticket.position.y)
		var strip: Rect2 = tile.strip_rect()
		assert_float(strip.size.y).is_equal_approx(MorningZoneTile.STRIP, 0.01)
		assert_float(strip.position.y).is_greater_equal(
			cell.position.y + ItemView.BELT_GROUND_Y - 0.5
		)
		# Under everything else of its cell: the cell's first child holds it.
		assert_int(tile.get_parent().get_index()).is_equal(0)
		assert_bool(tile.first).is_equal(index == 0)
		assert_bool(tile.last).is_equal(index == zone - 1)
		if index > 0:
			assert_float(rect.position.x).is_equal_approx(
				tiles[index - 1].get_global_rect().end.x, 0.5
			)
	var band: Rect2 = MorningBand.band_rect(row)
	assert_float(band.end.x).is_less_equal(row.slots[zone].get_global_rect().position.x)
	assert_float(band.position.x).is_less_equal(row.slots[0].get_global_rect().position.x)
	# Tea bags and Milk count; Potatoes does not.
	assert_array(Array(screen._effects.committed_model().mornings)).is_equal([0, 2])
	(
		assert_array(tiles.map(func(tile: MorningZoneTile) -> bool: return tile.counts()))
		. is_equal([true, false, true])
	)
	assert_that(tiles[0].strip_color()).is_equal(MorningZoneTile.STRIP_COUNTS)
	assert_that(tiles[1].strip_color()).is_equal(MorningZoneTile.STRIP_COLOR)


## The label: a sun and MORNING on the middle patch's strip, inside it, centred on its cell,
## inside the screen, clear of the tickets; one label for the zone.
func test_the_label_sits_on_the_zones_strip() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ROW)
	var row: RowStrip = screen._row_strip
	var tiles: Array[MorningZoneTile] = MorningBand.tiles(row)
	var label: MorningZoneLabel = MorningBand.label(row)
	assert_object(label).is_not_null()
	assert_bool(label.is_visible_in_tree()).is_true()
	assert_object(label.get_parent()).is_same(tiles[1].get_parent())
	assert_int(row.find_children("MorningZoneLabel", "", true, false).size()).is_equal(1)
	var rect: Rect2 = label.get_global_rect()
	var strip: Rect2 = tiles[1].strip_rect()
	(
		assert_bool(strip.grow(0.5).encloses(rect))
		. override_failure_message("%s not in %s" % [rect, strip])
		. is_true()
	)
	var cell: Rect2 = row.slots[1].get_global_rect()
	assert_float(rect.get_center().x).is_equal_approx(cell.get_center().x, 2.0)
	assert_bool(SCREEN_RECT.encloses(rect)).is_true()
	assert_str(label.text_label().text).is_equal(CardText.MORNING_WORD)
	var sun: Rect2 = label.sun().get_global_rect()
	var words: Rect2 = Rect2(
		label.text_label().get_global_position(), UiKit.pixel_text_size(label.text_label())
	)
	assert_bool(rect.grow(0.5).encloses(sun)).is_true()
	assert_float(sun.end.x).is_less_equal(words.position.x)
	assert_float(words.end.x).is_less_equal(rect.end.x + 0.5)
	for slot: int in range(ROW.size()):
		assert_bool(rect.intersects(_ticket(screen, slot))).is_false()


## The zone shows for a cart that reads MORNING, on an empty belt too (no patch lit), and not for
## a cart with no such card; the count hides it.
func test_the_zone_shows_only_for_a_cart_that_reads_morning() -> void:
	var screen: ShiftScreen = await _screen()
	var row: RowStrip = screen._row_strip
	var run: RunState = screen.run
	# A cart, hand and pile with no MORNING card.
	run.deck.restore(
		_plain(run.deck.cards),
		_plain(run.deck.hand()),
		_plain(run.deck.draw_pile()),
		run.deck.next_instance_id()
	)
	assert_int(MorningBand.zone_slots(run)).is_equal(0)
	await _place(screen, ["bread", "milk", "potatoes"])
	assert_array(MorningBand.tiles(row)).is_empty()
	assert_object(MorningBand.label(row)).is_null()
	assert_vector(MorningBand.band_rect(row).size).is_equal(Vector2.ZERO)
	# Coffee joins the hand: the zone is printed, Bread and Milk in it lit.
	screen._debug.add_card("coffee")
	await _frames(3)
	assert_int(MorningBand.zone_slots(run)).is_equal(3)
	var tiles: Array[MorningZoneTile] = MorningBand.tiles(row)
	assert_int(tiles.size()).is_equal(3)
	(
		assert_array(tiles.map(func(tile: MorningZoneTile) -> bool: return tile.counts()))
		. is_equal([false, false, false])
	)
	# No card on the belt reads MORNING yet: once Coffee stands on it, the items count.
	screen._on_hand_card_clicked(_view_for(screen, run.hand()[-1]))
	screen._on_slot_input(_left_click(), run.row.size())
	await _frames(3)
	tiles = MorningBand.tiles(row)
	(
		assert_array(tiles.map(func(tile: MorningZoneTile) -> bool: return tile.counts()))
		. is_equal([true, true, false])
	)
	# The count's start (PlanningEffects.clear) takes the print off.
	screen._effects.clear()
	await _frames(2)
	assert_array(MorningBand.tiles(row)).is_empty()


## An empty belt with a MORNING card in the hand: the zone waits on the first 3 empty slots.
func test_the_zone_waits_on_an_empty_belt() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.add_card("tea_bags")
	await _frames(3)
	var row: RowStrip = screen._row_strip
	var tiles: Array[MorningZoneTile] = MorningBand.tiles(row)
	assert_int(tiles.size()).is_equal(3)
	for tile: MorningZoneTile in tiles:
		assert_bool(tile.is_visible_in_tree()).is_true()
		assert_bool(tile.counts()).is_false()
	assert_bool(MorningBand.label(row).is_visible_in_tree()).is_true()


## The zone is the row's first 3 slots whatever the day does: under Short belt (a CLOSED cell at
## the row's end) and Spot check (slot 3 pays 0€, its item still a MORNING item), and on Big
## basket's scaled 8-slot row, where the patches follow the scaled cells.
func test_the_zone_under_day_events_and_on_a_scaled_row() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.set_inspection("spot_check")
	await _place(screen, ["coffee", "milk", "bread", "eggs"])
	var row: RowStrip = screen._row_strip
	var tiles: Array[MorningZoneTile] = MorningBand.tiles(row)
	assert_int(tiles.size()).is_equal(3)
	(
		assert_array(tiles.map(func(tile: MorningZoneTile) -> bool: return tile.counts()))
		. is_equal([true, true, true])
	)
	assert_int(screen._effects.committed_model().slots[2].payout).is_equal(0)
	# A new day event starts the shift again: an empty row.
	screen._debug.set_inspection("short_belt")
	await _frames(3)
	await _place(screen, ["coffee", "milk"])
	assert_int(row.closed.size()).is_equal(1)
	tiles = MorningBand.tiles(row)
	assert_int(tiles.size()).is_equal(3)
	assert_float(MorningBand.band_rect(row).end.x).is_less_equal(
		row.slots[3].get_global_rect().position.x
	)
	screen._debug.set_inspection("")
	screen._debug.give_upgrade("big_basket")
	await _frames(3)
	await _place(screen, ["coffee", "milk"])
	assert_int(row.slots.size()).is_equal(8)
	assert_float(row.box.scale.x).is_less(1.0)
	tiles = MorningBand.tiles(row)
	assert_int(tiles.size()).is_equal(3)
	var separation: float = row.box.get_theme_constant("separation") * row.box.scale.x
	for index: int in range(3):
		var cell: Rect2 = row.slots[index].get_global_rect()
		var rect: Rect2 = tiles[index].get_global_rect()
		assert_float(rect.position.x).is_equal_approx(cell.position.x - separation / 2.0, 0.5)
		assert_float(rect.end.x).is_equal_approx(cell.end.x + separation / 2.0, 0.5)
		assert_bool(SCREEN_RECT.encloses(rect)).is_true()
	(
		assert_bool(
			tiles[1].strip_rect().grow(0.5).encloses(MorningBand.label(row).get_global_rect())
		)
		. is_true()
	)


## The label is the MORNING keyword's own on the belt: resting on it shows MORNING's tooltip and
## lights the whole band (as a ticket's MORNING chip does), and a right-click then opens the
## handbook at MORNING.
func test_the_zone_explains_the_morning() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ROW)
	var row: RowStrip = screen._row_strip
	var tips: GlyphTips = screen._glyph_tips
	var page: HandbookPage = screen.find_child("HandbookPage", false, false) as HandbookPage
	var label: MorningZoneLabel = MorningBand.label(row)
	var at: Vector2 = label.get_global_rect().get_center()
	assert_str(label.tip_text).is_equal(GlyphText.keyword_tip(CardText.MORNING_WORD))
	assert_str(label.tip_text).contains("first %d slots" % (load(ZONE) as MorningZone).slots)
	assert_object(tips.glyph_at(at)).is_same(label)
	assert_bool(page.has_entry_for(label)).is_true()
	assert_str(page.entry_for_target(label).id).is_equal("morning")
	tips.point_at(at)
	tips.show_tip(label)
	for tile: MorningZoneTile in MorningBand.tiles(row):
		assert_bool(tile.is_hot()).is_true()
		assert_that(tile.strip_color()).is_equal(MorningZoneTile.STRIP_HOT)
	tips.hide_tip()
	for tile: MorningZoneTile in MorningBand.tiles(row):
		assert_bool(tile.is_hot()).is_false()
	# A ticket's own MORNING chip lights the band too.
	var ticket_chip: KeywordChip = _item(screen, 0).sticker().summary().keywords()[0]
	assert_str(ticket_chip.keyword).is_equal(CardText.MORNING_WORD)
	tips.show_tip(ticket_chip)
	assert_bool(MorningBand.tiles(row)[2].is_hot()).is_true()
	tips.hide_tip()
	assert_bool(MorningBand.tiles(row)[2].is_hot()).is_false()
	tips.point_at(at)
	tips.show_tip(label)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = at
	click.global_position = at
	tips._input(click)
	assert_bool(page.is_open()).is_true()
	assert_str(page.shown_entry().id).is_equal("morning")
	page.close()


## `cards` without the ones that read MORNING.
static func _plain(cards: Array[CardInstance]) -> Array[CardInstance]:
	var kept: Array[CardInstance] = []
	for card: CardInstance in cards:
		if CardMorning.zone_of([card.definition]) == null:
			kept.append(card)
	return kept


## `slot`'s ticket's global rect.
static func _ticket(screen: ShiftScreen, slot: int) -> Rect2:
	var sticker: PriceSticker = _item(screen, slot).sticker()
	return sticker.get_global_transform() * Rect2(Vector2.ZERO, sticker.size)


static func _item(screen: ShiftScreen, slot: int) -> ItemView:
	return screen._row_views[slot] as ItemView


func _screen() -> ShiftScreen:
	if FileAccess.file_exists(_folder.path_join(SaveService.RUN_FILE)):
		DirAccess.remove_absolute(_folder.path_join(SaveService.RUN_FILE))
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(2)
	return screen


func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(ids.size())
	await _frames(3)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for child: Node in screen._hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
