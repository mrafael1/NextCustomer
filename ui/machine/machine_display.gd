class_name MachineDisplay
extends Control
## The machine's LED display (#77, look F; build spec 4.2-4.3; the relook in v0.98, mock-up
## docs/art/mockups/machine_relook.html V2): a charcoal glass with scanlines in a steel bezel,
## left of the receipt slot, 340 px wide. Its message is hard pixel lettering at 2x in gold
## (MachineLine, chunky since v0.99: its words in the chunky capitals, PixelWords.Sheet.
## CHUNKY_CAPS, its amounts in the chunky price-gun digits, PixelWords.Sheet.CHUNKY, its marks
## ✓ ✕ drawn as pixels), with its sub line in bold Atkinson 12 (teal pale) under it; a message
## too wide for the glass wraps onto a second line instead of shrinking (the sub line then gives
## way). The SKIP bin bins a draw (2026-10-29, SkipBin).
## Atkinson has no ✓ or ✕: the sub line's font falls back to JetBrains Mono (ArtStyle.MONO_FONT)
## for them, the same on desktop and on the web build (marked_font).
##
## RewardMachineView gives the message for each wait point (show_message: PICK A CHUTE, the pick
## prompt, the landing's word); frame(t) plays the visit's own lines around them from the plan:
## READING…, then SPEND N€ ✓ THANK YOU! with the quota met (a later draw of the same receipt,
## 2026-11-06: AGAIN! blinking, with its reason and "draw 2 of 3"), on a PREMIUM visit PREMIUM /
## PREMIUM RECEIPT blinking while the machine turns
## PREMIUM, PACKING… while the tray packs, each landed ticket's rarity and prize (a level-up's
## "Coupon engine LV 2"), and on the landing ENJOY!, UPGRADING…, the landing's word with the cart
## count and SEE YOU NEXT SHIFT. A PREMIUM visit's receipt read says so (PREMIUM_READ).
##
## A pressed key no longer changes the display (v0.53: the tray's push bar confirms, MachineTray).
## No ticket feeds since 2026-11-06: the receipt pays every draw (the reader plate's lamps).

const SIZE := Vector2(340, 60)
## The glass inside the bezel, and the room the message's lines have in it.
const GLASS_RECT := Rect2(6, 6, 328, 48)
const PAD := 8.0
## The message's capitals (one line, or two when wrapped) and the sub line's box.
const LINE_TOP := 14.0
const LONE_TOP := 22.0
const WRAP_TOPS: Array[float] = [10.0, 30.0]
const SUB_TOP := 32.0
const SUB_HEIGHT := 18.0
const SUB_SIZE := 12
## The sub line's smaller sizes when 12 doesn't fit.
const SUB_STEPS: Array[int] = [12, 11, 10]
const SCANLINE_ALPHA := 0.35
## A BONUS line's ticket icon (2x) left of BONUS TICKET (a legacy line; no ticket feeds since
## 2026-11-06).
const BONUS_TICKET := "BONUS TICKET"
const TICKET_ICON := preload("res://art/icons/bonus_ticket.png")
const ICON_SCALE := 2.0
const ICON_GAP := 6.0
const BOLD_WEIGHT := 700
const RARITY_WORDS: Array[String] = ["COMMON", "RARE!", "LEGENDARY!!"]
const READING := "READING…"
const PACKING := "PACKING…"
## AGAIN! blinks this often (on, then off) while a later draw opens.
const AGAIN_BLINK := 2.5
## A PREMIUM visit's transform (v0.50): the lines blink this often.
const PREMIUM_LINES: Array[String] = ["PREMIUM", "PREMIUM RECEIPT"]
const PREMIUM_BLINK := 6.0
const SEE_YOU := "SEE YOU NEXT SHIFT"
## A PREMIUM visit's receipt read sub line, after the quota (v0.47).
const PREMIUM_READ := " · PREMIUM RECEIPT"
## A refused key's message (show_denied) shows this long, then the wait point's comes back.
const DENIED_MS := 1200

