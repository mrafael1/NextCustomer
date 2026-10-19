class_name BeltChips
extends RefCounted
## The belt items' corner marks and paid chips (#80, step 7; mock-up B2; #75's effect chips
## before it). Marks: one EffectMark per item that has a step EffectChip.qualifies, a fizzle disc
## when one of them fizzled (WASTED), else a check; no count. On a run resumed after its checkout
## every mark shows at once. Planning shows none since #71 (mock-up h1): its stickers
## (PlanningEffects) stack over the items, and the discs come back in the count-up as their steps
## land. The CHECKOUT click clears them (begin_count; #60's
## target markers fly to the same corner) and each comes back with a pop as CountUp.step_landed
## says one of its item's steps landed (land), still shown under reduced motion, without the pop.
## Nothing waits for a mark: the count-up's timing never changes.
##
## Paid chips (PayoutPlaque) show only in the count-up: CountUp.beat_started (follow_beat) makes
## the scanned item's chip the current one, popping with its echo, and settles every other shown
## chip into its small paper face, so earlier chips stay, and the last one settles as the
## monitor shows the total (follow), so the belt ends as a resumed checkout shows it, every chip
## settled. Every number comes from the result and the count-up; nothing here scores.

var _result: ScoreResult
var _views: Array[CardView] = []
## Between begin_count and the next show_all: marks come back as their steps land.
var _counting: bool = false
var _reduced_motion: bool = false
## The steps landed so far on each slot during the count-up.
var _landed: Dictionary[int, PackedInt32Array] = {}


## Follows `count_up`'s landed steps (land) and beats (follow_beat), and `led`'s TOTAL, which
## settles the last current chip.
func follow(count_up: CountUp, led: LedDisplay) -> void:
	count_up.step_landed.connect(land)
	count_up.beat_started.connect(follow_beat)
	led.mode_changed.connect(_on_led_mode)


## With `paid` (a resumed checkout) shows every mark of `result` on the belt items `views` and
## every item's paid chip, settled; else (planning) clears both: planning shows its stickers.
func show_all(result: ScoreResult, views: Array[CardView], paid: bool = false) -> void:
	_keep(result, views)
	_counting = false
	for slot: int in range(views.size()):
		var item: ItemView = _item(slot)
		if item == null:
			continue
		if paid and slot < result.payouts.size():
			item.set_badge_current(false)
			item.show_badge(result.payouts[slot], false)
		else:
			item.hide_badge()
		if paid and slot < result.payouts.size():
			_show_mark(item, EffectChip.step_indices(result, slot))
		else:
			item.clear_mark()


## The CHECKOUT click: clears every mark on `views` and settles every paid chip; land() and
## follow_beat() then bring them back one by one.
func begin_count(result: ScoreResult, views: Array[CardView], reduced_motion: bool) -> void:
	_keep(result, views)
	_counting = true
	_reduced_motion = reduced_motion
	_landed.clear()
	for slot: int in range(views.size()):
		var item: ItemView = _item(slot)
		if item != null:
			item.clear_mark()
			item.hide_badge()
			item.set_badge_current(false)


## Step `index` landed (CountUp.step_landed): when it marks its item, shows the item's mark for
## the steps landed there so far (a check turns into a fizzle disc in place) and pops it, unless
## reduced motion. Returns the mark, or null.
func land(index: int) -> EffectMark:
	if not _counting or _result == null or index < 0 or index >= _result.steps.size():
		return null
	var step: ScoreStep = _result.steps[index]
	if not EffectChip.qualifies(step) or step.slot < 0 or step.slot >= _views.size():
		return null
	var landed: PackedInt32Array = _landed.get(step.slot, PackedInt32Array())
	if landed.has(index):
		return null
	landed.append(index)
	_landed[step.slot] = landed
	var mark: EffectMark = _show_mark(_item(step.slot), landed)
	if mark != null:
		mark.pop(_reduced_motion)
	return mark


## A count-up beat started on `view` (CountUp.beat_started): its paid chip becomes the current
## one (popping with its echo, unless reduced motion) and every other item's settles.
func follow_beat(
	_beat: CountUpBeat, _step: ScoreStep, _line: String, view: CardView, _items: int
) -> void:
	if not _counting:
		return
	for slot: int in range(_views.size()):
		var item: ItemView = _item(slot)
		if item == null:
			continue
		if item == view:
			if not item.badge.visible or not (item.badge as PayoutPlaque).is_current():
				item.set_badge_current(true, not _reduced_motion)
		elif (item.badge as PayoutPlaque).is_current():
			item.set_badge_current(false)


## The count-up's total shows: no item is counted any more, so every paid chip settles.
func _on_led_mode(mode: LedDisplay.Mode) -> void:
	if not _counting or mode != LedDisplay.Mode.TOTAL:
		return
	for slot: int in range(_views.size()):
		var item: ItemView = _item(slot)
		if item != null and (item.badge as PayoutPlaque).is_current():
			item.set_badge_current(false)


func _keep(result: ScoreResult, views: Array[CardView]) -> void:
	_result = result
	_views = views


## Shows `item`'s mark for the steps at `indices` (a fizzle disc when one fizzled), or clears it
## when there are none. Returns the mark, or null.
func _show_mark(item: ItemView, indices: PackedInt32Array) -> EffectMark:
	if item == null:
		return null
	if indices.is_empty():
		item.clear_mark()
		return null
	return item.show_mark(EffectChip.fizzles(_result, indices))


## The belt item in `slot`, or null (not an item, or freed by a refresh).
func _item(slot: int) -> ItemView:
	if not is_instance_valid(_views[slot]):
		return null
	return _views[slot] as ItemView
