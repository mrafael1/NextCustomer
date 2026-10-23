class_name RewardMachine
extends RefCounted
## The RECEIPT REWARDS machine (#77, build spec 1.6): after a passed shift that isn't the last,
## the shift's ticket buys one visit; a passed inspected shift adds the bonus ticket's visit; on a
## STAMP DAY shift a run behind on registers gets a REGISTER pick. A visit chooses a chute, draws
## its prizes (MachineDraw, with the run's RNG) and picks one or bins them. Odds come from
## MachineOdds and never use the RNG.
##
## Two machine states (v0.47): a Normal visit lights NEW ITEMS and COUPONS; a BOOSTED visit (the
## ticket's visit after one of MachineDefinition.boosted_shifts) lights REGISTER and UPGRADES. A
## boosted shift whose REGISTER is full (or has nothing to draw) and whose UPGRADES has nothing to
## improve gives a Normal visit instead. The bonus ticket's visit after a boosted shift is BOOSTED
## too (v0.53, decided with the user on 2026-10-23), by the same rule from the state after the
## ticket's pick; STAMP DAY is its own REGISTER pick. Every visit after a shift draws at that
## shift's odds level (MachineDefinition.odds_level_after): rarity rises with the run's progress,
## not with use.
##
## The machine holds the run's RNG (a shared reference) but never the run: methods that read or
## change the run take it. It has its own stage and never writes RunState.phase. Cards from a pick
## go into the deck now; register effects apply from the next shift (ShiftLimits reads the
## upgrades when a shift starts).

enum Chute { NEW_ITEMS, COUPONS, REGISTER, UPGRADES }
## OPEN: lit. UNLIT: not a chute of this visit's state (REGISTER and UPGRADES on a Normal visit,
## NEW ITEMS and COUPONS on a BOOSTED one). CARD_FULL: REGISTER at the register cap. EMPTY:
## nothing to draw (UPGRADES: "NOTHING TO IMPROVE").
enum ChuteState { OPEN, UNLIT, CARD_FULL, EMPTY }
## IDLE: no visit. CHOOSE: a visit waits for its chute. PICK: its prizes wait for a pick or bin.
enum Stage { IDLE, CHOOSE, PICK }

const CHUTES: Array[int] = [Chute.NEW_ITEMS, Chute.COUPONS, Chute.REGISTER, Chute.UPGRADES]
## The chutes a Normal and a BOOSTED visit light.
const NORMAL_CHUTES: Array[int] = [Chute.NEW_ITEMS, Chute.COUPONS]
const BOOSTED_CHUTES: Array[int] = [Chute.REGISTER, Chute.UPGRADES]
## A visit's machine state, as logged (machine_visit's `state`).
const STATE_NORMAL := "normal"
const STATE_BOOSTED := "boosted"
const STATE_STAMP_DAY := "stamp_day"
const STAGE_NAMES: Array[String] = ["idle", "choose", "pick"]

var machine: MachineDefinition
var stage: Stage = Stage.IDLE
## The run's first COUPONS / NEW ITEMS draw happened (spent at the draw, picked or binned).
var coupons_first_done: bool = false
var new_items_first_done: bool = false
## The run's upgrade count at the last checkout (the upgrades the scored shift was played with).
var upgrades_at_checkout: int = 0
var _rng: RandomNumberGenerator
var _visit: MachineVisit
## The visits still to come this shift after the current one (MachineVisit.Kind).
var _queue: Array[int] = []
## Per-state caches, cleared on every change: the run snapshot and the odds card per chute.
var _context: MachineContext
var _cards: Dictionary = {}
## STAMP DAY: the REGISTER odds card its draw was made from.
var _stamp_odds: MachineOddsCard
## The visit's draw was its chute's first (it spent coupons_first_done or new_items_first_done):
## its chute's odds card during PICK is still the first draw's (saved, so a resume shows it too).
var _first_draw: bool = false


func _init(machine_definition: MachineDefinition, rng: RandomNumberGenerator) -> void:
	machine = machine_definition
	_rng = rng


