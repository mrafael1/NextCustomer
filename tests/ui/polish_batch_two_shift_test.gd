extends GdUnitTestSuite
## Polish audit batch 2 (2026-11-14), the shift group: the pending medal's PROJECTED digits over a
## light shadow and the over line off the paper's edge; the PREMIUM announce shades the monitor's
## planning content; the time card's event names and banner values a step darker; the gauge's
## empty socket on the band while the count runs and PAID clear of the margin words; the cart's
## keys in caps and a perk's type not repeating its name; the handbook over the shift shades the
## top bar and takes Esc, Enter and Space first. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const BULK_DEAL := "res://data/upgrades/bulk_deal.tres"
const DAIRY_REGULARS := "res://data/upgrades/dairy_regulars.tres"

var _folder: String = ""
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_polish_two_shift_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	get_tree().paused = false
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The pending medal's PROJECTED digits stand over a shadow lighter than their body (no stripes at
## 720p), and the line against the target keeps OVER_INSET_RIGHT off the paper's edge.
func test_the_pending_medal_reads_crisp_and_the_over_line_is_padded() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, 300)
	add_child(receipt)
	var target: ReceiptTarget = receipt.target
	target.show_quota(65)
	target.show_planned(131, 65)
	receipt.gold.show_pending(ReceiptGold.PENDING_SILVER, true)
	await _frames(2)
	var ink: Array[Color] = target.hero_ink()
	assert_float(ink[1].get_luminance()).is_greater(ink[0].get_luminance())
	assert_float(_contrast(ink[0], Palette.PAPER)).is_greater_equal(4.5)
	var over: Rect2 = target.over_row.get_rect()
	assert_float(over.end.x).is_less_equal(target.size.x - ReceiptTarget.OVER_INSET_RIGHT)
	var words: Rect2 = target.over.get_global_rect()
	assert_bool(target.get_global_rect().encloses(words)).is_true()


## The PREMIUM announce (here shift 4's payday): while its slip is on the monitor a shade covers
## the monitor's screen under it (nearly opaque once the print starts), and it is gone with the
## slip.
func test_the_premium_announce_shades_the_monitor() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(4)
	await _frames(3)
	var announce: PremiumAnnounce = screen._machine.announce
	assert_bool(announce.is_shown()).is_true()
	announce._process(PremiumAnnounce.PRINT_FROM + 0.3)
	await _frames(1)
	assert_float(announce.shade_alpha()).is_greater_equal(0.99)
	var clip: Control = announce.get_node("BurstClip") as Control
	var shade: Control = clip.get_node("Shade") as Control
	var mine: Transform2D = announce.get_global_transform()
	var screen_rect: Rect2 = mine * announce.monitor_screen()
	(
		assert_bool(shade.get_global_rect().grow(1.0).encloses(screen_rect))
		. override_failure_message("%s vs %s" % [shade.get_global_rect(), screen_rect])
		. is_true()
	)
	assert_bool(shade.get_index() < clip.get_node("Burst").get_index()).is_true()
	announce._process(PremiumAnnounce.FLY_TO + 1.0)
	await _frames(1)
	assert_float(announce.shade_alpha()).is_equal(0.0)


