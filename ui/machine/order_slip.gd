class_name OrderSlip
extends Control
## The stockroom's order slip (#77, look F; build spec 4.2): the receipt fed in, pinned up in the
## stockroom window. A paper slip (zig-zag bottom, tomato pin) headed "ORDER #<shift><chute>7" (a
## bonus ticket's "BONUS #<shift><chute>8", STAMP DAY's "STAMP DAY"; the chute's digit reads "?"
## until a chute is confirmed), the receipt's check line ("SPEND €N ✓", or "INSPECTED ✓"), a dashed
## rule and one line per prize ("n · NEW ITEM", "n · COUPON", "n · STAMP", "n · UPGRADE"; "n · ?"
## until a chute is confirmed). Each line's box ticks at its bay pick (a check mark, not only a
## colour), and the tilted PACKED stamp lands once the last box is picked.
##
## The root gives the visit's static data (show_order); frame(t) reads only view.plan and t: the
## slip slides down out of the slot as the receipt is fed (a bonus ticket's stub likewise; STAMP
## DAY's slip is already up), the ticks and the PACKED stamp's pop.

const SIZE := Vector2(102, 146)
## The paper inside the clip, its rest position and how far above it the slip starts.
const PAPER_RECT := Rect2(6, 8, 88, 128)
const SLIDE := 144.0
## The slip slides down until the feed's end plus SLIDE_TAIL_S.
const SLIDE_TAIL_S := 0.35
## A line's box ticks TICK_S after its bay pick (at once under reduced motion).
const TICK_S := 0.15
const PADDING := Vector2(6, 8)
const TITLE_SIZE := 12
const CHECK_SIZE := 8
const CHECK_HEIGHT := 12.0
const LINE_SIZE := 8
const LINE_HEIGHT := 15.0
const BOX := 10.0
const RULE_GAP := Vector2(3, 4)
const PACKED_TEXT := "PACKED"
const PACKED_SIZE := 12
const PACKED_AT := Vector2(10, 92)
const PACKED_TILT := -8.0
const PACKED_POP := 1.6
const PRIZE_WORDS: Array[String] = ["NEW ITEM", "COUPON", "STAMP", "UPGRADE"]
const BOLD_WEIGHT := 800
const SHADOW := 2.0
## The zig-zag bottom: TEETH teeth, each ZIG px deep.
const TEETH := 12
const ZIG := 4.0
const PIN := Rect2(38, 0, 12, 8)

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _paper: Control
var _title: Label
var _number: Label
var _check: Label
var _lines: Array[Label] = []
var _ticked: Array[bool] = []
var _packed: Label
var _packed_shown: bool = false
var _may_pack: bool = false


