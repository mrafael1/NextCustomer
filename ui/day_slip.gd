class_name DaySlip
extends Control
## Today's slip (2026-10-31): tapping the top bar's day chip ("D5", InspectionTag) drops a small
## paper slip under it, in the time card's paper and print (WeekCard), showing only today's
## events, big: "DAY 5 · TODAY", then each event's icon and name in its tone (a boon green, an
## inspection tomato, as on the time card's rows), its effect (notice_text) and, when it touches
## the belt, where: "→ slot 7 closed" (Short belt), "→ slot 8 opens" (Extra till), "→ slot 3 pays
## €0" (Spot check), "→ last filled slot" (Happy hour). Where is read from the event's data and the
## shift's limits (where_lines), never from its id. A day without an event reads "Normal day" and
## "No event today". The week chip still opens the whole time card (WeekFlow).
##
## open() drops the slip from its hook under the chip and lets it settle (DROP seconds; at once
## with reduced motion); tapping the chip again, the slip itself, anywhere else, or Esc closes it
## (close: a short fade). A click elsewhere still does its own work: the slip takes no clicks
## outside its paper. The slip is full-screen but ignores the mouse; only its paper stops it.

## The slip's words.
const HEAD := "DAY %d · TODAY"
const NO_EVENT := WeekCardModel.NO_EVENT
const NO_EVENT_EFFECT := "No event today"
const WHERE_CLOSED := "→ slot %d closed"
const WHERE_CLOSED_MANY := "→ slots %d–%d closed"
const WHERE_OPENS := "→ slot %d opens"
const WHERE_OPEN_MANY := "→ slots %d–%d open"
const WHERE_ZERO := "→ slot %d pays €0"
const WHERE_LAST := "→ last filled slot"
## The paper: its width, border, padding, hard shadow, the gap under the chip and the screen's
## margin it keeps.
const WIDTH := 300.0
const BORDER := 3
const PADDING := 10
const SHADOW := 4
const GAP := 10.0
const MARGIN := 8.0
## The print: the head, an event's name, effect and where line.
const HEAD_SIZE := 18
const NAME_SIZE := 24
const EFFECT_SIZE := 15
const WHERE_SIZE := 16
const ICON_SCALE := 2.0
const EVENT_GAP := 8
## The drop: from DROP_RISE px higher and turned DROP_DEGREES about its hook, settling in DROP
## seconds; the close's fade.
const DROP := 0.32
const DROP_RISE := 22.0
const DROP_DEGREES := -6.0
const FADE := 0.12

var reduced_motion: bool = false
var _paper: WeekCard.ShadowPanel
## The chip the slip hangs from (a click on it is the chip's, not "elsewhere").
var _anchor: Control
var _tween: Tween
## The chip's rect the slip was last hung under (it follows the chip while open).
var _anchor_rect: Rect2 = Rect2()
var _day: int = 0
var _names: Array[Label] = []
var _effects: Array[Label] = []
var _wheres: Array[Label] = []


func _init() -> void:
	name = "DaySlip"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process_input(false)
	set_process(false)


## Where `event` touches the belt this shift, one line each (none: it doesn't): the slots its
## extra_slots closes or opens (from `limits`: the open slots are the first card_limit, the closed
## ones follow), the slot a NthSlotZeroPayoutRule zeroes, and a LastCardBonusRule's last slot.
static func where_lines(event: InspectionDefinition, limits: ShiftLimits) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var open_count: int = RowCapacity.card_limit(limits) if limits != null else 0
	if event.extra_slots < 0 and limits != null and limits.closed_slots > 0:
		var count: int = mini(-event.extra_slots, limits.closed_slots)
		lines.append(_span(open_count + 1, open_count + count, WHERE_CLOSED, WHERE_CLOSED_MANY))
	elif event.extra_slots > 0 and open_count > 0:
		var first: int = maxi(open_count - event.extra_slots + 1, 1)
		lines.append(_span(first, open_count, WHERE_OPENS, WHERE_OPEN_MANY))
	for rule: InspectionRule in event.rules:
		var zero: NthSlotZeroPayoutRule = rule as NthSlotZeroPayoutRule
		if zero != null and zero.slot_number > 0:
			lines.append(WHERE_ZERO % zero.slot_number)
		elif rule is LastCardBonusRule and (rule as LastCardBonusRule).bonus != 0:
			lines.append(WHERE_LAST)
	return lines


