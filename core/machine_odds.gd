class_name MachineOdds
extends RefCounted
## The exact odds of a machine draw (#77, build spec 1.5): every possible draw of MachineDraw's
## process enumerated with its probability (draw77 tree and stats, with #108's drop kinds, PREMIUM
## floor and tier roll), never touching an RNG and keeping nothing between calls.
##
## The enumeration runs over equivalence classes rather than single prizes: prizes of one rarity
## and kind that the guarantee, the loyalty type rule and the new-arrival hold treat alike are
## interchangeable, so a class is drawn with the chance of any of its members still free, and
## each member's chance to be drawn is the class's expected count over its size. This keeps a
## large stock (the full collection) fast; tests compare it with a prize-by-prize enumeration
## and with the forward draw. The tier roll comes last and doesn't depend on the drop, so a
## product with a chain splits its chance over its tiers by the tier weights.

const NO_CLASS := -1


## The odds card of the chute's next draw from this context at an odds level.
static func card(chute: int, context: MachineContext, level: int) -> MachineOddsCard:
	var tree: Enumeration = Enumeration.new(chute, context, level)
	tree.run()
	var odds: MachineOddsCard = tree.to_card()
	odds.notes = _notes(chute, context, level, odds)
	return odds


## The card's note keys (MachineOddsCard.NOTE_*).
static func _notes(
	chute: int, context: MachineContext, level: int, odds: MachineOddsCard
) -> Array[StringName]:
	var found: Array[StringName] = []
	var chute_pools: Array = context.pools(chute)
	var legendary: Array[MachinePrize] = chute_pools[MachinePrize.Rarity.LEGENDARY]
	var rolls_legendary: bool = false
	for drop: int in range(context.machine.prizes_per_visit):
		var drop_weights: PackedInt32Array = MachineDraw.weights(
			context.machine, level, drop, context.min_rarity()
		)
		rolls_legendary = rolls_legendary or drop_weights[MachinePrize.Rarity.LEGENDARY] > 0
	if legendary.is_empty() and rolls_legendary:
		if chute == RewardMachine.Chute.NEW_ITEMS:
			found.append(MachineOddsCard.NOTE_LEGENDARY_NONE_IN_STOCK)
		else:
			found.append(MachineOddsCard.NOTE_LEGENDARY_EMPTY)
	var below_floor: float = 0.0
	for tier: int in maxi(odds.first_drop_min_rarity, odds.min_rarity):
		below_floor += odds.first_share[tier]
	for tier: int in odds.min_rarity:
		below_floor += odds.all_share[tier]
	if below_floor > 1e-12:
		found.append(MachineOddsCard.NOTE_FLOOR_FALLS)
	if odds.p_short > 1e-12:
		found.append(MachineOddsCard.NOTE_SHORT_DRAW)
	if chute == RewardMachine.Chute.NEW_ITEMS and context.holds_new_arrival():
		found.append(MachineOddsCard.NOTE_NEW_ARRIVAL_HELD)
	if chute == RewardMachine.Chute.NEW_ITEMS and context.balance != null:
		if context.deck.size() >= context.balance.deck_limit:
			found.append(MachineOddsCard.NOTE_CART_FULL)
	return found


