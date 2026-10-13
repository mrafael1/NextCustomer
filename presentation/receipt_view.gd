class_name ReceiptView
extends PanelContainer
## The receipt: one line per ScoreStep, printed from the steps alone so it can never disagree
## with the score. Used for the live preview (all lines at once) and the count-up (line by
## line, as each step plays). After a checkout, the shift's dessert (#61) ends it: the verdict
## "€total / €quota" on the TOTAL line, the margin line under it (with PAID on a pass), the tear,
## then the next shift's red notice (show_shift_end prints them all at once).

enum LineStyle { DETAIL, ITEM, CONTEXT, FIZZLE, TOTAL, NOTICE, MARGIN, TEAR }

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

var _lines: VBoxContainer
var _scroll: ScrollContainer
## The last TOTAL line printed, or null.
var _total_line: HBoxContainer


func _init() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_lines = VBoxContainer.new()
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.add_theme_constant_override("separation", 1)
	_scroll.add_child(_lines)


func clear() -> void:
	_total_line = null
	for line: Node in _lines.get_children():
		_lines.remove_child(line)
		line.queue_free()


## The whole receipt at once, for the live preview. `upgrade_names` are the run's upgrades'
## names in pick order and `inspection_names` the shift's inspections' names, for the lines
## they cause.
func show_result(
	result: ScoreResult,
	names: PackedStringArray,
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_names: PackedStringArray = PackedStringArray()
) -> void:
	clear()
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
	var cause: String = source_text(step, upgrade_names, inspection_names)
	var left: String = ""
	var right: String = ""
	var style: LineStyle = LineStyle.DETAIL
	match step.step_type:
		ScoreStep.StepType.TAG_ADDED:
			left = "%s: %s gains %s" % [step.text, names[step.slot], step.tag]
			style = LineStyle.CONTEXT
		ScoreStep.StepType.LINKED:
			left = "%s links %s + %s" % [step.text, names[step.slot], names[step.linked_slot]]
			style = LineStyle.CONTEXT
		ScoreStep.StepType.WASTED:
			left = "  %s: %s" % [cause, step.reason]
			right = "fizzle"
			style = LineStyle.FIZZLE
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
			style = LineStyle.ITEM
		ScoreStep.StepType.EFFECT_ARMED:
			# No line: the receipt stays a straight list of payouts and explanations. What the
			# effect does is printed where it lands (its FLAT or MULTIPLIER line, or a fizzle).
			return null
	return add_line(left, right, style)


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
	line.add_child(left_label)
	var right_label: Label = _label(right, style)
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(right_label)
	if style == LineStyle.TOTAL:
		var rule: HSeparator = HSeparator.new()
		_lines.add_child(rule)
	_lines.add_child(line)
	_scroll_to_end.call_deferred()
	return line


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
		LineStyle.TOTAL:
			font_size = TOTAL_FONT_SIZE
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


## Waits a frame so the new line is laid out before scrolling to it.
func _scroll_to_end() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_inside_tree():
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
