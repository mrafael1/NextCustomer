class_name BoosterPage
extends Control
## YOUR STORE, page 1 of the opening board (v1.32, full build plan 7.2; the user's pick of
## 2026-11-13 on mock-up docs/art/mockups/start_boosters_v3.html: "I really like mockup"). The
## store at dawn: its shutters roll up by themselves (after auto_roll_s; the web build waits for a
## click, which also unlocks audio) and the view walks in through the door; the lamps come on and
## today's aisle boosters drop under them. A booster opens on a click (or 1-2): grab, rattle,
## tear, burst, its three cards rise and spread, the commons flip on a rising note ladder and the
## brass-backed hit card waits for its click (TAP IT); a RARE hit freezes, flashes, pops over a
## teal sunburst and wears its RARE! tab. OPEN ALL (the primary key, A, or Space held) opens every
## booster fast with the hits flipped for you. When the last one is open the clock steps to 7:00,
## every lamp goes full and STOCKED! hangs under the board. The four regulars stand face up in
## their crate (STANDING ORDER): once every booster is open, a click opens the swap tray (3
## products per completed aisle) and a click on a swapped regular puts it back. RESTOCK (3
## completed aisles) returns one opened booster to the tote for a fresh sealed one. At 6 completed
## aisles three boosters stand under three lamps: PICK 2 OF 3, the third is SOLD OUT.
##
## Every rule goes through StartBoardActions (saved at once); the motion is cosmetic, played on the
## page's own clock (`now`), which tests and captures step with advance(). Reduced motion shows
## each end state. Drawing is BoosterPageDraw's, in art px (ArtPen).

signal title_pressed
signal next_pressed

enum Shutter { DOWN, ROLLING, UP }

## The clock's minutes past 6 on the top bar and the wall clock: 6:58 until STOCKED!.
const OPENING_MINUTES := 58
const TUNING_PATH := "res://data/balance/start_boosters.tres"
## The most one frame advances the page's clock (s).
const MAX_STEP := 0.1

var tuning: StartBoostersTuning
var run: RunState
var profile: ProfileState
var actions: StartBoardActions
var boosters: Array[BoosterOpening] = []
## The page's clock (s), and whether it waits for advance() (tests and captures).
var now: float = 0.0
var frozen: bool = false
var rm: bool = false
var shutter: Shutter = Shutter.DOWN
var shutter_t: float = -INF
var auto_roll_at: float = INF
var restock_armed: bool = false
## The returns tote's flight: when, which booster, its old cards (empty: none).
var tote_t: float = -INF
var tote_booster: int = -1
var tote_cards: Array[CardDefinition] = []
var tote_puff: bool = false
## The swap tray: the regular it swaps (-1: closed) and its aisle tab.
var tray_slot: int = -1
var tray_tab: int = 0
## STOCKED!: when the page completed (INF: not yet), when the stamp hung.
var complete_t: float = INF
var stocked_t: float = INF
var clock_minutes: int = OPENING_MINUTES
## PICK 2 OF 3 resolved: when the kept pair starts its slide (-INF: no pick on show).
var pick_settle_t: float = -INF
## The top bar's CART count: the target, the number shown (it rolls one a step), its punch.
var cart_n: int = 0
var cart_shown: int = 0
var cart_step_t: float = 0.0
var cart_punch_t: float = -INF
var cart_punch_s: float = 1.0
## The ladder's next note, how many boosters opened, how many RAREs landed.
var flip_n: int = 0
var opened_n: int = 0
var rare_n: int = 0
var shake_t: float = -INF
## Space held since (-1: not held); the hint LED's line and its start, a flashed message.
var hold_t: float = -1.0
var hint: String = ""
var hint_t: float = 0.0
var message: String = ""
var message_t: float = -INF
## The shelves' light per zone (0: A, 1: B): when on, when off.
var shelf_on: Array[float] = [INF, INF]
var shelf_off: Array[float] = [-INF, -INF]
## The pointer in art px, the hovered hit's id and since when; hits rebuilt every frame.
var mouse: Vector2 = Vector2(-1, -1)
var hover_id: String = ""
var hover_t0: float = 0.0
var hits: Array[Dictionary] = []
## A swapped regular's swap time (slot -> stage clock), for its drop-in.
var swap_t: Dictionary[int, float] = {}
## Kept for the board: NEW tags are gone from this page (its controls explain themselves).
var fresh: Array[StringName] = []
## The page's three helpers: the openings (arrival, boosters, PICK 2 OF 3), the counter (RESTOCK,
## the regulars' swaps) and the effects (sounds, cues, particles).
var openings: BoosterOpenings
var counter: BoosterCounter
var fx: BoosterFx
## A RARE's hitstop: the page's clock holds until this wall-clock time (ms).
var hitstop_until: int = 0
var _scene: Control
var _layers: Array[BoosterLayer] = []
var _facade: Control
var _hover_spot: Control
var _shown_run: RunState


