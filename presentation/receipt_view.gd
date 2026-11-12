class_name ReceiptView
extends PanelContainer
## The receipt: printed from a ScoreResult's payouts and steps alone, so it can never disagree
## with the score. Every money amount on it prints in whole euros (money(): "3€", "+15€"), as
## every score is (main scene v2, 2026-11-08: the cents were decoration only).
##
## Its header (`target`, ReceiptTarget: H2 of mock-up docs/art/mockups/main_scene_v2.html) is
## pinned at its top, outside the scroll area, once the screen shows the quota: BEAT TODAY'S
## TARGET over the quota, then PROJECTED (planning) or TOTAL (the count) with the hero number and
## the line against the target, then a dashed rule.
##
## In planning (show_planning) nothing is printed under the header (2026-11-08 feedback: no band,
## no minis): the paper is the header alone, as short as it, and the hero shows the projected
## total, rolling to each new one (ReceiptRoll).
##
## `anchored` (the shift screen's): the count prints each item's row as it reaches the item
## (ReceiptPrintRows), in slot order, its amount rolling with the count's reading (show_running,
## which also moves the hero), so the rows always add up to the TOTAL; the dessert's margin words
## count on the header's line against the target, and its other lines (PAID's line, INSPECTION
## PASSED, the tear, the next shift's notice) print under the rows. From the count's start the
## paper reaches its room's top (fit_height; planning's is the header alone), so the rows print in
## place: the header (the hero, the target, BEATEN!) never leaves the screen, and lines past the
## paper's room scroll the oldest rows up under the header, the newest line in view. Its paper
## turns gold on a payday or past the overtime laps (`gold`, ReceiptGold).
##
## Any other count (begin_count without planning, show_result: a copy of the receipt, the tests'
## expected receipts) prints its lines in detail: each step into its item's group (add_step), the
## BASE step filling the item's line in with its base amount, the other steps an indented line
## under it, a fizzle's in dark tomato with the fizzle icon, a multiplier's PAYOUT closing the item
## with "= 3€" (CLOSING_TEXT); every combo line is marked with a faint gold band (a loyalty perk's
## pale teal); the TOTAL line, then the dessert's verdict, margin, tear and notice under it. The
## line just printed is framed (mustard-pale fill, mustard frame) and kept in view. On the shift
## screen it stood on the printer's slot (fit_up, #80); since left column v2 (the user's pick of
## 2026-11-09, mock-up docs/art/mockups/left_column_v2.html) it hangs from the overhead printer
## (fit_up's `hang_down`, ReceiptHang): its top, the header, stays at the slot and the paper feeds
## DOWN.
## At an anchored count each printed line lengthens the paper by its height (whole art px) at its
## free end, where the line prints, until the paper reaches its room's foot (then the rows scroll
## under the header, as before). Planning's stub is the header alone; the next planning after a
## count (the next day, a Double checkout's row 2) clears the count's paper and POPS the new stub
## down out of the slot (at once under reduced motion), `stub_printed` telling the stage. A torn
## edge hangs under the paper's foot. A payday wears the paycheck design (payday_ribbon,
## ReceiptPayday: its brass ribbon over the header and brass foot band; no side frame).

## An anchored count's paper started (its count's first line, or a resumed checkout's): the stage
## hides the gauge.
signal count_paper_started
## Planning's stub printed (`popped`: it pops out after a count's paper, the next day's;
## `after_count`: it follows an anchored count, popped or still under reduced motion).
signal stub_printed(popped: bool, after_count: bool)

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
	COMBO,
	WAITING,
	CLOSING,
}

## An item line's mark in planning: none, fizzled, or denied by an inspection.
enum Mark { NONE, FIZZLED, DENIED, WRITTEN_OFF }