## RunState.checkout on a passed shift that isn't the last: queues the ticket's visit (BOOSTED after
## a boosted shift when REGISTER or UPGRADES can draw, else Normal), the bonus ticket's when due
## (BOOSTED or Normal by the same rule when it starts) and STAMP DAY when due, and waits for the
## ticket's chute. A visit none of whose lit chutes can draw is skipped (no lit key to wait on): the
## next queued one starts, else the machine idles.
func begin_after_checkout(run: RunState) -> void:
	clear_visits()
	if run.history.is_empty():
		return
	var record: ShiftRecord = run.history[-1]
	if not record.passed or record.shift >= run.shift_count():
		return
	upgrades_at_checkout = run.upgrades.size()
	_visit = MachineVisit.new(MachineVisit.Kind.TICKET)
	_visit.boosted = _boosted_due(run)
	if _bonus_due(run):
		_queue.append(MachineVisit.Kind.BONUS)
	if _stamp_day_due(run):
		_queue.append(MachineVisit.Kind.STAMP_DAY)
	stage = Stage.CHOOSE
	if not _can_draw_lit(run):
		_visit = null
		_next_visit(run)


## One chute's state for the UI: lit or why not, and its exact odds card.
func chute_info(run: RunState, chute: int) -> MachineChuteInfo:
	var info: MachineChuteInfo = MachineChuteInfo.new()
	info.state = _chute_state(run, chute)
	info.odds = _odds(run, chute)
	info.cart_full = (
		(chute == Chute.NEW_ITEMS or chute == Chute.COUPONS)
		and run.deck.size() >= run.balance.deck_limit
	)
	if info.state == ChuteState.UNLIT and BOOSTED_CHUTES.has(chute):
		info.opens_after_shift = _next_boosted_shift(run)
	if _visit != null and _visit.kind == MachineVisit.Kind.BONUS:
		_first_pick_changes(run, chute, info)
	return info


## A BONUS visit's chute_info: what the shift's first visit changed for `chute` when it was made
## there (a kept prize, the run's first-visit coupon spent by its draw).
func _first_pick_changes(run: RunState, chute: int, info: MachineChuteInfo) -> void:
	if run.history.is_empty() or run.history[-1].visits.is_empty():
		return
	var record: ShiftRecord = run.history[-1]
	var first: MachineVisit = record.visits[0]
	if first.chute != chute:
		return
	info.first_pick_kept = first.picked_prize() != null
	if chute != Chute.COUPONS:
		return
	info.first_pick_spent_coupon = true
	for earlier: ShiftRecord in run.history:
		if earlier == record:
			break
		for visit: MachineVisit in earlier.visits:
			if visit.chute == Chute.COUPONS:
				info.first_pick_spent_coupon = false
				return


## Chooses the visit's chute (CHOOSE only, a lit chute): draws its prizes with the run's RNG. The
## run's first COUPONS or NEW ITEMS draw spends its flag here, whatever is done with the prizes.
func choose(run: RunState, chute: int) -> bool:
	if stage != Stage.CHOOSE or _visit == null or not CHUTES.has(chute):
		return false
	if _chute_state(run, chute) != ChuteState.OPEN:
		return false
	var context: MachineContext = _snapshot(run)
	var drawn: Array[MachinePrize] = MachineDraw.draw(chute, context, odds_level(run), _rng)
	if drawn.is_empty():
		return false
	_visit.chute = chute
	_visit.set_drawn(drawn)
	_visit.guarantee_held = MachineDraw.holds(drawn, context.guarantee(chute))
	_first_draw = (
		(chute == Chute.COUPONS and not coupons_first_done)
		or (chute == Chute.NEW_ITEMS and not new_items_first_done)
	)
	if chute == Chute.COUPONS:
		coupons_first_done = true
	elif chute == Chute.NEW_ITEMS:
		new_items_first_done = true
	stage = Stage.PICK
	_clear_cache()
	return true


## The visit's prizes in reveal order (1 to prizes_per_visit), or none outside PICK.
func prizes() -> Array[MachinePrize]:
	if stage != Stage.PICK or _visit == null:
		return []
	return _visit.prizes.duplicate()


## What picking the prize at `index` would do, or null for no such prize.
func preview(run: RunState, index: int) -> MachinePreview:
	var prize: MachinePrize = _prize(index)
	if prize == null:
		return null
	var found: MachinePreview = MachinePreview.new()
	found.prize = prize
	found.adds_card = prize.adds_card()
	found.needs_replace = needs_replace(run, index)
	if prize.kind == MachinePrize.Kind.UPGRADE:
		found.targets = _targets(run, prize)
		for target: CardInstance in found.targets:
			found.to_cards.append(_stepped(target, prize))
		found.copies = found.targets.size()
	elif prize.kind == MachinePrize.Kind.REGISTER:
		found.box_index = run.upgrades.size()
	return found


