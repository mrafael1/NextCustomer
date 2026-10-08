class_name ShiftLimits
extends RefCounted
## One shift's limits (plan sections 3.1 and 3.8): its product and coupon-only slots, its
## redraws and its quota. Built when the shift starts from the balance data plus the run
## modifiers of every owned upgrade (Extra redraw, Extra coupon slot, Big basket), so an
## upgrade picked after a shift applies from the next one, and the quota never changes during
## a shift. The top bar, the pass check, the run history and the overtime coins all read this
## one quota. Inspections that change capacity add their own modifiers in phase 2 (#39).

var slot_count: int = 0
var coupon_slot_count: int = 0
var redraws: int = 0
var quota: int = 0


## The limits of the 0-based `shift_index` with these owned upgrades.
static func for_shift(
	balance: BalanceDefinition, upgrades: Array[UpgradeDefinition], shift_index: int
) -> ShiftLimits:
	var limits: ShiftLimits = ShiftLimits.new()
	limits.slot_count = balance.slot_count
	limits.coupon_slot_count = balance.coupon_slot_count
	limits.redraws = RunState.BASE_REDRAWS
	var quota_percent: int = 0
	for upgrade: UpgradeDefinition in upgrades:
		limits.slot_count += upgrade.extra_slots
		limits.coupon_slot_count += upgrade.extra_coupon_slots
		limits.redraws += upgrade.extra_redraws
		quota_percent += upgrade.quota_percent
	limits.slot_count = maxi(limits.slot_count, 1)
	limits.coupon_slot_count = maxi(limits.coupon_slot_count, 0)
	limits.redraws = maxi(limits.redraws, 0)
	# A balance without that shift's quota (a test's, or the simulator's row search) has no quota.
	if shift_index >= 0 and shift_index < balance.quotas.size():
		limits.quota = raised_quota(balance.quotas[shift_index], quota_percent)
	return limits


## A quota raised by `percent`, rounded up to whole euros (Big basket: +15% turns 17 into 20).
## Quotas and percents are small whole numbers, so the division is exact enough to round.
static func raised_quota(base_quota: int, percent: int) -> int:
	return ceili(base_quota * (100 + percent) / 100.0) if percent > 0 else base_quota


func card_limit() -> int:
	return slot_count + coupon_slot_count
