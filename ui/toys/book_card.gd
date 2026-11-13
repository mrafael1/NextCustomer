class_name BookCard
extends Control
## One card in the FIGURINE BOOK (v1.30 round 2; BookArt.card_face at 2x): an item as a trading
## card in its main family's ticket colours. Top down: its name in capitals on the
## family-coloured band (hard pixel words, in paper on a paper_text family; a name too wide sets
## its words closer, and only a name still too wide falls back to the bold body font), the
## figurine (its 48x48 sprite at the game's 2x) standing on a plinth in a window lit in the
## family's light colour, the family's glyph in the window's top left and the item's price on a
## sticker in its bottom right (the number font, "4€"), and its description on paper: the rule
## as the monitor reads it (CardText.monitor_text, else the sticker summary, else the rule text;
## families as chips, keywords as chips), at the first of TEXT_TIERS that fits (found once per
## card and kept: a page turn lays each rule out once); an item with no rule says so.
##
## Not collected yet (the user: "a grey card with name and description readable and a ? where the
## figurine goes"): the card is pale grey with a dashed outline (no family's colours, so it never
## reads like an owned card), the window shows a big ? and no sticker, and the name and
## description still read in full. A card collected since the book was last opened carries the
## NEW tag (ToyNewTag) in its window's top right, dropping in as it comes on screen. The pointer
## lifts the card LIFT art px out of its pocket. Sizes in canvas px unless named art px.
##
## A coupon's card (round 3) is the same card in the coupon's ticket colours (coupon_style: its
## ticket's first family's, else the coupon teal) with the coupon mark for its glyph; its window
## shows the coupon's slip with its icon (ItemView.item_art, as on the belt) centred in the
## scissors line (BookArt's coupon window), and no price sticker: a coupon pays nothing itself.
## Its description is its rule, found the same way as an item's.
##
## Round 7 (the user: "add second family icon under first family icon on items that posses have 2
## families"): under the main family's glyph stand the glyphs of the item's other printed
## families (glyph_families: the ticket's label rule, so Food shows only on a card whose only
## family it is, or as the main glyph of an OTHER FOOD card whose main family is Food), one under
## the other GLYPH_PITCH apart, down the window's left edge clear of the figurine; each is a
## FamilyGlyph, naming its family in the game's tip (the book's GlyphTips) when the pointer rests
## on it; it takes no clicks, so the card under it still lifts.
##
## Round 10 (v1.30, decided with the user 2026-11-12): a loyalty perk's card (BookEntry.for_perk)
## is in the LOYALTY teal (perks_family_style, the same on every perk), its name the perk's (LV 1),
## the PERKS mark for its first glyph and the family it boosts for its second (a family perk's).
## Its window (BookArt's perk window) holds the perk's stamp from the top bar's LOYALTY card
## (LoyaltyCard.make_ring: its icon, its family's ring, an Aisle run's tag) at PERK_RING_SCALE,
## with no level badge: the level pips in the window's bottom right light up to the highest level
## picked (a perk that never levels up has none). Its description is the perk's LV 1 rule as the
## LOYALTY ticket prints it (effect_text; families and keywords as chips). No price, never NEW.
## Not picked yet: the shared grey face with its ?, no stamp and no pips, name and rule readable.