## The display's fonts with the mark fallback, by weight (0: Pixelify).
static var _marked: Dictionary[int, FontVariation] = {}

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
## The message's lines (one, or two when it wraps) and the sub line.
var _lines: Array[MachineLine] = []
var _message: String = ""
var _sub: Label
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
	for index: int in range(2):
		var line: MachineLine = MachineLine.new()
		line.name = "Message%d" % index
		line.chunky = true
		add_child(line)
		_lines.append(line)
	_sub = UiKit.body_label("", SUB_SIZE, Palette.TEAL_PALE)
	_sub.name = "Sub"
	_sub.add_theme_font_override("font", marked_font(BOLD_WEIGHT))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub.clip_text = true
	add_child(_sub)
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
	return PackedStringArray([_message, _sub.text])


## The wait point's message and sub line (show_message).
func rest_texts() -> PackedStringArray:
	return _rest.duplicate()


## Whether the message wrapped onto a second line (too wide for the glass).
func message_wrapped() -> bool:
	return _lines[1].visible


## The message's hard pixel lines (the second one shows when it wraps), for layout tests.
func message_lines() -> Array[MachineLine]:
	return _lines


## The ticket icon left of a BONUS TICKET line, for tests.
func ticket_icon() -> TextureRect:
	return _icon


## The display's body text (its sub line), for layout tests.
func labels() -> Array[Label]:
	return [_sub]


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The display at time `t` (seconds) of view.plan: a refused key's lines for a moment, else the
## plan's own line at `t`, else the wait point's.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var timed: PackedStringArray = _timed(plan, t)
	var shown: PackedStringArray = timed if not timed.is_empty() else _rest
	if not _denied.is_empty():
		if Time.get_ticks_msec() - _denied_at_ms < DENIED_MS:
			shown = _denied
		else:
			_denied = PackedStringArray()
	if shown[0] != _message or shown[1] != _sub.text:
		_show(shown[0], shown[1])


## The plan's own line at `t`, or none (empty: the wait point's).
func _timed(plan: MachinePlan, t: float) -> PackedStringArray:
	if plan == null:
		return PackedStringArray()
	if plan.has_landing and t >= plan.press:
		return _landing_text(plan, t)
	if plan.has_draw and t >= plan.choose_at:
		return _draw_text(plan, t) if t < plan.pick_at else PackedStringArray()
	return _intro_text(plan, t) if t < plan.choose_at else PackedStringArray()


## The intro: READING…, then the receipt read (a later draw: AGAIN! blinking with its reason and
## its number, until the keys relight); none after it.
func _intro_text(plan: MachinePlan, t: float) -> PackedStringArray:
	if plan.is_again():
		if t < plan.read_end:
			var on: bool = plan.reduced_motion or fmod(t * AGAIN_BLINK, 1.0) < 0.6
			return PackedStringArray([OvertimeWords.AGAIN if on else "", again_sub(plan)])
		if plan.premium and t >= plan.premium_at and t < plan.premium_end:
			return PackedStringArray(PREMIUM_LINES)
		return PackedStringArray()
	if t < plan.feed_end:
		return PackedStringArray([READING, ""])
	if plan.premium and t >= plan.premium_at and t < plan.premium_end:
		var on: bool = int(floorf((t - plan.premium_at) * PREMIUM_BLINK)) % 2 == 1
		if plan.reduced_motion:
			on = true
		return PackedStringArray(PREMIUM_LINES if on else ["", ""])
	return _read_text() if t < plan.read_end else PackedStringArray()


