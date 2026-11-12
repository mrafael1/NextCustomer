class_name ToyLineupJoin
extends Control
## A new figurine joins the collection (v1.05, mock-up toy_shelf_unlock.html, the user's pick:
## option B, the lineup card): once the reveal's hold is over (ToyReveal.HOLD_S), on the TOY
## MACHINES stage, the drawn machine's lineup card (ToyLineup) drops in where the board hangs (or
## the hovered one, already up behind the reveal's shade, stays), the icon flies from the
## reveal's place into its place on the card on an arc as pixel art (2026-11-11: the 2x sprite,
## then its mini, on the 2 px grid, moving every frame and landing in FLY_S), its grey shape
## flips into colour with a sparkle, then the counts tick: the FIGURINES LED and the machine's
## floor plate (both lifted over the shade) hop, the window gives up one capsule. A NEW! burst
## sits under the mini for a look (a tap ends it) and the card goes back up.
##
## When the capsule completes its aisle (StartSetupRules.completed): the band turns gold with ALL
## COLLECTED, the stage shakes and the minis hop one after the other; the COMPLETED! card
## (ToyCompletedCard) pops in, its COMPLETED stamp slams onto the aisle's band (v1.30), and
## waits for OK; then the card and the lineup leave, the machine's SOLD OUT card drops in and
## swings, its plate flips to SOLD OUT and its lamp flickers off; at the whole collection the
## COLLECTION COMPLETE strip opens from its centre.
##
## The screen holds what the draw changed (ToyMachinesScreen: the FIGURINES count, the plate, the
## window and the machine's SOLD OUT state; only COINS changes at the draw) until this tells it
## the beat: `beat` (&"tick", &"sold", &"collection"), then `finished`. Nothing here saves: the
## draw is saved before it plays. A timeline of beats in seconds (the mock-up's), driven by
## _process: a click, Enter or Space plays the moving beats BOOST times faster to the next resting
## point (the look, which it ends, or the card, which needs OK), never skipping past the card;
## the end state is always the same. Reduced motion (the profile's): no flight, shake, swing or
## pops; the card fades in with the figurine already in colour, the counts change in place, the
## COMPLETED! card and SOLD OUT fade in. Every size in canvas px of the 1280x720 stage.

## A beat starts: &"to", &"tick", &"look", &"away", &"slap", &"card_in", &"card", &"card_out",
## &"sold" or &"collection".
signal beat(id: StringName)
signal finished

