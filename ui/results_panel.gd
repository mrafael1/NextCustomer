class_name ResultsPanel
extends PanelContainer
## The win and lose screens (plan section 2): the run's dessert, its final receipt (#61; full
## build plan 6.2 and 7.1). FinalReceipt's lines print one by one from the headline down, every
## final_line_ms (CountUpTuning); a tap (its own PressReader) prints the rest at once. The
## loyalty card is stapled to the receipt's top-right corner, beside the headline, so it covers
## no line. When the coin lines start printing, the coins clink (#62) and the music ducks for
## them (ShiftMusic.coins_printing), so both follow the print, a skipped one too. It only shows
## the run; Return to menu and Export log are reported to the shift screen. Return to menu can be
## clicked mid-print, once armed; it first prints the rest at once (a skip), so nothing keeps
## printing, nor reading presses, as the screen leaves for the title (where the TOY MACHINES
## are, #63).
##
## Behind the receipt the store closes (#56, results option 2): StoreClosed covers the whole
## window, the top bar too, its shutter down to the window's bottom edge, so the receipt no longer
## reads as the last shift's screen. It takes no
## clicks (the shift screen's shade under it does, below the top bar), so Cart and ☰ stay
## clickable. The profile's reduced motion (`reduced_motion`) shows the store closed at once.
##
## A run that reached its second week (v0.96: 16 shifts in 4 weeks) prints in two week columns
## (FinalReceipt.uses_columns): the first half of its weeks on the left, the rest on the right,
## each under its header, a tab in the week's colour (WeekCard.colour_of); the rules, the
## shortfall and the coins span both columns, and the lines print down the left column, then the
## right one, then the coins.
##
## The run's BEST line (v1.37, ReceiptHighlight: FinalReceipt's HIGHLIGHT line) prints in its
## turn, between the second rule and the coins, across the receipt: the band wipes in, the sticker
## slams down, and the coins wait for its wipe, slam and hold (CountUpTuning's final_highlight_*,
## about 0.65 s); with reduced motion it shows at once and only the hold stays. A tap prints it in
## its final state with the rest.
##
## Once the receipt has printed, the badge pins the run unlocked (pin_news, set by the shift screen
## at the run's end) come one by one under a spotlight and stack right of the receipt (PinReveal,
## over the whole window like the closed store, just in front of the panel). Return to menu, while
## a card is still to come, shows every card in its place and stays; a second press leaves.

signal menu_requested
signal export_requested

## Return to menu arms this long after the panel appears, once the mouse is up, like the
## machine's picks: the click that ended the run never leaves the results.
const ARM_MS := 350
## In caps like every pixel key (polish audit v1.36: the only lowercase pixel button).
const MENU_TEXT := "RETURN TO MENU"
const HEADLINE_SIZE := 44
const LINE_SIZE := 16
## The machine visits and the inspection under a shift's line are smaller and dim.
const DETAIL_SIZE := 13
## The column's spacing between the headline, the lines and the buttons.
const COLUMN_SEPARATION := 10
## A long run's receipt (#77: a dim line per machine visit) steps down through these until it
## fits the screen with the top bar's height free above and below it: the shift and coin lines'
## font size, the dim lines' and the column's spacing, roomiest first.
const FITS: Array[Vector3i] = [
	Vector3i(LINE_SIZE, DETAIL_SIZE, COLUMN_SEPARATION),
	Vector3i(15, 12, 6),
	Vector3i(14, 11, 4),
	Vector3i(13, 10, 2),
]
## A receipt that doesn't fit even then is built again compact (FinalReceipt.lines' `compact`, its
## inspection lines folded into the shift lines) through FITS, then COMPACT_FITS, smaller still.
## Since v0.96's week columns a won 16-shift run fits FITS in full.
const COMPACT_FITS: Array[Vector3i] = [Vector3i(12, 9, 2), Vector3i(11, 8, 0), Vector3i(10, 8, 0)]
## A week header's tab: its padding around the text, in px.
const WEEK_TAB_PADDING := Vector2i(6, 1)
## A receipt in week columns sets its lines this much tighter, top and bottom, in px (shift and
## coin lines, then the smaller dim lines): the mono font's line keeps room above its capitals
## and below its descenders that a column of 27 lines can't spare.
const WEEK_LINE_TRIM := 2
const WEEK_DETAIL_TRIM := 1
## The least gap between the closed store's CLOSED sign and the receipt, in px.
const SIGN_GAP := 4.0
## The staple across the loyalty card's top edge.
const STAPLE_SIZE := Vector2(20, 5)

