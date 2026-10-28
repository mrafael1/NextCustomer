class_name TipTarget
extends TextureRect
## Something a small tooltip names when the pointer rests on it (#105, mock-up readability v3,
## GlyphTips): a family glyph (FamilyGlyph: its family's name) or a ticket's colour
## (PriceSticker.ColourSpot: what the colour means). The tip opens below `tip_anchor` (a rail or
## shelf ticket) when `tip_below`, else above the target. It takes no clicks: the item under it
## keeps its hover, its drag and its clicks.

## Every target is in this group, for GlyphTips.
const GROUP := &"tip_target"

## Its tooltip's text.
var tip_text: String = ""
## The tooltip opens below `tip_anchor` (a rail or shelf ticket), else above the target.
var tip_below: bool = false
var tip_anchor: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(GROUP)


## Whether the target shows on screen now (GlyphTips only shows a tooltip for one that does).
func is_shown() -> bool:
	return is_visible_in_tree() and modulate.a > 0.0
