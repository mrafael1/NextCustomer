class_name RewardMachineView
extends Control
## The RECEIPT REWARDS machine on the shift screen (#77, build spec 4.2; redrawn front-on in v0.50,
## mock-up docs/art/mockups/premium_machine_v1.html). It stands in the store, on the back wall of
## the stage's world at ShiftStage.MACHINE_WALL_RECT, half size, all run. Between visits it is idle
## (show_idle): dimmed (MachineDim), its keys unlit, its display blank, its stock window shut, and
## it takes no click (mouse_behavior_recursive), so a click on it reaches the wall. A visit
## (open_visit) drives the StoreCamera (`camera`) and the stage's fore from its plan: a TICKET visit
## glides the camera to the machine at 2x, where its cabinet shows at ShiftStage.MACHINE_RECT at a
## net scale of 1, and lights it (set_lit). Back to front: the cabinet (MachineCabinet: body, trim,
## window frame, key plate, kick panel with the bonus ticket's dock), the marquee (MachineHead), the
## display (MachineDisplay, with BIN IT) and the receipt slot (SlotPlate) on one strip, the stock
## window (StockWindow: sealed tickets over each lit chute's odds), the chute keys on the key plate
## (ChuteKey, in `key_bay`, only the visit's pair standing), the tray (MachineTray, its push bar
## confirming the chosen chute), the dim veil (MachineDim); then MachineLayers': the receipt feed
## (ReceiptFeed, with the bonus ticket) and the cart drawer (CartDrawer) on the hud under the top
## bar, the prize row's veil (PrizeRow) and the prize's flight (MachineFlyer) over everything, and
## the prize tickets (PrizeTicket) with KEEP ONE over all of them.
##
## CLASSIC AND PREMIUM (v0.50, dressing A): a Normal visit shows RECEIPT REWARDS with NEW ITEMS and
## COUPONS; a BOOSTED visit (after shifts 3/5/7) turns the same machine PREMIUM after its receipt
## is read (MachinePlan.premium_at, MachineLook) and it stays so for the visit: LOYALTY (the
## REGISTER chute's name wherever the player sees it) and UPGRADES. The BONUS visit after it is
## BOOSTED too (v0.53) and opens PREMIUM (MachinePlan.premium_held). A STAMP DAY visit shows its
## LOYALTY key on the classic machine.
##
## It only displays what RunState and RewardMachine give it (chute_info, prizes, preview,
## can_bin, current_visit) and reports the player's choices: chute_confirmed, prize_picked and
## binned (the top bar's Cart opens the deck view during a visit, MachineFlow.show_deck).
## MachineFlow sequences the visits.
##
## CHOOSING A CHUTE: resting the pointer on a lit key lights its stock window column brighter
## (hover_key; `odds_opened` is logged: the player looked at that chute's odds). A press
## (press_key) drops the key, lights its LED and clicks; the tray's push bar lights up with the
## chute's name (PUSH TO CONFIRM, v0.53: the display keeps its lines); a press on another key moves
## the choice there (the first pops back up), on the same key lets it up. Only the push bar sends
## chute_confirmed; the chosen key stays down through the draw.
##
## THE PRIZES' EFFECTS (v0.53): resting the pointer on a revealed prize ticket opens `popup`
## (PrizePopup, the scan popup the offers used) with what it does in full, beside the ticket.
##
## THE CLOCK AND THE HOOKS:
## - `plan` is the visit's MachinePlan (presentation/machine_plan.gd: every beat's time, from
##   data/balance/machine_tempo.tres) and `clock` the time on it, in seconds. open_visit() starts
##   a plan at 0 (a resume at its wait point, `plan.resumed`); show_draw() adds the draw,
##   land() the landing.
## - The clock runs (game time) up to the next wait point and holds there: CHOOSE (keys lit),
##   PICK (prizes revealed), END (landing over: `finished`). At CHOOSE and PICK the machine arms
##   (accepts a key or a prize) once the mouse is up, so a click meant for the count-up never
##   chooses; arming emits beat &"armed".
## - Every frame the machine calls frame(clock) on each part; a part's frame(t) reads only
##   `view.plan` and `t`. show_at(t) renders every part at `t` (tests, captures), at most at the
##   current wait point (reaching END there still sends `finished`).
## - `idle_time` is the one free-running time (seconds since the visit opened; it goes on at the
##   wait points, where the clock holds, and stays 0 under reduced motion): a part's continuous
##   effects (the chasing bulbs, the keys' glow, the tickets' sparkles and the sunburst's turn)
##   read it in frame(t), never Time or delta.
## - `beat(beat_name, t0)` fires once per beat of the plan as the clock passes it, `t0` being the
##   beat's plan time: glide, snap, feed, read, premium, lights, draw, packed, reveal_0..reveal_2,
##   pick, land, bonus (a BONUS visit's start), stamp_day (STAMP DAY's start), plus armed. Beats
##   before a resume's start never fire.
## - A tap (a click or Space, PressReader) during a non-interactive beat fast-forwards to the next
##   wait point (`skipped`, then fast_forward()): the beats on the way still fire, in order, with
##   `skipping` true: a listener then shows its end state, with no sound and no motion.
## - Each part has setup(view), called once here as it is built (connect to `beat` there), and
##   frame(t). The screen's pieces a part may use: `receipt` (the stage's receipt), `stage`,
##   `loyalty_card`, `sfx`, `music`, set by MachineFlow, and the receipt's lines for a copy of it
##   (`receipt_header`, `receipt_names`, `receipt_upgrades`, `receipt_inspections`; the shift
##   end's `shift_total`, `shift_quota`, `shift_notice`; the ScoreResult is `run.last_result`).
##   `reduced_motion` (a Callable) is read once per visit into `plan.reduced_motion`.
## - `landing` is the pick's MachineLanding while its landing plays (null otherwise, and for a
##   bin): the loyalty box (`box_index`), the cart counts (`cart_before`, `cart_after`), the copy
##   added (`added`) and the one swapped out (`replaced`), the upgraded copies (`upgraded`).
## - `plain_landing`: while true MachineFlow plays the plain landing at beat &"land" (the loyalty
##   card's stamp, the place/stamp sound); MachineFlyer sets it false from its setup() and plays
##   its own. The top bar (Cart count, loyalty card) is refreshed at &"land" either way.