## How a boon day's notice starts (v0.69: a shift is a day): its NOTICE line prints in green.
const BOON_NOTICE_PREFIX := "TOMORROW: "
## Monospace for the receipt (plan section 2). JetBrains Mono, SIL Open Font License.
const MONO_FONT := preload("res://fonts/JetBrainsMono-Regular.ttf")
## The TOTAL and PROJECTED amounts' font size; their captions print at CAPTION_FONT_SIZE (v4's D:
## 39 and 24 px at 1920x1080).
const TOTAL_FONT_SIZE := 26
const CAPTION_FONT_SIZE := 16
## The verdict "total€ / quota€" on the TOTAL line, smaller than the total so it fits; a long
## one (a four-digit total) shrinks down to VERDICT_MIN_FONT_SIZE to stay on the line.
const VERDICT_FONT_SIZE := 15
const VERDICT_MIN_FONT_SIZE := 10
## The item and header lines' size (v4's D: 21 px at 1920x1080), the count's indented step lines'
## (a step below, so they keep their wrap), the sub lines' (a fizzle's reason, a closing line, an
## arm line) and the foot's small lines' (planning's line against the quota, the count-up's
## footer).
const LINE_FONT_SIZE := 14
const STEP_FONT_SIZE := 13
const FOOTER_FONT_SIZE := 12
const FOOT_FONT_SIZE := 14
## The PAID stamp on a passed shift's margin line (ReceiptStamps, with INSPECTION PASSED).
const PAID_TEXT := ReceiptStamps.PAID_TEXT
## The torn edge: this pattern repeated, clipped to the receipt's width.
const TEAR_PATTERN := "/\\"
const TEAR_REPEAT := 60
## Planning's caption (#80: PROJECTED, never TOTAL, which only the count prints).
const PROJECTED_TEXT := ReceiptTarget.PROJECTED_TEXT
const TOTAL_TEXT := ReceiptTarget.TOTAL_TEXT
## The dashed rules: a dash RULE_DASH long, then a gap as long.
const RULE_DASH := 4.0
## The count-up's footer, from its start to the TOTAL line.
const COUNT_FOOTER_TEXT := "tap: skip · hold: fast"
## The line closing an item whose lines don't add up to its payout (add_step): "= 3€", at
## FOOTER_FONT_SIZE in ink (LineStyle.CLOSING), with no left side.
const CLOSING_TEXT := "= "
## How a multiplier's receipt text ends in its factor ("Multipack ×3", ReceiptCause.multiplier).
const FACTOR_MARK := " ×"
## A money amount on the receipt (money()): whole euros, as every score is.
const MONEY_TEXT := "%d€"
## The inset around the lines: the frame reaches FRAME_OUT past their left and FRAME_PAD past
## their right (B2: 4 px of padding, then its 2 px frame).
const FRAME_OUT := 4.0
const FRAME_PAD := 6.0
## The framed line's frame reaches this far above and below the line.
const FRAME_GROW := 1.0
## B2's mark column at a line's right end: a 6 px gap past the amount, then the 14 px mark
## (ReceiptDecor.mark). Every line keeps it but the margin, the notice and the tear
## (ReceiptDecor.has_mark_column), so the dashed rules run across it. A fizzle's
## line has no amount: its column is just the mark and a 2 px gap (FIZZLE_MARK_COLUMN), with no
## gap before it.
const MARK_COLUMN := 20.0
const FIZZLE_MARK_COLUMN := 16.0
## A combo line: a faint gold band behind the whole line with a gold bar on its left, and the
## diamond after the bar; the line's text hangs past both (COMBO_INDENT takes the place of its
## leading spaces and its marker), so nothing sits outside the receipt's scroll area.
const COMBO_BAR := 2.0
const COMBO_ICON_RECT := Rect2(4, 3, 10, 10)
const COMBO_INDENT := 18.0
const COMBO_DIAMOND := preload("res://art/icons/combo_diamond.png")
## TODAY'S TARGET, pinned at the top (hidden until its show_quota).
var target: ReceiptTarget
## The count prints planning's items' rows as it reaches them (ReceiptPrintRows).
var anchored: bool = false
## Reduced motion: the rows print without their wipe (the count's flow sets it).
var reduced_motion: bool = false
## Planning's reduced motion (returns a bool; the screen's profile setting): the projected number
## shows at once, without its roll. Unset: it rolls.
var planning_still: Callable = Callable()
## The open slots the last planning receipt showed (show_planning), for a copy of it.
var planned_slots: int = 0
## The silver and gold paper (ReceiptGold).
var gold: ReceiptGold
## Payday's ribbon over the header (ReceiptPayday; hidden on other days): the paper's paycheck
## design shows while it does.
var payday_ribbon: ReceiptPayday
## Fit-down mode's feed, pop and tail (ReceiptHang; null unless it hangs: fit_up's `hang_down`).
var hang: ReceiptHang
## An anchored count's printed rows, or null.
var _print: ReceiptPrintRows
var _lines: VBoxContainer
## Holds the lines inside the scroll area, with room for the frame and the marks; draws the frame.
var _inset: MarginContainer
var _scroll: ScrollContainer
## The last TOTAL line printed (or pre-printed), or null.
var _total_line: HBoxContainer
## The pre-printed TOTAL line's dashed rule (begin_count), or null: the step lines print above it.
var _total_rule: Control
## The count-up's footer line, or null.
var _footer: Control
## Each slot's item line, its last printed line and its item's name.
var _items: Dictionary[int, HBoxContainer] = {}
var _last: Dictionary[int, Control] = {}
var _item_names: Dictionary[int, String] = {}
## Each slot's printed amount so far (its base plus its bonus and copy lines, or its override's
## amount and the lines after it), and its closing line.
var _sums: Dictionary[int, int] = {}
var _closing: Dictionary[int, Control] = {}
## Each slot's printed label whose amount is its printed sum (its base's, an override's), and
## each slot's card (ReceiptInk: minis and arm words; none when not given).
var _figures: Dictionary[int, Label] = {}
var _cards: Array[CardDefinition] = []
## The framed line (the counted step's, or the scanned item's in planning), or null.
var _framed: Control
## The receipt shows planning (show_planning): an anchored count prints its rows.
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
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	payday_ribbon = ReceiptPayday.new()
	column.add_child(payday_ribbon)
	payday_ribbon.visibility_changed.connect(_on_payday_shown)
	target = ReceiptTarget.new()
	column.add_child(target)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.sort_children.connect(_on_scroll_sorted)
	column.add_child(_scroll)
	target.minimum_size_changed.connect(_queue_fit)
	_inset = MarginContainer.new()
	_inset.name = "Inset"
	_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Fills a scroll area taller than its lines: planning's spacer then pins the foot at the bottom.
	_inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	gold = ReceiptGold.new(self, target)
	add_child(gold)
	# Over the metal (ReceiptGold draws first), under the ink: payday's design, then the tail.
	draw.connect(_draw_extras)