func _init() -> void:
	name = "OrderSlip"
	size = SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper = Control.new()
	_paper.name = "Paper"
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.position = PAPER_RECT.position
	_paper.size = PAPER_RECT.size
	_paper.draw.connect(_draw_paper)
	add_child(_paper)
	_title = UiKit.display_label("", TITLE_SIZE, false)
	_title.name = "Title"
	_title.position = PADDING
	_paper.add_child(_title)
	_number = UiKit.display_label("", TITLE_SIZE, false)
	_number.name = "Number"
	_number.add_theme_color_override("font_color", Palette.TEAL_SHADE)
	_paper.add_child(_number)
	_check = _label("", CHECK_SIZE, Palette.GREEN_DARK)
	_check.name = "Check"
	# Bold Atkinson lacks the ✓: the display's font with JetBrains Mono behind it.
	_check.add_theme_font_override("font", MachineDisplay.marked_font(BOLD_WEIGHT))
	# It clips (a long check line stays on the paper): its box spans the paper's text width.
	RewardMachineView.fit(
		_check,
		Rect2(PADDING + Vector2(0, 14), Vector2(PAPER_RECT.size.x - PADDING.x * 2.0, CHECK_HEIGHT))
	)
	_paper.add_child(_check)
	_packed = UiKit.display_label(PACKED_TEXT, PACKED_SIZE, false)
	_packed.name = "Packed"
	_packed.add_theme_color_override("font_color", Palette.TOMATO_DARK)
	_packed.add_theme_stylebox_override("normal", _packed_style())
	_packed.position = PACKED_AT
	_packed.rotation = deg_to_rad(PACKED_TILT)
	_packed.visible = false
	_paper.add_child(_packed)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The slip of a visit: `title` ("ORDER #…", "BONUS #…", "STAMP DAY"; rebuilt from the run with
## "?" for the chute's digit until one is chosen), the receipt's `check` line, `count` prize lines
## of MachinePrize.Kind `kind` (-1: "?" until a chute is chosen), and whether the visit gets packed
## (its PACKED stamp then lands at the plan's packed time).
func show_order(title: String, check: String, count: int, kind: int, packed: bool) -> void:
	var parts: PackedStringArray = _title_parts(title, kind)
	_title.text = parts[0]
	_number.text = parts[1]
	_number.position = PADDING + Vector2(_title.get_minimum_size().x + 4.0, 0)
	_check.text = check
	for line: Label in _lines:
		_paper.remove_child(line)
		line.queue_free()
	_lines = []
	_ticked = []
	var top: float = _rule_y() + RULE_GAP.y + 2.0
	for index: int in range(count):
		var word: String = PRIZE_WORDS[kind] if kind >= 0 and kind < PRIZE_WORDS.size() else "?"
		var line: Label = _label("%d · %s" % [index + 1, word], LINE_SIZE, Palette.GREY)
		line.name = "Line%d" % index
		line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		RewardMachineView.fit(
			line,
			Rect2(
				Vector2(PADDING.x + BOX + 4.0, top + LINE_HEIGHT * index),
				Vector2(PAPER_RECT.size.x - PADDING.x * 2.0 - BOX - 4.0, LINE_HEIGHT)
			)
		)
		_paper.add_child(line)
		_lines.append(line)
		_ticked.append(false)
	_may_pack = packed
	_packed.visible = false
	_packed_shown = false
	_paper.queue_redraw()


## The slip's texts: title, check line, then the prize lines, for tests.
func texts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray([_title_text(), _check.text])
	for line: Label in _lines:
		found.append(line.text)
	return found


## Whether the PACKED stamp shows (after the last bay pick).
func is_packed() -> bool:
	return _packed_shown


## Whether prize line `index`'s box is ticked (its box was picked from its bay).
func is_ticked(index: int) -> bool:
	return index >= 0 and index < _ticked.size() and _ticked[index]


## The paper's offset above its rest position (0 once it has slid down).
func slide_offset() -> float:
	return PAPER_RECT.position.y - _paper.position.y


## The font of the check line (bold Atkinson with JetBrains Mono behind it for the ✓), for tests.
func check_font() -> Font:
	return _check.get_theme_font("font")


## Shows the slip at time `t` (seconds) of view.plan.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	if plan == null:
		return
	var down: float = _slid(plan, t)
	_paper.position.y = PAPER_RECT.position.y - StockroomWindow.snap((1.0 - down) * SLIDE)
	_paper.visible = down > 0.0
	for index: int in range(_lines.size()):
		var ticked: bool = (
			plan.has_draw
			and index < plan.picks.size()
			and t >= plan.picks[index] + (0.0 if plan.reduced_motion else TICK_S)
		)
		if ticked != _ticked[index]:
			_ticked[index] = ticked
			_lines[index].add_theme_color_override(
				"font_color", Palette.INK if ticked else Palette.GREY
			)
			_paper.queue_redraw()
	_packed_shown = _may_pack and plan.has_draw and t >= plan.packed
	_packed.visible = _packed_shown
	if _packed_shown:
		var pop: float = 1.0
		if not plan.reduced_motion:
			var length: float = MachineTuning.sec(view.tuning.packed_pop_ms)
			var p: float = StockroomWindow.seg(t, plan.packed, plan.packed + length)
			pop = lerpf(PACKED_POP, 1.0, StockroomWindow.ease_out(p))
		_packed.pivot_offset = _packed.size / 2.0
		_packed.scale = Vector2(pop, pop)


## How far the slip has slid down at `t` (0 up in the slot .. 1 at rest).
func _slid(plan: MachinePlan, t: float) -> float:
	if plan.kind == MachineVisit.Kind.STAMP_DAY:
		return 1.0
	if plan.reduced_motion:
		return 1.0 if t >= plan.feed_end else 0.0
	var p: float = StockroomWindow.seg(t, plan.fly_end, plan.feed_end + SLIDE_TAIL_S)
	return StockroomWindow.smooth(p)


## The title's word and number: from the run when there is one (the chute's digit, "?" until a
## chute is chosen), else `title` as given.
func _title_parts(title: String, kind: int) -> PackedStringArray:
	var run: RunState = view.run if view != null else null
	var visit: MachineVisit = run.machine.current_visit() if run != null else null
	if visit == null or run.history.is_empty():
		var space: int = title.find(" #")
		if space < 0:
			return PackedStringArray([title, ""])
		return PackedStringArray([title.substr(0, space), title.substr(space + 1)])
	match visit.kind:
		MachineVisit.Kind.STAMP_DAY:
			return PackedStringArray(["STAMP DAY", ""])
		MachineVisit.Kind.BONUS:
			return PackedStringArray(["BONUS", _number_text(run, visit, kind, 8)])
	return PackedStringArray(["ORDER", _number_text(run, visit, kind, 7)])


static func _number_text(run: RunState, visit: MachineVisit, kind: int, last: int) -> String:
	var chute: String = str(visit.chute + 1) if kind >= 0 and visit.chute >= 0 else "?"
	return "#%d%s%d" % [run.history[-1].shift, chute, last]


func _title_text() -> String:
	return _title.text if _number.text.is_empty() else "%s %s" % [_title.text, _number.text]


func _rule_y() -> float:
	return _check.position.y + 11.0 + RULE_GAP.x


func _label(text: String, font_size: int, colour: Color) -> Label:
	var label: Label = UiKit.body_label(text, font_size, colour)
	label.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _packed_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.TOMATO_DARK
	style.set_border_width_all(2)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


## The paper: shadow, zig-zag bottom, ink edge, pin, dashed rule and the lines' check boxes.
func _draw_paper() -> void:
	var w: float = PAPER_RECT.size.x
	var h: float = PAPER_RECT.size.y
	var outline: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(w, 0)])
	var tooth: float = w / TEETH
	for index: int in range(TEETH, -1, -1):
		var deep: bool = index % 2 == 0
		outline.append(Vector2(tooth * index, h - (0.0 if deep else ZIG)))
	var shadow: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in outline:
		shadow.append(point + Vector2(SHADOW, SHADOW))
	_paper.draw_colored_polygon(shadow, Palette.WOOD_DARK)
	_paper.draw_colored_polygon(outline, Palette.PAPER)
	var closed: PackedVector2Array = outline.duplicate()
	closed.append(outline[0])
	_paper.draw_polyline(closed, Palette.INK, 2.0)
	# A double rule inside the PACKED stamp is its style's; here the pin and the dashed rule.
	_paper.draw_rect(PIN, Palette.INK)
	_paper.draw_rect(Rect2(PIN.position + Vector2(2, 0), PIN.size - Vector2(4, 2)), Palette.TOMATO)
	var rule_y: float = _rule_y()
	for x: int in range(int(PADDING.x), int(w - PADDING.x), 6):
		_paper.draw_rect(Rect2(x, rule_y, 4, 2), Palette.CREAM_SHADE)
	for index: int in range(_lines.size()):
		var box: Rect2 = Rect2(
			Vector2(PADDING.x, _lines[index].position.y + (LINE_HEIGHT - BOX) / 2.0),
			Vector2(BOX, BOX)
		)
		var ticked: bool = _ticked[index]
		_paper.draw_rect(box, Palette.INK if ticked else Palette.GREY)
		_paper.draw_rect(box.grow(-2.0), Palette.GOOD if ticked else Palette.PAPER)
		if ticked:
			# The check mark (a shape, not only the box's colour).
			_paper.draw_rect(Rect2(box.position + Vector2(2, 4), Vector2(2, 2)), Palette.PAPER)
			_paper.draw_rect(Rect2(box.position + Vector2(4, 2), Vector2(2, 4)), Palette.PAPER)