## The receipt read: the spend thanked, the quota met and the inspections passed; a PREMIUM visit
## says PREMIUM RECEIPT in their place, so the line fits (a payday's: REVIEW PASSED, v0.68).
func _read_text() -> PackedStringArray:
	var record: ShiftRecord = _record()
	if record == null:
		return PackedStringArray()
	var met: String = "quota %d€ met" % record.quota
	if _payday():
		met += Payday.READ
	elif OvertimeTickets.is_premium_visit(view.run):
		met += OvertimeWords.GOLD_READ
	elif view.run.machine.is_premium():
		met += PREMIUM_READ
	elif record.inspection != null:
		var passed: Array[InspectionDefinition] = InspectionDefinition.maluses(record.inspections)
		met += " · %s passed" % ", ".join(InspectionTag.names(passed))
	return PackedStringArray([RewardMachineView.SPEND_LINE % record.total, met])


## The draw: packing, the prizes out, each reveal's rarity and prize.
func _draw_text(plan: MachinePlan, t: float) -> PackedStringArray:
	if plan.n_prizes == 0 or t < plan.reveal_at[0]:
		var bonus: bool = plan.kind == MachineVisit.Kind.BONUS
		var count: String = "1 PRIZE" if plan.n_prizes == 1 else "%d PRIZES" % plan.n_prizes
		var from: String = "%s from %s" % [count.to_lower(), _chute_name().to_lower()]
		if bonus:
			from = "%s · draw %d of %d" % [why_words(), plan.draw_index + 1, plan.draws]
		return PackedStringArray([PACKING, from])
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


## What the pick did: the cart count, a copy swapped out, the perk stamped or levelled up.
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
			if stamped == null:
				return ""
			return "%s on your card" % LoyaltyCard.perk_name(stamped)
	if landing.replaced != null:
		return "1 swapped out · cart %d/%d" % [landing.cart_after, limit]
	return "cart %d/%d" % [landing.cart_after, limit]


func _end_sub(plan: MachinePlan) -> String:
	if plan.draws <= 1:
		return ""
	if _payday() and not _overtime():
		return Payday.END_SUB % plan.draws
	return "%d prizes this shift · %s" % [plan.draws, _why()]


## A later draw's sub line: its reason and its number ("silver medal · draw 2 of 2").
func again_sub(plan: MachinePlan) -> String:
	return OvertimeWords.AGAIN_SUB % [why_words(), plan.draw_index + 1, plan.draws]


## Why a later draw was given, as its lines say it: the SILVER medal's (2026-11-06), a payday's
## "review passed", "inspection passed", or "shift n" for a bonus extra shift.
func why_words() -> String:
	if _overtime():
		return OvertimeWords.SILVER_REASON
	if _payday():
		return Payday.REASON
	var record: ShiftRecord = _record()
	if record == null or record.inspection != null:
		return "inspection passed"
	return "shift %d" % record.shift


## Why a bonus ticket was given: "<inspections> passed" (every one of them, a Manager's review's
## two), or "shift n" for a bonus extra shift.
func _why() -> String:
	if _overtime():
		return why_words()
	var record: ShiftRecord = _record()
	if record == null:
		return ""
	if record.inspection != null:
		var passed: Array[InspectionDefinition] = InspectionDefinition.maluses(record.inspections)
		return "%s passed" % ", ".join(InspectionTag.names(passed))
	return "shift %d" % record.shift


## Whether the visit on show is a payday's (v0.68, RewardMachine.is_payday). After its pick the
## visit is in the record (the machine's current one is gone): its plan's PREMIUM flag says it,
## so the landing's end line still words the payday.
func _payday() -> bool:
	if view == null or view.run == null:
		return false
	var machine: RewardMachine = view.run.machine
	if machine.current_visit() != null or view.plan == null:
		return machine.is_payday(view.run)
	var record: ShiftRecord = _record()
	return record != null and view.plan.premium and machine.machine.is_payday_shift(record.shift)


## Whether the visit on show is an OVERTIME one (v1.03): its plan says it (after its pick too).
func _overtime() -> bool:
	return (
		view != null
		and view.run != null
		and view.plan != null
		and view.plan.overtime
		and view.plan.kind == MachineVisit.Kind.BONUS
	)


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
		return LoyaltyCard.perk_name(prize.upgrade) if prize.upgrade != null else ""
	return prize.card.display_name if prize.card != null else ""


