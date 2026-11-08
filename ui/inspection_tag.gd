class_name InspectionTag
extends PanelContainer
## The current shift's day events in the top bar (plan section 3.9; #80 step 10, mock-up B2): an
## inspection's (a MALUS) chip is tomato pale with the mustard warning sign and "Inspection" in the
## body font; a boon day's (v0.69) is green with the boon coin and the boon's name ("Quiet
## morning"). Since v1.15 (the user's play-test note of 2026-11-07: "Days shouldn't show quick
## effect", the bar grew and shrank from day to day) the chip names only the day's kind, no
## effect; its hover text and the slip that drops on a tap (DaySlip) keep the effects. Its width is
## fixed (reserved_width: its longest text, the run's event names among them), so the top bar
## stands still from day to day. Visible for the whole shift, so the change is never shown only
## inside an animation. Hovering it shows each event's name and notice. Hidden on shifts without
## an event. Day events never go on the loyalty card.
##
## The day chip (v0.70, the time card): with a day (a balance with weeks) it leads with "D3" in
## the number font and stays visible on a day without an event, grey with "Normal day"; a Manager's
## review's chip is mustard. Tapping it drops today's slip under it in planning (`pressed`,
## DaySlip; 2026-10-31, the week chip keeps the time card).
##
## Planning effects (#71): hovering it reports hovered / unhovered (its tooltip stays);
## set_relation rings it in gold and, for an inspection that causes the hovered item's effect,
## prints that inspection's name instead of the effects (one tag shows every inspection). The
## items it hits show its stamp on the belt (PlanningLayer), so the chip carries no count.
##
## The bonus ticket (#77 machine v2, show_bonus): when passing the shift earns it (PROMISED,
## RewardMachine.bonus_if_passed), a mustard pill after the text says so: "PASS ›", the ticket
## icon, "+1 BONUS TICKET" (bold Atkinson PILL_SIZE, a 2 px ink border). Once the shift has passed
## and earned it (EARNED), the chip turns teal pale with the check mark and "<name> passed", the
## pill keeping the icon and "+1 BONUS TICKET". BonusNotice pulses the chip once as planning opens.
##
## A Day off pin (#132, the user's call of 2026-11-02: the skip is on the day chip): while today
## can be taken off (show_skip), a teal "SKIP ›" tag ends the chip; a tap on it says
## `skip_pressed` (not `pressed`: the slip stays up), and armed (the day off's pile on the belt)
## it reads "UNDO ‹". While the run wears the pin, the chip keeps the tag's room on every day
## (show_skip's `reserved`), so the tag coming and going never moves the bar.

## The pointer entered or left the tag.
signal hovered
signal unhovered
## The SKIP tag was tapped (#132, a Day off pin: PinFlow arms, then takes the day off).
signal skip_pressed
## The chip was tapped (today's slip drops, DaySlip).
signal pressed

## The bonus ticket's pill: none, promised for a pass, or earned by the pass.
enum Bonus { NONE, PROMISED, EARNED }