func _init() -> void:
	name = "BoosterPage"
	size = ShiftStage.SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tuning = load(TUNING_PATH) as StartBoostersTuning
	openings = BoosterOpenings.new(self)
	counter = BoosterCounter.new(self)
	fx = BoosterFx.new(self)
	_scene = Control.new()
	_scene.name = "Scene"
	_scene.size = ShiftStage.SIZE
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene)
	_add_layer(_scene, "Back")
	_add_layer(_scene, "Light", true)
	_add_layer(_scene, "Front")
	var counter_clip: Control = _clip(
		_scene, "CounterClip", Rect2(0, 0, BoosterArt.AW, BoosterPageDraw.COUNTER_CLIP)
	)
	_add_layer(counter_clip, "Boosters")
	_add_layer(_scene, "Front2")
	var bay: Control = _clip(
		_scene, "BayClip", BoosterChromeDraw.bay_rect().grow_individual(-1, -1, -1, 0)
	)
	_add_layer(bay, "Tote").position = -bay.position
	_add_layer(_scene, "Front3")
	_add_layer(_scene, "Glow", true)
	_add_layer(_scene, "Pop")
	_facade = _add_layer(self, "Facade")
	_add_layer(self, "Top")
	_hover_spot = Control.new()
	_hover_spot.name = "HoverCard"
	_hover_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_spot.visible = false
	add_child(_hover_spot)


func _add_layer(parent: Control, layer_name: String, additive: bool = false) -> BoosterLayer:
	var layer: BoosterLayer = BoosterLayer.new(self, layer_name)
	if additive:
		var light: CanvasItemMaterial = CanvasItemMaterial.new()
		light.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		layer.material = light
	parent.add_child(layer)
	_layers.append(layer)
	return layer


## A control clipping what is drawn in it to art rect `rect`.
func _clip(parent: Control, clip_name: String, rect: Rect2) -> Control:
	var clip: Control = Control.new()
	clip.name = clip_name
	clip.position = rect.position * ArtPen.UNIT
	clip.size = rect.size * ArtPen.UNIT
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(clip)
	return clip


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.TEAL_BLACK)


## Shows the page for `shown_run` (a new run sets it up; the same run syncs with its setup).
func show_store(
	shown_run: RunState, shown_profile: ProfileState, board_actions: StartBoardActions = null
) -> void:
	profile = shown_profile
	if board_actions != null:
		actions = board_actions
	rm = profile.reduced_motion()
	if shown_run != _shown_run:
		run = shown_run
		_shown_run = shown_run
		_setup()
	else:
		_sync()


func _setup() -> void:
	boosters.clear()
	fx.clear()
	now = 0.0
	tray_slot = -1
	restock_armed = false
	tote_cards.clear()
	complete_t = INF
	stocked_t = INF
	clock_minutes = OPENING_MINUTES
	pick_settle_t = -INF
	var setup: StartSetup = run.start_setup
	var any_open: bool = false
	var choosing: bool = setup.picking()
	var zone: int = 0
	for index: int in setup.boosters.size():
		var booster: StartBooster = setup.boosters[index]
		var centre: float = float(BoosterArt.ZONE_A if zone == 0 else BoosterArt.ZONE_B)
		if choosing:
			centre = float(BoosterArt.PICK_X[mini(index, 2)])
		var opening: BoosterOpening = BoosterOpening.new(booster, index, centre)
		if booster.sold_out:
			opening.state = BoosterOpening.State.GONE
		else:
			zone += 1
			if booster.opened:
				opening.show_open()
				any_open = true
				shelf_on[BoosterArt.zone_of(opening.cx)] = -10.0
		boosters.append(opening)
		for k: int in opening.cards.size():
			BoosterArt.face(opening.cards[k], opening.rares[k])
	cart_n = cart_target()
	cart_shown = cart_n
	if any_open or rm:
		shutter = Shutter.UP
		shutter_t = -INF
		for opening: BoosterOpening in boosters:
			opening.drop_t = -10.0
			opening.lamp_on = -10.0
		if any_open and openings.all_open():
			complete_t = -10.0
			stocked_t = -10.0
			clock_minutes = 60
	else:
		shutter = Shutter.DOWN
		auto_roll_at = INF if OS.has_feature("web") else tuning.auto_roll_s
	set_hint("")


