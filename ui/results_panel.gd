class_name ResultsPanel
extends PanelContainer
## The win and lose screens (plan section 2): the run's dessert, its final receipt (#61; full
## build plan 6.2 and 7.1). FinalReceipt's lines print one by one from the headline down, every
## final_line_ms (CountUpTuning); a tap (its own PressReader) prints the rest at once. The
## loyalty card is stapled to the receipt's top-right corner, beside the headline, so it covers
## no line. When the coin lines start printing, the coins clink (#62) and the music ducks for
## them (ShiftMusic.coins_printing), so both follow the print, a skipped one too. It only shows
## the run; New run, Toy machines and Export log are reported to the shift screen. New run and
## Toy machines (#63: the TOY MACHINES, where coins buy capsules) can be clicked mid-print, once
## armed; Toy machines first prints the rest at once (a skip), so nothing keeps printing, nor
## reading presses, behind the full-screen machines.

signal new_run_requested
signal export_requested
signal toy_machines_requested

## New run (and Toy machines) arm this long after the panel appears, once the mouse is up, like
## the machine's picks: the click that ended the run never starts a new one.
const ARM_MS := 350
const TOY_MACHINES_TEXT := "Toy machines ›"
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
## A 12-shift run's receipt (v0.65) may not fit even then: it is built again compact
## (FinalReceipt.lines' `compact`, its inspection lines folded into the shift lines) through FITS,
## then COMPACT_FIT, smaller still.
const COMPACT_FIT := Vector3i(12, 9, 2)
## The staple across the loyalty card's top edge.
const STAPLE_SIZE := Vector2(20, 5)

## Time.get_ticks_msec() when the coin lines started printing, or -1 before that.
var coins_started_ms: int = -1
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
## How many lines have printed.
var _printed: int = 0
var _print_started_ms: int = 0
var _coin_sounds: int = 0
var _coins_s: float = 0.0
var _reader: PressReader
var _new_run_button: Button
var _toy_machines_button: Button
var _column: VBoxContainer
## The FITS entry the receipt is laid out with.
var _fit: Vector3i = FITS[0]
var _armed_ms: int = 0


func _init(tuning: CountUpTuning = null) -> void:
	_tuning = tuning if tuning != null else load(CountUp.TUNING_PATH) as CountUpTuning
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
	_headline = UiKit.label("", HEADLINE_SIZE, Palette.INK)
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
	_new_run_button = UiKit.button(buttons, "New run", func() -> void: new_run_requested.emit(), 22)
	_toy_machines_button = UiKit.button(buttons, TOY_MACHINES_TEXT, _on_toy_machines_pressed, 20)
	# The export confirms itself once done (ShiftScreen).
	UiKit.button(buttons, "Export log", func() -> void: export_requested.emit(), 18, "")
	_reader = PressReader.new()
	add_child(_reader)
	_reader.tapped.connect(func(_now_ms: int) -> void: skip_printing())
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and _reader != null:
		_reader.end()


func _process(_delta: float) -> void:
	if not visible:
		return
	_print_due()
	if not _new_run_button.disabled or Time.get_ticks_msec() < _armed_ms:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_new_run_button.disabled = false
		_toy_machines_button.disabled = false


## Shows a won or lost run: `result` is its last checkout, `coins_total` the profile's coins
## after the run, or -1 when the profile couldn't be saved. `music` ducks for the coins.
func show_results(
	run: RunState, result: ScoreResult, coins_total: int, music: MusicService = null
) -> void:
	_music = music
	var won: bool = run.phase == RunState.Phase.WON
	_headline.add_theme_color_override("font_color", Palette.GOOD if won else Palette.TOMATO)
	_loyalty_card.show_upgrades(LoyaltyCard.box_count(run), run.upgrades)
	_lay_out(
		FinalReceipt.lines(run, result, coins_total),
		FinalReceipt.lines(run, result, coins_total, true)
	)
	_coin_sounds = FinalReceipt.coin_sounds(CoinPayout.for_run(run).total())
	_coins_s = 0.0
	coins_started_ms = -1
	print_skipped = false
	_new_run_button.disabled = true
	_toy_machines_button.disabled = true
	_armed_ms = Time.get_ticks_msec() + ARM_MS
	UiKit.pop_in(self)
	_print_started_ms = Time.get_ticks_msec()
	_reader.begin()
	_print_due()


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


## New run and Toy machines (for tests and layout checks).
func new_run_button() -> Button:
	return _new_run_button


func toy_machines_button() -> Button:
	return _toy_machines_button


## Every line's text in print order, the headline first (for tests).
func texts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for line: Label in _lines:
		found.append(line.text)
	return found


## How many lines have printed (for tests).
func printed_count() -> int:
	return _printed


## The index of the first coin line among texts() (for tests).
func coin_line_index() -> int:
	return _coin_from


## Builds the lines with the roomiest FITS entry that fits the room (_room).
func _on_toy_machines_pressed() -> void:
	skip_printing()
	toy_machines_requested.emit()


func _lay_out(lines: Array[FinalReceipt.Line], compact: Array[FinalReceipt.Line]) -> void:
	for each: Array[FinalReceipt.Line] in [lines, compact]:
		var fits: Array[Vector3i] = FITS.duplicate()
		if each == compact:
			fits.append(COMPACT_FIT)
		for fit: Vector3i in fits:
			_fit = fit
			_column.add_theme_constant_override("separation", fit.z)
			_build_lines(each)
			if get_combined_minimum_size().y <= _room():
				return


## The height the receipt may take: its parent's, less the top bar's height above and below.
func _room() -> float:
	var height: float = get_parent_area_size().y
	return height - 2.0 * ShiftStage.PANEL_TOP


func _build_lines(lines: Array[FinalReceipt.Line]) -> void:
	for child: Node in _lines_box.get_children():
		_lines_box.remove_child(child)
		child.queue_free()
	_lines = []
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
		var label: Label = UiKit.label(line.text, _size(line), _color(line))
		label.add_theme_font_override("font", ReceiptView.MONO_FONT)
		_lines_box.add_child(label)
		_lines.append(label)
	# Not printed yet: hidden by alpha, so the receipt keeps its size while it prints.
	for label: Label in _lines:
		label.modulate.a = 0.0


## Prints every line due by now: one every final_line_ms from the show, all of them once
## skipped.
func _print_due() -> void:
	var due: int = _lines.size()
	if not print_skipped:
		var line_ms: int = maxi(_tuning.final_line_ms, 1)
		due = mini(due, floori(float(Time.get_ticks_msec() - _print_started_ms) / line_ms) + 1)
	while _printed < due:
		_lines[_printed].modulate.a = 1.0
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
		delay_s = (_lines.size() - 1 - _coin_from) * _tuning.final_line_ms / 1000.0
	_coins_s = delay_s + _coin_sounds * FinalReceipt.COIN_GAP
	var sfx: Sfx = Sfx.find(self)
	if sfx != null:
		sfx.play_series("coin", _coin_sounds, FinalReceipt.COIN_GAP, delay_s)
	if _music != null:
		ShiftMusic.coins_printing(_music, _coins_s)


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
		FinalReceipt.Tone.DETAIL:
			return Color(Palette.TOMATO if line.failed else Palette.INK, 0.55)
	return Palette.TOMATO if line.failed else Palette.INK
