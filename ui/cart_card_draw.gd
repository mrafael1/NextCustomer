class_name CartCardDraw
extends RefCounted
## One card of the deck view's Cart page (the cart as cards, mock-up docs/art/mockups/
## cart_cards.html, its "2x8 cart face", approved by the user on 2026-11-13): the booster's card
## face (BoosterArt.face_sized) at the cart face's CW art px wide, drawn through an ArtPen at any
## unit. Over it: the copies stacked behind (up to STACK_MAX teal card backs, each STACK_STEP_X
## right and STACK_RISE up), the RARE's teal or the LEGENDARY's gold moving foil and the
## laminate over the art, the name band's hard pixel lines, the rarity tab over the top edge
## (COMMON, RARE, LEGENDARY) and a BIG or GOLDEN copy's tier sticker on the art's bottom right.
## The family chips stand down the art window's left edge, one under the other CHIP_PITCH apart
## (the user, 2026-11-13: "card should have second family icon like in toy book"): a product's
## are the FIGURINE BOOK's (FamilyPalette.card_glyph_families: its main family, then its other
## printed families, Food only on a Food-only card), a coupon's its ticket's families. This draws
## their coloured tiles; their glyphs are the cell's FamilyGlyph tip targets (DeckCell).
## The rule text is a GlyphLabel of the cell (DeckCell), its keywords and families as chips. The
## start screen's cards stay BoosterCardDraw's.

## The cart face's width (art px; the booster's is BoosterArt.CW) and height.
const CW := 84
const CH := BoosterArt.CH
## The copies stacked behind: at most STACK_MAX, each STACK_STEP_X art px right (the mock-up's 5;
## at least STACK_STEP_MIN where the column gap is narrow) and STACK_RISE up. A copy's back is a
## lighter teal than the well in an ink outline with a dark teal inner line (the mock-up's ghost).
const STACK_MAX := 2
const STACK_STEP_X := 5
const STACK_STEP_MIN := 2
const STACK_RISE := 4
const STACK_FILL := Palette.TEAL_SHADE
const STACK_LINE := Palette.TEAL_DARK
## The tab over the top edge: its height and how far above the card it starts (art px).
const TAB_HEIGHT := 11.0
const TAB_RISE := 6.0
const TAB_WORDS: Array[String] = ["COMMON", "RARE", "LEGENDARY"]
## The tier sticker on the art's bottom right (art px): its height and its rise over the
## window's foot.
const TIER_HEIGHT := 9
const TIER_RISE := 11
## A family chip (art px): its tile's size, its first tile's top under the art window's top, the
## step to the next (a tile and 1 art px, as the book steps its glyphs) and its glyph's inset.
const CHIP_SIZE := 12
const CHIP_TOP := 8
const CHIP_PITCH := CHIP_SIZE + 1
const CHIP_GLYPH_INSET := 2
## The foil's speed (tile px a second) and the gold foil's colours.
const FOIL_SPEED := 6.0

static var _gold_foil: ImageTexture


## `card`'s look: a product's tier (MachineDefinition.product_rarity: plain COMMON, BIG RARE,
## GOLDEN LEGENDARY), a coupon's rarity in `machine` (rare_coupons, legendary_coupons; COMMON
## without a machine).
static func look_of(card: CardDefinition, machine: MachineDefinition) -> BoosterArt.Look:
	var rarity: int = MachinePrize.Rarity.COMMON
	if card.is_product():
		rarity = MachineDefinition.product_rarity(card)
	elif machine != null:
		rarity = machine.coupon_rarity(card)
	match rarity:
		MachinePrize.Rarity.RARE:
			return BoosterArt.Look.RARE
		MachinePrize.Rarity.LEGENDARY:
			return BoosterArt.Look.LEGENDARY
	return BoosterArt.Look.COMMON


## The rule's box (art px) on `card`'s face in `look`: under the name band, over the foot.
static func rule_box(card: CardDefinition, look: BoosterArt.Look) -> Rect2:
	var text: Dictionary = BoosterArt.face_text(card, look != BoosterArt.Look.COMMON, CW)
	var win: Rect2i = text.window
	var top: float = text.rule_top
	return Rect2(win.position.x + 2, top, win.size.x - 4, float(text.rule_bottom) - top)


