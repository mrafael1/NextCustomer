class_name BuildPage
extends Control
## YOUR BUILD, page 2 of the opening board (v1.32, the user's pick of 2026-11-13 on mock-up
## docs/art/mockups/start_boosters_v3.html: "I really like mockup"). The staff room: the three
## starter packs lie face up on the bench as real cards (each card behind the front one shows its
## name band); a hovered pack spreads its cards while the others sink behind the bench, and a click
## (or 1-3) picks it with its family stamp. NEW PACKS lives on the deck pile on the left: a click
## (or N) re-deals the packs once a run (keeping a pick), then the pile wears USED. While the
## profile owns a badge pin, the BADGE PINS step comes first and the packs wait under a tape; the
## step wears one pin per slot (or none) and its confirm deals the packs from the deck. The
## corkboard (or P) reopens it later without changing the packs. OPEN STORE (Enter) is lit once a
## pack is picked: the cards gather, turn into items, drop into the cart and the cart rolls out,
## then the board clocks in.
##
## Every rule goes through StartBoardActions (saved at once); the motion is cosmetic, on the
## page's own clock (`now`), which tests and captures step with advance(). Reduced motion shows
## each end state. Drawing is BuildPageDraw's (and PinStepDraw's, StoreFlight's), in art px.

signal store_pressed
signal store_opened(pack: StarterPackDefinition)

const TUNING_PATH := "res://data/balance/start_boosters.tres"
const MAX_STEP := 0.1
## The packs' places on the bench: each stack's x, a spread card's x, the spread's top (art px;
## v1.36: 4 px lower, so a RARE tab clears the strips' plates above it).
const STX: Array[int] = [186, 270, 354]
const SPX: Array[int] = [182, 264, 346]
const SPY := 122
## The deck pile's top left and the bench's top (art px).
const DECK := Vector2i(92, 170)
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

var tuning: StartBoostersTuning
var run: RunState
var profile: ProfileState
var actions: StartBoardActions
var now: float = 0.0
var frozen: bool = false
var rm: bool = false
## The page opened at (page clock).
var page_t: float = -INF
## The packs on the bench: each {pack, deal_at, leave ({} or {t, pack, pos}), sv (sink 0..1)}.
var stacks: Array[Dictionary] = []
var dealt: bool = false
## Until when the deal (or a re-deal) is busy (a click or Enter skips it).
var busy_until: float = -INF
## The spread pack (-1: none) and since when; the pick's slam, NEW PACKS, USED, the deck's hop.
var spread: int = -1
var spread_t: float = -INF
var pick_t: float = -INF
var new_t: float = -INF
var used_t: float = -INF
var deck_hop: float = -INF
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
var order: OrderSheet
## The page's hover tips (the spread pack's cards and their family chips).
var tips: StartTips
var _layers: Array[BuildLayer] = []


func _init() -> void:
	name = "BuildPage"
	size = ShiftStage.SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tuning = load(TUNING_PATH) as StartBoostersTuning
	pins = BuildPins.new(self)
	_add_layer("Room")
	_add_layer("Stacks", _clip("BenchClip"))
	_add_layer("Over")
	_add_layer("Flights", _clip("FlightClip"))
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


func _add_layer(layer_name: String, parent: Control = null) -> void:
	var layer: BuildLayer = BuildLayer.new(self, layer_name)
	(parent if parent != null else self as Control).add_child(layer)
	_layers.append(layer)


## A control clipping its layer to the room above the bench's top (the packs sink behind it).
func _clip(clip_name: String) -> Control:
	var clip: Control = Control.new()
	clip.name = clip_name
	clip.size = Vector2(ShiftStage.SIZE.x, BENCH_Y * ArtPen.UNIT)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	return clip


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
	if fresh:
		stacks.clear()
		dealt = false
	_sync_order()
	cart_n = cart_target()
	if fresh:
		cart_shown = cart_n


