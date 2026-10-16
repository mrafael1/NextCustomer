class_name ReceiptView
extends PanelContainer
## The receipt: one line per ScoreStep, printed from the steps alone so it can never disagree
## with the score. In planning the shift screen shows only its stub (#75, show_stub): the
## header, the projected total and how many fizzles the items show (each step's line is read by
## scanning its item). The count-up starts from the same header (begin) and prints its steps
## under it line by line, as each one plays; a resumed checkout prints them all at once
## (show_result). Every line another source boosts (a combo, is_combo) is marked with a faint
## gold band, a gold bar and a diamond. After a checkout, the shift's dessert (#61) ends it: the
## verdict "€total / €quota" on the TOTAL line, the margin line under it (with PAID on a pass),
## the tear, then the next shift's red notice (show_shift_end prints them all at once). On the
## shift screen it stands on the printer's slot and grows up (fit_up, #80): as tall as its lines,
## up to ShiftStage.RECEIPT_TOP. An indented step line hangs (#55): wrapped, it starts past its
## lead and marker on every row, and its amount (or "fizzle") sits on its last row.

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
	STUB_NOTE,
	COMBO,
}

## Monospace for the receipt (plan section 2). JetBrains Mono, SIL Open Font License.
const MONO_FONT := preload("res://fonts/JetBrainsMono-Regular.ttf")
## The TOTAL line's font size, which the dessert's slam lands at.
const TOTAL_FONT_SIZE := 22
## The PAID stamp on a passed shift's margin line, tilted like a clerk's stamp.
const PAID_TEXT := "PAID"
const PAID_TILT_DEG := -8.0
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
## The planning stub's total line, under a dashed rule (a dash RULE_DASH long, then a gap as
## long), and its fizzle count, which points at the items' fizzle chips.
const PROJECTED_TEXT := "PROJECTED"
const RULE_DASH := 4.0
const FIZZLES_TEXT := "%d fizzles · see the items"
const FIZZLE_TEXT := "1 fizzle · see the item"
## A combo line: a faint gold band behind the whole line with a gold bar on its left, and the
## diamond after the bar; the line's text hangs past both (COMBO_INDENT takes the place of its
## leading spaces), so nothing sits outside the receipt's scroll area.
const COMBO_BAR := 2.0
const COMBO_BAND_ALPHA := 0.25
const COMBO_ICON_RECT := Rect2(4, 3, 10, 10)
const COMBO_INDENT := 18.0
const COMBO_DIAMOND := preload("res://art/icons/combo_diamond.png")

var _lines: VBoxContainer
var _scroll: ScrollContainer
## The last TOTAL line printed, or null.
var _total_line: HBoxContainer
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
	add_theme_stylebox_override("panel", style)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.sort_children.connect(_on_scroll_sorted)
	add_child(_scroll)
	_lines = VBoxContainer.new()
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.add_theme_constant_override("separation", 1)
	_scroll.add_child(_lines)


## Fit-up mode (#80): the receipt stands on `bottom` (the parent's coordinates) and is as tall as
## its lines, up to `top` at most; past that it ends there, scrolled to its newest line, with no
## scroll bar (the mouse wheel still scrolls). It fits again whenever its lines change.
func fit_up(bottom: float, top: float) -> void:
	_stand_bottom = bottom
	_cap_top = top
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if not _lines.minimum_size_changed.is_connected(_queue_fit):
		_lines.minimum_size_changed.connect(_queue_fit)
	fit_height()


## Fits the receipt's height to its lines (fit-up mode only; see fit_up()), then scrolls to its
## end.
func fit_height() -> void:
	_fit_queued = false
	if _stand_bottom < 0.0:
		return
	var frame: float = get_theme_stylebox("panel").get_minimum_size().y
	var room: float = _stand_bottom - _cap_top
	# The newest line stays in view in the very frame the receipt grows or shrinks.
	_snap_to_end = true
	size.y = maxf(minf(natural_height(), room), frame)
	position.y = _stand_bottom - size.y
	# Sorted after the panel gives the scroll area its new size (the scroll area doesn't always
	# sort itself on a resize), so _on_scroll_sorted sees it.
	_scroll.queue_sort()
	scroll_to_end()


## The lines' natural height plus the paper's frame: how tall the receipt is when nothing stops
## it. (A ScrollContainer reports no content height: the lines' own minimum is the content.)
func natural_height() -> float:
	return _lines.get_combined_minimum_size().y + get_theme_stylebox("panel").get_minimum_size().y


## Shows the newest line: scrolls to the end once the new lines are laid out.
func scroll_to_end() -> void:
	_scroll_to_end.call_deferred()


func clear() -> void:
	_total_line = null
	for line: Node in _lines.get_children():
		_lines.remove_child(line)
		line.queue_free()