## The card in canvas px.
const SIZE := Vector2(180, 240)
## Its name's row (the band, inside the rim) and the pixel words' cap top in it; a number in a
## name (the coupon 2 for 1) sits NAME_GAP art px from its words (round 3: at 2 it read "2FOR1").
const NAME_RECT := Rect2(8, 6, 164, 26)
const NAME_CAP_TOP := 12.0
const NAME_GAP := 4
## The family glyph (9x9 art at 2x) in the window's top left.
const GLYPH_AT := Vector2(12, 40)
const GLYPH_SIZE := Vector2(18, 18)
## The next family glyph's step down (round 7): a glyph and 1 art px.
const GLYPH_PITCH := 20.0
## The figurine's top left (its sprite at 2x, 96x96): standing on the plinth (BookArt.
## PLINTH_TOP), a little left of centre so it keeps clear of the price sticker.
const FIGURINE_AT := Vector2(36, 32)
const FIGURINE_SIZE := Vector2(96, 96)
## The price sticker's text rect and size (BookArt.STICKER_RECT at 2x).
const PRICE_RECT := Rect2(134, 108, 36, 18)
const PRICE_FONT_SIZE := 14
const PRICE_TEXT := "%d€"
## The NEW tag's top left (ToyNewTag, 60x26) in the window's top right.
const NEW_TAG_AT := Vector2(112, 36)
## The description's rect on the paper and its tiers (size, line pitch), the first that fits.
const TEXT_AREA := Rect2(10, 144, 160, 82)
const TEXT_WEIGHT := 800
const TEXT_TIERS: Array[Vector2i] = [
	Vector2i(16, 19),
	Vector2i(15, 18),
	Vector2i(14, 17),
	Vector2i(13, 16),
	Vector2i(12, 15),
	Vector2i(12, 14)
]
const CHIP_MARGIN := 2.0
const CHIP_PADDING := 4.0
const PLAIN_TEXT := "No rule: it pays its price."
## The book's coupons as a family (their FAMILY option and their pages' header).
const COUPONS_NAME := "Coupons"
## The book's OTHER FOOD group (round 6, BookEntry.OTHER_FOOD): its FAMILY option and its
## pages' header.
const OTHER_FOOD_NAME := "Other food"
## The book's loyalty perks as a family (round 10, BookEntry.PERK_FAMILY): their FAMILY option
## and their pages' header, with the PERKS mark.
const PERKS_NAME := "Perks"
const PERK_MARK := preload("res://art/icons/family_perk.png")
## A perk's stamp (LoyaltyCard.make_ring's chip, CHIP_BOX_SIZE) drawn PERK_RING_SCALE times in the
## window, its top left PERK_RING_AT (centred in the window on the 2 px grid, standing on
## BookArt.PERK_FLOOR); its level pips' top left (BookArt.PIPS_RECT at 2x).
const PERK_RING_SCALE := 3.0
const PERK_RING_AT := Vector2(50, 46)
const PIPS_AT := Vector2(134, 120)
## How far the pointer lifts a card out of its pocket, in art px.
const LIFT := 2

## Each card's tier (its index in TEXT_TIERS), by card id (a perk's by perk_key), found the
## first time it is shown.
static var _tiers: Dictionary[StringName, int] = {}

var _entry: BookEntry
var _face: TextureRect
var _glyphs: Array[TextureRect] = []
var _name: Control
var _figurine: TextureRect
var _price: Label
var _description: Control
var _new_tag: ToyNewTag
var _ring: Control
var _pips: TextureRect
var _rest_y: float = 0.0


## The card for `item` in `style`'s colours (its main family's; null: grey), with the NEW tag
## when `is_new` (dropping in unless `still`); its family glyphs from `palette` (null: the
## shared one).
func _init(
	item: BookEntry, style: FamilyStyle, is_new: bool, still: bool, palette: FamilyPalette = null
) -> void:
	_entry = item
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var grey: bool = not item.owned
	var coloured: bool = style != null and style.has_ticket_colours()
	var body: Color = style.face if coloured else Palette.CREAM_SHADE
	var light: Color = style.light if coloured else Palette.CREAM
	var shade: Color = style.shade if coloured else Palette.GREY
	var perk: bool = item.is_perk()
	_face = UiKit.sprite(BookArt.card_face(body, light, shade, grey, item.coupon, perk))
	_face.size = SIZE
	add_child(_face)
	var ink: Color = Palette.PAPER if coloured and style.paper_text and not grey else Palette.INK
	_name = _make_name(item.display_name().to_upper(), ink)
	add_child(_name)
	var looks: FamilyPalette = palette if palette != null else FamilyPalette.shared()
	var glyphs: Array[FamilyStyle] = []
	if perk:
		glyphs.append(perks_family_style())
		var boosted: FamilyStyle = looks.style(item.perk.boosts_tag)
		if not item.perk.boosts_tag.is_empty() and boosted != null:
			glyphs.append(boosted)
	elif item.coupon and style != null:
		glyphs.append(style)
	elif not item.coupon:
		glyphs = looks.styles(glyph_families(item, looks))
	for look: FamilyStyle in glyphs:
		if look.glyph == null:
			continue
		var glyph: FamilyGlyph = FamilyGlyph.new(look)
		glyph.name = "Glyph" if _glyphs.is_empty() else "Glyph%d" % (_glyphs.size() + 1)
		glyph.position = GLYPH_AT + Vector2(0, GLYPH_PITCH * _glyphs.size())
		glyph.size = GLYPH_SIZE
		add_child(glyph)
		_glyphs.append(glyph)
	if perk:
		_add_perk_window(item, grey)
	elif not grey and item.coupon:
		_figurine = ItemView.item_art(item.card)
		_figurine.name = "Figurine"
		_figurine.position = coupon_slip_at()
		add_child(_figurine)
	elif not grey:
		_figurine = UiKit.sprite(ArtStyle.item_sprite(item.card))
		_figurine.name = "Figurine"
		_figurine.position = FIGURINE_AT
		_figurine.size = FIGURINE_SIZE
		add_child(_figurine)
		_price = UiKit.number_label(PRICE_TEXT % item.card.base, PRICE_FONT_SIZE, false)
		_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_price.size = Vector2(
			PRICE_RECT.size.x, maxf(PRICE_RECT.size.y, _price.get_minimum_size().y)
		)
		_price.position = (PRICE_RECT.get_center() - _price.size / 2.0).round()
		add_child(_price)
	if perk:
		_description = _make_description(item.perk.effect_text.strip_edges(), perk_key(item.perk))
	else:
		_description = _make_description(description_text(item.card), item.card.id)
	add_child(_description)
	if is_new:
		_new_tag = ToyNewTag.new()
		_new_tag.position = NEW_TAG_AT
		add_child(_new_tag)
		_new_tag.set_shown(true, still)
	mouse_entered.connect(set_lifted.bind(true))
	mouse_exited.connect(set_lifted.bind(false))