## The page opens (from page 1, or on a resumed run): the BADGE PINS step first while the packs
## wait for it, else the packs deal from the deck.
func enter() -> void:
	page_t = now
	pins_open = false
	spread = -1
	flight = null
	message = ""
	if packs_held():
		_hold_stacks()
		cart_n = cart_target()
		pins.open(now + (0.0 if rm else tuning.pins_delay_s))
		set_hint("WEAR YOUR BADGE PINS")
		return
	deal_packs(now + (0.0 if rm else tuning.p2_deal_delay_s))


func _hold_stacks() -> void:
	stacks.clear()
	for pack: StarterPackDefinition in run.start_offer.packs:
		stacks.append({"pack": pack, "deal_at": INF, "leave": {}, "sv": 0.0})
	dealt = false


## The packs fly from the deck from `t0`, a pack every p2_pack_gap_s.
func deal_packs(t0: float) -> void:
	stacks.clear()
	for k: int in run.start_offer.packs.size():
		var at: float = t0 + k * tuning.p2_pack_gap_s
		stacks.append({"pack": run.start_offer.packs[k], "deal_at": at, "leave": {}, "sv": 0.0})
	dealt = true
	busy_until = t0 + 0.75
	pick_t = now - 1.0 if picked() >= 0 else -INF
	used_t = now - 1.0 if run.start_setup.packs_redrawn else -INF
	deck_hop = t0
	cart_n = cart_target()
	if not rm:
		for n: int in 9:
			cue(t0 + n * 0.05, sfx.bind("card_place_%d" % (1 + n % 3) if n % 3 else "fan", -10.0))
		cue(t0 + 0.6, sfx.bind("stamp_1", -10.0))
	set_hint("" if picked() >= 0 else "HOVER A PACK, CLICK TO PICK")


## The picked pack's place in the offer (-1: none, also while the packs wait for the BADGE PINS
## step: a good first pick made at the deal stays hidden until the packs deal).
func picked() -> int:
	if run == null or packs_held():
		return -1
	for k: int in run.start_offer.packs.size():
		if run.start_offer.packs[k].id == run.start_setup.picked:
			return k
	return -1


## Whether the packs wait for the BADGE PINS step (the setup's own state).
func packs_held() -> bool:
	return StartSetupRules.pins_pending(run, pins.gate_count())


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
			var pack: StarterPackDefinition = flight.pack
			flight = null
			store_opened.emit(pack)
	_refresh_view()


func _refresh_view() -> void:
	hits = BuildPageDraw.hits(self)
	_update_hover()
	_update_spread()
	# No tip (and no node built) while the page slides in or out.
	if BuildPageDraw.tips_blocked(self) or position.x != 0.0:
		tips.clear()
	else:
		tips.show_entries(BuildPageDraw.tip_entries(self))
	for layer: BuildLayer in _layers:
		layer.queue_redraw()


## The spread follows the pointer; with a pick and no pointer on a pack, the picked pack spreads.
func _update_spread() -> void:
	if run == null:
		return
	var hv: int = hovered_pack() if dealt and not pins_open and flight == null else -1
	var pick: int = picked()
	var target: int = spread
	if pick < 0:
		target = hv
	elif hv >= 0:
		target = hv
	elif now >= busy_until:
		target = pick
	if pick >= 0 and now < busy_until and new_t > -INF and now - new_t < 1.0:
		target = -1
	if target != spread:
		spread = target
		spread_t = now
	var step: float = 1.0 if rm else 1.0 / maxf(tuning.p2_sink_s * 60.0, 1.0)
	for k: int in stacks.size():
		var want: float = 1.0 if spread >= 0 and spread != k else 0.0
		var sv: float = stacks[k].sv
		stacks[k].sv = want if rm else move_toward(sv, want, step)


func hovered_pack() -> int:
	if hover_id.begins_with("pack"):
		return int(hover_id.substr(4))
	return -1


## The top bar's CART target: the regulars, the counted boosters' cards and a picked pack's.
func cart_target() -> int:
	var count: int = run.starter.core_cards.size()
	for booster: StartBooster in run.start_setup.active_boosters():
		count += booster.cards.size()
	if picked() >= 0:
		count += run.start_offer.packs[picked()].cards.size()
	return count