## Fit-up mode (#80): the receipt stands on `bottom` (the parent's coordinates) and is as tall as
## its lines, up to `top` at most; past that it ends there, scrolled to its newest line (or its
## framed one), with no scroll bar (the mouse wheel still scrolls). It fits again whenever its
## lines change. With `hang_down` (fit-down mode, left column v2) it hangs from `top` instead (the
## printer's slot) and grows down to `bottom` at most (ReceiptHang: an anchored count's lines feed
## it down, the next day's stub pops).
func fit_up(bottom: float, top: float, hang_down: bool = false) -> void:
	if hang_down and hang == null:
		hang = ReceiptHang.new(self, top)
		hang.on_step = func() -> void: _scroll.scroll_vertical = _scroll_target()
	_stand_bottom = bottom
	_cap_top = top
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if not _inset.minimum_size_changed.is_connected(_queue_fit):
		_inset.minimum_size_changed.connect(_queue_fit)
	fit_height()


## Fits the receipt's height to its lines (fit-up and fit-down modes only; see fit_up()), then
## scrolls to its end (or its framed line).
func fit_height() -> void:
	_fit_queued = false
	if _stand_bottom < 0.0:
		return
	if hang != null:
		_snap_to_end = true
		hang.fit(_hang_height(), _print != null and not reduced_motion)
		_scroll.queue_sort()
		scroll_to_end()
		return
	var frame: float = get_theme_stylebox("panel").get_minimum_size().y
	var room: float = _stand_bottom - _cap_top
	# As tall as its lines, up to its room; planning's paper is the header alone (2026-11-08
	# feedback: no empty band). An anchored count's paper reaches its room's top from its start, so
	# its rows print in place and never move: longer lines (a full belt's rows, then the dessert's)
	# scroll under the pinned header, so the header (H2: the hero, the target, BEATEN!) never rises
	# off the screen.
	var tall: float = minf(natural_height(), room)
	if _print != null:
		tall = room
	# The newest line stays in view in the very frame the receipt grows or shrinks.
	_snap_to_end = true
	size.y = maxf(tall, frame)
	position.y = _stand_bottom - size.y
	# Sorted after the panel gives the scroll area its new size (the scroll area doesn't always
	# sort itself on a resize), so _on_scroll_sorted sees it.
	_scroll.queue_sort()
	scroll_to_end()


## The paper's height in fit-down mode: its lines', its room's at most, its frame's at least.
func _hang_height() -> float:
	var frame: float = get_theme_stylebox("panel").get_minimum_size().y
	return clampf(natural_height(), frame, maxf(_stand_bottom - _cap_top, frame))