func entry() -> BookEntry:
	return _entry


## The pieces, for tests: the face, the name (ItemName), the figurine (a coupon's slip; null on
## a grey card), the price (null on a grey card or a coupon), the description (a GlyphLabel, or
## the plain Label) and the NEW tag (null when not new).
func face() -> TextureRect:
	return _face


func name_control() -> Control:
	return _name


## The family glyphs, the main family's first (a coupon's: its coupon mark).
func family_glyphs() -> Array[TextureRect]:
	return _glyphs


func figurine() -> TextureRect:
	return _figurine


func price_label() -> Label:
	return _price


func description() -> Control:
	return _description


func new_tag() -> ToyNewTag:
	return _new_tag


## A perk card's stamp (null when not picked yet, or not a perk) and level pips (null too on a
## perk that never levels up).
func perk_ring() -> Control:
	return _ring


func level_pips() -> TextureRect:
	return _pips


## The description's text rect in this card's coordinates.
func description_rect() -> Rect2:
	var glyphs: GlyphLabel = _description as GlyphLabel
	if glyphs != null:
		return Rect2(_description.position + glyphs.text_rect().position, glyphs.text_rect().size)
	var plain: Label = _description as Label
	return Rect2(plain.position, plain.get_minimum_size())


## Whether the description shows in full inside TEXT_AREA.
func description_fits() -> bool:
	var glyphs: GlyphLabel = _description as GlyphLabel
	var fits: bool = glyphs == null or glyphs.fits()
	return fits and TEXT_AREA.grow(0.5).encloses(description_rect())


## Puts the card at `at` in its pocket (canvas px, at rest).
func place(at: Vector2) -> void:
	position = at
	_rest_y = at.y


## Lifts the card LIFT art px out of its pocket (the pointer is on it) or sets it back.
func set_lifted(lifted: bool) -> void:
	position.y = _rest_y - (float(LIFT * ArtStyle.ART_SCALE) if lifted else 0.0)


