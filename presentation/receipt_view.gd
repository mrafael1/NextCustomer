class_name ReceiptView
extends PanelContainer
## The receipt: one line per ScoreStep, printed from the steps alone so it can never disagree
## with the score. Used for the live preview (all lines at once) and the count-up (line by
## line, as each step plays). After a checkout, the shift's dessert (#61) ends it: the verdict
## "€total / €quota" on the TOTAL line, the margin line under it (with PAID on a pass), the tear,
## then the next shift's red notice (show_shift_end prints them all at once). On the shift
## screen it is in fit mode (#55): as tall as its lines, down to the paper pile's top. An
## indented step line hangs (#55): wrapped, it starts past its lead and marker on every row, and
## its amount (or "fizzle") sits on its last row.

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
## A step line's marker after its leading spaces (hang_parts()): it is printed beside the first
## row, and the wrapped rows hang under the text after it.
const HANG_MARKERS: Array[String] = ["+ ", "× "]

var _lines: VBoxContainer
var _scroll: ScrollContainer
## The last TOTAL line printed, or null.
var _total_line: HBoxContainer
## In fit mode (fit_mode()): the lowest the receipt's bottom may reach, in the parent's
## coordinates. Empty otherwise.
var _max_bottom: Callable = Callable()
## A fit is queued for the end of this frame's layout.
var _fit_queued: bool = false
## Fit mode: the next layout of the lines scrolls to their end, in the same frame.
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


## Fit mode (#55): the receipt is as tall as its lines, from where it stands down to at most
## `max_bottom`'s value (a Callable returning a float, the parent's coordinates); past that it
## ends there, scrolled to its newest line, with no scroll bar (the mouse wheel still scrolls).
## It fits again whenever its lines change; call fit_height() when `max_bottom` moves.
func fit_mode(max_bottom: Callable) -> void:
	_max_bottom = max_bottom
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if not _lines.minimum_size_changed.is_connected(_queue_fit):
		_lines.minimum_size_changed.connect(_queue_fit)
	fit_height()


## Fits the receipt's height to its lines (fit mode only; see fit_mode()), then scrolls to its
## end.
func fit_height() -> void:
	_fit_queued = false
	if not _max_bottom.is_valid():
		return
	var frame: float = get_theme_stylebox("panel").get_minimum_size().y
	var room: float = float(_max_bottom.call()) - position.y
	# The newest line stays in view in the very frame the receipt grows or shrinks.
	_snap_to_end = true
	size.y = maxf(minf(natural_height(), room), frame)
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
	if style == LineStyle.DETAIL or style == LineStyle.FIZZLE:
		_hang(left_label)
	line.add_child(left_label)
	var right_label: Label = _label(right, style)
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# The amount sits on the line's last row when the left side wraps.
	right_label.size_flags_vertical = Control.SIZE_FILL
	right_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	line.add_child(right_label)
	if style == LineStyle.TOTAL:
		var rule: HSeparator = HSeparator.new()
		_lines.add_child(rule)
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
## (a "Marker" label inside it). A line without leading spaces is left as it is.
static func _hang(label: Label) -> void:
	var parts: PackedStringArray = hang_parts(label.text)
	if parts[0].is_empty():
		return
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var lead: float = _text_width(parts[0], font, font_size)
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


## Fits once, at the end of this frame's layout, however many lines changed.
func _queue_fit() -> void:
	if _fit_queued:
		return
	_fit_queued = true
	fit_height.call_deferred()


## Fit mode: once the scroll area has laid out its new size, scrolls to the end (deferred: the
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