## Time.get_ticks_msec() when the coin lines started printing, or -1 before that.
var coins_started_ms: int = -1
## The badge pins the run unlocked, shown by the next show_results (then cleared).
var pin_news: PinUnlockNews
## A tap printed the rest of the receipt at once.
var print_skipped: bool = false
var _tuning: CountUpTuning
var _music: MusicService
var _headline: Label
var _loyalty_card: LoyaltyCard
var _lines_box: VBoxContainer
## Every line in print order, the headline first.
var _lines: Array[Label] = []
## The index in _lines of the first coin line.
var _coin_from: int = 0
## Each line's print time, in ms from the show (index × final_line_ms, the lines after the BEST
## line later by its wipe, slam and hold).
var _print_at: PackedInt32Array = PackedInt32Array()
## The BEST line, or null.
var _highlight: ReceiptHighlight
## How many lines have printed.
var _printed: int = 0
var _print_started_ms: int = 0
var _coin_sounds: int = 0
var _coins_s: float = 0.0
var _reader: PressReader
var _menu_button: FramedButton
## EXPORT LOG, right of Return to menu (hidden in a release build).
var _export_button: FramedButton
var _column: VBoxContainer
## The FITS entry the receipt is laid out with.
var _fit: Vector3i = FITS[0]
## In week columns: the weeks of the left column (the first half), and the two columns once built.
var _left_weeks: int = 0
var _week_columns: Array[VBoxContainer] = []
## The full receipt's line count (the compact one prints fewer).
var _full_count: int = 0
## The receipt font, its lines WEEK_LINE_TRIM (dim lines WEEK_DETAIL_TRIM) tighter: a receipt
## in week columns.
var _week_font: FontVariation
var _week_detail_font: FontVariation
var _armed_ms: int = 0
var _closed: StoreClosed
var _reveal: PinReveal
## Returns the profile's reduced motion (the shift screen's), or is unset: full motion.
var _reduced_motion: Callable


## `reduced_motion` returns the profile's reduced motion (unset: full motion).
func _init(tuning: CountUpTuning = null, reduced_motion: Callable = Callable()) -> void:
	_tuning = tuning if tuning != null else load(CountUp.TUNING_PATH) as CountUpTuning
	_reduced_motion = reduced_motion
	_week_font = _trimmed_font(WEEK_LINE_TRIM)
	_week_detail_font = _trimmed_font(WEEK_DETAIL_TRIM)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.INK
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", COLUMN_SEPARATION)
	add_child(column)
	_column = column
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	column.add_child(top)
	_headline = UiKit.display_label("", HEADLINE_SIZE, false)
	_headline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_headline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_headline)
	_loyalty_card = LoyaltyCard.new()
	_loyalty_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_loyalty_card.draw.connect(_draw_staple)
	top.add_child(_loyalty_card)
	_lines_box = VBoxContainer.new()
	_lines_box.add_theme_constant_override("separation", 0)
	column.add_child(_lines_box)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	# The game's pixel buttons (#56): Return to menu in the red frame, Export log in the top bar's
	# teal (playtest builds only, PlaytestUi).
	_menu_button = UiKit.framed_button(buttons, MENU_TEXT, _on_menu_pressed, 22)
	# The export confirms itself once done (ShiftScreen).
	_export_button = UiKit.framed_button(
		buttons,
		TopBar.EXPORT_TEXT,
		func() -> void: export_requested.emit(),
		18,
		TopBar.BUTTON_FRAME,
		Vector2.ZERO,
		""
	)
	_export_button.visible = PlaytestUi.shown()
	_reader = PressReader.new()
	add_child(_reader)
	_reader.tapped.connect(func(_now_ms: int) -> void: skip_printing())
	_closed = StoreClosed.new()
	_closed.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reveal = PinReveal.new()
	_reveal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reveal.setup(self, is_printing)
	visible = false


