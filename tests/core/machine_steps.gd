class_name MachineSteps
extends RefCounted
## Test helper (#77): plays the RECEIPT REWARDS machine's visits of a run as a player could, so
## core tests can get past a passed shift without the screen.


## Plays every waiting visit: chooses NEW ITEMS (else the first open chute, UPGRADE) and bins it
## (every visit can be binned since v0.61); a visit that can't be binned takes its first prize, at
## the deck limit swapping the deck's first card out. True when the run ended its visits (SCORED,
## or no visit).
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


## Chooses UPGRADE on the waiting visit and takes the loyalty perk `upgrade` when it is drawn
## (else the first loyalty perk drawn). Returns the perk taken, or null (no perk drawn).
static func take_register(run: RunState, upgrade: UpgradeDefinition = null) -> UpgradeDefinition:
	if run.phase == RunState.Phase.MACHINE_CHOOSE:
		if not run.machine.choose(run, RewardMachine.Chute.UPGRADE):
			return null
	var index: int = register_index(run, upgrade)
	if index == -1:
		return null
	var landing: MachineLanding = take(run, index)
	return landing.register if landing != null else null


## The reveal index of the loyalty perk `upgrade` in the waiting pick, else of its first loyalty
## perk (null `upgrade`, or not drawn); -1 when it holds none.
static func register_index(run: RunState, upgrade: UpgradeDefinition = null) -> int:
	var prizes: Array[MachinePrize] = run.machine.prizes()
	var index: int = -1
	for found: int in range(prizes.size()):
		if prizes[found].kind != MachinePrize.Kind.REGISTER:
			continue
		if index == -1 or prizes[found].upgrade == upgrade:
			index = found
		if prizes[found].upgrade == upgrade:
			break
	return index


## Whether the waiting pick offers the loyalty perk `upgrade`.
static func offers(run: RunState, upgrade: UpgradeDefinition) -> bool:
	return run.machine.prizes().any(
		func(prize: MachinePrize) -> bool: return prize.upgrade == upgrade
	)


## `preferred` when it is open, else the first open chute (NEW ITEMS when none is open).
static func first_lit(run: RunState, preferred: int) -> int:
	if _lit(run, preferred):
		return preferred
	for chute: int in RewardMachine.CHUTES:
		if _lit(run, chute):
			return chute
	return RewardMachine.Chute.NEW_ITEMS


static func _lit(run: RunState, chute: int) -> bool:
	return run.machine.chute_info(run, chute).state == RewardMachine.ChuteState.OPEN


## `balance` with its own machine copy that is PREMIUM (#108: a rarity boost) after exactly the
## 1-based `shifts`.
static func premium_on(balance: BalanceDefinition, shifts: Array[int]) -> BalanceDefinition:
	balance.machine = balance.machine.duplicate() as MachineDefinition
	balance.machine.premium_shifts = PackedInt32Array(shifts)
	return balance


## `run`'s machine on its own definition copy that is PREMIUM after exactly the 1-based `shifts`.
static func premium_run(run: RunState, shifts: Array[int]) -> void:
	run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
	run.machine.machine.premium_shifts = PackedInt32Array(shifts)


## `run`'s machine on its own definition copy that gives a passed inspection a BONUS visit, with no
## bonus extra shifts (the machine before v0.68's Payday; the data's has neither).
static func bonus_after_inspection(run: RunState) -> void:
	run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
	run.machine.machine.bonus_after_inspection = true
	run.machine.machine.bonus_extra_shifts = PackedInt32Array()
