class_name ChuteKey
extends Control
## One of the machine's four chute keys (#77, look F; build spec 4.2): a 92x74 key over a 4 px
## ink shadow with the chute's icon (28 px: the cart, a coupon slip, a stamp ring, an up arrow),
## its name (Pixelify 12) and what it does (bold Atkinson 8). Lit, it is paper with a mustard lip;
## idle, cream. A shut key is sunk, with a rubber face that says why in words, never by colour
## alone: LOCKED_SHIFT a padlock and "OPENS AFTER SHIFT n", EMPTY a padlock and "NOTHING TO
## IMPROVE", CARD_FULL the card's stamps and "CARD FULL". Hovering it asks for its odds card (no
## hover sound, #62) and lifts it 2 px. During a STAMP DAY pick the REGISTER key carries a "SEE
## ODDS" tab. It only shows the RewardMachine.ChuteState it is given.
##
## Machine v2 (#77): a pressed key (set_pressed, the machine's choice at the chute wait and
## through its draw) drops SINK px onto its shadow, its lip flattens to PRESSED_LIP, its face turns
## mustard light inside a RING px gold ring, and its LED (top right, steel when off) lights green
## with a GLOW px glow.
##
## frame(t) lights the keys in turn as the plan reaches them (0.14 s apart; a BONUS visit's keys
## go unlit, then relight 0.08 s apart); the pressed key stays down until the landing's end.

signal hovered(chute: int)
signal unhovered(chute: int)
signal pressed(chute: int)

const SIZE := Vector2(92, 74)
const NAMES: Array[String] = ["NEW ITEMS", "COUPONS", "REGISTER", "UPGRADES"]
const SUBS: Array[String] = ["ADD TO CART", "ADD TO CART", "STAMP YOUR CARD", "IMPROVE ONE YOU OWN"]
const NAME_SIZE := 12
const SUB_SIZE := 8
const REASON_SIZE := 9
const FULL_SIZE := 10
const NAME_RECT := Rect2(0, 33, 92, 14)
const SUB_RECT := Rect2(2, 48, 88, 24)
const ICON_TOP := 4.0
const ICON_HEIGHT := 28.0
const PADLOCK_RECT := Rect2(37, 6, 18, 20)
const STAMPS_TOP := 6.0
const STAMP_SIZE := 22.0
const STAMP_GAP := 2.0
const STAMP_INITIALS_SIZE := 8
const TAB_RECT := Rect2(14, -8, 64, 16)
const TAB_TEXT := "SEE ODDS"
const BORDER := 2
const LIP := 5.0
const PRESSED_LIP := 2.0
const SHADOW := 4.0
## How far a shut or pressed key sinks; how far a hovered key lifts.
const SINK := 4.0
const LIFT := 2.0
## The pressed key's gold ring (outside the border) and its LED: LED_RECT on the face, its glow.
const RING := 4.0
const LED_RECT := Rect2(80, 6, 6, 6)
const GLOW := 2.0
const BOLD_WEIGHT := 800
const PADLOCK := preload("res://art/icons/padlock.png")
const CART := preload("res://art/icons/cart.png")
const COUPON := preload("res://art/icons/coupon_two_for_one_v2.png")
const STAMP_RING := preload("res://art/icons/stamp_ring.png")
const UP_ARROW := preload("res://art/icons/up_arrow.png")

var chute: int = 0
## RewardMachine.ChuteState shown.
var state: int = RewardMachine.ChuteState.OPEN
var lit: bool = true
## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _face: Panel
var _style: StyleBoxFlat
var _lip: ColorRect
var _icon: Control
var _name: Label
var _sub: Label
var _shut: ColorRect
var _padlock: TextureRect
var _stamps: HBoxContainer
var _reason: Label
var _tab: Label
var _led: Control
var _hover: bool = false
## The machine's choice (set_pressed), and whether it shows pressed now (frame).
var _pressed: bool = false
var _pressed_now: bool = false
var _lit_now: bool = true
var _sink: float = 0.0