## NEW ITEMS and COUPONS on the ticket's and the bonus ticket's visits can be binned.
func can_bin() -> bool:
	if stage != Stage.PICK or _visit == null or _visit.kind == MachineVisit.Kind.STAMP_DAY:
		return false
	return _visit.chute == Chute.NEW_ITEMS or _visit.chute == Chute.COUPONS


## The prize adds a card and the cart is at the deck limit: the pick must swap a card out.
func needs_replace(run: RunState, index: int) -> bool:
	var prize: MachinePrize = _prize(index)
	return prize != null and prize.adds_card() and run.deck.size() >= run.balance.deck_limit


## Takes the prize at `index`: adds the card (swapping `replaced` out at the deck limit), takes
## the register (refused at the cap) or upgrades the copies; records the visit and moves on. Null
## when refused.
func pick(run: RunState, index: int, replaced: CardInstance = null) -> MachineLanding:
	var prize: MachinePrize = _prize(index)
	if prize == null or not _can_take(run, prize, index, replaced):
		return null
	var landing: MachineLanding = MachineLanding.new()
	landing.prize = prize
	landing.cart_before = run.deck.size()
	if _visit.kind == MachineVisit.Kind.STAMP_DAY:
		_odds(run, Chute.REGISTER)
	match prize.kind:
		MachinePrize.Kind.PRODUCT, MachinePrize.Kind.COUPON:
			if needs_replace(run, index):
				run.deck.remove_card(replaced)
				landing.replaced = replaced
				_visit.replaced = replaced.definition
			landing.added = run.deck.add_card(prize.card)
		MachinePrize.Kind.REGISTER:
			landing.box_index = run.upgrades.size()
			landing.register = prize.upgrade
			run.upgrades.append(prize.upgrade)
		MachinePrize.Kind.UPGRADE:
			for target: CardInstance in _targets(run, prize):
				var upgraded: CardInstance = run.deck.upgrade(target, _stepped(target, prize))
				landing.upgraded.append([target, upgraded])
				_visit.upgraded.append(
					[
						target.instance_id,
						String(target.definition.id),
						String(upgraded.definition.id)
					]
				)
	_visit.picked = index
	landing.cart_after = run.deck.size()
	_end_visit(run)
	landing.last_of_shift = stage == Stage.IDLE
	return landing


## Bins the prizes (can_bin only): records the visit and moves on.
func bin(run: RunState) -> bool:
	if not can_bin():
		return false
	_visit.binned = true
	_end_visit(run)
	return true


## The visit waiting for its chute or its pick, or null.
func current_visit() -> MachineVisit:
	return _visit


## The visits queued after the current one this shift (MachineVisit.Kind), in order.
func pending_kinds() -> Array[int]:
	return _queue.duplicate()


## Registers picked from the machine this run (REGISTER and STAMP DAY picks); a starting deck's
## starting_upgrade never counts.
func registers_picked(run: RunState) -> int:
	var found: int = 0
	for record: ShiftRecord in run.history:
		found += record.registers_taken().size()
	return found


## The odds level the visits after the last played shift draw at (0 before any checkout).
func odds_level(run: RunState) -> int:
	return machine.odds_level_after(_shift(run))


## Whether the waiting visit is BOOSTED.
func is_boosted() -> bool:
	return _visit != null and _visit.boosted


## A visit's machine state, as logged (STATE_NORMAL, STATE_BOOSTED, STATE_STAMP_DAY).
static func state_of(visit: MachineVisit) -> String:
	return state_for(visit.kind, visit.boosted)


## The machine state of a visit of `kind` (MachineVisit.Kind) that is `boosted` or not; also for
## a saved visit's fields (the simulator's records).
static func state_for(kind: int, boosted: bool) -> String:
	if kind == MachineVisit.Kind.STAMP_DAY:
		return STATE_STAMP_DAY
	return STATE_BOOSTED if boosted else STATE_NORMAL


## The chutes a visit lights by its state: BOOSTED_CHUTES on a BOOSTED visit, REGISTER alone on
## STAMP DAY, else NORMAL_CHUTES (no visit: Normal).
static func lit_chutes(visit: MachineVisit) -> Array[int]:
	if visit != null and visit.kind == MachineVisit.Kind.STAMP_DAY:
		return [Chute.REGISTER]
	if visit != null and visit.boosted:
		return BOOSTED_CHUTES
	return NORMAL_CHUTES


