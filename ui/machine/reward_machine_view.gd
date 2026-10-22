class_name RewardMachineView
extends Control
## The RECEIPT REWARDS machine on the shift screen (#77, look F; build spec 4.2): a screen child
## over the shade, placed every frame at the stage's MACHINE_RECT. Back to front: the cabinet
## (drawn), the head plate (MachineHead), the receipt slot (SlotPlate), the display with BIN IT
## (MachineDisplay), the four chute keys (ChuteKey) over their REGULAR meters (PunchMeter), the
## stockroom window (StockroomWindow) with the order slip (OrderSlip), the YOUR ORDER plate
## (OrderPlate), the tray belt (MachineBelt, BoxLane), the RESTOCK hood (RestockHood) and the
## prize tickets in their cells (PrizeTicket); the odds card (OddsCard) left of the machine; on the
## stage layer (stage coordinates, over everything): the receipt feed (ReceiptFeed), the cart
## drawer (CartDrawer) and the prize's flight (MachineFlyer).
##
## It only displays what RunState and RewardMachine give it (chute_info, prizes, preview,
## can_bin, current_visit) and reports the player's choices: chute_confirmed, prize_picked and
## binned (the top bar's Cart opens the deck view during a visit, MachineFlow.show_deck).
## MachineFlow sequences the visits.
##
## THE CLOCK AND THE HOOKS (U0; U1-U3 attach to these, never to the clock itself):
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
##   effects at a wait point (the odds card's pop, a LEGENDARY tab's sparkle and hop, flashing
##   chevrons and lamps, a GOLDEN item's shine) read it in frame(t), never Time or delta.
## - `beat(beat_name, t0)` fires once per beat of the plan as the clock passes it, `t0` being the
##   beat's plan time: feed, read, lights, draw, packed, reveal_0..reveal_2, pick, land, punch
##   (only when the meter rises), restock, bonus (a BONUS visit's start), stamp_day (STAMP DAY's
##   start), plus armed. Beats before a resume's start never fire.
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
##   card's stamp, the place/stamp sound); U3's landing sets it false from its setup() and plays
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
## The player opened a chute's odds card (hover or click): MachineFlow logs the order.
signal odds_opened(chute: int)
## The prize tickets were built: the scanner watches their items (ScanController.cover_offers).
signal items_shown

const SIZE := Vector2(420, 630)
const TUNING_PATH := "res://data/balance/machine_tempo.tres"
const HEAD_POSITION := Vector2(-10, -8)
const SLOT_POSITION := Vector2(14, 54)
const DISPLAY_POSITION := Vector2(14, 100)
const KEY_X: Array[float] = [14.0, 114.0, 214.0, 314.0]
const KEY_Y := 160.0
const METER_Y := 240.0
const WINDOW_POSITION := Vector2(22, 276)
const SLIP_POSITION := Vector2(30, 278)
const SIGN_POSITION := Vector2(270, 271)
const PLATE_POSITION := Vector2(120, 428)
const BELT_POSITION := Vector2(10, 444)
const LANE_POSITION := Vector2(12, 446)
const HOOD_POSITION := Vector2(396, 436)
## Cell i's left edge and the cells' top, in machine coordinates.
const CELL_X: Array[float] = MachinePlan.CELL_X
const CELL_Y := 452.0
## The prize tickets' shapes (burst, sunburst, sparkles) are drawn under every ticket and clipped
## to the tray: from the left rail to the RESTOCK hood, from the stockroom window's foot to the
## cabinet's bottom border.
const TICKET_FX_RECT := Rect2(
	PrizeTicket.TRAY_LEFT, 426, PrizeTicket.TRAY_RIGHT - PrizeTicket.TRAY_LEFT, 202
)
const SHADOW := 8.0
## A beat planned at the clock's time when its segment starts (the pick press) still fires.
const SAME_TIME := 0.000001
## The STOCKROOM sign (look F's .fSign): bold Atkinson 8 px, 2 px apart, teal light on a teal
## darkest plate with an ink border, 16 px high.
const SIGN_SIZE := 8
const SIGN_WEIGHT := 800
const SIGN_SPACING := 2
const SIGN_PAD := 6
const SIGN_HEIGHT := 16.0
const SPEND_LINE := "SPEND €%d ✓ THANK YOU!"
## The order slip's check line (look F: the slip is narrow, no THANK YOU).
const SLIP_SPEND_LINE := "SPEND €%d ✓"
## The chute wait's sub line (build spec 4.3's resume table) and a BONUS visit's message there.
const CHOOSE_SUB := "pick a chute"
const AGAIN := "PICK A CHUTE AGAIN"
const AGAIN_SUB := "meters and odds after your first pick"
## The display while an odds card is open at the chute wait (look F).
const ODDS_LINE := "%s: SEE THE ODDS"
const ODDS_SUB := "confirm to draw"
const ODDS_BONUS_SUB := "REGULAR %d/%d now · confirm to draw"
## A LEGENDARY reveal's jolt (look F, flow_template.html's shake + flash; never under reduced
## motion): between these points of its reveal the machine shakes SHAKE_X px across (flipping
## SHAKE_X_HZ times a second) and SHAKE_Y px down and up (SHAKE_Y_HZ), and earlier a gold flash
## over the stage fades from FLASH_ALPHA to 0.
const SHAKE_FROM := 0.6
const SHAKE_TO := 0.7
const SHAKE_X := 3.0
const SHAKE_Y := 2.0
const SHAKE_X_HZ := 40.0
const SHAKE_Y_HZ := 50.0
const FLASH_FROM := 0.35
const FLASH_TO := 0.45
const FLASH_ALPHA := 0.28

