class_name ShiftLimits
extends RefCounted
## One shift's limits (plan sections 3.1 and 3.8): its slots, its redraws, its hand and its quota.
## Built when the shift starts from the balance data plus the run modifiers of every owned upgrade
## (Extra redraw, Big basket), so an upgrade picked after a shift applies from the next one, and
## the quota never changes during a shift. The top bar, the pass check, the run history and the
## overtime coins all read this one quota. The shift's day events (inspections and boons, v0.69)
## add their own modifiers on top (Short belt's slot, Till jam's redraw, Small baskets' hand item,
## Rush hour's quota percent), so a closed slot is counted against what the run has, never a fixed
## number.

## The row's slots: any card fits any slot (plan v0.46).
var slot_count: int = 0
## Slots the shift's inspections closed, counted against what the run has (for the screen).
var closed_slots: int = 0
var redraws: int = 0
## The redraws the shift has without any upgrade's (the balance's and its day events'): a redraw
## past them is Extra redraw's (ScoreCredits).
var own_redraws: int = 0
## The hand's items: the balance's hand_size plus the day events' hand_size_delta (at least 1).
var hand_size: int = 0
var quota: int = 0


## The limits of the 0-based `shift_index` with these owned upgrades and the shift's day events.
static func for_shift(
	balance: BalanceDefinition,
	upgrades: Array[UpgradeDefinition],
	shift_index: int,
	inspections: Array[InspectionDefinition] = []
) -> ShiftLimits:
	var limits: ShiftLimits = ShiftLimits.new()
	limits.slot_count = balance.slot_count
	limits.redraws = balance.base_redraws
	limits.own_redraws = balance.base_redraws
	limits.hand_size = balance.hand_size
	for upgrade: UpgradeDefinition in upgrades:
		limits.slot_count += upgrade.extra_slots
		limits.redraws += upgrade.extra_redraws
	var run_slots: int = maxi(limits.slot_count, 1)
	var quota_percent: int = 0
	for inspection: InspectionDefinition in inspections:
		limits.slot_count += inspection.extra_slots
		limits.redraws += inspection.extra_redraws
		limits.own_redraws += inspection.extra_redraws
		limits.hand_size += inspection.hand_size_delta
		quota_percent += inspection.quota_percent
	limits.slot_count = maxi(limits.slot_count, 1)
	limits.closed_slots = maxi(run_slots - limits.slot_count, 0)
	limits.redraws = maxi(limits.redraws, 0)
	limits.own_redraws = maxi(limits.own_redraws, 0)
	limits.hand_size = maxi(limits.hand_size, 1)
	# A balance without that shift's quota (a test's, or the simulator's row search) has no quota.
	if shift_index >= 0 and shift_index < balance.quotas.size():
		limits.quota = with_percent(balance.quotas[shift_index], quota_percent)
	return limits


## A quota (`amount`) changed by `percent` (Rush hour's +10, Quiet morning's -10), rounded to
## whole euros and never below 1; 0% or a quota of 0 (the simulator's --quotas=0) keeps it.
static func with_percent(amount: int, percent: int) -> int:
	if percent == 0 or amount <= 0:
		return amount
	return maxi(roundi(amount * (100 + percent) / 100.0), 1)
