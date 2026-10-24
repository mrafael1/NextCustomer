class_name ChuteKey
extends Control
## One of the machine's chute keys (#77; redrawn front-on in v0.50, mock-up
## premium_machine_v1.html): a big 192x96 key on the key plate with the chute's icon (the cart,
## the 2 for 1 coupon, a mini punch card with the top bar's stamp slots, the up arrow), its name
## (bold Atkinson 18) and what it does (bold Atkinson 10). NEW ITEMS and COUPONS are cream
## (mustard pale when lit); LOYALTY (the REGISTER chute, named LOYALTY wherever the player sees
## it) and UPGRADES are gold (gold when lit). Only the visit's pair stands on the plate
## (RewardMachineView, MachineLook): NEW ITEMS / COUPONS on a Normal visit, LOYALTY / UPGRADES on a
## BOOSTED (PREMIUM) or STAMP DAY visit; the other pair is sunk out of sight.
##
## A lit key glows (a pulsing ring, on view.idle_time): since v0.53 the ring hugs the key's whole
## silhouette, its face and the base under it (the key's bottom face, its depth), a 2 px gap off it,
## with a fainter ring outside, so the glow never crosses the base. A shut key is sunk, with a
## rubber face that says why in words, never by colour alone: UNLIT a padlock and its visit state
## ("PREMIUM VISITS ONLY" or "PREMIUM AFTER SHIFT n" for LOYALTY and UPGRADES, "NORMAL VISITS ONLY"
## for the others), EMPTY a padlock and "NOTHING TO IMPROVE", CARD_FULL the card's stamps and "CARD
## FULL". Hovering it lifts it 2 px (no hover sound, #62) and lights its stock window column. It
## only shows the RewardMachine.ChuteState it is given.
##
## A pressed key (set_pressed, the machine's choice at the chute wait and through its draw) sinks
## PRESS px, its glow ring turns solid gold and its LED (top right, steel when off) lights green.
## frame(t) lights the keys in turn as the plan reaches them (0.14 s apart; a BONUS visit's keys
## relight 0.08 s apart); the pressed key stays down until the landing's end.

signal hovered(chute: int)
signal unhovered(chute: int)
signal pressed(chute: int)

const SIZE := Vector2(192, 96)
const NAMES: Array[String] = ["NEW ITEMS", "COUPONS", "LOYALTY", "UPGRADES"]
const SUBS: Array[String] = ["ADD TO CART", "ADD TO CART", "STAMP YOUR CARD", "IMPROVE ONE YOU OWN"]
const NAME_SIZE := 18
const SUB_SIZE := 10
const REASON_SIZE := 10
const NAME_WEIGHT := 800
const SUB_WEIGHT := 750
## The face (it sinks by PRESS), the base under it and the icon's, the name's and the sub line's
## middles on the face.
const FACE_HEIGHT := 84.0
const BASE_RECT := Rect2(0, 8, 192, 88)
const ICON_MIDDLE := 26.0
const NAME_RECT := Rect2(4, 44, 184, 24)
const SUB_RECT := Rect2(4, 64, 184, 16)
const REASON_RECT := Rect2(8, 44, 176, 36)
const PADLOCK_RECT := Rect2(87, 8, 18, 20)
const STAMPS_TOP := 8.0
const STAMP_SIZE := 26.0
const STAMP_GAP := 4.0
const STAMP_INITIALS_SIZE := 9
const PRESS := 6.0
const LIFT := 2.0
## How far a shut key sinks.
const SINK := 6.0
## The glow round a lit key: a ring GLOW_GAP outside its silhouette (face and base), a fainter
## one outside that at GLOW_OUTER_ALPHA of it; and its pulse.
const GLOW_GAP := 2.0
const GLOW_OUTER_ALPHA := 0.4
const GLOW_RATE := 5.0
const LED_RECT := Rect2(176, 8, 8, 8)
const PADLOCK := preload("res://art/icons/padlock.png")
const CART := preload("res://art/icons/cart.png")
const COUPON := preload("res://art/icons/coupon_two_for_one_v2.png")
const STAMP_RING := preload("res://art/icons/stamp_ring.png")
const STAMP_EMPTY := preload("res://art/icons/stamp_ring_empty.png")
const UP_ARROW := preload("res://art/icons/up_arrow.png")
## The icons' scale (canvas px per art px): the cart and the arrow at the mock-up's 2x (4), the
## coupon and the stamp rings at its 1x (2).
const BIG_ICON := 4.0
const ICON := 2.0

