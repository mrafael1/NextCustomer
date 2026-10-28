class_name InspectionTag
extends PanelContainer
## The current shift's day events in the top bar (plan section 3.9; #80 step 10, mock-up B2): an
## inspection's (a MALUS) chip is tomato pale with the mustard warning sign and "Inspection ·
## <effect>" in the body font (each inspection's chip_text, from data, e.g. "Inspection · −1
## slot"); a boon day's (v0.69) is green with the boon coin and "Today: <name> — <effect>" ("Today:
## Quiet morning — quota −10%"). Visible for the whole shift, so the change is never shown only
## inside an animation. Hovering it shows each event's name and notice. Hidden on shifts without
## an event. Day events never go on the loyalty card.
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

## The pointer entered or left the tag.
signal hovered
signal unhovered

## The bonus ticket's pill: none, promised for a pass, or earned by the pass.
enum Bonus { NONE, PROMISED, EARNED }

## The red notice printed under a passed shift's total when the next shift is inspected.
const NEXT_NOTICE := "INSPECTION NEXT SHIFT: %s"
## A Manager's review's notice (v0.65): its several inspections at once, their notices joined.
const NEXT_REVIEW_NOTICE := "MANAGER'S REVIEW NEXT SHIFT: %s"
## A boon day's notice (v0.69), in green (ReceiptView.BOON_NOTICE_PREFIX): "TOMORROW: Quiet
## morning — quota −10%".
const NEXT_BOON_NOTICE := ReceiptView.BOON_NOTICE_PREFIX + "%s"
## The chip's caption: an inspected shift's, and a Manager's review's (several at once, v0.65).
const CAPTION := "Inspection"
const REVIEW_CAPTION := "Review"
## A boon's words on the chip and its notice (v0.69): "Today: Quiet morning — quota −10%".
const TODAY_TEXT := "Today: %s"
const BOON_TEXT := "%s — %s"
const FONT_SIZE := 14
const FONT_WEIGHT := 700
## The warning sign (13x11 art) at 2x.
const ICON_SIZE := Vector2(26, 22)
## The gold ring's line (#71).
const RING_WIDTH := 2.0
## The bonus ticket's pill (#77 machine v2): its texts, size, weight, padding and gaps.
const PASS_WORD := "PASS ›"
const PILL_TEXT := "+1 BONUS TICKET"
## The pill's text when the top bar has no room for the whole line (fit_width).
const PILL_SHORT := "+1"
## The tooltip's line for the promised ticket (the pill may be short).
const PILL_TIP := "PASS › +1 BONUS TICKET"
const EARNED_TEXT := "%s passed"
const PILL_SIZE := 12
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
var _pill: PanelContainer
var _pass_word: Label
var _pill_label: Label
var _bonus: Bonus = Bonus.NONE
var _inspections: Array[InspectionDefinition] = []
## The effects' text (show_inspections), printed while no cause is named.
var _effects_text: String = ""
## The text shown when no inspection is named: _effects_text, or its short form (fit_width).
var _shown_text: String = ""
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
	_icon = UiKit.sprite(WARNING)
	_icon.custom_minimum_size = ICON_SIZE
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	_label = UiKit.body_label("", FONT_SIZE, Palette.INK)
	_label.add_theme_font_override("font", ArtStyle.bold_font(FONT_WEIGHT))
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# A named inspection keeps the chip's width (set_relation).
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)
	_pill = _make_pill()
	row.add_child(_pill)
	visible = false


## Shows the shift's day events by their effects (empty: hidden): the inspections' under their
## caption, then each boon's "Today: <name> — <effect>". Hovering shows each one's name and notice.
func show_inspections(inspections: Array[InspectionDefinition]) -> void:
	visible = not inspections.is_empty()
	_inspections = inspections.duplicate()
	var tips: PackedStringArray = PackedStringArray()
	for inspection: InspectionDefinition in inspections:
		var kind: String = "TODAY" if inspection.is_boon() else "INSPECTION"
		tips.append("%s: %s\n%s" % [kind, inspection.display_name, inspection.notice_text])
	var maluses: Array[InspectionDefinition] = InspectionDefinition.maluses(inspections)
	var parts: PackedStringArray = PackedStringArray()
	if not maluses.is_empty():
		var caption: String = REVIEW_CAPTION if maluses.size() > 1 else CAPTION
		parts.append(" · ".join(PackedStringArray([caption]) + effects(maluses)))
	var boons: Array[InspectionDefinition] = InspectionDefinition.boons(inspections)
	if not boons.is_empty():
		parts.append(TODAY_TEXT % ", ".join(boon_texts(boons)))
	_effects_text = " · ".join(parts)
	_shown_text = _effects_text
	_label.text = _effects_text
	custom_minimum_size.x = 0.0
	_tips = "\n\n".join(tips)
	_show_bonus_state()