func _init(key_chute: int) -> void:
	chute = key_chute
	name = "ChuteKey%d" % chute
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_face = Panel.new()
	_face.name = "Face"
	_face.size = SIZE
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.border_color = Palette.INK
	_style.set_border_width_all(BORDER)
	_face.add_theme_stylebox_override("panel", _style)
	add_child(_face)
	_lip = _rect(Rect2(BORDER, SIZE.y - BORDER - LIP, SIZE.x - 2 * BORDER, LIP), _face)
	_icon = _make_icon()
	_face.add_child(_icon)
	_shut = _rect(Rect2(BORDER, BORDER, SIZE.x - 2 * BORDER, SIZE.y - 2 * BORDER), _face)
	_shut.name = "ShutFace"
	_shut.color = Palette.RUBBER
	_padlock = _sprite(PADLOCK, PADLOCK_RECT, _face)
	_led = Control.new()
	_led.name = "Led"
	_led.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_led.position = LED_RECT.position
	_led.size = LED_RECT.size
	_led.draw.connect(_draw_led)
	_face.add_child(_led)
	_stamps = HBoxContainer.new()
	_stamps.name = "CardStamps"
	_stamps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamps.add_theme_constant_override("separation", int(STAMP_GAP))
	_face.add_child(_stamps)
	_name = _label(UiKit.display_label(NAMES[chute], NAME_SIZE, false), NAME_RECT)
	_sub = _label(UiKit.body_label(SUBS[chute], SUB_SIZE, Palette.INK), SUB_RECT, true)
	_reason = _label(UiKit.body_label("", REASON_SIZE, Palette.GREY_LIGHT), SUB_RECT, true)
	_reason.name = "Reason"
	_tab = UiKit.body_label(TAB_TEXT, SUB_SIZE, Palette.PAPER)
	_tab.name = "SeeOddsTab"
	_tab.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
	_tab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tab_style: StyleBoxFlat = StyleBoxFlat.new()
	tab_style.bg_color = Palette.TOMATO_DARK
	tab_style.border_color = Palette.INK
	tab_style.set_border_width_all(BORDER)
	_tab.add_theme_stylebox_override("normal", tab_style)
	RewardMachineView.fit(_tab, TAB_RECT)
	_tab.visible = false
	add_child(_tab)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	show_state(RewardMachine.ChuteState.OPEN, 0, true)


## Shows the chute's state: `opens_after` is LOCKED_SHIFT's shift (0: no later shift); `is_lit`
## lights an open key (an unchosen key is idle once a chute is chosen, and on a bonus visit before
## the keys relight).
func show_state(key_state: int, opens_after: int, is_lit: bool) -> void:
	state = key_state
	lit = is_lit
	var shut: bool = key_state != RewardMachine.ChuteState.OPEN
	_shut.visible = shut
	_padlock.visible = (
		key_state == RewardMachine.ChuteState.LOCKED_SHIFT
		or key_state == RewardMachine.ChuteState.EMPTY
	)
	_icon.visible = not shut
	_stamps.visible = key_state == RewardMachine.ChuteState.CARD_FULL
	_sub.visible = not shut
	_reason.visible = shut
	_name.add_theme_color_override("font_color", Palette.PAPER if shut else Palette.INK)
	match key_state:
		RewardMachine.ChuteState.LOCKED_SHIFT:
			_sub.text = "OPENS AFTER SHIFT %d" % opens_after if opens_after > 0 else "CLOSED"
			_reason.text = "OPENS AFTER\nSHIFT %d" % opens_after if opens_after > 0 else "CLOSED"
		RewardMachine.ChuteState.CARD_FULL:
			_sub.text = "CARD FULL"
			_reason.text = "CARD FULL"
			_show_card_stamps()
		RewardMachine.ChuteState.EMPTY:
			_sub.text = "NOTHING TO IMPROVE"
			_reason.text = "NOTHING TO\nIMPROVE"
		_:
			_sub.text = SUBS[chute]
	var full: bool = key_state == RewardMachine.ChuteState.CARD_FULL
	_reason.add_theme_color_override(
		"font_color", Palette.MUSTARD_LIGHT if full else Palette.GREY_LIGHT
	)
	_reason.add_theme_font_size_override("font_size", FULL_SIZE if full else REASON_SIZE)
	_apply(is_lit, SINK if shut else 0.0)


