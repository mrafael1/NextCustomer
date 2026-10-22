class_name ReceiptView
extends PanelContainer
## The receipt: printed from a ScoreResult's payouts and steps alone, so it can never disagree
## with the score. Every money amount on it prints with cents (money(): "€3.00", "+€15.00"); the
## values stay whole euros.
##
## In planning (show_planning, #80) it is itemised: the header and a dashed rule, one line per
## belt item in scan order (its name, its payout, then its mark: a green check when its payout is
## above its base, the fizzle icon when one of its effects fizzles, the warning icon when an
## inspection denies it), a muted "5 ·····" for each open empty slot, a dashed rule, "PROJECTED
## €22.00" (against the quota: green with the met mark, or red with "short €N.00" under it), and
## the fizzle footer ("2 WASTED · hover an item", none without fizzles). The belt
## item being scanned frames its line (highlight_slot). A hovered belt item (#71) frames its line
## too, marks its targets' lines with a mustard-pale fill and the token it gives them
## (show_relations), and the footer names it (set_footer_hint: "2 WASTED · Multipack hovered").
##
## The count-up (begin_count) pre-prints the header, every item's line greyed ("Multipack
## ·····"), the dashed rule, "TOTAL •••••" and the footer "tap: skip · hold: fast". Each step
## then prints into its item's group (add_step): the BASE step fills the item's line in with its
## base amount, which it keeps; the other steps print an indented line under the item's earlier
## lines, a fizzle's in dark tomato with the fizzle icon. Every item's lines add up: its base, its
## bonus and copy lines ("+€15.00") and an override's "= €0.00" (which the item's amount is from
## then on) come to its PAYOUT step's value, or (a multiplier) the PAYOUT step closes the item
## with a small "= €3.00" line (CLOSING_TEXT, LineStyle.CLOSING), its last line; when they do, it
## prints nothing. The line just printed (or filled; the item's line when the PAYOUT step prints
## nothing) is framed (mustard-pale fill, mustard frame), and the receipt keeps it in view.
## add_total fills the TOTAL line in plainly and drops the footer and the frame; the dessert (#61)
## then prints the verdict on it, the margin (PAID on a pass), the BONUS stub (#77 machine v2,
## `stub`), the tear and the next shift's notice under it, scrolled to the newest line. A resumed
## checkout prints it all at once (show_result), through the same lines. Every line another
## source boosts (a combo, is_combo) is marked with a faint gold band, a gold bar and a diamond.
##
## On the shift screen it stands on the printer's slot and grows up (fit_up, #80): as tall as its
## lines, up to ShiftStage.RECEIPT_TOP. An indented step line hangs (#55): wrapped, it starts past
## its lead and marker on every row, and its amount sits on its last row (a fizzle's line has
## none: its mark says it, on its first row). The lines
## sit in an inset (FRAME_OUT on the left, FRAME_PAD on the right) that holds the frame, inside
## the scroll area; most lines keep B2's mark column (MARK_COLUMN) at their right end.

enum LineStyle {
	DETAIL,
	ITEM,
	CONTEXT,
	FIZZLE,
	TOTAL,
	NOTICE,
	MARGIN,
	TEAR,
	PROJECTED,
	FOOTER,
	COMBO,
	WAITING,
	CLOSING,
}

## An item line's mark in planning: none, raised (its payout is above its base), fizzled, or
## denied by an inspection; and the PROJECTED line's met (the total reaches the quota).
enum Mark { NONE, RAISED, FIZZLED, DENIED, MET }

