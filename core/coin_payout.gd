class_name CoinPayout
extends RefCounted
## The coins a run pays at its end (full build plan 7.1), printed at the bottom of the final
## receipt and added to the profile. Decided with the user (phase 1): coins by shifts passed
## from a table in balance data (the overtime coin for the run's margin over quota went on
## 2026-11-05: a shift far over quota earns a machine ticket instead, OvertimeTickets). Every
## amount is balance data; a run that hasn't ended pays nothing. Pure.

var shifts_passed: int = 0
## Coins for the shifts passed (coins_by_shifts_passed).
var shift_coins: int = 0


## The payout of a run that ended (won or lost); an empty payout for any other run.
static func for_run(run: RunState) -> CoinPayout:
	var payout: CoinPayout = CoinPayout.new()
	if run.phase != RunState.Phase.WON and run.phase != RunState.Phase.LOST:
		return payout
	for record: ShiftRecord in run.history:
		if record.passed:
			payout.shifts_passed += 1
	var table: PackedInt32Array = run.balance.coins_by_shifts_passed
	if not table.is_empty():
		# A won run pays the table's last entry, whatever its slips (v0.68).
		var index: int = payout.shifts_passed
		if run.phase == RunState.Phase.WON:
			index = table.size() - 1
		payout.shift_coins = table[mini(index, table.size() - 1)]
	return payout


func total() -> int:
	return shift_coins