## Shows or hides the STAMP DAY "SEE ODDS" tab.
func set_tab(shown: bool) -> void:
	_tab.visible = shown


## The key's sub line ("ADD TO CART", "OPENS AFTER SHIFT 3", ...), for tests.
func sub_text() -> String:
	return _sub.text


func has_padlock() -> bool:
	return _padlock.visible


func has_tab() -> bool:
	return _tab.visible


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
	return _led.get_global_rect()


## Whether the key looks lit now (frame(t): the keys light in turn).
func looks_lit() -> bool:
	return _lit_now


## How far the face sits below its rest (negative: lifted by a hover).
func face_offset() -> float:
	return _sink


## The labels shown on the face (the name, then the sub line or the reason), for layout tests.
func shown_labels() -> Array[Label]:
	return [_name, _reason if _reason.visible else _sub]


## The key's face (sinks and lifts), for layout tests.
func face() -> Control:
	return _face


## The STAMP DAY tab, for layout tests.
func tab() -> Label:
	return _tab


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
## reaches its turn (lights + its index x the stagger: TICKET 0.14 s, BONUS 0.08 s; a BONUS
## visit's keys stay unlit until then); the pressed key stays down until the landing's end; a
## hovered lit key lifts 2 px while the chutes wait (no lift under reduced motion).
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var shut: bool = state != RewardMachine.ChuteState.OPEN
	var on: bool = lit and not shut
	var offset: float = SINK if shut else 0.0
	if plan != null and not shut:
		var intro: bool = plan.kind != MachineVisit.Kind.STAMP_DAY and t < plan.choose_at
		if intro:
			on = on and t >= plan.lights + _stagger(plan) * chute
		var landed: bool = plan.has_landing and t >= plan.end_at
		if _pressed and on and not landed:
			offset = SINK
		elif _hover and on and not plan.has_draw and not plan.reduced_motion:
			offset = -LIFT
	_apply(on, offset)


func _stagger(plan: MachinePlan) -> float:
	var ms: int = plan.tuning.key_stagger_ms
	if plan.kind == MachineVisit.Kind.BONUS:
		ms = plan.tuning.relight_stagger_ms
	return MachineTuning.sec(ms)


## The face: lit (paper, mustard lip) or idle (cream, cream-shade lip), at `offset` below rest;
## pressed (lit and sunk): mustard light, a flat mustard-dark lip, the ring and the LED on.
func _apply(on: bool, offset: float) -> void:
	_lit_now = on and state == RewardMachine.ChuteState.OPEN
	var pressed_now: bool = _pressed and _lit_now and offset >= SINK
	_style.bg_color = Palette.PAPER if _lit_now else Palette.CREAM
	_lip.color = Palette.MUSTARD_LIGHT if _lit_now else Palette.CREAM_SHADE
	var lip: float = PRESSED_LIP if pressed_now else LIP
	if pressed_now:
		_style.bg_color = Palette.MUSTARD_LIGHT
		_lip.color = Palette.MUSTARD_DARK
	_lip.position.y = SIZE.y - BORDER - lip
	_lip.size.y = lip
	if offset != _sink or pressed_now != _pressed_now:
		_sink = offset
		_pressed_now = pressed_now
		_face.position.y = offset
		_led.queue_redraw()
		queue_redraw()


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
			LoyaltyCard.initials(upgrade.display_name), STAMP_INITIALS_SIZE, Palette.INK
		)
		initials.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
		initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initials.size = Vector2.ONE * STAMP_SIZE
		ring.add_child(initials)
		_stamps.add_child(ring)
	var width: float = owned.size() * STAMP_SIZE + maxf(0.0, owned.size() - 1.0) * STAMP_GAP
	_stamps.position = Vector2(roundf((SIZE.x - width) / 4.0) * 2.0, STAMPS_TOP)
	_stamps.size = Vector2(width, STAMP_SIZE)


