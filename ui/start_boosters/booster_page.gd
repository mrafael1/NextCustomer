class_name BoosterPage
extends Control
## YOUR STORE, page 1 of the opening board (full build plan 7.2; the aisle board, v1.40, the
## user's decisions of 2026-11-18 on mock-up docs/art/mockups/start_roulette.html, variant A; it
## replaces v1.32's store at dawn). The six aisles are bays on the back wall, each under its hung
## sign and stocked with its own products. A light runs along the bays, slows and lands on
## today's first aisle, then on the second; the other bays roll their shutters down; each open
## bay throws its booster to its card row's start (round 3), where it waits sealed until the
## player opens it (a click on it, 1-2, or Enter for the next one; round 2 of the 2026-11-19
## play test) into its compact cards (picture, price, name: the full card with its rule pops on
## hover). The light
## only plays the result: the aisles and the boosters were dealt and saved before the page shows
## (AisleRoulette). A click skips. The guided first run, a resumed page and reduced motion show
## the two open bays at once (a booster opened before stands open, the others sealed). A locked
## aisle's bay is shut behind a padlock from the start. RESTOCK (3 finished aisles) sends one
## opened booster's cards back into their bay for a fresh booster of the same aisle. The
## regulars are in the cart from the start (the CART count); their swap window (SwapWindow) opens
## from page 2's SWAP key, drawn by this page over page 2 (`overlay`).
##
## Every rule goes through StartBoardActions (saved at once); the motion is cosmetic, played on the
## page's own clock (`now`), which tests and captures step with advance(). Reduced motion shows
## each end state. Drawing is AisleBoardDraw's, in art px (ArtPen).

signal title_pressed
signal next_pressed
## The swap window shown over page 2 has shut (StartBoard puts page 2 back in front).
signal swap_closed

const TUNING_PATH := "res://data/balance/start_boosters.tres"
## The most one frame advances the page's clock (s).
const MAX_STEP := 0.1
## What the primary key flashes while RESTOCK is armed (it no longer cancels: v1.36).
const RESTOCK_NEXT_HINT := "PICK A BOOSTER TO RETURN"

var tuning: StartBoostersTuning
var run: RunState
var profile: ProfileState
var actions: StartBoardActions
var boosters: Array[BoosterOpening] = []
## The page's clock (s), and whether it waits for advance() (tests and captures).
var now: float = 0.0
var frozen: bool = false
var rm: bool = false
var restock_armed: bool = false
## When the page completed: every booster open (INF: not yet). NEXT is armed from it.
var complete_t: float = INF
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
## A flashed message (a refused or unsaved action) and its start; `hint` is kept for the swap
## window, which sets it (the page has no hint line since v1.40).
var hint: String = ""
var hint_t: float = 0.0
var message: String = ""
var message_t: float = -INF
## The pointer in art px, the hovered hit's id and since when; hits rebuilt every frame.
var mouse: Vector2 = Vector2(-1, -1)
var hover_id: String = ""
var hover_t0: float = 0.0
var hits: Array[Dictionary] = []
## Kept for the board: NEW tags are gone from this page (its controls explain themselves).
var fresh: Array[StringName] = []
## The page's helpers: the roulette (the light, the shutters, the throws), the
## openings (each booster's beats), the counter (RESTOCK, the swap count), the effects (sounds,
## cues, particles) and the swap window.
var roulette: AisleRoulette
var openings: BoosterOpenings
var counter: BoosterCounter
var fx: BoosterFx
var swap: SwapWindow
## The page's hover tips (the swap window's cards; the full cards' family chips).
var tips: StartTips
## A RARE's hitstop: the page's clock holds until this wall-clock time (ms).
var hitstop_until: int = 0
## Whether the page only shows its swap window, over page 2 (its own scene hidden).
var overlay: bool = false
var _scene: Control
var _layers: Array[BoosterLayer] = []
var _top: Control
var _swap_slide: Control
var _shown_run: RunState
## Whether BOOSTERS_ALL_OPEN went out for the page's current completion (a RESTOCK sends it again).
var _done_sent: bool = false