## The art window (art px) of a face in `look`.
static func window(look: BoosterArt.Look) -> Rect2i:
	return BoosterArt.window_of(look != BoosterArt.Look.COMMON, CW)


## The families whose chips `card`'s face shows, top down: a product's glyph families (the book's
## rule), a coupon's ticket families (BoosterArt.families: at most two; none for the plain one).
static func chip_families(card: CardDefinition) -> Array[FamilyStyle]:
	if not card.is_product():
		return BoosterArt.families(card)
	var palette: FamilyPalette = FamilyPalette.shared()
	return palette.styles(palette.card_glyph_families(card))


## Chip `index`'s tile (art px from the face's top left) on a face in `look`.
static func chip_rect(look: BoosterArt.Look, index: int) -> Rect2i:
	var win: Rect2i = window(look)
	return Rect2i(
		win.position.x + 1, win.position.y + CHIP_TOP + index * CHIP_PITCH, CHIP_SIZE, CHIP_SIZE
	)


## Draws `card` in `look` at the pen's origin with `copies` copies stacked behind it (each `step`
## art px right), the foil at clock `now` (s; `still`: no motion).
static func draw(
	pen: ArtPen,
	card: CardDefinition,
	look: BoosterArt.Look,
	copies: int,
	now: float = 0.0,
	still: bool = false,
	step: int = STACK_STEP_X
) -> void:
	for index: int in range(mini(copies - 1, STACK_MAX), 0, -1):
		var at: Vector2 = Vector2(step * index, -STACK_RISE * index)
		pen.rb(at.x, at.y, CW, CH, STACK_LINE)
		pen.r(at.x + 2, at.y + 2, CW - 4, CH - 4, STACK_FILL)
	var rare: bool = look != BoosterArt.Look.COMMON
	var off: int = 5 if still else int(floorf(now * FOIL_SPEED)) % 16
	if rare:
		var foil: Texture2D = (
			gold_foil_tile()
			if look == BoosterArt.Look.LEGENDARY
			else BoosterArt.foil_tile(2 if still else int(floorf(now / 0.35)) % 3)
		)
		pen.canvas.draw_texture_rect_region(
			foil, Rect2(pen.at(0, 0), pen.size_of(CW, CH)), Rect2(posmod(-off, 16), 0, CW, CH)
		)
	pen.tex(BoosterArt.face_sized(card, look, CW, false, false), 0, 0)
	var win: Rect2i = window(look)
	var chips: Array[FamilyStyle] = chip_families(card)
	for k: int in chips.size():
		var tile: Rect2i = chip_rect(look, k)
		pen.rb(tile.position.x, tile.position.y, CHIP_SIZE, CHIP_SIZE, chips[k].face)
		pen.r(tile.position.x + 1, tile.position.y + 1, CHIP_SIZE - 2, 1, chips[k].light)
	if rare:
		pen.canvas.draw_texture_rect_region(
			BoosterArt.laminate_tile(),
			Rect2(pen.at(win.position.x, win.position.y), pen.size_of(win.size.x, win.size.y)),
			Rect2(posmod(win.position.x - off, 16), win.position.y, win.size.x, win.size.y)
		)
	var text: Dictionary = BoosterArt.face_text(card, rare, CW)
	var lines: PackedStringArray = text.lines
	var coupon: bool = card.is_coupon()
	for k: int in lines.size():
		pen.pix(
			lines[k],
			win.position.x + win.size.x / 2.0,
			(text.band_y as int) + 3 + k * 9,
			Palette.PAPER if coupon else Palette.INK,
			1.0,
			HORIZONTAL_ALIGNMENT_CENTER
		)
	var tier: String = PriceSticker.tier_text(card) if card.is_product() else ""
	if not tier.is_empty():
		tier_sticker(pen, tier, card.tier == CardDefinition.Tier.GOLDEN, win)
	tab(pen, look, CW / 2.0, -TAB_RISE)


