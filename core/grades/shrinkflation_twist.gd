class_name ShrinkflationTwist
extends GradeTwist
## Shrinkflation (#182 grade 2, v1.49): at the end of each week the product checked out most that
## week (ties: the run's RNG) loses `euros` of its price for the rest of the run, stacking each time
## it wins again, down to the event's ProductShrinkRule.min_base (GradeRules.start_shift). The run's
## shrinks play as `event`, a copy of it per run carrying them (GradeRules.shrink_event).

## Euros a week's top product loses (0: none).
@export var euros: int = 0
## The scoring carrier (tone TWIST): one ProductShrinkRule, whose min_base is the floor.
@export var event: InspectionDefinition
