class_name TotalNumber
extends Control
## The monitor's total (#105 piece 2, mock-up readability_v3.html, monitor b): a whole number of
## euros and the € after it ("26€"), in the number font at one size: configure's, or with
## `fit_room` the largest of CountTotalTuning.number_sizes its digit count fits at rest (fit_size:
## every 2-digit total at the mock-up's 38 px; a total gaining a digit steps down as it rolls in,
## one losing one steps back up), each character in its own cell
## (as wide as its glyph plus 1 px; the € euro_gap px after the digits), with a 2 px ink outline, a
## 4 px ink drop and its fill in four gold bands (presentation/gold_bands.gdshader). The group is
## centred on `centre_x` (its parent's coordinates) at the top `top`.
##
## On a new value (set_value) only the digits that change roll, over digit_roll_s of real time
## (a hit-stop never holds a half-rolled digit): the old one slides up and out, the new one up from
## below, centred in the new glyph's cell, on the 2 px grid, clipped to the cell's height only
## while it rolls (the outline stays whole sideways); its first frame is already a frame in, so
## the number never shows the old value at the new spacing while the reading (and the top bar)
## read the new one. Between values the number is still: it never shows a half value. punch() pops
## the group about its centre by its landing's kind (base, +N, ×: 1 + A x (1 - t / punch_s)^2), a
## × also flashes it (brightness flash_mul for flash_s) and a +N or a × runs the shine over it.
## The punch, the flash and the shine run on `make_tween`'s tweens (the count's, so taps, holds
## and hit-stops move them: a hit-stop holds the punch), else its own. Under `reduced_motion`
## nothing rolls, punches, flashes or shines: the number just changes. Display only: the value is
## the reading's.

const SHADER := preload("res://presentation/gold_bands.gdshader")
const OUTLINE := 2
const DROP := 4
## Each cell's room either side for the outline (never clipped sideways).
const PAD := 8.0
## The digits' ink top (the glyph, without its outline) under the cell's top.
const INK_TOP := 4.0
const FILL_COLOR := Palette.GOLD
const INK_COLOR := Palette.INK
const EURO := "€"
## The grid the roll's offset snaps to.
const GRID := 2.0
## How far in a roll's first frame stands at most (its share of digit_roll_s).
const FIRST_ROLL_MAX := 0.5

## Returns a new Tween on the count's clock; none: the number's own.
var make_tween: Callable = Callable()
## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()
## Where the group's centre stands (x, the parent's coordinates) and its top (y).
var centre_x: float = 0.0:
	set(value):
		centre_x = value
		_place()
var top: float = 0.0:
	set(value):
		top = value
		_place()
## The width the number fits at rest for its size (fit_size), its outline included; 0 keeps
## configure's size. A punch may overrun it: the parent clips at the paper, as the mock-up's
## screen does.
var fit_room: float = 0.0

var _tuning: CountTotalTuning
var _font_size: int = 0
var _cell_h: float = 34.0
var _gap: float = 2.0
var _value: int = -1
var _text: String = ""
## One cell per digit, then the €'s.
var _cells: Array[Control] = []
var _euro_cell: Control
var _rolls: Dictionary[int, Tween] = {}
var _whole: Label
var _motion: Tween
var _flash: Tween
var _shine: Tween
var _hidden: bool = false
var _width: float = 0.0
## The digits' ink span from the baseline (x: top, negative; y: bottom).
var _ink: Vector2 = Vector2.ZERO


func _init(tuning: CountTotalTuning = null) -> void:
	name = "TotalNumber"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tuning = tuning if tuning != null else load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning
	_cell_h = _tuning.number_cell_h
	_gap = _tuning.euro_gap
	_whole = _label("")
	_whole.name = "Whole"
	_whole.visible = false
	add_child(_whole)
	var sizes: PackedInt32Array = _tuning.number_sizes
	configure(sizes[0] if not sizes.is_empty() else _tuning.climax_number_size)


