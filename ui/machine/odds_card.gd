class_name OddsCard
extends Control
## A chute's odds card (#77 machine v2, the approved page's hover card): it shows only while the
## pointer rests on a lit key at the chute wait (and on the REGISTER key during a STAMP DAY pick,
## read-only), above that key, its tail pointing down at it, centred on the key and kept inside
## the machine. Exactly three rows, nothing else: COMMON (grey light, ink), RARE! (teal, paper),
## LEGENDARY!! (gold, ink), each with its share per drop as a whole percent (Pixelify 12 name,
## Pixelify 24 percent, a 2 px ink border); a row whose share is exactly 0 stays, faded. Paper
## with a 3 px ink border over a 5 px charcoal shadow. A machine child, so it zooms with the
## machine (1:1 on screen at the camera's 2x), drawn over every other part and the docked bonus
## ticket (Z). Every number is MachineChuteInfo.odds.rarity_share (RewardMachine, MachineOdds);
## the card only rounds it (whole_pct). It pops in (from POP_FROM over MachineTuning.odds_open_ms,
## on view.idle_time; reduced motion: at once).

const WIDTH := 172.0
const BORDER := 3.0
const PAD := 5.0
const ROW_HEIGHT := 30.0
const ROW_GAP := 3.0
const ROW_BORDER := 2
const ROW_PAD := 7.0
const NAME_SIZE := 12
const PERCENT_SIZE := 24
const SHADOW := 5.0
## The tail: TAIL_LENGTH long, 2 x TAIL_HALF wide at the card, its tip KEY_GAP above the key.
const TAIL_LENGTH := 10.0
const TAIL_HALF := 8.0
const KEY_GAP := 2.0
## The card keeps this far inside the machine's sides.
const MARGIN := 4.0
## A row whose share is exactly 0 shows at this opacity.
const ZERO_ALPHA := 0.45
## The pop: from POP_FROM of its size, over MachineTuning.odds_open_ms.
const POP_FROM := 0.85
## Drawn over the machine's other parts and the overlay's docked ticket.
const Z := 100
const RARITY_WORDS: Array[String] = ["COMMON", "RARE!", "LEGENDARY!!"]
const ROW_COLOURS: Array[Color] = [Palette.GREY_LIGHT, Palette.TEAL, Palette.GOLD]
const TEXT_COLOURS: Array[Color] = [Palette.INK, Palette.PAPER, Palette.INK]
## The pick's sub line when the cart is full (RewardMachineView).
const CART_FULL_TEXT := "CART FULL: SWAP 1 OUT"

var chute: int = 0
## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _rows: Array[Panel] = []
var _names: Array[Label] = []
var _percents: Array[Label] = []
var _tail_x: float = WIDTH / 2.0
var _opened_at: float = 0.0
## The next visit's per-drop shares as last seen per chute ("40% / 45% / 15%"), for the display's
## REGULAR line after the pick.
var _next_shares: Dictionary[int, String] = {}


func _init() -> void:
	name = "OddsCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = Z
	size = Vector2(WIDTH, height())
	for rarity: int in range(RARITY_WORDS.size()):
		var row: Panel = Panel.new()
		row.name = "Row%d" % rarity
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = ROW_COLOURS[rarity]
		style.border_color = Palette.INK
		style.set_border_width_all(ROW_BORDER)
		row.add_theme_stylebox_override("panel", style)
		row.position = Vector2(BORDER + PAD, BORDER + PAD + rarity * (ROW_HEIGHT + ROW_GAP))
		row.size = Vector2(WIDTH - 2.0 * (BORDER + PAD), ROW_HEIGHT)
		add_child(row)
		_rows.append(row)
		var name_label: Label = _row_label(RARITY_WORDS[rarity], NAME_SIZE, rarity)
		name_label.name = "Name"
		row.add_child(name_label)
		_names.append(name_label)
		var percent: Label = _row_label("", PERCENT_SIZE, rarity)
		percent.name = "Percent"
		percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(percent)
		_percents.append(percent)
		var inner: Rect2 = Rect2(ROW_PAD, 0, row.size.x - 2.0 * ROW_PAD, ROW_HEIGHT)
		RewardMachineView.fit(name_label, inner)
		RewardMachineView.fit(percent, inner)
	visible = false


## The card's height: its border, padding and three rows.
static func height() -> float:
	return 2.0 * (BORDER + PAD) + 3.0 * ROW_HEIGHT + 2.0 * ROW_GAP


## A share as a whole percent ("33%"); a share above 0 that would round to 0 reads "<1%".
static func whole_pct(share: float) -> String:
	var whole: int = roundi(share * 100.0)
	if share > 0.0 and whole == 0:
		return "<1%"
	return "%d%%" % whole