## Monospace for the receipt (plan section 2). JetBrains Mono, SIL Open Font License.
const MONO_FONT := preload("res://fonts/JetBrainsMono-Regular.ttf")
## The TOTAL and PROJECTED amounts' font size; their captions print at CAPTION_FONT_SIZE.
const TOTAL_FONT_SIZE := 22
const CAPTION_FONT_SIZE := 15
## The verdict "€total / €quota" on the TOTAL line, smaller than the total so it fits; a long
## one (a four-digit total) shrinks down to VERDICT_MIN_FONT_SIZE to stay on the line.
const VERDICT_FONT_SIZE := 15
const VERDICT_MIN_FONT_SIZE := 10
## The step and item lines' size, and the footer's.
const LINE_FONT_SIZE := 13
const FOOTER_FONT_SIZE := 12
## The PAID stamp on a passed shift's margin line (ReceiptStamps, with INSPECTION PASSED).
const PAID_TEXT := ReceiptStamps.PAID_TEXT
## The torn edge: this pattern repeated, clipped to the receipt's width.
const TEAR_PATTERN := "/\\"
const TEAR_REPEAT := 60
## A step line's marker after its leading spaces (hang_parts()): it is printed beside the first
## row, and the wrapped rows hang under the text after it.
const HANG_MARKERS: Array[String] = ["+ ", "× "]
## The receipt's header (#75, style frame v2): the shop and the register, then the shift and how
## many items are on the belt (coupons count as items), ITEM_TEXT for just one.
const HEADER_TEXT := "NEXT CUSTOMER · REG 3"
const SHIFT_TEXT := "SHIFT %d/%d · %d ITEMS"
const ITEM_TEXT := "SHIFT %d/%d · 1 ITEM"
## The planning receipt's last line (#80: PROJECTED, never TOTAL, which only the count-up prints).
const PROJECTED_TEXT := "PROJECTED"
const TOTAL_TEXT := "TOTAL"
## The dashed rules: a dash RULE_DASH long, then a gap as long.
const RULE_DASH := 4.0
## The fizzle footer: the count (in dark tomato), then the hint (muted): where to read them, or
## the hovered item (set_footer_hint).
## The count reads EffectLink.WASTED_WORD, one or many ("1 WASTED", "2 WASTED", #45).
const FIZZLES_TEXT := "%d " + EffectLink.WASTED_WORD
const HINT_TEXT := " · %s"
const DEFAULT_HINT := "hover an item"
const HOVERED_HINT := "%s hovered"
## A projected total under the quota prints its shortfall on the footer's first row (ReceiptDecor).
const SHORT_TEXT := "short %s"
## The count-up's footer, from its start to the TOTAL line.
const COUNT_FOOTER_TEXT := "tap: skip · hold: fast"
## A line still to print: an item's name then WAITING_DOTS, an open empty slot's number then
## them, the TOTAL line's amount.
const WAITING_DOTS := "·····"
const EMPTY_SLOT_TEXT := "%d ·····"
const TOTAL_WAITING := "•••••"
## The line closing an item whose lines don't add up to its payout (add_step): "= €3.00", at
## FOOTER_FONT_SIZE in ink (LineStyle.CLOSING), with no left side.
const CLOSING_TEXT := "= "
## How a multiplier's receipt text ends in its factor ("Multipack ×3", multiplier_cause).
const FACTOR_MARK := " ×"
## A money amount on the receipt (money()).
const MONEY_TEXT := "€%d.00"
## The inset around the lines: the frame reaches FRAME_OUT past their left and FRAME_PAD past
## their right (B2: 4 px of padding, then its 2 px frame).
const FRAME_OUT := 4.0
const FRAME_PAD := 6.0
## The framed line's frame reaches this far above and below the line.
const FRAME_GROW := 1.0
## B2's mark column at a line's right end: a 6 px gap past the amount, then the 14 px mark
## (ReceiptDecor.mark). Every line keeps it but the footer, the margin, the notice and the tear
## (has_mark_column), so the dashed rules and the footer run across it. A fizzle's line has no
## amount: its column is just the mark and a 2 px gap (FIZZLE_MARK_COLUMN), with no gap before it.
const MARK_COLUMN := 20.0
const FIZZLE_MARK_COLUMN := 16.0
## A combo line: a faint gold band behind the whole line with a gold bar on its left, and the
## diamond after the bar; the line's text hangs past both (COMBO_INDENT takes the place of its
## leading spaces and its marker), so nothing sits outside the receipt's scroll area.
const COMBO_BAR := 2.0
const COMBO_ICON_RECT := Rect2(4, 3, 10, 10)
const COMBO_INDENT := 18.0
const COMBO_DIAMOND := preload("res://art/icons/combo_diamond.png")

## The gold BONUS stub line (#77 machine v2, ReceiptStamps.add_bonus_stub), or null: set, it
## prints at the receipt's foot.
var stub: ReceiptStub:
	set(value):
		stub = value
		if value != null:
			_lines.add_child(value)
			scroll_to_end()
var _lines: VBoxContainer
## Holds the lines inside the scroll area, with room for the frame and the marks; draws the frame.
var _inset: MarginContainer
var _scroll: ScrollContainer
## The last TOTAL line printed (or pre-printed), or null.
var _total_line: HBoxContainer
## The pre-printed TOTAL line's dashed rule (begin_count), or null: the step lines print above it.
var _total_rule: Control
## The footer line (fizzles in planning, the count-up's), or null.
var _footer: Control
## Each slot's item line, its last printed line and its item's name.
var _items: Dictionary[int, HBoxContainer] = {}
var _last: Dictionary[int, Control] = {}
var _item_names: Dictionary[int, String] = {}
## Each slot's printed amount so far (its base plus its bonus and copy lines, or its override's
## amount and the lines after it), and its closing line.
var _sums: Dictionary[int, int] = {}
var _closing: Dictionary[int, Control] = {}
## The framed line (the counted step's, or the scanned item's in planning), or null.
var _framed: Control
## The receipt shows planning's lines (show_planning): highlight_slot frames them.
var _planning: bool = false
## In fit-up mode (fit_up()): the bottom the receipt stands on and the highest its top may reach,
## in the parent's coordinates; -1 otherwise.
var _stand_bottom: float = -1.0
var _cap_top: float = 0.0
## A fit is queued for the end of this frame's layout.
var _fit_queued: bool = false
## Fit-up mode: the next layout of the lines scrolls to their end, in the same frame.
var _snap_to_end: bool = false


func _init() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	style.content_margin_left = 12 - FRAME_OUT
	style.content_margin_right = 12 - FRAME_OUT
	add_theme_stylebox_override("panel", style)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.sort_children.connect(_on_scroll_sorted)
	add_child(_scroll)
	_inset = MarginContainer.new()
	_inset.name = "Inset"
	_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset.add_theme_constant_override("margin_left", int(FRAME_OUT))
	_inset.add_theme_constant_override("margin_right", int(FRAME_PAD))
	_inset.add_theme_constant_override("margin_top", int(FRAME_GROW))
	_inset.add_theme_constant_override("margin_bottom", int(FRAME_GROW))
	_inset.draw.connect(_draw_frame)
	_scroll.add_child(_inset)
	_lines = VBoxContainer.new()
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.add_theme_constant_override("separation", 1)
	_lines.sort_children.connect(_inset.queue_redraw)
	_inset.add_child(_lines)


## Fit-up mode (#80): the receipt stands on `bottom` (the parent's coordinates) and is as tall as
## its lines, up to `top` at most; past that it ends there, scrolled to its newest line (or its
## framed one), with no scroll bar (the mouse wheel still scrolls). It fits again whenever its
## lines change.
func fit_up(bottom: float, top: float) -> void:
	_stand_bottom = bottom
	_cap_top = top
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if not _inset.minimum_size_changed.is_connected(_queue_fit):
		_inset.minimum_size_changed.connect(_queue_fit)
	fit_height()