## The number's font size (CountTotalTuning.number_sizes; with `fit_room` set_value picks it
## again) and its cells' height (0: CountTotalTuning.number_cell_h; the climax's big number takes
## its own). The value is laid out again at once.
func configure(size_px: int, cell_height: float = 0.0) -> void:
	_font_size = size_px
	_cell_h = cell_height if cell_height > 0.0 else _tuning.number_cell_h
	_ink = ink_span("0", ArtStyle.number_font(), _font_size)
	var shown: int = _value
	_value = -1
	_text = ""
	_rebuild("")
	if shown >= 0:
		set_value(shown, false)


func font_size() -> int:
	return _font_size


## The largest of `sizes` whose group for `amount`'s digit count ("N€", every digit as wide as
## the widest, the € `gap` px after them) as drawn at rest, its ink outline included, is at most
## `room` wide: every amount of one digit count gets one size. The smallest when none is; 0 for no
## sizes.
static func fit_size(amount: int, sizes: PackedInt32Array, room: float, gap: float) -> int:
	var digits: int = ("%d" % maxi(amount, 0)).length()
	for size_px: int in sizes:
		if widest_width(digits, size_px, gap) + 2.0 * OUTLINE <= room:
			return size_px
	return sizes[sizes.size() - 1] if not sizes.is_empty() else 0


## The group's width for `digits` digits, each as wide as the widest digit at `size_px`.
static func widest_width(digits: int, size_px: int, gap: float) -> float:
	var widest: float = 0.0
	for digit: int in range(10):
		widest = maxf(widest, cell_width(str(digit), size_px))
	return widest * digits + gap + cell_width(EURO, size_px)


## The group's width for the digits `digits` at `size_px`: each cell ceil(glyph) + 1 px, the
## gap, then the €'s cell.
static func group_width(digits: String, size_px: int, gap: float) -> float:
	var width: float = 0.0
	for character: String in digits:
		width += cell_width(character, size_px)
	return width + gap + cell_width(EURO, size_px)


static func cell_width(character: String, size_px: int) -> float:
	var font: Font = ArtStyle.number_font()
	var drawn: float = font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	return ceilf(drawn) + 1.0


## Shows `amount`: with `animate` (and not reduced motion) the changed digits roll.
func set_value(amount: int, animate: bool = true) -> void:
	if amount == _value:
		return
	var old_text: String = _text
	_value = amount
	_text = "%d" % maxi(amount, 0)
	var rolls: bool = animate and not _reduced() and not old_text.is_empty()
	var refitted: bool = _fit_to(amount)
	if refitted or old_text.length() != _text.length() or _cells.is_empty():
		_rebuild(old_text if rolls else "")
	else:
		for index: int in range(_text.length()):
			if _text[index] != old_text[index]:
				_set_cell(index, _text[index], old_text[index] if rolls else "")
	_lay_out()
	_whole.text = _text + EURO
	_lay_whole()


func value() -> int:
	return _value


## The digits shown (the € left out).
func text() -> String:
	return _text


## The cells rolling now (their indices), for checks.
func rolling() -> Array[int]:
	var found: Array[int] = []
	for index: int in _rolls:
		var roll: Tween = _rolls[index]
		if roll != null and roll.is_valid() and roll.is_running():
			found.append(index)
	return found


## The cells (digits, then the €), for checks.
func cells() -> Array[Control]:
	var found: Array[Control] = _cells.duplicate()
	if _euro_cell != null:
		found.append(_euro_cell)
	return found


## A landing of `kind` punches the group (none for a WASTE or NONE; a DOWN neither): base, +N or ×.
func punch(kind: CountUpBeat.Land) -> void:
	var amount: float = 0.0
	match kind:
		CountUpBeat.Land.BASE:
			amount = _tuning.punch_base - 1.0
		CountUpBeat.Land.ADD:
			amount = _tuning.punch_add - 1.0
		CountUpBeat.Land.MUL:
			amount = _tuning.punch_mul - 1.0
	if amount <= 0.0 or _reduced():
		return
	_punch(amount)
	if kind == CountUpBeat.Land.MUL:
		_stop(_flash)
		_flash = _new_tween()
		modulate = Color(_tuning.flash_mul, _tuning.flash_mul, _tuning.flash_mul)
		_flash.tween_interval(_tuning.flash_s)
		_flash.tween_callback(func() -> void: modulate = Color.WHITE)
	run_shine()


