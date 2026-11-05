class_name TipTarget
extends TextureRect
## Something a small tooltip names when the pointer rests on it (#105, mock-up readability v3,
## GlyphTips): a family glyph (FamilyGlyph: its family's name), a ticket's colour
## (PriceSticker.ColourSpot: what the colour means) or a keyword (KeywordChip, #128: what it
## means, or why its line is wasted). The tip opens below `tip_anchor` (a rail or shelf ticket)
## when `tip_below`, else above the target. It takes no clicks: the item under it keeps its hover,
## its drag and its clicks.

## Every target is in this group, for GlyphTips.
const GROUP := &"tip_target"

## Its tooltip's text.
var tip_text: String = ""
## What the tip adds while it shows on the belt (tickets v5: a family's items there, or what a
## written family's rule counts; PlanningEffects sets it when the tip opens), or "".
var tip_more: String = ""
## The tooltip opens below `tip_anchor` (a rail or shelf ticket), else above the target.
var tip_below: bool = false
var tip_anchor: Control
## Its tip still shows while GlyphTips is `blocked` (the count-up): a monitor count row's bag glyph
## (v1.11), which only shows during the count.
var shows_while_blocked: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(GROUP)


## Its tooltip showed (`shown`) or went (GlyphTips calls it once per change): a keyword chip
## lights while its tip shows (KeywordChip). Nothing by default.
func tip_shown(_shown: bool) -> void:
	pass


## The tooltip's whole text: tip_text, then tip_more after a " · ".
func full_tip() -> String:
	return tip_text if tip_more.is_empty() else "%s · %s" % [tip_text, tip_more]


## Whether the target shows on screen now (GlyphTips only shows a tooltip for one that does).
func is_shown() -> bool:
	return is_visible_in_tree() and modulate.a > 0.0
