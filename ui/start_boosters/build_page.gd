class_name BuildPage
extends Control
## YOUR BUILD, page 2 of the opening board (v1.32, the user's pick of 2026-11-13 on mock-up
## docs/art/mockups/start_boosters_v3.html: "I really like mockup"). The staff room: the corkboard
## with the BADGE PINS step, the order sheet (the cart: the regulars, today's boosters and the worn
## pins' cards), the REGULARS crate (BuildRegulars: the regulars, SWAP and KEEP) and OPEN STORE.
## While the profile owns a badge pin, the BADGE PINS step opens first and OPEN STORE waits for its
## confirm; the step wears one pin per slot (or none). The corkboard (or P) reopens it later. Then
## OPEN STORE waits for the crate's KEEP (v1.41: every run, swapping or not; Enter presses it).
## Once both are done OPEN STORE (Enter) lights: the cart's cards gather, turn into items, drop into
## the cart and the cart rolls out, then the board clocks in. (The three starter packs on the bench,
## NEW PACKS and the pick went in v1.41, 2026-11-18.)
##
## Every rule goes through StartBoardActions (saved at once); the motion is cosmetic, on the
## page's own clock (`now`), which tests and captures step with advance(). Reduced motion shows
## each end state. Drawing is BuildPageDraw's (and PinStepDraw's, StoreFlight's), in art px.

signal store_pressed
## The crate's SWAP key (S): the board opens the regulars' swap window over this page.
signal swap_pressed
signal store_opened

const TUNING_PATH := "res://data/balance/start_boosters.tres"
const MAX_STEP := 0.1
## The bench's top (art px).
const BENCH_Y := 298
## The corkboard's badge pin (art px) and the BADGE PINS step's box.
const CORK_PIN := Vector2i(64, 125)
const PIN_BOX := Rect2i(104, 42, 336, 252)
const PIN_ROW_H := 26
## The floor: ‹ STORE, the hint LED and the primary key (art px).
const BACK_RECT := Rect2i(8, 323, 72, 26)
const LED_RECT := Rect2i(88, 326, 412, 18)
const PRIMARY_RECT := Rect2i(512, 322, 120, 28)
## The order sheet's place on the stage (px): the right column, as the staff room's.
const ORDER_POSITION := Vector2(892, 68)
## The floor ticker's line once the cart is ready.
const READY_HINT := "CHECK YOUR CART, THEN OPEN STORE"

var tuning: StartBoostersTuning
var run: RunState
var profile: ProfileState
var actions: StartBoardActions
var now: float = 0.0
var frozen: bool = false
var rm: bool = false
## The page opened at (page clock).
var page_t: float = -INF
## The BADGE PINS step: open, since when, the pins being chosen, the last toggled {pin, t}, the
## worn pin's flight to the corkboard.
var pins_open: bool = false
var pins_t: float = -INF
var pins_sel: Array[PinDefinition] = []
var pins_tick: Dictionary = {}
var fly_t: float = -INF
var fly_pin: PinDefinition
## The top bar's CART count: the target, the number shown, its last step and punch.
var cart_n: int = 0
var cart_shown: int = 0
var cart_step_t: float = 0.0
var cart_punch_t: float = -INF
var cart_punch_s: float = 1.0
var hint: String = ""
var hint_t: float = 0.0
var message: String = ""
var message_t: float = -INF
## The pointer (art px), the hovered hit's id; the hit list, rebuilt every frame.
var mouse: Vector2 = Vector2(-1, -1)
var hover_id: String = ""
var hits: Array[Dictionary] = []
## Cues {at, fn} and sparkles {x, y, t} on the page clock.
var cues: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
## OPEN STORE's flight (null: not flying).
var flight: StoreFlight
var pins: BuildPins
## The regulars in the cart (the order sheet's REGULAR lines) and whether KEEP was pressed on this
## run (the page's own state: a resumed run asks again).
var regulars: Array[CardDefinition] = []
var regulars_ok: bool = false
var order: OrderSheet
## The page's hover tips (the SWAP key's: it shows no word).
var tips: StartTips
var _layers: Array[BuildLayer] = []


func _init() -> void:
	name = "BuildPage"
	size = ShiftStage.SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tuning = load(TUNING_PATH) as StartBoostersTuning
	pins = BuildPins.new(self)
	_add_layer("Room")
	_add_layer("Over2")
	order = OrderSheet.new()
	order.name = "OrderSheet"
	order.position = ORDER_POSITION
	order.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(order)
	_add_layer("Floor")
	_add_layer("Top")
	_add_layer("Pins")
	_add_layer("Store")
	tips = StartTips.new()
	add_child(tips)