## The card's top-left in its parent for a key at `key_rect` (same parent): centred over the key,
## inside [MARGIN, parent_width - MARGIN], its tail's tip KEY_GAP above the key's top.
static func place_for(key_rect: Rect2, parent_width: float) -> Vector2:
	var x: float = key_rect.get_center().x - WIDTH / 2.0
	x = clampf(x, MARGIN, parent_width - MARGIN - WIDTH)
	var y: float = key_rect.position.y - KEY_GAP - TAIL_LENGTH - height()
	return Vector2(roundf(x), roundf(y))


## Shows `info`'s three rows for `card_chute`, above the key at `key_rect` (in the card's parent).
func show_card(card_chute: int, info: MachineChuteInfo, key_rect: Rect2) -> void:
	chute = card_chute
	var shares: PackedFloat64Array = info.odds.rarity_share
	for rarity: int in range(RARITY_WORDS.size()):
		var share: float = shares[rarity] if rarity < shares.size() else 0.0
		_percents[rarity].text = whole_pct(share)
		_rows[rarity].modulate.a = ZERO_ALPHA if share == 0.0 else 1.0
	remember(card_chute, info)
	var parent_width: float = RewardMachineView.SIZE.x
	position = place_for(key_rect, parent_width)
	_tail_x = clampf(
		key_rect.get_center().x - position.x, BORDER + TAIL_HALF, WIDTH - BORDER - TAIL_HALF
	)
	pivot_offset = tail_tip()
	visible = true
	_opened_at = view.idle_time if view != null else 0.0
	_pop(1.0 if _instant() else 0.0)
	queue_redraw()


## Keeps `info`'s next-visit shares for `card_chute` (the display's line after the pick).
func remember(card_chute: int, info: MachineChuteInfo) -> void:
	if info.odds.meter_rises:
		_next_shares[card_chute] = _shares_text(info.odds.next_rarity_share)


## The next visit's per-drop shares last seen for `card_chute` ("40% / 45% / 15%"), or "".
func next_share_text(card_chute: int) -> String:
	return _next_shares.get(card_chute, "")


## The rows' texts, top to bottom: [name, percent] each, for tests.
func row_texts() -> Array[PackedStringArray]:
	var found: Array[PackedStringArray] = []
	for rarity: int in range(_rows.size()):
		found.append(PackedStringArray([_names[rarity].text, _percents[rarity].text]))
	return found


## Row `rarity`'s colour (its plate) and opacity, for tests.
func row_colour(rarity: int) -> Color:
	var style: StyleBoxFlat = _rows[rarity].get_theme_stylebox("panel") as StyleBoxFlat
	return style.bg_color


func row_alpha(rarity: int) -> float:
	return _rows[rarity].modulate.a


func rows() -> Array[Panel]:
	return _rows.duplicate()


## Every label on the card, for layout tests.
func shown_labels() -> Array[Label]:
	var found: Array[Label] = []
	found.append_array(_names)
	found.append_array(_percents)
	return found


## The tail's tip (local), pointing down at the key.
func tail_tip() -> Vector2:
	return Vector2(_tail_x, height() + TAIL_LENGTH)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The card's pop at the machine's free-running time (it holds at a wait point): from POP_FROM to
## its size over odds_open_ms after it opened, at once under reduced motion.
func frame(_t: float) -> void:
	if not visible:
		return
	if _instant():
		_pop(1.0)
		return
	var length: float = MachineTuning.sec(view.tuning.odds_open_ms)
	var p: float = 1.0 if length <= 0.0 else (view.idle_time - _opened_at) / length
	_pop(clampf(p, 0.0, 1.0))


func _instant() -> bool:
	return view == null or view.plan == null or view.plan.reduced_motion


func _pop(p: float) -> void:
	var eased: float = 1.0 - (1.0 - p) * (1.0 - p)
	scale = Vector2.ONE * lerpf(POP_FROM, 1.0, eased)
	modulate.a = eased


static func _shares_text(shares: PackedFloat64Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for share: float in shares:
		parts.append(whole_pct(share))
	return " / ".join(parts)


static func _row_label(text: String, font_size: int, rarity: int) -> Label:
	var label: Label = UiKit.display_label(text, font_size, false)
	label.add_theme_color_override("font_color", TEXT_COLOURS[rarity])
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The card: its shadow, the paper with a 3 px ink border, and the tail pointing down.
func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(Vector2(0, SHADOW), size), Palette.CHARCOAL)
	draw_rect(rect, Palette.PAPER)
	draw_rect(rect.grow(-BORDER / 2.0), Palette.INK, false, BORDER)
	var top: float = size.y - 1.0
	var outer: PackedVector2Array = PackedVector2Array(
		[
			Vector2(_tail_x - TAIL_HALF, top),
			Vector2(_tail_x, size.y + TAIL_LENGTH),
			Vector2(_tail_x + TAIL_HALF, top),
		]
	)
	draw_colored_polygon(outer, Palette.INK)
