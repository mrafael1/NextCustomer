class_name DaySlip
extends Control
## Today's slip (2026-10-31): tapping the top bar's day calendar (DayCalendar, v1.17) drops a
## small paper slip under it, in the time card's paper and print (WeekCard), showing only today's
## events, big: "DAY 5 · TODAY", then each event's icon and name in its tone (a boon green, an
## inspection tomato, as on the time card's rows), its effect (notice_text) and, when it touches
## the belt, where: "→ slot 7 closed" (Short belt), "→ slot 8 opens" (Extra till), "→ slot 3 pays
## 0€" (Spot check), "→ last filled slot" (Happy hour). Where is read from the event's data and the
## shift's limits (where_lines), never from its id. A day without an event reads "Normal day" and
## "No event today". The week glass still opens the whole time card (WeekFlow).
## Under today's events a short line reminds the week's bonus (v1.02, run info: "WEEK 4 ·
## CLEARANCE WEEK" and its effect, framed in the week's colour), when the week has an event; the
## training week's misses read as on the time card's banner, on their red tag.
##
## open() drops the slip from its hook under the chip and lets it settle (DROP seconds; at once
## with reduced motion); tapping the chip again, the slip itself, anywhere else, or Esc closes it
## (close: a short fade). A click elsewhere still does its own work: the slip takes no clicks
## outside its paper. The slip is full-screen but ignores the mouse; only its paper stops it.
##
## Above (play test 2026-11-09, the desk calendar on the register: "needs to be higher"): the
## slip pops UP out of the calendar instead, into the receipt well over the planning receipt, its
## right edge on the calendar's, its foot GAP over the calendar's tags, its punch-clock notch on its
## foot pointing down at the calendar; it rises from DROP_RISE lower about its foot's middle. Where
## the paper would not fit over the calendar (a review day's two events at 1280x720) it prints
## compact. A long hover opens it too (`hover`: no sound); leaving the calendar and the paper for
## HOVER_GRACE closes it, unless a click pinned it (pin()).

## The slip's words.
const HEAD := "DAY %d · TODAY"
const NO_EVENT := WeekCardModel.NO_EVENT
const NO_EVENT_EFFECT := "No event today"
const WHERE_CLOSED := "→ slot %d closed"
const WHERE_CLOSED_MANY := "→ slots %d–%d closed"
const WHERE_OPENS := "→ slot %d opens"
const WHERE_OPEN_MANY := "→ slots %d–%d open"
const WHERE_ZERO := "→ slot %d pays 0€"
const WHERE_LAST := "→ last filled slot"
## The week's reminder: its head, and the week colour's square beside it.
const WEEK_HEAD := "WEEK %d · %s"
const WEEK_SIZE := 15
const WEEK_SQUARE := 10.0
## The paper: its widest, border, padding, hard shadow, the gap from the chip and the screen's
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
## The event icon, at this scale, centred on the left of its block (2026-11-01).
const ICON_SCALE := 3.0
const EVENT_GAP := 8
## An event block's padding.
const EVENT_PADDING := 6
## The compact print (above, where the paper would not fit): a smaller name and icon, tighter.
const COMPACT_NAME_SIZE := 20
const COMPACT_ICON_SCALE := 2.0
const COMPACT_EVENT_GAP := 6
const COMPACT_EVENT_PADDING := 4
## The calendar's bonus line under the head (WeekFlow.bonus_line: the "+1" pill's whole words).
const BONUS_SIZE := 14
## A hover-opened slip closes once the pointer has been off the calendar and the paper this long.
const HOVER_GRACE := 0.2
## The drop: from DROP_RISE px higher and turned DROP_DEGREES about its hook, settling in DROP
## seconds; the close's fade.
const DROP := 0.32
const DROP_RISE := 22.0
const DROP_DEGREES := -6.0
const FADE := 0.12

