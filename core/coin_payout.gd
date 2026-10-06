class_name CoinPayout
extends RefCounted
## The coins a run pays at its end (full build plan 7.1), printed at the bottom of the final
## receipt and added to the profile. Decided with the user (phase 1): coins by shifts passed
## from a table in balance data, plus overtime coins for the run's margin over quota. Every
## amount is balance data; a run that hasn't ended pays nothing. Pure.

var shifts_passed: int = 0
## Coins for the shifts passed (coins_by_shifts_passed).
var shift_coins: int = 0
## The run's overtime: the margin over quota summed over its passed shifts, in euros.
var overtime: int = 0
## One coin per overtime_coin_euros of overtime, at most overtime_coin_max.
var overtime_coins: int = 0


## The payout of a run that ended (won or lost); an empty payout for any other run.
static func for_run(run: RunState) -> CoinPayout:
	var payout: CoinPayout = CoinPayout.new()
	if run.phase != RunState.Phase.WON and run.phase != RunState.Phase.LOST:
		return payout
	for record: ShiftRecord in run.history:
		if record.passed:
			payout.shifts_passed += 1
			payout.overtime += record.total - record.quota
	var table: PackedInt32Array = run.balance.coins_by_shifts_passed
	if not table.is_empty():
		payout.shift_coins = table[mini(payout.shifts_passed, table.size() - 1)]
	if run.balance.overtime_coin_euros > 0:
		payout.overtime_coins = mini(
			floori(float(payout.overtime) / run.balance.overtime_coin_euros),
			run.balance.overtime_coin_max
		)
	return payout


func total() -> int:
	return shift_coins + overtime_coins