## The lines' natural height plus the target's (and payday's ribbon's) and the paper's frame: how
## tall the receipt is when nothing stops it. (A ScrollContainer reports no content height: the
## inset's own minimum is the content.)
func natural_height() -> float:
	var frame: float = get_theme_stylebox("panel").get_minimum_size().y
	return _inset.get_combined_minimum_size().y + _pinned_height() + frame


## The header's height over the scrolling lines: the target and payday's ribbon.
func _pinned_height() -> float:
	var pinned: float = target.get_combined_minimum_size().y if target.visible else 0.0
	if payday_ribbon.visible:
		pinned += ReceiptPayday.height()
	return pinned


## Shows the newest line (or the framed one): scrolls once the new lines are laid out.
func scroll_to_end() -> void:
	_scroll_to_end.call_deferred()


func clear() -> void:
	_total_line = null
	_total_rule = null
	_footer = null
	_framed = null
	_print = null
	_planning = false
	_inset.add_theme_constant_override("margin_bottom", int(FRAME_GROW))
	_items.clear()
	_last.clear()
	_item_names.clear()
	_sums.clear()
	_closing.clear()
	_figures.clear()
	_cards = []
	_inset.queue_redraw()
	for line: Node in _lines.get_children():
		_lines.remove_child(line)
		line.queue_free()


## Starts a receipt: clears it, then prints `header` (a Double checkout's row line; none when
## empty), small.
func begin(header: PackedStringArray = PackedStringArray()) -> void:
	clear()
	for text: String in header:
		var line: Control = add_line(text, "", LineStyle.DETAIL)
		(line.get_child(0) as Label).add_theme_font_size_override("font_size", FOOTER_FONT_SIZE)


## Starts the count-up's receipt (and a resumed checkout's, show_result). An anchored receipt
## showing planning prints the items' rows under its header as the count reaches them
## (ReceiptPrintRows: `header` above them, the header's caption TOTAL). Any other prints `header`
## and its dashed rule (none without a header), then (with `footer`) "tap: skip · hold: fast";
## the items print line by line as they scan (#61, #105 piece 2), each named from `names`, above
## the TOTAL line's dashed rule, which shows with the TOTAL at the end (add_total). `cards` are the
## items' cards (their minis and arm words).
func begin_count(
	header: PackedStringArray,
	names: PackedStringArray,
	footer: bool = true,
	cards: Array[CardDefinition] = []
) -> void:
	if anchored and _planning:
		begin(header)
		_cards = cards
		target.begin_count(0)
		_print = ReceiptPrintRows.new(
			self, _lines, names, cards, _row_pitch(names.size()), reduced_motion
		)
		if hang != null:
			hang.finish_pop()
		_queue_fit()
		count_paper_started.emit()
		return
	begin(header)
	_cards = cards
	if not header.is_empty():
		_lines.add_child(ReceiptDecor.dashed_rule())
	for slot: int in range(names.size()):
		_item_names[slot] = names[slot]
	_total_rule = ReceiptDecor.dashed_rule()
	_total_rule.visible = false
	_lines.add_child(_total_rule)
	if footer:
		_footer = add_line(COUNT_FOOTER_TEXT, "", LineStyle.WAITING)
		(_footer.get_child(0) as Label).add_theme_font_size_override("font_size", FOOT_FONT_SIZE)


## The planning receipt (H2 of main scene v2): `header` (a Double checkout's row line; none when
## empty) and no item rows. The header shows PROJECTED with `result`'s total against `quota` (none
## when negative), rolling to it from the number shown (ReceiptTarget.show_planned; at once under
## `reduced_motion` or a first show). `names`, `cards` and `open_slots` are kept for the count's
## rows and a copy (planned_slots).
func show_planning(
	header: PackedStringArray,
	result: ScoreResult,
	names: PackedStringArray,
	open_slots: int,
	quota: int = -1,
	cards: Array[CardDefinition] = []
) -> void:
	var after_count: bool = _print != null
	begin(header)
	_planning = true
	planned_slots = open_slots
	_cards = cards
	for slot: int in range(names.size()):
		_item_names[slot] = names[slot]
	target.show_planned(result.total, quota, not _still())
	_queue_fit()
	if hang != null:
		var followed: bool = after_count and anchored and is_inside_tree()
		var pop: bool = followed and not _still()
		if pop:
			hang.pop(_hang_height())
		stub_printed.emit(pop, followed)