## The time card's day events: their names a step darker than their rim, 4.5:1 or more on their
## fill; the banner's gain and harm values in the darker banner inks.
func test_the_time_card_names_read() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(5)
	await _frames(2)
	var card: WeekCard = screen._week.card
	card.reopen(WeekCardModel.of(screen.run), null, true)
	await _frames(3)
	var names: int = 0
	for row: Control in card.rows():
		for found: Node in row.find_children("Name", "Label", true, false):
			var label: Label = found as Label
			var ink: Color = label.get_theme_color("font_color")
			if ink != WeekCard.BOON_NAME_INK and ink != WeekCard.HARM_NAME_INK:
				continue
			names += 1
			var panel: PanelContainer = (
				label.get_parent().get_parent().get_parent() as PanelContainer
			)
			var fill: Color = (panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color
			(
				assert_float(_contrast(ink, fill))
				. override_failure_message(label.text)
				. is_greater_equal(4.5)
			)
	assert_int(names).is_greater(0)
	var effect: RichTextLabel = card.banner().find_child("Effect", true, false) as RichTextLabel
	if effect.visible:
		(
			assert_bool(
				(
					effect.text.contains(WeekCard.BANNER_GAIN_INK.to_html(false))
					or effect.text.contains(WeekCard.BANNER_HARM_INK.to_html(false))
				)
			)
			. is_true()
		)
	assert_float(WeekCard.UPCOMING_ALPHA).is_greater(WeekCard.PAST_ALPHA)


## While the gauge is up out of the bar for the count its socket shows on the band where it rests
## (inside the bar's gauge room, under the bezel's span); in planning the gauge stands over it.
## The receipt's PAID lands STAMP_GAP clear of the margin words.
func test_the_count_keeps_a_socket_and_paid_clear() -> void:
	var screen: ShiftScreen = await _screen()
	var bar: TopBar = screen._top_bar as TopBar
	var gauge: GaugePanel = bar.gauge_panel
	var socket: GaugeSocket = bar.gauge_socket
	assert_bool(socket.get_index() < gauge.get_index()).is_true()
	assert_object(socket.get_parent()).is_same(gauge.get_parent())
	gauge.hide_gauge(false)
	await _frames(2)
	assert_bool(socket.is_visible_in_tree()).is_true()
	var room: Rect2 = (socket.get_parent() as Control).get_global_rect()
	var recess: Rect2 = socket.get_global_transform() * socket.recess_rect()
	assert_bool(recess.has_area()).is_true()
	assert_bool(room.grow(1.0).encloses(recess)).override_failure_message(str(recess)).is_true()
	gauge.show_gauge(false)
	await _frames(2)
	var bezel: Rect2 = gauge.get_global_transform() * gauge.bezel_rect()
	assert_float(recess.end.x).is_equal_approx(bezel.end.x, 1.0)
	assert_float(recess.position.y).is_equal_approx(bezel.position.y, 1.0)
	assert_float(recess.end.y).is_equal_approx(bezel.end.y, 1.0)

	var receipt: ReceiptView = auto_free(ReceiptView.new())
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, 300)
	add_child(receipt)
	var target: ReceiptTarget = receipt.target
	target.show_quota(24)
	target.show_planned(24, 24)
	target.begin_count(0)
	target.show_running(24)
	var row: HBoxContainer = target.show_margin_words(ShiftMargin.of(24, 24))
	ReceiptStamps.stamp_paid(row)
	await _frames(3)
	var font: Font = target.over.get_theme_font("font")
	var font_size: int = target.over.get_theme_font_size("font_size")
	var words: float = (
		font.get_string_size(target.over.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	)
	var words_end: float = target.over.position.x + target.over.size.x
	assert_float(words).is_less_equal(target.over.size.x + 1.0)
	assert_float(target.stamp.position.x - words_end).is_greater_equal(
		ReceiptTarget.STAMP_GAP - 1.0
	)


## The cart's keys in caps (CART, STOCK BOOK, CLOSE), the shown page's tab picked, not dimmed, all
## inside the screen; a perk whose type is its name says it once in its LOYALTY tip.
func test_the_cart_keys_and_perk_tips() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_deck_button_pressed()
	await _frames(3)
	var cart: DeckView = screen._deck_view
	var captions: Array[String] = []
	for tab: FramedButton in [cart._deck_tab, cart._info_tab, cart._close_button]:
		captions.append(tab.caption)
		assert_bool(screen.get_global_rect().encloses(tab.get_global_rect())).is_true()
	assert_array(captions).is_equal(["CART", "STOCK BOOK", "CLOSE"])
	for info: bool in [false, true]:
		cart.show_page(info)
		await _frames(2)
		var shown: FramedButton = cart._info_tab if info else cart._deck_tab
		assert_bool(shown.selected).is_true()
		assert_bool(shown.modulate.is_equal_approx(Color.WHITE)).is_true()
	var bulk: UpgradeDefinition = load(BULK_DEAL) as UpgradeDefinition
	assert_str(LoyaltyCard.tooltip_for(bulk).get_slice("\n", 0)).is_equal(bulk.display_name)
	var regulars: UpgradeDefinition = load(DAIRY_REGULARS) as UpgradeDefinition
	assert_str(LoyaltyCard.tooltip_for(regulars).get_slice("\n", 0)).is_equal(
		"%s (%s)" % [LoyaltyCard.perk_name(regulars), regulars.type_label()]
	)


## The handbook over the shift shades the top bar's row deeper (LOYALTY and ☰ under it) and takes
## the keys first: Enter and Space do nothing behind it, P opens no pause, Esc closes it alone
## (over the cart too, which stays open), and only then Esc opens the pause.
func test_the_handbook_over_the_shift_shades_the_bar_and_takes_the_keys() -> void:
	var screen: ShiftScreen = await _screen()
	var guide: HandbookPage = screen._pause._guide
	var bar: TopBar = screen._top_bar as TopBar
	assert_object(guide.shade_bar).is_same(bar)
	bar.guide_pressed.emit(&"")
	await _frames(2)
	assert_bool(guide.is_open()).is_true()
	var band: Rect2 = guide.get_global_transform() * guide.top_shade_rect()
	for part: Control in [bar.loyalty_card, bar.menu_button, bar.deck_button]:
		(
			assert_bool(band.grow(1.0).encloses(part.get_global_rect()))
			. override_failure_message("%s %s" % [part.name, part.get_global_rect()])
			. is_true()
		)
	var close: Rect2 = guide.close_button().get_global_rect()
	assert_bool(screen.get_global_rect().encloses(close)).is_true()
	var phase: RunState.Phase = screen.run.phase
	var row: int = screen.run.row.size()
	for keycode: Key in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER, KEY_P]:
		await _press(keycode)
		assert_bool(guide.is_open()).override_failure_message(str(keycode)).is_true()
		assert_bool(screen._pause.is_open()).override_failure_message(str(keycode)).is_false()
	assert_int(screen.run.phase).is_equal(phase)
	assert_int(screen.run.row.size()).is_equal(row)
	await _press(KEY_ESCAPE)
	assert_bool(guide.is_open()).is_false()
	assert_bool(screen._pause.is_open()).is_false()
	screen._on_deck_button_pressed()
	await _frames(2)
	guide.open_at()
	await _frames(2)
	await _press(KEY_ESCAPE)
	assert_bool(guide.is_open()).is_false()
	assert_bool(screen._deck_view.visible).is_true()
	await _press(KEY_ESCAPE)
	assert_bool(screen._deck_view.visible).is_false()
	await _press(KEY_ESCAPE)
	assert_bool(screen._pause.is_open()).is_true()


func _screen() -> ShiftScreen:
	if FileAccess.file_exists(_folder.path_join(SaveService.RUN_FILE)):
		DirAccess.remove_absolute(_folder.path_join(SaveService.RUN_FILE))
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	screen._week.skip()
	await _frames(3)
	return screen


func _press(keycode: Key) -> void:
	_runner.simulate_key_pressed(keycode)
	await _frames(3)


## The WCAG contrast ratio of two colours.
static func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(color: Color) -> float:
	var linear: Color = color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