## The red notice printed under a passed shift's total when the next shift is inspected.
const NEXT_NOTICE := "INSPECTION NEXT SHIFT: %s"
## A Manager's review's notice (v0.65): its several inspections at once, their notices joined.
const NEXT_REVIEW_NOTICE := "MANAGER'S REVIEW NEXT SHIFT: %s"
## A boon day's notice (v0.69), in green (ReceiptView.BOON_NOTICE_PREFIX): "TOMORROW: Quiet
## morning (quota −10%)".
const NEXT_BOON_NOTICE := ReceiptView.BOON_NOTICE_PREFIX + "%s"
## The chip's text (v1.15: the day's kind only): an inspected shift's, and a Manager's review's
## (several at once, v0.65); a boon day's is the boon's name, a day without an event NO_EVENT.
const CAPTION := "Inspection"
const REVIEW_CAPTION := "Review"
## The day chip's day (v0.70) and its text on a day without an event.
const DAY_TEXT := "D%d"
const DAY_FONT_SIZE := 20
const NO_EVENT := WeekCardModel.NO_EVENT
## A boon's words in its notice (v0.69): "TOMORROW: Quiet morning (quota −10%)".
const BOON_TEXT := "%s (%s)"
const FONT_SIZE := 14
const FONT_WEIGHT := 700
## The warning sign (13x11 art) at 2x.
const ICON_SIZE := Vector2(26, 22)
## The gold ring's line (#71).
const RING_WIDTH := 2.0
## The bonus ticket's pill (#77 machine v2): its texts, size, weight, padding and gaps.
const PASS_WORD := "PASS ›"
const PILL_TEXT := "+1 BONUS TICKET"
## The pill's text when the top bar has no room for the whole chip (fit_width).
const PILL_SHORT := "+1"
## The tooltip's line for the promised ticket (the pill may be short).
const PILL_TIP := "PASS › +1 BONUS TICKET"
const EARNED_TEXT := "%s passed"
const PILL_SIZE := 12
const SKIP_TEXT := "SKIP ›"
const SKIP_ARMED_TEXT := "UNDO ‹"
const PILL_WEIGHT := 800
const PILL_PAD := Vector2(6, 1)
const PILL_GAP := 4

const CHIP_FRAME := preload("res://art/frames/chip_warn.png")
const WARNING := preload("res://art/icons/warning.png")
const BOON := preload("res://art/icons/boon.png")
const CHECK := preload("res://art/icons/mark_check.png")
const TICKET := preload("res://art/icons/bonus_ticket.png")

var _label: Label
var _icon: TextureRect
## "D3" (v0.70; hidden without a day).
var _day_label: Label
var _day: int = 0
var _pill: PanelContainer
var _pass_word: Label
var _pill_label: Label
var _skip: PanelContainer
var _skip_label: Label
var _bonus: Bonus = Bonus.NONE
var _inspections: Array[InspectionDefinition] = []
## The day's kind (show_inspections), printed while no cause is named.
var _shown_text: String = ""
## Every text the chip may print this run (its kinds, the run's event names), for its width.
var _texts: PackedStringArray = PackedStringArray()
## The SKIP tag's room is kept on every day (show_skip's `reserved`).
var _skip_reserved: bool = false
## fit_width had less than reserved_width (the bar shortens something else first).
var _squeezed: bool = false
var _ringed: bool = false
## fit_width gave up the pill's "PASS ›" (the bonus state keeps it hidden until the next fit).
var _pass_hidden: bool = false
## The inspections' names and notices (show_inspections), the tooltip's start.
var _tips: String = ""


func _init() -> void:
	name = "InspectionTag"
	var style: StyleBoxTexture = ArtStyle.frame_style(CHIP_FRAME, FramedButton.FRAME_MARGIN)
	style.content_margin_left = TopBar.CHIP_PADDING
	style.content_margin_right = TopBar.CHIP_PADDING
	add_theme_stylebox_override("panel", style)
	custom_minimum_size.y = TopBar.ROW_SIZE.y
	ArtStyle.use_pixel_material(self)
	# PASS, not IGNORE: the tooltip needs the mouse.
	mouse_filter = Control.MOUSE_FILTER_PASS
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", TopBar.CHIP_SEPARATION)
	add_child(row)
	_day_label = UiKit.number_label("", DAY_FONT_SIZE, false)
	_day_label.name = "Day"
	_day_label.add_theme_color_override("font_color", Palette.INK)
	_day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_day_label.visible = false
	row.add_child(_day_label)
	_icon = UiKit.sprite(WARNING)
	_icon.custom_minimum_size = ICON_SIZE
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	_label = UiKit.body_label("", FONT_SIZE, Palette.INK)
	_label.add_theme_font_override("font", ArtStyle.bold_font(FONT_WEIGHT))
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The chip's width is reserved_width, never its text's: a text too long for it is trimmed.
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)
	_pill = _make_pill()
	row.add_child(_pill)
	_skip = _make_skip()
	row.add_child(_skip)
	visible = false