## The chute's icon, centred in the key's top 28 px: the cart on a teal tag, the 2 for 1 coupon
## slip, a stamp ring, the up arrow.
func _make_icon() -> Control:
	var holder: Control = Control.new()
	holder.name = "Icon"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = Vector2(0, ICON_TOP)
	holder.size = Vector2(SIZE.x, ICON_HEIGHT)
	match chute:
		RewardMachine.Chute.NEW_ITEMS:
			var tag: Panel = Panel.new()
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tag_style: StyleBoxFlat = StyleBoxFlat.new()
			tag_style.bg_color = Palette.TEAL
			tag_style.border_color = Palette.INK
			tag_style.set_border_width_all(BORDER)
			tag.add_theme_stylebox_override("panel", tag_style)
			var cart_size: Vector2 = CART.get_size() * 2.0
			tag.size = cart_size + Vector2(16, 8)
			tag.position = _centred(tag.size)
			holder.add_child(tag)
			_sprite(CART, Rect2(Vector2(8, 4), cart_size), tag)
		RewardMachine.Chute.COUPONS:
			var coupon_size: Vector2 = COUPON.get_size() * 2.0
			_sprite(COUPON, Rect2(_centred(coupon_size), coupon_size), holder)
		RewardMachine.Chute.REGISTER:
			var ring_size: Vector2 = STAMP_RING.get_size() * 2.0
			_sprite(STAMP_RING, Rect2(_centred(ring_size), ring_size), holder)
		_:
			var arrow_size: Vector2 = UP_ARROW.get_size() * 3.0
			_sprite(UP_ARROW, Rect2(_centred(arrow_size), arrow_size), holder)
	return holder


## The top-left that centres `item_size` in the icon's 92x28 box, on the 2 px grid.
static func _centred(item_size: Vector2) -> Vector2:
	var at: Vector2 = (Vector2(SIZE.x, ICON_HEIGHT) - item_size) / 2.0
	return Vector2(floorf(at.x / 2.0) * 2.0, floorf(at.y / 2.0) * 2.0)


func _sprite(texture: Texture2D, rect: Rect2, parent: Control) -> TextureRect:
	var result: TextureRect = UiKit.sprite(texture)
	result.position = rect.position
	result.size = rect.size
	parent.add_child(result)
	return result


func _rect(rect: Rect2, parent: Control) -> ColorRect:
	var result: ColorRect = ColorRect.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.position = rect.position
	result.size = rect.size
	parent.add_child(result)
	return result


func _label(label: Label, rect: Rect2, wraps: bool = false) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if wraps:
		label.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.add_theme_constant_override("line_spacing", -2)
	RewardMachineView.fit(label, rect)
	_face.add_child(label)
	return label


func _on_mouse_entered() -> void:
	_hover = true
	hovered.emit(chute)


func _on_mouse_exited() -> void:
	_hover = false
	unhovered.emit(chute)


## The LED: steel in an ink border, green with a glow ring while the key shows pressed.
func _draw_led() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, LED_RECT.size)
	if _pressed_now:
		_led.draw_rect(rect.grow(GLOW), Color(Palette.GOOD, 0.55))
	_led.draw_rect(rect, Palette.INK)
	_led.draw_rect(rect.grow(-1.0), Palette.GOOD if _pressed_now else Palette.STEEL_SHADE)


## The key's shadow (4 px of ink under the face; none while it sinks onto it) and, pressed, the
## gold ring outside its border.
func _draw() -> void:
	if _sink < SHADOW:
		draw_rect(Rect2(0, SIZE.y + _sink, SIZE.x, SHADOW - _sink), Palette.INK)
	if _pressed_now:
		var face_rect: Rect2 = Rect2(Vector2(0, _sink), SIZE)
		draw_rect(face_rect.grow(RING / 2.0), Palette.GOLD, false, RING)
