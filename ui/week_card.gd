class_name WeekCard
extends Control
## The punch-clock time card (v0.70, mock-up docs/art/mockups/rota_card_v1.html, layout C): a
## mustard card over a dim, "TIME CARD" and "CASHIER · TILL 4 / WEEK 2 OF 3" over the week's
## banner (its colour, colour_of: "WEEK 2 OF 3", the week event's name, its effect, the training
## week's "2 SLIPS"), then a table with one row per day: the day's number with its "IN" punch on
## the left (played days and today), and on the right every day event by name and effect (a
## day without one: "Normal day · No event"); a Manager's review's row is mustard, headed
## "MANAGER'S REVIEW · 2 MALUSES" and closed by its reward ("REVIEW PASSED · 2 PREMIUM TICKETS",
## or day 12's "PASS = RUN WON").
##
## play(): the card arrives (print), the banner stamps, the rows fill in one by one (today's
## punch), the card holds HOLD seconds and shrinks into the week chip. reopen(): the whole card at
## once (a pop), open until tapped. Reduced motion shows the whole card at once and keeps it open
## until tapped. Tapping the card closes it (it shrinks into the chip; at once with reduced
## motion), then `closed`. A timeline in seconds (advance, finish), so tests drive it frame-free.

signal closed

## The timeline (s): the card's arrival (from 55% of its height lower), the banner's stamp, the
## days' fill (one step per day, a review's longer), each row's own pop, the hold before the card
## flies into the chip, and the flight.
const ARRIVE := 0.65
const STAMP_AT := 0.65
const STAMP_LENGTH := 0.42
const DAYS_AT := 1.25
const DAY_STEP := 0.36
const REVIEW_STEP := 0.82
const ROW_POP := 0.34
const HOLD := 1.5
const SHRINK := 0.6
## The banner's stamp: from 2.3x turned -9 degrees to 1x turned -2.
const STAMP_SCALE := 2.3
const STAMP_FROM_DEGREES := -9.0
const BANNER_DEGREES := -2.0
## The rows pop from 60%.
const ROW_FROM_SCALE := 0.6
## The flight ends this wide (px), or at 8% of the card.
const SHRINK_WIDTH := 70.0
const SHRINK_MIN_SCALE := 0.08
const DIM := Color(Palette.CHARCOAL, 0.72)
const CARD_WIDTH := 380.0
const CARD_BORDER := 3
const CARD_PADDING := 10
const PUNCH_WIDTH := 52.0
const TITLE_SIZE := 22
const SUB_SIZE := 11
const BANNER_KEY_SIZE := 11
const BANNER_TITLE_SIZE := 22
const BANNER_EFFECT_SIZE := 14
const DAY_SIZE := 20
const PUNCH_SIZE := 10
const EVENT_NAME_SIZE := 15
const EVENT_EFFECT_SIZE := 12
const REVIEW_HEAD_SIZE := 11
const REWARD_SIZE := 11
const ROW_GAP := 4
## The banner's padding and border, and the width its effect line wraps at.
const BANNER_PADDING := 7
const BANNER_BORDER := 3
const BANNER_TEXT_WIDTH := (
	CARD_WIDTH - 2.0 * (CARD_PADDING + CARD_BORDER) - 2.0 * (BANNER_PADDING + BANNER_BORDER)
)
## The weeks' banner colours (the mock-up's teal shade, mustard dark, ink light), by week; later
## weeks reuse the last.
const WEEK_COLOURS: Array[Color] = [Palette.TEAL_SHADE, Palette.MUSTARD_DARK, Palette.INK_LIGHT]

const WARNING := preload("res://art/icons/warning.png")
const BOON := preload("res://art/icons/boon.png")
const CHECK := preload("res://art/icons/mark_check.png")
const TICKET := preload("res://art/icons/bonus_ticket.png")

