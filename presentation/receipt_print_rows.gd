class_name ReceiptPrintRows
extends RefCounted
## The shift screen's receipt through the count (main scene v2, H2 of 2026-11-08: mock-up
## docs/art/mockups/main_scene_v2.html; ReceiptView.anchored): planning printed no rows, so each
## item's row prints as the count reaches it (its BASE step, or its PAYOUT when that comes first),
## in slot order under the header, at one pitch for the whole belt (ReceiptRows), wiping in over
## WIPE_STEPS steps of WIPE_STEP_SECONDS (at once under reduced motion). A row holds the item's
## mini, its name, its amount at the mark column and its mark (the fizzle icon, an inspection's
## warning: ReceiptDecor.mark). Its amount waits empty until its PAYOUT, then rolls with the
## count's reading (roll(): the reading's rise since the payout started, never past the payout),
## lifted LIFT px while it rolls and LIFT_SECONDS after, so the printed rows always add up to the
## TOTAL above them; a payout of 0 prints at once in tomato dark. Only the count's own values show
## (the PAYOUT step's value, the LED's reading): nothing is scored here. No step lines: the monitor
## tells each step. Display only.

const WIPE_STEPS := 3
const WIPE_STEP_SECONDS := 0.06
const LIFT := 2.0
const LIFT_SECONDS := 0.16
const ZERO_INK := Palette.TOMATO_DARK
const LIFT_META := &"lift_font"

var _view: ReceiptView
var _lines: VBoxContainer
var _names: PackedStringArray
var _cards: Array[CardDefinition] = []
var _pitch: float = ReceiptRows.MAX_PITCH
var _still: bool = false
## The lines before the rows (a Double checkout's row line).
var _start: int = 0
var _rows: Dictionary[int, HBoxContainer] = {}
## Each marked row's mark (a DENIED replaces a FIZZLED: ReceiptView.slot_mark's precedence).
var _marked: Dictionary[int, ReceiptView.Mark] = {}
var _pending_marks: Dictionary[int, ReceiptView.Mark] = {}
var _payouts: Dictionary[int, int] = {}
## The row whose amount rolls with the reading (-1: none), and the reading it rolls from.
var _rolling: int = -1
var _roll_from: int = 0
var _reading: int = 0


## Prints `names`' rows (with `cards`' minis) on `view`'s `lines`, at `pitch`, under the lines
## already there; `still`: no wipe (reduced motion). `reading`: the total the count starts from.
func _init(
	view: ReceiptView,
	lines: VBoxContainer,
	names: PackedStringArray,
	cards: Array[CardDefinition],
	pitch: float,
	still: bool,
	reading: int = 0
) -> void:
	_view = view
	_lines = lines
	_names = names
	_cards = cards
	_pitch = pitch
	_still = still
	_reading = reading
	_start = lines.get_child_count()


## The printed rows, in slot order.
func rows() -> Array[Control]:
	var slots: Array[int] = []
	slots.assign(_rows.keys())
	slots.sort()
	var printed: Array[Control] = []
	for slot: int in slots:
		if is_instance_valid(_rows[slot]):
			printed.append(_rows[slot])
	return printed


## `slot`'s row, or null before it printed.
func row_of(slot: int) -> HBoxContainer:
	return _rows[slot] if _rows.has(slot) and is_instance_valid(_rows[slot]) else null


## `slot`'s amount label, or null before its row printed.
func amount_of(slot: int) -> Label:
	var row: HBoxContainer = row_of(slot)
	return row.get_child(1) as Label if row != null else null


## Counts `counted` on its row: a BASE or PAYOUT prints the row (a PAYOUT starts its amount's
## roll and returns the amount label, which the count fades in); a fizzle or an inspection's
## override marks it. Returns the row (null for a step with no row).
func step(counted: ScoreStep) -> Control:
	var slot: int = counted.slot
	match counted.step_type:
		ScoreStep.StepType.BASE:
			return _print(slot)
		ScoreStep.StepType.PAYOUT:
			_print(slot)
			_pay(slot, counted.value)
			return amount_of(slot)
		ScoreStep.StepType.WASTED:
			if not counted.row_wide:
				_mark(slot, ReceiptView.Mark.FIZZLED)
		ScoreStep.StepType.PAYOUT_OVERRIDE:
			if counted.source_kind == ScoreStep.SourceKind.INSPECTION:
				_mark(slot, ReceiptView.Mark.DENIED)
	return row_of(slot)


## The count's reading is `value`: the rolling row's amount follows its rise.
func roll(value: int) -> void:
	_reading = value
	if _rolling < 0:
		return
	var payout: int = _payouts[_rolling]
	var shown: int = value - _roll_from
	shown = clampi(shown, mini(0, payout), maxi(0, payout))
	var amount: Label = amount_of(_rolling)
	if amount == null:
		return
	if amount.text.is_empty():
		_lift(amount, true)
		_view.target.bump()
	amount.text = ReceiptView.money(shown)
	if shown == payout:
		_settle(_rolling)