const STAGE := Vector2(1280, 720)
## Beat lengths (seconds), then under reduced motion.
## 2026-11-11 feel pass (the user: the join felt slow, as if frames dropped): the flight lands in
## FLY_S (well under a second), the look and the way out are short, so the machines are usable
## again about JOIN_S after the reveal's hold.
const TO_S := 0.5
const TO_S_REDUCED := 0.25
const TICK_S := 0.2
const LOOK_S := 0.5
const AWAY_S := 0.2
const AWAY_S_REDUCED := 0.2
const SLAP_S := 0.65
const SLAP_S_REDUCED := 0.3
const CARD_IN_S := 0.8
const CARD_IN_S_REDUCED := 0.3
const CARD_OUT_S := 0.25
const SOLD_S := 0.8
const SOLD_S_REDUCED := 0.3
const COLLECTION_S := 0.9
const COLLECTION_S_REDUCED := 0.3
## A tap's speed-up to the next resting point.
const BOOST := 4.0
## The shade over the machines while the lineup card is the stage (the reveal's fades under it).
const SHADE_ALPHA := 0.2
## The card drops from at least this far above its place (and leaves the same way): from far
## enough that none of it, pointer included, shows above the screen's top.
const DROP := 200.0
## The flight (the travel, inside the TO_S beat): its share of the first beat (from 0, so the
## icon leaves the moment the 1 s hold ends; every frame, on the 2 px grid), the arc's peak over
## the straight line (as much as the trip goes sideways) and the eased share from which the 2x
## sprite becomes the mini at 2x, a puff of sparkles hiding the swap for PUFF_SHARE of the
## flight. Its curve (_fly) leaves fast and still lands at speed (review fix: an ease in and out
## stood still on the grid as it lifted off and crawled as it settled), so every frame of it
## moves. FLY_S is the travel's length (TO_S * FLY_TO).
const FLY_FROM := 0.0
const FLY_TO := 0.8
const FLY_S := TO_S * FLY_TO
const ARC := 50.0
const MINI_FROM := 0.7
const MINI_SIZE := Vector2(28, 28)
const PUFF_SHARE := 0.12
const PUFF_SPREAD := 18.0
## The curve's landing speed (its slope at the end; 1 at the start plus what the end loses).
const LAND_SPEED := 0.4
## The whole join of a capsule that completes nothing, in seconds (look included).
const JOIN_S := TO_S + TICK_S + LOOK_S + AWAY_S
## Sparkles (sparkle.png at 2x): a ring of RING round the landed mini for RING_S.
const SPARKLE := preload("res://art/effects/sparkle.png")
const SPARKLE_SIZE := Vector2(10, 10)
const RING := 6
const RING_S := 0.5
const RING_RADIUS := 26.0
## NEW! under the landed mini (the reveal's burst, smaller).
const BURST := preload("res://art/effects/sticker_burst.png")
const BURST_SIZE := Vector2(62, 34)
const BURST_DROP := 36.0
const BURST_ROTATION := -8.0
const NEW_TEXT := "NEW!"
## The tick: the LED and the plate hop TICK_RISE art px.
const TICK_RISE := 2
## The slap: the band turns gold SLAP_GOLD_S in; the minis hop HOP_RISE art px for HOP_S each,
## HOP_GAP_S apart from HOP_FROM_S; the stage shakes SHAKE art px over SHAKE_SHARE of the beat.
const SLAP_GOLD_S := 0.1
const HOP_FROM_S := 0.15
const HOP_GAP_S := 0.05
const HOP_S := 0.24
const HOP_RISE := 2
const SHAKE := 2
const SHAKE_SHARE := 0.3
## The COMPLETED! card: pops over CARD_POP_SHARE of its beat from CARD_POP_FROM, the stage
## dimmed to CARD_SHADE_ALPHA behind it; its stamp slams in from STAMP_FROM of the beat over
## STAMP_SHARE (from STAMP_SIZE times its size to 1, eased in: it speeds up into the band, in
## STAMP_STEPS only, whole canvas px per art px, so its pixels never smear), and the card jolts
## JOLT art px down for JOLT_S at the impact.
const CARD_POP_SHARE := 0.25
const CARD_POP_FROM := 0.7
const STAMP_FROM := 0.4
const STAMP_SHARE := 0.18
const STAMP_SIZE := 2.0
const STAMP_STEPS: Array[float] = [2.0, 1.5, 1.0]
const CARD_SHADE_ALPHA := 0.5
const JOLT := 2
const JOLT_S := 0.08
## SOLD OUT: the card drops SOLD_DROP px in SOLD_DROP_S and swings SWING_DEGREES, settling; the
## plate flips between SOLD_FLIP of the beat; the lamp flickers over its first half.
const SOLD_DROP := 46.0
const SOLD_DROP_S := 0.15
const SWING_DEGREES := 22.0
const SOLD_FLIP := Vector2(0.35, 0.6)
const FLICKER_STEPS := 20.0
## Sounds (all existing ones).
const LAND_SOUND := "card_place"
const TICK_SOUND := "tick"
const SLAP_SOUND := "stamp_paid"
const STAMP_SOUND := "stamp"
const SOLD_SOUND := "stamp_notice"
const COLLECTION_SOUND := "register_bell"