signal chute_confirmed(chute: int)
signal prize_picked(index: int)
signal binned
## The visit's landing is over (the clock reached END): the next visit or shift may start.
signal finished
## A moment of the visit (see above): `t0` is its time on `plan`, in seconds.
signal beat(beat_name: StringName, t0: float)
## The player tapped to fast-forward (MachineFlow logs presentation_skipped).
signal skipped
## The player looked at a chute's odds (its key hovered): MachineFlow logs the order.
signal odds_opened(chute: int)
## The prize tickets were built (the scanner watches the machine's items: none since v0.50).
signal items_shown

const SIZE := MachineCabinet.SIZE
const TUNING_PATH := "res://data/balance/machine_tempo.tres"
const HEAD_POSITION := Vector2(-20, -56)
const DISPLAY_POSITION := Vector2(20, 12)
const SLOT_POSITION := Vector2(320, 12)
const WINDOW_POSITION := Vector2(20, 76)
## The key plate's inside, where the keys stand (it clips the pair that is sunk out of sight), and
## each key's place in it: chutes 0 and 2 on the left, 1 and 3 on the right.
const KEY_BAY_RECT := Rect2(14, 298, 420, 108)
const KEY_X: Array[float] = [10.0, 218.0]
const KEY_Y := 6.0
const TRAY_POSITION := Vector2(20, 420)
## A beat planned at the clock's time when its segment starts (the pick press) still fires.
const SAME_TIME := 0.000001
const SPEND_LINE := "SPEND €%d ✓ THANK YOU!"
## The chute wait's sub line (build spec 4.3's resume table) and a BONUS visit's lines there
## (#77 machine v2: "BONUS TICKET" / "inspection passed · 1 more prize · pick a chute").
const CHOOSE_SUB := "pick a chute"
## A BOOSTED visit (v0.50: the PREMIUM machine): the chute wait's sub line.
const BOOSTED_SUB := "premium · loyalty or upgrades · pick a chute"
const BONUS_TITLE := MachineDisplay.BONUS_TICKET
const BONUS_SUB := "%s · 1 more prize · pick a chute"
## A pressed key's title sub line: what the chute does (on a BONUS or BOOSTED visit the visit's
## word in its place, v0.50: the strip beside CONFIRM is 160 px and the key already says it), the
## prizes.
const TITLE_SUB := "%s · %d prizes, keep 1"
const TITLE_BONUS := "bonus ticket"
const TITLE_BOOSTED := "premium"
## A pressed key's click.
const PRESS_SOUND := "ui_click"
## A BONUS visit's head stamp under-line (an extra shift's: "shift n").
const BONUS_UNDER := "INSPECTION PASSED"
## The pick wait's sub line when the cart is full (a pick swaps a card out).
const CART_FULL_TEXT := "CART FULL: SWAP 1 OUT"

