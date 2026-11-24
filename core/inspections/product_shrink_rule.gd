class_name ProductShrinkRule
extends InspectionRule
## Shrinkflation's carrier (#182 grade 2, v1.49): each product whose product (a tier counts as its
## plain card) is in `shrinks` pays that many euros less, as a flat malus with the day events', but
## never takes its printed price below `min_base` (a product priced at or under it loses nothing)
## nor its value below 0. `shrinks` is the run's (GradeState), set on a copy made for the run
## (GradeRules.shrink_event): the data's rule holds none and does nothing.

## The lowest price a shrink leaves (0: down to free).
@export var min_base: int = 0
## The run's shrinks: product id to euros. Not data: never exported.
var shrinks: Dictionary[StringName, int] = {}


func flat_bonus(state: ScoreState, slot: int, value: int) -> int:
	if shrinks.is_empty() or not state.is_product(slot):
		return 0
	var off: int = off_for(state.definition(slot))
	return -mini(off, maxi(value, 0)) if off > 0 else 0


## The euros `definition` loses: its product's shrink, kept above min_base.
func off_for(definition: CardDefinition) -> int:
	var shrink: int = shrinks.get(definition.product_card().id, 0)
	return mini(shrink, maxi(definition.base - min_base, 0))