## The count's reading `value` (the LED's, ReceiptCountFlow): an anchored count's hero and its
## rolling row's amount follow it. Nothing for any other receipt.
func show_running(value: int) -> void:
	if _print == null:
		return
	target.show_running(value)
	_print.roll(value)


## The rows an anchored count printed (ReceiptPrintRows), in slot order; none for any other.
func printed_rows() -> Array[Control]:
	var none: Array[Control] = []
	return _print.rows() if _print != null else none


## Whether planning's projected number shows at once (planning_still).
func _still() -> bool:
	return planning_still.is_valid() and bool(planning_still.call())


## A money amount as the receipt prints it: "3€", or "+15€" when `signed` ("−2€" for a fall: Late
## delivery's, v0.69). Every score is whole euros (ScoreResult, ScoreStep: ints), so nothing
## rounds.
static func money(euros: int, signed: bool = false) -> String:
	var prefix: String = "" if not signed else "+" if euros >= 0 else "−"
	return prefix + MONEY_TEXT % (absi(euros) if signed else euros)


## `slot`'s mark in `result`, read from its recorded amounts: DENIED when an inspection's
## PAYOUT_OVERRIDE is on it, else FIZZLED when a WASTED step of its own is on it (even when
## another card raises its payout: since #45 an unpaired Banana or Cheese that another card boosts
## fizzles too; an upgrade's row-wide fizzle on the last slot is not the item's:
## ScoreStep.row_wide), else NONE.
static func slot_mark(result: ScoreResult, slot: int) -> Mark:
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
	if fizzled:
		return Mark.FIZZLED
	return Mark.NONE


## The whole receipt at once, under `header` (none when empty): a resumed
## checkout's, as the count-up printed it (begin_count without its footer, then every step and
## the total), and the tests' expected receipts. `upgrade_names` are the run's upgrades' names in
## pick order and `inspection_names` the shift's inspections' names, for the lines they cause;
## `cards` the items' cards (begin_count).
func show_result(
	result: ScoreResult,
	names: PackedStringArray,
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_names: PackedStringArray = PackedStringArray(),
	header: PackedStringArray = PackedStringArray(),
	cards: Array[CardDefinition] = []
) -> void:
	begin_count(header, names, false, cards)
	for step: ScoreStep in result.steps:
		add_step(step, names, upgrade_names, inspection_names)
	add_total(result.total)


## Prints one step and returns what the count-up animates: a BASE step fills its item's line in
## (its base amount, in ink, kept for good) and returns the line; a PAYOUT step prints the
## closing line "= payout€" when the item's printed amount (its BASE step's value plus its FLAT
## and COPY steps', a PAYOUT_OVERRIDE step's value replacing the sum) is not its value, and
## returns that line's amount label; else it prints nothing and returns the item line's amount
## label when nothing printed under the item (a plain card: its amount fades in on the beat), or
## null (its amount has shown since its BASE step: nothing new to fade in). Any other step prints
## its line under its item's earlier lines (above its closing line, which stays last) and
## returns it. The printed or filled line is framed (the item's line when a PAYOUT step prints
## nothing). Returns null for a step that prints no line. An item with no line yet (no
## begin_count) gets one, at the end. The item's payout figure prints bold (for an item whose
## + lines add up to it, the last + amount, which completes it), a × amount amber, and an
## EFFECT_ARMED step its "arms" sub line (ReceiptInk.arm_line; no amount).
func add_step(
	step: ScoreStep,
	names: PackedStringArray,
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_names: PackedStringArray = PackedStringArray()
) -> Control:
	if _print != null:
		return _print.step(step)
	return _print_step(step, names, upgrade_names, inspection_names)