var chute: int = 0
## RewardMachine.ChuteState shown.
var state: int = RewardMachine.ChuteState.OPEN
var lit: bool = true
## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _face: Control
var _icon: Control
var _name: Label
var _sub: Label
var _padlock: TextureRect
var _stamps: HBoxContainer
var _reason: Label
var _hover: bool = false
## The machine's choice (set_pressed), and whether it shows pressed now (frame).
var _pressed: bool = false
var _pressed_now: bool = false
var _lit_now: bool = true
var _sink: float = 0.0
var _glow: float = 0.0


func _init(key_chute: int) -> void:
	chute = key_chute
	name = "ChuteKey%d" % chute
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_face = Control.new()
	_face.name = "Face"
	_face.size = Vector2(SIZE.x, FACE_HEIGHT)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.draw.connect(_draw_face)
	add_child(_face)
	_icon = _make_icon()
	_face.add_child(_icon)
	_padlock = _sprite(PADLOCK, PADLOCK_RECT, _face)
	_stamps = HBoxContainer.new()
	_stamps.name = "CardStamps"
	_stamps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamps.add_theme_constant_override("separation", int(STAMP_GAP))
	_face.add_child(_stamps)
	_name = _label(NAMES[chute], NAME_SIZE, NAME_WEIGHT, NAME_RECT, false)
	_sub = _label(SUBS[chute], SUB_SIZE, SUB_WEIGHT, SUB_RECT, false)
	_reason = _label("", REASON_SIZE, NAME_WEIGHT, REASON_RECT, true)
	_reason.name = "Reason"
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	show_state(RewardMachine.ChuteState.OPEN, 0, true)


## Whether the key is one of the gold pair (LOYALTY, UPGRADES).
static func is_gold(key_chute: int) -> bool:
	return RewardMachine.BOOSTED_CHUTES.has(key_chute)


## Shows the chute's state: `opens_after` is an UNLIT LOYALTY or UPGRADES key's next PREMIUM
## shift (0: none left); `is_lit` lights an open key (an unchosen key is idle once a chute is
## chosen, and on a bonus visit before the keys relight).
func show_state(key_state: int, opens_after: int, is_lit: bool) -> void:
	state = key_state
	lit = is_lit
	var shut: bool = key_state != RewardMachine.ChuteState.OPEN
	_padlock.visible = (
		key_state == RewardMachine.ChuteState.UNLIT or key_state == RewardMachine.ChuteState.EMPTY
	)
	_icon.visible = not shut
	_stamps.visible = key_state == RewardMachine.ChuteState.CARD_FULL
	_sub.visible = not shut
	_reason.visible = shut
	_name.visible = not shut
	match key_state:
		RewardMachine.ChuteState.UNLIT:
			_sub.text = unlit_text(chute, opens_after, false)
			_reason.text = "%s\n%s" % [NAMES[chute], unlit_text(chute, opens_after, false)]
		RewardMachine.ChuteState.CARD_FULL:
			_sub.text = "CARD FULL"
			_reason.text = "%s\nCARD FULL" % NAMES[chute]
			_show_card_stamps()
		RewardMachine.ChuteState.EMPTY:
			_sub.text = "NOTHING TO IMPROVE"
			_reason.text = "%s\nNOTHING TO IMPROVE" % NAMES[chute]
		_:
			_sub.text = SUBS[chute]
	var full: bool = key_state == RewardMachine.ChuteState.CARD_FULL
	_reason.add_theme_color_override(
		"font_color", Palette.MUSTARD_LIGHT if full else Palette.GREY_LIGHT
	)
	_apply(is_lit, SINK if shut else 0.0)