## The bonus ticket's pill (#77 machine v2): NONE hides it; PROMISED shows "PASS › [ticket] +1
## BONUS TICKET"; EARNED turns the chip teal pale, its text "<name> passed" with the check mark.
func show_bonus(state: Bonus) -> void:
	_bonus = state
	_show_bonus_state()


func bonus_state() -> Bonus:
	return _bonus


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
## index) that causes the hovered item's effect: the tag prints its name until the ring comes off,
## keeping its width meanwhile (a shorter name would shift the top bar under the pointer).
func set_relation(related: bool, cause: int = -1) -> void:
	_ringed = related
	var named: bool = related and cause >= 0 and cause < _inspections.size()
	if named and _label.text == _shown_text:
		custom_minimum_size.x = size.x
	elif not named:
		custom_minimum_size.x = 0.0
	_label.text = _inspections[cause].display_name if named else _shown_text
	if not named:
		_show_bonus_state()
	queue_redraw()


func has_relation() -> bool:
	return _ringed


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


## Keeps the chip within `width` (TopBar.fit_inspection), never cutting the effects while
## something else can give way: the whole chip when it fits, else without the pill's "PASS ›", else
## with the pill down to its ticket and "+1" (the tooltip and the monitor's plate keep the whole
## line), else also without "Inspection · " (the warning sign says it); only then the text trimmed
## with an ellipsis (the tooltip keeps it whole). The bonus state keeps what it gave up.
func fit_width(width: float) -> void:
	_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_label.custom_minimum_size.x = 0.0
	_pass_hidden = false
	_pill_label.text = PILL_TEXT
	_pass_word.visible = _bonus == Bonus.PROMISED
	var shown: bool = _label.text == _shown_text
	if shown:
		_shown_text = _effects_text
		_label.text = _shown_text
	if get_combined_minimum_size().x <= width:
		return
	if _pass_word.visible:
		_pass_hidden = true
		_pass_word.visible = false
		if get_combined_minimum_size().x <= width:
			return
	if _pill.visible:
		_pill_label.text = PILL_SHORT
		if get_combined_minimum_size().x <= width:
			return
	if shown and not _inspections.is_empty():
		_shown_text = " · ".join(effects(_inspections))
		_label.text = _shown_text
		if get_combined_minimum_size().x <= width:
			return
	var whole: float = get_combined_minimum_size().x
	var text_width: float = _label.get_minimum_size().x
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.custom_minimum_size.x = maxf(0.0, text_width - (whole - width))


## Whether the chip shows a boon day only (v0.69: green, the boon coin), no inspection.
func is_boon() -> bool:
	return not _inspections.is_empty() and InspectionDefinition.maluses(_inspections).is_empty()


## Whether the text is trimmed to fit (fit_width).
func is_trimmed() -> bool:
	return _label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING


## The chip's look for the bonus state: the pill, the icon, the text and the chip's tint.
func _show_bonus_state() -> void:
	var earned: bool = _bonus == Bonus.EARNED
	_pill.visible = _bonus != Bonus.NONE
	_pass_word.visible = _bonus == Bonus.PROMISED and not _pass_hidden
	var boon: bool = is_boon()
	var icon: Texture2D = CHECK if earned else (BOON if boon else WARNING)
	_icon.texture = icon
	_icon.custom_minimum_size = icon.get_size() * 2.0 if earned or boon else ICON_SIZE
	if earned:
		var passed: Array[InspectionDefinition] = InspectionDefinition.maluses(_inspections)
		_label.text = EARNED_TEXT % ", ".join(names(passed))
	elif _label.text != _shown_text and not _ringed:
		_label.text = _shown_text
	# The paper chip tinted: teal pale once earned, green for a boon day, tomato pale for an
	# inspection.
	var pale: Color = Palette.TEAL_PALE if earned else Palette.TOMATO_PALE
	if boon and not earned:
		pale = Palette.GREEN_LIGHT
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


static func _pill_text_label(caption: String) -> Label:
	var line: Label = UiKit.body_label(caption, PILL_SIZE, Palette.INK)
	line.add_theme_font_override("font", ArtStyle.bold_font(PILL_WEIGHT))
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return line


## The tag's text (for tests).
func text() -> String:
	# The whole effects text, even while fit_width shows it short.
	return _effects_text if _label.text == _shown_text else _label.text


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


## The inspections' chip texts (the name for one without), indexed like the shift's inspections.
static func effects(inspections: Array[InspectionDefinition]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for inspection: InspectionDefinition in inspections:
		var effect: String = inspection.chip_text
		result.append(effect if not effect.is_empty() else inspection.display_name)
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
## morning — quota −10%", in green when it is the only event).
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


## Each boon's "<name> — <effect>" (its chip_text; the name alone without one).
static func boon_texts(boons: Array[InspectionDefinition]) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for boon: InspectionDefinition in boons:
		var effect: String = boon.chip_text
		texts.append(
			BOON_TEXT % [boon.display_name, effect] if not effect.is_empty() else boon.display_name
		)
	return texts