## add_step's printed lines (not an anchored count's).
func _print_step(
	step: ScoreStep,
	names: PackedStringArray,
	upgrade_names: PackedStringArray,
	inspection_names: PackedStringArray
) -> Control:
	if step.step_type == ScoreStep.StepType.EFFECT_ARMED:
		var card: CardDefinition = _cards[step.slot] if step.slot < _cards.size() else null
		var words: String = "  " + ReceiptInk.arm_words(step, card)
		return ReceiptInk.arm_line(_add_group_line(step.slot, words, "", LineStyle.DETAIL))
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
				_figures[step.slot] = amount
			if step.step_type == ScoreStep.StepType.BASE:
				_set_frame(item)
				return item
			if printed == step.value:
				_set_frame(item)
				if _figures.has(step.slot):
					ReceiptInk.embolden(_figures[step.slot])
				return amount if _last.get(step.slot) == item else null
			var closing: Control = _add_group_line(
				step.slot, "", CLOSING_TEXT + text[1], LineStyle.CLOSING
			)
			_closing[step.slot] = closing
			ReceiptInk.embolden(closing.get_child(1) as Label)
			return closing.get_child(1) as Label
		ScoreStep.StepType.FLAT, ScoreStep.StepType.COPY:
			var so_far: int = _sums.get(step.slot, 0)
			_sums[step.slot] = so_far + step.value
		ScoreStep.StepType.PAYOUT_OVERRIDE:
			_sums[step.slot] = step.value
	var line: Control = _add_group_line(step.slot, text[0], text[1], step_style(step))
	match step.step_type:
		ScoreStep.StepType.WASTED:
			ReceiptDecor.mark(line as HBoxContainer, Mark.FIZZLED)
		ScoreStep.StepType.MULTIPLIER:
			ReceiptInk.amber(line.get_child(1) as Label)
		ScoreStep.StepType.PAYOUT_OVERRIDE, ScoreStep.StepType.FLAT, ScoreStep.StepType.COPY:
			_figures[step.slot] = line.get_child(1) as Label
	if step.source_kind == ScoreStep.SourceKind.UPGRADE and step_style(step) == LineStyle.COMBO:
		ReceiptDecor.perk(line)
	return line


## Prints a line ("left", "right", in `style`) into `slot`'s group, after its earlier lines but
## above its closing line, and frames it.
func _add_group_line(
	slot: int, left: String, right: String, style: LineStyle = LineStyle.ITEM
) -> Control:
	# A count prints an item's line as its first line does (its amount once its base lands).
	if _item_line_of(slot) == null and _item_names.has(slot):
		_item_line(slot, _item_names[slot])
	var line: Control = add_line(left, right, style)
	_lines.move_child(line, mini(_group_index(slot), _lines.get_child_count() - 1))
	if not _closing.has(slot):
		_last[slot] = line
	_set_frame(line)
	return line


## The receipt's words for one step: its left side (with its indent and marker) and its right side
## (the amount, or nothing: a fizzle's mark says "WASTED"), or none for a step that prints no
## line. A BASE or PAYOUT step's left side is its item's name: it fills the item's line (add_step).
static func step_text(
	step: ScoreStep,
	names: PackedStringArray,
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_names: PackedStringArray = PackedStringArray()
) -> PackedStringArray:
	var cause: String = source_text(step, upgrade_names, inspection_names)
	if step.step_type == ScoreStep.StepType.MULTIPLIER:
		cause = ReceiptCause.multiplier(step, upgrade_names, inspection_names)
	var left: String = ""
	var right: String = ""
	match step.step_type:
		ScoreStep.StepType.TAG_ADDED:
			left = "  %s: %s gains %s" % [step.text, names[step.slot], step.tag]
		ScoreStep.StepType.LINKED:
			left = "  %s links %s + %s" % [step.text, names[step.slot], names[step.linked_slot]]
		ScoreStep.StepType.WRITTEN_OFF:
			left = "  %s: %s" % [step.text, names[step.slot]]
			right = EffectLink.WRITTEN_OFF_WORD
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
			right = step.times_text()
		ScoreStep.StepType.COPY:
			left = "  %s: copy of %s" % [step.text, names[step.linked_slot]]
			right = money(step.value, true)
		ScoreStep.StepType.PAYOUT_OVERRIDE:
			left = "  " + cause
			right = "= " + money(step.value)
		ScoreStep.StepType.EFFECT_ARMED:
			# No words: add_step prints its arm line (ReceiptInk), not a step line.
			return PackedStringArray()
		ScoreStep.StepType.CREDIT:
			# A label, not an addend (#108 piece 2): the amount is in its words, already counted
			# in the item's payout, so the right side stays empty.
			left = "  %s earned %s (%s)" % [cause, money(step.value), step.reason]
	return PackedStringArray([left, right])