## The name in hard pixel words (PixelLine, as every word at the TOY MACHINES) on the band, its
## cap top NAME_CAP_TOP down; a name too wide for NAME_RECT falls back to the bold body font
## (ItemName.make's fallback, as the Cart prints a long name). Round 10: no tighter word gap first,
## since at 1 art px (the letter spacing) or 2 CATEGORY ENGINE read as one word.
func _make_name(text: String, ink: Color) -> Control:
	var line: PixelLine = PixelLine.new()
	line.show_tokens(PixelLine.split(text), ink, ink, 1, NAME_GAP)
	if line.width() <= NAME_RECT.size.x:
		line.name = "ItemName"
		line.position = Vector2(NAME_RECT.position.x, NAME_CAP_TOP)
		return line
	line.free()
	var label: Control = ItemName.make(text, NAME_RECT.size.x, NAME_RECT.size.y, ink)
	if ItemName.is_display(label):
		label.free()
		var fallback: Label = UiKit.body_label(
			text, ItemName.fallback_size(text, NAME_RECT.size.x), ink
		)
		fallback.add_theme_font_override("font", ArtStyle.bold_font(ArtStyle.NAME_FALLBACK_WEIGHT))
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.clip_text = true
		fallback.size = NAME_RECT.size
		label = fallback
	label.name = "ItemName"
	label.position = NAME_RECT.position
	return label


## A perk card's window (round 10): when picked, the perk's stamp (LoyaltyCard.make_ring of its
## LV 1, so no level badge) at PERK_RING_SCALE, taking no pointer (the card under it lifts), and
## the level pips of a perk that levels up.
func _add_perk_window(item: BookEntry, grey: bool) -> void:
	if grey:
		return
	var ring: PanelContainer = LoyaltyCard.make_ring(item.perk)
	ring.name = "PerkRing"
	TipTarget.cover_text(ring, "")  # No PERK tip: the card under it lifts.
	_ignore_pointer(ring)
	ring.size = LoyaltyCard.CHIP_BOX_SIZE
	ring.scale = Vector2.ONE * PERK_RING_SCALE
	ring.position = PERK_RING_AT
	add_child(ring)
	_ring = ring
	if item.levels > 1:
		var pips: Texture2D = BookArt.level_pips(item.level, item.levels)
		_pips = UiKit.sprite(pips)
		_pips.name = "LevelPips"
		_pips.size = pips.get_size() * ArtStyle.ART_SCALE
		_pips.position = PIPS_AT
		add_child(_pips)


static func _ignore_pointer(node: Node) -> void:
	var control: Control = node as Control
	if control != null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_pointer(child)


## The card's rule in plain language (`text`, "" for none), at the first tier that fits TEXT_AREA
## (else the smallest); the tier is found once per `key` (a card id, or perk_key) and kept, so
## later pages lay the rule out once.
func _make_description(text: String, key: StringName) -> Control:
	if text.is_empty():
		var plain: Label = UiKit.body_label(PLAIN_TEXT, TEXT_TIERS[0].x, Palette.MUTED_INK)
		plain.add_theme_font_override("font", ArtStyle.bold_font(TEXT_WEIGHT))
		plain.autowrap_mode = TextServer.AUTOWRAP_WORD
		plain.position = TEXT_AREA.position
		plain.size = Vector2(TEXT_AREA.size.x, 0)
		return plain
	var label: GlyphLabel = null
	if _tiers.has(key):
		label = _glyph_label(text, TEXT_TIERS[_tiers[key]])
	else:
		for index: int in TEXT_TIERS.size():
			var tier: Vector2i = TEXT_TIERS[index]
			label = _glyph_label(text, tier)
			var rows: int = floori(TEXT_AREA.size.y / tier.y)
			_tiers[key] = index
			if label.fits() and label.line_count() <= rows:
				break
			if index < TEXT_TIERS.size() - 1:
				label.free()
	label.position = TEXT_AREA.position
	label.size = TEXT_AREA.size
	return label


func _glyph_label(text: String, tier: Vector2i) -> GlyphLabel:
	var rows: int = floori(TEXT_AREA.size.y / tier.y)
	var label: GlyphLabel = GlyphLabel.new(
		text,
		ArtStyle.bold_font(TEXT_WEIGHT),
		tier.x,
		Palette.INK,
		tier.y,
		TEXT_AREA.size.x,
		rows,
		false,
		null,
		true
	)
	label.name = "Description"
	label.set_chip_room(CHIP_MARGIN, CHIP_PADDING)
	label.set_tip(true, self)
	return label


## The families whose glyphs an item's card shows, top down (round 7): its main family, then
## its other printed families by the ticket's label rule (FamilyPalette.shelf_families: Food
## only when it is the card's only family); none for a coupon.
static func glyph_families(item: BookEntry, palette: FamilyPalette) -> PackedStringArray:
	var shown: PackedStringArray = PackedStringArray()
	if item.coupon:
		return shown
	if not item.family.is_empty():
		shown.append(item.family)
	for family: String in palette.shelf_families(item.tags):
		if not shown.has(family):
			shown.append(family)
	return shown