var reduced_motion: bool = false
var _paper: WeekCard.ShadowPanel
## Popped up over the chip (open's "above"), its width and its compact print.
var _above: bool = false
var _width: float = WIDTH
var _compact: bool = false
## Opened by a long hover and not pinned by a click: leaving closes it.
var _hover: bool = false
## Seconds the pointer has been off the chip and the paper (below 0: it is on one).
var _away: float = -1.0
## The chip the slip hangs from (a click on it is the chip's, not "elsewhere").
var _anchor: Control
var _tween: Tween
## The chip's rect the slip was last hung under (it follows the chip while open).
var _anchor_rect: Rect2 = Rect2()
var _day: int = 0
var _names: Array[Label] = []
var _effects: Array[Label] = []
var _wheres: Array[Label] = []
## The week's reminder (null: a week without an event, or no week given).
var _week: Control


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
## under `anchor`, the shift's `limits` saying where on the belt, and `week`'s event (if any)
## reminded under them. `options`: "above" (pops up over the anchor, its right edge on the
## anchor's, compact when it must), "hover" (a long hover opened it: no sound, leaving closes it)
## and "bonus" (a line under the head: the calendar's bonus ticket, WeekFlow.bonus_line).
func open(
	day: int,
	events: Array[InspectionDefinition],
	limits: ShiftLimits,
	anchor: Control,
	reduced: bool,
	week: WeekCardModel = null,
	options: Dictionary = {}
) -> void:
	clear()
	_day = day
	_anchor = anchor
	reduced_motion = reduced
	_above = bool(options.get("above", false)) and anchor != null
	_hover = bool(options.get("hover", false))
	_width = WIDTH
	if _above:
		_width = clampf(_local_reach().end.x - MARGIN, WIDTH * 0.75, WIDTH)
	var bonus: String = String(options.get("bonus", ""))
	_compact = false
	_build(events, limits, week, bonus)
	if _above and _paper.get_combined_minimum_size().y > _room():
		_compact = true  # A review day over the calendar at 1280x720: the compact print.
		_paper.free()
		_paper = null
		_clear_labels()
		_build(events, limits, week, bonus)
	visible = true
	modulate.a = 1.0
	set_process_input(true)
	set_process(true)
	_place()
	if not _hover:
		Sfx.play_at(self, "ui_open")
	if reduced:
		return
	var rest: Vector2 = _paper.position
	_paper.position.y = rest.y + (DROP_RISE if _above else -DROP_RISE)
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


## Closes the slip: a short fade (at once with reduced motion); `quiet`: no sound (a hover-opened
## slip the pointer left).
func close(quiet: bool = false) -> void:
	if not visible or _paper == null:
		return
	if not quiet:
		Sfx.play_at(self, "ui_close")
	set_process_input(false)
	_away = -1.0
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
	_hover = false
	_away = -1.0
	_clear_labels()


## Open and not closing.
func is_open() -> bool:
	return visible and is_processing_input()


## Opened by a long hover and not pinned: leaving the chip and the paper closes it.
func is_hover_open() -> bool:
	return is_open() and _hover


## A click on the chip while hover-opened: the slip stays until a click or Esc closes it.
func pin() -> void:
	_hover = false
	_away = -1.0


## The pointer left the chip or the paper: a hover-opened slip closes after HOVER_GRACE unless it
## comes back (pointer_back).
func pointer_left() -> void:
	if is_hover_open():
		_away = 0.0


func pointer_back() -> void:
	_away = -1.0


## Whether it prints compact (above, a paper too tall for its room).
func is_compact() -> bool:
	return _compact


## Moves the hover's grace on by `seconds` (tests; _process moves it by the frame's).
func advance(seconds: float) -> void:
	if _away < 0.0 or not is_hover_open():
		return
	_away += seconds
	if _away >= HOVER_GRACE:
		close(true)


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


