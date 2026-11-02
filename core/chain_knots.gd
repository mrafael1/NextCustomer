class_name ChainKnots
extends RefCounted
## The knots of one score (#128, Produce links): a Lemon between two Bananas ties the Banana just
## before it to the Banana just after it, for the chain only. ScoreState.knots holds one (null
## while nothing is tied); CardChain reads it. These links are never adjacency, so no rule but
## the chain sees across a knot.

## For each product just after a knot, the products just before that knot, and the reverse.
var _before: Dictionary[int, PackedInt32Array] = {}
var _after: Dictionary[int, PackedInt32Array] = {}
## For each tied pair (Vector2i(before, after)), the knot's slot; for each knot, its factor.
var _knot_of: Dictionary[Vector2i, int] = {}
var _factor: Dictionary[int, int] = {}


## The knot in slot `knot` (with `factor`) ties the product `before` it to the product `after` it.
func tie(before: int, after: int, knot: int, factor: int) -> void:
	var pair: Vector2i = Vector2i(before, after)
	if _knot_of.has(pair):
		return
	_knot_of[pair] = knot
	_factor[knot] = factor
	var befores: PackedInt32Array = _before.get(after, PackedInt32Array())
	befores.append(before)
	_before[after] = befores
	var afters: PackedInt32Array = _after.get(before, PackedInt32Array())
	afters.append(after)
	_after[before] = afters


## The products a knot ties to `slot` from before it.
func tied_before(slot: int) -> PackedInt32Array:
	return _before.get(slot, PackedInt32Array())


## The products a knot ties to `slot` from after it.
func tied_after(slot: int) -> PackedInt32Array:
	return _after.get(slot, PackedInt32Array())


## The knot tying `before_slot` to `after_slot`, or -1.
func between(before_slot: int, after_slot: int) -> int:
	return _knot_of.get(Vector2i(before_slot, after_slot), -1)


## Whether a knot in `slot` ties anything.
func has(slot: int) -> bool:
	return _factor.has(slot)


## The factor of the knot in `slot` (1 for no knot).
func factor_of(slot: int) -> int:
	return _factor.get(slot, 1)


## The knots' slots in slot order.
func slots() -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array(_factor.keys())
	found.sort()
	return found