var cabinet: MachineCabinet
var head: MachineHead
var slot_plate: SlotPlate
var display: MachineDisplay
var stock: StockWindow
var tray: MachineTray
## The key plate's inside: the keys stand in it.
var key_bay: Control
var keys: Array[ChuteKey] = []
var tickets: Array[PrizeTicket] = []
## The hovered prize's popup, on the card layer (PrizePopup).
var popup: PrizePopup
## MachineLayers': the feed layer (on the hud), the stage layer and the card layer.
var feed_layer: Control
var stage_layer: Control
var card_layer: Control
var receipt_feed: ReceiptFeed
var cart_drawer: CartDrawer
var prize_row: PrizeRow
var flyer: MachineFlyer
## Dims the machine between visits (set_lit).
var veil: MachineDim
var tuning: MachineTuning
## The store's camera and the stage's fore follow the visit's plan (null: none, as in some tests).
var camera: StoreCamera
## The visit's timeline and the time on it (seconds); null while closed.
var plan: MachinePlan
var clock: float = 0.0
## Seconds since the visit opened, going on at the wait points (0 under reduced motion).
var idle_time: float = 0.0
## The pick being landed (land()), or null (none, or a bin).
var landing: MachineLanding
## True while beats fire during a fast-forward or a jump.
var skipping: bool = false
## The run shown (open_visit), or null.
var run: RunState
## The screen's pieces, for the parts (MachineFlow sets them; see the header).
var receipt: Control
var stage: Control
var loyalty_card: LoyaltyCard
var sfx: Sfx
var music: MusicService
var reduced_motion: Callable = func() -> bool: return false
## The receipt's lines as the count-up printed them, for a copy of it (MachineFlow sets them).
var receipt_header: PackedStringArray = PackedStringArray()
var receipt_names: PackedStringArray = PackedStringArray()
var receipt_upgrades: PackedStringArray = PackedStringArray()
var receipt_inspections: PackedStringArray = PackedStringArray()
var shift_total: int = 0
var shift_quota: int = 0
var shift_notice: String = ""
var plain_landing: bool = true
## CONFIRM › played the confirm's sound for this visit (MachineSounds then doesn't again).
var confirm_played: bool = false
var _armed: bool = false
## The pressed key's chute at the chute wait and through its draw (-1: none).
var _pressed: int = -1
## The hovered key's chute (-1: none) and the chute whose odds were last logged.
var _hovered: int = -1
## The wait point (MachinePlan.WaitPoint) the clock runs to, the last time beats fired up to, and
## whether `finished` was sent for this visit.
var _until: int = MachinePlan.WaitPoint.CHOOSE
var _fired: float = -1.0
var _ended: bool = true
var _presses: PressReader
## The LEGENDARY landing's shake now (stage px), as applied to the stage.
var _shake: Vector2 = Vector2.ZERO


func _init() -> void:
	name = "RewardMachineView"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tuning = load(TUNING_PATH) as MachineTuning
	_presses = PressReader.new()
	add_child(_presses)
	_presses.tapped.connect(_on_tapped)
	cabinet = _add(MachineCabinet.new(), Vector2.ZERO) as MachineCabinet
	head = _add(MachineHead.new(), HEAD_POSITION) as MachineHead
	display = _add(MachineDisplay.new(), DISPLAY_POSITION) as MachineDisplay
	display.bin_pressed.connect(_on_bin_pressed)
	slot_plate = _add(SlotPlate.new(), SLOT_POSITION) as SlotPlate
	stock = _add(StockWindow.new(), WINDOW_POSITION) as StockWindow
	key_bay = Control.new()
	key_bay.name = "KeyBay"
	key_bay.position = KEY_BAY_RECT.position
	key_bay.size = KEY_BAY_RECT.size
	key_bay.clip_contents = true
	key_bay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(key_bay)
	for chute: int in RewardMachine.CHUTES:
		var at: Vector2 = Vector2(KEY_X[chute % 2], KEY_Y)
		var key: ChuteKey = _add(ChuteKey.new(chute), at, key_bay) as ChuteKey
		key.hovered.connect(_on_key_hovered)
		key.unhovered.connect(_on_key_unhovered)
		key.pressed.connect(press_key)
		keys.append(key)
	tray = _add(MachineTray.new(), TRAY_POSITION) as MachineTray
	tray.confirm_pressed.connect(_on_confirmed)
	feed_layer = MachineLayers.make("MachineFeedLayer", false)
	add_child(feed_layer)
	visibility_changed.connect(func() -> void: feed_layer.visible = visible)
	stage_layer = MachineLayers.make("MachineStageLayer", true)
	add_child(stage_layer)
	receipt_feed = _add(ReceiptFeed.new(), Vector2.ZERO, feed_layer) as ReceiptFeed
	cart_drawer = _add(CartDrawer.new(), Vector2.ZERO, feed_layer) as CartDrawer
	prize_row = _add(PrizeRow.new(), Vector2.ZERO, stage_layer) as PrizeRow
	flyer = _add(MachineFlyer.new(), Vector2.ZERO, stage_layer) as MachineFlyer
	veil = MachineDim.new()
	add_child(veil)
	card_layer = MachineLayers.make("MachineCardLayer", true)
	card_layer.size = SIZE
	add_child(card_layer)
	card_layer.add_child(prize_row.keep_label())
	prize_row.place_keep()
	popup = PrizePopup.new()
	card_layer.add_child(popup)
	MachineDim.idle_mouse(self, true)
	set_lit(0.0)
	_place_keys(MachineLook.new())


