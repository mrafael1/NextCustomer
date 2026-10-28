class_name RewardMachine
extends RefCounted
## The RECEIPT REWARDS machine (#77, build spec 1.6): after a passed shift that isn't the last,
## the shift's ticket buys one visit, and a passed inspected shift adds the bonus ticket's visit.
## A visit chooses a chute, draws its prizes (MachineDraw, with the run's RNG) and picks one or
## bins them. Odds come from MachineOdds and never use the RNG.
##
## One machine, two chutes (#108, v0.61, decided with the user on 2026-10-25): NEW ITEMS (new cards
## for the cart: products, which can arrive BIG or GOLDEN, and a coupon) and UPGRADE (improve what
## you own: loyalty perks, new or a level-up of an owned one up to LV 3, and item upgrades). Every
## visit offers both. The machine is CLASSIC, or PREMIUM on the ticket's visit after one of
## MachineDefinition.premium_shifts and on the BONUS visit that follows it: PREMIUM raises every
## drop to at least premium_min_rarity and every product with a chain to at least
## premium_min_tier. Every visit after a shift draws at that shift's odds level
## (MachineDefinition.odds_level_after): rarity rises with the run's progress, not with use.
## STAMP DAY (the free loyalty visit before v0.61) is gone.
##
## The machine holds the run's RNG (a shared reference) but never the run: methods that read or
## change the run take it. It has its own stage and never writes RunState.phase. Cards from a pick
## go into the deck now; loyalty perks apply from the next shift (ShiftLimits reads the upgrades
## when a shift starts), so the machine keeps the perks the scored shift was played with
## (played_upgrades): a level-up changes a box in place.

enum Chute { NEW_ITEMS, UPGRADE }
## OPEN: can draw. EMPTY: nothing to draw (UPGRADE: "NOTHING TO IMPROVE").
enum ChuteState { OPEN, EMPTY }
## IDLE: no visit. CHOOSE: a visit waits for its chute. PICK: its prizes wait for a pick or bin.
enum Stage { IDLE, CHOOSE, PICK }

const CHUTES: Array[int] = [Chute.NEW_ITEMS, Chute.UPGRADE]
## A visit's machine state, as logged (machine_visit's `state`; before v0.61 "normal", "boosted"
## and "stamp_day").
const STATE_CLASSIC := "classic"
const STATE_PREMIUM := "premium"
const STAGE_NAMES: Array[String] = ["idle", "choose", "pick"]

var machine: MachineDefinition
var stage: Stage = Stage.IDLE
## The run's first coupon draw / NEW ITEMS draw happened (spent at the draw, picked or binned).
## Both are spent by NEW ITEMS since v0.61 (they differ only in a save from before it).
var coupons_first_done: bool = false
var new_items_first_done: bool = false
## The loyalty perks the last scored shift was played with (a copy of the run's upgrades at the
## checkout; a resume re-scores the row with them).
var played_upgrades: Array[UpgradeDefinition] = []
var _rng: RandomNumberGenerator
var _visit: MachineVisit
## The visits still to come this shift after the current one (MachineVisit.Kind).
var _queue: Array[int] = []
## Per-state caches, cleared on every change: the run snapshot and the odds card per chute.
var _context: MachineContext
var _cards: Dictionary = {}
## The visit's draw was the run's first NEW ITEMS draw (it spent the first-draw flags): its odds
## card during PICK is still the first draw's (saved, so a resume shows it too).
var _first_draw: bool = false


func _init(machine_definition: MachineDefinition, rng: RandomNumberGenerator) -> void:
	machine = machine_definition
	_rng = rng


## RunState.checkout on a passed shift that isn't the last: keeps the played perks, queues the
## ticket's visit (PREMIUM after a premium shift) and the bonus ticket's when due (PREMIUM by the
## same rule), and waits for the ticket's chute. A visit none of whose chutes can draw is skipped:
## the next queued one starts, else the machine idles.
func begin_after_checkout(run: RunState) -> void:
	clear_visits()
	if run.history.is_empty():
		return
	var record: ShiftRecord = run.history[-1]
	# Kept after a write-up too (v0.65), which gets no visit: the save checks the perks against it.
	played_upgrades = run.upgrades.duplicate()
	if not record.passed or record.shift >= run.shift_count():
		return
	_visit = MachineVisit.new(MachineVisit.Kind.TICKET)
	_visit.premium = machine.is_premium_shift(record.shift)
	if _bonus_due(run):
		_queue.append(MachineVisit.Kind.BONUS)
	stage = Stage.CHOOSE
	if not _can_draw_any(run):
		_visit = null
		_next_visit(run)


