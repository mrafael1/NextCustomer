class_name ReceiptView
extends PanelContainer
## The receipt: one line per ScoreStep, printed from the steps alone so it can never disagree
## with the score. Used for the live preview (all lines at once) and the count-up (line by
## line, as each step plays).

enum LineStyle { DETAIL, ITEM, CONTEXT, FIZZLE, TOTAL, NOTICE }

## Monospace for the receipt (plan section 2). JetBrains Mono, SIL Open Font License.
const MONO_FONT := preload("res://fonts/JetBrainsMono-Regular.ttf")

var _lines: VBoxContainer
var _scroll: ScrollContainer


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
	return add_line("TOTAL", "€%d" % total, LineStyle.TOTAL)


## A red notice under the total (plan section 3.9: the next shift's inspection).
func add_notice(text: String) -> Control:
	return add_line(text, "", LineStyle.NOTICE)


func add_line(left: String, right: String, style: LineStyle) -> Control:
	var line: HBoxContainer = HBoxContainer.new()
	var left_label: Label = _label(left, style)
	left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
			font_size = 22
		LineStyle.NOTICE:
			font_size = 15
			color = Palette.TOMATO
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