func _process(delta: float) -> void:
	if not visible or plan == null:
		return
	if not plan.reduced_motion:
		idle_time += delta
	if not _at_wait():
		var showing: MachinePlan = plan
		_run_to(clock + delta)
		if plan != showing or plan == null or not visible:
			return
	_frame()
	_arm_when_released()


## Opens the machine on `run_state`'s current visit, on `stage_control` (the receipt the visit was
## paid with is `receipt_source`'s): a new plan from 0, or `resumed` at its wait point (no
## replay). A visit waiting for its chute shows its pair of keys (lit, or shut: CARD FULL or
## NOTHING TO IMPROVE, from chute_info) and the lit chutes' odds in the stock window; one waiting
## for its pick (a STAMP DAY, or a resume at MACHINE_PICK) shows its prizes too (show_draw). A
## BOOSTED visit's plan turns the machine PREMIUM.
func open_visit(
	run_state: RunState, receipt_source: Control, stage_control: Control, resumed: bool
) -> void:
	_set_shake(Vector2.ZERO)
	run = run_state
	stage = stage_control
	receipt = receipt_source
	visible = true
	MachineDim.idle_mouse(self, false)
	if resumed and is_instance_valid(receipt):
		receipt.visible = false  # It was fed before the save.
	landing = null
	_disarm()
	_hide_odds()
	_release()
	_clear_tickets()
	var visit: MachineVisit = run.machine.current_visit()
	var kind: int = visit.kind if visit != null else MachineVisit.Kind.TICKET
	# A TICKET visit's `why` is empty: the shift's record says whether it passed an inspection.
	var inspected: bool = (
		(visit != null and not visit.why.is_empty())
		or (not run.history.is_empty() and run.history[-1].inspection != null)
	)
	var stub: bool = run.machine.pending_kinds().has(MachineVisit.Kind.BONUS)
	var premium: bool = run.machine.is_boosted()
	_start(
		MachinePlan.new(
			tuning, kind, reduced_motion.call(), inspected, stub, premium, _ticket_was_premium()
		)
	)
	_show_head(kind, visit)
	_show_keys(run.phase == RunState.Phase.MACHINE_PICK)
	if run.phase == RunState.Phase.MACHINE_PICK:
		show_draw(run, resumed)
		return
	if resumed:
		_resume(MachinePlan.WaitPoint.CHOOSE)
	display.set_bin(false, false)
	if kind == MachineVisit.Kind.BONUS:
		display.show_message(BONUS_TITLE, BONUS_SUB % display.why_words())
	elif premium:
		display.show_message(SPEND_LINE % run.history[-1].total, BOOSTED_SUB)
	else:
		display.show_message(SPEND_LINE % run.history[-1].total, CHOOSE_SUB)
	_place()
	_frame()


## The visit's prizes as tickets (reveal order), the pick prompt and BIN IT when it can be binned.
## The clock goes on from the chute wait through the draw and the tickets' landings to the pick
## wait (`resumed`: it starts there).
func show_draw(run_state: RunState, resumed: bool = false) -> void:
	run = run_state
	visible = true
	_disarm()
	_hide_odds()
	tray.clear_confirm()
	_clear_tickets()
	var visit: MachineVisit = run.machine.current_visit()
	var prizes: Array[MachinePrize] = run.machine.prizes()
	if plan == null:
		_start(
			MachinePlan.new(
				tuning,
				visit.kind,
				reduced_motion.call(),
				true,
				false,
				visit.boosted,
				_ticket_was_premium()
			)
		)
	if not resumed and clock < plan.choose_at:
		_jump_to(plan.choose_at)  # Chosen before the keys lit (debug, tests).
	var rarities: Array[int] = []
	for prize: MachinePrize in prizes:
		rarities.append(prize.rarity)
	plan.set_draw(rarities)
	_until = MachinePlan.WaitPoint.PICK
	_fired = minf(_fired, clock - SAME_TIME)
	if resumed:
		_resume(MachinePlan.WaitPoint.PICK)
	_show_head(visit.kind, visit)
	_show_keys(true)
	# The chosen key stays down through the draw (none for STAMP DAY's own pick).
	_press_only(visit.chute if visit.kind != MachineVisit.Kind.STAMP_DAY else -1)
	for index: int in range(prizes.size()):
		var ticket: PrizeTicket = PrizeTicket.new(
			index, prizes[index], run.machine.preview(run, index), run
		)
		ticket.rest = PrizeRow.card_rect(index, prizes.size()).position
		ticket.launch = PrizeRow.LAUNCH
		ticket.position = ticket.launch
		ticket.clicked.connect(pick)
		ticket.hovered.connect(_on_ticket_hovered)
		ticket.unhovered.connect(_on_ticket_unhovered)
		ticket.setup(self)
		card_layer.add_child(ticket)
		tickets.append(ticket)
	var can_bin: bool = run.machine.can_bin()
	display.set_bin(can_bin, false)
	display.show_message(pick_prompt(prizes.size(), run), _pick_sub(run, can_bin))
	items_shown.emit()
	_read_presses()
	_frame()