func _add_layer(layer_name: String) -> void:
	var layer: BuildLayer = BuildLayer.new(self, layer_name)
	add_child(layer)
	_layers.append(layer)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.INK_LIGHT)


## Shows the page for `shown_run` and keeps it in step with the setup (a board refresh).
func show_build(
	shown_run: RunState, shown_profile: ProfileState, board_actions: StartBoardActions
) -> void:
	var fresh: bool = shown_run != run
	run = shown_run
	profile = shown_profile
	actions = board_actions
	rm = profile.reduced_motion()
	_sync_order()
	cart_n = cart_target()
	if fresh:
		cart_shown = cart_n
		regulars_ok = false


## The page opens (from page 1, or on a resumed run): the BADGE PINS step first while OPEN STORE
## waits for it.
func enter() -> void:
	page_t = now
	pins_open = false
	flight = null
	message = ""
	cart_n = cart_target()
	if pins_pending():
		pins.open(now + (0.0 if rm else tuning.pins_delay_s))
		set_hint("WEAR YOUR BADGE PINS")
		return
	set_hint(BuildRegulars.HINT if regulars_pending() else READY_HINT)


## Whether OPEN STORE waits for the BADGE PINS step (the setup's own state).
func pins_pending() -> bool:
	return StartSetupRules.pins_pending(run, pins.gate_count())


## Whether OPEN STORE waits for the REGULARS crate's KEEP.
func regulars_pending() -> bool:
	return run != null and not regulars_ok


## KEEP on the REGULARS crate (a click, or Enter): OPEN STORE lights. Refused while the BADGE PINS
## step waits or is open.
func keep_regulars(_via: String = "click") -> bool:
	if not regulars_pending() or pins_open or pins_pending() or flight != null:
		return false
	regulars_ok = true
	sfx("stamp_1", -6.0)
	var keep: Rect2i = BuildRegulars.keep_rect(self)
	BuildPageDraw.add_sparkles(
		self, keep.position.x, keep.position.y, keep.size.x, keep.size.y, now, 0.05
	)
	set_hint(READY_HINT)
	page_t = now
	return true


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not frozen:
		advance(minf(delta, MAX_STEP))
	else:
		_refresh_view()


func advance(dt: float) -> void:
	now += dt
	cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at < b.at)
	while not cues.is_empty() and (cues[0].at as float) <= now:
		var due: Dictionary = cues.pop_front()
		(due.fn as Callable).call()
	var step_s: float = 0.06
	if cart_shown != cart_n and now - cart_step_t >= step_s:
		cart_shown += signi(cart_n - cart_shown)
		cart_step_t = now
		cart_punch_t = now
	sparks = sparks.filter(func(p: Dictionary) -> bool: return now - (p.t as float) < 0.2)
	if flight != null:
		flight.step(now)
		if flight.done(now):
			flight = null
			store_opened.emit()
	_refresh_view()


func _refresh_view() -> void:
	hits = BuildPageDraw.hits(self)
	_update_hover()
	# No tip while blocked or while the page slides (no node is built during the board's slide).
	if BuildPageDraw.tips_blocked(self) or position.x != 0.0:
		tips.clear()
	else:
		tips.show_entries(BuildRegulars.tip_entries(self))
	for layer: BuildLayer in _layers:
		layer.queue_redraw()


## The top bar's CART target: the regulars and the counted boosters' cards.
func cart_target() -> int:
	var count: int = run.starter.core_cards.size()
	for booster: StartBooster in run.start_setup.active_boosters():
		count += booster.cards.size()
	return count


func _sync_order() -> void:
	var view: StartBuildView = StartBuildView.new()
	view.starter = run.starter
	view.start_offer = run.start_offer
	view.balance = run.balance
	view.pins = run.pins
	order.show_cart(view)
	regulars.clear()
	for line: StartCartLine in StartSetupRules.cart_lines(
		run.starter, run.start_offer, run.balance, run.pins
	):
		if line.source == StartCartLine.Source.REGULAR:
			regulars.append(line.card)


## The primary key (Enter, a click): the pins' confirm, the pins step, a skip, the crate's KEEP
## (Enter; a click on the dim key says so), or OPEN STORE.
func primary(via: String = "key") -> bool:
	# A click on the key asked its hit already (click); the pins step's key is its confirm, Enter
	# while KEEP waits is KEEP.
	var id: StringName = TutorialAnchors.PRIMARY
	if pins_open:
		id = TutorialAnchors.PINS_CONFIRM
	elif flight == null and not pins_pending() and regulars_pending() and via != "click":
		id = TutorialAnchors.REGULARS_OK
	if via != "click" and flight == null and not StartBoardActions.hit_allowed(actions, id):
		return false
	var used: bool = true
	if flight != null:
		flight.skip(now)
	elif pins_open:
		used = pins.confirm(via)
	elif pins_pending():
		used = pins.open(now)
	elif regulars_pending():
		used = via != "click" and keep_regulars(via)
		if via == "click":
			flash("KEEP YOUR REGULARS FIRST")
	else:
		used = open_store()
	return used


