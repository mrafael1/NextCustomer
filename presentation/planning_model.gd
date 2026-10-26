class_name PlanningModel
extends RefCounted
## What the belt shows while planning (#71, mock-up h1, H1_BUILD_SPEC.md sections 2, 5 and 7):
## one PlanningSlot per filled slot (stickers, pay, halo, stamp) and the rail strips between
## the items, all from one EffectGraph of RunState.preview()'s ScoreResult plus its payouts and
## the cards' bases. The UI never scores: every number here is a step's value, a link's gain or
## a payout. Pure data: no Node.

enum Pay { PLAIN, BOOSTED, LOWERED, DENIED, ZERO }
enum Glyph { NONE, FIZZLE, WARNING }

## The pay tag's text.
const PAY_TEXT := "€%d"
## The links that make rail strips.
const STRIP_KINDS: Array[EffectLink.Kind] = [
	EffectLink.Kind.BONUS,
	EffectLink.Kind.STAMP,
	EffectLink.Kind.COPY,
	EffectLink.Kind.FIZZLE,
]

var graph: EffectGraph
## One per slot of the row, in slot order.
var slots: Array[PlanningSlot] = []
## One per giver slot with cross-item links, in giver order, with lanes assigned.
var strips: Array[RailStripSpec] = []


## The model of `result` for `row` (the cards in slot order) under the run's `upgrades` and the
## shift's `inspections` (for the badges' and stamps' names), with `tuning`'s halo ratios.
static func build(
	result: ScoreResult,
	row: Array[CardDefinition],
	upgrades: Array[UpgradeDefinition],
	inspections: Array[InspectionDefinition],
	tuning: PlanningTuning
) -> PlanningModel:
	var model: PlanningModel = PlanningModel.new()
	model.graph = EffectGraph.build(result)
	if result == null:
		return model
	var causes: CauseNames = CauseNames.new(row, upgrades, inspections)
	for slot: int in range(row.size()):
		var payout: int = result.payouts[slot] if slot < result.payouts.size() else 0
		model.slots.append(_slot(model.graph, slot, row[slot], payout, causes, tuning))
	var names: PackedStringArray = PackedStringArray()
	for card: CardDefinition in row:
		names.append(card.display_name)
	model.strips = _strips(model.graph, names)
	assign_lanes(model.strips)
	return model


## The rail strip of the item at `slot` in `result` (what it gives the other items), or null when
## it gives none: a belt item's scan prints it as its "gives" line (ScanController). `names` are
## the row's display names in slot order.
static func strip_of(result: ScoreResult, slot: int, names: PackedStringArray) -> RailStripSpec:
	for spec: RailStripSpec in _strips(EffectGraph.build(result), names):
		if spec.giver_slot == slot:
			return spec
	return null


## Gives each strip its lane (section 5.2): sorted by (lo, giver slot), a strip takes lane 0
## when no strip already in lane 0 shares a slot with it, else lane 1 likewise, else -1
## (overflow, drawn only on hover).
static func assign_lanes(specs: Array[RailStripSpec]) -> void:
	var order: Array[RailStripSpec] = specs.duplicate()
	order.sort_custom(
		func(a: RailStripSpec, b: RailStripSpec) -> bool:
			if a.lo() != b.lo():
				return a.lo() < b.lo()
			return a.giver_slot < b.giver_slot
	)
	var lanes: Array[Array] = [[], []]
	for strip: RailStripSpec in order:
		strip.lane = -1
		for lane: int in range(lanes.size()):
			var free: bool = lanes[lane].all(
				func(other: RailStripSpec) -> bool: return not strip.conflicts(other)
			)
			if free:
				strip.lane = lane
				lanes[lane].append(strip)
				break


## The lanes of the hot strips (section 5.3) while an item F is hovered, from `hot` (giver slot:
## -1 for F's own strip, else F's slot, for a strip giving to F): giver slot to lane, 0 or 1. Every
## hot strip spans F, so no two can share a lane and at most two are drawn. F's own strip takes
## lane 0 first; the strips giving to F follow by their gain to F (largest first, then by giver
## slot), each in its calm lane when that is free, else in the other one. A strip left without a
## lane is not drawn hot: it stays calm and dims, and F's stickers still carry its badge.
static func hot_lanes(
	specs: Array[RailStripSpec], hot: Dictionary[int, int]
) -> Dictionary[int, int]:
	var order: Array[RailStripSpec] = []
	for spec: RailStripSpec in specs:
		if hot.has(spec.giver_slot):
			order.append(spec)
	order.sort_custom(
		func(a: RailStripSpec, b: RailStripSpec) -> bool:
			var own_a: bool = hot[a.giver_slot] < 0
			var own_b: bool = hot[b.giver_slot] < 0
			if own_a != own_b:
				return own_a
			var gain_a: int = _gain_to(a, hot[a.giver_slot])
			var gain_b: int = _gain_to(b, hot[b.giver_slot])
			if gain_a != gain_b:
				return gain_a > gain_b
			return a.giver_slot < b.giver_slot
	)
	var lanes: Dictionary[int, int] = {}
	var placed: Array[Array] = [[], []]
	for spec: RailStripSpec in order:
		var choices: Array[int] = [0, 1]
		if hot[spec.giver_slot] >= 0 and spec.lane == 1:
			choices = [1, 0]
		for lane: int in choices:
			var free: bool = placed[lane].all(
				func(other: RailStripSpec) -> bool: return not spec.conflicts(other)
			)
			if free:
				lanes[spec.giver_slot] = lane
				placed[lane].append(spec)
				break
	return lanes