## Why an UNLIT key is shut, by its chute (`opens_after`: the next PREMIUM shift, 0 for none),
## on one line or (`wrapped`) on two.
static func unlit_text(key_chute: int, opens_after: int, wrapped: bool) -> String:
	var gap: String = "\n" if wrapped else " "
	if not RewardMachine.BOOSTED_CHUTES.has(key_chute):
		return "NORMAL%sVISITS ONLY" % gap
	if opens_after > 0:
		return "PREMIUM%sAFTER SHIFT %d" % [gap, opens_after]
	return "PREMIUM%sVISITS ONLY" % gap


## The key's sub line ("ADD TO CART", "PREMIUM AFTER SHIFT 3", ...), for tests.
func sub_text() -> String:
	return _sub.text


func has_padlock() -> bool:
	return _padlock.visible


## Presses the key (the machine's choice) or lets it back up; frame(t) shows it.
func set_pressed(pressed_now: bool) -> void:
	_pressed = pressed_now
	_apply(_lit_now, _sink)


## Whether the key is the machine's choice (set_pressed).
func is_pressed() -> bool:
	return _pressed


## Whether the key shows pressed now (down, gold ring, LED on).
func looks_pressed() -> bool:
	return _pressed_now


## Whether its LED is lit (green): the key shows pressed.
func led_lit() -> bool:
	return _pressed_now


## The LED's rect on screen, for layout tests.
func led_global_rect() -> Rect2:
	return _face.get_global_transform() * LED_RECT


## Whether the key looks lit now (frame(t): the keys light in turn).
func looks_lit() -> bool:
	return _lit_now


## Whether the pointer is on the key.
func is_hovered() -> bool:
	return _hover


## How far the face sits below its rest (negative: lifted by a hover).
func face_offset() -> float:
	return _sink


## The labels shown on the face (the name and the sub line, or the reason), for layout tests.
func shown_labels() -> Array[Label]:
	if _reason.visible:
		return [_reason]
	return [_name, _sub]


## The key's face (sinks and lifts), for layout tests.
func face() -> Control:
	return _face


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit(chute)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The key at time `t` (seconds) of view.plan: during the intro an open key lights once the plan
## reaches its turn (lights + its place x the stagger: TICKET 0.14 s, BONUS 0.08 s); the pressed
## key stays down until the landing's end; a hovered lit key lifts 2 px while the chutes wait (no
## lift under reduced motion). A lit key's ring pulses on view.idle_time.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var shut: bool = state != RewardMachine.ChuteState.OPEN
	var on: bool = lit and not shut
	var offset: float = SINK if shut else 0.0
	if plan != null and not shut:
		var intro: bool = plan.kind != MachineVisit.Kind.STAMP_DAY and t < plan.choose_at
		if intro:
			on = on and t >= plan.lights + _stagger(plan) * (chute % 2)
		var landed: bool = plan.has_landing and t >= plan.end_at
		if _pressed and on and not landed:
			offset = PRESS
		elif _hover and on and not plan.has_draw and not plan.reduced_motion:
			offset = -LIFT
	var glow: float = 0.0
	if on and plan != null:
		var idle: float = view.idle_time
		glow = 1.0 if _pressed else 0.55 + 0.45 * sin(idle * GLOW_RATE)
	if glow != _glow:
		_glow = glow
		queue_redraw()
	_apply(on, offset)


func _stagger(plan: MachinePlan) -> float:
	var ms: int = plan.tuning.key_stagger_ms
	if plan.kind == MachineVisit.Kind.BONUS:
		ms = plan.tuning.relight_stagger_ms
	return MachineTuning.sec(ms)