## Keeps the page in step with the setup after a board refresh (a swap, a pin change).
func _sync() -> void:
	cart_n = cart_target()


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not frozen:
		var step: float = minf(delta, MAX_STEP)
		if Time.get_ticks_msec() < hitstop_until:
			step = 0.0
		advance(step)
	else:
		_refresh_view()


## Moves the page's clock on `dt` seconds: the openings, the cues, the cart count, STOCKED!.
func advance(dt: float) -> void:
	now += dt
	if shutter == Shutter.DOWN and now >= auto_roll_at:
		openings.roll_up()
	openings.step(dt)
	fx.run_cues(now)
	var step_s: float = 0.03
	if cart_shown != cart_n and now - cart_step_t >= step_s:
		cart_shown += signi(cart_n - cart_shown)
		cart_step_t = now
		cart_punch_t = now
	if hold_t >= 0.0 and now - hold_t >= tuning.hold_space_s:
		hold_t = -1.0
		openings.open_all("hold space")
	var dropped: float = tuning.restock_tote_at_s + tuning.restock_tote_s
	if (
		tote_cards.size() > 0
		and not tote_puff
		and now - tote_t >= dropped + tuning.restock_tote_back_s
	):
		tote_puff = true
		var bay: Rect2 = BoosterChromeDraw.bay_rect()
		fx.dust(bay.get_center().x, bay.position.y + 2, 4)
		fx.sfx("card_place_1", -10.0)
	if tote_cards.size() > 0 and (rm or now - tote_t > dropped + tuning.restock_clear_s):
		tote_cards.clear()
		tote_booster = -1
	_check_complete()
	fx.prune(now)
	_refresh_view()


func _refresh_view() -> void:
	hits = BoosterPageDraw.hits(self)
	_update_hover()
	_place_scene()
	for layer: BoosterLayer in _layers:
		layer.queue_redraw()


## The walk-in: the store grows about the doorway from 0.5x, and a shake on a RARE or STOCKED!.
func _place_scene() -> void:
	var scale_in: float = 1.0
	if shutter == Shutter.ROLLING and not rm:
		var z: float = clampf(
			(now - shutter_t - tuning.shutter_up_s) / maxf(tuning.walk_in_s, 0.001), 0.0, 1.0
		)
		scale_in = minf(1.0, 0.5 + roundf(z * z * 0.5 * 8.0) / 8.0)
	var door: Vector2 = (
		Vector2(
			StoreDawnArt.DOOR.get_center().x,
			StoreDawnArt.DOOR.position.y + StoreDawnArt.DOOR.size.y * 0.55
		)
		* ArtPen.UNIT
	)
	_scene.scale = Vector2.ONE * scale_in
	_scene.position = (door - door * scale_in).round()
	var u: float = now - shake_t
	if not rm and u >= 0.0 and u < 0.14:
		_scene.position += Vector2(0, 8) if u < 0.07 else Vector2(-4, 4)


## TITLE (its plate, the top bar's own) and NEXT (the YOUR BUILD tab once the store is stocked).
func press_title() -> void:
	title_pressed.emit()


func press_next() -> void:
	next_pressed.emit()


## Whether PICK 2 OF 3 is pending (the setup's own state).
func picking() -> bool:
	return run != null and run.start_setup.picking()


## "PICK 2 OF 3" from the data: dealt_aisle_count of start_booster_choice_count boosters.
func _pick_text() -> String:
	return "PICK %d OF %d" % [run.balance.dealt_aisle_count, run.balance.start_booster_choice_count]


func _check_complete() -> void:
	if (
		complete_t != INF
		or shutter != Shutter.UP
		or tote_cards.size() > 0
		or not openings.all_open()
	):
		return
	var t0: float = now + tuning.complete_delay_s
	complete_t = t0
	fx.cue(
		t0,
		func() -> void:
			fx.note(10, -4.0, true)
			# After a RESTOCK the clock already reads 7:00: it never steps back.
			clock_minutes = maxi(clock_minutes, 59)
			fx.sfx("tick", -8.0)
	)
	fx.cue(
		t0 + 0.12,
		func() -> void:
			clock_minutes = 60
			fx.sfx("tick", -8.0)
	)
	fx.cue(t0 + 0.2, fx.sfx.bind("register_bell", -4.0))
	var k: int = 0
	for opening: BoosterOpening in boosters:
		if opening.is_counted():
			fx.cue(full_at(k), fx.sfx.bind("tick", -6.0, 1.3))
			k += 1
	fx.cue(t0 + 0.24, _stamp_stocked)
	fx.cue(t0 + 0.3, fx.sfx.bind("armed", -6.0))
	set_hint("")


