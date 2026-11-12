class_name MachineOdds
extends RefCounted
## The exact odds of a machine draw (#77, build spec 1.5): every possible draw of MachineDraw's
## process enumerated with its probability (draw77 tree and stats, with #108's drop kinds and
## PREMIUM floor, and v1.25's tiers as rarities and draw weights), never touching an RNG and
## keeping nothing between calls.
##
## The enumeration runs over equivalence classes rather than single prizes. An item is one prize,
## or for a NEW ITEMS product one product line: its tiers, each a prize at its rarity (v1.25: plain
## COMMON, BIG RARE, GOLDEN LEGENDARY), of which a draw holds one at most. Items of one kind with
## the same rarities and the same draw weight (MachineDraw.draw_weight) that the guarantee, the
## loyalty type rule and the new-arrival hold treat alike are interchangeable, so a class is drawn
## at a rarity with the chance of its free members' weight against the other candidates', and each
## member's chance to be drawn at that rarity is the class's expected count there over its size.
## This keeps a large stock (the full collection) fast; tests compare it with a prize-by-prize
## enumeration and with the forward draw.

const NO_CLASS := -1
const RARITY_COUNT := 3


## The odds card of the chute's next draw from this context at an odds level.
static func card(chute: int, context: MachineContext, level: int) -> MachineOddsCard:
	var tree: Enumeration = Enumeration.new(chute, context, level)
	tree.run()
	var odds: MachineOddsCard = tree.to_card()
	odds.notes = _notes(chute, context, level, odds)
	return odds


## The item a prize belongs to: for a product its product line (plain_id: a draw holds one tier
## at most), else the prize itself (its key).
static func item_key(prize: MachinePrize) -> String:
	if prize.kind == MachinePrize.Kind.PRODUCT:
		return "product:%s" % prize.plain_id()
	return prize.key()


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
			context.machine, context.machine.rarity_level(chute, level), drop, context.min_rarity()
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


