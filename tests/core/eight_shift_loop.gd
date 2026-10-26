class_name EightShiftLoop
extends RefCounted
## The run's loop before v0.65's rework, for tests that script an 8-shift run around it: shifts 3,
## 5 and 7 inspected (one inspection each), no Manager's reviews, a miss ends the run (no
## write-ups), and the machine PREMIUM after shifts 3, 5 and 7 with the 8-shift odds levels. The
## live balance holds the 12-shift loop (full build plan section 5.3); these tests are about other
## things, and keep their runs.


## `balance` (a copy the test owns) with the 8-shift loop, its machine a copy too. Returns it.
static func apply(balance: BalanceDefinition) -> BalanceDefinition:
	balance.inspection_shifts = PackedInt32Array([3, 5, 7])
	balance.review_shifts = PackedInt32Array()
	balance.write_up_limit = 0
	if balance.machine != null:
		var machine: MachineDefinition = balance.machine.duplicate()
		machine.premium_shifts = PackedInt32Array([3, 5, 7])
		machine.shift_odds_levels = PackedInt32Array([0, 0, 1, 1, 2, 2, 3, 3])
		balance.machine = machine
	return balance