var _lineup: ToyLineup
var _reveal: ToyReveal
var _chip: Control
var _layer: Control
var _board: Control
var _strip: Control
var _card: ToyCompletedCard
var _shade: ColorRect
var _flyer: TextureRect
var _sparkles: Array[TextureRect] = []
var _burst: TextureRect
## This join's pieces and state.
var _machine: ToyMachineView
var _lamp: TextureRect
var _figure: Texture2D
var _mini: Texture2D
var _index: int = 0
var _complete: bool = false
var _reduced: bool = false
var _dropped: bool = true
var _active: bool = false
var _owns_lineup: bool = false
var _segments: Array[Dictionary] = []
var _t: float = 0.0
var _boost: float = 1.0
var _card_closed: bool = false
var _chip_rest: Vector2 = Vector2.ZERO
var _sold_rest: Vector2 = Vector2.ZERO
var _stamped: bool = false
var _card_rest: Vector2 = Vector2.ZERO
var _landed: bool = false


func _init() -> void:
	size = STAGE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_shade = ColorRect.new()
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.size = STAGE
	_shade.z_index = 1
	add_child(_shade)
	_flyer = UiKit.sprite(null)
	_flyer.z_index = 3
	add_child(_flyer)
	for index: int in range(RING):
		var sparkle: TextureRect = UiKit.sprite(SPARKLE)
		sparkle.size = SPARKLE_SIZE
		sparkle.z_index = 3
		add_child(sparkle)
		_sparkles.append(sparkle)
	_burst = UiKit.sprite(BURST)
	_burst.size = BURST_SIZE
	_burst.pivot_offset = BURST_SIZE / 2.0
	_burst.rotation_degrees = BURST_ROTATION
	_burst.z_index = 3
	var new_text: Label = UiKit.body_label(NEW_TEXT, 12, Palette.INK)
	new_text.add_theme_font_override("font", ArtStyle.bold_font(800))
	new_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	new_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_burst.add_child(new_text)
	add_child(_burst)
	_card = ToyCompletedCard.new()
	_card.z_index = 4
	_card.closed.connect(_on_card_closed)
	add_child(_card)


## The screen's pieces the join moves: the lineup card, the reveal, the FIGURINES LED, the
## machines' layer (shaken), the board (hidden under the card) and the LED strip.
func setup(
	lineup: ToyLineup,
	reveal: ToyReveal,
	figurines_chip: Control,
	machines_layer: Control,
	board: Control,
	strip: Control
) -> void:
	_lineup = lineup
	_reveal = reveal
	_chip = figurines_chip
	_layer = machines_layer
	_board = board
	_strip = strip


## At the draw: the join owns the lineup card from now (the screen leaves it be); `kept` when it
## is up for the drawn machine (hovered), staying behind the reveal's shade.
func hold_lineup(kept: bool) -> void:
	_owns_lineup = true
	_dropped = not kept


## Whether the join owns the lineup card (from the draw to the end).
func owns_lineup() -> bool:
	return _owns_lineup


## Plays the join of `card` (mini `index` of `aisle`'s lineup) from `machine` (its lamp `lamp`),
## the lineup showing `before` (the collection before the draw), once the reveal's hold is over.
## With `completed` (the capsule completed its aisle) the COMPLETED! card follows. Options:
## `reduced` (reduced motion) and `collection` (the COLLECTION COMPLETE strip at the end).
func play(
	card: CardDefinition,
	aisle: AisleDefinition,
	machine: ToyMachineView,
	lamp: TextureRect,
	before: Dictionary,
	completed: bool,
	options: Dictionary
) -> void:
	_machine = machine
	_lamp = lamp
	_index = aisle.capsule_cards.find(card)
	_figure = ArtStyle.item_sprite(card)
	_mini = ToyLineup.mini_art(card)
	_complete = completed
	_reduced = bool(options.get("reduced", false))
	_card_closed = false
	_stamped = false
	_landed = false
	_boost = 1.0
	if _dropped or _lineup.shown_aisle() != aisle:
		_dropped = true
		var centre: int = roundi(machine.position.x / ArtStyle.ART_SCALE)
		_lineup.show_aisle(aisle, before, centre + ToyMachinesScreen.MACHINE_CENTRE)
	_lineup.visible = true
	_board.visible = false
	_lineup.z_index = 2
	_chip.z_index = 2
	machine.lift_floor(true)
	if _complete:
		_card.build(aisle, STAGE)
		_card_rest = _card.position
	_build_timeline(bool(options.get("collection", false)))
	_t = 0.0
	_active = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	beat.emit(&"to")
	_apply()