## Fits the receipt's height to its lines (fit-up mode only; see fit_up()), then scrolls to its
## end (or its framed line).
func fit_height() -> void:
	_fit_queued = false
	if _stand_bottom < 0.0:
		return
	var frame: float = get_theme_stylebox("panel").get_minimum_size().y
	var room: float = _stand_bottom - _cap_top
	# The newest line stays in view in the very frame the receipt grows or shrinks.
	_snap_to_end = true
	# A stub snapping off shrinks the receipt from its foot, its body kept where it was.
	var lost: float = stub.lost() if is_instance_valid(stub) else 0.0
	size.y = maxf(minf(natural_height() + lost, room) - lost, frame)
	position.y = _stand_bottom - size.y - lost
	# Sorted after the panel gives the scroll area its new size (the scroll area doesn't always
	# sort itself on a resize), so _on_scroll_sorted sees it.
	_scroll.queue_sort()
	scroll_to_end()


## The lines' natural height plus the paper's frame: how tall the receipt is when nothing stops
## it. (A ScrollContainer reports no content height: the inset's own minimum is the content.)
func natural_height() -> float:
	return _inset.get_combined_minimum_size().y + get_theme_stylebox("panel").get_minimum_size().y


## Shows the newest line (or the framed one): scrolls once the new lines are laid out.
func scroll_to_end() -> void:
	_scroll_to_end.call_deferred()


func clear() -> void:
	stub = null
	_total_line = null
	_total_rule = null
	_footer = null
	_framed = null
	_planning = false
	_items.clear()
	_last.clear()
	_item_names.clear()
	_sums.clear()
	_closing.clear()
	_inset.queue_redraw()
	for line: Node in _lines.get_children():
		_lines.remove_child(line)
		line.queue_free()


## Starts a receipt: clears it, then prints `header` (header_lines(); none when empty).
func begin(header: PackedStringArray = PackedStringArray()) -> void:
	clear()
	for text: String in header:
		add_line(text, "", LineStyle.DETAIL)


## Starts the count-up's receipt (and a resumed checkout's, show_result): `header` and its dashed
## rule (none without a header), each of `names`' items waiting greyed in scan order, the dashed
## rule and "TOTAL •••••", then (with `footer`) "tap: skip · hold: fast".
func begin_count(header: PackedStringArray, names: PackedStringArray, footer: bool = true) -> void:
	begin(header)
	if not header.is_empty():
		_lines.add_child(ReceiptDecor.dashed_rule())
	for slot: int in range(names.size()):
		_item_names[slot] = names[slot]
		var line: HBoxContainer = _add_item(slot, names[slot] + " " + WAITING_DOTS, "")
		_set_waiting(line, true)
	_total_rule = ReceiptDecor.dashed_rule()
	_lines.add_child(_total_rule)
	_total_line = add_line(TOTAL_TEXT, TOTAL_WAITING, LineStyle.TOTAL) as HBoxContainer
	_set_waiting(_total_line, true)
	if footer:
		_footer = add_line(COUNT_FOOTER_TEXT, "", LineStyle.WAITING)
		(_footer.get_child(0) as Label).add_theme_font_size_override("font_size", FOOTER_FONT_SIZE)


## The planning receipt (#80): `header` and a dashed rule; for each belt item (`names`, in scan
## order) its name, its payout in `result` and its mark (slot_mark()); "n ·····" for each open
## slot past them up to `open_slots`; a dashed rule and "PROJECTED €total", against `quota` (none
## when negative): green with the met mark at or over it, red under it; then the footer: the
## shortfall ("short €12.00", its own row) and the fizzles (each none without it).
func show_planning(
	header: PackedStringArray,
	result: ScoreResult,
	names: PackedStringArray,
	open_slots: int,
	quota: int = -1
) -> void:
	begin(header)
	_planning = true
	_lines.add_child(ReceiptDecor.dashed_rule())
	for slot: int in range(names.size()):
		var payout: int = result.payouts[slot] if slot < result.payouts.size() else 0
		var line: HBoxContainer = _add_item(slot, names[slot], money(payout))
		ReceiptDecor.mark(line, slot_mark(result, slot))
	for slot: int in range(names.size(), open_slots):
		add_line(EMPTY_SLOT_TEXT % (slot + 1), "", LineStyle.WAITING)
	var projected: Control = add_line(PROJECTED_TEXT, money(result.total), LineStyle.PROJECTED)
	if quota >= 0:
		var short: String = ReceiptDecor.against_quota(
			projected as HBoxContainer, result.total, quota
		)
		if not short.is_empty():
			add_line(short, "", LineStyle.FOOTER)
	var fizzles: int = fizzle_count(result)
	if fizzles > 0:
		_footer = add_line(_fizzle_count_text(fizzles), HINT_TEXT % DEFAULT_HINT, LineStyle.FOOTER)


## Planning only: frames `slot`'s item line (the belt item being scanned), or none for -1 (or a
## slot with no line). Does nothing outside planning: the count-up frames its own lines.
func highlight_slot(slot: int) -> void:
	if not _planning:
		return
	_set_frame(_item_line_of(slot))