var head: MachineHead
var slot_plate: SlotPlate
var display: MachineDisplay
var stockroom: StockroomWindow
var slip: OrderSlip
var order_plate: OrderPlate
var belt: MachineBelt
var box_lane: BoxLane
var hood: RestockHood
var odds_card: OddsCard
## The tickets' shapes behind them (PrizeTicket moves its own here), clipped to the tray.
var ticket_fx: Control
var keys: Array[ChuteKey] = []
var meters: Array[PunchMeter] = []
var tickets: Array[PrizeTicket] = []
## The stage layer: stage coordinates, drawn over the screen (top_level), shown with the machine.
var stage_layer: Control
var receipt_feed: ReceiptFeed
var cart_drawer: CartDrawer
var flyer: MachineFlyer
## The LEGENDARY reveal's gold flash over the stage (on the stage layer, over its parts).
var flash: ColorRect
var tuning: MachineTuning
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
var _armed: bool = false
var _lookup: ContentLookup
## The chute whose odds card is pinned by a click (-1: none; a hover only shows it).
var _pinned: int = -1
## The wait point (MachinePlan.WaitPoint) the clock runs to, the last time beats fired up to, and
## whether `finished` was sent for this visit.
var _until: int = MachinePlan.WaitPoint.CHOOSE
var _fired: float = -1.0
var _ended: bool = true
var _presses: PressReader
## The LEGENDARY reveal's shake now (stage px), as applied to the stage.
var _shake: Vector2 = Vector2.ZERO
## The display's wait lines while an odds card shows the page's odds lines (empty: none held).
var _wait_lines: PackedStringArray = PackedStringArray()


