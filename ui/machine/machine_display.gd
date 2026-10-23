class_name MachineDisplay
extends Panel
## The machine's char display (#77, look F; build spec 4.2-4.3; v0.50: the LED strip left of the
## receipt slot, 292 px wide, mock-up premium_machine_v1.html): the message in Pixelify 24
## (mustard light; bold Atkinson 17, then 15, 13 or 12, when it doesn't fit) with its sub line (bold
## Atkinson 11, grey light), and the BIN IT ✕ button at the right (NEW ITEMS and COUPONS visits
## only: RewardMachine.can_bin; shown from the last reveal's end until the pick or the bin, as
## look F). Pixelify and Atkinson have no ✓ or ✕: the display's fonts fall back to JetBrains Mono
## (ArtStyle.MONO_FONT) for them, the same on desktop and on the web build (marked_font).
##
## RewardMachineView gives the message for each wait point (show_message: PICK A CHUTE, the pick
## prompt, the landing's word); frame(t) plays the visit's own lines around them from the plan:
## READING…, then SPEND €N ✓ THANK YOU! with the quota met (a BONUS visit: BONUS TICKET! until
## its stub is fed), on a BOOSTED visit PREMIUM / PREMIUM RECEIPT blinking while the machine turns
## PREMIUM, PACKING… while the tray packs, each landed ticket's rarity and prize, STAMP DAY's free
## stamp, and on the landing ENJOY!, UPGRADING…, the landing's word with the cart count and SEE
## YOU NEXT SHIFT. A BOOSTED visit's receipt read says so (BOOSTED_READ).
##
## A pressed key no longer changes the display (v0.53: the tray's push bar confirms, MachineTray;
## until then a title mode with a CONFIRM › key took the strip). A BONUS visit's feed reads the
## ticket icon and "BONUS TICKET" / "inspection passed · feeding in".

signal bin_pressed

const SIZE := Vector2(292, 52)
const MESSAGE_SIZE := 24
## The message's size in bold Atkinson when Pixelify 24 doesn't fit (look F's 17 px), then the
## smaller steps when that doesn't fit either (v0.50: the strip is 292 px, 180 px beside BIN IT).
const FALLBACK_STEPS: Array[int] = [17, 15, 13, 12]
## The sub line's smaller sizes when 11 doesn't fit.
const SUB_STEPS: Array[int] = [11, 10, 9]
const SUB_SIZE := 11
const PAD := 10.0
const MESSAGE_TOP := 2.0
const MESSAGE_HEIGHT := 28.0
const SUB_TOP := 30.0
const SUB_HEIGHT := 16.0
const BIN_RECT := Rect2(196, 13, 88, 26)
const BIN_GAP := 6.0
const BIN_TEXT := "BIN IT ✕"
const BIN_SIZE := 12
## A BONUS visit's feed: the ticket icon (2x) left of BONUS TICKET.
const BONUS_TICKET := "BONUS TICKET"
const TICKET_ICON := preload("res://art/icons/bonus_ticket.png")
const ICON_SCALE := 2.0
const ICON_GAP := 6.0
const BOLD_WEIGHT := 700
const RARITY_WORDS: Array[String] = ["COMMON", "RARE!", "LEGENDARY!!"]
const READING := "READING…"
const PACKING := "PACKING…"
## A BOOSTED visit's transform (v0.50): the lines blink this often.
const PREMIUM_LINES: Array[String] = ["PREMIUM", "PREMIUM RECEIPT"]
const PREMIUM_BLINK := 6.0
const SEE_YOU := "SEE YOU NEXT SHIFT"
## A BOOSTED visit's receipt read sub line, after the quota (v0.47).
const BOOSTED_READ := " · PREMIUM RECEIPT"
## A refused key's message (show_denied) shows this long, then the wait point's comes back.
const DENIED_MS := 1200

## The display's fonts with the mark fallback, by weight (0: Pixelify).
static var _marked: Dictionary[int, FontVariation] = {}

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _message: Label
var _sub: Label
var _bin: Button
var _bin_shown: bool = false
var _icon: TextureRect
## The wait point's message and sub line (show_message), shown when the plan has no line of its
## own at the time.
var _rest: PackedStringArray = PackedStringArray(["", ""])
## A refused key's lines (show_denied) and when they were shown (Time ticks, ms).
var _denied: PackedStringArray = PackedStringArray()
var _denied_at_ms: int = 0