var reduced_motion: bool = false
var _dim: ColorRect
var _card: PanelContainer
var _banner: PanelContainer
var _rows: Array[Control] = []
var _punches: Array[Label] = []
var _model: WeekCardModel
## Each row's start on the timeline.
var _row_at: Array[float] = []
## The chip the card flies into.
var _target: Control
## Seconds into the timeline (-1: no intro: a reopened card), and into the flight (-1: none).
var _t: float = -1.0
var _shrink_t: float = -1.0
## The card stays open until tapped (a reopened card, reduced motion).
var _stays: bool = false
## The intro's sounds played so far (the arrival, the stamp, then one per row).
var _sounded: int = 0


func _init() -> void:
	name = "WeekCard"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = DIM
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	visible = false
	set_process(false)


## The banner colour of 1-based `week`.
static func colour_of(week: int) -> Color:
	return WEEK_COLOURS[clampi(week - 1, 0, WEEK_COLOURS.size() - 1)]


## Plays the week's card for `model` (a week's start), flying into `target` at the end.
func play(model: WeekCardModel, target: Control, reduced: bool) -> void:
	_open(model, target, reduced)
	_stays = reduced
	_t = _intro_end() if reduced else 0.0
	_sounded = 0
	if reduced:
		Sfx.play_at(self, "stamp_notice")
		_sounded = _rows.size() + 2
	_render()


## Reopens the card (the week or day chip tapped in planning): whole at once, open until tapped.
func reopen(model: WeekCardModel, target: Control, reduced: bool) -> void:
	_open(model, target, reduced)
	_stays = true
	_t = _intro_end()
	_sounded = _rows.size() + 2
	_render()
	if reduced:
		Sfx.play_at(self, "ui_open")
	else:
		UiKit.pop_in(_card)  # Its open sound too.


## Closes the card: it flies into the chip (at once with reduced motion), then `closed`.
func close() -> void:
	if not visible or _shrink_t >= 0.0:
		return
	Sfx.play_at(self, "ui_close")
	if reduced_motion or _target == null:
		_end()
		return
	_shrink_t = 0.0
	_render()


## Hides the card at once (a new run, a resume), with no flight and no signal.
func clear() -> void:
	visible = false
	set_process(false)
	_shrink_t = -1.0
	if _card != null:
		_card.queue_free()
		_card = null


func is_open() -> bool:
	return visible


## Whether the card is flying into the chip.
func is_shrinking() -> bool:
	return _shrink_t >= 0.0


## Moves the timeline on by `seconds` (tests; _process moves it by the frame's).
func advance(seconds: float) -> void:
	if not visible:
		return
	if _shrink_t >= 0.0:
		_shrink_t += seconds
		if _shrink_t >= SHRINK:
			_end()
			return
	elif _stays and _t >= _intro_end():
		return  # Open until tapped: nothing moves (a reopen's pop plays on its own).
	else:
		_t += seconds
		if not _stays and _t >= _intro_end() + HOLD:
			_shrink_t = 0.0
	_render()


## Skips the intro to the whole card (tests).
func finish() -> void:
	if visible and _shrink_t < 0.0:
		_t = maxf(_t, _intro_end())
		_render()


## Seconds into the timeline, and where the intro ends (the last row filled).
func time() -> float:
	return _t


func _intro_end() -> float:
	if _row_at.is_empty():
		return DAYS_AT
	return _row_at[-1] + _step_of(_rows.size() - 1)


## The card, its banner, its rows and their punches (for layout tests).
func card() -> PanelContainer:
	return _card


func banner() -> PanelContainer:
	return _banner


func rows() -> Array[Control]:
	return _rows.duplicate()


func punches() -> Array[Label]:
	return _punches.duplicate()


func _process(delta: float) -> void:
	advance(delta)


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		close()


func _open(model: WeekCardModel, target: Control, reduced: bool) -> void:
	clear()
	_model = model
	_target = target
	reduced_motion = reduced
	_shrink_t = -1.0
	_build(model)
	visible = true
	set_process(true)
	_place()