## Shows the shift's day events by their kind (empty: hidden): "Inspection", "Review" for several,
## a boon day's boon name (v1.15: no effect; hovering shows each one's name and notice). With a
## 1-based `day_number` (v0.70) the chip leads with "D<day>", shows "Normal day" without an event
## and can be tapped. `pool`: every day event the run may draw (its balance's pools), whose names
## the chip keeps room for (reserved_width), so its width is the same every day.
func show_inspections(
	inspections: Array[InspectionDefinition],
	day_number: int = 0,
	pool: Array[InspectionDefinition] = []
) -> void:
	_day = day_number
	_day_label.text = DAY_TEXT % day_number
	_day_label.visible = day_number > 0
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if day_number > 0 else CURSOR_ARROW
	visible = not inspections.is_empty() or day_number > 0
	_inspections = inspections.duplicate()
	var tips: PackedStringArray = PackedStringArray()
	for inspection: InspectionDefinition in inspections:
		var kind: String = "TODAY" if inspection.is_boon() else "INSPECTION"
		tips.append("%s: %s\n%s" % [kind, inspection.display_name, inspection.notice_text])
	_shown_text = kind_text(inspections)
	_label.text = _shown_text
	_texts = PackedStringArray([NO_EVENT, CAPTION, REVIEW_CAPTION, _shown_text])
	for event: InspectionDefinition in pool + inspections:
		_texts.append(event.display_name)
	_tips = "\n\n".join(tips)
	_show_bonus_state()
	custom_minimum_size.x = reserved_width()


## The bonus ticket's pill (#77 machine v2): NONE hides it; PROMISED shows "PASS › [ticket] +1
## BONUS TICKET"; EARNED turns the chip teal pale, its text "<name> passed" with the check mark.
func show_bonus(state: Bonus) -> void:
	_bonus = state
	_show_bonus_state()


func bonus_state() -> Bonus:
	return _bonus


## Shows the SKIP tag (#132: today can be taken off), "UNDO ‹" while `armed`, or hides it.
## `reserved` (the run wears a Day off pin) keeps its room while it is hidden. Returns whether the
## chip's width changed (the bar is then fitted again: TopBar.fit_inspection).
func show_skip(shown: bool, armed: bool = false, reserved: bool = false) -> bool:
	var before: float = reserved_width()
	_skip.visible = shown
	_skip_reserved = reserved or shown
	_skip_label.text = SKIP_ARMED_TEXT if armed else SKIP_TEXT
	var style: StyleBoxFlat = _skip.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = Palette.MUSTARD if armed else Palette.TEAL_LIGHT
	return not is_equal_approx(before, reserved_width())


## The SKIP tag (for layout tests).
func skip_tag() -> Control:
	return _skip


## The pill (for layout tests and the pulse).
func pill() -> Control:
	return _pill


## Every text the chip shows, the pill's included ("Inspection · −1 slot PASS › +1 BONUS TICKET").
func full_text() -> String:
	var parts: PackedStringArray = PackedStringArray([_label.text])
	if _pill.visible:
		if _pass_word.visible:
			parts.append(_pass_word.text)
		parts.append(_pill_label.text)
	return " ".join(parts)


## Rings the tag in gold (#71), or takes the ring off. `cause`: the shift's inspection (its
## index) that causes the hovered item's effect: the tag prints its name until the ring comes off
## (the chip's fixed width has room for every event's name: reserved_width).
func set_relation(related: bool, cause: int = -1) -> void:
	_ringed = related
	var named: bool = related and cause >= 0 and cause < _inspections.size()
	_label.text = _inspections[cause].display_name if named else _shown_text
	if not named:
		_show_bonus_state()
	queue_redraw()


func has_relation() -> bool:
	return _ringed