func _init() -> void:
	name = "MachineDisplay"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.CHARCOAL
	style.border_color = Palette.INK
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)
	_message = UiKit.display_label("", MESSAGE_SIZE, false)
	_message.name = "Message"
	_message.add_theme_font_override("font", marked_font(0))
	_message.add_theme_color_override("font_color", Palette.MUSTARD_LIGHT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.clip_text = true
	add_child(_message)
	_sub = UiKit.body_label("", SUB_SIZE, Palette.GREY_LIGHT)
	_sub.name = "Sub"
	_sub.add_theme_font_override("font", marked_font(BOLD_WEIGHT))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub.clip_text = true
	add_child(_sub)
	# Silent: MachineSounds plays the bin's ui_back when the landing is planned.
	_bin = UiKit.button(self, BIN_TEXT, func() -> void: bin_pressed.emit(), BIN_SIZE, "")
	_bin.name = "BinButton"
	_bin.add_theme_font_override("font", marked_font(0))
	_style_bin()
	RewardMachineView.fit(_bin, BIN_RECT)
	_bin.visible = false
	_icon = UiKit.sprite(TICKET_ICON)
	_icon.name = "TicketIcon"
	_icon.size = TICKET_ICON.get_size() * ICON_SCALE
	_icon.visible = false
	add_child(_icon)
	_show("", "")


## Shows `message` with `sub` under it: the wait point's line (frame(t) shows the plan's own
## lines between the wait points).
func show_message(message: String, sub: String = "") -> void:
	_rest = PackedStringArray([message, sub])
	_show(message, sub)


## A refused key's lines for DENIED_MS, then the wait point's again (show_message's stay).
func show_denied(message: String, sub: String) -> void:
	_denied = PackedStringArray([message, sub])
	_denied_at_ms = Time.get_ticks_msec()
	_show(message, sub)


## The display's font with JetBrains Mono behind it for the marks (✓ ✕) Pixelify and Atkinson
## lack: Pixelify for `weight` 0, else bold Atkinson at `weight`.
static func marked_font(weight: int) -> Font:
	if not _marked.has(weight):
		var font: FontVariation = FontVariation.new()
		font.base_font = ArtStyle.DISPLAY_FONT if weight == 0 else ArtStyle.BODY_FONT
		if weight != 0:
			var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
			font.variation_opentype = {tag: weight}
		var fallbacks: Array[Font] = [ArtStyle.MONO_FONT]
		font.fallbacks = fallbacks
		_marked[weight] = font
	return _marked[weight]


## The message and its sub line shown now, for tests.
func texts() -> PackedStringArray:
	return PackedStringArray([_message.text, _sub.text])


## The wait point's message and sub line (show_message).
func rest_texts() -> PackedStringArray:
	return _rest.duplicate()


## Whether the message is printed in Pixelify (true) or in the bold Atkinson fallback.
func message_in_display_font() -> bool:
	return _message.get_theme_font("font") == marked_font(0)


## The ticket icon left of a BONUS TICKET line, for tests.
func ticket_icon() -> TextureRect:
	return _icon


## The message and sub labels, for layout tests.
func labels() -> Array[Label]:
	return [_message, _sub]


## Offers BIN IT on this draw or not (it shows at the times frame(t) gives), and whether it can
## be pressed yet.
func set_bin(shown: bool, enabled: bool) -> void:
	_bin_shown = shown
	_bin.disabled = not enabled
	_bin.visible = _bin_at(view.clock if view != null else 0.0)
	_show(_message.text, _sub.text)


## Whether this draw offers BIN IT (set_bin), shown yet or not.
func bin_offered() -> bool:
	return _bin_shown


func bin_button() -> Button:
	return _bin


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The display at time `t` (seconds) of view.plan: a refused key's lines for a moment, else the
## plan's own line at `t`, else the wait point's; BIN IT from the last reveal's end until the
## pick or the bin is made.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var bin_now: bool = _bin_at(t)
	var moved: bool = bin_now != _bin.visible
	_bin.visible = bin_now
	var timed: PackedStringArray = _timed(plan, t)
	var shown: PackedStringArray = timed if not timed.is_empty() else _rest
	if not _denied.is_empty():
		if Time.get_ticks_msec() - _denied_at_ms < DENIED_MS:
			shown = _denied
		else:
			_denied = PackedStringArray()
	if moved or shown[0] != _message.text or shown[1] != _sub.text:
		_show(shown[0], shown[1])


## Whether BIN IT shows at `t`: offered, the draw's last reveal over, the pick not yet made (no
## plan: whenever offered).
func _bin_at(t: float) -> bool:
	if not _bin_shown:
		return false
	var plan: MachinePlan = view.plan if view != null else null
	if plan == null:
		return true
	if not plan.has_draw or plan.n_prizes <= 0:
		return false
	var last: int = plan.n_prizes - 1
	if t < plan.reveal_at[last] + plan.reveal_length[last]:
		return false
	return not (plan.has_landing and t >= plan.press)


## The plan's own line at `t`, or none (empty: the wait point's).
func _timed(plan: MachinePlan, t: float) -> PackedStringArray:
	if plan == null:
		return PackedStringArray()
	if plan.has_landing and t >= plan.press:
		return _landing_text(plan, t)
	if plan.has_draw and t >= plan.choose_at:
		return _draw_text(plan, t) if t < plan.pick_at else PackedStringArray()
	return _intro_text(plan, t) if t < plan.choose_at else PackedStringArray()


## The intro: READING…, then the receipt read (a BONUS visit: BONUS TICKET! until its stub is
## fed); none after it.
func _intro_text(plan: MachinePlan, t: float) -> PackedStringArray:
	if plan.kind == MachineVisit.Kind.BONUS:
		if t < plan.feed_end:
			return PackedStringArray([BONUS_TICKET, "%s · feeding in" % why_words()])
		return PackedStringArray()
	if t < plan.feed_end:
		return PackedStringArray([READING, ""])
	if plan.premium and t >= plan.premium_at and t < plan.premium_end:
		var on: bool = int(floorf((t - plan.premium_at) * PREMIUM_BLINK)) % 2 == 1
		if plan.reduced_motion:
			on = true
		return PackedStringArray(PREMIUM_LINES if on else ["", ""])
	return _read_text() if t < plan.read_end else PackedStringArray()


## The receipt read: the spend thanked, the quota met and the inspection passed; a BOOSTED visit
## says BOOSTED VISIT in the inspection's place, so the line fits (the BONUS visit that follows
## names the inspection).
func _read_text() -> PackedStringArray:
	var record: ShiftRecord = _record()
	if record == null:
		return PackedStringArray()
	var met: String = "quota €%d met" % record.quota
	if view.run.machine.is_boosted():
		met += BOOSTED_READ
	elif record.inspection != null:
		met += " · %s passed" % record.inspection.display_name
	return PackedStringArray([RewardMachineView.SPEND_LINE % record.total, met])


## The draw: packing, the prizes out, each reveal's rarity and prize; STAMP DAY's free stamp.
func _draw_text(plan: MachinePlan, t: float) -> PackedStringArray:
	if plan.kind == MachineVisit.Kind.STAMP_DAY:
		var record: ShiftRecord = _record()
		var shift: int = record.shift if record != null else 0
		return PackedStringArray(
			["STAMP DAY! A FREE STAMP", "your card is behind after shift %d" % shift]
		)
	if plan.n_prizes == 0 or t < plan.reveal_at[0]:
		var bonus: bool = plan.kind == MachineVisit.Kind.BONUS
		var count: String = "1 PRIZE" if plan.n_prizes == 1 else "%d PRIZES" % plan.n_prizes
		var from: String = "%s from %s" % [count.to_lower(), _chute_name().to_lower()]
		return PackedStringArray([PACKING, "bonus ticket" if bonus else from])
	var last: int = plan.n_prizes - 1
	if t >= plan.reveal_at[last] + plan.reveal_length[last]:
		return PackedStringArray()
	var index: int = last
	while index > 0 and t < plan.reveal_at[index]:
		index -= 1
	return PackedStringArray([RARITY_WORDS[plan.rarities[index]], _prize_name(index)])


## The landing: ENJOY! while the prize flies, UPGRADING… while it glints, then the landing's word
## and what it did (a bin: BINNED); the shift's last visit ends on SEE YOU NEXT SHIFT.
func _landing_text(plan: MachinePlan, t: float) -> PackedStringArray:
	if plan.kind == MachineVisit.Kind.STAMP_DAY:
		return PackedStringArray(["ENJOY!", ""] if t < plan.land else [_rest[0], _toast()])
	var split: float = plan.punch_end + (plan.end_at - plan.punch_end) / 2.0
	if plan.next_visit == MachinePlan.NO_VISIT and t >= split:
		return PackedStringArray([SEE_YOU, _end_sub(plan)])
	if plan.landing == MachinePlan.Landing.BIN:
		return PackedStringArray(["BINNED ✕", "no prize this time"])
	if t < plan.land:
		return PackedStringArray(["ENJOY!", ""])
	if plan.landing == MachinePlan.Landing.UPGRADE and t < plan.glint_end:
		return PackedStringArray(["UPGRADING…", ""])
	return PackedStringArray([_rest[0], _toast()])


## What the pick did: the cart count, a copy swapped out, the register stamped.
func _toast() -> String:
	var landing: MachineLanding = view.landing if view != null else null
	if landing == null or view.run == null:
		return ""
	var limit: int = view.run.balance.deck_limit
	match landing.prize.kind:
		MachinePrize.Kind.UPGRADE:
			return "cart stays %d/%d" % [landing.cart_after, limit]
		MachinePrize.Kind.REGISTER:
			var stamped: UpgradeDefinition = landing.register
			return "%s on your card" % stamped.display_name if stamped != null else ""
	if landing.replaced != null:
		return "1 swapped out · cart %d/%d" % [landing.cart_after, limit]
	return "cart %d/%d" % [landing.cart_after, limit]


func _end_sub(plan: MachinePlan) -> String:
	if plan.kind != MachineVisit.Kind.BONUS:
		return ""
	return "2 prizes this shift · %s" % _why()


## Why a bonus ticket was given, as the BONUS visit's lines say it (#77 machine v2): "inspection
## passed", or "shift n" for a bonus extra shift.
func why_words() -> String:
	var record: ShiftRecord = _record()
	if record == null or record.inspection != null:
		return "inspection passed"
	return "shift %d" % record.shift


## Why a bonus ticket was given: "<inspection> passed", or "shift n" for a bonus extra shift.
func _why() -> String:
	var record: ShiftRecord = _record()
	if record == null:
		return ""
	if record.inspection != null:
		return "%s passed" % record.inspection.display_name
	return "shift %d" % record.shift


func _record() -> ShiftRecord:
	if view == null or view.run == null or view.run.history.is_empty():
		return null
	return view.run.history[-1]


func _chute_name() -> String:
	var visit: MachineVisit = view.run.machine.current_visit() if view.run != null else null
	if visit == null or visit.chute < 0:
		return "THE MACHINE"
	return ChuteKey.NAMES[visit.chute]


func _prize_name(index: int) -> String:
	if index >= view.tickets.size():
		return ""
	var prize: MachinePrize = view.tickets[index].prize
	if prize.kind == MachinePrize.Kind.REGISTER:
		return prize.upgrade.display_name if prize.upgrade != null else ""
	return prize.card.display_name if prize.card != null else ""


## Shows the two lines: the message in Pixelify 24 if it fits the room left of BIN IT (else bold
## Atkinson 17), both centred in that room; a lone message centred in the display. BONUS TICKET
## gets the ticket icon before it.
func _show(message: String, sub: String) -> void:
	_message.text = message
	_sub.text = sub
	var left: float = PAD
	var room: float = SIZE.x - 2.0 * PAD
	if _bin.visible:
		room = BIN_RECT.position.x - BIN_GAP - PAD
	var font: Font = marked_font(0)
	var width: float = font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, MESSAGE_SIZE).x
	_icon.visible = message == BONUS_TICKET
	if _icon.visible:
		# The icon and the line centred together.
		var pair: float = _icon.size.x + ICON_GAP + width
		var start: float = roundf((SIZE.x - pair) / 2.0)
		_icon.position = Vector2(start, MESSAGE_TOP + roundf((MESSAGE_HEIGHT - _icon.size.y) / 2.0))
		left = start + _icon.size.x + ICON_GAP
		room = width
	var fits: bool = width <= room
	_message.add_theme_font_override("font", font if fits else marked_font(BOLD_WEIGHT))
	_message.add_theme_font_size_override(
		"font_size", MESSAGE_SIZE if fits else _step(message, BOLD_WEIGHT, FALLBACK_STEPS, room)
	)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub_room: float = room if not _icon.visible else SIZE.x - 2.0 * PAD
	var sub_size: int = _step(sub, BOLD_WEIGHT, SUB_STEPS, sub_room)
	_sub.add_theme_font_size_override("font_size", sub_size)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var top: float = MESSAGE_TOP if not sub.is_empty() else (SIZE.y - MESSAGE_HEIGHT) / 2.0
	_message.position = Vector2(left, top)
	_message.size = Vector2(room, MESSAGE_HEIGHT)
	var sub_left: float = left if not _icon.visible else PAD
	_sub.position = Vector2(sub_left, SUB_TOP)
	_sub.size = Vector2(sub_room, SUB_HEIGHT)
	_sub.visible = not sub.is_empty()


## The first of `steps` (font sizes, largest first) at which `text` in the marked font of
## `weight` fits `room`, else the last.
func _step(text: String, weight: int, steps: Array[int], room: float) -> int:
	var font: Font = marked_font(weight)
	for font_size: int in steps:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room:
			return font_size
	return steps[-1]


func _style_bin() -> void:
	var looks: Dictionary[String, Color] = {
		"normal": Palette.STEEL_LIGHT,
		"hover": Palette.STEEL_HIGHLIGHT,
		"pressed": Palette.STEEL_PALE,
		"disabled": Palette.STEEL_PALE,
	}
	for state: String in looks:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = looks[state]
		style.border_color = Palette.INK
		style.set_border_width_all(2)
		_bin.add_theme_stylebox_override(state, style)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_bin.add_theme_color_override(colour, Palette.INK)
	_bin.add_theme_color_override("font_disabled_color", Palette.GREY_DARK)