## The machine's state for the run save (RunSave).
func to_dictionary() -> Dictionary:
	return {
		"coupons_first_done": coupons_first_done,
		"new_items_first_done": new_items_first_done,
		"upgrades_at_checkout": upgrades_at_checkout,
		"queue": _queue.map(func(kind: int) -> String: return MachineVisit.KIND_NAMES[kind]),
		"stage": STAGE_NAMES[stage],
		"visit": _visit.to_dictionary() if _visit != null else {},
		"first_draw": _first_draw,
	}


## Puts back to_dictionary's state (as parsed from JSON). False, changing nothing, when a field
## is missing or wrong or the stage and the visit don't fit together.
func restore_from(data: Dictionary, lookup: ContentLookup) -> bool:
	var reader: SaveReader = SaveReader.new(data, lookup)
	var saved_stage: int = STAGE_NAMES.find(reader.text("stage"))
	var saved_queue: Array[int] = []
	var queue_data: Variant = data.get("queue")
	for kind_name: Variant in queue_data if queue_data is Array else [null]:
		saved_queue.append(MachineVisit.KIND_NAMES.find(kind_name) if kind_name is String else -1)
	var visit_data: Variant = data.get("visit")
	var visit: MachineVisit = null
	if visit_data is Dictionary and not (visit_data as Dictionary).is_empty():
		visit = MachineVisit.from_dictionary(visit_data, lookup)
	var valid: bool = (
		reader.ok
		and saved_queue.all(func(kind: int) -> bool: return kind > MachineVisit.Kind.TICKET)
		and visit_data is Dictionary
		and _fits_stage(saved_stage, visit, visit_data, saved_queue)
	)
	var first_coupons: bool = reader.flag("coupons_first_done")
	var first_new_items: bool = reader.flag("new_items_first_done")
	var at_checkout: int = reader.whole("upgrades_at_checkout")
	# Left out by saves made before it was added: not a first draw.
	var first_draw: Variant = data.get("first_draw", false)
	if not valid or not reader.ok or not first_draw is bool:
		return false
	coupons_first_done = first_coupons
	new_items_first_done = first_new_items
	upgrades_at_checkout = at_checkout
	_queue = saved_queue
	stage = saved_stage as Stage
	_visit = visit
	_first_draw = first_draw and stage == Stage.PICK
	_clear_cache()
	return true


## Empties the queue and the current visit (debug jump).
func clear_visits() -> void:
	_queue = []
	_visit = null
	_first_draw = false
	stage = Stage.IDLE
	_clear_cache()


func _fits_stage(
	saved_stage: int, visit: MachineVisit, visit_data: Variant, queue: Array[int]
) -> bool:
	match saved_stage:
		Stage.IDLE:
			return queue.is_empty() and (visit_data as Dictionary).is_empty()
		Stage.CHOOSE:
			return (
				visit != null
				and visit.kind != MachineVisit.Kind.STAMP_DAY
				and visit.prizes.is_empty()
				and visit.chute == MachineVisit.NO_CHUTE
			)
		Stage.PICK:
			return (
				visit != null
				and CHUTES.has(visit.chute)
				and not visit.prizes.is_empty()
				and visit.prizes.size() <= machine.prizes_per_visit
				and visit.picked == -1
				and not visit.binned
				and lit_chutes(visit).has(visit.chute)
			)
	return false


## The prize at a reveal index of the visit waiting for its pick, or null.
func _prize(index: int) -> MachinePrize:
	if stage != Stage.PICK or _visit == null or index < 0 or index >= _visit.prizes.size():
		return null
	return _visit.prizes[index]


func _can_take(run: RunState, prize: MachinePrize, index: int, replaced: CardInstance) -> bool:
	match prize.kind:
		MachinePrize.Kind.REGISTER:
			return registers_picked(run) < machine.register_cap
		MachinePrize.Kind.UPGRADE:
			return not _targets(run, prize).is_empty()
	return not needs_replace(run, index) or (replaced != null and run.deck.cards.has(replaced))


func _targets(run: RunState, prize: MachinePrize) -> Array[CardInstance]:
	return ItemUpgrades.targets(machine.item_upgrades, run.deck, prize.card, prize.rarity)


## The card an UPGRADES prize turns a copy into.
func _stepped(target: CardInstance, prize: MachinePrize) -> CardDefinition:
	var steps: int = ItemUpgrades.step_count(prize.rarity)
	return ItemUpgrades.tier_step(machine.item_upgrades, target.definition, steps)


## Records the finished visit (history) and moves on to the next queued one.
func _end_visit(run: RunState) -> void:
	run.history[-1].visits.append(_visit)
	_visit = null
	_first_draw = false
	_clear_cache()
	_next_visit(run)