## The slots in focus when the item at `slot` is hovered (section 8.1): itself, the cards giving
## to it and the items it gives to, ascending.
func related(slot: int) -> PackedInt32Array:
	var found: PackedInt32Array = graph.related_slots(slot) if graph != null else PackedInt32Array()
	var index: int = found.bsearch(slot)
	if index >= found.size() or found[index] != slot:
		found.insert(index, slot)
	return found


static func _slot(
	effects: EffectGraph,
	slot: int,
	card: CardDefinition,
	payout: int,
	names: CauseNames,
	tuning: PlanningTuning
) -> PlanningSlot:
	var planning: PlanningSlot = PlanningSlot.new()
	var incoming: Array[EffectLink] = effects.incoming(slot)
	var denial: EffectLink = null
	var fizzled: bool = false
	var fizzles: Dictionary[String, bool] = {}
	for link: EffectLink in incoming:
		match link.kind:
			EffectLink.Kind.DENIED:
				denial = link
			EffectLink.Kind.FIZZLE:
				fizzled = true
				# A run of unused charges shows once.
				var key: String = (
					"%d|%d|%d|%s" % [link.cause_kind, link.cause_slot, link.cause_index, link.text]
				)
				if not fizzles.has(key):
					fizzles[key] = true
					planning.stickers.append(_sticker(link, names))
			_:
				planning.stickers.append(_sticker(link, names))
	if denial != null:
		planning.stamp_amount = PAY_TEXT % denial.value
		planning.stamp_caption = names.of_cause(denial).to_upper()
		planning.denied = denial.value == 0
	_pay(planning, card, payout, denial, fizzled)
	if planning.pay == Pay.BOOSTED:
		planning.rings = _rings(payout, card.base, tuning)
	return planning


## Sets the ticket's pay (section 2.2).
static func _pay(
	planning: PlanningSlot, card: CardDefinition, payout: int, denial: EffectLink, fizzled: bool
) -> void:
	var base: int = card.base
	if payout == 0 and denial != null:
		planning.pay = Pay.DENIED
		planning.glyph = (
			Glyph.WARNING if denial.cause_kind == ScoreStep.SourceKind.INSPECTION else Glyph.FIZZLE
		)
	elif payout == 0 and fizzled and (base > 0 or card.is_coupon()):
		planning.pay = Pay.ZERO
		planning.glyph = Glyph.FIZZLE
	elif payout == 0 and base > 0:
		# Nothing on the slot says why (no rule pays a product nothing today without a step).
		planning.pay = Pay.ZERO
	elif payout > base:
		planning.pay = Pay.BOOSTED
	elif payout < base:
		planning.pay = Pay.LOWERED
	else:
		planning.pay = Pay.PLAIN
	if planning.pay != Pay.PLAIN:
		planning.pay_text = PAY_TEXT % payout
		# A coupon's title "COUPON" is never struck.
		planning.struck = card.is_product()


## The halo's rings for a boosted pay (section 2.3): 1, then one more at each ratio of the base
## (at least 1) the pay reaches.
static func _rings(payout: int, base: int, tuning: PlanningTuning) -> int:
	var rings: int = 1
	var ratios: PackedInt32Array = tuning.halo_ratios if tuning != null else PackedInt32Array()
	for ratio: int in ratios:
		if ratio > 0 and payout >= maxi(base, 1) * ratio:
			rings += 1
	return mini(rings, 3)


static func _sticker(link: EffectLink, names: CauseNames) -> StickerSpec:
	var sticker: StickerSpec = StickerSpec.new()
	match link.kind:
		EffectLink.Kind.STAMP:
			sticker.kind = StickerSpec.Kind.MULTIPLY
		EffectLink.Kind.COPY:
			sticker.kind = StickerSpec.Kind.COPY
		EffectLink.Kind.FIZZLE:
			sticker.kind = StickerSpec.Kind.FIZZLE
		_:
			sticker.kind = StickerSpec.Kind.ADD
	sticker.text = link.token
	sticker.cause_kind = link.cause_kind
	sticker.cause_slot = link.cause_slot
	sticker.cause_index = link.cause_index
	sticker.step_index = link.step_index
	if not link.own:
		sticker.badge = names.badge_of(link)
		sticker.badge_text = GiverBadge.initials_for(sticker.badge, names.of_cause(link))
		if sticker.badge == GiverBadge.Kind.ITEM:
			sticker.badge_mini = names.mini_of(link)
		elif sticker.badge == GiverBadge.Kind.LOYALTY:
			sticker.badge_mini = names.icon_of(link)
	return sticker