## Every row's amount at its payout (the total line: nothing rolls any more).
func finish() -> void:
	if _rolling >= 0:
		var amount: Label = amount_of(_rolling)
		if amount != null:
			amount.text = ReceiptView.money(_payouts[_rolling])
		_settle(_rolling)


func _pay(slot: int, payout: int) -> void:
	finish()
	_payouts[slot] = payout
	var amount: Label = amount_of(slot)
	if payout == 0:
		amount.text = ReceiptView.money(0)
		amount.add_theme_color_override("font_color", ZERO_INK)
		return
	_rolling = slot
	_roll_from = _reading


func _settle(slot: int) -> void:
	_rolling = -1
	var amount: Label = amount_of(slot)
	if amount == null:
		return
	if _still or not amount.is_inside_tree():
		_lift(amount, false)
		return
	# By weak reference: the receipt may start over (and free the row) before the timer ends.
	var held: WeakRef = weakref(amount)
	amount.get_tree().create_timer(LIFT_SECONDS, false).timeout.connect(
		func() -> void: _lift(held.get_ref() as Label, false)
	)


func _print(slot: int) -> HBoxContainer:
	if row_of(slot) != null:
		return _rows[slot]
	var item_name: String = _names[slot] if slot < _names.size() else ""
	var row: HBoxContainer = (
		_view.add_line(item_name, "", ReceiptView.LineStyle.ITEM) as HBoxContainer
	)
	var label: Label = row.get_child(0) as Label
	var card: CardDefinition = _cards[slot] if slot < _cards.size() else null
	ReceiptInk.add_item_mini(label, ReceiptInk.item_art(card))
	ReceiptRows.one_row(label)
	var height: float = _pitch - float(_lines.get_theme_constant("separation"))
	ReceiptRows.set_height(row, height)
	# Again whenever the name is laid out: its fit (ReceiptInk) may change its font size first.
	label.resized.connect(ReceiptRows.set_height.bind(row, height))
	var before: int = 0
	for other: int in _rows:
		if other < slot and is_instance_valid(_rows[other]):
			before += 1
	_lines.move_child(row, mini(_start + before, _lines.get_child_count() - 1))
	_rows[slot] = row
	if _pending_marks.has(slot):
		_mark(slot, _pending_marks[slot])
	_wipe(label)
	return row


## Marks `slot`'s row `kind` (pending until it prints). An inspection's DENIED wins over a fizzle
## whichever came first (a context pass's fizzle is counted before the slot's override), as
## ReceiptView.slot_mark decides; anything else keeps the first mark.
func _mark(slot: int, kind: ReceiptView.Mark) -> void:
	var row: HBoxContainer = row_of(slot)
	if row == null:
		if _pending_marks.get(slot, ReceiptView.Mark.NONE) != ReceiptView.Mark.DENIED:
			_pending_marks[slot] = kind
		return
	if _marked.has(slot):
		if _marked[slot] != ReceiptView.Mark.FIZZLED or kind != ReceiptView.Mark.DENIED:
			return
		var old: Node = row.get_child(1).get_node_or_null("Mark")
		if old != null:
			old.get_parent().remove_child(old)
			old.queue_free()
	_marked[slot] = kind
	ReceiptDecor.mark(row, kind)
	ReceiptRows.set_height(row, _pitch - float(_lines.get_theme_constant("separation")))


## The row's name wipes in from the left in WIPE_STEPS steps (at once when still).
func _wipe(label: Label) -> void:
	if _still or not label.is_inside_tree():
		return
	label.visible_ratio = 1.0 / WIPE_STEPS
	var tween: Tween = label.create_tween()
	for step_index: int in range(2, WIPE_STEPS + 1):
		tween.tween_interval(WIPE_STEP_SECONDS)
		tween.tween_property(label, "visible_ratio", float(step_index) / WIPE_STEPS, 0.0)


## Lifts `amount` LIFT px (`up`) or sets it down: its line's font spacing moves its glyphs up,
## its height unchanged.
static func _lift(amount: Label, up: bool) -> void:
	if amount == null or not is_instance_valid(amount):
		return
	if not up:
		if amount.has_meta(LIFT_META):
			amount.add_theme_font_override("font", amount.get_meta(LIFT_META) as Font)
			amount.remove_meta(LIFT_META)
		return
	if amount.has_meta(LIFT_META):
		return
	var font: Font = amount.get_theme_font("font")
	amount.set_meta(LIFT_META, font)
	var lifted: FontVariation = FontVariation.new()
	lifted.base_font = font
	var spaced: FontVariation = font as FontVariation
	if spaced != null:
		# The row's own spacing (ReceiptRows.set_height), moved up: the line keeps its height.
		lifted = spaced.duplicate() as FontVariation
	lifted.spacing_top -= int(LIFT)
	lifted.spacing_bottom += int(LIFT)
	amount.add_theme_font_override("font", lifted)