func _init() -> void:
	name = "BoosterPage"
	size = ShiftStage.SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tuning = load(TUNING_PATH) as StartBoostersTuning
	roulette = AisleRoulette.new(self)
	openings = BoosterOpenings.new(self)
	counter = BoosterCounter.new(self)
	fx = BoosterFx.new(self)
	swap = SwapWindow.new(self)
	_scene = Control.new()
	_scene.name = "Scene"
	_scene.size = ShiftStage.SIZE
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene)
	_add_layer(_scene, "Back")
	_add_layer(_scene, "Light", true)
	var counter_clip: Control = _clip(
		_scene, "CounterClip", Rect2(0, 0, BoosterArt.AW, BoosterPageDraw.COUNTER_CLIP)
	)
	_add_layer(counter_clip, "Boosters")
	_add_layer(_scene, "Front")
	_top = _add_layer(self, "Top")
	_add_layer(self, "SwapVeil")
	_swap_slide = Control.new()
	_swap_slide.name = "SwapSlide"
	_swap_slide.size = ShiftStage.SIZE
	_swap_slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_swap_slide)
	_add_layer(_swap_slide, "SwapFrame")
	var window: Control = _clip(
		_swap_slide, "SwapClip", SwapWindowDraw.RECT.grow_individual(-1, -1, -1, -1)
	)
	_add_layer(window, "Swap").position = -window.position
	_add_layer(_swap_slide, "SwapTop")
	tips = StartTips.new()
	add_child(tips)


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
	if not overlay:
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
	swap = SwapWindow.new(self)
	restock_armed = false
	complete_t = INF
	_done_sent = false
	message = ""
	var setup: StartSetup = run.start_setup
	for index: int in setup.boosters.size():
		var booster: StartBooster = setup.boosters[index]
		var opening: BoosterOpening = BoosterOpening.new(booster, index, 0.0)
		opening.board = true
		opening.compact = tuning.compact_fan_cards
		opening.tabs = false
		if booster.opened:
			opening.show_open()
			opening.fly_t = -10.0
		boosters.append(opening)
		for k: int in opening.cards.size():
			BoosterArt.face(opening.cards[k], opening.rares[k])
	roulette.setup()
	cart_n = cart_target()
	cart_shown = cart_n
	if openings.all_open():
		complete_t = -10.0
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


## Moves the page's clock on `dt` seconds: the roulette's cues, the openings, the cart count, the
## completion.
func advance(dt: float) -> void:
	now += dt
	fx.run_cues(now)
	openings.step(dt)
	swap.step(dt)
	var step_s: float = 0.03
	if cart_shown != cart_n and now - cart_step_t >= step_s:
		cart_shown += signi(cart_n - cart_shown)
		cart_step_t = now
		cart_punch_t = now
	_check_complete()
	if page_done() != _done_sent:
		_done_sent = page_done()
		if _done_sent:
			StartBoardActions.emit(actions, TutorialEvents.BOOSTERS_ALL_OPEN)
	fx.prune(now)
	_refresh_view()


func _refresh_view() -> void:
	if overlay and not swap.visible():
		_end_overlay()
	if swap.visible():
		hits = SwapWindowDraw.hits(self)
	elif overlay:
		hits = []
	else:
		hits = BoosterPageDraw.hits(self)
	_update_hover()
	_update_tips()
	_place_scene()
	_swap_slide.visible = swap.visible()
	_swap_slide.position.y = swap.slide() * ArtPen.UNIT
	for layer: BoosterLayer in _layers:
		layer.queue_redraw()
	queue_redraw()


## A short shake of the scene on a RARE.
func _place_scene() -> void:
	_scene.position = Vector2.ZERO
	var u: float = now - shake_t
	if not rm and u >= 0.0 and u < 0.14:
		_scene.position = Vector2(0, 8) if u < 0.07 else Vector2(-4, 4)


## Page 2's SWAP key: the swap window opens over page 2, this page showing nothing else
## (StartBoard brings it to the front). False when the window can't open.
func open_swap_over() -> bool:
	if swap.visible() or overlay or run == null:
		return false
	if not swap.open_window(false):
		return false
	overlay = true
	_scene.visible = false
	_top.visible = false
	_refresh_view()
	return true


func _end_overlay() -> void:
	overlay = false
	_scene.visible = true
	_top.visible = true
	swap_closed.emit()


## TITLE (its plate) and NEXT (the YOUR BUILD tab once every booster is open).
func press_title() -> void:
	title_pressed.emit()