## Starts a receipt: clears it, then prints `header` (header_lines(); none when empty). The
## count-up starts here, so its lines print under the planning stub's header.
func begin(header: PackedStringArray = PackedStringArray()) -> void:
	clear()
	for text: String in header:
		add_line(text, "", LineStyle.DETAIL)


## The planning stub (#75, decision 1A): `header`, a dashed rule, "PROJECTED €projected", then
## the fizzle count (fizzle_text(); no line without fizzles) and the tear.
func show_stub(header: PackedStringArray, projected: int, fizzles: int) -> void:
	begin(header)
	add_line(PROJECTED_TEXT, "€%d" % projected, LineStyle.PROJECTED)
	if fizzles > 0:
		add_line(fizzle_text(fizzles), "", LineStyle.STUB_NOTE)
	add_tear()


## The header's lines for 1-based `shift` of `shifts` with `items` on the belt (coupons
## included): "NEXT CUSTOMER · REG 3", then "SHIFT n/m · k ITEMS" ("· 1 ITEM" for one).
static func header_lines(shift: int, shifts: int, items: int) -> PackedStringArray:
	var shift_text: String = (
		ITEM_TEXT % [shift, shifts] if items == 1 else SHIFT_TEXT % [shift, shifts, items]
	)
	return PackedStringArray([HEADER_TEXT, shift_text])


## How many of `result`'s steps fizzle (the stub's count): every WASTED step, the upgrades'
## too.
static func fizzle_count(result: ScoreResult) -> int:
	var count: int = 0
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			count += 1
	return count


## The stub's fizzle line: "1 fizzle · see the item", "N fizzles · see the items", or empty for
## none.
static func fizzle_text(fizzles: int) -> String:
	if fizzles <= 0:
		return ""
	return FIZZLE_TEXT if fizzles == 1 else FIZZLES_TEXT % fizzles


## The whole receipt at once, under `header` (header_lines(); none when empty): a resumed
## checkout's, as the count-up printed it, and the tests' expected receipts. `upgrade_names` are
## the run's upgrades' names in pick order and `inspection_names` the shift's inspections'
## names, for the lines they cause.
func show_result(
	result: ScoreResult,
	names: PackedStringArray,
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_names: PackedStringArray = PackedStringArray(),
	header: PackedStringArray = PackedStringArray()
) -> void:
	begin(header)
	for step: ScoreStep in result.steps:
		add_step(step, names, upgrade_names, inspection_names)
	add_total(result.total)


## Prints the line for one step and returns it, so the count-up can animate it. Returns null
## for a step that prints no line.
func add_step(
	step: ScoreStep,
	names: PackedStringArray,
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_names: PackedStringArray = PackedStringArray()
) -> Control:
	var text: PackedStringArray = step_text(step, names, upgrade_names, inspection_names)
	if text.is_empty():
		return null
	return add_line(text[0], text[1], step_style(step))


## The receipt's words for one step: its left side (with its indent and marker) and its right
## side (the amount, "fizzle" or nothing), or none for a step that prints no line. The receipt
## prints them (add_step), and a belt item's scan popup lists them (#75, step_line), so the two
## always word a step alike.
static func step_text(
	step: ScoreStep,
	names: PackedStringArray,
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_names: PackedStringArray = PackedStringArray()
) -> PackedStringArray:
	var cause: String = source_text(step, upgrade_names, inspection_names)
	var left: String = ""
	var right: String = ""
	match step.step_type:
		ScoreStep.StepType.TAG_ADDED:
			left = "%s: %s gains %s" % [step.text, names[step.slot], step.tag]
		ScoreStep.StepType.LINKED:
			left = "%s links %s + %s" % [step.text, names[step.slot], names[step.linked_slot]]
		ScoreStep.StepType.WASTED:
			left = "  %s: %s" % [cause, step.reason]
			right = "fizzle"
		ScoreStep.StepType.BASE:
			left = names[step.slot].to_upper()
			right = str(step.value)
		ScoreStep.StepType.FLAT:
			left = "  + " + cause
			right = "+%d" % step.value
		ScoreStep.StepType.MULTIPLIER:
			left = "  × " + cause
			right = "×%d" % step.value
		ScoreStep.StepType.COPY:
			left = "  %s: copy of %s" % [step.text, names[step.linked_slot]]
			right = "+%d" % step.value
		ScoreStep.StepType.PAYOUT_OVERRIDE:
			left = "  " + cause
			right = "= %d" % step.value
		ScoreStep.StepType.PAYOUT:
			right = "€%d" % step.value
		ScoreStep.StepType.EFFECT_ARMED:
			# No line: the receipt stays a straight list of payouts and explanations. What the
			# effect does is printed where it lands (its FLAT or MULTIPLIER line, or a fizzle).
			return PackedStringArray()
	return PackedStringArray([left, right])