## Planning only (#71): the hovered belt item at `focus_slot` (-1: none) frames its line, each slot
## of `tokens` (its targets) gets a mustard-pale fill and the token it gives them before its
## amount (ReceiptDecor.relate), and the fizzle footer's hint becomes `hint` ("Bread hovered").
## The previous relations go. (One call, not three: gdlint allows the class 20 public methods.)
func show_relations(
	focus_slot: int, tokens: Dictionary[int, String] = {}, hint: String = DEFAULT_HINT
) -> void:
	if not _planning:
		return
	for slot: int in _items:
		if _item_line_of(slot) != null:
			ReceiptDecor.relate(_item_line_of(slot), tokens.get(slot, ""))
	highlight_slot(focus_slot)
	if is_instance_valid(_footer):
		(_footer.get_child(1) as Label).text = HINT_TEXT % hint


## The header's lines for 1-based `shift` of `shifts` with `items` on the belt (coupons
## included): "NEXT CUSTOMER · REG 3", then "SHIFT n/m · k ITEMS" ("· 1 ITEM" for one).
static func header_lines(shift: int, shifts: int, items: int) -> PackedStringArray:
	var shift_text: String = (
		ITEM_TEXT % [shift, shifts] if items == 1 else SHIFT_TEXT % [shift, shifts, items]
	)
	return PackedStringArray([HEADER_TEXT, shift_text])


## A money amount as the receipt prints it: "€3.00", or "+€15.00" when `signed`. Values are
## whole euros: only the receipt shows cents.
static func money(euros: int, signed: bool = false) -> String:
	return ("+" if signed else "") + MONEY_TEXT % euros


## How many of `result`'s steps fizzle (the footer's count): every WASTED step, the upgrades'
## too.
static func fizzle_count(result: ScoreResult) -> int:
	var count: int = 0
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			count += 1
	return count


## `slot`'s mark in `result`, read from its recorded amounts: DENIED when an inspection's
## PAYOUT_OVERRIDE is on it, else RAISED when its payout is above its BASE step's value (even with
## a fizzle of its own, as its belt ticket shows BOOSTED: since #45 an unpaired Banana or Cheese
## that another card boosts fizzles too), else FIZZLED when a WASTED step of its own is on it
## (an upgrade's row-wide fizzle on the last slot is not the item's: ScoreStep.row_wide), else
## NONE.
static func slot_mark(result: ScoreResult, slot: int) -> Mark:
	var base: int = -1
	var fizzled: bool = false
	for step: ScoreStep in result.steps:
		if step.slot != slot:
			continue
		if (
			step.step_type == ScoreStep.StepType.PAYOUT_OVERRIDE
			and step.source_kind == ScoreStep.SourceKind.INSPECTION
		):
			return Mark.DENIED
		fizzled = fizzled or (step.step_type == ScoreStep.StepType.WASTED and not step.row_wide)
		if step.step_type == ScoreStep.StepType.BASE:
			base = step.value
	if base >= 0 and slot < result.payouts.size() and result.payouts[slot] > base:
		return Mark.RAISED
	if fizzled:
		return Mark.FIZZLED
	return Mark.NONE


## The whole receipt at once, under `header` (header_lines(); none when empty): a resumed
## checkout's, as the count-up printed it (begin_count without its footer, then every step and
## the total), and the tests' expected receipts. `upgrade_names` are the run's upgrades' names in
## pick order and `inspection_names` the shift's inspections' names, for the lines they cause.
func show_result(
	result: ScoreResult,
	names: PackedStringArray,
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_names: PackedStringArray = PackedStringArray(),
	header: PackedStringArray = PackedStringArray()
) -> void:
	begin_count(header, names, false)
	for step: ScoreStep in result.steps:
		add_step(step, names, upgrade_names, inspection_names)
	add_total(result.total)


## Prints one step and returns what the count-up animates: a BASE step fills its item's line in
## (its base amount, in ink, kept for good) and returns the line; a PAYOUT step prints the
## closing line "= €payout" when the item's printed amount (its BASE step's value plus its FLAT
## and COPY steps', a PAYOUT_OVERRIDE step's value replacing the sum) is not its value, and
## returns that line's amount label; else it prints nothing and returns the item line's amount
## label when nothing printed under the item (a plain card: its amount fades in on the beat), or
## null (its amount has shown since its BASE step: nothing new to fade in). Any other step prints
## its line under its item's earlier lines (above its closing line, which stays last) and
## returns it. The printed or filled line is framed (the item's line when a PAYOUT step prints
## nothing). Returns null for a step that prints no line. An item with no line yet (no
## begin_count) gets one, at the end.
func add_step(
	step: ScoreStep,
	names: PackedStringArray,
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_names: PackedStringArray = PackedStringArray()
) -> Control:
	var text: PackedStringArray = step_text(step, names, upgrade_names, inspection_names)
	if text.is_empty():
		return null
	match step.step_type:
		ScoreStep.StepType.BASE, ScoreStep.StepType.PAYOUT:
			var item: HBoxContainer = _item_line(step.slot, text[0])
			var amount: Label = item.get_child(1) as Label
			var name_text: String = text[0]
			if _item_names.has(step.slot):
				name_text = _item_names[step.slot]
			(item.get_child(0) as Label).text = name_text
			if step.step_type == ScoreStep.StepType.BASE:
				_sums[step.slot] = step.value
			var printed: int = _sums.get(step.slot, 0)
			if step.step_type == ScoreStep.StepType.BASE or amount.text.is_empty():
				amount.text = money(printed)
			_set_waiting(item, false)
			if step.step_type == ScoreStep.StepType.BASE:
				_set_frame(item)
				return item
			if printed == step.value:
				_set_frame(item)
				return amount if _last.get(step.slot) == item else null
			var closing: Control = _add_group_line(
				step.slot, "", CLOSING_TEXT + text[1], LineStyle.CLOSING
			)
			_closing[step.slot] = closing
			return closing.get_child(1) as Label
		ScoreStep.StepType.FLAT, ScoreStep.StepType.COPY:
			var so_far: int = _sums.get(step.slot, 0)
			_sums[step.slot] = so_far + step.value
		ScoreStep.StepType.PAYOUT_OVERRIDE:
			_sums[step.slot] = step.value
	var line: Control = _add_group_line(step.slot, text[0], text[1], step_style(step))
	if step.step_type == ScoreStep.StepType.WASTED:
		ReceiptDecor.mark(line as HBoxContainer, Mark.FIZZLED)
	return line


