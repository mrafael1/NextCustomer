class_name CaptureWeeks
extends RefCounted
## The screen capture's four-week options (v0.95), kept out of ScreenCapture so it stays under
## gdlint's file length.
##
## `--at-shift=<n>`: the fixed shift is shift n in place of shift 5 (`--at-shift=13 --week` shows
## week 4's time card, `--at-shift=16` the top bar on the final review), its day events the live
## schedule's (the week the run draws) in place of the fixed shift's Short belt; the file gets
## shift<n>_.
## `--results=<won|lost>`: a scripted run's final receipt over the shift screen, printed in full:
## `won` a won run of every shift (each passed with some overtime, every ticket and payday visit
## taken, each day's events by the live schedule), `lost` one that slipped on shift 2 and was lost
## on LOST_SHIFT. The file gets results_<won|lost>_.

const SHIFT_ARGUMENT := "--at-shift="
const RESULTS_ARGUMENT := "--results="
## The shift the `lost` run is lost on, and the one it slipped on.
const LOST_SHIFT := 11
const SLIP_SHIFT := 2
## The scripted run's own RNG seed (its events, margins and prizes).
const SCRIPT_SEED := 7
## The loyalty perks the scripted run starts with.
const STARTING_PERKS: Array[String] = ["coupon_engine"]


## The fixed shift's 1-based number: --at-shift's, else `default_shift`.
static func shift(default_shift: int) -> int:
	var value: String = _argument(SHIFT_ARGUMENT)
	return value.to_int() if value.is_valid_int() and value.to_int() > 0 else default_shift


## Whether --at-shift picks the fixed shift.
static func at_shift() -> bool:
	return _argument(SHIFT_ARGUMENT).is_valid_int()


## The file name part of these options.
static func file_part() -> String:
	var part: String = ""
	if _argument(SHIFT_ARGUMENT).is_valid_int():
		part += "shift%s_" % _argument(SHIFT_ARGUMENT)
	if not _argument(RESULTS_ARGUMENT).is_empty():
		part += "results_%s_" % _argument(RESULTS_ARGUMENT)
	return part


## With --results, starts a run on `screen` (seed `seed_value`), scripts its history and shows its
## final receipt, printed in full; returns whether it did.
static func show_results(screen: ShiftScreen, seed_value: int) -> bool:
	var spec: String = _argument(RESULTS_ARGUMENT)
	if spec.is_empty():
		return false
	screen.start_new_run(seed_value)
	screen.debug_show_shift()
	screen._week.skip()
	var run: RunState = screen.run
	script_run(run, spec == "lost")
	var result: ScoreResult = ScoreResult.new()
	result.total = run.history[-1].total
	screen._show_results(result)
	screen._results.skip_printing()
	return true


## Gives `run` a played history by the live schedule (see --results) and ends it.
static func script_run(run: RunState, lost: bool) -> void:
	var balance: BalanceDefinition = run.balance
	var machine: MachineDefinition = balance.machine
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SCRIPT_SEED
	var upgrades: Array[UpgradeDefinition] = []
	for id: String in STARTING_PERKS:
		upgrades.append(load("res://data/upgrades/%s.tres" % id) as UpgradeDefinition)
	var last: int = LOST_SHIFT if lost else run.shift_count()
	var history: Array[ShiftRecord] = []
	for shift_number: int in range(1, last + 1):
		var events: Array[InspectionDefinition] = _events(balance, shift_number, rng)
		var percent: int = 0
		for event: InspectionDefinition in WeekSchedule.events_for(balance, shift_number, events):
			percent += event.quota_percent
		var quota: int = ShiftLimits.with_percent(balance.quotas[shift_number - 1], percent)
		var total: int = quota + rng.randi_range(1, maxi(floori(quota / 4.0), 2))
		if lost and (shift_number == SLIP_SHIFT or shift_number == last):
			total = quota - rng.randi_range(3, 12)
		var record: ShiftRecord = ShiftRecord.new(shift_number, quota, total)
		record.inspections = events
		if record.passed and shift_number < run.shift_count():
			record.visits.append(_ticket(machine, rng, shift_number))
			if machine.is_payday_shift(shift_number):
				var perk: UpgradeDefinition = _perk(machine, upgrades, rng)
				record.visits.append(_premium(perk))
				upgrades.append(perk)
		history.append(record)
	run.history = history
	run.upgrades = upgrades
	run.shift_index = last - 1
	run.limits.quota = history[-1].quota
	run.phase = RunState.Phase.LOST if lost else RunState.Phase.WON