## The day shown ("D3"), 0 for none (for tests).
func day() -> int:
	return _day


## The day's label (for layout tests).
func day_label() -> Label:
	return _day_label


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if _day > 0 and press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _skip.visible and _skip.get_global_rect().grow(2.0).has_point(press.global_position):
			skip_pressed.emit()
		else:
			pressed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hovered.emit()
	elif what == NOTIFICATION_MOUSE_EXIT:
		unhovered.emit()


## The gold ring round the chip while it is related to the hovered item (over the frame).
func _draw() -> void:
	if _ringed:
		draw_rect(
			Rect2(Vector2.ZERO, size).grow(-RING_WIDTH / 2.0), Palette.GOLD, false, RING_WIDTH
		)


## The label printing the text (for layout tests).
func label() -> Label:
	return _label


## Keeps the chip within `width` (TopBar.fit_inspection): its fixed width (reserved_width) when
## it fits; else it gives up the pill's "PASS ›", then the pill's words down to its ticket and "+1"
## (the tooltip keeps the whole line), and takes `width`, its text trimmed with an ellipsis only if
## it no longer fits (the tooltip keeps it whole). The bonus state keeps what it gave up.
func fit_width(width: float) -> void:
	_pass_hidden = false
	_pill_label.text = PILL_TEXT
	_pass_word.visible = _bonus == Bonus.PROMISED
	if reserved_width() > width and _pass_word.visible:
		_pass_hidden = true
		_pass_word.visible = false
	if reserved_width() > width and _pill.visible:
		_pill_label.text = PILL_SHORT
	_squeezed = reserved_width() > width
	custom_minimum_size.x = minf(reserved_width(), width)


## The chip's fixed width (v1.15): its padding, the day ("D88": its widest digits), the widest icon
## and its widest text (every day kind, the run's event names: show_inspections' `pool`), the SKIP
## tag's room while the run wears a Day off (show_skip), and the pill while it shows (no default
## balance shows it: a review's pass pays a payday instead).
func reserved_width() -> float:
	var gap: float = TopBar.CHIP_SEPARATION
	var width: float = get_theme_stylebox("panel").get_minimum_size().x
	if _day_label.visible:
		width += _widest_day() + gap
	width += maxf(ICON_SIZE.x, maxf(BOON.get_width(), CHECK.get_width()) * 2.0) + gap
	width += _widest_text()
	if _skip_reserved:
		width += gap + TopBar.fresh_width(_skip)
	if _pill.visible:
		width += gap + TopBar.fresh_width(_pill)
	return ceilf(width)


## Whether the chip shows a boon day only (v0.69: green, the boon coin), no inspection.
func is_boon() -> bool:
	return not _inspections.is_empty() and InspectionDefinition.maluses(_inspections).is_empty()


## Whether the text is trimmed to fit (fit_width gave the chip less than its text needs).
func is_trimmed() -> bool:
	var room: float = _widest_text() - maxf(0.0, reserved_width() - custom_minimum_size.x)
	return text_width(_label.text) > room


## Whether fit_width had less than the chip's fixed width (reserved_width), the pill's short forms
## given up first: the bar makes room elsewhere (TopBar.fit_inspection). It depends on the run
## (and a bonus pill, which no default balance shows), never on the day's kind.
func is_shortened() -> bool:
	return _squeezed


## `words` width in the chip's text font (its label's).
func text_width(words: String) -> float:
	var font: Font = _label.get_theme_font(&"font")
	var font_size: int = _label.get_theme_font_size(&"font_size")
	return ceilf(font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)


## The day's kind on the chip (v1.15): "Review" for several inspections, "Inspection" for one, a
## boon day's boon name, else NO_EVENT.
static func kind_text(events: Array[InspectionDefinition]) -> String:
	match WeekCardModel.kind_of(events):
		WeekCardModel.Kind.REVIEW:
			return REVIEW_CAPTION
		WeekCardModel.Kind.MALUS:
			return CAPTION
		WeekCardModel.Kind.BOON:
			return ", ".join(names(InspectionDefinition.boons(events)))
	return NO_EVENT