## The face lit or idle at `offset` below rest; pressed (lit and down) its ring solid and its LED
## on.
func _apply(on: bool, offset: float) -> void:
	_lit_now = on and state == RewardMachine.ChuteState.OPEN
	var pressed_now: bool = _pressed and _lit_now and offset >= PRESS
	var colours: Array[Color] = _ink()
	_name.add_theme_color_override("font_color", colours[0])
	_sub.add_theme_color_override("font_color", colours[1])
	if offset != _sink or pressed_now != _pressed_now:
		_sink = offset
		_pressed_now = pressed_now
		_face.position.y = offset
	_face.queue_redraw()
	queue_redraw()


## The name's and the sub line's colours.
func _ink() -> Array[Color]:
	if is_gold(chute):
		return [Palette.BRASS_DARKEST, Palette.BRASS_DARKEST]
	return [Palette.INK, Palette.MUSTARD_DARKEST]


## The card's stamps on a CARD FULL key: the owned registers' rings with their initials (the
## last three, as the loyalty card shows them).
func _show_card_stamps() -> void:
	for child: Node in _stamps.get_children():
		_stamps.remove_child(child)
		child.queue_free()
	var owned: Array[UpgradeDefinition] = []
	if view != null and view.run != null:
		owned = view.run.upgrades.slice(maxi(0, view.run.upgrades.size() - 3))
	for upgrade: UpgradeDefinition in owned:
		var ring: TextureRect = UiKit.sprite(STAMP_RING)
		ring.custom_minimum_size = Vector2.ONE * STAMP_SIZE
		var initials: Label = UiKit.body_label(
			LoyaltyCard.initials(upgrade.display_name), STAMP_INITIALS_SIZE, Palette.PAPER
		)
		initials.add_theme_font_override("font", ArtStyle.bold_font(NAME_WEIGHT))
		initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initials.size = Vector2.ONE * STAMP_SIZE
		ring.add_child(initials)
		_stamps.add_child(ring)
	var width: float = owned.size() * STAMP_SIZE + maxf(0.0, owned.size() - 1.0) * STAMP_GAP
	_stamps.position = Vector2(roundf((SIZE.x - width) / 4.0) * 2.0, STAMPS_TOP)
	_stamps.size = Vector2(width, STAMP_SIZE)


## The chute's icon, centred ICON_MIDDLE down the face: the cart, the 2 for 1 coupon, a mini
## punch card (the top bar's stamp slots, two stamped), the up arrow.
func _make_icon() -> Control:
	var holder: Control = Control.new()
	holder.name = "Icon"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(SIZE.x, ICON_MIDDLE * 2.0)
	match chute:
		RewardMachine.Chute.NEW_ITEMS:
			_centred_sprite(CART, BIG_ICON, holder)
		RewardMachine.Chute.COUPONS:
			_centred_sprite(COUPON, ICON, holder)
		RewardMachine.Chute.REGISTER:
			ArtStyle.use_pixel_material(holder)
			holder.draw.connect(_draw_punch_card.bind(holder))
		_:
			_centred_sprite(UP_ARROW, BIG_ICON, holder)
	return holder


func _centred_sprite(texture: Texture2D, k: float, holder: Control) -> void:
	var side: Vector2 = texture.get_size() * k
	var at: Vector2 = MachineArt.snap_point(Vector2(SIZE.x / 2.0, ICON_MIDDLE) - side / 2.0)
	_sprite(texture, Rect2(at, side), holder)