## Prints a line ("left", "right", in `style`) into `slot`'s group, after its earlier lines but
## above its closing line, and frames it.
func _add_group_line(
	slot: int, left: String, right: String, style: LineStyle = LineStyle.ITEM
) -> Control:
	var line: Control = add_line(left, right, style)
	_lines.move_child(line, mini(_group_index(slot), _lines.get_child_count() - 1))
	if not _closing.has(slot):
		_last[slot] = line
	_set_frame(line)
	return line


## The receipt's words for one step: its left side (with its indent and marker) and its right
## side (the amount, with cents, or nothing: a fizzle's mark says "WASTED"), or none for a step
## that prints no line. A BASE or PAYOUT step's left side is its item's name: they fill the
## item's line in (add_step).
static func step_text(
	step: ScoreStep,
	names: PackedStringArray,
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_names: PackedStringArray = PackedStringArray()
) -> PackedStringArray:
	var cause: String = source_text(step, upgrade_names, inspection_names)
	if step.step_type == ScoreStep.StepType.MULTIPLIER:
		cause = multiplier_cause(step, upgrade_names, inspection_names)
	var left: String = ""
	var right: String = ""
	match step.step_type:
		ScoreStep.StepType.TAG_ADDED:
			left = "  %s: %s gains %s" % [step.text, names[step.slot], step.tag]
		ScoreStep.StepType.LINKED:
			left = "  %s links %s + %s" % [step.text, names[step.slot], names[step.linked_slot]]
		ScoreStep.StepType.WASTED:
			left = "  %s: %s" % [cause, step.reason]
		ScoreStep.StepType.BASE, ScoreStep.StepType.PAYOUT:
			left = names[step.slot]
			right = money(step.value)
		ScoreStep.StepType.FLAT:
			left = "  + " + cause
			right = money(step.value, true)
		ScoreStep.StepType.MULTIPLIER:
			left = "  × " + cause
			right = "×%d" % step.value
		ScoreStep.StepType.COPY:
			left = "  %s: copy of %s" % [step.text, names[step.linked_slot]]
			right = money(step.value, true)
		ScoreStep.StepType.PAYOUT_OVERRIDE:
			left = "  " + cause
			right = "= " + money(step.value)
		ScoreStep.StepType.EFFECT_ARMED:
			# No line: the receipt stays a straight list of payouts and explanations. What the
			# effect does is printed where it lands (its FLAT or MULTIPLIER line, or a fizzle).
			return PackedStringArray()
	return PackedStringArray([left, right])


## The style a step's line prints in: CONTEXT for a tag or a link, FIZZLE for a fizzle, ITEM for
## a base or a payout (its item's line), COMBO for a combo (is_combo), DETAIL for the rest.
static func step_style(step: ScoreStep) -> LineStyle:
	match step.step_type:
		ScoreStep.StepType.TAG_ADDED, ScoreStep.StepType.LINKED:
			return LineStyle.CONTEXT
		ScoreStep.StepType.WASTED:
			return LineStyle.FIZZLE
		ScoreStep.StepType.BASE, ScoreStep.StepType.PAYOUT:
			return LineStyle.ITEM
	return LineStyle.COMBO if is_combo(step) else LineStyle.DETAIL


## Whether a step is a combo (#75): a bonus or a multiplier that another source caused (another
## item, an upgrade or an inspection: the steps that become an item's boost chips,
## EffectChip.qualifies), or a copy, which always pays another item's payout.
static func is_combo(step: ScoreStep) -> bool:
	match step.step_type:
		ScoreStep.StepType.FLAT, ScoreStep.StepType.MULTIPLIER:
			return step.source_kind != ScoreStep.SourceKind.CARD or step.source_slot != step.slot
		ScoreStep.StepType.COPY:
			return true
	return false


## A step's line on one row, in whole euros (#75 and #80: the monitor's count-up line and a belt
## item's scan footer). A bonus reads as B2 words it, its amount first ("+€15 Category engine",
## "×2 Multipack", "+€3 Repeat: copy of Bread"); a base "MILK  2", a payout "€17", an override
## "Spot check: the 3rd product pays €0  = 0"; the others are the receipt's left side without its
## indent, then its right side two spaces after it ("Coffee: no Breakfast product after it
## WASTED"). Empty for a step that prints no line.
static func step_line(
	step: ScoreStep,
	names: PackedStringArray,
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_names: PackedStringArray = PackedStringArray()
) -> String:
	var cause: String = source_text(step, upgrade_names, inspection_names)
	match step.step_type:
		ScoreStep.StepType.FLAT:
			return "+€%d %s" % [step.value, cause]
		ScoreStep.StepType.MULTIPLIER:
			return "×%d %s" % [step.value, multiplier_cause(step, upgrade_names, inspection_names)]
		ScoreStep.StepType.COPY:
			return "+€%d %s: copy of %s" % [step.value, step.text, names[step.linked_slot]]
		ScoreStep.StepType.BASE:
			return joined_line(names[step.slot].to_upper(), str(step.value))
		ScoreStep.StepType.PAYOUT:
			return "€%d" % step.value
		ScoreStep.StepType.PAYOUT_OVERRIDE:
			return joined_line(cause, "= %d" % step.value)
		ScoreStep.StepType.WASTED:
			return joined_line("%s: %s" % [cause, step.reason], EffectLink.WASTED_WORD)
	var text: PackedStringArray = step_text(step, names, upgrade_names, inspection_names)
	if text.is_empty():
		return ""
	return joined_line(text[0], text[1])