func _widest_text() -> float:
	var widest: float = 0.0
	for words: String in _texts:
		widest = maxf(widest, text_width(words))
	return widest


## The widest "D<n>" a run can show: two of the number font's widest digit.
func _widest_day() -> float:
	var font: Font = _day_label.get_theme_font(&"font")
	var font_size: int = _day_label.get_theme_font_size(&"font_size")
	var digit: float = 0.0
	for number: int in range(10):
		digit = maxf(
			digit, font.get_string_size(str(number), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
	return ceilf(
		font.get_string_size("D", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 2.0 * digit
	)


## The chip's look for the bonus state: the pill, the icon, the text and the chip's tint.
func _show_bonus_state() -> void:
	var earned: bool = _bonus == Bonus.EARNED
	_pill.visible = _bonus != Bonus.NONE
	_pass_word.visible = _bonus == Bonus.PROMISED and not _pass_hidden
	var boon: bool = is_boon()
	var icon: Texture2D = CHECK if earned else (BOON if boon else WARNING)
	_icon.visible = earned or not _inspections.is_empty()
	_icon.texture = icon
	_icon.custom_minimum_size = icon.get_size() * 2.0 if earned or boon else ICON_SIZE
	if earned:
		var passed: Array[InspectionDefinition] = InspectionDefinition.maluses(_inspections)
		_label.text = EARNED_TEXT % ", ".join(names(passed))
	elif _label.text != _shown_text and not _ringed:
		_label.text = _shown_text
	# The paper chip tinted: teal pale once earned, green for a boon day, tomato pale for an
	# inspection.
	var pale: Color = tint_of(WeekCardModel.kind_of(_inspections))
	if earned:
		pale = Palette.TEAL_PALE
	var paper: Color = Palette.PAPER
	self_modulate = Color(pale.r / paper.r, pale.g / paper.g, pale.b / paper.b)
	tooltip_text = _tips + ("\n\n" + PILL_TIP if _bonus == Bonus.PROMISED else "")


## The mustard pill: "PASS ›", the ticket icon at 2x, "+1 BONUS TICKET".
func _make_pill() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "BonusPill"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.MUSTARD
	style.border_color = Palette.INK
	style.set_border_width_all(2)
	style.content_margin_left = PILL_PAD.x
	style.content_margin_right = PILL_PAD.x
	style.content_margin_top = PILL_PAD.y
	style.content_margin_bottom = PILL_PAD.y
	panel.add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", PILL_GAP)
	panel.add_child(row)
	_pass_word = _pill_text_label(PASS_WORD)
	row.add_child(_pass_word)
	var ticket: TextureRect = UiKit.sprite(TICKET)
	ticket.custom_minimum_size = TICKET.get_size() * 2.0
	ticket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ticket)
	_pill_label = _pill_text_label(PILL_TEXT)
	row.add_child(_pill_label)
	panel.visible = false
	return panel


## The SKIP tag (#132): teal light (mustard armed), a 2 px ink border, bold Atkinson PILL_SIZE.
func _make_skip() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "SkipTag"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.TEAL_LIGHT
	style.border_color = Palette.INK
	style.set_border_width_all(2)
	style.content_margin_left = PILL_PAD.x
	style.content_margin_right = PILL_PAD.x
	style.content_margin_top = PILL_PAD.y
	style.content_margin_bottom = PILL_PAD.y
	panel.add_theme_stylebox_override("panel", style)
	# As wide as "SURE? ›" from the start, so arming it never moves the top bar.
	_skip_label = _pill_text_label(SKIP_ARMED_TEXT)
	_skip_label.custom_minimum_size.x = _skip_label.get_minimum_size().x
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_label.text = SKIP_TEXT
	panel.add_child(_skip_label)
	panel.visible = false
	return panel


## A day's tint (v0.70): green for a boon day, tomato pale for an inspection, mustard pale for a
## Manager's review, grey light for a day without an event.
static func tint_of(kind: WeekCardModel.Kind) -> Color:
	match kind:
		WeekCardModel.Kind.BOON:
			return Palette.GREEN_LIGHT
		WeekCardModel.Kind.REVIEW:
			return Palette.MUSTARD_LIGHT
		WeekCardModel.Kind.NONE:
			return Palette.GREY_LIGHT
	return Palette.TOMATO_PALE


static func _pill_text_label(caption: String) -> Label:
	var line: Label = UiKit.body_label(caption, PILL_SIZE, Palette.INK)
	line.add_theme_font_override("font", ArtStyle.bold_font(PILL_WEIGHT))
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return line


## The tag's text (for tests): the day's kind, or the named inspection's name.
func text() -> String:
	return _label.text


## Where each of the shift's inspections is shown (all on this tag), indexed like the shift's
## inspections (a step's source_index), for the count-up.
func sources(inspections: Array[InspectionDefinition]) -> Array[Control]:
	var controls: Array[Control] = []
	for _inspection: InspectionDefinition in inspections:
		controls.append(self)
	return controls


## The inspections' names, indexed like the shift's inspections, for the receipt.
static func names(inspections: Array[InspectionDefinition]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for inspection: InspectionDefinition in inspections:
		result.append(inspection.display_name)
	return result


## The chip's bonus ticket for `run` (#77 machine v2): PROMISED in planning when passing the shift
## earns it (RewardMachine.bonus_if_passed), EARNED at the machine once the count-up is over when
## the pass earned it (bonus_earned); while `counting`, the chip keeps its `shown` state (as
## planning left it). A payday's two PREMIUM tickets (v0.68) are the PREMIUM announce's and the
## machine's banner: the chip shows no bonus pill for them.
static func bonus_for(run: RunState, counting: bool, shown: Bonus) -> Bonus:
	if run.machine == null:
		return Bonus.NONE
	if RunState.MACHINE_PHASES.has(run.phase):
		if counting:
			return shown
		var payday: bool = run.machine.machine.is_payday_shift(run.history[-1].shift)
		return Bonus.EARNED if run.machine.bonus_earned(run) and not payday else Bonus.NONE
	if Payday.if_passed(run):
		return Bonus.NONE
	if run.phase == RunState.Phase.PLANNING and run.machine.bonus_if_passed(run):
		return Bonus.PROMISED
	return Bonus.NONE


## The notice for the next shift's day events, or "" when it has none: its inspections' (a
## Manager's review's several, v0.65, named all), then its boon's (v0.69: "TOMORROW: Quiet
## morning (quota −10%)", in green when it is the only event).
static func next_notice(next_inspections: Array[InspectionDefinition]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var maluses: Array[InspectionDefinition] = InspectionDefinition.maluses(next_inspections)
	if not maluses.is_empty():
		var notices: PackedStringArray = PackedStringArray()
		for inspection: InspectionDefinition in maluses:
			notices.append(inspection.notice_text)
		var notice: String = NEXT_REVIEW_NOTICE if maluses.size() > 1 else NEXT_NOTICE
		parts.append(notice % " · ".join(notices))
	var boons: Array[InspectionDefinition] = InspectionDefinition.boons(next_inspections)
	if not boons.is_empty():
		parts.append(NEXT_BOON_NOTICE % ", ".join(boon_texts(boons)))
	return " · ".join(parts)


## Each boon's "<name> (<effect>)" (its chip_text; the name alone without one).
static func boon_texts(boons: Array[InspectionDefinition]) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for boon: InspectionDefinition in boons:
		var effect: String = boon.chip_text
		texts.append(
			BOON_TEXT % [boon.display_name, effect] if not effect.is_empty() else boon.display_name
		)
	return texts