func is_active() -> bool:
	return _active


## The COMPLETED! card (built when the capsule completes its aisle).
func completed_card() -> ToyCompletedCard:
	return _card


## The seconds into the join.
func time() -> float:
	return _t


## The current beat's id (&"" once finished).
func current() -> StringName:
	var segment: Dictionary = _segment_at(_t)
	return StringName(segment.get("id", &"")) if _active else &""


## Whether the join waits for the COMPLETED! card's OK.
func is_waiting() -> bool:
	return _active and _hold_at() >= 0.0 and _t >= _hold_at() and not _card_closed


## The flying figurine (its sprite, then its mini), NEW! and the shade, for tests and captures.
func flyer() -> TextureRect:
	return _flyer


func new_burst() -> TextureRect:
	return _burst


func shade() -> ColorRect:
	return _shade


## Moves the join to `seconds` (beats fire on the way; it stops at the card while it waits for
## OK): the screen capture's stills.
func seek(seconds: float) -> void:
	if _active:
		_advance_to(seconds)


## Plays to the end at once, closing the COMPLETED! card (tests).
func finish() -> void:
	if not _active:
		_owns_lineup = false  # A draw whose reveal closed before its OK: the screen's hover again.
		_dropped = true
		return
	_card_closed = true
	_card.visible = false
	_advance_to(_total())


## A click, Enter or Space: ends the look, closes the armed card, or speeds the moving beats up
## to the next resting point.
func tap() -> void:
	if not _active:
		return
	var segment: Dictionary = _segment_at(_t)
	if is_waiting():
		_card.close()
	elif bool(segment.get("rest", false)):
		_advance_to(float(segment["t1"]))
	else:
		_boost = BOOST


func _process(delta: float) -> void:
	if not _active:
		return
	_advance_to(_t + delta * _boost)


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if _active and press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		tap()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not _active or key == null or not key.pressed or key.echo:
		return
	if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		tap()


func _build_timeline(collection: bool) -> void:
	_segments = []
	var rm: bool = _reduced
	_add(&"to", TO_S_REDUCED if rm else TO_S)
	_add(&"tick", TICK_S)
	if not _complete:
		_add(&"look", LOOK_S, true)
		_add(&"away", AWAY_S_REDUCED if rm else AWAY_S)
		return
	_add(&"slap", SLAP_S_REDUCED if rm else SLAP_S)
	_add(&"card_in", CARD_IN_S_REDUCED if rm else CARD_IN_S)
	_add(&"card", 0.0, false, true)
	_add(&"card_out", CARD_OUT_S)
	_add(&"sold", SOLD_S_REDUCED if rm else SOLD_S)
	if collection:
		_add(&"collection", COLLECTION_S_REDUCED if rm else COLLECTION_S)


func _add(id: StringName, seconds: float, rest: bool = false, hold: bool = false) -> void:
	var t0: float = 0.0 if _segments.is_empty() else float(_segments[-1]["t1"])
	_segments.append({"id": id, "t0": t0, "t1": t0 + seconds, "rest": rest, "hold": hold})


func _total() -> float:
	return float(_segments[-1]["t1"])