func press_next() -> void:
	next_pressed.emit()


func _check_complete() -> void:
	if complete_t != INF or roulette.busy() or not openings.all_open():
		return
	complete_t = now + tuning.complete_delay_s
	fx.cue(complete_t, fx.sfx.bind("armed", -6.0))


## Whether the page is done: every booster is open (NEXT is armed).
func page_done() -> bool:
	return complete_t != INF and now >= complete_t


## The primary key (Enter, Space, a click on it): the swap window's DONE while it is open; else a
## skip (the light, the throws), the next sealed booster's opening, a skip of an opening, what an
## armed RESTOCK waits for, or NEXT.
func primary(via: String = "key") -> bool:
	# A skip is never asked of the tutorial's gate: it changes nothing but the pace.
	if not swap.visible() and not overlay:
		if roulette.skip():
			return true
		if openings.next_sealed() == null and openings.boost_all():
			return true
	# A click on the key asked its hit already (click); the swap window's DONE is its part.
	if via != "click":
		if swap.active and not StartBoardActions.swap_allowed(actions, TutorialAnchors.SWAP_DONE):
			return false
		if not swap.active and not StartBoardActions.hit_allowed(actions, TutorialAnchors.PRIMARY):
			return false
	var used: bool = true
	if swap.active:
		used = swap.primary(via)
	elif overlay:
		used = false
	elif restock_armed:
		# v1.36: CANCEL is RESTOCK's own key (and Esc); the primary key says what comes next.
		flash(RESTOCK_NEXT_HINT)
		used = false
	elif openings.next_sealed() != null:
		used = openings.open_booster(openings.next_sealed().index, "key")
	elif page_done():
		next_pressed.emit()
	else:
		used = false
	return used


## The label and sub-label of the primary key, and whether it is lit (BoosterChromeDraw).
func primary_label() -> Array:
	var label: Array = ["NEXT ›", "YOUR BUILD", page_done()]
	if restock_armed:
		label = ["PICK 1", "TO RETURN", false]
	elif roulette.busy():
		label = ["SKIP ›", "SPEED IT UP", true]
	elif openings.next_sealed() != null:
		label = ["OPEN ›", "BOOSTER", true]
	elif openings.opening_now():
		label = ["SKIP ›", "SPEED IT UP", true]
	return label


## The flashed message while it shows (2 s), else "".
func hint_line() -> String:
	return message if message != "" and now - message_t < 2.0 else ""


## A short message over the floor row (a refused or unsaved action), with the close click.
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
		for k: int in opening.cards.size():
			if opening.landed(k, tuning):
				count += 1
	return count


## The boosters on show, left to right (by bay).
func shown_boosters() -> Array[BoosterOpening]:
	var shown: Array[BoosterOpening] = boosters.duplicate()
	shown.sort_custom(func(a: BoosterOpening, z: BoosterOpening) -> bool: return a.bay < z.bay)
	return shown


## A page-1 key from the board (1-3, R, Esc; the swap window's 1-2, R and Esc while it shows);
## true when it was used.
func handle_key(keycode: Key) -> bool:
	var number: int = [KEY_1, KEY_2, KEY_3].find(keycode)
	var used: bool = false
	if swap.visible():
		used = _swap_key(keycode, number)
	elif overlay or not StartBoardActions.hit_allowed(actions, _key_hit(keycode, number)):
		used = false
	elif keycode == KEY_ESCAPE:
		if restock_armed:
			cancel_restock("ui_back")
			used = true
	elif keycode == KEY_R and BoosterChromeDraw.key_shown(self):
		used = counter.arm_restock()
	elif number >= 0:
		used = _key_booster(number)
	return used


## A key while the swap window shows: Esc (a held card home, else the window shut), 1-2 (its
## boosters), R (RESET); every other key is held back from the page under it.
func _swap_key(keycode: Key, number: int) -> bool:
	var part: StringName = &""
	if number >= 0:
		part = TutorialAnchors.indexed(TutorialAnchors.SWAP_BOOSTER, number)
	elif keycode == KEY_R:
		part = TutorialAnchors.SWAP_RESET
	var used: bool = true
	if not swap.active or not StartBoardActions.swap_allowed(actions, part):
		used = true
	elif keycode == KEY_ESCAPE:
		used = swap.escape()
	elif number >= 0:
		used = swap.open_booster(number, "key")
	elif keycode == KEY_R:
		used = swap.reset()
	return used