## The week's reminder, or null.
func week_line() -> Control:
	return _week


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
		if _reach().has_point(press.position):
			return  # The chip's own tap toggles the slip.
	if _paper.get_global_rect().has_point(press.position):
		get_viewport().set_input_as_handled()
	close()  # The slip, or elsewhere: a click elsewhere still does its own work.


## Follows the chip (the top bar lays out after a new shift's chips change); a hover-opened slip
## counts the pointer's time away.
func _process(delta: float) -> void:
	advance(delta)
	if _paper == null or _is_dropping() or _anchor == null or not is_instance_valid(_anchor):
		return
	if _reach() != _anchor_rect:
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


## Hangs the paper under the chip, its left edge on the chip's (above: over the chip and its
## tags, its right edge on the chip's), kept inside the screen.
func _place() -> void:
	_paper.reset_size()
	_paper.size = _paper.get_combined_minimum_size()
	var at: Vector2 = Vector2(MARGIN, MARGIN)
	if _anchor != null and is_instance_valid(_anchor):
		_anchor_rect = _reach()
		var chip: Rect2 = _local_reach()
		at = Vector2(chip.position.x, chip.end.y + GAP)
		if _above:
			at = Vector2(chip.end.x - _paper.size.x, chip.position.y - GAP - _paper.size.y)
	at.x = clampf(at.x, MARGIN, maxf(size.x - _paper.size.x - MARGIN, MARGIN))
	at.y = clampf(at.y, MARGIN, maxf(size.y - _paper.size.y - MARGIN, MARGIN))
	_paper.position = at.round()
	_paper.pivot_offset = Vector2(_paper.size.x / 2.0, _paper.size.y if _above else 0.0)


## The anchor's rect on the canvas, a calendar's visible tags over it included.
func _reach() -> Rect2:
	var rect: Rect2 = _anchor.get_global_rect()
	var calendar: DayCalendar = _anchor as DayCalendar
	if calendar != null:
		var tags: Rect2 = calendar.part_rects()["tags"]
		if tags.has_area():
			rect = rect.merge(tags)
	return rect


## The anchor's reach in the slip's own coordinates.
func _local_reach() -> Rect2:
	return get_global_transform().affine_inverse() * _reach()


## The height the paper has over the anchor (above): from the screen's margin to GAP over it.
func _room() -> float:
	return _local_reach().position.y - GAP - MARGIN


func _clear_labels() -> void:
	_names.clear()
	_effects.clear()
	_wheres.clear()
	_week = null


# --- Build -----------------------------------------------------------------------------------


func _build(
	events: Array[InspectionDefinition], limits: ShiftLimits, week: WeekCardModel, bonus: String
) -> void:
	_paper = WeekCard.ShadowPanel.new(_box(Palette.PAPER, Palette.INK, BORDER, PADDING), SHADOW)
	_paper.name = "Paper"
	_paper.notch = true
	_paper.notch_bottom = _above
	_paper.mouse_filter = Control.MOUSE_FILTER_STOP
	_paper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_paper.custom_minimum_size.x = _width
	_paper.mouse_entered.connect(pointer_back)
	_paper.mouse_exited.connect(pointer_left)
	add_child(_paper)
	var column: VBoxContainer = _column(COMPACT_EVENT_GAP if _compact else EVENT_GAP)
	_paper.add_child(column)
	var notch_room: Control = Control.new()
	notch_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notch_room.custom_minimum_size.y = WeekCard.NOTCH_SIZE.y - BORDER
	column.add_child(notch_room)
	var head: Label = _bold(HEAD % _day, HEAD_SIZE, Palette.MUSTARD_DARKEST)
	head.name = "Head"
	column.add_child(head)
	if not bonus.is_empty():
		var line: Label = _bold(bonus, BONUS_SIZE, Palette.TEAL_DARK)
		line.name = "Bonus"
		_wrap(line, _width - 2.0 * (PADDING + BORDER))
		column.add_child(line)
	var rule: ColorRect = ColorRect.new()
	rule.color = Palette.INK
	rule.custom_minimum_size.y = 3
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	if events.is_empty():
		column.add_child(_event_block(null, limits))
	for event: InspectionDefinition in events:
		column.add_child(_event_block(event, limits))
	if week != null and week.event != null:
		_week = _week_block(week)
		column.add_child(_week)
	if _above:
		column.move_child(notch_room, -1)  # The notch is on the foot, over the calendar.