## When the clock waits for the card's OK (-1: no card).
func _hold_at() -> float:
	for segment: Dictionary in _segments:
		if segment["hold"]:
			return float(segment["t0"])
	return -1.0


func _segment_at(seconds: float) -> Dictionary:
	for segment: Dictionary in _segments:
		if seconds < float(segment["t1"]):
			return segment
	return _segments[-1] if not _segments.is_empty() else {}


## Moves the clock to `target` (held at the card until it closes), starting each beat it passes
## (a resting or held beat ends the tap's boost), then lays everything out; at the end, finishes.
func _advance_to(target: float) -> void:
	var hold: float = _hold_at()
	if hold >= 0.0 and not _card_closed:
		target = minf(target, hold)
	target = minf(target, _total())
	for segment: Dictionary in _segments:
		var t0: float = float(segment["t0"])
		if t0 > _t and t0 <= target:
			if segment["rest"] or segment["hold"]:
				_boost = 1.0
			_start(segment["id"])
	_t = target
	_apply()
	if _t >= _total():
		_end()


func _start(id: StringName) -> void:
	match id:
		&"tick":
			beat.emit(id)
			_chip_rest = _chip.position
			Sfx.play_at(self, TICK_SOUND)
		&"slap":
			Sfx.play_at(self, SLAP_SOUND)
		&"card_in":
			_card.visible = true  # It pops in by _apply_card.
		&"card":
			_card.open()
		&"sold":
			_card.visible = false
			beat.emit(id)
			var sold: Control = _machine.part("sold_out")
			_sold_rest = sold.position
			sold.pivot_offset = Vector2(sold.size.x / 2.0, 0.0)
			Sfx.play_at(self, SOLD_SOUND)
		&"collection":
			beat.emit(id)
			_strip.pivot_offset = _strip.size / 2.0
			Sfx.play_at(self, COLLECTION_SOUND)
		_:
			beat.emit(id)


func _on_card_closed() -> void:
	_card_closed = true
	_advance_to(_t)


func _end() -> void:
	_active = false
	_owns_lineup = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lineup.z_index = 0
	_lineup.position = _lineup.rest_position()
	_lineup.modulate.a = 1.0
	_lineup.visible = false
	_chip.z_index = 0
	_layer.position = Vector2.ZERO
	_strip.scale = Vector2.ONE
	if _machine != null:
		_machine.lift_floor(false)
		_machine.nudge_floor(0)
		var sold: Control = _machine.part("sold_out")
		sold.rotation = 0.0
		sold.modulate.a = 1.0
		_machine.part("floor").scale = Vector2.ONE
	if _reveal.visible:
		_reveal.leave(1.0)
	finished.emit()


func _p(id: StringName) -> float:
	for segment: Dictionary in _segments:
		if segment["id"] == id:
			var length: float = float(segment["t1"]) - float(segment["t0"])
			if length <= 0.0:
				return 1.0 if _t >= float(segment["t0"]) else 0.0
			return clampf((_t - float(segment["t0"])) / length, 0.0, 1.0)
	return 0.0


func _since(id: StringName) -> float:
	for segment: Dictionary in _segments:
		if segment["id"] == id:
			return _t - float(segment["t0"])
	return -1.0


func _started(id: StringName) -> bool:
	var since: float = _since(id)
	return since >= 0.0 and _has(id)


func _has(id: StringName) -> bool:
	for segment: Dictionary in _segments:
		if segment["id"] == id:
			return true
	return false