func _end() -> void:
	clear()
	closed.emit()


## Centres the card in the screen at its whole size.
func _place() -> void:
	_card.reset_size()
	_card.size = _card.get_combined_minimum_size()
	_card.position = ((size - _card.size) / 2.0).round()
	_card.pivot_offset = _card.size / 2.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _card != null:
		_place()


func _render() -> void:
	if _card == null:
		return
	var intro: float = _t if _t >= 0.0 else _intro_end()
	var arrive: float = clampf(intro / ARRIVE, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - arrive, 3.0)
	_card.position.y = ((size.y - _card.size.y) / 2.0) + (1.0 - eased) * _card.size.y * 0.55
	_card.modulate.a = arrive
	_card.scale = Vector2.ONE
	_dim.modulate.a = 1.0
	var stamp: float = clampf((intro - STAMP_AT) / STAMP_LENGTH, 0.0, 1.0)
	_banner.pivot_offset = _banner.size / 2.0
	_banner.modulate.a = 1.0 if stamp > 0.0 else 0.0
	_banner.scale = Vector2.ONE * lerpf(STAMP_SCALE, 1.0, _ease_out_back(stamp))
	_banner.rotation_degrees = lerpf(STAMP_FROM_DEGREES, BANNER_DEGREES, stamp)
	for index: int in range(_rows.size()):
		var pop: float = clampf((intro - _row_at[index]) / ROW_POP, 0.0, 1.0)
		var row: Control = _rows[index]
		row.pivot_offset = row.size / 2.0
		row.modulate.a = pop
		row.scale = Vector2.ONE * lerpf(ROW_FROM_SCALE, 1.0, _ease_out_back(pop))
	_sound(intro)
	if _shrink_t >= 0.0:
		_render_shrink(clampf(_shrink_t / SHRINK, 0.0, 1.0))


## The intro's sounds as the timeline passes them: the print as the card arrives, the stamp, then
## each row's tick, today's punch a stamp.
func _sound(intro: float) -> void:
	var marks: Array[float] = [0.0, STAMP_AT]
	marks.append_array(_row_at)
	while _sounded < marks.size() and intro >= marks[_sounded]:
		if _sounded == 0:
			Sfx.play_at(self, "print")
		elif _sounded == 1:
			Sfx.play_at(self, "stamp_notice")
		else:
			var day: WeekCardModel.WeekDay = _model.days[_sounded - 2]
			Sfx.play_at(self, "stamp_1" if day.today else "tick")
		_sounded += 1


## The flight into the chip: the card moves to the chip's centre, shrinks and fades, as the dim.
func _render_shrink(k: float) -> void:
	var eased: float = k * k
	var target: Vector2 = _target_centre()
	var from: Vector2 = (size - _card.size) / 2.0 + _card.size / 2.0
	var end_scale: float = maxf(SHRINK_MIN_SCALE, SHRINK_WIDTH / maxf(_card.size.x, 1.0))
	var centre: Vector2 = from.lerp(target, eased)
	_card.position = centre - _card.size / 2.0
	_card.scale = Vector2.ONE * lerpf(1.0, end_scale, eased)
	_card.modulate.a = 1.0 - eased
	_dim.modulate.a = 1.0 - k


## The chip's centre in the card's coordinates.
func _target_centre() -> Vector2:
	if _target == null or not is_instance_valid(_target):
		return size / 2.0
	var chip: Rect2 = _target.get_global_rect()
	return get_global_transform().affine_inverse() * chip.get_center()


func _step_of(index: int) -> float:
	return REVIEW_STEP if _model.days[index].review else DAY_STEP


static func _ease_out_back(k: float) -> float:
	var c: float = 1.70158
	return 1.0 + (c + 1.0) * pow(k - 1.0, 3.0) + c * pow(k - 1.0, 2.0)


# --- Build -----------------------------------------------------------------------------------