## One enumeration: the classes of a chute's pools and the sums over every possible draw.
class Enumeration:
	extends RefCounted

	var chute: int = 0
	var level: int = 0
	var prizes: int = 0
	var machine: MachineDefinition
	## The PREMIUM rarity floor (0 on a CLASSIC visit) and the tier weights (plain, BIG, GOLDEN).
	var floor_rarity: int = 0
	var premium: bool = false
	var tier_weights: PackedInt32Array = PackedInt32Array([1, 0, 0])
	## Per class: its rarity, its kind (MachinePrize.Kind), its members (Array[MachinePrize]),
	## whether they are in the guarantee set, their perk type (loyalty perks; -1 otherwise).
	var rarity: PackedInt32Array = PackedInt32Array()
	var kind: PackedInt32Array = PackedInt32Array()
	var members: Array = []
	var held: PackedByteArray = PackedByteArray()
	var type: PackedInt32Array = PackedInt32Array()
	## The new arrival's own class when the draw holds it, else NO_CLASS.
	var new_arrival: int = NO_CLASS
	var guarded: bool = false
	var all_share: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
	var first_share: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
	var rest_share: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
	var expected: PackedFloat64Array = PackedFloat64Array()
	var p_rare_plus: float = 0.0
	var p_legendary: float = 0.0
	var p_short: float = 0.0
	var p_held: float = 0.0

	func _init(draw_chute: int, context: MachineContext, draw_level: int) -> void:
		chute = draw_chute
		level = draw_level
		machine = context.machine
		prizes = machine.prizes_per_visit
		floor_rarity = context.min_rarity()
		premium = context.premium
		var odds_level: MachineOddsLevel = machine.odds_level(level)
		if odds_level != null and chute == RewardMachine.Chute.NEW_ITEMS:
			tier_weights = odds_level.tier_weights(context.min_tier())
		var held_ids: Dictionary = context.guarantee(chute)
		guarded = not held_ids.is_empty()
		var arrival: CardDefinition = null
		if chute == RewardMachine.Chute.NEW_ITEMS and context.holds_new_arrival():
			arrival = context.new_arrival
		var chute_pools: Array = context.pools(chute)
		var by_signature: Dictionary = {}
		for pool: Array[MachinePrize] in chute_pools:
			for prize: MachinePrize in pool:
				var is_arrival: bool = arrival != null and prize.card == arrival
				var prize_type: int = (
					prize.upgrade.type if prize.kind == MachinePrize.Kind.REGISTER else -1
				)
				var signature: String = (
					"%d|%d|%s|%d|%s"
					% [prize.rarity, prize.kind, held_ids.has(prize.id()), prize_type, is_arrival]
				)
				if not by_signature.has(signature):
					by_signature[signature] = rarity.size()
					rarity.append(prize.rarity)
					kind.append(prize.kind)
					var list: Array[MachinePrize] = []
					members.append(list)
					held.append(1 if held_ids.has(prize.id()) else 0)
					type.append(prize_type)
					if is_arrival:
						new_arrival = rarity.size() - 1
				var class_members: Array[MachinePrize] = members[by_signature[signature]]
				class_members.append(prize)
		expected.resize(rarity.size())
		expected.fill(0.0)

	func run() -> void:
		var used: PackedInt32Array = PackedInt32Array()
		used.resize(rarity.size())
		used.fill(0)
		_step(0, PackedInt32Array(), used, 1.0)

	func to_card() -> MachineOddsCard:
		var odds: MachineOddsCard = MachineOddsCard.new()
		odds.chute = chute
		odds.level = level
		odds.premium = premium
		odds.min_rarity = floor_rarity
		odds.all_share = _normalised(all_share)
		odds.first_share = _normalised(first_share)
		odds.rest_share = _normalised(rest_share)
		var first_floor: int = 0
		var odds_level: MachineOddsLevel = machine.odds_level(level)
		if odds_level != null:
			first_floor = odds_level.first_drop_min_rarity
		odds.first_drop_min_rarity = first_floor
		var rest_total: float = 0.0
		for share: float in odds.rest_share:
			rest_total += share
		var by_rest: bool = first_floor > floor_rarity and prizes > 1 and rest_total > 0.0
		odds.rarity_share = odds.rest_share if by_rest else odds.all_share
		odds.p_rare_plus = p_rare_plus
		odds.p_legendary = p_legendary
		odds.p_short = p_short
		odds.p_guarantee_held = p_held
		odds.guarded = guarded
		var tier_float: PackedFloat64Array = PackedFloat64Array()
		for weight: int in tier_weights:
			tier_float.append(maxi(weight, 0))
		odds.tier_share = _normalised(tier_float)
		for index: int in rarity.size():
			var class_members: Array[MachinePrize] = members[index]
			if held[index] == 1:
				for prize: MachinePrize in class_members:
					odds.guaranteed[prize.key()] = true
			if expected[index] <= 0.0:
				continue
			for prize: MachinePrize in class_members:
				_add_in_draw(odds, prize, expected[index] / class_members.size())
		return odds

	## A prize's chance in the draw, split over its tiers when it is a NEW ITEMS product with a
	## chain (the tier roll doesn't depend on the drop).
	func _add_in_draw(odds: MachineOddsCard, prize: MachinePrize, chance: float) -> void:
		var chain: ItemUpgradeDefinition = null
		if chute == RewardMachine.Chute.NEW_ITEMS:
			chain = MachineDraw.chain_of(machine, prize)
		if chain == null:
			odds.in_draw[prize.key()] = chance
			return
		var tiers: Array[CardDefinition] = chain.tiers()
		for tier: int in tiers.size():
			var share: float = odds.tier_share[tier]
			if share <= 0.0 or tiers[tier] == null:
				continue
			var tiered: MachinePrize = MachinePrize.new(prize.kind, prize.rarity, tiers[tier])
			odds.in_draw[tiered.key()] = chance * share

	## One drop of the tree (draw77 tree step), then the next.
	func _step(drop: int, drawn: PackedInt32Array, used: PackedInt32Array, chance: float) -> void:
		if drop >= prizes:
			_finish(drawn, used, chance)
			return
		var drop_weights: PackedInt32Array = MachineDraw.weights(machine, level, drop, floor_rarity)
		var total: int = 0
		for weight: int in drop_weights:
			total += maxi(weight, 0)
		if total <= 0:
			_finish(drawn, used, chance)
			return
		var drop_kind: int = MachineDraw.drop_kind(chute, machine, drop)
		for rolled: int in drop_weights.size():
			if drop_weights[rolled] <= 0:
				continue
			var rolled_chance: float = chance * drop_weights[rolled] / total
			var landed: PackedInt32Array = _land(drop_kind, rolled, drawn, used)
			if landed.is_empty():
				_finish(drawn, used, rolled_chance)
				continue
			var free: int = 0
			for found: int in landed:
				free += _free(found, used)
			for found: int in landed:
				var next_drawn: PackedInt32Array = drawn.duplicate()
				next_drawn.append(found)
				var next_used: PackedInt32Array = used.duplicate()
				next_used[found] += 1
				_step(drop + 1, next_drawn, next_used, rolled_chance * _free(found, used) / free)

	## A finished draw: the guarantee swap's alternatives (within the swapped drop's kind), then
	## the new-arrival hold.
	func _finish(drawn: PackedInt32Array, used: PackedInt32Array, chance: float) -> void:
		var holds: bool = false
		for found: int in drawn:
			holds = holds or held[found] == 1
		if not guarded or holds:
			_record(drawn, used, chance)
			return
		for index: int in range(drawn.size() - 1, -1, -1):
			var swaps: PackedInt32Array = PackedInt32Array()
			var free: int = 0
			for other: int in rarity.size():
				if rarity[other] != rarity[drawn[index]] or kind[other] != kind[drawn[index]]:
					continue
				if held[other] == 0 or _free(other, used) <= 0 or _type_taken(other, drawn, index):
					continue
				swaps.append(other)
				free += _free(other, used)
			if swaps.is_empty():
				continue
			for other: int in swaps:
				var swapped: PackedInt32Array = drawn.duplicate()
				swapped[index] = other
				var swapped_used: PackedInt32Array = used.duplicate()
				swapped_used[drawn[index]] -= 1
				swapped_used[other] += 1
				_record(swapped, swapped_used, chance * _free(other, used) / free)
			return
		_record(drawn, used, chance)

	## Adds one finished draw (after the new-arrival hold) to the sums (draw77 stats). The draw
	## holds its guarantee when one of its drops is in the guarantee set.
	func _record(drawn: PackedInt32Array, used: PackedInt32Array, chance: float) -> void:
		var final: PackedInt32Array = _with_new_arrival(drawn, used)
		var count: int = final.size()
		if count < prizes:
			p_short += chance
		var holds: bool = false
		var rare_plus: bool = false
		var legendary: bool = false
		for index: int in count:
			var tier: int = rarity[final[index]]
			rare_plus = rare_plus or tier >= MachinePrize.Rarity.RARE
			legendary = legendary or tier == MachinePrize.Rarity.LEGENDARY
			holds = holds or held[final[index]] == 1
			all_share[tier] += chance / count
			if index == 0:
				first_share[tier] += chance
			else:
				rest_share[tier] += chance / (count - 1)
			expected[final[index]] += chance
		if holds:
			p_held += chance
		if rare_plus:
			p_rare_plus += chance
		if legendary:
			p_legendary += chance

	## MachineDraw.new_arrival_swap on classes (product drops only).
	func _with_new_arrival(drawn: PackedInt32Array, used: PackedInt32Array) -> PackedInt32Array:
		if new_arrival == NO_CLASS or used[new_arrival] > 0:
			return drawn
		var useful: int = 0
		for found: int in drawn:
			useful += held[found]
		for index: int in range(drawn.size() - 1, -1, -1):
			if kind[drawn[index]] != MachinePrize.Kind.PRODUCT:
				continue
			if useful == 1 and held[drawn[index]] == 1:
				continue
			var swapped: PackedInt32Array = drawn.duplicate()
			swapped[index] = new_arrival
			return swapped
		return drawn

	## MachineDraw.land on classes: the classes of the drop's kind with a free member of the
	## rolled rarity, else of the rarities in MachineDraw.fallback_order; then any kind.
	func _land(
		drop_kind: int, rolled: int, drawn: PackedInt32Array, used: PackedInt32Array
	) -> PackedInt32Array:
		for tried: int in MachineDraw.fallback_order(rolled, floor_rarity):
			var found: PackedInt32Array = PackedInt32Array()
			for index: int in rarity.size():
				if rarity[index] != tried or _free(index, used) <= 0:
					continue
				if drop_kind != MachineDraw.ANY_KIND and kind[index] != drop_kind:
					continue
				if not _type_taken(index, drawn, -1):
					found.append(index)
			if not found.is_empty():
				return found
		if drop_kind != MachineDraw.ANY_KIND:
			return _land(MachineDraw.ANY_KIND, rolled, drawn, used)
		return PackedInt32Array()

	func _free(index: int, used: PackedInt32Array) -> int:
		var class_members: Array[MachinePrize] = members[index]
		return class_members.size() - used[index]

	## Loyalty perks only: whether a drop other than `skip` has the class's perk type.
	func _type_taken(index: int, drawn: PackedInt32Array, skip: int) -> bool:
		if type[index] == -1:
			return false
		for at: int in drawn.size():
			if at != skip and type[drawn[at]] == type[index]:
				return true
		return false

	static func _normalised(shares: PackedFloat64Array) -> PackedFloat64Array:
		var total: float = 0.0
		for share: float in shares:
			total += share
		var found: PackedFloat64Array = shares.duplicate()
		if total > 0.0:
			for index: int in found.size():
				found[index] = found[index] / total
		return found