## A step's line style: CONTEXT for a tag, a link or a write-off, FIZZLE for a fizzle, ITEM for
## a base or a payout (its item's line), COMBO for a combo (is_combo), DETAIL for the rest.
static func step_style(step: ScoreStep) -> LineStyle:
	match step.step_type:
		ScoreStep.StepType.TAG_ADDED, ScoreStep.StepType.LINKED, ScoreStep.StepType.WRITTEN_OFF:
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
## item's scan footer). A bonus reads as B2 words it, its amount first ("+15€ Category engine",
## "×2 Multipack"; a copy names its source, "Copied from Bread  3€", MonitorText.copied_from); a
## base "MILK  2", a payout "17€", an override
## "Spot check: the 3rd product pays 0€  = 0"; the others are the receipt's left side without its
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
			return "%s %s" % [MonitorText.signed_euros(step.value), cause]
		ScoreStep.StepType.MULTIPLIER:
			return (
				step.times_text()
				+ " "
				+ ReceiptCause.multiplier(step, upgrade_names, inspection_names)
			)
		ScoreStep.StepType.COPY:
			return MonitorText.copied_from(names[step.linked_slot], step.value)
		ScoreStep.StepType.BASE:
			return joined_line(names[step.slot].to_upper(), str(step.value))
		ScoreStep.StepType.PAYOUT:
			return MonitorText.euros(step.value)
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
## inspection's name (plan section 3.9): "Spot check: the 3rd product pays 0€".
static func source_text(
	step: ScoreStep,
	upgrade_names: PackedStringArray,
	inspection_names: PackedStringArray = PackedStringArray()
) -> String:
	return ReceiptCause.of(step, step.text, upgrade_names, inspection_names)


## The TOTAL line ("TOTAL 22€"): after a count's lines, under its dashed rule (begin_count),
## which also ends the count-up's footer and frame; else a new one under a solid rule. An
## anchored count's header shows `total` instead (every row at its payout); returns the header.
func add_total(total: int) -> Control:
	if _print != null:
		_print.finish()
		target.show_running(total)
		return target
	_set_frame(null)
	if is_instance_valid(_footer):
		_lines.remove_child(_footer)
		_footer.queue_free()
	_footer = null
	if is_instance_valid(_total_rule):
		_total_rule.visible = true
	_total_line = add_line(TOTAL_TEXT, money(total), LineStyle.TOTAL) as HBoxContainer
	return _total_line


## A notice under the total (plan section 3.9): the next inspection in red, a boon day's green.
func add_notice(text: String) -> Control:
	return add_line(text, "", LineStyle.NOTICE)


## The shift's end at once, as the dessert leaves it (#61): the verdict, the margin (PAID on a
## pass), INSPECTION PASSED naming `inspection` (#77; none when empty), the tear and `notice`
## (none when empty). An anchored count's paper ends at its rows (the user's play test of
## 2026-11-09): the margin and PAID on its header, nothing printed under them.
func show_shift_end(total: int, quota: int, notice: String = "", inspection: String = "") -> void:
	var margin: ShiftMargin = ShiftMargin.of(total, quota)
	show_verdict(total, quota)
	var line: Control = add_margin(margin)
	if margin.passed():
		ReceiptStamps.stamp_paid(line)
	if _print != null:
		return
	if margin.passed():
		if not inspection.is_empty():
			ReceiptStamps.stamp_inspection(self, inspection)
	add_tear()
	if not notice.is_empty():
		add_notice(notice)


## The TOTAL line's "total€ / quota€" (#61; since #80 it prints plainly, and the dessert's slam
## lands on the monitor).
static func verdict_text(total: int, quota: int) -> String:
	return "%s / %s" % [money(total), money(quota)]


## Shows the verdict on the TOTAL line at once: its right side reads "total€ / quota€" at
## VERDICT_FONT_SIZE across the mark column (down to VERDICT_MIN_FONT_SIZE when it would not
## fit beside TOTAL), green on a pass and red on a miss. Returns that label (null when no
## TOTAL line was printed, and for an anchored count: its hero and target say it).
func show_verdict(total: int, quota: int) -> Label:
	if _print != null:
		return null
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
	label.add_theme_font_size_override(
		"font_size",
		ReceiptInk.fit_font_size(label.text, room, VERDICT_FONT_SIZE, VERDICT_MIN_FONT_SIZE)
	)
	label.add_theme_color_override(
		"font_color", Palette.GOOD if ShiftMargin.of(total, quota).passed() else Palette.TOMATO
	)
	return label


## The TOTAL line's right-hand label (the total, then the verdict), or null before a total.
func total_label() -> Label:
	if _total_line == null or not is_instance_valid(_total_line):
		return null
	return _total_line.get_child(1) as Label


