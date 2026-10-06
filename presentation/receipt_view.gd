class_name ReceiptView
extends PanelContainer
## The receipt: one line per ScoreStep, printed from the steps alone so it can never disagree
## with the score. Used for the live preview (all lines at once) and the count-up (line by
## line, as each step plays).

enum LineStyle { DETAIL, ITEM, CONTEXT, FIZZLE, TOTAL }

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


## The whole receipt at once, for the live preview.
func show_result(result: ScoreResult, names: PackedStringArray) -> void:
	clear()
	for step: ScoreStep in result.steps:
		add_step(step, names)
	add_total(result.total)


## Prints the line for one step and returns it, so the count-up can animate it.
func add_step(step: ScoreStep, names: PackedStringArray) -> Control:
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
			left = "  %s: %s" % [step.text, step.reason]
			right = "fizzle"
			style = LineStyle.FIZZLE
		ScoreStep.StepType.BASE:
			left = names[step.slot].to_upper()
			right = str(step.value)
		ScoreStep.StepType.FLAT:
			left = "  + " + step.text
			right = "+%d" % step.value
		ScoreStep.StepType.MULTIPLIER:
			left = "  × " + step.text
			right = "×%d" % step.value
		ScoreStep.StepType.COPY:
			left = "  %s: copy of %s" % [step.text, names[step.linked_slot]]
			right = "+%d" % step.value
		ScoreStep.StepType.PAYOUT_OVERRIDE:
			left = "  " + step.text
			right = "= %d" % step.value
		ScoreStep.StepType.PAYOUT:
			right = "€%d" % step.value
			style = LineStyle.ITEM
	return add_line(left, right, style)


func add_total(total: int) -> Control:
	return add_line("TOTAL", "€%d" % total, LineStyle.TOTAL)


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