## One chute's state for the UI: whether it can draw, and its exact odds card.
func chute_info(run: RunState, chute: int) -> MachineChuteInfo:
	var info: MachineChuteInfo = MachineChuteInfo.new()
	info.state = _chute_state(run, chute)
	info.odds = _odds(run, chute)
	info.premium = is_premium()
	info.cart_full = chute == Chute.NEW_ITEMS and run.deck.size() >= run.balance.deck_limit
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
	if chute != Chute.NEW_ITEMS:
		return
	info.first_pick_spent_coupon = true
	for earlier: ShiftRecord in run.history:
		if earlier == record:
			break
		for visit: MachineVisit in earlier.visits:
			if visit.chute == Chute.NEW_ITEMS:
				info.first_pick_spent_coupon = false
				return


## Chooses the visit's chute (CHOOSE only, an OPEN chute): draws its prizes with the run's RNG.
## The run's first NEW ITEMS draw spends both first-draw flags here, whatever is done with the
## prizes.
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
		chute == Chute.NEW_ITEMS and (not coupons_first_done or not new_items_first_done)
	)
	if chute == Chute.NEW_ITEMS:
		coupons_first_done = true
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
		var owned: int = PerkLevels.owned_index(run.upgrades, prize.upgrade)
		found.level_up = PerkLevels.is_level_up(prize.upgrade) and owned != -1
		found.box_index = owned if found.level_up else run.upgrades.size()
		if found.level_up:
			found.from_level = run.upgrades[owned].level_number()
	return found


## Any visit's prizes can be binned (both chutes, since v0.61).
func can_bin() -> bool:
	return stage == Stage.PICK and _visit != null and CHUTES.has(_visit.chute)


## The prize adds a card and the cart is at the deck limit: the pick must swap a card out.
func needs_replace(run: RunState, index: int) -> bool:
	var prize: MachinePrize = _prize(index)
	return prize != null and prize.adds_card() and run.deck.size() >= run.balance.deck_limit


## Takes the prize at `index`: adds the card (swapping `replaced` out: needed at the deck limit,
## and since 2026-10-28 a choice below it too), stamps
## a new perk (refused at the cap) or levels up an owned one in its box, or upgrades the copies;
## records the visit and moves on. Null when refused.
func pick(run: RunState, index: int, replaced: CardInstance = null) -> MachineLanding:
	var prize: MachinePrize = _prize(index)
	if prize == null or not _can_take(run, prize, index, replaced):
		return null
	var landing: MachineLanding = MachineLanding.new()
	landing.prize = prize
	landing.cart_before = run.deck.size()
	match prize.kind:
		MachinePrize.Kind.PRODUCT, MachinePrize.Kind.COUPON:
			if replaced != null:
				run.deck.remove_card(replaced)
				landing.replaced = replaced
				_visit.replaced = replaced.definition
			landing.added = run.deck.add_card(prize.card)
		MachinePrize.Kind.REGISTER:
			landing.register = prize.upgrade
			landing.level_up = PerkLevels.is_level_up(prize.upgrade)
			landing.box_index = run.upgrades.size()
			if landing.level_up:
				landing.box_index = PerkLevels.owned_index(run.upgrades, prize.upgrade)
				run.upgrades[landing.box_index] = prize.upgrade
			else:
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


## New loyalty perks picked from the machine this run (each stamped a box; before v0.61 STAMP
## DAY's too): a level-up never counts, nor does a starting deck's starting_upgrade, nor a
## retired perk's pick (ContentLookup.is_retired: RunSave drops it from the run, so its loyalty box
## is free again).
static func registers_picked(run: RunState) -> int:
	var found: int = 0
	for record: ShiftRecord in run.history:
		for upgrade: UpgradeDefinition in record.perks_added():
			if not ContentLookup.is_retired(upgrade):
				found += 1
	return found


## The odds level the visits after the last played shift draw at (0 before any checkout).
func odds_level(run: RunState) -> int:
	return machine.odds_level_after(_shift(run))


## Whether the waiting visit is PREMIUM.
func is_premium() -> bool:
	return _visit != null and _visit.premium


## A visit's machine state, as logged (STATE_CLASSIC, STATE_PREMIUM).
static func state_of(visit: MachineVisit) -> String:
	return state_for(visit.premium)


## The machine state of a visit that is `premium` or not; also for a saved visit's fields (the
## simulator's records).
static func state_for(premium: bool) -> String:
	return STATE_PREMIUM if premium else STATE_CLASSIC


## The machine's state for the run save (RunSave).
func to_dictionary() -> Dictionary:
	return {
		"coupons_first_done": coupons_first_done,
		"new_items_first_done": new_items_first_done,
		"played_upgrades":
		played_upgrades.map(func(upgrade: UpgradeDefinition) -> String: return String(upgrade.id)),
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
	# A visit still waiting for its pick never offers a retired register (a save made before
	# the rule change that retired it).
	if visit != null and visit.picked == -1:
		visit.drop_retired_prizes()
	var valid: bool = (
		reader.ok
		and saved_queue.all(func(kind: int) -> bool: return kind > MachineVisit.Kind.TICKET)
		and visit_data is Dictionary
		and _fits_stage(saved_stage, visit, visit_data, saved_queue)
	)
	var first_coupons: bool = reader.flag("coupons_first_done")
	var first_new_items: bool = reader.flag("new_items_first_done")
	var played: Array[UpgradeDefinition] = reader.upgrades("played_upgrades")
	# Left out by saves made before it was added: not a first draw.
	var first_draw: Variant = data.get("first_draw", false)
	if not valid or not reader.ok or not first_draw is bool:
		return false
	coupons_first_done = first_coupons
	new_items_first_done = first_new_items
	played_upgrades = played
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
				visit != null and visit.prizes.is_empty() and visit.chute == MachineVisit.NO_CHUTE
			)
		Stage.PICK:
			return (
				visit != null
				and CHUTES.has(visit.chute)
				and not visit.prizes.is_empty()
				and visit.prizes.size() <= machine.prizes_per_visit
				and visit.picked == -1
				and not visit.binned
			)
	return false