func _init() -> void:
	name = "RewardMachineView"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tuning = load(TUNING_PATH) as MachineTuning
	_presses = PressReader.new()
	add_child(_presses)
	_presses.tapped.connect(_on_tapped)
	head = _add(MachineHead.new(), HEAD_POSITION) as MachineHead
	slot_plate = _add(SlotPlate.new(), SLOT_POSITION) as SlotPlate
	display = _add(MachineDisplay.new(), DISPLAY_POSITION) as MachineDisplay
	display.bin_pressed.connect(_on_bin_pressed)
	for chute: int in RewardMachine.CHUTES:
		var key: ChuteKey = _add(ChuteKey.new(chute), Vector2(KEY_X[chute], KEY_Y)) as ChuteKey
		key.hovered.connect(_on_key_hovered)
		key.unhovered.connect(_on_key_unhovered)
		key.pressed.connect(open_odds)
		keys.append(key)
		meters.append(_add(PunchMeter.new(chute), Vector2(KEY_X[chute], METER_Y)) as PunchMeter)
	stockroom = _add(StockroomWindow.new(), WINDOW_POSITION) as StockroomWindow
	slip = _add(OrderSlip.new(), SLIP_POSITION) as OrderSlip
	add_child(_stockroom_sign())
	order_plate = _add(OrderPlate.new(), PLATE_POSITION) as OrderPlate
	belt = _add(MachineBelt.new(), BELT_POSITION) as MachineBelt
	box_lane = _add(BoxLane.new(), LANE_POSITION) as BoxLane
	hood = _add(RestockHood.new(), HOOD_POSITION) as RestockHood
	ticket_fx = Control.new()
	ticket_fx.name = "TicketFx"
	ticket_fx.position = TICKET_FX_RECT.position
	ticket_fx.size = TICKET_FX_RECT.size
	ticket_fx.clip_contents = true
	ticket_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ticket_fx)
	odds_card = OddsCard.new()
	odds_card.setup(self)
	odds_card.position = ShiftStage.ODDS_CARD_RECT.position - ShiftStage.MACHINE_RECT.position
	odds_card.confirmed.connect(_on_confirmed)
	odds_card.backed.connect(close_odds)
	add_child(odds_card)
	stage_layer = Control.new()
	stage_layer.name = "MachineStageLayer"
	stage_layer.top_level = true
	stage_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage_layer)
	receipt_feed = _add(ReceiptFeed.new(), Vector2.ZERO, stage_layer) as ReceiptFeed
	cart_drawer = _add(CartDrawer.new(), Vector2.ZERO, stage_layer) as CartDrawer
	flyer = _add(MachineFlyer.new(), Vector2.ZERO, stage_layer) as MachineFlyer
	flash = ColorRect.new()
	flash.name = "LegendaryFlash"
	flash.color = Palette.GOLD
	flash.size = ShiftStage.SIZE
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.visible = false
	stage_layer.add_child(flash)
	visible = false


func _process(delta: float) -> void:
	if not visible or plan == null:
		return
	_place()
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
## replay). A visit waiting for its chute shows the keys (lit, padlocked, CARD FULL or NOTHING TO
## IMPROVE from chute_info) over their meters and the order slip's "?" lines; one waiting for its
## pick (a STAMP DAY, or a resume at MACHINE_PICK) shows its prizes too (show_draw).
func open_visit(
	run_state: RunState, receipt_source: Control, stage_control: Control, resumed: bool
) -> void:
	_set_shake(Vector2.ZERO)
	run = run_state
	stage = stage_control
	receipt = receipt_source
	if _lookup == null or _lookup.balance != run.balance:
		_lookup = ContentLookup.new(run.balance)
	visible = true
	landing = null
	_disarm()
	close_odds()
	_clear_tickets()
	var visit: MachineVisit = run.machine.current_visit()
	var kind: int = visit.kind if visit != null else MachineVisit.Kind.TICKET
	var inspected: bool = visit == null or not visit.why.is_empty()
	_start(MachinePlan.new(tuning, kind, reduced_motion.call(), inspected))
	_show_head(kind, visit)
	_show_keys(run.phase == RunState.Phase.MACHINE_PICK)
	if run.phase == RunState.Phase.MACHINE_PICK:
		show_draw(run, resumed)
		return
	if resumed:
		_resume(MachinePlan.WaitPoint.CHOOSE)
	slip.show_order(
		_order_title(kind), _slip_check_line(), run.machine.machine.prizes_per_visit, -1, false
	)
	display.set_bin(false, false)
	if kind == MachineVisit.Kind.BONUS:
		display.show_message(AGAIN, AGAIN_SUB)
	else:
		display.show_message(SPEND_LINE % run.history[-1].total, CHOOSE_SUB)
	_place()
	_frame()


## The visit's prizes in their cells (reveal order; a short draw uses the centre cell for one
## prize, the left and centre cells for two), the pick prompt and BIN IT when it can be binned.
## The clock goes on from the chute wait through the draw and the reveals to the pick wait
## (`resumed`: it starts there).
func show_draw(run_state: RunState, resumed: bool = false) -> void:
	run = run_state
	visible = true
	_disarm()
	close_odds()
	_clear_tickets()
	var visit: MachineVisit = run.machine.current_visit()
	var prizes: Array[MachinePrize] = run.machine.prizes()
	if plan == null:
		_start(MachinePlan.new(tuning, visit.kind, reduced_motion.call()))
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
	var kind: int = prizes[0].kind if not prizes.is_empty() else -1
	slip.show_order(_order_title(visit.kind), _slip_check_line(), prizes.size(), kind, true)
	for index: int in range(prizes.size()):
		var ticket: PrizeTicket = PrizeTicket.new(
			index, prizes[index], run.machine.preview(run, index), run
		)
		ticket.position = Vector2(cell_x(index, prizes.size()), CELL_Y)
		ticket.clicked.connect(pick)
		ticket.setup(self)
		add_child(ticket)
		tickets.append(ticket)
	var can_bin: bool = run.machine.can_bin()
	display.set_bin(can_bin, false)
	display.show_message(pick_prompt(prizes.size(), run), _pick_sub(run, can_bin))
	items_shown.emit()
	_read_presses()
	_frame()