## A receipt line's two sides on one row: the left without its indent, then the right (if any)
## two spaces after it.
static func joined_line(left: String, right: String) -> String:
	var stripped: String = left.strip_edges()
	return stripped if right.is_empty() else "%s  %s" % [stripped, right]


## Who caused a step, as the receipt names it. A card's rule is named by its receipt text; an
## upgrade's line always names the upgrade (plan section 3.8), with its rule's receipt text
## after it when that text is something else. An inspection's line starts with the
## inspection's name (plan section 3.9): "Spot check: the 3rd product pays €0".
static func source_text(
	step: ScoreStep,
	upgrade_names: PackedStringArray,
	inspection_names: PackedStringArray = PackedStringArray()
) -> String:
	return _cause(step, step.text, upgrade_names, inspection_names)


## A multiplier's cause as source_text names it, less the factor its receipt text ends in
## ("Multipack ×3" is "Multipack"): its line prints the factor itself ("×3 Multipack").
static func multiplier_cause(
	step: ScoreStep,
	upgrade_names: PackedStringArray,
	inspection_names: PackedStringArray = PackedStringArray()
) -> String:
	var text: String = step.text
	var at: int = text.rfind(FACTOR_MARK)
	if at > 0 and text.substr(at + FACTOR_MARK.length()).is_valid_int():
		text = text.substr(0, at)
	return _cause(step, text, upgrade_names, inspection_names)


## source_text's words for `step` with `text` as its rule's receipt text.
static func _cause(
	step: ScoreStep,
	text: String,
	upgrade_names: PackedStringArray,
	inspection_names: PackedStringArray
) -> String:
	match step.source_kind:
		ScoreStep.SourceKind.UPGRADE:
			if step.source_index < 0 or step.source_index >= upgrade_names.size():
				return text
			var upgrade_name: String = upgrade_names[step.source_index]
			if text.is_empty() or text == upgrade_name:
				return upgrade_name
			return "%s (%s)" % [text, upgrade_name]
		ScoreStep.SourceKind.INSPECTION:
			if step.source_index < 0 or step.source_index >= inspection_names.size():
				return text
			var inspection_name: String = inspection_names[step.source_index]
			if text.is_empty() or text == inspection_name:
				return inspection_name
			return "%s: %s" % [inspection_name, text]
	return text


## The TOTAL line: the pre-printed one filled in plainly ("TOTAL €22.00", begin_count), which
## also ends the count-up's footer and frame; or a new one under a solid rule.
func add_total(total: int) -> Control:
	_set_frame(null)
	if is_instance_valid(_footer):
		_lines.remove_child(_footer)
		_footer.queue_free()
	_footer = null
	if is_instance_valid(_total_line) and _total_line.get_parent() == _lines:
		(_total_line.get_child(1) as Label).text = money(total)
		_set_waiting(_total_line, false)
		scroll_to_end()
		return _total_line
	_total_line = add_line(TOTAL_TEXT, money(total), LineStyle.TOTAL) as HBoxContainer
	return _total_line


## A red notice under the total (plan section 3.9: the next shift's inspection).
func add_notice(text: String) -> Control:
	return add_line(text, "", LineStyle.NOTICE)


## The shift's end at once, as the dessert leaves it (#61): the verdict, the margin (PAID on a
## pass), INSPECTION PASSED naming `inspection` (#77; none when empty), the BONUS stub with its
## small line `sub` (#77 machine v2; none when empty), the tear and `notice` (none when empty).
func show_shift_end(
	total: int, quota: int, notice: String = "", inspection: String = "", sub: String = ""
) -> void:
	var margin: ShiftMargin = ShiftMargin.of(total, quota)
	show_verdict(total, quota)
	var line: Control = add_margin(margin)
	if margin.passed():
		ReceiptStamps.stamp_paid(line)
		if not inspection.is_empty():
			ReceiptStamps.stamp_inspection(self, inspection)
		if not sub.is_empty():
			ReceiptStamps.add_bonus_stub(self, sub).grow(BonusTicket.SIZE.y)
	add_tear()
	if not notice.is_empty():
		add_notice(notice)


## The TOTAL line's "€total / €quota" (#61; since #80 it prints plainly, and the dessert's slam
## lands on the monitor), with cents.
static func verdict_text(total: int, quota: int) -> String:
	return "%s / %s" % [money(total), money(quota)]


## Shows the verdict on the TOTAL line at once: its right side reads "€total / €quota" at
## VERDICT_FONT_SIZE across the mark column (smaller when it would not fit beside TOTAL,
## verdict_font_size), green on a pass and red on a miss. Returns that label (null when no
## TOTAL line was printed).
func show_verdict(total: int, quota: int) -> Label:
	var label: Label = total_label()
	if label == null:
		return null
	label.text = verdict_text(total, quota)
	# The TOTAL line has no mark: the verdict runs on across its mark column.
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var room: float = INF
	if _lines.size.x > 0.0:
		var caption: Label = _total_line.get_child(0) as Label
		room = (
			_lines.size.x
			- text_width(caption.text, MONO_FONT, CAPTION_FONT_SIZE)
			- _total_line.get_theme_constant("separation")
		)
	label.add_theme_font_size_override("font_size", verdict_font_size(label.text, room))
	label.add_theme_color_override(
		"font_color", Palette.GOOD if ShiftMargin.of(total, quota).passed() else Palette.TOMATO
	)
	return label


