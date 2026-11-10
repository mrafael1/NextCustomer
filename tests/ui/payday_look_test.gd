extends GdUnitTestSuite
## Payday's look on the real shift screen (the user's picks of 2026-11-10, mock-up
## docs/art/mockups/payday_day.html: ShiftStage.show_payday, PaydayTrim, ReceiptPayday,
## RegisterKey.Kind.PAYDAY). On a payday shift, and only then: a brass moulding round the monitor,
## inside the receipt well, on the register's lip and on the belt's lip and guard; PAYDAY on the
## calendar's page; the receipt's brass ribbon and foot band, with no side frame; CHECKOUT a brass
## key with an ink caption in every state. Nothing moves: every node of the stage keeps its
## normal-day rect. The next shift, and a resumed payday, are told from the run alone. Nothing
## sits on the key: the PAYDAY announce leaves no tag (premium_announce_test; a resumed payday
## shows none of it). Layout asserts on-screen geometry (memory: UI tests check layout).

const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const MILK := "res://data/cards/milk.tres"
## The live schedule's first payday and the ordinary shift after it.
const PAYDAY_SHIFT := 4
const ORDINARY_SHIFT := 5
## The brass: the mustard ramp, and the golds it must never be taken for.
const BRASS: Array[Color] = [
	Palette.MUSTARD_PALE,
	Palette.MUSTARD_LIGHT,
	Palette.MUSTARD,
	Palette.MUSTARD_DARK,
	Palette.MUSTARD_DARKEST,
]
const KEY_FRAMES: Array[String] = [
	"res://art/frames/key_payday.png",
	"res://art/frames/key_payday_lit.png",
	"res://art/frames/key_payday_off.png",
]
## A hero amount as wide as the paper takes, and an "over" as long.
const BIG_TOTAL := 98765
const BIG_QUOTA := 73

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_payday_look_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The payday's dressing moves nothing: every node of the stage has the rect it has on the same
## shift without the dressing (the receipt's own column aside: its ribbon is in it).
func test_a_payday_moves_nothing() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(3)
	var stage: ShiftStage = screen._stage
	assert_bool(stage.payday).is_true()
	var dressed: Dictionary = _rects(stage)
	stage.show_payday(false)
	await _frames(2)
	assert_bool(stage.payday).is_false()
	var plain: Dictionary = _rects(stage)
	assert_int(dressed.size()).is_greater(20)
	for path: String in plain:
		(
			assert_that(dressed.get(path))
			. override_failure_message(
				"%s: %s, on a payday %s" % [path, plain[path], dressed.get(path)]
			)
			. is_equal(plain[path])
		)
	stage.show_payday(true)
	await _frames(1)
	assert_dict(_rects(stage)).is_equal(dressed)