func _build(model: WeekCardModel) -> void:
	_rows.clear()
	_punches.clear()
	_row_at.clear()
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size.x = CARD_WIDTH
	_card.add_theme_stylebox_override(
		"panel", _box(Palette.MUSTARD_PALE, Palette.INK, CARD_BORDER, CARD_PADDING)
	)
	add_child(_card)
	var column: VBoxContainer = _column(8)
	_card.add_child(column)
	column.add_child(_head(model))
	_banner = _make_banner(model)
	column.add_child(_banner)
	var table: PanelContainer = PanelContainer.new()
	table.name = "Table"
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.add_theme_stylebox_override("panel", _box(Palette.PAPER, Palette.INK, 2, 0))
	column.add_child(table)
	var days: VBoxContainer = _column(0)
	table.add_child(days)
	var at: float = DAYS_AT
	for index: int in range(model.days.size()):
		var day: WeekCardModel.WeekDay = model.days[index]
		var row: Control = _day_row(day)
		days.add_child(row)
		_rows.append(row)
		_row_at.append(at)
		at += REVIEW_STEP if day.review else DAY_STEP


## "TIME CARD" and, right-aligned, "CASHIER · TILL 4" over "WEEK 2 OF 3", over an ink rule.
func _head(model: WeekCardModel) -> Control:
	var head: VBoxContainer = _column(4)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(row)
	var title: Label = UiKit.display_label(WeekCardModel.CARD_TITLE, TITLE_SIZE, false)
	title.name = "Title"
	title.add_theme_color_override("font_color", Palette.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var sub: Label = _bold(
		"%s\n%s" % [WeekCardModel.CARD_SUB, model.head()], SUB_SIZE, Palette.MUSTARD_DARKEST
	)
	sub.name = "Sub"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(sub)
	var rule: ColorRect = ColorRect.new()
	rule.color = Palette.INK
	rule.custom_minimum_size.y = 3
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(rule)
	return head


## The week's banner, in its colour: "WEEK 2 OF 3", the event's name, its effect, and the
## training week's slips.
func _make_banner(model: WeekCardModel) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Banner"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel", _box(colour_of(model.week_number), Palette.INK, BANNER_BORDER, BANNER_PADDING)
	)
	var column: VBoxContainer = _column(1)
	panel.add_child(column)
	var key: Label = _bold(model.head(), BANNER_KEY_SIZE, Palette.PAPER)
	key.name = "Key"
	column.add_child(key)
	var title: Label = UiKit.display_label(model.title(), BANNER_TITLE_SIZE, true)
	title.name = "WeekTitle"
	column.add_child(title)
	var effect: String = model.effect()
	var slips: String = model.slips_text()
	if not slips.is_empty():
		effect = "%s · %s" % [effect, slips] if not effect.is_empty() else slips
	var line: Label = _bold(effect, BANNER_EFFECT_SIZE, Palette.PAPER)
	line.name = "Effect"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapping label needs its width to measure its height before the card is laid out.
	line.custom_minimum_size.x = BANNER_TEXT_WIDTH
	line.visible = not effect.is_empty()
	column.add_child(line)
	for label: Label in [key, title, line]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel


## A day's row: the punch column (its number and "IN"), then its events.
func _day_row(day: WeekCardModel.WeekDay) -> Control:
	var row: PanelContainer = PanelContainer.new()
	row.name = "Day%d" % day.shift
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: StyleBoxFlat = _box(Color.TRANSPARENT, Palette.INK, 0, 0)
	line.border_width_bottom = 2
	row.add_theme_stylebox_override("panel", line)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_theme_constant_override("separation", 0)
	row.add_child(columns)
	var clock: PanelContainer = PanelContainer.new()
	clock.name = "Punch"
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.custom_minimum_size.x = PUNCH_WIDTH
	var clock_box: StyleBoxFlat = _box(
		Palette.MUSTARD if day.review else Palette.CREAM, Palette.INK, 0, 4
	)
	clock_box.border_width_right = 2
	clock.add_theme_stylebox_override("panel", clock_box)
	columns.add_child(clock)
	var stack: VBoxContainer = _column(2)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	clock.add_child(stack)
	var number: Label = UiKit.number_label(str(day.shift), DAY_SIZE, false)
	number.add_theme_color_override("font_color", Palette.INK)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(number)
	var punch: Label = _bold(WeekCardModel.PUNCH, PUNCH_SIZE, Palette.VELVET)
	punch.name = "In"
	punch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	punch.rotation_degrees = -8.0
	punch.add_theme_stylebox_override("normal", _box(Color.TRANSPARENT, Palette.VELVET, 2, 2))
	punch.modulate.a = 1.0 if day.punched else 0.0
	stack.add_child(punch)
	_punches.append(punch)
	var body: PanelContainer = PanelContainer.new()
	body.name = "Events"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tint: Color = Palette.MUSTARD_LIGHT if day.review else Color.TRANSPARENT
	body.add_theme_stylebox_override("panel", _box(tint, Palette.INK, 0, 5))
	columns.add_child(body)
	var events: VBoxContainer = _column(ROW_GAP)
	body.add_child(events)
	if day.review:
		var head: Label = _bold(day.head(), REVIEW_HEAD_SIZE, Palette.MUSTARD_DARKEST)
		head.name = "ReviewHead"
		events.add_child(head)
	if day.events.is_empty():
		events.add_child(_event_row(null))
	for event: InspectionDefinition in day.events:
		events.add_child(_event_row(event))
	if not day.reward().is_empty():
		events.add_child(_reward_row(day))
	return row


## One day event by name and effect (null: "Normal day · No event"), tinted by its tone.
func _event_row(event: InspectionDefinition) -> Control:
	var boon: bool = event != null and event.is_boon()
	var fill: Color = Color.TRANSPARENT
	var border: Color = Palette.GREY
	var ink: Color = Palette.GREY_DARK
	if event != null:
		fill = Palette.GREEN_LIGHT if boon else Palette.TOMATO_PALE
		border = Palette.GREEN_DARK if boon else Palette.TOMATO_DARK
		ink = Palette.GREEN_DARK if boon else Palette.TOMATO_DARK
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Event"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(fill, border, 2, 4))
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	if event != null:
		var icon: TextureRect = UiKit.sprite(BOON if boon else WARNING)
		icon.custom_minimum_size = icon.texture.get_size()
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	var text: VBoxContainer = _column(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var title: String = event.display_name if event != null else WeekCardModel.NO_EVENT
	var name_label: Label = UiKit.display_label(title, EVENT_NAME_SIZE, false)
	name_label.name = "Name"
	name_label.add_theme_color_override("font_color", ink)
	text.add_child(name_label)
	var effect: String = WeekCardModel.NO_EVENT_EFFECT
	if event != null:
		effect = event.chip_text if not event.chip_text.is_empty() else event.notice_text
	var effect_label: Label = _bold(effect, EVENT_EFFECT_SIZE, Palette.INK)
	effect_label.name = "Effect"
	text.add_child(effect_label)
	return panel


## A review's reward: gold with two tickets ("REVIEW PASSED · 2 PREMIUM TICKETS"), or the last
## review's mustard light with the check mark ("PASS = RUN WON").
func _reward_row(day: WeekCardModel.WeekDay) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Reward"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: Color = Palette.MUSTARD_PALE if day.final else Palette.GOLD
	panel.add_theme_stylebox_override("panel", _box(fill, Palette.INK, 2, 4))
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	var icons: Array[Texture2D] = [CHECK]
	if not day.final:
		icons = [TICKET, TICKET]
	for texture: Texture2D in icons:
		var icon: TextureRect = UiKit.sprite(texture)
		icon.custom_minimum_size = texture.get_size()
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	var line: Label = _bold(day.reward(), REWARD_SIZE, Palette.INK)
	line.name = "RewardText"
	row.add_child(line)
	return panel


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