## Shows the two lines: the message in hard pixel lettering, centred on the glass (on its own
## line, or wrapped onto two), the sub line under it; a lone message centred in the display.
## BONUS TICKET gets the ticket icon before it.
func _show(message: String, sub: String) -> void:
	_message = message
	_sub.text = sub
	var room: float = GLASS_RECT.size.x - 2.0 * PAD
	_icon.visible = message in [BONUS_TICKET, Payday.TICKET_TITLE]
	var icon_room: float = _icon.size.x + ICON_GAP if _icon.visible else 0.0
	var parts: PackedStringArray = wrap_message(message, room - icon_room)
	var wrapped: bool = parts.size() > 1
	_sub.visible = not sub.is_empty() and not wrapped
	var tops: Array[float] = WRAP_TOPS.duplicate()
	if not wrapped:
		tops = [LINE_TOP if _sub.visible else LONE_TOP]
	for index: int in range(_lines.size()):
		var line: MachineLine = _lines[index]
		line.visible = index < parts.size()
		if not line.visible:
			continue
		line.show_text(parts[index], Palette.GOLD, Palette.GOLD)
		line.centre_in(Rect2(icon_room, tops[index], SIZE.x - icon_room, line.size.y))
	if _icon.visible:
		# The icon and the line centred together.
		var pair: float = _icon.size.x + ICON_GAP + _lines[0].width()
		var start: float = MachineArt.snap((SIZE.x - pair) / 2.0)
		var cap_middle: float = _lines[0].position.y + _lines[0].size.y / 2.0
		_icon.position = Vector2(start, MachineArt.snap(cap_middle - _icon.size.y / 2.0))
		_lines[0].position.x = start + _icon.size.x + ICON_GAP
	_sub.add_theme_font_size_override("font_size", _step(sub, BOLD_WEIGHT, SUB_STEPS, room))
	_sub.position = Vector2(GLASS_RECT.position.x + PAD, SUB_TOP)
	_sub.size = Vector2(room, SUB_HEIGHT)


## `message` as it fits `room` px of glass: one line, or split at the space nearest its middle
## into two when it is too wide (a single long word stays one line).
static func wrap_message(message: String, room: float) -> PackedStringArray:
	if message.is_empty() or MachineLine.width_of(message, 1, true) <= room:
		return PackedStringArray([message])
	var words: PackedStringArray = message.split(" ")
	var best: PackedStringArray = PackedStringArray([message])
	var widest: float = INF
	for cut: int in range(1, words.size()):
		var first: String = " ".join(words.slice(0, cut))
		var second: String = " ".join(words.slice(cut))
		var wide: float = maxf(
			MachineLine.width_of(first, 1, true), MachineLine.width_of(second, 1, true)
		)
		if wide < widest:
			widest = wide
			best = PackedStringArray([first, second])
	return best


## The first of `steps` (font sizes, largest first) at which `text` in the marked font of
## `weight` fits `room`, else the last.
func _step(text: String, weight: int, steps: Array[int], room: float) -> int:
	var font: Font = marked_font(weight)
	for font_size: int in steps:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room:
			return font_size
	return steps[-1]


## The steel bezel and the charcoal glass with its scanlines.
func _draw() -> void:
	var p: float = MachineArt.PIXEL
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	draw_rect(rect, Palette.INK)
	draw_rect(rect.grow(-p), Palette.STEEL_DARK)
	draw_rect(Rect2(p, p, SIZE.x - 2.0 * p, p), Palette.STEEL_SHADE)
	draw_rect(rect.grow(-2.0 * p), Palette.INK)
	draw_rect(GLASS_RECT, Palette.CHARCOAL)
	var y: float = GLASS_RECT.position.y + p
	while y < GLASS_RECT.end.y:
		draw_rect(
			Rect2(GLASS_RECT.position.x, y, GLASS_RECT.size.x, p / 2.0),
			Color(Palette.INK, SCANLINE_ALPHA)
		)
		y += 2.0 * p
