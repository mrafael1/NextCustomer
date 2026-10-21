class_name MachineSteps
extends RefCounted
## Test helper (#77): plays the RECEIPT REWARDS machine's visits of a run as a player could, so
## core tests can get past a passed shift without the screen.


## Plays every waiting visit: chooses NEW ITEMS (else the first lit chute) and bins it; a visit
## that can't be binned (STAMP DAY, REGISTER, UPGRADES) takes its first prize, at the deck limit
## swapping the deck's first card out. True when the run ended its visits (SCORED, or no visit).
static func pass_visits(run: RunState) -> bool:
	while RunState.MACHINE_PHASES.has(run.phase):
		if run.phase == RunState.Phase.MACHINE_CHOOSE:
			if not run.machine.choose(run, first_lit(run, RewardMachine.Chute.NEW_ITEMS)):
				return false
		elif run.machine.can_bin():
			run.machine.bin(run)
		elif take(run, 0) == null:
			return false
	return true


## Passes the visits, then starts the next shift (after the last shift: nothing).
static func next_shift(run: RunState) -> bool:
	return pass_visits(run) and run.next_shift()


## Chooses `chute` on the waiting visit (MACHINE_CHOOSE).
static func choose(run: RunState, chute: int) -> bool:
	return run.machine.choose(run, chute)


## Takes the prize at `index` of the waiting pick, at the deck limit swapping the deck's first
## card out.
static func take(run: RunState, index: int) -> MachineLanding:
	var replaced: CardInstance = null
	if run.machine.needs_replace(run, index):
		replaced = run.deck.cards[0]
	return run.machine.pick(run, index, replaced)


## Chooses REGISTER on the waiting visit and takes `upgrade` when it is drawn (else the first
## register). Returns the register taken, or null.
static func take_register(run: RunState, upgrade: UpgradeDefinition = null) -> UpgradeDefinition:
	if run.phase == RunState.Phase.MACHINE_CHOOSE:
		if not run.machine.choose(run, RewardMachine.Chute.REGISTER):
			return null
	var prizes: Array[MachinePrize] = run.machine.prizes()
	var index: int = 0
	for found: int in range(prizes.size()):
		if prizes[found].upgrade == upgrade:
			index = found
	var landing: MachineLanding = take(run, index)
	return landing.register if landing != null else null


## `preferred` when it is lit, else the first lit chute (NEW ITEMS when none is lit).
static func first_lit(run: RunState, preferred: int) -> int:
	if _lit(run, preferred):
		return preferred
	for chute: int in RewardMachine.CHUTES:
		if _lit(run, chute):
			return chute
	return RewardMachine.Chute.NEW_ITEMS


static func _lit(run: RunState, chute: int) -> bool:
	return run.machine.chute_info(run, chute).state == RewardMachine.ChuteState.OPEN


## `balance` with its own machine copy that holds no STAMP DAY, so a low-quota test run never
## gets a forced register (Big basket would raise its quotas).
static func without_stamp_day(balance: BalanceDefinition) -> BalanceDefinition:
	balance.machine = balance.machine.duplicate() as MachineDefinition
	balance.machine.stamp_day_shifts = PackedInt32Array()
	balance.machine.stamp_day_floor = PackedInt32Array()
	return balance