## When a counted booster's lamp steps to full (its place k among them).
func full_at(k: int) -> float:
	return complete_t + 0.04 + k * 0.08


func _stamp_stocked() -> void:
	stocked_t = now
	fx.sfx("stamp_1", -2.0)
	fx.sfx("stamp_paid", -6.0)
	shake_t = now
	var size_px: Vector2 = BoosterArt.STOCKED.get_size()
	var centre: Vector2 = Vector2(BoosterArt.STOCKED_CENTRE)
	fx.sparkles(
		centre.x - size_px.x / 2.0,
		centre.y - size_px.y / 2.0 + 1,
		size_px.x,
		size_px.y,
		now + 0.1,
		0.06
	)


## Whether the page is done: STOCKED! has come (NEXT is armed).
func page_done() -> bool:
	return complete_t != INF and now >= complete_t


## The primary key (Enter, a click on it): ROLL UP, skip the arrival, cancel RESTOCK, speed up an
## opening, flip the waiting hit, OPEN ALL, or NEXT.
func primary(via: String = "key") -> bool:
	var used: bool = true
	var waiting: BoosterOpening = openings.waiting_booster()
	if shutter == Shutter.DOWN:
		used = openings.roll_up()
	elif openings.arrival_busy():
		openings.end_arrival()
	elif restock_armed:
		cancel_restock("ui_close")
	elif tote_cards.size() > 0:
		used = false
	elif openings.boost_all():
		used = true
	elif waiting != null and waiting.at_rest(tuning):
		used = openings.flip_hit(waiting.index)
	elif picking():
		flash(_pick_text() + " BOOSTERS")
		used = false
	elif openings.any_sealed():
		used = openings.open_all(via)
	elif page_done():
		next_pressed.emit()
	else:
		used = false
	return used


## The label and sub-label of the primary key, and whether it is lit (BoosterPageDraw).
func primary_label() -> Array:
	var label: Array = ["NEXT ›", "YOUR BUILD", true]
	var sealed: int = 0
	for opening: BoosterOpening in boosters:
		if opening.state == BoosterOpening.State.SEALED and opening.is_counted():
			sealed += 1
	if shutter == Shutter.DOWN:
		label = ["ROLL UP", "OPEN THE STORE", true]
	elif restock_armed:
		label = ["CANCEL", "RESTOCK", false]
	elif openings.opening_now() or openings.arrival_busy():
		label = ["SKIP ›", "SPEED IT UP", true]
	elif picking():
		label = [
			"PICK %d" % run.balance.dealt_aisle_count,
			"OF %d BOOSTERS" % run.balance.start_booster_choice_count,
			false
		]
	elif openings.waiting_booster() != null:
		label = ["FLIP ?", "THE HIT CARD", true]
	elif sealed > 0:
		label = ["OPEN ALL", "%d BOOSTER%s" % [sealed, "" if sealed == 1 else "S"], true]
	return label


## The hint LED's line: a flashed message for 2 s, else the state's hint.
func hint_line() -> String:
	var line: String = ""
	if message != "" and now - message_t < 2.0:
		line = message
	elif hint != "":
		line = hint
	elif shutter == Shutter.DOWN:
		line = "ROLL UP THE SHUTTER"
	elif openings.waiting_booster() != null:
		line = "CLICK THE ? CARD"
	elif restock_armed:
		line = "PICK A BOOSTER TO RETURN"
	elif picking():
		line = _pick_text() + " BOOSTERS"
	elif page_done():
		var can_swap: bool = counter.swaps_live() and counter.swaps_used() < counter.swap_limit()
		line = "CLICK A REGULAR TO SWAP" if can_swap else "THE STORE IS STOCKED"
	elif openings.any_sealed():
		line = "CLICK A BOOSTER TO OPEN IT"
	return line


func hint_start() -> float:
	return message_t if message != "" and now - message_t < 2.0 else hint_t