## The style a step's line prints in: CONTEXT for a tag or a link, FIZZLE for a fizzle, ITEM for
## a payout, COMBO for a combo (is_combo), DETAIL for the rest.
static func step_style(step: ScoreStep) -> LineStyle:
	match step.step_type:
		ScoreStep.StepType.TAG_ADDED, ScoreStep.StepType.LINKED:
			return LineStyle.CONTEXT
		ScoreStep.StepType.WASTED:
			return LineStyle.FIZZLE
		ScoreStep.StepType.PAYOUT:
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


## A step's line on one row (#75, a belt item's scan popup): the receipt's left side without its
## indent, then its right side two spaces after it ("+ Strawberries beside Produce  +3",
## "Coffee: no Breakfast product after it  fizzle"). Empty for a step that prints no line.
static func step_line(
	step: ScoreStep,
	names: PackedStringArray,
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_names: PackedStringArray = PackedStringArray()
) -> String:
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
	match step.source_kind:
		ScoreStep.SourceKind.UPGRADE:
			if step.source_index < 0 or step.source_index >= upgrade_names.size():
				return step.text
			var upgrade_name: String = upgrade_names[step.source_index]
			if step.text.is_empty() or step.text == upgrade_name:
				return upgrade_name
			return "%s (%s)" % [step.text, upgrade_name]
		ScoreStep.SourceKind.INSPECTION:
			if step.source_index < 0 or step.source_index >= inspection_names.size():
				return step.text
			var inspection_name: String = inspection_names[step.source_index]
			if step.text.is_empty() or step.text == inspection_name:
				return inspection_name
			return "%s: %s" % [inspection_name, step.text]
	return step.text


func add_total(total: int) -> Control:
	_total_line = add_line("TOTAL", "€%d" % total, LineStyle.TOTAL) as HBoxContainer
	return _total_line


## A red notice under the total (plan section 3.9: the next shift's inspection).
func add_notice(text: String) -> Control:
	return add_line(text, "", LineStyle.NOTICE)


## The shift's end at once, as the dessert leaves it (#61): the verdict on the TOTAL line, the
## margin line (PAID on a pass), the tear and `notice` (none when empty). The receipt ends with
## the TOTAL line.
func show_shift_end(total: int, quota: int, notice: String = "") -> void:
	var margin: ShiftMargin = ShiftMargin.of(total, quota)
	show_verdict(total, quota)
	var line: Control = add_margin(margin)
	if margin.passed():
		stamp_paid(line)
	add_tear()
	if not notice.is_empty():
		add_notice(notice)


## "€total / €quota", as the dessert's slam prints it.
static func verdict_text(total: int, quota: int) -> String:
	return "€%d / €%d" % [total, quota]


## The dessert's slam lands on the TOTAL line: its right side reads "€total / €quota", green
## on a pass and red on a miss. Returns that label (null when no TOTAL line was printed).
func show_verdict(total: int, quota: int) -> Label:
	var label: Label = total_label()
	if label == null:
		return null
	label.text = verdict_text(total, quota)
	label.add_theme_color_override(
		"font_color", Palette.GOOD if ShiftMargin.of(total, quota).passed() else Palette.TOMATO
	)
	return label


## The TOTAL line's right-hand label (the total, then the verdict), or null before a total.
func total_label() -> Label:
	if _total_line == null or not is_instance_valid(_total_line):
		return null
	return _total_line.get_child(1) as Label


## The margin line under the total, showing the whole margin: "+€N OVER QUOTA", "SHORT €N" (red)
## or "ON QUOTA" (green). The dessert counts it up with show_margin.
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
			return "+€%d OVER QUOTA" % euros
		ShiftMargin.Kind.SHORT:
			return "SHORT €%d" % euros
	return "ON QUOTA"


## PAID is stamped on a passed shift's margin `line`, tilted. Returns the stamp's label.
static func stamp_paid(line: Control) -> Label:
	var stamp: Label = line.get_child(1) as Label
	stamp.text = PAID_TEXT
	stamp.add_theme_color_override("font_color", Palette.TOMATO)
	_tilt(stamp)
	# A container sets its children's rotation back to 0 whenever it sorts them.
	(line as Container).sort_children.connect(_tilt.bind(stamp))
	return stamp