## Everything at the clock's time.
func _apply() -> void:
	var to: float = _p(&"to")
	_reveal.leave(1.0 if _reduced else to)
	var leaving: float = _p(&"card_out") if _complete else _p(&"away")
	var dim: float = SHADE_ALPHA * (1.0 if _reduced else to) * (1.0 - leaving)
	if _complete and _card.visible and _started(&"card_in"):
		dim = maxf(dim, CARD_SHADE_ALPHA * clampf(_p(&"card_in") * 4.0, 0.0, 1.0) * (1.0 - leaving))
	if _complete and _started(&"sold"):
		dim = 0.0
	_shade.color = Color(Palette.INK, dim)
	_apply_lineup(to, leaving)
	# Once the card has left (the COMPLETED! card's exit), the board is back on the wall and the
	# lineup card gone for the SOLD OUT and collection beats.
	var gone: bool = _complete and leaving >= 1.0
	_lineup.visible = not gone
	_board.visible = gone
	_apply_flight(to)
	_apply_tick()
	_apply_card()
	_apply_sold()
	if _has(&"collection"):
		var opening: float = 1.0 if _reduced else _ease_out(_p(&"collection"))
		_strip.scale = Vector2(maxf(opening, 0.01) if _started(&"collection") else 1.0, 1.0)


## The card: dropped in (or faded in) and out, the drawn mini flipped into colour, gold and
## hopping at the slap.
func _apply_lineup(to: float, leaving: float) -> void:
	var rest: Vector2 = _lineup.rest_position()
	var pointer: float = (ToyLineup.POINTER_GAP + ToyLineup.POINTER_ROWS) * ArtStyle.ART_SCALE
	var drop: float = maxf(DROP, rest.y + _lineup.size.y + pointer)
	var dy: float = 0.0
	var alpha: float = 1.0
	if _dropped:
		if _reduced:
			alpha = clampf(to * 2.0, 0.0, 1.0)
		else:
			dy = lerpf(-drop, 0.0, _back_out(_sub(to, 0.0, 0.35), 1.1))
	if leaving > 0.0:
		if _reduced:
			alpha = 1.0 - leaving
		else:
			dy = lerpf(0.0, -drop, _ease_out(leaving))
	var shake: Vector2 = _shake()
	_lineup.position = rest + Vector2(0, _grid(dy))
	_layer.position = shake
	_lineup.modulate.a = alpha
	var flip: float = 1.0 if _reduced else _sub(to, FLY_TO, 1.0)
	if _index >= 0:
		var squeeze: float = 1.0 if flip <= 0.0 or flip >= 1.0 else absf(cos(flip * PI))
		_lineup.flip_mini(_index, flip >= 0.5, squeeze)
		if flip >= 1.0 and not _landed:
			_landed = true
			Sfx.play_at(self, LAND_SOUND)
	_lineup.set_collected(_complete and _since(&"slap") >= (0.0 if _reduced else SLAP_GOLD_S))
	for index: int in _lineup.minis().size():
		var rise: int = 0
		if _complete and not _reduced and _has(&"slap"):
			var hop: float = _since(&"slap") - HOP_FROM_S - index * HOP_GAP_S
			if hop > 0.0 and hop < HOP_S:
				rise = roundi(sin(hop / HOP_S * PI) * HOP_RISE)
		_lineup.hop_mini(index, rise)


## The icon's flight from the reveal's place to its mini (every frame, on the 2 px grid: the 2x
## sprite, then the mini) and the landing's ring.
func _apply_flight(to: float) -> void:
	var start: Vector2 = _reveal.icon_centre()
	var target: Vector2 = _lineup.mini_centre(maxi(_index, 0))
	var fly: float = 1.0 if _reduced else _sub(to, FLY_FROM, FLY_TO)
	_flyer.visible = fly < 1.0 and _index >= 0
	for sparkle: TextureRect in _sparkles:
		sparkle.visible = false
	if _flyer.visible:
		var q: float = _fly(fly)
		var shown: Vector2 = ItemView.SPRITE_SIZE
		_flyer.texture = _figure
		if q >= MINI_FROM and _mini != null:
			shown = MINI_SIZE
			_flyer.texture = _mini
		_flyer.size = shown
		var centre: Vector2 = _arc(start, target, q)
		_flyer.position = _grid_v(centre - shown / 2.0)
		var puff: float = (fly - _unfly(MINI_FROM)) / PUFF_SHARE
		if puff >= 0.0 and puff < 1.0 and _mini != null:
			for k: int in range(0, RING, 2):
				var angle: float = k * TAU / RING + PI / 6.0
				var spread: float = lerpf(PUFF_SPREAD * 0.6, PUFF_SPREAD, puff)
				_sparkle(k, centre + Vector2(cos(angle), sin(angle)) * spread, 1.0)
		return
	var since: float = _t - (float(_segments[0]["t1"]) if not _segments.is_empty() else 0.0)
	if _reduced or since < 0.0 or since >= RING_S:
		return
	for k: int in range(RING):
		var angle: float = k * TAU / RING
		var spread: float = _ease_out(clampf(since * 3.0, 0.0, 1.0)) * RING_RADIUS
		_sparkle(k, target + Vector2(cos(angle), sin(angle)) * spread, 1.0 - since * 2.2)