## Drops the slip for day `day` (1-based, as the chip reads) with `events` (none: a plain day)
## under `anchor`, the shift's `limits` saying where on the belt.
func open(
	day: int,
	events: Array[InspectionDefinition],
	limits: ShiftLimits,
	anchor: Control,
	reduced: bool
) -> void:
	clear()
	_day = day
	_anchor = anchor
	reduced_motion = reduced
	_build(events, limits)
	visible = true
	modulate.a = 1.0
	set_process_input(true)
	set_process(true)
	_place()
	Sfx.play_at(self, "ui_open")
	if reduced:
		return
	var rest: Vector2 = _paper.position
	_paper.position.y = rest.y - DROP_RISE
	_paper.rotation_degrees = DROP_DEGREES
	_paper.modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_paper, "modulate:a", 1.0, DROP * 0.4)
	_tween.tween_property(_paper, "position:y", rest.y, DROP).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	(
		_tween
		. tween_property(_paper, "rotation_degrees", 0.0, DROP)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)


## Closes the slip: a short fade (at once with reduced motion).
func close() -> void:
	if not visible or _paper == null:
		return
	Sfx.play_at(self, "ui_close")
	set_process_input(false)
	if reduced_motion:
		clear()
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE)
	_tween.tween_callback(clear)


## Hides the slip at once, with no sound.
func clear() -> void:
	_kill_tween()
	visible = false
	modulate.a = 1.0
	set_process_input(false)
	set_process(false)
	if _paper != null:
		_paper.queue_free()
		_paper = null
	_names.clear()
	_effects.clear()
	_wheres.clear()


## Open and not closing.
func is_open() -> bool:
	return visible and is_processing_input()


## Ends the drop at once (tests, the screen capture).
func settle() -> void:
	if _tween != null and _tween.is_valid():
		_tween.custom_step(DROP + FADE)
	_kill_tween()


func day_number() -> int:
	return _day


## The paper, and each event's name, effect and where labels (for tests).
func paper() -> PanelContainer:
	return _paper


func name_labels() -> Array[Label]:
	return _names.duplicate()


func effect_labels() -> Array[Label]:
	return _effects.duplicate()


func where_labels() -> Array[Label]:
	return _wheres.duplicate()


## Every text on the slip, one per line (tests).
func slip_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	if _paper != null:
		_collect(_paper, lines)
	return "\n".join(lines)


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
		return
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or not press.pressed:
		return
	if press.button_index != MOUSE_BUTTON_LEFT and press.button_index != MOUSE_BUTTON_RIGHT:
		return  # The wheel scrolls; it never closes the slip.
	if _anchor != null and is_instance_valid(_anchor):
		if _anchor.get_global_rect().has_point(press.position):
			return  # The chip's own tap toggles the slip.
	if _paper.get_global_rect().has_point(press.position):
		get_viewport().set_input_as_handled()
	close()  # The slip, or elsewhere: a click elsewhere still does its own work.


## Follows the chip (the top bar lays out after a new shift's chips change).
func _process(_delta: float) -> void:
	if _paper == null or _is_dropping() or _anchor == null or not is_instance_valid(_anchor):
		return
	if _anchor.get_global_rect() != _anchor_rect:
		_place()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _paper != null and not _is_dropping():
		_place()


func _is_dropping() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## Hangs the paper under the chip, its left edge on the chip's, kept inside the screen.
func _place() -> void:
	_paper.reset_size()
	_paper.size = _paper.get_combined_minimum_size()
	var at: Vector2 = Vector2(MARGIN, MARGIN)
	if _anchor != null and is_instance_valid(_anchor):
		var chip: Rect2 = _anchor.get_global_rect()
		_anchor_rect = chip
		var local: Transform2D = get_global_transform().affine_inverse()
		at = local * Vector2(chip.position.x, chip.end.y + GAP)
	at.x = clampf(at.x, MARGIN, maxf(size.x - _paper.size.x - MARGIN, MARGIN))
	at.y = clampf(at.y, MARGIN, maxf(size.y - _paper.size.y - MARGIN, MARGIN))
	_paper.position = at.round()
	_paper.pivot_offset = Vector2(_paper.size.x / 2.0, 0.0)


# --- Build -----------------------------------------------------------------------------------