## A pick's landing (`picked`, kept as `landing` for the parts), or the draw binned (null): the
## meters as they are now and the landing's word ("NEW IN CART ✓", "UPGRADED ✓", "STAMPED ✓");
## the clock runs to END, then `finished`.
func land(picked: MachineLanding) -> void:
	_disarm()
	close_odds()
	if plan == null:
		return
	landing = picked
	if clock < plan.wait_time(MachinePlan.WaitPoint.PICK):
		_jump_to(plan.wait_time(MachinePlan.WaitPoint.PICK))  # Picked before it armed (debug).
	var next_kind: int = MachinePlan.NO_VISIT
	if RunState.MACHINE_PHASES.has(run.phase) and run.machine.current_visit() != null:
		next_kind = run.machine.current_visit().kind
	if picked == null:
		var visit: MachineVisit = run.history[-1].visits[-1]
		plan.set_landing(MachinePlan.Landing.BIN, 1, visit.meter_rose, next_kind)
	else:
		plan.set_landing(
			_landing_kind(picked), picked.upgraded.size(), picked.meter_rose, next_kind
		)
		display.show_message(
			_landing_word(picked), "SEE YOU NEXT SHIFT" if picked.last_of_shift else ""
		)
	_show_meters()
	_until = MachinePlan.WaitPoint.END
	_fired = minf(_fired, clock - SAME_TIME)
	_read_presses()
	_frame()


## Hides the machine and its odds card; the clock stops.
func close() -> void:
	visible = false
	close_odds()
	_clear_tickets()
	_presses.end()
	_set_shake(Vector2.ZERO)
	flash.visible = false
	run = null
	plan = null
	landing = null
	_ended = true


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


## Opens `chute`'s odds card, pinned with CONFIRM › while the visit waits for its chute and the
## chute is lit; a shut chute's key is refused (denied) with its reason on the display for a
## moment. During a STAMP DAY pick the REGISTER key shows the card STAMP DAY drew from,
## read-only and not pinned (it closes when the pointer leaves the key).
func open_odds(chute: int) -> void:
	if run == null or not _armed:
		return
	var info: MachineChuteInfo = run.machine.chute_info(run, chute)
	var choosing: bool = run.phase == RunState.Phase.MACHINE_CHOOSE
	if choosing and info.state != RewardMachine.ChuteState.OPEN:
		Sfx.play_at(self, "denied")
		display.show_denied(ChuteKey.NAMES[chute], keys[chute].sub_text())
		return
	if not choosing and not _stamp_day_register(chute):
		return
	_pinned = chute if choosing else -1
	for key: ChuteKey in keys:
		key.set_pinned(key.chute == _pinned)
	_show_odds(chute, info, choosing)


## Closes the odds card.
func close_odds() -> void:
	_pinned = -1
	for key: ChuteKey in keys:
		key.set_pinned(false)
	_hide_odds()


## Picks the prize in cell `index` (armed only).
func pick(index: int) -> void:
	if _armed and run != null and run.phase == RunState.Phase.MACHINE_PICK:
		prize_picked.emit(index)


## Whether the clock holds at its wait point (the chute wait, the pick wait or the end).
func is_waiting() -> bool:
	return plan != null and _at_wait()


## Whether a key or a prize can be clicked yet (the clock waits and the mouse was released).
func is_armed() -> bool:
	return visible and _armed


## The tray items of the product and coupon prizes (the scanner reads them).
func items() -> Array[ItemView]:
	var found: Array[ItemView] = []
	for ticket: PrizeTicket in tickets:
		if ticket.item != null and ticket.prize.adds_card():
			found.append(ticket.item)
	return found