## The verdict's font size: VERDICT_FONT_SIZE, or the largest down to VERDICT_MIN_FONT_SIZE at
## which `text` fits in `room` pixels.
static func verdict_font_size(text: String, room: float) -> int:
	var font_size: int = VERDICT_FONT_SIZE
	while font_size > VERDICT_MIN_FONT_SIZE and text_width(text, MONO_FONT, font_size) > room:
		font_size -= 1
	return font_size


## The TOTAL line's right-hand label (the total, then the verdict), or null before a total.
func total_label() -> Label:
	if _total_line == null or not is_instance_valid(_total_line):
		return null
	return _total_line.get_child(1) as Label


## The margin line under the total, showing the whole margin: "+€N.00 OVER QUOTA", "SHORT €N.00"
## (red) or "ON QUOTA" (green). The dessert counts it up with show_margin.
func add_margin(margin: ShiftMargin) -> Control:
	var line: Control = add_line(margin_text(margin.kind(), margin.amount()), "", LineStyle.MARGIN)
	var color: Color = Palette.TOMATO if margin.kind() == ShiftMargin.Kind.SHORT else Palette.GOOD
	for label: Node in line.get_children():
		(label as Label).add_theme_color_override("font_color", color)
	return line


## Shows `euros` on a margin `line` of `kind`, as its count passes them.
static func show_margin(line: Control, kind: ShiftMargin.Kind, euros: int) -> void:
	(line.get_child(0) as Label).text = margin_text(kind, euros)


static func margin_text(kind: ShiftMargin.Kind, euros: int) -> String:
	match kind:
		ShiftMargin.Kind.OVER:
			return "%s OVER QUOTA" % money(euros, true)
		ShiftMargin.Kind.SHORT:
			return "SHORT %s" % money(euros)
	return "ON QUOTA"


## The receipt tears off under the shift's lines: a torn edge, clipped to the receipt's width.
func add_tear() -> Control:
	return add_line(TEAR_PATTERN.repeat(TEAR_REPEAT), "", LineStyle.TEAR)


func add_line(left: String, right: String, style: LineStyle) -> Control:
	var line: HBoxContainer = HBoxContainer.new()
	var left_label: Label = _label(left, style)
	left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if style == LineStyle.TEAR:
		# The torn edge never wraps or widens the receipt: it is cut at the paper's edge.
		left_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		left_label.clip_text = true
		left_label.custom_minimum_size.x = 1.0
	if style == LineStyle.DETAIL or style == LineStyle.FIZZLE or style == LineStyle.CONTEXT:
		ReceiptDecor.hang(left_label)
	elif style == LineStyle.COMBO:
		ReceiptDecor.hang(left_label, COMBO_INDENT, false)
		ReceiptDecor.combo(line, left_label)
	elif style == LineStyle.TOTAL or style == LineStyle.PROJECTED:
		left_label.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
		# The caption never breaks inside its word: a long verdict shrinks instead.
		left_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		left_label.size_flags_vertical = Control.SIZE_SHRINK_END
	line.add_child(left_label)
	var right_label: Label = _label(right, style)
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# The amount sits on the line's last row when the left side wraps.
	right_label.size_flags_vertical = Control.SIZE_FILL
	right_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	if has_mark_column(style):
		var column: StyleBoxEmpty = StyleBoxEmpty.new()
		column.content_margin_right = MARK_COLUMN
		if style == LineStyle.FIZZLE:
			# The reason takes the rest of the line: no amount, so no gap before the mark.
			column.content_margin_right = FIZZLE_MARK_COLUMN
			line.add_theme_constant_override("separation", 0)
		right_label.add_theme_stylebox_override("normal", column)
	if style == LineStyle.FOOTER:
		# The fizzle count, then where to read them, run on as one line.
		left_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		right_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		right_label.add_theme_color_override("font_color", Palette.INK_LIGHT)
		# One line that never widens the stub: a long hint is cut with an ellipsis.
		right_label.clip_text = true
		right_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		right_label.custom_minimum_size.x = 1.0
		line.add_theme_constant_override("separation", 0)
	line.add_child(right_label)
	if style == LineStyle.TOTAL and not is_instance_valid(_total_rule):
		_lines.add_child(HSeparator.new())
	elif style == LineStyle.PROJECTED:
		_lines.add_child(ReceiptDecor.dashed_rule())
	_lines.add_child(line)
	scroll_to_end()
	return line


## Whether a line of `style` keeps the mark column (MARK_COLUMN) at its right end: all but the
## footer, the margin, the notice and the tear, which run across it.
static func has_mark_column(style: LineStyle) -> bool:
	return style not in [LineStyle.FOOTER, LineStyle.MARGIN, LineStyle.NOTICE, LineStyle.TEAR]


## A step line's text split for a hanging indent: its leading spaces, its marker ("+ " or "× ",
## only after leading spaces) and the rest.
static func hang_parts(text: String) -> PackedStringArray:
	var rest: String = text.lstrip(" ")
	var lead: String = text.substr(0, text.length() - rest.length())
	var marker: String = ""
	for candidate: String in HANG_MARKERS:
		if not lead.is_empty() and rest.begins_with(candidate):
			marker = candidate
			rest = rest.substr(candidate.length())
			break
	return PackedStringArray([lead, marker, rest])


