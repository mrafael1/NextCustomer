class_name FamilyPalette
extends Resource
## The families' looks (#105, full build plan section 6.1), as data in
## data/families/family_palette.tres: each family's glyph, tooltip name and ticket colours
## (FamilyStyle), the order that picks a card's main family and the families the glyph row leaves
## out. The colour-blind-safe set B (Food tomato pale, Clearance tomato darkest) is the default;
## set A's two styles sit in data/families/set_a/, so switching sets is two paths in the .tres.
##
## A ticket's families come from CardFamilies (core), with this palette's order and data_card as
## its card lookup; nothing here reads a rule. Every default is neutral (empty).

## The game's palette.
const PATH := "res://data/families/family_palette.tres"
## What a ticket's colour means (#105, mock-up readability v3's colourTip and its popup line): its
## tooltip ("Breakfast colour · works with Breakfast", a split's "Bakery + Dairy: works with
## both", the plain coupon's) and the scan popup's line ("Breakfast ticket: works with
## Breakfast"), from CardFamilies.colour_reason.
const COLOUR_TIP := "%s colour · %s"
const SPLIT_TIP := "%s + %s: works with both"
const PLAIN_COUPON_TIP := "Plain coupon: works with whatever is beside it"
const TICKET_LINE := "%s ticket: %s"
const SPLIT_LINE := "%s + %s ticket: works with both"
const WORKS_WITH := "works with %s"
const WORKS_WITH_ANOTHER := "works with another %s"
const GIVES := "gives %s"
const OWN_FAMILY := "its own family"

static var _shared: FamilyPalette
## data_card's lookup: the game's own card resolution (a card needs no balance).
static var _cards: ContentLookup

## Every family's look, the coupon mark's included.
@export var families: Array[FamilyStyle] = []
## The order that picks a card's main family (CardFamilies.main_family): an aisle family beats
## Breakfast, which beats Clearance, which beats Food.
@export var main_family_order: PackedStringArray = PackedStringArray()
## The families the glyph row leaves out when a card has another (CardFamilies.shelf_families).
@export var quiet_families: PackedStringArray = PackedStringArray()


## The game's palette, loaded once.
static func shared() -> FamilyPalette:
	if _shared == null:
		_shared = load(PATH) as FamilyPalette
	return _shared


## The card with this id from data/cards (ContentLookup.card: a plain id only, its file checked
## first so nothing prints an error, and the card's own id must match), or null.
static func data_card(id: String) -> CardDefinition:
	if _cards == null:
		_cards = ContentLookup.new(null)
	return _cards.card(id)


## The look of the family `id`, or null when the palette has none.
func style(id: String) -> FamilyStyle:
	for family: FamilyStyle in families:
		if family.id == id:
			return family
	return null


## The families `definition`'s ticket is coloured by (CardFamilies.ticket_families): one, two
## for a split ticket, or none for the plain coupon ticket.
func ticket_families(definition: CardDefinition) -> PackedStringArray:
	return CardFamilies.ticket_families(definition, main_family_order, data_card)


## Why `definition`'s ticket has its colour (CardFamilies.colour_reason).
func colour_reason(definition: CardDefinition) -> CardFamilies.Why:
	return CardFamilies.colour_reason(definition, main_family_order, data_card)


## What the colour means, after the colour's name: "works with Breakfast", "works with Milk",
## "works with another Banana", "gives Breakfast" or "its own family" ("" for the plain coupon).
func colour_meaning(definition: CardDefinition) -> String:
	var why: CardFamilies.Why = colour_reason(definition)
	match why.reason:
		CardFamilies.Reason.FAMILY:
			return WORKS_WITH % display_name(why.subject)
		CardFamilies.Reason.GIVES:
			return GIVES % display_name(why.subject)
		CardFamilies.Reason.CARD:
			return WORKS_WITH % why.subject
		CardFamilies.Reason.SAME:
			return WORKS_WITH_ANOTHER % why.subject
		CardFamilies.Reason.OWN, CardFamilies.Reason.OVERRIDE:
			return OWN_FAMILY
	return ""


## The tooltip of `definition`'s ticket colour: "<family> colour · <meaning>", a split ticket's
## "<first> + <second>: works with both", or the plain coupon's.
func colour_tip(definition: CardDefinition) -> String:
	var ids: PackedStringArray = ticket_families(definition)
	if ids.is_empty():
		return PLAIN_COUPON_TIP
	if ids.size() > 1:
		return SPLIT_TIP % [display_name(ids[0]), display_name(ids[1])]
	return COLOUR_TIP % [display_name(ids[0]), colour_meaning(definition)]


## The scan popup's line under its coloured header: "<family> ticket: <meaning>", a split
## ticket's "<first> + <second> ticket: works with both", or "" for the plain coupon (no colour).
func ticket_line(definition: CardDefinition) -> String:
	var ids: PackedStringArray = ticket_families(definition)
	if ids.is_empty():
		return ""
	if ids.size() > 1:
		return SPLIT_LINE % [display_name(ids[0]), display_name(ids[1])]
	return TICKET_LINE % [display_name(ids[0]), colour_meaning(definition)]


## A family's name as the game shows it (its style's display name, else its id).
func display_name(id: String) -> String:
	var family: FamilyStyle = style(id)
	return family.display_name if family != null and not family.display_name.is_empty() else id


## The families a ticket's glyph row shows for these tags (CardFamilies.shelf_families).
func shelf_families(tags: PackedStringArray) -> PackedStringArray:
	return CardFamilies.shelf_families(tags, quiet_families)


## The looks of `ids`, skipping any the palette lacks.
func styles(ids: PackedStringArray) -> Array[FamilyStyle]:
	var found: Array[FamilyStyle] = []
	for id: String in ids:
		var family: FamilyStyle = style(id)
		if family != null:
			found.append(family)
	return found


## A ticket's text and glyph ink over these families: paper only when every one of them has
## paper text (a split ticket reads in ink unless both halves are dark), ink for none (the plain
## coupon).
func text_color(ids: PackedStringArray) -> Color:
	var found: Array[FamilyStyle] = styles(ids)
	if found.is_empty():
		return Palette.INK
	for family: FamilyStyle in found:
		if not family.paper_text:
			return Palette.INK
	return Palette.PAPER


## Which family a word of sticker text names, by its id or one of its words, or "" for none
## (GlyphText).
func family_for_word(word: String) -> String:
	for family: FamilyStyle in families:
		if family.id == word or family.words.has(word):
			return family.id
	return ""