## The closed store goes in the panel's parent (the shift screen, over the whole window), just
## behind the panel, and the pin cards just in front of it, once the parent has finished setting
## up its children.
func _ready() -> void:
	_place_closed.call_deferred()


func _place_closed() -> void:
	get_parent().add_child(_closed)
	get_parent().move_child(_closed, get_index())
	_closed.visible = visible
	get_parent().add_child(_reveal)
	get_parent().move_child(_reveal, get_index() + 1)
	_reveal.visible = visible


func _notification(what: int) -> void:
	# Freed before the closed store was placed: it would be left orphaned.
	if what == NOTIFICATION_PREDELETE and _closed != null and not _closed.is_inside_tree():
		_closed.free()
		_reveal.free()
	if what == NOTIFICATION_VISIBILITY_CHANGED and _closed != null:
		_closed.visible = visible
		_reveal.visible = visible
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and _reader != null:
		_reader.end()


func _process(_delta: float) -> void:
	if not visible:
		return
	_closed.focus = get_global_rect()
	_print_due()
	if not _menu_button.disabled or Time.get_ticks_msec() < _armed_ms:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_menu_button.disabled = false


## Shows a won or lost run: `result` is its last checkout, `coins_total` the profile's coins
## after the run, or -1 when the profile couldn't be saved. `music` ducks for the coins.
func show_results(
	run: RunState, result: ScoreResult, coins_total: int, music: MusicService = null
) -> void:
	_music = music
	var won: bool = run.phase == RunState.Phase.WON
	_headline.add_theme_color_override("font_color", Palette.GOOD if won else Palette.TOMATO)
	_loyalty_card.show_upgrades(LoyaltyCard.box_count(run), run.upgrades)
	_left_weeks = FinalReceipt.left_weeks(run)
	var columns: bool = _left_weeks > 0
	_lay_out(
		FinalReceipt.lines(run, result, coins_total, false, columns),
		FinalReceipt.lines(run, result, coins_total, true, columns)
	)
	_coin_sounds = FinalReceipt.coin_sounds(CoinPayout.for_run(run).total())
	_coins_s = 0.0
	coins_started_ms = -1
	print_skipped = false
	_menu_button.disabled = true
	_armed_ms = Time.get_ticks_msec() + ARM_MS
	UiKit.pop_in(self)
	_closed.close_store(_reduced_motion.is_valid() and bool(_reduced_motion.call()))
	_print_started_ms = Time.get_ticks_msec()
	_reader.begin()
	_print_due()
	_reveal.show_news(pin_news, _reduced_motion.is_valid() and bool(_reduced_motion.call()))
	pin_news = null


## Prints the rest of the receipt at once (a tap). The coins still clink and the music still
## ducks for them, from now.
func skip_printing() -> void:
	if not is_printing():
		return
	print_skipped = true
	_print_due()


func is_printing() -> bool:
	return visible and _printed < _lines.size()


## Seconds from the coin lines' print until one COIN_GAP after the last coin sound (0 before
## they print).
func coins_seconds() -> float:
	return _coins_s


## The closed store behind the receipt (for tests).
func store_closed() -> StoreClosed:
	return _closed


## The badge pins' unlock cards (for tests and layout checks).
func pin_reveal() -> PinReveal:
	return _reveal


## Return to menu (for tests and layout checks).
func menu_button() -> FramedButton:
	return _menu_button


func export_button() -> FramedButton:
	return _export_button


## Every line's text in print order, the headline first (for tests).
func texts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for line: Label in _lines:
		found.append(line.text)
	return found


## How many lines have printed (for tests).
func printed_count() -> int:
	return _printed


## The BEST line (ReceiptHighlight), or null for a receipt without one (for tests).
func highlight() -> ReceiptHighlight:
	return _highlight


## Each line's print time, in ms from the show (for tests).
func print_times() -> PackedInt32Array:
	return _print_at


## The index of the first coin line among texts() (for tests).
func coin_line_index() -> int:
	return _coin_from


## The week columns, left then right (empty for a receipt in one column; for tests).
func week_columns() -> Array[VBoxContainer]:
	return _week_columns


## Whether the receipt is laid out compact (for tests).
func is_compact() -> bool:
	return COMPACT_FITS.has(_fit) or texts().size() < _full_count