## A pick's landing (`picked`, kept as `landing` for the parts), or the draw binned (null): the
## landing's word ("NEW IN CART ✓", "UPGRADED ✓", "STAMPED ✓"); the clock runs to END, then
## `finished`.
func land(picked: MachineLanding) -> void:
	_disarm()
	_hide_odds()
	popup.close_popup()
	if plan == null:
		return
	landing = picked
	if clock < plan.wait_time(MachinePlan.WaitPoint.PICK):
		_jump_to(plan.wait_time(MachinePlan.WaitPoint.PICK))  # Picked before it armed (debug).
	var next_kind: int = MachinePlan.NO_VISIT
	if RunState.MACHINE_PHASES.has(run.phase) and run.machine.current_visit() != null:
		next_kind = run.machine.current_visit().kind
	if picked == null:
		plan.set_landing(MachinePlan.Landing.BIN, 1, next_kind)
	else:
		plan.set_landing(_landing_kind(picked), picked.upgraded.size(), next_kind)
		display.show_message(
			_landing_word(picked), "SEE YOU NEXT SHIFT" if picked.last_of_shift else ""
		)
	_until = MachinePlan.WaitPoint.END
	_fired = minf(_fired, clock - SAME_TIME)
	_read_presses()
	_frame()


## Ends the visit: the prizes go, the clock stops and the machine is idle again (show_idle's look,
## with the run it showed). The camera and the fore stay where they are (the glide back moves
## them: MachineFlow).
func close() -> void:
	var shown: RunState = run
	visible = true
	_hide_odds()
	popup.close_popup()
	_release()
	_clear_tickets()
	_presses.end()
	_set_shake(Vector2.ZERO)
	run = null
	plan = null
	landing = null
	_ended = true
	_disarm()
	MachineDim.idle_mouse(self, true)
	MachineDim.rest_parts(self, shown)
	_frame()


## The idle machine on the wall (between visits, and in planning): no visit, its sign classic,
## its keys unlit with nothing pressed, its display blank, its window shut, the slot's lamp off,
## no dock, no prizes; it takes no click. Its dimming is set_lit's.
func show_idle(run_state: RunState) -> void:
	close()
	MachineDim.rest_parts(self, run_state)


## Whether a visit is under way (opened and not closed).
func is_open() -> bool:
	return plan != null


## How lit the machine looks (`p`: 0 dim on the wall .. 1 lit, as at a visit; MachineDim).
func set_lit(p: float) -> void:
	veil.set_lit(self, p)


## How lit the machine is now (0 .. 1).
func lit_level() -> float:
	return veil.lit


## Jumps the clock to the next wait point (the player's tap, or the debug skip): the beats on
## the way fire with `skipping` true; at END the visit finishes (`finished`, at once).
func fast_forward() -> void:
	if plan == null or _at_wait():
		return
	_jump_to(plan.wait_time(_until))
	if plan != null and visible:
		_frame()


## Renders every part at `t` on the plan, without firing beats or moving the clock's wait point
## (tests and screen captures; build spec 4.3's `?at=` seam). `t` is held at the current wait
## point: it never passes it, and reaching END still sends `finished`.
func show_at(t: float) -> void:
	if plan == null:
		return
	var target: float = plan.wait_time(_until)
	clock = minf(t, target) if target >= 0.0 else t
	_fired = maxf(_fired, clock)
	_frame()
	if not _at_wait():
		return
	_presses.end()
	if _until == MachinePlan.WaitPoint.END and not _ended:
		_ended = true
		finished.emit()