## The hit a page-1 key acts as, for the tutorial's gate (&"": never asked: Esc, unused keys): R
## the RESTOCK key, 1-3 the booster shown at that place (its return, or its bay's pick).
func _key_hit(keycode: Key, number: int) -> StringName:
	var id: StringName = &""
	if keycode == KEY_R:
		id = TutorialAnchors.RESTOCK
	elif number >= 0:
		var shown: Array[BoosterOpening] = shown_boosters()
		if number < shown.size():
			id = TutorialAnchors.booster(shown[number].index)
			if restock_armed:
				id = TutorialAnchors.indexed(TutorialAnchors.RCARDS, shown[number].index)
	return id


## Number key `number` on the boosters shown (left to right): the booster's RESTOCK while armed,
## else its opening while it waits sealed on the counter.
func _key_booster(number: int) -> bool:
	var shown: Array[BoosterOpening] = shown_boosters()
	if number >= shown.size():
		return false
	var target: BoosterOpening = shown[number]
	if restock_armed:
		return counter.restock(target.index)
	if roulette.busy() or not roulette.landed(target):
		return false
	return openings.open_booster(target.index, "key")


## RESTOCK disarmed (Esc, CANCEL), with `sound`.
func cancel_restock(sound: String) -> void:
	restock_armed = false
	fx.sfx(sound, -6.0)
	StartBoardActions.emit(actions, TutorialEvents.RESTOCK_CANCELLED)


func _gui_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		mouse = (motion.position / ArtPen.UNIT).floor()
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	mouse = (button.position / ArtPen.UNIT).floor()
	accept_event()
	if button.pressed:
		click(mouse)
	elif swap.active:
		swap.release(mouse - Vector2(0, swap.slide()))


## A click at art point `at`: the swap window's while it shows; else a skip (the light, the
## throws), a sealed booster's opening (its pouch), a skip of an opening, else the topmost hit
## under it.
func click(at: Vector2) -> void:
	if swap.visible():
		if swap.active:
			swap.press(at - Vector2(0, swap.slide()))
		return
	if overlay:
		return
	if roulette.skip():
		return
	hits = BoosterPageDraw.hits(self)
	var on_pouch: bool = false
	for entry: Dictionary in hits:
		var id: String = entry.id
		if id.begins_with(TutorialAnchors.BOOSTER) and (entry.rect as Rect2).has_point(at):
			on_pouch = true
	if not on_pouch and openings.boost_all():
		return
	for k: int in range(hits.size() - 1, -1, -1):
		var entry: Dictionary = hits[k]
		if (entry.rect as Rect2).has_point(at):
			var act: Callable = entry.act
			# TITLE is never asked; a hit with nothing to do asks nothing either.
			var id: StringName = StringName(entry.id) if act.is_valid() else &""
			if id == TutorialAnchors.TITLE or StartBoardActions.hit_allowed(actions, id):
				if act.is_valid():
					act.call()
			return
	if restock_armed:
		restock_armed = false
		StartBoardActions.emit(actions, TutorialEvents.RESTOCK_CANCELLED)


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


## Lays the hover tips over this frame's targets (none while tips_blocked, or while the page slides:
## no node is built during the board's page slide).
func _update_tips() -> void:
	if tips_blocked() or position.x != 0.0:
		tips.clear()
	elif swap.visible():
		tips.show_entries(SwapWindowDraw.tip_entries(self))
	else:
		tips.show_entries(BoosterChromeDraw.tip_entries(self))


## Whether no hover tip may show now: the light, a throw, a booster opening (page 1's or the swap
## window's), or in the swap window a held card or its slide.
func tips_blocked() -> bool:
	if run == null:
		return true
	if swap.visible():
		return not swap.active or swap.held != null or swap.slide() != 0.0 or _swap_opening()
	return overlay or roulette.busy() or openings.opening_now()


## Whether one of the swap window's boosters is still opening.
func _swap_opening() -> bool:
	for b: BoosterOpening in swap.boosters:
		if b.state == BoosterOpening.State.OPENING and not b.at_rest(tuning):
			return true
	return false


func is_hovered(id: String) -> bool:
	return hover_id == id