## The trims show on a payday only, each where its part is: round the monitor's bezel, inside the
## well, on the deck's lip, on the belt's lip and guard; all in the mustard brass, nothing
## animated (no process on them).
func test_the_brass_trims_show_on_a_payday_only() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(3)
	var stage: ShiftStage = screen._stage
	var origin: Vector2 = stage.get_global_rect().position
	assert_bool(stage.monitor.payday).is_true()
	assert_bool(stage.tower.payday_trim.is_visible_in_tree()).is_true()
	assert_bool(stage.cabinet.payday_lip.is_visible_in_tree()).is_true()
	assert_bool(stage.belt.is_payday()).is_true()
	# Round the monitor: outside its bezel, never over the top bar or the belt.
	var reach: float = PaydayTrim.reach()
	var bezel: Rect2 = ShiftStage.MONITOR_RECT
	assert_float(reach).is_equal(float((PaydayTrim.MOULDING.size() + 1) * ArtStyle.ART_SCALE))
	assert_float(bezel.position.y - reach).is_greater_equal(ShiftStage.TOP_BAR_BOTTOM)
	assert_float(bezel.end.y + reach).is_less_equal(ShiftStage.BELT_RECT.position.y + 0.5)
	# Inside the well.
	var wall: Rect2 = stage.tower.payday_trim.get_global_rect()
	assert_that(wall).is_equal(Rect2(origin + RegisterTower.PAYDAY_TRIM_RECT.position, wall.size))
	assert_that(wall.size).is_equal(RegisterTower.PAYDAY_TRIM_RECT.size)
	var well: Rect2 = Rect2(origin + ShiftStage.RECEIPT_WELL_RECT.position, Vector2.ZERO)
	well.size = ShiftStage.RECEIPT_WELL_RECT.size
	assert_bool(well.encloses(wall)).override_failure_message("%s in %s" % [wall, well]).is_true()
	# The receipt hangs inside the moulding, never on it.
	var paper: Rect2 = screen._receipt.get_global_rect()
	var inside: Rect2 = wall.grow(-PaydayTrim.MOULDING.size() * ArtStyle.ART_SCALE)
	assert_float(paper.position.x).is_greater_equal(inside.position.x)
	assert_float(paper.end.x).is_less_equal(inside.end.x)
	# On the deck's lip.
	var lip: Rect2 = stage.cabinet.payday_lip.get_global_rect()
	assert_that(lip).is_equal(Rect2(origin + RegisterCabinet.PAYDAY_LIP_RECT.position, lip.size))
	var deck: Rect2 = Rect2(origin + ShiftStage.DECK_RECT.position, ShiftStage.DECK_RECT.size)
	assert_bool(deck.encloses(lip)).override_failure_message("%s in %s" % [lip, deck]).is_true()
	assert_float(lip.end.y).is_less_equal(stage.checkout_button.get_global_rect().position.y)
	# On the belt: its lip and its guard's long steel runs, inside the belt.
	var belt: Rect2 = Rect2(Vector2.ZERO, ShiftStage.BELT_RECT.size)
	var belt_lip: Rect2 = stage.belt.payday_lip_rect()
	assert_bool(belt.encloses(belt_lip)).override_failure_message(str(belt_lip)).is_true()
	var runs: Array[Array] = stage.belt.payday_guard_runs()
	assert_int(runs.size()).is_greater(0)
	for run: Array in runs:
		assert_bool(belt.encloses(run[0] as Rect2)).override_failure_message(str(run)).is_true()
		assert_bool(BRASS.has(run[1] as Color)).override_failure_message(str(run)).is_true()
		assert_bool((run[0] as Rect2).intersects(belt_lip)).is_false()
	for colour: Color in PaydayTrim.MOULDING + PaydayTrim.LIP_ROWS + PaydayTrim.BELT_LIP_ROWS:
		assert_bool(BRASS.has(colour)).override_failure_message(str(colour)).is_true()
		assert_bool(colour.is_equal_approx(GoldPaperArt.FACE)).is_false()
	for trim: Control in [stage.tower.payday_trim, stage.cabinet.payday_lip]:
		assert_bool(trim.is_processing()).is_false()
		assert_int(trim.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	# The calendar's page reads PAYDAY on its band, inside the pad, over the day's number.
	var parts: Dictionary = screen._calendar.part_rects()
	var word: Rect2 = parts["payday"]
	var band: Rect2 = parts["payday_band"]
	assert_bool(word.has_area()).is_true()
	assert_bool(band.encloses(word)).override_failure_message("%s in %s" % [word, band]).is_true()
	assert_bool((parts["pad"] as Rect2).encloses(band)).is_true()
	assert_float(band.end.y).is_less_equal((parts["number"] as Rect2).position.y)
	assert_bool((parts["day"] as Rect2).has_area()).is_false()
	# The next shift: nothing of it.
	screen._debug.skip_to_shift(ORDINARY_SHIFT)
	await _frames(3)
	_assert_plain(screen)


## The receipt on a payday: the brass ribbon over the header and nothing beside the paper's
## text. A hero number as wide as the paper takes and its "over" line stay inside the paper,
## clear of the ribbon, of the watermark and of the foot band, in planning's stub and hanging.
func test_the_paycheck_keeps_its_numbers_clear() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(3)
	var receipt: ReceiptView = screen._receipt
	var ribbon: ReceiptPayday = receipt.payday_ribbon
	assert_bool(ribbon.visible).is_true()
	var width: float = receipt.get_global_rect().size.x
	receipt.target.show_planned(BIG_TOTAL, BIG_QUOTA)
	await _frames(3)
	_assert_numbers_clear(receipt)
	# The paper keeps its everyday width: the design adds no frame.
	assert_float(receipt.get_global_rect().size.x).is_equal(width)
	screen._stage.show_payday(false)
	ribbon.visible = false
	await _frames(2)
	assert_float(receipt.get_global_rect().size.x).is_equal(width)
	ribbon.visible = true
	await _frames(2)
	# The ribbon: brass rows and ink words; on a gold paper the darkest brass and paper words.
	assert_that(ribbon.row_colour(0)).is_equal(Palette.MUSTARD_LIGHT)
	assert_that(ribbon.row_colour(1)).is_equal(Palette.MUSTARD)
	assert_that(ribbon.row_colour(ReceiptPayday.ROWS - 1)).is_equal(Palette.MUSTARD_DARK)
	assert_that(ribbon.words_ink()).is_equal(Palette.INK)
	assert_that(ReceiptPayday.teeth_colour(false)).is_equal(Palette.MUSTARD_DARK)
	ribbon.on_gold = true
	assert_that(ribbon.row_colour(1)).is_equal(Palette.MUSTARD_DARKEST)
	assert_that(ribbon.words_ink()).is_equal(Palette.PAPER)
	assert_that(ReceiptPayday.teeth_colour(true)).is_equal(Palette.MUSTARD_DARKEST)
	assert_bool(ribbon.row_colour(1).is_equal_approx(GoldPaperArt.FACE)).is_false()
	ribbon.on_gold = false
	# A long paper: the foot band is the paper's very end, under every line of it.
	var paper: Vector2 = Vector2(width, 900.0)
	var foot: Rect2 = ReceiptPayday.foot_rect(paper)
	assert_float(foot.position.y).is_equal(paper.y - ArtStyle.ART_SCALE)
	assert_float(foot.end.y).is_equal(paper.y + ReceiptHang.TAIL_MARGIN * ArtStyle.ART_SCALE)
	assert_float(foot.position.x).is_greater(0.0)
	assert_float(foot.end.x).is_less(paper.x)
	# The watermark: under the header when there is room, none behind a stub's hero.
	var long: Rect2 = Rect2(Vector2.ZERO, paper)
	var mark: Rect2 = ReceiptPayday.watermark_rect(long, 200.0)
	assert_bool(mark.has_area()).is_true()
	assert_float(mark.position.y).is_greater_equal(200.0)
	assert_bool(long.encloses(mark)).is_true()
	assert_bool(ReceiptPayday.watermark_rect(long, paper.y - 20.0).has_area()).is_false()


## The hanging paper of a payday's count: its numbers clear of the ribbon and of the foot band
## under it, the band under every line of the paper.
func test_the_counted_paycheck_ends_in_its_foot_band() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(3)
	for _card: int in range(2):
		screen.run.place(screen.run.debug_add_to_hand(load(MILK)), screen.run.row.size())
	screen._refresh()
	await _frames(2)
	screen._on_checkout_pressed()
	var receipt: ReceiptView = screen._receipt
	for _frame: int in range(600):
		await get_tree().process_frame
		if receipt.hang != null:
			break
	assert_object(receipt.hang).is_not_null()
	assert_bool(receipt.payday_ribbon.visible).is_true()
	# The key is held through the count, still brass.
	var key: RegisterKey = screen._stage.checkout_button
	assert_bool(key.held).is_true()
	assert_str(key.frame_texture().resource_path).is_equal(KEY_FRAMES[RegisterKey.Look.OFF])
	receipt.target.show_running(BIG_TOTAL)
	await _frames(3)
	_assert_numbers_clear(receipt)
	var paper: Rect2 = receipt.get_global_rect()
	var foot: Rect2 = ReceiptPayday.foot_rect(paper.size)
	foot.position += paper.position
	for label: Control in _texts(receipt):
		var box: Rect2 = label.get_global_rect()
		(
			assert_float(box.end.y)
			. override_failure_message("%s %s on the foot band %s" % [label.name, box, foot])
			. is_less_equal(foot.position.y + 0.5)
		)
	Rush.rush(screen._count_up)
	for _frame: int in range(3000):
		if not screen._counting:
			break
		await get_tree().process_frame


## CHECKOUT on a payday: the brass key (its three frames, none with the tomato in it) with an ink
## caption, in every state and with Double checkout's caption; the same key, label and rect as on
## any day. The next shift's is the tomato key with its paper caption; a resumed payday's is brass.
func test_checkout_is_a_brass_key_on_a_payday() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(ORDINARY_SHIFT)
	await _frames(3)
	var key: RegisterKey = screen._stage.checkout_button
	var rect: Rect2 = key.get_global_rect()
	var caption: Rect2 = key.caption_label().get_global_rect()
	var words: String = key.caption
	assert_int(key.key_kind()).is_equal(RegisterKey.Kind.CHECKOUT)
	assert_that(_ink(key.caption_label())).is_equal(Palette.PAPER)
	screen._debug.skip_to_shift(PAYDAY_SHIFT)
	await _frames(3)
	assert_bool(screen._stage.cabinet.is_payday()).is_true()
	assert_int(key.key_kind()).is_equal(RegisterKey.Kind.PAYDAY)
	assert_str(key.caption).is_equal(words)
	assert_that(key.get_global_rect()).is_equal(rect)
	assert_that(key.caption_label().get_global_rect()).is_equal(caption)
	assert_that(_ink(key.caption_label())).is_equal(Palette.INK)
	assert_that(_ink(screen._stage.cabinet.checkout_arrow)).is_equal(Palette.INK)
	# Its looks: normal, lit (hover, press), off (held, disabled); each a brass frame.
	assert_str(key.frame_texture().resource_path).is_equal(KEY_FRAMES[RegisterKey.Look.NORMAL])
	key.lit = true
	assert_str(key.frame_texture().resource_path).is_equal(KEY_FRAMES[RegisterKey.Look.LIT])
	key.lit = false
	key.down = true
	assert_str(key.frame_texture().resource_path).is_equal(KEY_FRAMES[RegisterKey.Look.LIT])
	key.down = false
	key.held = true
	assert_str(key.frame_texture().resource_path).is_equal(KEY_FRAMES[RegisterKey.Look.OFF])
	assert_that(_ink(key.caption_label())).is_equal(Palette.INK)
	key.held = false
	var was_disabled: bool = key.disabled
	key.disabled = true
	assert_str(key.frame_texture().resource_path).is_equal(KEY_FRAMES[RegisterKey.Look.OFF])
	key.disabled = was_disabled
	for path: String in KEY_FRAMES:
		_assert_brass_frame(path)
	# Double checkout's caption: the same brass key and ink.
	key.show_caption("CHECKOUT 1/2")
	await _frames(1)
	assert_int(key.key_kind()).is_equal(RegisterKey.Kind.PAYDAY)
	assert_that(_ink(key.caption_label())).is_equal(Palette.INK)
	key.show_caption(words)
	# A resumed payday is dressed from the run alone.
	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.shift_index).is_equal(PAYDAY_SHIFT - 1)
	assert_bool(resumed._stage.payday).is_true()
	assert_bool(resumed._stage.monitor.payday).is_true()
	assert_bool(resumed._stage.tower.payday_trim.visible).is_true()
	assert_bool(resumed._stage.belt.is_payday()).is_true()
	assert_bool((resumed._calendar.part_rects()["payday"] as Rect2).has_area()).is_true()
	assert_bool(resumed._receipt.payday_ribbon.visible).is_true()
	var resumed_key: RegisterKey = resumed._stage.checkout_button
	assert_int(resumed_key.key_kind()).is_equal(RegisterKey.Kind.PAYDAY)
	assert_that(_ink(resumed_key.caption_label())).is_equal(Palette.INK)
	# A resumed payday shows nothing of the announce: no receipt on the monitor, no tag.
	var announce: PremiumAnnounce = resumed._machine.announce
	resumed._machine._process(0.1)
	assert_bool(announce.payday).is_true()
	assert_bool(announce.is_shown()).is_false()
	assert_bool(announce.tag_hangs()).is_false()
	# And its next shift is back to normal.
	resumed._debug.skip_to_shift(ORDINARY_SHIFT)
	await _frames(3)
	_assert_plain(resumed)
	assert_that(resumed_key.get_global_rect()).is_equal(rect)


