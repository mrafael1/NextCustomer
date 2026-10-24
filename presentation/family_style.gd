class_name FamilyStyle
extends Resource
## One family's look (#105, full build plan section 6.1): its glyph, the name its tooltip shows
## and its ticket colours, as data (data/families/), so a colour set is switched by data alone.
## A family is a tag as cards write it ("Breakfast"); the coupon mark ("Coupon") is a family
## with a glyph and words but no ticket colours. Every default is neutral (empty, black, false),
## so a script edit never silently changes the data.

## The tag this styles, as cards write it ("Breakfast"; "Coupon" for the coupon mark).
@export var id: String = ""
## The tooltip's text: the family's name for players.
@export var display_name: String = ""
## The 9x9 glyph, shown alone at 2x.
@export var glyph: Texture2D
## The ticket's colours (mock-up readability v3, FC): `face` fills it, `light` is its lit top row
## (and a split ticket's seam), `shade` its right column and bottom row. All three are
## art/src/palette.txt colours.
@export var face: Color = Color()
@export var light: Color = Color()
@export var shade: Color = Color()
## The ticket's text and glyph ink: paper on this face when true, else ink.
@export var paper_text: bool = false
## More words in sticker text drawn as this glyph, besides `id` (the coupon mark's "coupon" and
## "coupons").
@export var words: PackedStringArray = PackedStringArray()


## Whether this family colours tickets: the coupon mark leaves `face` at its default, Color()
## (no family is ink black).
func has_ticket_colours() -> bool:
	return face != Color()