## A shift's day events by the live schedule: its inspections, then its boon.
static func _events(
	balance: BalanceDefinition, shift_number: int, rng: RandomNumberGenerator
) -> Array[InspectionDefinition]:
	var events: Array[InspectionDefinition] = []
	var maluses: Array[InspectionDefinition] = balance.inspection_pool.duplicate()
	for _index: int in range(InspectionSchedule.count_for(balance, shift_number)):
		events.append(maluses.pop_at(rng.randi_range(0, maluses.size() - 1)))
	var boons: Array[InspectionDefinition] = balance.boon_pool
	for _index: int in range(InspectionSchedule.boon_count_for(balance, shift_number)):
		events.append(boons[rng.randi_range(0, boons.size() - 1)])
	return events


## The ticket after a shift: NEW ITEMS (a rare product, or a coupon every 4th shift) or, every
## third shift, an UPGRADE step of a staple.
static func _ticket(
	machine: MachineDefinition, rng: RandomNumberGenerator, shift_number: int
) -> MachineVisit:
	var visit: MachineVisit = MachineVisit.new()
	var prize: MachinePrize
	if shift_number % 3 == 0:
		visit.chute = RewardMachine.Chute.UPGRADE
		var chains: Array[ItemUpgradeDefinition] = machine.item_upgrades
		var chain: ItemUpgradeDefinition = chains[rng.randi_range(0, chains.size() - 1)]
		prize = MachinePrize.new(
			MachinePrize.Kind.UPGRADE, MachinePrize.Rarity.COMMON, chain.product
		)
	else:
		visit.chute = RewardMachine.Chute.NEW_ITEMS
		var coupon: bool = shift_number % 4 == 0
		var pool: Array[CardDefinition] = machine.rare_coupons if coupon else machine.rare_products
		var card: CardDefinition = pool[rng.randi_range(0, pool.size() - 1)]
		var kind: MachinePrize.Kind = (
			MachinePrize.Kind.COUPON if coupon else MachinePrize.Kind.PRODUCT
		)
		prize = MachinePrize.new(kind, MachinePrize.Rarity.RARE, card)
	var drawn: Array[MachinePrize] = [prize]
	visit.set_drawn(drawn)
	visit.picked = 0
	return visit


## A payday's PREMIUM visit, its loyalty perk taken.
static func _premium(perk: UpgradeDefinition) -> MachineVisit:
	var visit: MachineVisit = MachineVisit.new(MachineVisit.Kind.BONUS, "payday")
	visit.premium = true
	visit.chute = RewardMachine.Chute.UPGRADE
	var drawn: Array[MachinePrize] = [
		MachinePrize.new(MachinePrize.Kind.REGISTER, MachinePrize.Rarity.RARE, null, perk)
	]
	visit.set_drawn(drawn)
	visit.picked = 0
	return visit


## A machine loyalty perk the run doesn't own yet.
static func _perk(
	machine: MachineDefinition, owned: Array[UpgradeDefinition], rng: RandomNumberGenerator
) -> UpgradeDefinition:
	var left: Array[UpgradeDefinition] = machine.rare_upgrades.filter(
		func(perk: UpgradeDefinition) -> bool: return not owned.has(perk)
	)
	return left[rng.randi_range(0, left.size() - 1)]


static func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