## One enumeration: the classes of a chute's pools and the sums over every possible draw. A draw
## in progress is two parallel lists: the class of each drop and the rarity it landed at.
class Enumeration:
	extends RefCounted

	var chute: int = 0
	var level: int = 0
	var prizes: int = 0
	var machine: MachineDefinition
	## The PREMIUM rarity floor (0 on a CLASSIC visit).
	var floor_rarity: int = 0
	var premium: bool = false
	## Per class: the rarities its items have (a bit per rarity), its kind (MachinePrize.Kind),
	## its members (each an item: an Array of RARITY_COUNT prizes, null where it has none),
	## whether they are in the guarantee set, their perk type (loyalty perks; -1 otherwise) and
	## their draw weight.
	var rarities: PackedInt32Array = PackedInt32Array()
	var kind: PackedInt32Array = PackedInt32Array()
	var members: Array = []
	var held: PackedByteArray = PackedByteArray()
	var type: PackedInt32Array = PackedInt32Array()
	var weight: PackedInt32Array = PackedInt32Array()
	## The new arrival's own class when the draw holds it, else NO_CLASS, and the rarity it is
	## held at (its plain card's: COMMON).
	var new_arrival: int = NO_CLASS
	var arrival_rarity: int = MachinePrize.Rarity.COMMON
	var guarded: bool = false
	var all_share: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
	var first_share: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
	var rest_share: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
	## Per class and rarity (index class * RARITY_COUNT + rarity): its expected count in the draw.
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
		var held_ids: Dictionary = context.guarantee(chute)
		guarded = not held_ids.is_empty()
		var arrival: CardDefinition = null
		if chute == RewardMachine.Chute.NEW_ITEMS and context.holds_new_arrival():
			arrival = context.new_arrival
			arrival_rarity = MachineDefinition.product_rarity(arrival)
		var items: Dictionary = {}
		for pool: Array[MachinePrize] in context.pools(chute):
			for prize: MachinePrize in pool:
				var key: String = MachineOdds.item_key(prize)
				if not items.has(key):
					var slots: Array = []
					slots.resize(RARITY_COUNT)
					items[key] = slots
				var item: Array = items[key]
				item[prize.rarity] = prize
		var by_signature: Dictionary = {}
		for key: String in items:
			_add_item(items[key], held_ids, arrival, by_signature)
		expected.resize(rarities.size() * RARITY_COUNT)
		expected.fill(0.0)

	func run() -> void:
		var used: PackedInt32Array = PackedInt32Array()
		used.resize(rarities.size())
		used.fill(0)
		_step(0, PackedInt32Array(), PackedInt32Array(), used, 1.0)

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
		var odds_level: MachineOddsLevel = machine.odds_level(machine.rarity_level(chute, level))
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
		for index: int in rarities.size():
			var class_members: Array = members[index]
			for at: int in RARITY_COUNT:
				if not _has_rarity(index, at):
					continue
				var chance: float = expected[index * RARITY_COUNT + at] / class_members.size()
				for item: Array in class_members:
					var prize: MachinePrize = item[at]
					if held[index] == 1:
						odds.guaranteed[prize.key()] = true
					if chance > 0.0:
						odds.in_draw[prize.key()] = chance
		return odds

	## Puts one item into its class (made on first use).
	func _add_item(
		item: Array, held_ids: Dictionary, arrival: CardDefinition, by_signature: Dictionary
	) -> void:
		var mask: int = 0
		var first: MachinePrize = null
		for at: int in RARITY_COUNT:
			if item[at] != null:
				mask |= 1 << at
				if first == null:
					first = item[at]
		var is_arrival: bool = (
			arrival != null
			and first.kind == MachinePrize.Kind.PRODUCT
			and first.card.is_same_product(arrival)
		)
		var is_held: bool = held_ids.has(first.plain_id())
		var prize_type: int = first.upgrade.type if first.kind == MachinePrize.Kind.REGISTER else -1
		var item_weight: int = MachineDraw.draw_weight(first)
		var signature: String = (
			"%d|%d|%s|%d|%s|%d" % [mask, first.kind, is_held, prize_type, is_arrival, item_weight]
		)
		if not by_signature.has(signature):
			by_signature[signature] = rarities.size()
			rarities.append(mask)
			kind.append(first.kind)
			members.append([])
			held.append(1 if is_held else 0)
			type.append(prize_type)
			weight.append(item_weight)
			if is_arrival:
				new_arrival = rarities.size() - 1
		var class_members: Array = members[by_signature[signature]]
		class_members.append(item)

	## One drop of the tree (draw77 tree step), then the next. `drawn` holds each drop's class,
	## `landed_at` the rarity it landed at.
	func _step(
		drop: int,
		drawn: PackedInt32Array,
		landed_at: PackedInt32Array,
		used: PackedInt32Array,
		chance: float
	) -> void:
		if drop >= prizes:
			_finish(drawn, landed_at, used, chance)
			return
		var drop_weights: PackedInt32Array = MachineDraw.weights(
			machine, machine.rarity_level(chute, level), drop, floor_rarity
		)
		var total: int = 0
		for rarity_weight: int in drop_weights:
			total += maxi(rarity_weight, 0)
		if total <= 0:
			_finish(drawn, landed_at, used, chance)
			return
		var drop_kind: int = MachineDraw.drop_kind(chute, machine, drop)
		for rolled: int in drop_weights.size():
			if drop_weights[rolled] <= 0:
				continue
			var rolled_chance: float = chance * drop_weights[rolled] / total
			var landing: Array = _land(drop_kind, rolled, drawn, used)
			var landed: PackedInt32Array = landing[1]
			var free: int = _free_weight(landed, used)
			if free <= 0:
				_finish(drawn, landed_at, used, rolled_chance)
				continue
			for found: int in landed:
				var next_drawn: PackedInt32Array = drawn.duplicate()
				next_drawn.append(found)
				var next_landed_at: PackedInt32Array = landed_at.duplicate()
				next_landed_at.append(landing[0])
				var next_used: PackedInt32Array = used.duplicate()
				next_used[found] += 1
				var share: float = float(_free(found, used) * weight[found]) / free
				_step(drop + 1, next_drawn, next_landed_at, next_used, rolled_chance * share)

	## A finished draw: the guarantee swap's alternatives (within the swapped drop's kind and
	## rarity, by their draw weights), then the new-arrival hold.
	func _finish(
		drawn: PackedInt32Array, landed_at: PackedInt32Array, used: PackedInt32Array, chance: float
	) -> void:
		var holds: bool = false
		for found: int in drawn:
			holds = holds or held[found] == 1
		if not guarded or holds:
			_record(drawn, landed_at, used, chance)
			return
		for index: int in range(drawn.size() - 1, -1, -1):
			var swaps: PackedInt32Array = PackedInt32Array()
			for other: int in rarities.size():
				if not _has_rarity(other, landed_at[index]) or kind[other] != kind[drawn[index]]:
					continue
				if held[other] == 0 or _free(other, used) <= 0 or _type_taken(other, drawn, index):
					continue
				swaps.append(other)
			var free: int = _free_weight(swaps, used)
			if free <= 0:
				continue
			for other: int in swaps:
				var swapped: PackedInt32Array = drawn.duplicate()
				swapped[index] = other
				var swapped_used: PackedInt32Array = used.duplicate()
				swapped_used[drawn[index]] -= 1
				swapped_used[other] += 1
				var share: float = float(_free(other, used) * weight[other]) / free
				_record(swapped, landed_at, swapped_used, chance * share)
			return
		_record(drawn, landed_at, used, chance)

	## Adds one finished draw (after the new-arrival hold) to the sums (draw77 stats). The draw
	## holds its guarantee when one of its drops is in the guarantee set.
	func _record(
		drawn: PackedInt32Array, landed_at: PackedInt32Array, used: PackedInt32Array, chance: float
	) -> void:
		var final: Array = _with_new_arrival(drawn, landed_at, used)
		var final_drawn: PackedInt32Array = final[0]
		var final_at: PackedInt32Array = final[1]
		var count: int = final_drawn.size()
		if count < prizes:
			p_short += chance
		var holds: bool = false
		var rare_plus: bool = false
		var legendary: bool = false
		for index: int in count:
			var tier: int = final_at[index]
			rare_plus = rare_plus or tier >= MachinePrize.Rarity.RARE
			legendary = legendary or tier == MachinePrize.Rarity.LEGENDARY
			holds = holds or held[final_drawn[index]] == 1
			all_share[tier] += chance / count
			if index == 0:
				first_share[tier] += chance
			else:
				rest_share[tier] += chance / (count - 1)
			expected[final_drawn[index] * RARITY_COUNT + tier] += chance
		if holds:
			p_held += chance
		if rare_plus:
			p_rare_plus += chance
		if legendary:
			p_legendary += chance

	## MachineDraw.new_arrival_swap on classes (product drops only): [classes, rarities].
	func _with_new_arrival(
		drawn: PackedInt32Array, landed_at: PackedInt32Array, used: PackedInt32Array
	) -> Array:
		if new_arrival == NO_CLASS or used[new_arrival] > 0:
			return [drawn, landed_at]
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
			var swapped_at: PackedInt32Array = landed_at.duplicate()
			swapped_at[index] = arrival_rarity
			return [swapped, swapped_at]
		return [drawn, landed_at]

	## MachineDraw.land on classes: [the rarity landed at, the classes of the drop's kind with a
	## free member at it]: the rolled rarity, else the rarities in MachineDraw.fallback_order; then
	## any kind. No classes when there is none.
	func _land(
		drop_kind: int, rolled: int, drawn: PackedInt32Array, used: PackedInt32Array
	) -> Array:
		for tried: int in MachineDraw.fallback_order(rolled, floor_rarity):
			var found: PackedInt32Array = PackedInt32Array()
			for index: int in rarities.size():
				if not _has_rarity(index, tried) or _free(index, used) <= 0:
					continue
				if drop_kind != MachineDraw.ANY_KIND and kind[index] != drop_kind:
					continue
				if not _type_taken(index, drawn, -1):
					found.append(index)
			if not found.is_empty():
				return [tried, found]
		if drop_kind != MachineDraw.ANY_KIND:
			return _land(MachineDraw.ANY_KIND, rolled, drawn, used)
		return [rolled, PackedInt32Array()]

	func _has_rarity(index: int, at: int) -> bool:
		return (rarities[index] & (1 << at)) != 0

	func _free(index: int, used: PackedInt32Array) -> int:
		var class_members: Array = members[index]
		return class_members.size() - used[index]

	## The free members' draw weight summed over `classes`.
	func _free_weight(classes: PackedInt32Array, used: PackedInt32Array) -> int:
		var total: int = 0
		for index: int in classes:
			total += _free(index, used) * weight[index]
		return total

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