## While a pin's card is still to come, the press shows them all in place and stays: a player
## clicking through still sees the unlocks, and the next press leaves.
func _on_menu_pressed() -> void:
	skip_printing()
	if _reveal.is_revealing():
		_reveal.finish()
		return
	menu_requested.emit()


## Builds the lines with the roomiest FITS entry that fits the room (_room, _room_width).
func _lay_out(lines: Array[FinalReceipt.Line], compact: Array[FinalReceipt.Line]) -> void:
	_full_count = lines.size()
	for each: Array[FinalReceipt.Line] in [lines, compact]:
		var fits: Array[Vector3i] = FITS.duplicate()
		if each == compact:
			fits.append_array(COMPACT_FITS)
		for fit: Vector3i in fits:
			_fit = fit
			_column.add_theme_constant_override("separation", fit.z)
			_build_lines(each)
			var needed: Vector2 = get_combined_minimum_size()
			if needed.y <= _room() and needed.x <= _room_width():
				return


## The height the receipt may take: its parent's, less the top bar's height above and below.
func _room() -> float:
	var height: float = get_parent_area_size().y
	return height - 2.0 * ShiftStage.PANEL_TOP


## The width the centred receipt may take: its parent's, less the closed store's CLOSED sign (by
## the window's left edge) and as much again on the right, so the sign stays in view (v0.96: a
## receipt in week columns is wide).
func _room_width() -> float:
	var width: float = get_parent_area_size().x
	if _closed == null or not _closed.is_inside_tree():
		return width
	var sign_end: float = _closed.sign_rect().end.x - _closed.get_global_rect().position.x
	return width - 2.0 * (sign_end + SIGN_GAP)


func _build_lines(lines: Array[FinalReceipt.Line]) -> void:
	for child: Node in _lines_box.get_children():
		_lines_box.remove_child(child)
		child.queue_free()
	_lines = []
	_week_columns = []
	_highlight = null
	_printed = 0
	_coin_from = lines.size()
	for index: int in range(lines.size()):
		var line: FinalReceipt.Line = lines[index]
		if line.tone == FinalReceipt.Tone.HEADLINE:
			_headline.text = line.text
			_lines.append(_headline)
			continue
		if line.tone == FinalReceipt.Tone.COINS and _coin_from == lines.size():
			_coin_from = index
		var font: Font = ReceiptView.MONO_FONT
		if _left_weeks > 0:
			font = _week_detail_font if line.tone == FinalReceipt.Tone.DETAIL else _week_font
		var label: Label
		if line.tone == FinalReceipt.Tone.HIGHLIGHT:
			_highlight = ReceiptHighlight.new(line, _size(line), font)
			label = _highlight
		else:
			label = UiKit.label(line.text, _size(line), _color(line))
			label.add_theme_font_override("font", font)
		if line.tone == FinalReceipt.Tone.WEEK:
			_make_week_tab(label, line.week)
		_line_parent(line).add_child(label)
		_lines.append(label)
	# Not printed yet: hidden by alpha, so the receipt keeps its size while it prints.
	for label: Label in _lines:
		label.modulate.a = 0.0
	_print_at = _print_times()


## Each line's print time from the show: one every final_line_ms, the lines after the BEST line
## later by its wipe, slam and hold (the hold alone with reduced motion).
func _print_times() -> PackedInt32Array:
	var line_ms: int = maxi(_tuning.final_line_ms, 1)
	var extra: int = _tuning.final_highlight_hold_ms
	if not _is_reduced():
		extra += _tuning.final_highlight_wipe_ms + _tuning.final_highlight_slam_ms
	var times: PackedInt32Array = PackedInt32Array()
	var after: bool = false
	for index: int in range(_lines.size()):
		times.append(index * line_ms + (extra if after else 0))
		after = after or _lines[index] == _highlight
	return times


func _is_reduced() -> bool:
	return _reduced_motion.is_valid() and bool(_reduced_motion.call())