func _sync_order() -> void:
	var view: StartBuildView = StartBuildView.new()
	view.starter = run.starter
	view.start_offer = run.start_offer
	view.balance = run.balance
	view.pins = run.pins
	var shown: int = picked()
	var hv: int = hovered_pack() if dealt and not packs_held() else -1
	var at: int = hv if hv >= 0 else shown
	var pack: StarterPackDefinition = run.start_offer.packs[at] if at >= 0 else null
	order.show_cart(view, pack, at >= 0 and at != shown, packs_held())


## Picks pack `index` (a click, 1-3, or TAKE PACK); false (with its reason on the LED) when it is
## held for the pins, no longer fits, or the save failed.
func pick_pack(index: int, _via: String = "click") -> bool:
	var why: String = _pick_refusal(index)
	if why != "":
		if why != "-":
			flash(why)
		return false
	var pack: StarterPackDefinition = run.start_offer.packs[index]
	var had: bool = picked() >= 0
	if not actions.save_pick.call(pack):
		flash("COULD NOT SAVE YOUR PICK")
		return false
	pick_t = now
	spread = index
	spread_t = now if had else minf(spread_t, now)
	sfx("stamp_loyalty", -4.0)
	sfx("card_pickup_1", -8.0)
	if not rm:
		var stamp: Vector2 = BuildPageDraw.family_stamp_size(pack)
		var cx: float = STX[index] + BoosterArt.CW / 2.0
		BuildPageDraw.add_sparkles(
			self, cx - stamp.x / 2.0, 92 - stamp.y / 2.0, stamp.x, stamp.y, now + 0.08, 0.05
		)
	if not had:
		cart_punch_s = 1.22
		for i: int in 3:
			cue(now + i * 0.06, sfx.bind("slot_tick", -8.0))
	cart_n = cart_target()
	cue(now + 0.3, sfx.bind("armed", -6.0))
	set_hint("")
	_sync_order()
	return true


## NEW PACKS (the deck pile, N): the packs not picked re-deal once a run.
func new_packs() -> bool:
	var why: String = _new_packs_refusal()
	if why == "skip":
		_skip_deal()
		return true
	if why != "":
		if why != "-":
			flash(why)
		return false
	var before: Array[StarterPackDefinition] = run.start_offer.packs.duplicate()
	if not actions.new_packs.call():
		flash("COULD NOT SAVE NEW PACKS")
		return false
	var keep: int = picked()
	new_t = now
	used_t = now + 0.2
	deck_hop = now + 0.45
	for k: int in run.start_offer.packs.size():
		var pack: StarterPackDefinition = run.start_offer.packs[k]
		if k == keep or (k < before.size() and before[k] == pack):
			continue
		var old: StarterPackDefinition = before[k] if k < before.size() else null
		var leave: Dictionary = {}
		if not rm and old != null:
			leave = {
				"t": now, "pack": old, "pos": BuildPageDraw.rest_positions_in(k, old, run.balance)
			}
		var at: float = now + (0.0 if rm else tuning.new_packs_deal_s + k * tuning.p2_pack_gap_s)
		stacks[k] = {"pack": pack, "deal_at": at, "leave": leave, "sv": 0.0}
		if not rm:
			for j: int in 3:
				var n: int = k * 3 + j
				cue(
					at + j * 0.05,
					sfx.bind("card_place_%d" % (1 + n % 3) if n % 3 else "fan", -10.0)
				)
	busy_until = now + (0.0 if rm else 1.0)
	sfx("shuffle", -6.0)
	cue(now + 0.2, sfx.bind("stamp_notice", -4.0))
	cart_n = cart_target()
	_sync_order()
	return true


## The deal (or a re-deal) lands at once.
func _skip_deal() -> void:
	for stack: Dictionary in stacks:
		stack.deal_at = minf(stack.deal_at as float, now - 2.0)
		stack.leave = {}
	busy_until = now
	cues.clear()