## Whether the scanner may read the prize items: shown and armed.
func can_scan() -> bool:
	return is_visible_in_tree() and _armed and not tickets.is_empty()


## Cell i's left edge for a draw of `count` prizes: one prize takes the centre cell, two the left
## and centre cells.
static func cell_x(index: int, count: int) -> float:
	return CELL_X[MachinePlan.cell_of(index, count)]


## The machine's shake at `t` on `shown` (zero but during a LEGENDARY reveal's jolt; never under
## reduced motion).
static func legendary_shake(shown: MachinePlan, t: float) -> Vector2:
	if (
		shown == null
		or shown.reduced_motion
		or not _legendary_between(shown, t, SHAKE_FROM, SHAKE_TO)
	):
		return Vector2.ZERO
	var x: float = SHAKE_X if int(floorf(t * SHAKE_X_HZ)) % 2 == 1 else -SHAKE_X
	var y: float = SHAKE_Y if int(floorf(t * SHAKE_Y_HZ)) % 2 == 1 else -SHAKE_Y
	return Vector2(x, y)


## The gold flash's opacity at `t` on `shown` (0 but early in a LEGENDARY reveal; never under
## reduced motion).
static func legendary_flash(shown: MachinePlan, t: float) -> float:
	if shown == null or shown.reduced_motion or not shown.has_draw:
		return 0.0
	var alpha: float = 0.0
	for index: int in range(shown.reveal_at.size()):
		if shown.rarities[index] != MachinePrize.Rarity.LEGENDARY:
			continue
		var p: float = shown.reveal_progress(index, t)
		if p > FLASH_FROM and p < FLASH_TO:
			alpha = FLASH_ALPHA * (1.0 - (p - FLASH_FROM) / (FLASH_TO - FLASH_FROM))
	return alpha


static func _legendary_between(shown: MachinePlan, t: float, from: float, to: float) -> bool:
	if not shown.has_draw:
		return false
	for index: int in range(shown.reveal_at.size()):
		if shown.rarities[index] != MachinePrize.Rarity.LEGENDARY:
			continue
		var p: float = shown.reveal_progress(index, t)
		if p > from and p < to:
			return true
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


func _stockroom_sign() -> Label:
	var sign_label: Label = UiKit.body_label("STOCKROOM", SIGN_SIZE, Palette.TEAL_LIGHT)
	sign_label.name = "StockroomSign"
	var font: FontVariation = FontVariation.new()
	font.base_font = ArtStyle.bold_font(SIGN_WEIGHT)
	font.spacing_glyph = SIGN_SPACING
	sign_label.add_theme_font_override("font", font)
	var plate: StyleBoxFlat = plate_style(Palette.BACKGROUND)
	plate.content_margin_left = SIGN_PAD
	plate.content_margin_right = SIGN_PAD
	sign_label.add_theme_stylebox_override("normal", plate)
	sign_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sign_label.custom_minimum_size = Vector2(0, SIGN_HEIGHT)
	sign_label.position = SIGN_POSITION
	return sign_label


## Places `part` at `at`, hooks it (its setup(view)) and adds it to `parent` (null: the machine).
func _add(part: Control, at: Vector2, parent: Node = null) -> Control:
	part.position = at
	part.call(&"setup", self)
	(parent if parent != null else self).add_child(part)
	return part


## Every part at the clock.
func _frame() -> void:
	var t: float = clock
	head.frame(t)
	slot_plate.frame(t)
	display.frame(t)
	for key: ChuteKey in keys:
		key.frame(t)
	for meter: PunchMeter in meters:
		meter.frame(t)
	stockroom.frame(t)
	slip.frame(t)
	order_plate.frame(t)
	belt.frame(t)
	box_lane.frame(t)
	hood.frame(t)
	for ticket: PrizeTicket in tickets:
		ticket.frame(t)
	odds_card.frame(t)
	receipt_feed.frame(t)
	cart_drawer.frame(t)
	flyer.frame(t)
	_set_shake(legendary_shake(plan, t))
	var flash_alpha: float = legendary_flash(plan, t)
	flash.visible = flash_alpha > 0.0
	flash.modulate.a = flash_alpha
	_place()


func _place() -> void:
	if not is_instance_valid(stage):
		return
	var xform: Transform2D = stage.get_global_transform()
	global_position = (xform * ShiftStage.MACHINE_RECT).position
	stage_layer.position = xform.origin
	stage_layer.scale = xform.get_scale()
	stage_layer.size = stage.size