static func text_width(text: String, font: Font, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


static func _fizzle_count_text(fizzles: int) -> String:
	return FIZZLES_TEXT % fizzles


## A new item line for `slot` ("left", "right"), above the TOTAL line's rule.
func _add_item(slot: int, left: String, right: String) -> HBoxContainer:
	var line: HBoxContainer = add_line(left, right, LineStyle.ITEM) as HBoxContainer
	_lines.move_child(line, _end_index(line))
	_items[slot] = line
	if not _last.has(slot):
		_last[slot] = line
	return line


## `slot`'s item line, a new one named `name_text` when it has none yet.
func _item_line(slot: int, name_text: String) -> HBoxContainer:
	var item: HBoxContainer = _item_line_of(slot)
	if item != null:
		return item
	_item_names[slot] = name_text
	return _add_item(slot, name_text, "")


## Where a new line of `slot`'s group goes: above its closing line, else right after the group's
## last line, or (no group yet) above the TOTAL line's rule.
func _group_index(slot: int) -> int:
	if _closing.has(slot) and is_instance_valid(_closing[slot]):
		return _closing[slot].get_index()
	if _last.has(slot) and is_instance_valid(_last[slot]):
		return _last[slot].get_index() + 1
	return _total_rule.get_index() if is_instance_valid(_total_rule) else _lines.get_child_count()


## Where `line`, just added last, goes when it ends the lines printed so far: above the TOTAL
## line's rule when there is one, else where it is.
func _end_index(line: Control) -> int:
	if is_instance_valid(_total_rule) and _total_rule.get_parent() == _lines:
		return _total_rule.get_index()
	return line.get_index()


## A line's look while it waits to print (muted ink) or once printed (ink; the TOTAL line's).
static func _set_waiting(line: HBoxContainer, waiting: bool) -> void:
	for child: Node in line.get_children():
		(child as Label).add_theme_color_override(
			"font_color", Palette.MUTED_INK if waiting else Palette.INK
		)


## The framed line, or null.
func _framed_line() -> Control:
	return _framed if is_instance_valid(_framed) else null


## `slot`'s item line, or null.
func _item_line_of(slot: int) -> HBoxContainer:
	if _items.has(slot) and is_instance_valid(_items[slot]):
		return _items[slot]
	return null


## The framed line's frame, behind the lines (ReceiptDecor.draw_frame).
func _draw_frame() -> void:
	ReceiptDecor.draw_frame(_inset, _lines, _framed_line())


## Frames `line` (none for null) and keeps it in view. A framed line's "framed" meta is set: a
## combo line drops its band and bar while framed (B2: the frame's fill and frame alone).
func _set_frame(line: Control) -> void:
	for old_or_new: Control in [_framed_line(), line]:
		if old_or_new != null:
			old_or_new.set_meta("framed", old_or_new == line)
			old_or_new.queue_redraw()
	_framed = line
	_inset.queue_redraw()
	scroll_to_end()


func _label(text: String, style: LineStyle) -> Label:
	var label: Label = Label.new()
	label.text = text
	var font_size: int = LINE_FONT_SIZE
	var color: Color = Palette.INK
	match style:
		LineStyle.CONTEXT:
			color = Palette.TEAL
		LineStyle.FIZZLE, LineStyle.FOOTER:
			# A fizzle's reason at B2's step-line size, so a long one keeps to two rows.
			color = Palette.TOMATO_DARK
			font_size = FOOTER_FONT_SIZE
		LineStyle.TOTAL, LineStyle.PROJECTED:
			font_size = TOTAL_FONT_SIZE
		LineStyle.NOTICE:
			font_size = 15
			color = Palette.TOMATO
		LineStyle.MARGIN:
			font_size = 15
		LineStyle.TEAR, LineStyle.WAITING:
			color = Palette.MUTED_INK
		LineStyle.CLOSING:
			font_size = FOOTER_FONT_SIZE
	label.add_theme_font_override("font", MONO_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Fits once, at the end of this frame's layout, however many lines changed.
func _queue_fit() -> void:
	if _fit_queued:
		return
	_fit_queued = true
	fit_height.call_deferred()


## Fit-up mode: once the scroll area has laid out its new size, scrolls to the end (deferred: the
## scroll area lays its lines out again for the new scroll only after this sort has finished).
func _on_scroll_sorted() -> void:
	if not _snap_to_end:
		return
	_snap_to_end = false
	_snap.call_deferred()


func _snap() -> void:
	_scroll.scroll_vertical = _scroll_target()
	# A scroll clamped during that sort (a taller receipt) moved no line yet: lay them out again.
	_scroll.queue_sort()


## Waits a frame so the new line is laid out before scrolling to it.
func _scroll_to_end() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_inside_tree():
		_scroll.scroll_vertical = _scroll_target()


## Where the scroll goes: the least scroll that shows the framed line whole (with its frame), or
## the end when no line is framed.
func _scroll_target() -> int:
	var end: int = int(_scroll.get_v_scroll_bar().max_value)
	var line: Control = _framed_line()
	if line == null or line.get_parent() != _lines:
		return end
	# In the scroll's content: the inset's own position moves with the scroll.
	var top: float = _lines.position.y + line.position.y - FRAME_GROW
	var bottom: float = top + line.size.y + 2.0 * FRAME_GROW
	var view: float = _scroll.size.y
	var scroll: float = clampf(float(_scroll.scroll_vertical), bottom - view, top)
	return clampi(roundi(scroll), 0, maxi(end, 0))