## The primary key (Enter, a click): the pins' confirm, the pins step, a skip, TAKE PACK, or OPEN
## STORE.
func primary(via: String = "key") -> bool:
	var used: bool = true
	if flight != null:
		flight.skip(now)
	elif pins_open:
		used = pins.confirm(via)
	elif packs_held():
		used = pins.open(now)
	elif now < busy_until:
		_skip_deal()
	elif picked() < 0:
		var first: StarterPackDefinition = run.start_offer.first_pick
		if first != null:
			used = pick_pack(run.start_offer.packs.find(first), "open_store")
		else:
			flash("PICK A PACK FIRST")
			used = false
	else:
		used = open_store()
	return used


## OPEN STORE: the flight to the cart (reduced motion: straight to the clock-in).
func open_store() -> bool:
	if flight != null or picked() < 0 or packs_held() or not run.start_setup.all_open():
		return false
	var pack: StarterPackDefinition = run.start_offer.packs[picked()]
	flight = StoreFlight.new(self, pack)
	if rm:
		flight = null
		store_opened.emit(pack)
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


## A page-2 key from the board (1-9, N, P, Esc, Enter, Space); true when used.
func handle_key(keycode: Key) -> bool:
	var number: int = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9].find(keycode)
	var used: bool = false
	if keycode == KEY_ESCAPE:
		used = pins.close()
	elif keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		used = primary("key")
	elif pins_open:
		used = number >= 0 and pins.toggle_at(number)
	elif flight != null:
		used = false
	elif number >= 0 and number < 3:
		used = pick_pack(number, "key")
	elif keycode == KEY_N:
		used = new_packs()
	elif keycode == KEY_P:
		used = pins.open(now)
	return used


## Why pack `index` can't be picked now ("-": silently), or "" when it can. A running deal lands.
func _pick_refusal(index: int) -> String:
	var why: String = ""
	if flight != null or run == null or pins_open:
		why = "-"
	elif index < 0 or index >= run.start_offer.packs.size():
		why = "-"
	elif packs_held():
		why = "PACKS DEAL AFTER PINS"
	else:
		if now < busy_until:
			_skip_deal()
		var pack: StarterPackDefinition = run.start_offer.packs[index]
		var block: StringName = StartSetupRules.pick_block(run, profile, pack, pins.gate_count())
		if picked() == index:
			why = "-"
		elif block == &"copies":
			why = StartTips.COPY_LIMIT_LINE % run.starter.copy_max
		elif block != &"":
			why = "PICK A PACK FIRST"
	return why


## Why NEW PACKS can't be used now ("-": silently; "skip": a running deal lands instead), or "".
func _new_packs_refusal() -> String:
	var why: String = ""
	if flight != null or pins_open or run == null:
		why = "-"
	elif packs_held():
		why = "PACKS DEAL AFTER PINS"
	elif run.start_setup.packs_redrawn:
		why = "NEW PACKS USED"
	elif now < busy_until:
		why = "skip"
	else:
		var block: StringName = StartSetupRules.new_packs_block(run, profile, pins.gate_count())
		if block == &"none":
			why = "NO OTHER PACKS FIT"
		elif block != &"":
			why = "NEW PACKS USED"
	return why


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
			if act.is_valid():
				act.call()
			return


func _update_hover() -> void:
	var found: String = ""
	for k: int in range(hits.size() - 1, -1, -1):
		if (hits[k].rect as Rect2).has_point(mouse):
			found = hits[k].id
			break
	if found != hover_id:
		var was: int = hovered_pack()
		hover_id = found
		if hovered_pack() != was and run != null:
			_sync_order()
	var live: bool = found != "" and not found.begins_with("modal")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if live else Control.CURSOR_ARROW


## ‹ STORE and the YOUR STORE tab: back to page 1.
func press_store() -> void:
	store_pressed.emit()


func is_hovered(id: String) -> bool:
	return hover_id == id