## Prints every line due by now: one every final_line_ms from the show, all of them once
## skipped.
func _print_due() -> void:
	var due: int = _lines.size()
	if not print_skipped:
		var elapsed: int = Time.get_ticks_msec() - _print_started_ms
		due = 0
		while due < _lines.size() and _print_at[due] <= elapsed:
			due += 1
	if print_skipped and _highlight != null:
		_highlight.finish()
	while _printed < due:
		_lines[_printed].modulate.a = 1.0
		if _lines[_printed] == _highlight and not print_skipped:
			_highlight.play(_tuning, _is_reduced())
		if _printed == _coin_from:
			_start_coins()
		_printed += 1
	if _printed >= _lines.size():
		_reader.end()


## The coin lines start printing: one `coin` per coin (capped) from the COINS line on, and the
## music ducks until one gap after the last.
func _start_coins() -> void:
	coins_started_ms = Time.get_ticks_msec()
	var delay_s: float = 0.0
	if not print_skipped:
		delay_s = (_print_at[_lines.size() - 1] - _print_at[_coin_from]) / 1000.0
	_coins_s = delay_s + _coin_sounds * FinalReceipt.COIN_GAP
	var sfx: Sfx = Sfx.find(self)
	if sfx != null:
		sfx.play_series("coin", _coin_sounds, FinalReceipt.COIN_GAP, delay_s)
	if _music != null:
		ShiftMusic.coins_printing(_music, _coins_s)


## Where `line` goes: its week's column (built at the first week line), else the receipt's box.
func _line_parent(line: FinalReceipt.Line) -> Control:
	if line.week <= 0 or _left_weeks <= 0:
		return _lines_box
	if _week_columns.is_empty():
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "WeekColumns"
		# The gap is FinalReceipt.COLUMN_GAP characters, so the rules span both columns.
		var gap: String = " ".repeat(FinalReceipt.COLUMN_GAP)
		var font_size: int = _fit.x
		var gap_px: float = (
			ReceiptView.MONO_FONT.get_string_size(gap, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
		row.add_theme_constant_override("separation", roundi(gap_px))
		_lines_box.add_child(row)
		for side: int in range(2):
			var column: VBoxContainer = VBoxContainer.new()
			column.name = "WeekColumn%d" % side
			column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			# Both halves of the receipt's width: the right column starts at its middle.
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			column.add_theme_constant_override("separation", 0)
			row.add_child(column)
			_week_columns.append(column)
	return _week_columns[0 if line.week <= _left_weeks else 1]


## The receipt font with `trim` px less room above and below its lines.
static func _trimmed_font(trim: int) -> FontVariation:
	var font: FontVariation = FontVariation.new()
	font.base_font = ReceiptView.MONO_FONT
	font.spacing_top = -trim
	font.spacing_bottom = -trim
	return font


## A week header's look: a tab in the week's colour, hugging its text.
static func _make_week_tab(label: Label, week: int) -> void:
	var tab: StyleBoxFlat = StyleBoxFlat.new()
	tab.bg_color = WeekCard.colour_of(week)
	tab.content_margin_left = WEEK_TAB_PADDING.x
	tab.content_margin_right = WEEK_TAB_PADDING.x
	tab.content_margin_top = WEEK_TAB_PADDING.y
	tab.content_margin_bottom = WEEK_TAB_PADDING.y
	label.add_theme_stylebox_override("normal", tab)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _draw_staple() -> void:
	var at: Vector2 = Vector2(_loyalty_card.size.x / 2.0 - STAPLE_SIZE.x / 2.0, -1.0)
	_loyalty_card.draw_rect(Rect2(at, STAPLE_SIZE), Palette.MUTED_INK)


func _size(line: FinalReceipt.Line) -> int:
	return _fit.y if line.tone == FinalReceipt.Tone.DETAIL else _fit.x


static func _color(line: FinalReceipt.Line) -> Color:
	match line.tone:
		FinalReceipt.Tone.RULE:
			return Palette.MUTED_INK
		FinalReceipt.Tone.SHORTFALL:
			return Palette.TOMATO
		FinalReceipt.Tone.COINS_TOTAL:
			return Palette.TEAL
		FinalReceipt.Tone.WEEK:
			return Palette.PAPER
		FinalReceipt.Tone.DETAIL:
			return Color(Palette.TOMATO if line.failed else Palette.INK, 0.55)
	return Palette.TOMATO if line.failed else Palette.INK
