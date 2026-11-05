class_name StartCartLine
extends RefCounted
## One line of the opening-time cart (StartSetupRules.cart_lines): a card and where it comes from.
## The order sheet, the parked trolley and the board's cart count all read the same lines.

enum Source { REGULAR, PACK, DEALT, PIN }

## The card, or null for a pack line still waiting for the pick.
var card: CardDefinition
var source: Source = Source.REGULAR
## The source's id: the pack's or pin's id, the dealt card's aisle id (&"" for the staples
## shelf), &"" for a regular or a pack line waiting for the pick.
var origin: StringName = &""
## The source's display name ("" for a regular, the staples shelf, or a line waiting).
var origin_name: String = ""
## A pack line of a pack only previewed (hovered), not picked.
var preview: bool = false


func _init(
	line_card: CardDefinition,
	line_source: Source,
	line_origin: StringName = &"",
	line_origin_name: String = "",
	line_preview: bool = false
) -> void:
	card = line_card
	source = line_source
	origin = line_origin
	origin_name = line_origin_name
	preview = line_preview