## The TOTAL line's and the verdict's punch: the ×'s, with the shine.
func punch_total() -> void:
	if _reduced():
		return
	_punch(_tuning.punch_mul - 1.0)
	run_shine()


## The shine runs across the group over shine_s (none under reduced motion).
func run_shine() -> void:
	if _reduced():
		return
	_stop(_shine)
	_shine = _new_tween()
	_shine.tween_method(_set_shine, 0.0, 1.0, _tuning.shine_s)
	_shine.tween_callback(_set_shine.bind(-1.0))


## The shine at `progress` across the group (-1: none), for the climax's own timing.
func set_shine(progress: float) -> void:
	_set_shine(progress)


## The punch's scale now.
func punch_scale() -> float:
	return scale.x


## The group's glyph ink as drawn now (global): the digits' and the €'s ink without the outline,
## scaled by a punch.
func ink_rect() -> Rect2:
	var base: float = INK_TOP - _ink.x
	var local: Rect2 = Rect2(0.0, INK_TOP, _width, base + _ink.y - INK_TOP)
	var to_global: Transform2D = get_global_transform()
	return Rect2(to_global * local.position, local.size * to_global.get_scale())


## The group's whole drawn rect now (global), its outline and drop included.
func drawn_rect() -> Rect2:
	var base: float = INK_TOP - _ink.x
	var local: Rect2 = Rect2(
		-OUTLINE,
		INK_TOP - OUTLINE,
		_width + 2.0 * OUTLINE,
		base + _ink.y - INK_TOP + 2 * OUTLINE + DROP
	)
	var to_global: Transform2D = get_global_transform()
	return Rect2(to_global * local.position, local.size * to_global.get_scale())


## The dessert's slam (#61): a label of the whole group ("26€") laid over it in its look, and the
## group hidden under the slam until it lands.
func slam_label() -> Label:
	_lay_whole()
	return _whole


func hide_for_slam(out_of_sight: bool) -> void:
	_hidden = out_of_sight
	for cell: Control in cells():
		cell.visible = not out_of_sight


## The ink's top and bottom of `text`'s glyphs, from the baseline (down is positive): their
## outlines' extent, as a glyph's bitmap rect carries padding (and an MSDF font's its range).
static func ink_span(text_shown: String, font: Font, font_size_px: int) -> Vector2:
	var server: TextServer = TextServerManager.get_primary_interface()
	var line: TextLine = TextLine.new()
	line.add_string(text_shown, font, font_size_px)
	var span: Vector2 = Vector2(INF, -INF)
	for glyph: Dictionary in server.shaped_text_get_glyphs(line.get_rid()):
		var font_rid: RID = glyph["font_rid"]
		var index: int = glyph["index"]
		var contours: Dictionary = server.font_get_glyph_contours(font_rid, font_size_px, index)
		var points: PackedVector3Array = contours.get("points", PackedVector3Array())
		for point: Vector3 in points:
			span.x = minf(span.x, point.y)
			span.y = maxf(span.y, point.y)
	return span if span.x <= span.y else Vector2.ZERO


## Rebuilds every cell for _text; a cell whose character differs from `old` (right-aligned, "" for
## none) rolls.
func _rebuild(old: String) -> void:
	for index: int in _rolls:
		_stop(_rolls[index])
	_rolls.clear()
	for cell: Control in cells():
		remove_child(cell)
		cell.queue_free()
	_cells.clear()
	_euro_cell = null
	# Only a number shown before rolls ("" lays the cells out at rest).
	var padded: String = ""
	if not old.is_empty() and old.length() <= _text.length():
		padded = old.lpad(_text.length())
	for index: int in range(_text.length()):
		var cell: Control = _new_cell()
		_cells.append(cell)
		add_child(cell)
		var from: String = padded[index] if not padded.is_empty() else ""
		_set_cell(index, _text[index], from if from != _text[index] else "")
	if not _text.is_empty():
		_euro_cell = _new_cell()
		_euro_cell.name = "Euro"
		add_child(_euro_cell)
		_fill(_euro_cell, EURO)
	_lay_out()
	hide_for_slam(_hidden)