## The week's reminder: the week colour's square and "WEEK 4 · CLEARANCE WEEK", then its effect,
## in a box bordered in the week's colour.
func _week_block(week: WeekCardModel) -> Control:
	var colour: Color = WeekCard.colour_of(week.week_number)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Week"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(Palette.PAPER, colour, 2, 4))
	var words: VBoxContainer = _column(0)
	panel.add_child(words)
	var head_row: HBoxContainer = HBoxContainer.new()
	head_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_row.add_theme_constant_override("separation", 6)
	words.add_child(head_row)
	var square: ColorRect = ColorRect.new()
	square.name = "Square"
	square.color = colour
	square.custom_minimum_size = Vector2(WEEK_SQUARE, WEEK_SQUARE)
	square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_row.add_child(square)
	var head: Label = _bold(
		WEEK_HEAD % [week.week_number, week.title()], WEEK_SIZE, Palette.MUSTARD_DARKEST
	)
	head.name = "WeekHead"
	head_row.add_child(head)
	var misses: String = week.misses_text()
	if not misses.is_empty():
		words.add_child(_misses_line(misses))
		return panel
	# Its gains green and its harms red, as on the monitor (v1.02).
	var effect: RichTextLabel = WeekCard.effect_line(week, WEEK_SIZE, Palette.INK)
	effect.name = "WeekEffect"
	# A wrapping label needs its width to measure its height before the slip is laid out.
	effect.custom_minimum_size.x = _width - 2.0 * (PADDING + BORDER) - 2.0 * (4 + 2)
	words.add_child(effect)
	return panel


## The training week's effect as the time card's banner reads it (WeekCard._misses_line): "THIS
## WEEK ALLOWS" in ink, then the misses on their red tag (WeekCard.misses_tag).
func _misses_line(misses: String) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "WeekEffect"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var lead: Label = _bold(WeekCardModel.ALLOWS_LEAD, WEEK_SIZE, Palette.INK)
	lead.name = "Lead"
	lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lead)
	row.add_child(WeekCard.misses_tag(misses, WEEK_SIZE))
	return row


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
	var padding: int = COMPACT_EVENT_PADDING if _compact else EVENT_PADDING
	panel.add_theme_stylebox_override("panel", _box(fill, border, 2, padding))
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var text_width: float = _width - 2.0 * (PADDING + BORDER) - 2.0 * (padding + 2)
	if event != null:
		var texture: Texture2D = WeekCard.BOON if boon else WeekCard.WARNING
		if not event.icon_ref.is_empty():
			texture = load(event.icon_ref) as Texture2D
		var icon: TextureRect = UiKit.sprite(texture)
		icon.name = "Icon"
		var icon_scale: float = COMPACT_ICON_SCALE if _compact else ICON_SCALE
		icon.custom_minimum_size = texture.get_size() * icon_scale
		icon.flip_v = event.icon_flipped
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		text_width -= icon.custom_minimum_size.x + 8.0
	var words: VBoxContainer = _column(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var title: Label = UiKit.display_label(
		event.display_name if event != null else NO_EVENT,
		COMPACT_NAME_SIZE if _compact else NAME_SIZE,
		false
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
		if line.trim_prefix("→ ").to_lower() == event.notice_text.to_lower():
			continue  # The effect already says it (Spot check's "Slot 3 pays 0€").
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
	var rich: RichTextLabel = node as RichTextLabel
	if rich != null and rich.visible:
		lines.append(rich.get_parsed_text())
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