## OPEN STORE: the flight to the cart (reduced motion: straight to the clock-in). Refused while a
## counted booster is sealed (a RESTOCK on page 1) or the BADGE PINS step waits.
func open_store() -> bool:
	if flight != null or pins_pending() or regulars_pending():
		return false
	if not run.start_setup.all_open():
		flash("OPEN YOUR BOOSTERS FIRST")
		return false
	flight = StoreFlight.new(self)
	StartBoardActions.emit(actions, TutorialEvents.STORE_OPENED)
	if rm:
		flight = null
		store_opened.emit()
	return true


func flash(text: String) -> void:
	message = text
	message_t = now
	sfx("ui_close", -10.0)


func set_hint(text: String) -> void:
	if hint != text:
		hint = text
		hint_t = now


func cue(at: float, fn: Callable) -> void:
	cues.append({"at": at, "fn": fn})


func sfx(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var player: Sfx = Sfx.find(self)
	if player != null:
		player.play(sound, pitch, volume_db)


## A page-2 key from the board (1-9, P, S, Esc, Enter, Space); true when used.
func handle_key(keycode: Key) -> bool:
	var number: int = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9].find(keycode)
	var used: bool = false
	if not StartBoardActions.hit_allowed(actions, _key_hit(keycode, number)):
		used = false
	elif keycode == KEY_ESCAPE:
		used = pins.close()
	elif keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		used = primary("key")
	elif pins_open:
		used = number >= 0 and pins.toggle_at(number)
	elif flight != null:
		used = false
	elif keycode == KEY_P:
		used = pins.open(now)
	elif keycode == KEY_S and BuildRegulars.swap_shown(self):
		swap_pressed.emit()
		used = true
	return used


## The hit a page-2 key acts as, for the tutorial's gate (&"": never asked: Esc, Enter and Space,
## which primary asks, unused keys): 1-9 a pin row in the pins step, P the corkboard, S the
## crate's SWAP key.
func _key_hit(keycode: Key, number: int) -> StringName:
	var id: StringName = &""
	if keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or flight != null:
		id = &""
	elif pins_open:
		id = TutorialAnchors.indexed(TutorialAnchors.PIN_ROW, number) if number >= 0 else &""
	elif keycode == KEY_P:
		id = TutorialAnchors.PINS
	elif keycode == KEY_S and BuildRegulars.swap_shown(self):
		id = TutorialAnchors.SWAP_KEY
	return id


## The tutorial's id for this frame's hit `entry` (&"": never asked: a modal's background, which
## only says what to do): a pin row, the pins step's confirm, else the hit's own id.
func _hit_id(entry: Dictionary) -> StringName:
	var id: String = entry.id
	if id.begins_with("modal"):
		return &""
	if id == "pinsok":
		return TutorialAnchors.PINS_CONFIRM
	if id.begins_with("pin_"):
		var owned: Array[PinDefinition] = pins.owned()
		for k: int in owned.size():
			if "pin_%s" % owned[k].id == id:
				return TutorialAnchors.indexed(TutorialAnchors.PIN_ROW, k)
	return StringName(id)


func _gui_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		mouse = (motion.position / ArtPen.UNIT).floor()
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	mouse = (button.position / ArtPen.UNIT).floor()
	accept_event()
	click(mouse)


## A click at art point `at`: the topmost hit under it (a modal hit swallows the rest).
func click(at: Vector2) -> void:
	if flight != null:
		flight.skip(now)
		return
	hits = BuildPageDraw.hits(self)
	for k: int in range(hits.size() - 1, -1, -1):
		var entry: Dictionary = hits[k]
		if (entry.rect as Rect2).has_point(at):
			var act: Callable = entry.act
			if act.is_valid() and StartBoardActions.hit_allowed(actions, _hit_id(entry)):
				act.call()
			return


func _update_hover() -> void:
	var found: String = ""
	for k: int in range(hits.size() - 1, -1, -1):
		if (hits[k].rect as Rect2).has_point(mouse):
			found = hits[k].id
			break
	hover_id = found
	var live: bool = found != "" and not found.begins_with("modal")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if live else Control.CURSOR_ARROW


## ‹ STORE and the YOUR STORE tab: back to page 1.
func press_store() -> void:
	store_pressed.emit()


func is_hovered(id: String) -> bool:
	return hover_id == id