## Nothing of payday's look shows on `screen`.
func _assert_plain(screen: ShiftScreen) -> void:
	var stage: ShiftStage = screen._stage
	assert_bool(ReceiptGoldFlow.payday(screen.run)).is_false()
	assert_bool(stage.payday).is_false()
	assert_bool(stage.monitor.payday).is_false()
	assert_bool(stage.tower.payday_trim.visible).is_false()
	assert_bool(stage.cabinet.payday_lip.visible).is_false()
	assert_bool(stage.cabinet.is_payday()).is_false()
	assert_bool(stage.belt.is_payday()).is_false()
	assert_bool(screen._receipt.payday_ribbon.visible).is_false()
	var parts: Dictionary = screen._calendar.part_rects()
	assert_bool((parts["payday"] as Rect2).has_area()).is_false()
	assert_bool((parts["day"] as Rect2).has_area()).is_true()
	var key: RegisterKey = stage.checkout_button
	assert_int(key.key_kind()).is_equal(RegisterKey.Kind.CHECKOUT)
	assert_that(_ink(key.caption_label())).is_equal(Palette.PAPER)
	assert_that(_ink(stage.cabinet.checkout_arrow)).is_equal(Palette.PAPER)
	assert_str(key.frame_texture().resource_path).contains("key_checkout")