## A short message on the hint LED (a refused or unsaved action), with the close click.
func flash(text: String) -> void:
	message = text
	message_t = now
	fx.sfx("ui_close", -10.0)


func set_hint(text: String) -> void:
	if hint != text:
		hint = text
		hint_t = now


## The top bar's CART target: the regulars and every landed card of the counted boosters.
func cart_target() -> int:
	var count: int = run.starter.core_cards.size()
	for opening: BoosterOpening in boosters:
		if not opening.is_counted():
			continue
		for k: int in opening.cards.size():
			if opening.landed(k, tuning):
				count += 1
	return count


## Space pressed (`down`) or released: a hold of hold_space_s opens everything; a tap is the
## primary key.
func space(down: bool) -> void:
	if not down:
		hold_t = -1.0
		return
	if (
		shutter == Shutter.UP
		and openings.any_sealed()
		and not picking()
		and not openings.opening_now()
	):
		hold_t = now
		fx.sfx("pour", -8.0)
	else:
		primary("space")


## A page-1 key from the board (1-3, A, R, Esc); true when it was used.
func handle_key(keycode: Key) -> bool:
	var number: int = [KEY_1, KEY_2, KEY_3].find(keycode)
	var used: bool = false
	if keycode == KEY_ESCAPE:
		if tray_slot >= 0:
			tray_slot = -1
			used = true
		elif restock_armed:
			cancel_restock("ui_back")
			used = true
	elif tray_slot >= 0 and number >= 0:
		used = counter.swap_to(number, "key")
	elif keycode == KEY_A:
		used = openings.open_all("key")
	elif keycode == KEY_R:
		used = counter.arm_restock()
	elif number >= 0:
		used = _key_booster(number)
	return used


## Number key `number` on the boosters shown (left to right): ROLL UP first, then the booster's
## RESTOCK, its pick, its hit card's flip or its opening.
func _key_booster(number: int) -> bool:
	var shown: Array[BoosterOpening] = []
	for opening: BoosterOpening in boosters:
		if opening.state != BoosterOpening.State.GONE:
			shown.append(opening)
	var used: bool = false
	if shutter == Shutter.DOWN:
		used = openings.roll_up()
	elif number < shown.size():
		var target: BoosterOpening = shown[number]
		if openings.arrival_busy():
			openings.end_arrival()
		if restock_armed:
			used = counter.restock(target.index)
		elif picking():
			used = openings.pick_booster(target.index)
		elif target.state == BoosterOpening.State.OPENING and target.at_rest(tuning):
			used = openings.flip_hit(target.index)
		else:
			used = openings.open_booster(target.index, "key")
	return used


## RESTOCK disarmed (Esc, CANCEL), with `sound`.
func cancel_restock(sound: String) -> void:
	restock_armed = false
	set_hint("")
	fx.sfx(sound, -6.0)


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


## A click at art point `at`: the shutter, a skip, else the topmost hit under it.
func click(at: Vector2) -> void:
	if shutter == Shutter.DOWN:
		openings.roll_up()
		return
	if openings.arrival_busy():
		openings.end_arrival()
		return
	if openings.boost_all():
		return
	hits = BoosterPageDraw.hits(self)
	for k: int in range(hits.size() - 1, -1, -1):
		var entry: Dictionary = hits[k]
		if (entry.rect as Rect2).has_point(at):
			var act: Callable = entry.act
			if act.is_valid():
				act.call()
			return
	tray_slot = -1
	if restock_armed:
		restock_armed = false
		set_hint("")


func _update_hover() -> void:
	var found: Dictionary = {}
	for k: int in range(hits.size() - 1, -1, -1):
		if (hits[k].rect as Rect2).has_point(mouse):
			found = hits[k]
			break
	var id: String = found.get("id", "")
	if id != hover_id:
		hover_id = id
		hover_t0 = now
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if id != "" else Control.CURSOR_ARROW
	var card: CardDefinition = found.get("card") as CardDefinition
	_hover_spot.visible = card != null
	if card != null:
		var rect: Rect2 = found.rect
		_hover_spot.position = rect.position * ArtPen.UNIT
		_hover_spot.size = rect.size * ArtPen.UNIT
		_hover_spot.set_meta("card", card)


## The control under the pointer that carries a hovered card (its scan popup), or null.
func hovered_card() -> Control:
	return _hover_spot if _hover_spot.visible else null


func is_hovered(id: String) -> bool:
	return hover_id == id