func _build(events: Array[InspectionDefinition], limits: ShiftLimits) -> void:
	_paper = WeekCard.ShadowPanel.new(_box(Palette.PAPER, Palette.INK, BORDER, PADDING), SHADOW)
	_paper.name = "Paper"
	_paper.notch = true
	_paper.mouse_filter = Control.MOUSE_FILTER_STOP
	_paper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_paper.custom_minimum_size.x = WIDTH
	add_child(_paper)
	var column: VBoxContainer = _column(EVENT_GAP)
	_paper.add_child(column)
	var notch_room: Control = Control.new()
	notch_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notch_room.custom_minimum_size.y = WeekCard.NOTCH_SIZE.y - BORDER
	column.add_child(notch_room)
	var head: Label = _bold(HEAD % _day, HEAD_SIZE, Palette.MUSTARD_DARKEST)
	head.name = "Head"
	column.add_child(head)
	var rule: ColorRect = ColorRect.new()
	rule.color = Palette.INK
	rule.custom_minimum_size.y = 3
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	if events.is_empty():
		column.add_child(_event_block(null, limits))
	for event: InspectionDefinition in events:
		column.add_child(_event_block(event, limits))


## One event (null: the plain day): its icon, name, effect and where lines in its tone's tint.
func _event_block(event: InspectionDefinition, limits: ShiftLimits) -> Control:
	var boon: bool = event != null and event.is_boon()
	var fill: Color = Palette.CREAM
	var border: Color = Palette.GREY
	var ink: Color = Palette.GREY_DARK
	var effect_ink: Color = Palette.GREY_DARK
	if event != null:
		fill = (
			Palette.GREEN_LIGHT.lerp(Palette.PAPER, WeekCard.PALE_MIX)
			if boon
			else Palette.TOMATO_PALE.lerp(Palette.PAPER, WeekCard.BLUSH_MIX)
		)
		border = Palette.GREEN_DARK if boon else Palette.TOMATO_DARK
		ink = border
		effect_ink = Palette.GREEN_DARK.darkened(0.45) if boon else Palette.TOMATO_DARKEST
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Event"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(fill, border, 2, 6))
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var text_width: float = WIDTH - 2.0 * (PADDING + BORDER) - 2.0 * (6 + 2)
	if event != null:
		var texture: Texture2D = WeekCard.BOON if boon else WeekCard.WARNING
		if not event.icon_ref.is_empty():
			texture = load(event.icon_ref) as Texture2D
		var icon: TextureRect = UiKit.sprite(texture)
		icon.name = "Icon"
		icon.custom_minimum_size = texture.get_size() * ICON_SCALE
		icon.flip_v = event.icon_flipped
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		text_width -= icon.custom_minimum_size.x + 8.0
	var words: VBoxContainer = _column(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var title: Label = UiKit.display_label(
		event.display_name if event != null else NO_EVENT, NAME_SIZE, false
	)
	title.name = "Name"
	title.add_theme_color_override("font_color", ink)
	words.add_child(title)
	_names.append(title)
	var effect: Label = _bold(
		event.notice_text if event != null else NO_EVENT_EFFECT, EFFECT_SIZE, effect_ink
	)
	effect.name = "Effect"
	_wrap(effect, text_width)
	words.add_child(effect)
	_effects.append(effect)
	if event == null:
		return panel
	for line: String in where_lines(event, limits):
		var where: Label = _bold(line, WHERE_SIZE, Palette.INK)
		where.name = "Where"
		var tag: StyleBoxFlat = _box(Palette.PAPER, ink, 2, 2)
		tag.content_margin_left = 6
		tag.content_margin_right = 6
		where.add_theme_stylebox_override("normal", tag)
		where.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		words.add_child(where)
		_wheres.append(where)
	return panel


static func _span(first: int, last: int, one: String, many: String) -> String:
	return one % first if first == last else many % [first, last]


static func _wrap(label: Label, width: float) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapping label needs its width to measure its height before the slip is laid out.
	label.custom_minimum_size.x = width


static func _collect(node: Node, lines: PackedStringArray) -> void:
	var label: Label = node as Label
	if label != null and label.visible:
		lines.append(label.text)
	for child: Node in node.get_children():
		_collect(child, lines)


static func _column(separation: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", separation)
	return column


static func _bold(text: String, font_size: int, color: Color) -> Label:
	var label: Label = UiKit.body_label(text, font_size, color)
	label.add_theme_font_override("font", ArtStyle.bold_font(700))
	return label


static func _box(fill: Color, border: Color, width: int, padding: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_content_margin_all(padding + width)
	return box