## Shakes the whole stage by `shake` (stage px), as look F's #shakeWrap moves the register,
## belt, receipt, top bar, machine and flash together; the machine and its stage layer follow the
## stage (_place). Zero puts the stage back.
func _set_shake(shake: Vector2) -> void:
	if shake == _shake:
		return
	if is_instance_valid(stage):
		stage.position += (shake - _shake) * stage.scale
	_shake = shake


func _start(visit_plan: MachinePlan) -> void:
	plan = visit_plan
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
			return "UPGRADED ✓"
		MachinePrize.Kind.REGISTER:
			return "STAMPED ✓"
	return "NEW IN CART ✓"


func _pick_sub(run_state: RunState, can_bin: bool) -> String:
	var visit: MachineVisit = run_state.machine.current_visit()
	var fills: bool = visit.chute == RewardMachine.Chute.NEW_ITEMS
	fills = fills or visit.chute == RewardMachine.Chute.COUPONS
	if fills and run_state.deck_is_full():
		return OddsCard.CART_FULL_TEXT
	return "or bin them all" if can_bin else "you must pick one"


func _show_head(kind: int, visit: MachineVisit) -> void:
	match kind:
		MachineVisit.Kind.BONUS:
			var under: String = "%s passed" % _inspection_name(visit.why)
			if visit.why.is_empty():
				under = "shift %d" % run.history[-1].shift
			head.set_stamp("BONUS TICKET!", under)
		MachineVisit.Kind.STAMP_DAY:
			head.set_stamp("STAMP DAY!", "")
		_:
			head.set_stamp("", "")


## The keys from chute_info: once a chute is chosen (`picking`), only it is lit; during a STAMP
## DAY pick the REGISTER key carries the SEE ODDS tab.
func _show_keys(picking: bool) -> void:
	var visit: MachineVisit = run.machine.current_visit()
	for chute: int in RewardMachine.CHUTES:
		var info: MachineChuteInfo = run.machine.chute_info(run, chute)
		var lit: bool = not picking or (visit != null and visit.chute == chute)
		keys[chute].show_state(info.state, info.opens_after_shift, lit)
		keys[chute].set_tab(_stamp_day_register(chute))
	_show_meters()


func _show_meters() -> void:
	for chute: int in RewardMachine.CHUTES:
		meters[chute].show_level(run.machine.level(chute), run.machine.machine.max_level())


func _show_odds(chute: int, info: MachineChuteInfo, choosable: bool) -> void:
	var names: Dictionary = {}
	for key: String in info.odds.in_draw:
		names[key] = _prize_name(key)
	odds_card.show_card(chute, info, names, _bonus_band(chute, info), choosable)
	if run.phase == RunState.Phase.MACHINE_CHOOSE:
		_show_odds_lines(chute, info)
	odds_opened.emit(chute)


## While a chute's odds card shows at the chute wait, the display reads look F's
## "<CHUTE>: SEE THE ODDS" / "confirm to draw" (BONUS: "REGULAR n/3 now · confirm to draw"); the
## wait's lines come back when it closes.
func _show_odds_lines(chute: int, info: MachineChuteInfo) -> void:
	if _wait_lines.is_empty():
		_wait_lines = display.rest_texts()
	var sub: String = ODDS_SUB
	var visit: MachineVisit = run.machine.current_visit()
	if visit != null and visit.kind == MachineVisit.Kind.BONUS:
		sub = ODDS_BONUS_SUB % [info.level, info.max_level]
	display.show_message(ODDS_LINE % ChuteKey.NAMES[chute], sub)


func _hide_odds() -> void:
	odds_card.visible = false
	if not _wait_lines.is_empty():
		display.show_message(_wait_lines[0], _wait_lines[1])
		_wait_lines = PackedStringArray()