## The coupon slip's top left on a coupon's card: its drawn pixels centred in the window, on the
## art grid.
static func coupon_slip_at() -> Vector2:
	var used: Rect2i = ArtStyle.COUPON_SLIP.get_image().get_used_rect()
	var window: Rect2i = BookArt.WINDOW_RECT
	var centre: Vector2 = Vector2(window.position) + Vector2(window.size) / 2.0
	var at: Vector2 = (centre - Vector2(used.position) - Vector2(used.size) / 2.0).floor()
	return at * ArtStyle.ART_SCALE


## A coupon card's look: the colours of its ticket (its first family with ticket colours, else
## the coupon teal, as PriceSticker colours it) and the coupon mark for its glyph.
static func coupon_style(card: CardDefinition, palette: FamilyPalette) -> FamilyStyle:
	var look: FamilyStyle = PriceSticker.coupon_teal()
	for family: FamilyStyle in palette.styles(palette.ticket_families(card)):
		if family.has_ticket_colours():
			look.face = family.face
			look.light = family.light
			look.shade = family.shade
			look.paper_text = family.paper_text
			break
	return _with_coupon_mark(look, palette)


## The coupons' FAMILY option and page header: the coupon teal, the coupon mark and COUPONS_NAME.
static func coupons_family_style(palette: FamilyPalette) -> FamilyStyle:
	return _with_coupon_mark(PriceSticker.coupon_teal(), palette)


## The perks' FAMILY option, page header and cards (round 10): the LOYALTY teal (the coupon
## teal), the PERKS mark and PERKS_NAME.
static func perks_family_style() -> FamilyStyle:
	var look: FamilyStyle = PriceSticker.coupon_teal()
	look.id = BookEntry.PERK_FAMILY
	look.display_name = PERKS_NAME
	look.glyph = PERK_MARK
	return look


## A FAMILY option's and page header's look for `family`: the coupons' (coupons_family_style),
## the perks' (perks_family_style), OTHER FOOD's (round 6: the Food family's colours and
## glyph, named OTHER_FOOD_NAME), else the family's own (null when the palette has none).
static func family_style(family: String, palette: FamilyPalette) -> FamilyStyle:
	if family == BookEntry.COUPON_FAMILY:
		return coupons_family_style(palette)
	if family == BookEntry.PERK_FAMILY:
		return perks_family_style()
	if family != BookEntry.OTHER_FOOD:
		return palette.style(family)
	var food: FamilyStyle = palette.style(BookEntry.FOOD_TAG)
	var look: FamilyStyle = food.duplicate() as FamilyStyle if food != null else FamilyStyle.new()
	look.id = BookEntry.OTHER_FOOD
	look.display_name = OTHER_FOOD_NAME
	return look


static func _with_coupon_mark(look: FamilyStyle, palette: FamilyPalette) -> FamilyStyle:
	var mark: FamilyStyle = palette.style(BookEntry.COUPON_FAMILY)
	look.id = BookEntry.COUPON_FAMILY
	look.display_name = COUPONS_NAME
	look.glyph = mark.glyph if mark != null else null
	return look


## The text a card's description shows (the monitor's): its monitor text, else its sticker
## summary, else its rule text ("" for a card with no rule).
static func description_text(card: CardDefinition) -> String:
	var text: String = CardText.monitor_text(card)
	if text.is_empty():
		text = CardText.sticker_summary(card)
	if text.is_empty() and not card.rules.is_empty():
		text = card.rule_text
	return text.strip_edges()


## The TEXT_TIERS index `card`'s rule was laid out at (-1: not shown yet), for tests.
static func tier_of(card: CardDefinition) -> int:
	return _tiers.get(card.id, -1)


## The TEXT_TIERS index `perk`'s rule was laid out at (-1: not shown yet), for tests.
static func perk_tier_of(perk: UpgradeDefinition) -> int:
	return _tiers.get(perk_key(perk), -1)


## The key a perk's tier is kept under, apart from the card ids.
static func perk_key(perk: UpgradeDefinition) -> StringName:
	return StringName("perk:%s" % perk.id)