## Cell `index` shows `character`; from `from` ("" or " " for none) it rolls.
func _set_cell(index: int, character: String, from: String) -> void:
	var cell: Control = _cells[index]
	if _rolls.has(index):
		_stop(_rolls[index])
		_rolls.erase(index)
	var label: Label = _fill(cell, character)
	if from.strip_edges().is_empty() and from != " ":
		return
	if not is_inside_tree():
		return
	var old: Label = null
	if not from.strip_edges().is_empty():
		old = _label(from)
		old.name = "Old"
		cell.add_child(old)
		# Centred in the new glyph's cell, as the mock-up's: never left in a wider or narrower one.
		old.size = label.size
		old.position = label.position + Vector2(roundf((label.size.x - old.size.x) / 2.0), 0.0)
		old.material = label.material
	cell.clip_contents = true
	var rest: float = label.position.y
	# The first frame drawn is already a frame in (at most half way): the old digit never shows
	# whole at the new spacing while the reading (and the top bar) read the new one.
	var roll_s: float = maxf(0.001, _tuning.digit_roll_s)
	var first: float = clampf(get_process_delta_time() / roll_s, 0.0, FIRST_ROLL_MAX)
	_roll_to(first, label, old, rest)
	# The roll runs in real time: a hit-stop on its tick never leaves the old digit showing while
	# the reading (and the top bar) already read the new one.
	var roll: Tween = create_tween()
	roll.tween_method(_roll_to.bind(label, old, rest), first, 1.0, roll_s * (1.0 - first))
	roll.tween_callback(_end_roll.bind(cell, old))
	_rolls[index] = roll


## The roll at `progress`: the old character up and out, the new one up from below.
func _roll_to(progress: float, label: Label, old: Label, rest: float) -> void:
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	var offset: float = snappedf(eased * _cell_h, GRID)
	if is_instance_valid(label):
		label.position.y = rest + _cell_h - offset
	if is_instance_valid(old):
		old.position.y = rest - offset


func _end_roll(cell: Control, old: Label) -> void:
	if is_instance_valid(old):
		old.queue_free()
	if is_instance_valid(cell):
		cell.clip_contents = false
		for child: Node in cell.get_children():
			var label: Label = child as Label
			if label != null and label != old:
				label.position.y = _label_y(label)


## `cell`'s one label set to `character` (any other goes), at rest.
func _fill(cell: Control, character: String) -> Label:
	var label: Label = null
	for child: Node in cell.get_children():
		if child is Label and label == null and child.name == "Glyph":
			label = child as Label
		elif child is Label:
			cell.remove_child(child)
			child.queue_free()
	if label == null:
		label = _label(character)
		label.name = "Glyph"
		cell.add_child(label)
	cell.clip_contents = false
	label.text = character
	label.size = Vector2(cell_width(character, _font_size), label.get_minimum_size().y)
	label.position = Vector2(PAD, _label_y(label))
	if label.material == null:
		label.material = _new_material()
	return label


func _new_cell() -> Control:
	var cell: Control = Control.new()
	cell.name = "Cell"
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cell