## The target's hero number and its "over / short" line on `receipt`: inside the paper (its ink
## sides aside), under the ribbon, off the watermark.
func _assert_numbers_clear(receipt: ReceiptView) -> void:
	var paper: Rect2 = receipt.get_global_rect()
	var ribbon: Rect2 = receipt.payday_ribbon.get_global_rect()
	assert_bool(paper.encloses(ribbon)).override_failure_message(str(ribbon)).is_true()
	var frame: StyleBox = receipt.get_theme_stylebox("panel")
	var header: float = frame.get_margin(SIDE_TOP) + receipt._pinned_height()
	var mark: Rect2 = ReceiptPayday.watermark_rect(Rect2(Vector2.ZERO, paper.size), header)
	mark.position += paper.position
	var inside: Rect2 = paper.grow_individual(-ArtStyle.ART_SCALE, 0.0, -ArtStyle.ART_SCALE, 0.0)
	for text: Control in [receipt.target.hero, receipt.target.over]:
		if not text.is_visible_in_tree():
			continue
		var box: Rect2 = text.get_global_rect()
		var said: String = "%s %s; paper %s, ribbon %s" % [text.name, box, paper, ribbon]
		assert_bool(inside.encloses(box)).override_failure_message(said).is_true()
		assert_bool(box.intersects(ribbon)).override_failure_message(said).is_false()
		assert_float(box.position.y).override_failure_message(said).is_greater_equal(ribbon.end.y)
		if mark.has_area():
			assert_bool(box.intersects(mark)).override_failure_message(said).is_false()
	assert_bool(receipt.target.hero.is_visible_in_tree()).is_true()