## The tier sticker `words` (BIG, GOLDEN) on art window `win`'s bottom right: mustard, or gold
## when `golden`, in the booster's BIG chip style.
static func tier_sticker(pen: ArtPen, words: String, golden: bool, win: Rect2i) -> void:
	var word: ImageTexture = ArtPen.word_texture(words, Palette.INK, false)
	var box: Rect2i = tier_rect(words, win)
	var x: int = box.position.x
	var y: int = box.position.y
	pen.rn(x, y, box.size.x, TIER_HEIGHT, Palette.GOLD if golden else Palette.MUSTARD)
	pen.r(x + 1, y + 1, box.size.x - 2, 1, Palette.PAPER if golden else Palette.MUSTARD_LIGHT)
	pen.tex(word, x + 3, y + 2)


## The tier sticker `words`' rect (art px) on art window `win`.
static func tier_rect(words: String, win: Rect2i) -> Rect2i:
	var w: int = ArtPen.word_texture(words, Palette.INK, false).get_width() + 6
	return Rect2i(win.end.x - w - 1, win.end.y - TIER_RISE, w, TIER_HEIGHT)


## The rarity tab centred on `cx` with its top at `y` (art px): COMMON on cream with a grey dot,
## RARE on teal and LEGENDARY on gold, each between two pixel diamonds.
static func tab(pen: ArtPen, look: BoosterArt.Look, cx: float, y: float) -> void:
	var label: String = TAB_WORDS[look]
	var rare: bool = look != BoosterArt.Look.COMMON
	var tw: float = tab_width(look)
	var x: float = roundf(cx - tw / 2.0)
	var fill: Color = Palette.CREAM
	var light: Color = Palette.PAPER
	var shade: Color = Palette.CREAM_SHADE
	var ink: Color = Palette.INK
	if look == BoosterArt.Look.RARE:
		fill = Palette.TEAL
		light = Palette.TEAL_LIGHT
		shade = Palette.TEAL_SHADE
		ink = Palette.PAPER
	elif look == BoosterArt.Look.LEGENDARY:
		fill = Palette.GOLD
		light = Palette.MUSTARD_PALE
		shade = Palette.BRASS
	pen.rn(x, y, tw, TAB_HEIGHT, fill)
	pen.r(x + 1, y + 1, tw - 2, 1, light)
	pen.r(x + 1, y + TAB_HEIGHT - 2, tw - 2, 1, shade)
	if rare:
		for px: float in [x + 3.0, x + tw - 6.0]:
			pen.r(px + 1, y + 3, 1, 1, ink)
			pen.r(px, y + 4, 3, 1, ink)
			pen.r(px + 1, y + 5, 1, 1, ink)
		pen.pix(label, x + tw / 2.0, y + 3, ink, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		pen.r(x + 4, y + 4, 2, 2, Palette.GREY)
		pen.pix(label, x + tw / 2.0 + 2, y + 3, ink, 1.0, HORIZONTAL_ALIGNMENT_CENTER)


## The rarity tab's width (art px) for `look`.
static func tab_width(look: BoosterArt.Look) -> float:
	var rare: bool = look != BoosterArt.Look.COMMON
	return ArtPen.pix_width(TAB_WORDS[look]) + (16.0 if rare else 13.0)


## The rarity tab's rect on a card face (art px from the face's top left), as draw() places it.
static func tab_rect(look: BoosterArt.Look) -> Rect2:
	var tw: float = tab_width(look)
	return Rect2(roundf(CW / 2.0 - tw / 2.0), -TAB_RISE, tw, TAB_HEIGHT)


## The LEGENDARY foil's 16x16 tile: brass with a gold diagonal stripe and pale glints (the
## booster's teal foil in gold).
static func gold_foil_tile() -> ImageTexture:
	if _gold_foil == null:
		var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Palette.BRASS)
		for y: int in 16:
			for x: int in 16:
				var dd: int = (x + y) % 16
				if dd < 2 or ((dd == 2 or dd == 15) and (x + y * 3) % 2 == 0):
					image.set_pixel(x, y, Palette.GOLD)
				elif dd == 8 and x % 2 == 0:
					image.set_pixel(x, y, Palette.MUSTARD_PALE)
		_gold_foil = ImageTexture.create_from_image(image)
	return _gold_foil