func _sparkle(index: int, centre: Vector2, alpha: float) -> void:
	var sparkle: TextureRect = _sparkles[index]
	sparkle.visible = alpha > 0.0
	sparkle.position = _grid_v(centre - SPARKLE_SIZE / 2.0)
	sparkle.modulate.a = clampf(alpha, 0.0, 1.0)


## The tick: the LED and the plate hop; NEW! under the landed mini until the card leaves.
func _apply_tick() -> void:
	var ticking: bool = _started(&"tick") and _p(&"tick") < 1.0 and not _reduced
	var rise: int = roundi(sin(_p(&"tick") * PI) * TICK_RISE) if ticking else 0
	if _started(&"tick"):
		_chip.position = _chip_rest - Vector2(0, rise * ArtStyle.ART_SCALE)
	_machine.nudge_floor(rise)
	var shown: bool = not _complete and _started(&"tick") and not _started(&"away")
	_burst.visible = shown
	if shown:
		var target: Vector2 = _lineup.mini_centre(maxi(_index, 0))
		_burst.position = _grid_v(target + Vector2(0, BURST_DROP) - BURST_SIZE / 2.0)
		_burst.modulate.a = 1.0 if _reduced else clampf(_since(&"tick") * 5.0, 0.0, 1.0)


func _shake() -> Vector2:
	if not _complete or _reduced or not _started(&"slap"):
		return Vector2.ZERO
	var p: float = _p(&"slap")
	if p >= SHAKE_SHARE:
		return Vector2.ZERO
	var strength: float = (1.0 - p / SHAKE_SHARE) * SHAKE
	var art: float = ArtStyle.ART_SCALE
	return Vector2(roundf(sin(p * 90.0) * strength), roundf(cos(p * 70.0) * strength)) * art


## The COMPLETED! card: popped (or faded) in, its stamp slammed onto the band (the card jolts at
## the impact); out.
func _apply_card() -> void:
	if not _complete or not _card.visible:
		return
	var pin: float = _p(&"card_in")
	var out: float = _p(&"card_out")
	var alpha: float = (clampf(pin * 3.0, 0.0, 1.0) if _reduced else 1.0) * (1.0 - out)
	var pop: float = (
		CARD_POP_FROM
		+ (1.0 - CARD_POP_FROM) * _back_out(clampf(pin / CARD_POP_SHARE, 0.0, 1.0), 1.6)
	)
	_card.scale = Vector2.ONE * (1.0 if _reduced else pop * (1.0 - 0.3 * out))
	_card.modulate.a = alpha
	var stamp: Control = _card.stamp()
	var slam: float = 1.0 if _reduced else clampf((pin - STAMP_FROM) / STAMP_SHARE, 0.0, 1.0)
	stamp.modulate.a = 1.0 if slam > 0.0 else 0.0
	stamp.scale = Vector2.ONE * _stamp_step(lerpf(STAMP_SIZE, 1.0, slam * slam), slam)
	var jolt: int = 0
	if not _reduced and slam >= 1.0:
		var since: float = _since(&"card_in") - CARD_IN_S * (STAMP_FROM + STAMP_SHARE)
		jolt = JOLT if since >= 0.0 and since < JOLT_S else 0
	_card.position = _card_rest + Vector2(0, jolt * ArtStyle.ART_SCALE)
	if slam >= 1.0 and not _stamped:
		_stamped = true
		Sfx.play_at(self, STAMP_SOUND)