## A press on `chute`'s key (armed, at the chute wait): a lit key drops, lights and clicks
## (PRESS_SOUND) and the tray's push bar offers it (PUSH TO CONFIRM); a press on another key moves
## the choice (the first pops back up, silently); the same key again lets it up and the bar goes
## dark. A shut chute's key is refused (denied) with its reason on the display for a moment.
func press_key(chute: int) -> void:
	if run == null or not _armed or run.phase != RunState.Phase.MACHINE_CHOOSE:
		return
	var info: MachineChuteInfo = run.machine.chute_info(run, chute)
	if info.state != RewardMachine.ChuteState.OPEN:
		Sfx.play_at(self, "denied")
		var why: String = keys[chute].sub_text()
		if info.state == RewardMachine.ChuteState.UNLIT:  # A PREMIUM visit's classic keys show none.
			why = ChuteKey.unlit_text(chute, info.opens_after_shift, false)
		display.show_denied(ChuteKey.NAMES[chute], why)
		return
	if _pressed == chute:
		_release()
		_frame()
		return
	_press_only(chute)
	Sfx.play_at(self, PRESS_SOUND)
	tray.offer_confirm(ChuteKey.NAMES[chute], title_sub(chute))
	_frame()


## The pointer rests on `chute`'s key: while the visit waits for its chute and the key is lit,
## its stock window column glows brighter and the look at its odds is logged (odds_opened).
func hover_key(chute: int) -> void:
	if run == null or not _armed:
		return
	var choosing: bool = run.phase == RunState.Phase.MACHINE_CHOOSE
	var info: MachineChuteInfo = run.machine.chute_info(run, chute)
	if choosing and info.state == RewardMachine.ChuteState.OPEN:
		_hovered = chute
		stock.set_hovered(chute)
		odds_opened.emit(chute)


## The hovered key's chute whose odds glow (-1: none).
func hovered_chute() -> int:
	return _hovered


## The pressed key's chute (-1: none).
func pressed_chute() -> int:
	return _pressed


## A pressed key's line under the push bar: "<what it does> · 3 prizes, keep 1" (a BONUS visit:
## "bonus ticket · 3 prizes, keep 1"; a BOOSTED one: "premium · 3 prizes, keep 1").
func title_sub(chute: int) -> String:
	var visit: MachineVisit = run.machine.current_visit() if run != null else null
	var lead: String = ChuteKey.SUBS[chute].to_lower()
	if visit != null and visit.kind == MachineVisit.Kind.BONUS:
		lead = TITLE_BONUS
	elif visit != null and visit.boosted:
		lead = TITLE_BOOSTED
	var prizes: int = run.machine.machine.prizes_per_visit if run != null else 3
	return TITLE_SUB % [lead, prizes]


## Picks the prize of ticket `index` (armed only).
func pick(index: int) -> void:
	if _armed and run != null and run.phase == RunState.Phase.MACHINE_PICK:
		prize_picked.emit(index)


## Whether the clock holds at its wait point (the chute wait, the pick wait or the end).
func is_waiting() -> bool:
	return plan != null and _at_wait()


## Whether a key or a prize can be clicked yet (the clock waits and the mouse was released).
func is_armed() -> bool:
	return visible and _armed


## The machine's items for the scanner: none since v0.50 (a ticket shows its prize's rule in full,
## so a prize is never scanned).
func items() -> Array[ItemView]:
	return []


## Whether the scanner may read the machine's items: never (items() is empty).
func can_scan() -> bool:
	return false


## The pick prompt: "PICK 1", or "PICK 1 · ONLY n IN STOCK" for a short draw; STAMP DAY's
## "PICK 1 STAMP".
static func pick_prompt(count: int, run_state: RunState) -> String:
	var visit: MachineVisit = run_state.machine.current_visit()
	if visit != null and visit.kind == MachineVisit.Kind.STAMP_DAY:
		return "PICK 1 STAMP"
	if count < run_state.machine.machine.prizes_per_visit:
		return "PICK 1 · ONLY %d IN STOCK" % count
	return "PICK 1"


## Places `control` (a part's Label or Button, often built before the machine is in the tree)
## at `rect`. Outside the tree a Control measures its text with the default theme (its overrides
## reach its theme cache only with NOTIFICATION_THEME_CHANGED, which the tree sends), so a box set
## then grows to that larger size and keeps it, its centred text off centre: the theme is applied
## first.
static func fit(control: Control, rect: Rect2) -> void:
	control.notification(Control.NOTIFICATION_THEME_CHANGED)
	control.position = rect.position
	control.size = rect.size