## The prize at a reveal index of the visit waiting for its pick, or null.
func _prize(index: int) -> MachinePrize:
	if stage != Stage.PICK or _visit == null or index < 0 or index >= _visit.prizes.size():
		return null
	return _visit.prizes[index]


## A level-up needs the level below it owned; a new perk a free box and its family not owned.
func _can_take(run: RunState, prize: MachinePrize, index: int, replaced: CardInstance) -> bool:
	match prize.kind:
		MachinePrize.Kind.REGISTER:
			if PerkLevels.is_level_up(prize.upgrade):
				return PerkLevels.owns_previous(run.upgrades, prize.upgrade)
			return (
				registers_picked(run) < machine.register_cap
				and PerkLevels.owned_index(run.upgrades, prize.upgrade) == -1
			)
		MachinePrize.Kind.UPGRADE:
			return not _targets(run, prize).is_empty()
	if replaced != null:
		return run.deck.cards.has(replaced)
	return not needs_replace(run, index)


func _targets(run: RunState, prize: MachinePrize) -> Array[CardInstance]:
	return ItemUpgrades.targets(machine.item_upgrades, run.deck, prize.card, prize.rarity)


## The card an item upgrade prize turns a copy into.
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


## Starts the next queued visit that has something to draw (a BONUS visit none of whose chutes
## can draw is skipped), else idles. A BONUS visit after a premium shift is PREMIUM too (v0.53).
func _next_visit(run: RunState) -> void:
	while not _queue.is_empty():
		var kind: int = _queue.pop_front()
		var record: ShiftRecord = run.history[-1]
		var why: String = String(record.inspection.id) if record.inspection != null else ""
		_visit = MachineVisit.new(kind as MachineVisit.Kind, why)
		_visit.premium = machine.is_premium_shift(record.shift)
		stage = Stage.CHOOSE
		if _can_draw_any(run):
			return
		_visit = null
	stage = Stage.IDLE


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
## shift would make the machine PREMIUM after it, as begin_after_checkout decides it at that
## checkout. False on the last shift (no machine follows it).
func premium_if_passed(run: RunState) -> bool:
	return not run.is_last_shift() and machine.is_premium_shift(run.shift_index + 1)


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


func _chute_state(run: RunState, chute: int) -> ChuteState:
	return ChuteState.OPEN if _can_draw(run, chute) else ChuteState.EMPTY


## Whether `chute` has something to draw on the waiting visit.
func _can_draw(run: RunState, chute: int) -> bool:
	var chute_pools: Array = _snapshot(run).pools(chute)
	return not chute_pools.all(func(pool: Array) -> bool: return pool.is_empty())


## Whether one of the chutes can draw.
func _can_draw_any(run: RunState) -> bool:
	return CHUTES.any(func(chute: int) -> bool: return _can_draw(run, chute))


## The odds card of a chute's next draw, at the shift's odds level; cached until the state
## changes. During PICK after the run's first NEW ITEMS draw, its card is the first draw's
## (resumed too).
func _odds(run: RunState, chute: int) -> MachineOddsCard:
	if not _cards.has(chute):
		_cards[chute] = _new_card(run, chute)
	return _cards[chute]


func _new_card(run: RunState, chute: int) -> MachineOddsCard:
	var chosen: bool = _visit != null and _visit.chute == chute
	var context: MachineContext = _snapshot(run)
	if chosen and _first_draw:
		# The first draw's card, as shown before it (its first-offer coupon, its new arrival; a
		# save from before v0.61 whose coupon draw was spent shows the first-offer coupon too).
		context = MachineContext.from_run(run, machine, false, false, is_premium())
	return MachineOdds.card(chute, context, odds_level(run))


## The run's snapshot for this state, built once.
func _snapshot(run: RunState) -> MachineContext:
	if _context == null:
		_context = MachineContext.from_run(
			run, machine, coupons_first_done, new_items_first_done, is_premium()
		)
	return _context


## The 1-based shift the visits follow: the last played shift's.
func _shift(run: RunState) -> int:
	return run.history[-1].shift if not run.history.is_empty() else 0


func _clear_cache() -> void:
	_context = null
	_cards = {}