## Starts the next queued visit that has something to draw (a BONUS visit none of whose lit
## chutes can draw is skipped), else idles. A BONUS visit after a boosted shift is BOOSTED when
## REGISTER or UPGRADES can draw after the ticket's pick (v0.53), else Normal.
func _next_visit(run: RunState) -> void:
	if not _stamp_day_due(run):
		_queue.erase(MachineVisit.Kind.STAMP_DAY)
	while not _queue.is_empty():
		var kind: int = _queue.pop_front()
		if kind == MachineVisit.Kind.BONUS:
			var record: ShiftRecord = run.history[-1]
			var why: String = String(record.inspection.id) if record.inspection != null else ""
			_visit = MachineVisit.new(MachineVisit.Kind.BONUS, why)
			_visit.boosted = _boosted_due(run)
			stage = Stage.CHOOSE
			if _can_draw_lit(run):
				return
			_visit = null
			continue
		if _start_stamp_day(run):
			return
	stage = Stage.IDLE


## STAMP DAY: draws REGISTER at the shift's odds level with the run's RNG and waits for the pick.
## False (no visit) when nothing can be drawn.
func _start_stamp_day(run: RunState) -> bool:
	var context: MachineContext = _snapshot(run)
	var odds: MachineOddsCard = _odds(run, Chute.REGISTER)
	var drawn: Array[MachinePrize] = MachineDraw.draw(
		Chute.REGISTER, context, odds_level(run), _rng
	)
	if drawn.is_empty():
		return false
	var visit: MachineVisit = MachineVisit.new(MachineVisit.Kind.STAMP_DAY)
	visit.chute = Chute.REGISTER
	visit.set_drawn(drawn)
	visit.guarantee_held = MachineDraw.holds(drawn, context.guarantee(Chute.REGISTER))
	visit.stamp_day_odds = odds
	_visit = visit
	_stamp_odds = odds
	stage = Stage.PICK
	return true


func _bonus_due(run: RunState) -> bool:
	var record: ShiftRecord = run.history[-1]
	return _bonus_for(machine, record.shift, record.inspection != null)


## Read-only, for the planning notice (#77 machine v2): whether passing the current shift would
## queue the bonus ticket's visit, as _bonus_due decides it at that checkout. False on the last
## shift (no machine follows it).
func bonus_if_passed(run: RunState) -> bool:
	if run.is_last_shift():
		return false
	return _bonus_for(machine, run.shift_index + 1, not run.inspections.is_empty())


## Read-only, for the planning announce (v0.50, "PREMIUM NEXT"): whether passing the current
## shift would queue a BOOSTED ticket visit, as begin_after_checkout decides it at that checkout
## (a boosted shift, and REGISTER or UPGRADES able to draw from the run as it is now). False on
## the last shift (no machine follows it).
func boosted_if_passed(run: RunState) -> bool:
	if run.is_last_shift() or not machine.is_boosted_shift(run.shift_index + 1):
		return false
	var context: MachineContext = MachineContext.from_run(
		run, machine, coupons_first_done, new_items_first_done
	)
	for chute: int in BOOSTED_CHUTES:
		if chute == Chute.REGISTER and registers_picked(run) >= machine.register_cap:
			continue
		if not context.pools(chute).all(func(pool: Array) -> bool: return pool.is_empty()):
			return true
	return false


## Read-only, for the inspection chip (#77 machine v2): whether the shift just checked out was an
## inspected one, passed, and its pass earned the bonus ticket (the chip's EARNED state). False
## before any checkout and after a failed or last shift.
func bonus_earned(run: RunState) -> bool:
	if run.history.is_empty():
		return false
	var record: ShiftRecord = run.history[-1]
	if not record.passed or record.inspection == null or record.shift >= run.shift_count():
		return false
	return _bonus_due(run)


## Whether a passed `shift` (1-based), `inspected` or not, earns the bonus ticket on `definition`.
static func _bonus_for(definition: MachineDefinition, shift: int, inspected: bool) -> bool:
	if definition.bonus_after_inspection and inspected:
		return true
	return definition.bonus_extra_shifts.has(shift)


## STAMP DAY follows a listed shift when the run picked fewer registers than its floor and the
## card isn't full.
func _stamp_day_due(run: RunState) -> bool:
	var picked: int = registers_picked(run)
	var floor_count: int = machine.stamp_floor(_shift(run))
	return picked < floor_count and picked < machine.register_cap