## One strip per giver slot with cross-item BONUS, STAMP, COPY or FIZZLE links (section 5.1), named
## by `names` (the row's display names).
static func _strips(effects: EffectGraph, names: PackedStringArray) -> Array[RailStripSpec]:
	var by_giver: Dictionary[int, Array] = {}
	for link: EffectLink in effects.links:
		if not STRIP_KINDS.has(link.kind):
			continue
		if link.cause_kind != ScoreStep.SourceKind.CARD or link.cause_slot == link.target_slot:
			continue
		if link.cause_slot < 0 or link.cause_slot >= names.size():
			continue
		if not by_giver.has(link.cause_slot):
			by_giver[link.cause_slot] = []
		by_giver[link.cause_slot].append(link)
	var givers: Array[int] = by_giver.keys()
	givers.sort()
	var found: Array[RailStripSpec] = []
	for giver: int in givers:
		found.append(_strip(giver, names[giver], by_giver[giver]))
	return found


static func _strip(giver: int, display_name: String, links: Array) -> RailStripSpec:
	var strip: RailStripSpec = RailStripSpec.new()
	strip.giver_slot = giver
	strip.name = display_name.to_upper()
	var targets: Array[int] = []
	for link: EffectLink in links:
		if not targets.has(link.target_slot):
			targets.append(link.target_slot)
	targets.sort()
	strip.backward = targets.all(func(target: int) -> bool: return target < giver)
	if strip.backward:
		targets.reverse()
	for target: int in targets:
		var tokens: PackedStringArray = PackedStringArray()
		var gain: int = 0
		var cancelled: bool = false
		for link: EffectLink in links:
			if link.target_slot != target:
				continue
			tokens.append(link.token)
			gain += link.gain
			cancelled = cancelled or link.cancelled
		strip.targets.append(target)
		strip.tokens.append(" ".join(tokens))
		strip.gains.append(-1 if cancelled else gain)
	return strip


## Names and badges of the causes: the row's cards, the run's upgrades, the shift's inspections.
class CauseNames:
	extends RefCounted
	var _row: Array[CardDefinition]
	var _upgrades: Array[UpgradeDefinition]
	var _inspections: Array[InspectionDefinition]

	func _init(
		row: Array[CardDefinition],
		upgrades: Array[UpgradeDefinition],
		inspections: Array[InspectionDefinition]
	) -> void:
		_row = row
		_upgrades = upgrades
		_inspections = inspections

	## The display name of `link`'s cause, or empty when it is out of range.
	func of_cause(link: EffectLink) -> String:
		match link.cause_kind:
			ScoreStep.SourceKind.CARD:
				if link.cause_slot >= 0 and link.cause_slot < _row.size():
					return _row[link.cause_slot].display_name
			ScoreStep.SourceKind.UPGRADE:
				if link.cause_index >= 0 and link.cause_index < _upgrades.size():
					return _upgrades[link.cause_index].display_name
			ScoreStep.SourceKind.INSPECTION:
				if link.cause_index >= 0 and link.cause_index < _inspections.size():
					return _inspections[link.cause_index].display_name
		return ""

	## The giver-badge mini of `link`'s cause (CardDefinition.badge_mini_ref) for a card cause,
	## or empty.
	func mini_of(link: EffectLink) -> String:
		if link.cause_kind != ScoreStep.SourceKind.CARD:
			return ""
		if link.cause_slot < 0 or link.cause_slot >= _row.size():
			return ""
		return _row[link.cause_slot].badge_mini_ref()

	## The perk icon of `link`'s cause (UpgradeDefinition.icon_ref) for an upgrade cause, or
	## empty.
	func icon_of(link: EffectLink) -> String:
		if link.cause_kind != ScoreStep.SourceKind.UPGRADE:
			return ""
		if link.cause_index < 0 or link.cause_index >= _upgrades.size():
			return ""
		return _upgrades[link.cause_index].icon_ref

	## The badge of `link`'s cause.
	func badge_of(link: EffectLink) -> GiverBadge.Kind:
		match link.cause_kind:
			ScoreStep.SourceKind.UPGRADE:
				return GiverBadge.Kind.LOYALTY
			ScoreStep.SourceKind.INSPECTION:
				return GiverBadge.Kind.INSPECTION
		if link.cause_slot >= 0 and link.cause_slot < _row.size():
			if _row[link.cause_slot].is_coupon():
				return GiverBadge.Kind.COUPON
		return GiverBadge.Kind.ITEM


## `spec`'s summed gain to `target` (0 when cancelled, or not one of its targets).
static func _gain_to(spec: RailStripSpec, target: int) -> int:
	var index: int = spec.targets.find(target)
	return maxi(spec.gains[index], 0) if index >= 0 and index < spec.gains.size() else 0