static func _tilt(stamp: Label) -> void:
	stamp.pivot_offset = stamp.size / 2.0
	stamp.rotation = deg_to_rad(PAID_TILT_DEG)


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
	if style == LineStyle.DETAIL or style == LineStyle.FIZZLE:
		_hang(left_label)
	elif style == LineStyle.COMBO:
		_hang(left_label, COMBO_INDENT)
		_mark_combo(line, left_label)
	line.add_child(left_label)
	var right_label: Label = _label(right, style)
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# The amount sits on the line's last row when the left side wraps.
	right_label.size_flags_vertical = Control.SIZE_FILL
	right_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	line.add_child(right_label)
	if style == LineStyle.TOTAL:
		_lines.add_child(HSeparator.new())
	elif style == LineStyle.PROJECTED:
		_lines.add_child(_dashed_rule())
	_lines.add_child(line)
	scroll_to_end()
	return line


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


## Hangs an indented line's left `label`: its text starts past its lead and marker on every
## wrapped row (an empty "normal" style's left margin), the marker printed beside the first row
## (a "Marker" label inside it). The lead is its leading spaces' width, or `lead_width` when
## that is set (a combo line's COMBO_INDENT). A line without leading spaces is left as it is.
static func _hang(label: Label, lead_width: float = -1.0) -> void:
	var parts: PackedStringArray = hang_parts(label.text)
	if parts[0].is_empty():
		return
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var lead: float = lead_width if lead_width >= 0.0 else _text_width(parts[0], font, font_size)
	var indent: StyleBoxEmpty = StyleBoxEmpty.new()
	indent.content_margin_left = lead + _text_width(parts[1], font, font_size)
	label.add_theme_stylebox_override("normal", indent)
	label.text = parts[2]
	if parts[1].is_empty():
		return
	var marker: Label = Label.new()
	marker.name = "Marker"
	marker.text = parts[1].strip_edges()
	marker.add_theme_font_override("font", font)
	marker.add_theme_font_size_override("font_size", font_size)
	marker.add_theme_color_override("font_color", label.get_theme_color("font_color"))
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.position = Vector2(lead, 0)
	label.add_child(marker)


## Marks a combo `line` (its hung `left` label): the band and bar drawn behind the whole line
## (both sides and every wrapped row), and the diamond (a "ComboDiamond" inside `left`) beside the
## bar, so it is marked by shape, not colour alone.
static func _mark_combo(line: HBoxContainer, left: Label) -> void:
	line.draw.connect(_draw_combo_band.bind(line))
	var diamond: TextureRect = TextureRect.new()
	diamond.name = "ComboDiamond"
	diamond.texture = COMBO_DIAMOND
	diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diamond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	diamond.stretch_mode = TextureRect.STRETCH_SCALE
	ArtStyle.use_pixel_material(diamond)
	diamond.position = COMBO_ICON_RECT.position
	diamond.size = COMBO_ICON_RECT.size
	left.add_child(diamond)


static func _draw_combo_band(line: HBoxContainer) -> void:
	line.draw_rect(Rect2(Vector2.ZERO, line.size), Color(Palette.GOLD, COMBO_BAND_ALPHA))
	line.draw_rect(Rect2(0, 0, COMBO_BAR, line.size.y), Palette.GOLD)


## The stub's rule above PROJECTED: dashes in place of the TOTAL line's solid rule.
static func _dashed_rule() -> HSeparator:
	var rule: HSeparator = HSeparator.new()
	rule.name = "StubRule"
	rule.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	rule.draw.connect(_draw_dashes.bind(rule))
	return rule


static func _draw_dashes(rule: HSeparator) -> void:
	var y: float = roundf((rule.size.y - ArtStyle.ART_SCALE) / 2.0)
	var x: float = 0.0
	while x < rule.size.x:
		var dash: float = minf(RULE_DASH, rule.size.x - x)
		rule.draw_rect(Rect2(x, y, dash, ArtStyle.ART_SCALE), Palette.GREY)
		x += 2.0 * RULE_DASH


static func _text_width(text: String, font: Font, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _label(text: String, style: LineStyle) -> Label:
	var label: Label = Label.new()
	label.text = text
	var font_size: int = 13
	var color: Color = Palette.INK
	match style:
		LineStyle.ITEM:
			font_size = 15
		LineStyle.CONTEXT:
			color = Palette.TEAL
		LineStyle.FIZZLE:
			color = Palette.MUTED_INK
		LineStyle.TOTAL, LineStyle.PROJECTED:
			font_size = TOTAL_FONT_SIZE
		LineStyle.STUB_NOTE:
			color = Palette.TOMATO_DARK
		LineStyle.NOTICE:
			font_size = 15
			color = Palette.TOMATO
		LineStyle.MARGIN:
			font_size = 15
		LineStyle.TEAR:
			color = Palette.MUTED_INK
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
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
	# A scroll clamped during that sort (a taller receipt) moved no line yet: lay them out again.
	_scroll.queue_sort()


## Waits a frame so the new line is laid out before scrolling to it.
func _scroll_to_end() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_inside_tree():
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