## The bonus ticket's band on `chute`'s odds card: why it was given, and what the first pick
## changed for this chute (look F): its REGULAR punch (level before › now), the cart holding the
## first upgrade, the new stamp no longer dropping, no first-visit coupon now.
func _bonus_band(chute: int, info: MachineChuteInfo) -> PackedStringArray:
	var visit: MachineVisit = run.machine.current_visit()
	if visit == null or visit.kind != MachineVisit.Kind.BONUS:
		return PackedStringArray()
	var record: ShiftRecord = run.history[-1]
	var why: String = "shift %d" % record.shift
	if not visit.why.is_empty():
		why = "%s passed" % _inspection_name(visit.why)
	var line: String = "odds after your first pick"
	var changes: PackedStringArray = _first_pick_changes(chute, info)
	if not changes.is_empty():
		line += ": " + " · ".join(changes)
	return PackedStringArray(["BONUS TICKET · %s" % why, line])


## What the shift's first visit changed for `chute`'s draw now (look F's bonus band items), as
## RewardMachine.chute_info reports it (MachineChuteInfo.first_pick_*); the view only words it.
static func _first_pick_changes(chute: int, info: MachineChuteInfo) -> PackedStringArray:
	var changes: PackedStringArray = PackedStringArray()
	if info.first_pick_level_before >= 0:
		changes.append("REGULAR %d › %d" % [info.first_pick_level_before, info.level])
	if chute == RewardMachine.Chute.UPGRADES and info.first_pick_kept:
		changes.append("your cart holds the first upgrade")
	if chute == RewardMachine.Chute.REGISTER and info.first_pick_kept:
		changes.append("your new stamp no longer drops")
	if info.first_pick_spent_coupon:
		changes.append("no first-visit coupon now")
	return changes


func _stamp_day_register(chute: int) -> bool:
	var visit: MachineVisit = run.machine.current_visit() if run != null else null
	return (
		chute == RewardMachine.Chute.REGISTER
		and visit != null
		and visit.kind == MachineVisit.Kind.STAMP_DAY
	)


func _prize_name(key: String) -> String:
	var id: String = key.get_slice(":", 1)
	if key.get_slice(":", 0) == MachinePrize.KIND_NAMES[MachinePrize.Kind.REGISTER]:
		var upgrade: UpgradeDefinition = _lookup.upgrade(id)
		return upgrade.display_name if upgrade != null else id
	var card: CardDefinition = _lookup.card(id)
	return card.display_name if card != null else id


func _inspection_name(id: String) -> String:
	var inspection: InspectionDefinition = _lookup.inspection(id)
	return inspection.display_name if inspection != null else id


func _order_title(kind: int) -> String:
	match kind:
		MachineVisit.Kind.BONUS:
			return "BONUS #%d8" % run.history[-1].shift
		MachineVisit.Kind.STAMP_DAY:
			return "STAMP DAY"
	var visit: MachineVisit = run.machine.current_visit()
	var chute: int = visit.chute + 1 if visit != null and visit.chute >= 0 else 0
	return "ORDER #%d%d7" % [run.history[-1].shift, chute]


## The order slip's check line: the spend (shorter than the display's), or a BONUS visit's
## INSPECTED.
func _slip_check_line() -> String:
	var visit: MachineVisit = run.machine.current_visit()
	if visit != null and visit.kind == MachineVisit.Kind.BONUS:
		return "INSPECTED ✓"
	return SLIP_SPEND_LINE % run.history[-1].total


func _disarm() -> void:
	_armed = false
	display.set_bin(display.bin_offered(), false)


func _clear_tickets() -> void:
	for ticket: PrizeTicket in tickets:
		remove_child(ticket)
		ticket.queue_free()
	tickets = []


func _draw() -> void:
	draw_rect(Rect2(Vector2(SHADOW, SHADOW), SIZE), Palette.TEAL_BLACK)
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.PANEL)
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.INK, false, 2.0)


func _on_key_hovered(chute: int) -> void:
	if _pinned >= 0 or run == null or not _armed:
		return
	var choosing: bool = run.phase == RunState.Phase.MACHINE_CHOOSE
	var info: MachineChuteInfo = run.machine.chute_info(run, chute)
	if (choosing and info.state == RewardMachine.ChuteState.OPEN) or _stamp_day_register(chute):
		_show_odds(chute, info, false)


func _on_key_unhovered(_chute: int) -> void:
	if _pinned < 0:
		_hide_odds()


func _on_confirmed(chute: int) -> void:
	if run == null or run.phase != RunState.Phase.MACHINE_CHOOSE:
		return
	close_odds()
	chute_confirmed.emit(chute)


func _on_bin_pressed() -> void:
	if _armed and run != null and run.machine.can_bin():
		binned.emit()