## The machine's plain plates: `colour` with a 2 px ink border.
static func plate_style(colour: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = Palette.INK
	style.set_border_width_all(2)
	return style


## Places `part` at `at`, hooks it (its setup(view)) and adds it to `parent` (null: the machine).
func _add(part: Control, at: Vector2, parent: Node = null) -> Control:
	part.position = at
	part.call(&"setup", self)
	(parent if parent != null else self).add_child(part)
	return part


## Every part at the clock.
func _frame() -> void:
	var t: float = clock
	cabinet.frame(t)
	head.frame(t)
	display.frame(t)
	slot_plate.frame(t)
	stock.frame(t)
	_place_keys(MachineLook.at(plan, t))
	for key: ChuteKey in keys:
		key.frame(t)
	tray.frame(t)
	for ticket: PrizeTicket in tickets:
		ticket.frame(t)
	_frame_scene(t)
	_place()
	receipt_feed.frame(t)
	cart_drawer.frame(t)
	prize_row.frame(t)
	flyer.frame(t)
	_set_shake(MachineLayers.legendary_shake(plan, t))
	_place()


## Stands the visit's pair of keys on the plate (MachineLook: the classic pair, the loyalty pair,
## or both moving through the premium transform); a pair sunk out of sight is hidden.
func _place_keys(look: MachineLook) -> void:
	for key: ChuteKey in keys:
		var up: float = look.pair_up(ChuteKey.is_gold(key.chute))
		key.position.y = KEY_Y + MachineArt.snap((1.0 - up) * (ChuteKey.SIZE.y + KEY_Y * 2.0))
		key.visible = up > 0.0


## The store around the visit at `t`: the camera's glide and the reduced-motion cut's fade, the
## stage's fore dropping out of frame, the machine lighting up (none while idle).
func _frame_scene(t: float) -> void:
	if plan == null:
		return
	var progress: float = plan.camera_at(t)
	if camera != null:
		camera.set_view(progress)
		camera.set_fade(plan.fade_at(t))
	var shown_stage: ShiftStage = stage as ShiftStage
	if shown_stage != null:
		var e: float = StoreCamera.ease_in_out(progress)
		shown_stage.set_fore_drop(e, plan.reduced_motion, tuning.fore_drop_px)
	set_lit(plan.lit_at(t))


## The card layer on the machine's transform; the feed layer on the stage's hud and the stage
## layer over it: stage coordinates, at 1:1 whatever the camera does.
func _place() -> void:
	MachineLayers.follow(card_layer, self)
	if not is_instance_valid(stage):
		return
	MachineLayers.home(feed_layer, stage, visible)
	var xform: Transform2D = stage.get_global_transform()
	stage_layer.position = xform.origin
	stage_layer.scale = xform.get_scale()
	stage_layer.size = stage.size


## The feed layer lives on the stage's hud: it goes with the machine.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(feed_layer):
		MachineLayers.release(feed_layer, self)


## Shakes the whole stage by `shake` (stage px): the hud and the stage layer with the stage
## (_place), the zoomed world with the camera. Zero puts them back.
func _set_shake(shake: Vector2) -> void:
	if shake == _shake:
		return
	if is_instance_valid(stage):
		stage.position += (shake - _shake) * stage.scale
	if camera != null:
		camera.set_shake(shake)
	_shake = shake


func _start(visit_plan: MachinePlan) -> void:
	plan = visit_plan
	confirm_played = false
	clock = 0.0
	idle_time = 0.0
	_fired = -1.0
	_ended = false
	_until = MachinePlan.WaitPoint.CHOOSE
	_read_presses()


## Positions the plan at `point` for a resume: nothing before it fires.
func _resume(point: int) -> void:
	plan = plan.resume_at(point)
	clock = plan.start
	_fired = clock
	_presses.end()


## Runs the clock to `t`, at most to the wait point, firing the beats it passes; at END the
## visit finishes.
func _run_to(t: float) -> void:
	var target: float = plan.wait_time(_until)
	if target < 0.0:
		return
	var showing: MachinePlan = plan
	clock = maxf(clock, minf(t, target))
	for beat_name: StringName in plan.beats_between(_fired, clock):
		beat.emit(beat_name, plan.beat_time(beat_name))
		if plan != showing:
			return
	_fired = maxf(_fired, clock)
	if clock < target:
		return
	_presses.end()
	if _until == MachinePlan.WaitPoint.END and not _ended:
		_ended = true
		finished.emit()


## Runs the clock straight to `t` (beats fire with `skipping` true).
func _jump_to(t: float) -> void:
	skipping = true
	_run_to(t)
	skipping = false


func _at_wait() -> bool:
	var target: float = plan.wait_time(_until)
	return target >= 0.0 and clock >= target


## Reads taps (fast-forward) while the clock runs.
func _read_presses() -> void:
	if plan != null and not _at_wait():
		_presses.begin()
	else:
		_presses.end()


func _arm_when_released() -> void:
	if _armed or _until == MachinePlan.WaitPoint.END or not _at_wait():
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	_armed = true
	display.set_bin(display.bin_offered(), true)
	beat.emit(&"armed", clock)
	for key: ChuteKey in keys:
		if key.is_hovered() and key.visible:
			hover_key(key.chute)


func _on_tapped(_now_ms: int) -> void:
	if plan == null or _at_wait() or not visible:
		return
	skipped.emit()
	fast_forward()


static func _landing_kind(picked: MachineLanding) -> int:
	match picked.prize.kind:
		MachinePrize.Kind.UPGRADE:
			return MachinePlan.Landing.UPGRADE
		MachinePrize.Kind.REGISTER:
			return MachinePlan.Landing.REGISTER
	return MachinePlan.Landing.NEW_CARD


static func _landing_word(picked: MachineLanding) -> String:
	match picked.prize.kind:
		MachinePrize.Kind.UPGRADE:
			if picked.upgraded.is_empty():
				return "UPGRADED ✓"
			var copy: CardInstance = (picked.upgraded[0] as Array)[1] as CardInstance
			return "%s ✓" % UpgradeSwap.tier_line(copy.definition)
		MachinePrize.Kind.REGISTER:
			return "STAMPED ✓"
	return "NEW IN CART ✓"


func _pick_sub(run_state: RunState, can_bin: bool) -> String:
	var visit: MachineVisit = run_state.machine.current_visit()
	var fills: bool = visit.chute == RewardMachine.Chute.NEW_ITEMS
	fills = fills or visit.chute == RewardMachine.Chute.COUPONS
	if fills and run_state.deck_is_full():
		return CART_FULL_TEXT
	return "or bin them all" if can_bin else "you must pick one"


## Whether the shift's visit before this one (a BONUS visit's ticket) was BOOSTED: the machine is
## then PREMIUM already and a BOOSTED BONUS visit keeps it so from its start (v0.53).
func _ticket_was_premium() -> bool:
	if run == null or run.history.is_empty() or run.history[-1].visits.is_empty():
		return false
	return run.history[-1].visits[-1].boosted


func _show_head(kind: int, visit: MachineVisit) -> void:
	match kind:
		MachineVisit.Kind.BONUS:
			var under: String = BONUS_UNDER
			if visit.why.is_empty():
				under = "shift %d" % run.history[-1].shift
			head.set_stamp(MachineHead.BONUS_TEXT, under)
		MachineVisit.Kind.STAMP_DAY:
			head.set_stamp("STAMP DAY!", "")
		_:
			head.set_stamp("", "")


## The keys and the stock window from chute_info: once a chute is chosen (`picking`), only it is
## lit. On a PREMIUM visit the classic keys are only seen before they sink in the transform: they
## stand cream and idle (as at rest), never padlocked, so nothing reads "locked" just before the
## machine turns premium.
func _show_keys(picking: bool) -> void:
	var visit: MachineVisit = run.machine.current_visit()
	var infos: Array[MachineChuteInfo] = []
	var premium: bool = plan != null and plan.premium
	for chute: int in RewardMachine.CHUTES:
		var info: MachineChuteInfo = run.machine.chute_info(run, chute)
		infos.append(info)
		var lit: bool = not picking or (visit != null and visit.chute == chute)
		var sinking: bool = premium and not ChuteKey.is_gold(chute)
		if sinking and info.state == RewardMachine.ChuteState.UNLIT:
			keys[chute].show_state(RewardMachine.ChuteState.OPEN, 0, false)
			continue
		keys[chute].show_state(info.state, info.opens_after_shift, lit)
	var chosen: int = visit.chute if picking and visit != null else -1
	if picking and visit != null and visit.kind == MachineVisit.Kind.STAMP_DAY:
		chosen = RewardMachine.Chute.REGISTER
	stock.show_chutes(infos, chosen)


func _hide_odds() -> void:
	_hovered = -1
	stock.set_hovered(-1)


## Presses `chute`'s key alone (-1: none).
func _press_only(chute: int) -> void:
	_pressed = chute
	for key: ChuteKey in keys:
		key.set_pressed(key.chute == chute)


## Lets every key up; the push bar goes dark.
func _release() -> void:
	_press_only(-1)
	tray.clear_confirm()


func _disarm() -> void:
	_armed = false
	display.set_bin(display.bin_offered(), false)


func _clear_tickets() -> void:
	popup.close_popup()
	for ticket: PrizeTicket in tickets:
		ticket.get_parent().remove_child(ticket)
		ticket.queue_free()
	tickets = []


func _on_key_hovered(chute: int) -> void:
	hover_key(chute)


func _on_key_unhovered(chute: int) -> void:
	if _hovered == chute:
		_hide_odds()


## The push bar: the pressed key's chute is confirmed (it stays down for the draw).
func _on_confirmed() -> void:
	if run == null or run.phase != RunState.Phase.MACHINE_CHOOSE or _pressed < 0:
		return
	_hide_odds()
	confirm_played = true
	chute_confirmed.emit(_pressed)


func _on_bin_pressed() -> void:
	if _armed and run != null and run.machine.can_bin():
		binned.emit()


func _on_ticket_hovered(index: int) -> void:
	if index >= 0 and index < tickets.size():
		popup.open_for(tickets[index])


func _on_ticket_unhovered(index: int) -> void:
	popup.leave(index)
