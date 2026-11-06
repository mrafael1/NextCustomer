class_name OvertimeChip
extends VBoxContainer
## The over-quota rewards' cue at the checkout (v1.03, OvertimeTickets): when the count's laps
## reach a reward's ×N (QuotaMeter.lap_reached, through QuotaCrossing) a pill pops in beside the
## gauge's top, under the top bar: "×2 [ticket] +1 TICKET" in mustard (the bonus ticket's pill
## look), "×3 [ticket] PREMIUM TICKET" in velvet with gold text (the PREMIUM machine's dressing),
## or, when the week's reward is already used, a subdued steel "×2 · USED THIS WEEK". Each pill
## stays under MAX_WIDTH, so the chip fits between the register tower and the monitor. A ×3 shift
## shows both of its rows. The pills stay past the count's end (the dessert's printer feed, or a
## skipped dessert's) for HOLD_SECONDS, then fade over FADE_SECONDS (fade_out), so a skipped
## count still shows them; the machine opening (MachineFlow.open) fades them at once, so they
## never cover it, and the next count clears them. Decor only: what the shift earned
## is the checkout's (CountUpContext, OvertimeCue.dress).

## A pill's look: its body, border and text colours by OvertimeTickets.State (EARNED, USED), and
## the PREMIUM pill's.
const EARNED_FILL := Palette.MUSTARD
const PREMIUM_FILL := Palette.VELVET
const PREMIUM_TEXT := Palette.GOLD
const USED_FILL := Palette.STEEL_PALE
const USED_BORDER := Palette.STEEL_DARK
const USED_TEXT := Palette.INK_LIGHT
const BORDER := 2
const PAD := Vector2(4, 2)
const GAP := 4
const ROW_GAP := 4
const FONT_SIZE := 12
## The widest a pill may be (stage px): the room between the tower and the monitor, less a gap.
const MAX_WIDTH := 168.0
const FONT_WEIGHT := 800
const TICKET := preload("res://art/icons/bonus_ticket.png")
## The pop as a pill shows: from POP_SCALE over POP_SECONDS (none under reduced motion).
const POP_SCALE := 1.6
const POP_SECONDS := 0.18
const LEAD := "%s"
## After the count: held, then faded out (fade_out; at once under reduced motion's fade).
const HOLD_SECONDS := 1.6
const FADE_SECONDS := 0.3
const USED_LEAD := "%s ·"

var reduced_motion: bool = false
## The rows shown, by reward (false: the extra ticket, true: the PREMIUM transform).
var _rows: Dictionary[bool, PanelContainer] = {}
var _fade: Tween


func _init() -> void:
	name = "OvertimeChip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", ROW_GAP)
	visible = false


## Shows the row of a reward (`premium`: the PREMIUM transform, else the extra ticket) in `state`
## (OvertimeTickets.State: EARNED or USED; NONE shows nothing), naming its laps `laps` ("×2").
func show_reward(premium: bool, state: int, laps: String) -> void:
	if state == OvertimeTickets.State.NONE or _rows.has(premium):
		return
	var row: PanelContainer = _make_row(premium, state, laps)
	_rows[premium] = row
	add_child(row)
	# The extra ticket's row stays on top.
	if not premium and _rows.has(true):
		move_child(row, 0)
	visible = true
	if not reduced_motion:
		row.pivot_offset = row.get_combined_minimum_size() / 2.0
		row.scale = Vector2.ONE * POP_SCALE
		var tween: Tween = row.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(row, "scale", Vector2.ONE, POP_SECONDS)


## Holds the rows HOLD_SECONDS, then fades them out over FADE_SECONDS and removes them; nothing
## without rows, or while a fade is under way.
func fade_out() -> void:
	if _rows.is_empty() or fading():
		return
	_start_fade(HOLD_SECONDS)


## Fades the rows out now, over FADE_SECONDS (no hold; a held fade under way is cut short).
func fade_now() -> void:
	if _rows.is_empty():
		return
	if fading():
		_fade.kill()
	_start_fade(0.0)


func _start_fade(hold: float) -> void:
	_fade = create_tween()
	if hold > 0.0:
		_fade.tween_interval(hold)
	_fade.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_fade.tween_callback(clear)


## Whether the rows are fading out after the count (fade_out).
func fading() -> bool:
	return _fade != null and _fade.is_valid()


## Removes every row at once (a fade_out under way stops).
func clear() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
	modulate.a = 1.0
	for row: PanelContainer in _rows.values():
		row.queue_free()
	_rows.clear()
	visible = false


## The rows' texts, top to bottom (for tests).
func texts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for child: Node in get_children():
		if child is PanelContainer and not child.is_queued_for_deletion():
			var parts: PackedStringArray = PackedStringArray()
			for label: Node in child.find_children("*", "Label", true, false):
				parts.append((label as Label).text)
			found.append(" ".join(parts))
	return found


## The rows' rects in global coordinates, top to bottom (for tests).
func row_rects() -> Array[Rect2]:
	var found: Array[Rect2] = []
	for child: Node in get_children():
		if child is PanelContainer and not child.is_queued_for_deletion():
			found.append((child as Control).get_global_rect())
	return found


func _make_row(premium: bool, state: int, laps: String) -> PanelContainer:
	var used: bool = state == OvertimeTickets.State.USED
	var fill: Color = EARNED_FILL
	var ink: Color = Palette.INK
	if used:
		fill = USED_FILL
		ink = USED_TEXT
	elif premium:
		fill = PREMIUM_FILL
		ink = PREMIUM_TEXT
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "PremiumRow" if premium else "TicketRow"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = USED_BORDER if used else Palette.INK
	style.set_border_width_all(BORDER)
	style.content_margin_left = PAD.x
	style.content_margin_right = PAD.x
	style.content_margin_top = PAD.y
	style.content_margin_bottom = PAD.y
	panel.add_theme_stylebox_override("panel", style)
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", GAP)
	# Every row is as tall as an earned one (its ticket's height), USED rows too, so the first row
	# covers the ceiling lamp's shade whatever the state (v1.13 review).
	line.custom_minimum_size.y = TICKET.get_size().y * 2.0
	panel.add_child(line)
	line.add_child(_label((USED_LEAD if used else LEAD) % laps, ink))
	if not used:
		var ticket: TextureRect = UiKit.sprite(TICKET)
		ticket.custom_minimum_size = TICKET.get_size() * 2.0
		ticket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(ticket)
	var words: String = OvertimeWords.CHIP_PREMIUM if premium else OvertimeWords.CHIP_TICKET
	line.add_child(_label(OvertimeWords.CHIP_USED if used else words, ink))
	return panel


static func _label(caption: String, colour: Color) -> Label:
	var line: Label = UiKit.body_label(caption, FONT_SIZE, colour)
	line.add_theme_font_override("font", ArtStyle.bold_font(FONT_WEIGHT))
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return line