## SOLD OUT drops in and swings (or fades in), the plate flips, the lamp flickers off.
func _apply_sold() -> void:
	if not _complete or not _started(&"sold"):
		return
	var p: float = _p(&"sold")
	var seconds: float = _since(&"sold")
	var sold: Control = _machine.part("sold_out")
	var floor_plate: Control = _machine.part("floor")
	if _reduced:
		sold.modulate.a = clampf(p * 3.0, 0.0, 1.0)
		return
	var drop: float = _ease_out(clampf(seconds / SOLD_DROP_S, 0.0, 1.0))
	sold.position = _sold_rest + Vector2(0, _grid(lerpf(-SOLD_DROP, 0.0, drop)))
	var swing: float = SWING_DEGREES * exp(-6.0 * seconds) * cos(13.0 * seconds)
	sold.rotation_degrees = swing if p < 1.0 else 0.0
	var flip: float = _sub(p, SOLD_FLIP.x, SOLD_FLIP.y)
	floor_plate.pivot_offset = floor_plate.size / 2.0
	floor_plate.scale = Vector2(1.0, maxf(0.05, absf(cos(flip * PI))) if flip < 1.0 else 1.0)
	var on: bool = p < 0.5 and int(floorf(p * FLICKER_STEPS)) % 2 == 1
	_lamp.texture = ToyExitArt.lamp("on" if on else "off")


## The slam's scale `eased` held to the nearest of STAMP_STEPS above 1 until it lands (`slam` 1).
static func _stamp_step(eased: float, slam: float) -> float:
	if slam >= 1.0:
		return 1.0
	var best: float = STAMP_STEPS[0]
	for step: float in STAMP_STEPS.slice(0, -1):
		if absf(step - eased) < absf(best - eased):
			best = step
	return best


## The flight's path at `q`: the straight line lifted by an arc of ARC at most, as much as the
## trip goes sideways (review fix: on a trip straight up to the card, the arc lifted the icon
## over its slot and it hung there before falling in).
static func _arc(from: Vector2, to: Vector2, q: float) -> Vector2:
	var trip: Vector2 = to - from
	var sideways: float = absf(trip.x) / maxf(trip.length(), 1.0)
	return from.lerp(to, q) - Vector2(0, sin(q * PI) * ARC * sideways)


static func _sub(p: float, from: float, to: float) -> float:
	return clampf((p - from) / (to - from), 0.0, 1.0)


static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


## The flight's curve: quick off the mark (slope 2 - LAND_SPEED) and still moving as it lands
## (slope LAND_SPEED), so on the 2 px grid it never stands still for a frame.
static func _fly(x: float) -> float:
	return x + (1.0 - LAND_SPEED) * x * (1.0 - x)


## The flight's share `fly` at which _fly reaches `q`.
static func _unfly(q: float) -> float:
	var k: float = 1.0 - LAND_SPEED
	var b: float = 1.0 + k
	return (b - sqrt(b * b - 4.0 * k * q)) / (2.0 * k)


static func _back_out(x: float, overshoot: float) -> float:
	var c3: float = overshoot + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + overshoot * pow(x - 1.0, 2.0)


## On the 2 px art grid.
static func _grid(value: float) -> float:
	var art: float = ArtStyle.ART_SCALE
	return roundf(value / art) * art


static func _grid_v(value: Vector2) -> Vector2:
	return Vector2(_grid(value.x), _grid(value.y))