## Every shown text of `receipt`.
func _texts(receipt: ReceiptView) -> Array[Control]:
	var texts: Array[Control] = []
	for node: Node in receipt.find_children("*", "Control", true, false):
		var control: Control = node as Control
		var worded: bool = control is Label and not (control as Label).text.strip_edges().is_empty()
		if control is PixelWords:
			worded = not (control as PixelWords).text.is_empty()
		if worded and control.is_visible_in_tree() and control.modulate.a > 0.0:
			texts.append(control)
	return texts


## A payday key frame holds the brass and no tomato.
func _assert_brass_frame(path: String) -> void:
	var image: Image = (load(path) as Texture2D).get_image()
	var brass: int = 0
	var tomato: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a < 1.0:
				continue
			if BRASS.any(func(colour: Color) -> bool: return colour.is_equal_approx(pixel)):
				brass += 1
			for red: Color in [Palette.TOMATO, Palette.TOMATO_DARK, Palette.TOMATO_LIGHT]:
				if red.is_equal_approx(pixel):
					tomato += 1
	assert_int(brass).override_failure_message(path).is_greater(image.get_width())
	assert_int(tomato).override_failure_message(path).is_equal(0)


## The global rect of every shown Control under `stage`, by its path; the receipt's own column
## (its ribbon is in it) and the payday parts aside.
func _rects(stage: ShiftStage) -> Dictionary:
	var rects: Dictionary = {}
	var receipt_path: String = str(stage.get_path_to(stage.receipt))
	for node: Node in stage.find_children("*", "Control", true, false):
		var control: Control = node as Control
		var path: String = str(stage.get_path_to(control))
		if not control.is_visible_in_tree() or path.contains("Payday"):
			continue
		if path.begins_with(receipt_path + "/"):
			continue
		rects[path] = control.get_global_rect()
	return rects


func _screen() -> ShiftScreen:
	var scene: PackedScene = load(SCREEN)
	var screen: ShiftScreen = auto_free(scene.instantiate())
	scene_runner(screen)
	await _frames(4)
	return screen


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _ink(label: Label) -> Color:
	return label.get_theme_color("font_color")


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