## The mini punch card: cream, a teal band, three stamp slots, two stamped.
func _draw_punch_card(holder: Control) -> void:
	var centre: Vector2 = Vector2(SIZE.x / 2.0, ICON_MIDDLE)
	var card: Rect2 = Rect2(centre - Vector2(50, 18), Vector2(100, 38))
	MachineArt.box(holder, card, Palette.CREAM, Palette.INK)
	holder.draw_rect(Rect2(centre - Vector2(48, 16), Vector2(96, 4)), Palette.TEAL)
	for slot: int in range(3):
		var texture: Texture2D = STAMP_RING if slot < 2 else STAMP_EMPTY
		var at: Vector2 = centre + Vector2(-44 + slot * 30, -10)
		holder.draw_texture_rect(texture, Rect2(at, texture.get_size() * ICON), false)


func _sprite(texture: Texture2D, rect: Rect2, parent: Control) -> TextureRect:
	var result: TextureRect = UiKit.sprite(texture)
	result.position = rect.position
	result.size = rect.size
	parent.add_child(result)
	return result


func _label(text: String, font_size: int, weight: int, rect: Rect2, wraps: bool) -> Label:
	var label: Label = UiKit.body_label(text, font_size, Palette.INK)
	label.add_theme_font_override("font", ArtStyle.bold_font(weight))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wraps:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.add_theme_constant_override("line_spacing", -2)
	else:
		label.clip_text = true
	RewardMachineView.fit(label, rect)
	_face.add_child(label)
	return label


func _on_mouse_entered() -> void:
	_hover = true
	hovered.emit(chute)


func _on_mouse_exited() -> void:
	_hover = false
	unhovered.emit(chute)


## The face: a bevelled key, cream or gold, lit or idle (a shut key's rubber face), the LED.
func _draw_face() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _face.size)
	var gold: bool = is_gold(chute)
	if state != RewardMachine.ChuteState.OPEN:
		MachineArt.bevel(_face, rect, Palette.RUBBER, Palette.STEEL_DARK, Palette.RUBBER_DARK)
		return
	var face_colour: Color = Palette.MUSTARD_PALE if _lit_now else Palette.CREAM
	var hi: Color = Palette.PAPER
	var lo: Color = Palette.CREAM_SHADE
	var line: Color = Palette.INK
	if gold:
		face_colour = Palette.GOLD if _lit_now else Palette.MUSTARD_LIGHT
		hi = Palette.MUSTARD_PALE
		lo = Palette.BRASS
		line = Palette.BRASS_DARKEST
	MachineArt.bevel(_face, rect, face_colour, hi, lo, line)
	MachineArt.box(
		_face, LED_RECT, Palette.GOOD if _pressed_now else Palette.STEEL_SHADE, Palette.INK
	)


## The key's base and shadow under the face, and a lit key's glow ring outside it.
func _draw() -> void:
	var gold: bool = is_gold(chute)
	var line: Color = Palette.BRASS_DARKEST if gold else Palette.INK
	draw_rect(Rect2(-2, 8, SIZE.x + 4, SIZE.y - 4), Color(Palette.INK, 0.35))
	MachineArt.box(self, BASE_RECT, Palette.BRASS_DARK if gold else Palette.CREAM_SHADE, line)
	if _glow > 0.0:
		var colour: Color = Palette.GOLD if gold or _pressed_now else Palette.MUSTARD
		var ring: Rect2 = glow_rect()
		MachineArt.ring(self, ring, Color(colour, _glow))
		var outer: Rect2 = ring.grow(MachineArt.PIXEL)
		MachineArt.ring(self, outer, Color(colour, _glow * GLOW_OUTER_ALPHA))


## The glow's inner ring (key coordinates): the key's silhouette now, its face (sunk or lifted by
## the offset) over its base, grown by the gap and the ring.
func glow_rect() -> Rect2:
	var top: float = minf(_sink, BASE_RECT.position.y)
	var silhouette: Rect2 = Rect2(0, top, SIZE.x, BASE_RECT.end.y - top)
	return silhouette.grow(GLOW_GAP + MachineArt.PIXEL)


## How bright the glow is now (0: none).
func glow_level() -> float:
	return _glow