## CARD_FULL (REGISTER at the cap) first, then UNLIT (not a chute of the visit's state), then
## EMPTY (nothing to draw). On a boosted shift's ticket or BONUS visit that fell back to Normal,
## REGISTER and UPGRADES show their real reason (CARD_FULL, EMPTY) instead of UNLIT, which would
## promise a boost the visit has just skipped.
func _chute_state(run: RunState, chute: int) -> ChuteState:
	if chute == Chute.REGISTER and registers_picked(run) >= machine.register_cap:
		return ChuteState.CARD_FULL
	if not lit_chutes(_visit).has(chute):
		if BOOSTED_CHUTES.has(chute) and _boost_fell_back(run) and not _can_draw(run, chute):
			return ChuteState.EMPTY
		return ChuteState.UNLIT
	return ChuteState.OPEN if _can_draw(run, chute) else ChuteState.EMPTY


## Whether the waiting visit is a boosted shift's ticket or BONUS visit that fell back to Normal
## (neither REGISTER nor UPGRADES could draw).
func _boost_fell_back(run: RunState) -> bool:
	if _visit == null or _visit.kind == MachineVisit.Kind.STAMP_DAY or _visit.boosted:
		return false
	return machine.is_boosted_shift(_shift(run))


## Whether `chute` has something to draw (REGISTER: below the cap too).
func _can_draw(run: RunState, chute: int) -> bool:
	if chute == Chute.REGISTER and registers_picked(run) >= machine.register_cap:
		return false
	var chute_pools: Array = _snapshot(run).pools(chute)
	return not chute_pools.all(func(pool: Array) -> bool: return pool.is_empty())


## Whether one of the waiting visit's lit chutes can draw.
func _can_draw_lit(run: RunState) -> bool:
	return lit_chutes(_visit).any(func(chute: int) -> bool: return _can_draw(run, chute))


## The ticket's (or the bonus ticket's) visit after the last played shift is BOOSTED: a boosted
## shift, and REGISTER or UPGRADES can draw (else it falls back to Normal).
func _boosted_due(run: RunState) -> bool:
	if not machine.is_boosted_shift(_shift(run)):
		return false
	return BOOSTED_CHUTES.any(func(chute: int) -> bool: return _can_draw(run, chute))


## The first boosted shift after the current one that has a visit after it, or 0.
func _next_boosted_shift(run: RunState) -> int:
	var found: int = 0
	for shift_number: int in machine.boosted_shifts:
		var later: bool = shift_number > _shift(run) and shift_number < run.shift_count()
		if later and (found == 0 or shift_number < found):
			found = shift_number
	return found


## The odds card of a chute's next draw, at the shift's odds level; cached until the state
## changes. During STAMP DAY, REGISTER's is the card its draw was made from, pinned on the visit
## (after a resume, recomputed from the restored state, which is the state the draw was made
## from); during PICK after a chute's first draw, that chute's is the first draw's card (resumed
## too).
func _odds(run: RunState, chute: int) -> MachineOddsCard:
	var stamp_day: bool = _visit != null and _visit.kind == MachineVisit.Kind.STAMP_DAY
	if stamp_day and chute == Chute.REGISTER:
		if _stamp_odds == null:
			_stamp_odds = _visit.stamp_day_odds
		if _stamp_odds == null:
			_stamp_odds = _new_card(run, chute)
		_visit.stamp_day_odds = _stamp_odds
		return _stamp_odds
	if not _cards.has(chute):
		_cards[chute] = _new_card(run, chute)
	return _cards[chute]


func _new_card(run: RunState, chute: int) -> MachineOddsCard:
	var chosen: bool = _visit != null and _visit.chute == chute
	var context: MachineContext = _snapshot(run)
	if chosen and _first_draw:
		# The first draw's card, as shown before it (its guarantee or new-arrival hold).
		context = MachineContext.from_run(
			run,
			machine,
			coupons_first_done and chute != Chute.COUPONS,
			new_items_first_done and chute != Chute.NEW_ITEMS
		)
	return MachineOdds.card(chute, context, odds_level(run))


## The run's snapshot for this state, built once.
func _snapshot(run: RunState) -> MachineContext:
	if _context == null:
		_context = MachineContext.from_run(run, machine, coupons_first_done, new_items_first_done)
	return _context


## The 1-based shift the visits follow: the last played shift's.
func _shift(run: RunState) -> int:
	return run.history[-1].shift if not run.history.is_empty() else 0


func _clear_cache() -> void:
	_context = null
	_cards = {}
	_stamp_odds = null