## The margin line under the total, showing the whole margin (ReceiptTarget.margin_text), red when
## short, else green. The dessert counts it up with ReceiptTarget.show_margin. An anchored count's
## margin words go on its header's line against the target (returned), its PAID or SLIP stamped
## after them there: no line prints under the rows.
func add_margin(margin: ShiftMargin) -> Control:
	if _print != null:
		return target.show_margin_words(margin)
	var text: String = ReceiptTarget.margin_text(margin.kind(), margin.amount())
	var line: Control = add_line(text, "", LineStyle.MARGIN)
	var color: Color = Palette.TOMATO if margin.kind() == ShiftMargin.Kind.SHORT else Palette.GOOD
	for label: Node in line.get_children():
		(label as Label).add_theme_color_override("font_color", color)
	return line


## The receipt tears off under the shift's lines: a torn edge, clipped to the receipt's width.
func add_tear() -> Control:
	return add_line(TEAR_PATTERN.repeat(TEAR_REPEAT), "", LineStyle.TEAR)


func add_line(left: String, right: String, style: LineStyle) -> Control:
	var line: HBoxContainer = HBoxContainer.new()
	var left_label: Label = ReceiptDecor.line_label(left, style)
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
	var right_label: Label = ReceiptDecor.line_label(right, style)
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# The amount sits on the line's last row when the left side wraps.
	right_label.size_flags_vertical = Control.SIZE_FILL
	right_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	if ReceiptDecor.has_mark_column(style):
		var column: StyleBoxEmpty = StyleBoxEmpty.new()
		column.content_margin_right = MARK_COLUMN
		if style == LineStyle.FIZZLE:
			# The reason takes the rest of the line: no amount, so no gap before the mark.
			column.content_margin_right = FIZZLE_MARK_COLUMN
			line.add_theme_constant_override("separation", 0)
		right_label.add_theme_stylebox_override("normal", column)
	line.add_child(right_label)
	if style == LineStyle.TOTAL and not is_instance_valid(_total_rule):
		_lines.add_child(HSeparator.new())
	elif style == LineStyle.PROJECTED:
		_lines.add_child(ReceiptDecor.dashed_rule())
	_lines.add_child(line)
	scroll_to_end()
	return line


## An anchored count's rows' pitch for `count` items: what the paper leaves under the header and
## its lines so far, shared by them (ReceiptRows), MAX_PITCH at most, MIN_PITCH at least.
func _row_pitch(count: int) -> float:
	if _stand_bottom < 0.0:
		return ReceiptRows.MAX_PITCH
	var frame: float = get_theme_stylebox("panel").get_minimum_size().y
	var room: float = _stand_bottom - _cap_top - frame - _pinned_height()
	room -= _inset.get_combined_minimum_size().y
	return maxf(ReceiptRows.pitch_for(room, count), ReceiptRows.MIN_PITCH)


static func text_width(text: String, font: Font, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## A new item line for `slot` ("left", "right"), in scan order: above the group of the next slot
## that has a line already (a tag or link on a later item prints before the earlier items' bases),
## else above the TOTAL line's rule.
func _add_item(slot: int, left: String, right: String) -> HBoxContainer:
	var line: HBoxContainer = add_line(left, right, LineStyle.ITEM) as HBoxContainer
	var card: CardDefinition = _cards[slot] if slot < _cards.size() else null
	ReceiptInk.add_item_mini(line.get_child(0) as Label, ReceiptInk.item_art(card))
	var after: int = -1
	for other: int in _items:
		if other > slot and _item_line_of(other) != null and (after == -1 or other < after):
			after = other
	_lines.move_child(line, _items[after].get_index() if after != -1 else _end_index(line))
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


## Where the scroll goes (ReceiptDecor.scroll_target): in fit-down mode the top while the paper
## still has room for its lines (a feed reveals the newest line at the free end).
func _scroll_target() -> int:
	if hang != null and natural_height() <= _stand_bottom - _cap_top + 0.5:
		return 0
	return ReceiptDecor.scroll_target(_scroll, _lines, _framed_line())


## Over the metal, under the ink: payday's design (its brass foot on the tail), else the tail.
func _draw_extras() -> void:
	if payday_ribbon.visible:
		var header: float = get_theme_stylebox("panel").get_margin(SIDE_TOP) + _pinned_height()
		payday_ribbon.draw_paper(self, header, gold, hang != null)
	elif hang != null:
		ReceiptHang.draw_tail(self, size, gold.face_colour())


## Payday's ribbon shows or hides: the paper redraws its design and fits its new header.
func _on_payday_shown() -> void:
	queue_redraw()
	_queue_fit()