## A label in the number's look: the number font, gold fill (repainted in bands), ink outline and
## ink drop.
func _label(text_shown: String) -> Label:
	var label: Label = Label.new()
	label.text = text_shown
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", ArtStyle.number_font())
	label.add_theme_font_size_override("font_size", _font_size)
	label.add_theme_color_override("font_color", FILL_COLOR)
	label.add_theme_color_override("font_outline_color", INK_COLOR)
	label.add_theme_color_override("font_shadow_color", INK_COLOR)
	label.add_theme_constant_override("outline_size", OUTLINE)
	label.add_theme_constant_override("shadow_outline_size", OUTLINE)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", DROP)
	label.add_theme_constant_override("line_spacing", 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## A label's top for its baseline to put the digits' ink top at INK_TOP.
func _label_y(label: Label) -> float:
	var font: Font = ArtStyle.number_font()
	var line_h: float = font.get_height(_font_size)
	var baseline_in_label: float = (label.size.y - line_h) / 2.0 + font.get_ascent(_font_size)
	return roundf(INK_TOP - _ink.x - baseline_in_label)


func _new_material() -> ShaderMaterial:
	var material_made: ShaderMaterial = ShaderMaterial.new()
	material_made.shader = SHADER
	material_made.set_shader_parameter(&"shine", -1.0)
	return material_made


## The cells side by side (each its glyph's width; the € after the gap), the group centred.
func _lay_out() -> void:
	var x: float = 0.0
	for cell: Control in _cells:
		var label: Label = _glyph(cell)
		var width: float = cell_width(label.text, _font_size)
		cell.position = Vector2(x - PAD, 0.0)
		cell.size = Vector2(width + 2.0 * PAD, _cell_h)
		x += width
	if _euro_cell != null:
		x += _gap
		var width_euro: float = cell_width(EURO, _font_size)
		_euro_cell.position = Vector2(x - PAD, 0.0)
		_euro_cell.size = Vector2(width_euro + 2.0 * PAD, _cell_h)
		x += width_euro
	_width = x
	size = Vector2(_width, _cell_h)
	pivot_offset = size / 2.0
	for cell: Control in cells():
		for child: Node in cell.get_children():
			var label: Label = child as Label
			if label != null and label.material is ShaderMaterial:
				_map(label.material as ShaderMaterial, cell.position.x + label.position.x, label)
	_place()


## The bands' and the shine's place for a label at `group_x` in the group.
func _map(into: ShaderMaterial, group_x: float, label: Label) -> void:
	var font: Font = ArtStyle.number_font()
	var line_h: float = font.get_height(_font_size)
	var baseline_in_label: float = (label.size.y - line_h) / 2.0 + font.get_ascent(_font_size)
	into.set_shader_parameter(&"ink_top", baseline_in_label + _ink.x)
	into.set_shader_parameter(&"ink_base", baseline_in_label)
	into.set_shader_parameter(&"group_x", group_x)
	into.set_shader_parameter(&"group_w", maxf(1.0, _width))


func _lay_whole() -> void:
	_whole.add_theme_font_size_override("font_size", _font_size)
	_whole.size = Vector2(_width, _whole.get_minimum_size().y)
	_whole.position = Vector2(0.0, _label_y(_whole))
	if _whole.material == null:
		_whole.material = _new_material()
	_map(_whole.material as ShaderMaterial, 0.0, _whole)


## With `fit_room`: the size `amount`'s digit count fits at (fit_size) becomes the number's; true
## when it changed (the cells are built again).
func _fit_to(amount: int) -> bool:
	if fit_room <= 0.0:
		return false
	var wanted: int = fit_size(amount, _tuning.number_sizes, fit_room, _gap)
	if wanted <= 0 or wanted == _font_size:
		return false
	_font_size = wanted
	_ink = ink_span("0", ArtStyle.number_font(), _font_size)
	return true


func _place() -> void:
	position = Vector2(roundf(centre_x - _width / 2.0), top)


func _glyph(cell: Control) -> Label:
	for child: Node in cell.get_children():
		if child is Label and child.name == "Glyph":
			return child as Label
	return null


func _set_shine(progress: float) -> void:
	for cell: Control in cells():
		for child: Node in cell.get_children():
			var label: Label = child as Label
			if label != null and label.material is ShaderMaterial:
				(label.material as ShaderMaterial).set_shader_parameter(&"shine", progress)


func _punch(amount: float) -> void:
	_stop(_motion)
	_motion = _new_tween()
	_motion.tween_method(_punch_at.bind(amount), 0.0, _tuning.punch_s, _tuning.punch_s)
	_motion.tween_callback(func() -> void: scale = Vector2.ONE)


func _punch_at(seconds: float, amount: float) -> void:
	var left: float = 1.0 - seconds / maxf(0.001, _tuning.punch_s)
	scale = Vector2.ONE * (1.0 + amount * left * left)


func _new_tween() -> Tween:
	if make_tween.is_valid():
		var tween: Tween = make_tween.call() as Tween
		if tween != null:
			return tween
	return create_tween()


static func _stop(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
