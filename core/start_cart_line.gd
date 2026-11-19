class_name StartCartLine
extends RefCounted
## One line of the opening-time cart (StartSetupRules.cart_lines): a card and where it comes from.
## The order sheet, the parked trolley and the board's cart count all read the same lines.

enum Source { REGULAR, DEALT, PIN }

## The card.
var card: CardDefinition
var source: Source = Source.REGULAR
## The source's id: the pin's id, the booster card's aisle id (DEALT: a card of one of today's
## aisle boosters), &"" for a regular.
var origin: StringName = &""
## The source's display name ("" for a regular).
var origin_name: String = ""


func _init(
	line_card: CardDefinition,
	line_source: Source,
	line_origin: StringName = &"",
	line_origin_name: String = ""
) -> void:
	card = line_card
	source = line_source
	origin = line_origin
	origin_name = line_origin_name
