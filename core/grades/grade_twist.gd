class_name GradeTwist
extends Resource
## A difficulty grade's twist (#182, v1.49, decided with the user on 2026-11-23): a rule that
## changes how a graded run plays, beyond the balance numbers GradeDefinition sets
## (Shrinkflation, Expiry dates, the Picky regular). A grade carries at most one
## (GradeDefinition.twist); GradeApply.balance_for lists the twists of grades 1 to n on the
## graded balance (BalanceDefinition.twists), and GradeRules plays them. Shared and stateless:
## the run's twist state is GradeState. Every default is neutral.

@export var id: StringName = &""


## `text` (a grade's rule line, its event's words) with the twist's numbers in place of their keys
## (the Picky regular's "{off}"); as it is for a twist without keys.
func format_text(text: String) -> String:
	return text
