extends GdUnitTestSuite
## The price ticket (#75; #105's readability pass, mock-up readability v3): every card in
## data/cards (every tier) shows its summary from core (CardDefinition.sticker_summary) in at most
## 2 lines inside SUMMARY_RECT, its family glyphs in the glyph row (4 + 20j, 5), 18x18, its plain
## price tag on the corner at rest, all inside the ticket and apart, and its face in the colours of
## the family it works with (FamilyPalette, data). Struck (#71, #105) the old price stands under
## the pay tag, right-aligned at STRUCK_RIGHT, 15 px, its strike low across it (tomato on a light
## ticket, paper on a dark one), and the text's first line keeps clear of it (a text that needs
## its whole first line puts it beside the tag, clear of the glyphs); a wide burst squeezes a
## two-glyph row; a coupon's COUPON shrinks to stay clear of its €0 tag. set_got rings a product's
## ticket. Its colour says what it means in a tooltip (ColourSpot). No ticket carries the staple
## padlock.

const LiveCardCount := preload("res://tests/data/live_card_count.gd")
const CARDS := "res://data/cards"
## A number that isn't an ordinal ("2nd" stays): the data's numbers, which balance passes may
## change.
const NUMBER := "\\d+(?!st|nd|rd|th)"
## The approved readings of style frame v2's cards (spec section 4.1), every number from the data
## as N.
const READINGS: Dictionary[String, String] = {
	"eggs": "×N next Food",
	"tea_bags": "×N next Breakfast",
	# The Banana chain (#106) replaced v2's "+N after Banana".
	"banana": "+prev after Banana",
	"batteries": "+N in last slot",
	"two_for_one": "Same both sides: 2nd ×N",
	"crisps": "+N beside Bread",
	"coffee": "+N next Breakfast",
	"milk": "+N per earlier Breakfast",
	"cheese": "+N after Bread",
	"strawberries": "+N beside Produce",
	"croissant": "+N beside Bakery",
	"multipack": "×N later with prior's tag",
}
## The pay tags' rects on a ticket (mock-up v3, ticketHTML): the burst, the wide burst (and where
## it moves over a two-glyph row) and a plain or €0 tag.
const BURST := Rect2(54, -6, 60, 32)
const WIDE := Rect2(42, -12, 80, 36)
const WIDE_CLEAR := Rect2(46, -12, 80, 36)
const PLAIN := Rect2(60, -4, 52, 26)
## The pay tag's die-cut: two art pixels round its art.
const CUT := 4.0


## Every ticket, at rest and struck under each pay tag: its glyphs, price and text are where the
## mock-up puts them, inside the ticket and apart.
func test_every_ticket_lays_out_inside_and_apart() -> void:
	var cards: Array[CardDefinition] = _cards()
	assert_int(cards.size()).is_equal(LiveCardCount.CARDS)
	var palette: FamilyPalette = FamilyPalette.shared()
	var face: Rect2 = Rect2(Vector2.ZERO, PriceSticker.SIZE)
	var problems: PackedStringArray = PackedStringArray()
	for definition: CardDefinition in cards:
		var sticker: PriceSticker = auto_free(PriceSticker.new(definition))
		add_child(sticker)
		var id: String = String(definition.id)
		var summary: GlyphLabel = sticker.summary()
		if summary.text != definition.sticker_summary():
			problems.append("%s: summary '%s'" % [id, summary.text])
		if not summary.fits() or summary.line_count() > PriceSticker.MAX_SUMMARY_LINES:
			problems.append("%s: summary over 2 lines" % id)
		var text: Rect2 = sticker.summary_text_rect()
		var box: Rect2 = PriceSticker.SUMMARY_RECT.grow_side(SIDE_TOP, 1)
		if text.has_area() and not box.encloses(text):
			problems.append("%s: summary %s outside %s" % [id, text, box])
		if sticker.face_families() != palette.ticket_families(definition):
			problems.append("%s: face %s" % [id, sticker.face_families()])
		if sticker.find_children("*Lock*", "", true, false).size() > 0:
			problems.append("%s: a padlock" % id)
		var expected: PackedStringArray = PackedStringArray()
		if definition.is_product():
			expected = palette.shelf_families(definition.tags)
		var shown: PackedStringArray = PackedStringArray()
		for index: int in sticker.glyphs().size():
			var glyph: FamilyGlyph = sticker.glyphs()[index]
			shown.append(glyph.family)
			var at: Rect2 = Rect2(PriceSticker.GLYPH_ROW + Vector2(20 * index, 0), Vector2(18, 18))
			if Rect2(glyph.position, glyph.size) != at or not face.encloses(glyph.rim_rect()):
				problems.append("%s: glyph %d at %s" % [id, index, glyph.position])
			if text.has_area() and glyph.rim_rect().intersects(text):
				problems.append("%s: glyph %d over the text" % [id, index])
		if shown != expected:
			problems.append("%s: glyphs %s, not %s" % [id, shown, expected])
		if definition.is_coupon():
			if sticker.plain_tag() != null or sticker.coupon_title() == null:
				problems.append("%s: a coupon's head" % id)
			continue
		problems.append_array(_struck_problems(sticker, id, text))
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


func test_the_v2_cards_read_as_approved() -> void:
	var number: RegEx = RegEx.create_from_string(NUMBER)
	for card_id: String in READINGS:
		var sticker: PriceSticker = auto_free(PriceSticker.new(_card(card_id)))
		var text: String = sticker.summary().text
		assert_str(number.sub(text, "N", true)).override_failure_message(card_id).is_equal(
			READINGS[card_id]
		)


## A card with no rule (Bread) shows only its price: an empty summary, its plain tag.
func test_a_card_with_no_rule_shows_only_its_price() -> void:
	var bread: CardDefinition = _card("bread")
	assert_bool(bread.rules.is_empty()).is_true()
	var sticker: PriceSticker = auto_free(PriceSticker.new(bread))
	assert_str(sticker.summary().text).is_empty()
	assert_bool(sticker.summary_text_rect().has_area()).is_false()
	assert_str(sticker.plain_tag().text()).is_equal("€%d" % bread.base)


## The face (mock-up v3, frame3URL): an ink outline with cut corners, the family's light top row,
## its shade on the right column and the bottom row, its face colour inside; the text in ink or
## paper by the family (Clearance and Household are paper).
func test_the_face_is_in_its_familys_colours() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var cases: Dictionary[String, Array] = {
		"milk": ["Breakfast", Palette.INK],
		"cereal": ["Dairy", Palette.INK],
		"banana": ["Produce", Palette.INK],
		"eggs": ["Food", Palette.INK],
		"batteries": ["Household", Palette.PAPER],
		"final_markdown": ["Clearance", Palette.PAPER],
	}
	for card_id: String in cases:
		var sticker: PriceSticker = auto_free(PriceSticker.new(_card(card_id)))
		var family: FamilyStyle = palette.style(cases[card_id][0] as String)
		assert_array(Array(sticker.face_families())).contains_exactly([family.id])
		assert_object(sticker.text_color()).override_failure_message(card_id).is_equal(
			cases[card_id][1]
		)
		var art: Image = (sticker.face() as TextureRect).texture.get_image()
		assert_vector(Vector2(art.get_size())).is_equal(PriceSticker.SIZE / 2.0)
		var coupon: bool = _card(card_id).is_coupon()
		assert_str(_hex(art.get_pixel(10, 10))).override_failure_message(card_id).is_equal(
			_hex(family.face)
		)
		if not coupon:
			assert_str(_hex(art.get_pixel(10, 1))).is_equal(_hex(family.light))
		assert_str(_hex(art.get_pixel(52, 10))).is_equal(_hex(family.shade))
		assert_str(_hex(art.get_pixel(10, 30))).is_equal(_hex(family.shade))
		assert_str(_hex(art.get_pixel(10, 0))).is_equal(_hex(ArtStyle.INK))
		assert_float(art.get_pixel(0, 0).a).is_equal(0.0)
		assert_float(art.get_pixel(53, 31).a).is_equal(0.0)
		# Its text's ink matches the face.
		assert_object(sticker.summary().color()).is_equal(cases[card_id][1])


## The plain coupon keeps its slip with COUPON in teal dark; a family coupon (the Breakfast
## sticker) gets its family's face, perforated, and COUPON in the ticket's text colour.
func test_coupons_show_coupon_on_their_face() -> void:
	var plain: PriceSticker = auto_free(PriceSticker.new(_card("multipack")))
	assert_object((plain.face() as TextureRect).texture).is_same(PriceSticker.COUPON_FRAME)
	var title: Label = plain.coupon_title()
	assert_vector(title.position).is_equal(PriceSticker.COUPON_TITLE_AT)
	assert_object(title.get_theme_color("font_color")).is_equal(Palette.TEAL_DARK)
	assert_int(title.get_theme_font_size("font_size")).is_equal(12)
	var family: PriceSticker = auto_free(PriceSticker.new(_card("breakfast_sticker")))
	var breakfast: FamilyStyle = FamilyPalette.shared().style("Breakfast")
	var art: Image = (family.face() as TextureRect).texture.get_image()
	# Rows 1 and 2 perforated: shade, shade, light.
	assert_str(_hex(art.get_pixel(1, 1))).is_equal(_hex(breakfast.shade))
	assert_str(_hex(art.get_pixel(3, 2))).is_equal(_hex(breakfast.light))
	assert_str(_hex(art.get_pixel(10, 10))).is_equal(_hex(breakfast.face))
	assert_object(family.coupon_title().get_theme_color("font_color")).is_equal(Palette.INK)
	# Beside a coupon's tag (a fizzled €0) COUPON stays, shrunk to end clear of the tag's die-cut;
	# never struck, never ringed.
	for coupon: PriceSticker in [plain, family]:
		coupon.set_pay(true, PLAIN)
		var shown: Label = coupon.coupon_title()
		assert_bool(coupon.is_struck()).is_false()
		assert_bool(shown.visible).is_true()
		var font: Font = shown.get_theme_font("font")
		var font_size: int = shown.get_theme_font_size("font_size")
		var width: float = (
			font
			. get_string_size(PriceSticker.COUPON_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			. x
		)
		assert_float(shown.position.x + width).is_less_equal(
			PLAIN.grow(CUT).position.x - PriceSticker.COUPON_TAG_GAP
		)
		assert_int(font_size).is_greater_equal(PriceSticker.COUPON_TITLE_FITS[-1].x)
	plain.set_got(true)
	assert_bool(plain.is_got()).is_false()
	plain.set_pay(false, Rect2())
	assert_bool(title.visible).is_true()
	assert_int(title.get_theme_font_size("font_size")).is_equal(12)


## A split ticket (two families): a 45° stair, the second family past it, the seam in its light.
func test_a_split_face_is_a_stair_with_a_seam() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var first: FamilyStyle = palette.style("Produce")
	var second: FamilyStyle = palette.style("Dairy")
	var styles: Array[FamilyStyle] = [first, second]
	var art: Image = TicketFace.image(styles, false)
	assert_str(_hex(art.get_pixel(5, 5))).is_equal(_hex(first.face))
	assert_str(_hex(art.get_pixel(40, 20))).is_equal(_hex(second.face))
	assert_str(_hex(art.get_pixel(22, 20))).is_equal(_hex(second.light))
	assert_str(_hex(art.get_pixel(21, 20))).is_equal(_hex(first.face))
	assert_str(_hex(art.get_pixel(30, 1))).is_equal(_hex(first.light))
	assert_str(_hex(art.get_pixel(45, 1))).is_equal(_hex(second.light))


## Struck: the plain tag hides under the pinned tag, the old price stands under it (the tag draws
## it, PayTag.show_struck; alone it draws itself), right-aligned at STRUCK_RIGHT, 15 px, its
## strike 2 px thick at round(15 × 0.62) under its top, 2 px past each end: tomato with a paper
## rim on a light ticket, paper on a dark one; the text's first line keeps clear of it.
func test_a_struck_price_stands_under_the_tag() -> void:
	var milk: PriceSticker = auto_free(PriceSticker.new(_card("milk")))
	add_child(milk)
	milk.set_pay(true, BURST)
	assert_bool(milk.is_struck()).is_true()
	assert_bool(milk.plain_tag().visible).is_false()
	assert_bool(milk.struck_price().visible).is_false()
	milk.set_pay(true, Rect2())
	assert_bool(milk.struck_price().visible).is_true()
	var struck: Rect2 = milk.struck_rect()
	assert_float(struck.end.x).is_equal(PriceSticker.STRUCK_RIGHT)
	assert_float(struck.position.y).is_equal(PriceSticker.STRUCK_TOP)
	assert_float(struck.size.y).is_equal(PriceSticker.STRUCK_HEIGHT)
	var line: Rect2 = milk.strike_rect()
	assert_float(line.position.y).is_equal(PriceSticker.STRUCK_TOP + 9.0)
	assert_float(line.size.y).is_equal(2.0)
	assert_float(line.position.x).is_equal(struck.position.x - 2.0)
	assert_float(line.size.x).is_equal(struck.size.x + 4.0)
	assert_object(milk.struck_price().strike_color()).is_equal(Palette.TOMATO)
	assert_object(milk.struck_price().text_color()).is_equal(Palette.INK)
	var first: Rect2 = milk.summary().first_line_rect()
	first.position += milk.summary().position
	assert_bool(first.intersects(struck)).is_false()
	var dark: PriceSticker = auto_free(PriceSticker.new(_card("batteries")))
	dark.set_pay(true, Rect2())
	assert_object(dark.struck_price().strike_color()).is_equal(Palette.PAPER)
	assert_object(dark.struck_price().text_color()).is_equal(Palette.PAPER)
	assert_float(milk.struck_rect().position.y).is_equal(PriceSticker.STRUCK_TOP)
	# A text that needs its whole first line (the soups') keeps it: the old price stands beside
	# the tag instead, at the glyph row's height, clear of the tag's die-cut and of the glyphs.
	for soup_id: String in ["soup", "soup_big", "soup_golden"]:
		var soup: PriceSticker = auto_free(PriceSticker.new(_card(soup_id)))
		for tag: Rect2 in [PLAIN, BURST]:
			soup.set_pay(true, tag)
			var beside: Rect2 = soup.struck_rect()
			var message: String = "%s under %s: %s" % [soup_id, tag, beside]
			assert_bool(soup.is_struck()).override_failure_message(message).is_true()
			assert_bool(soup.summary().fits()).override_failure_message(message).is_true()
			assert_float(beside.position.y).is_equal(PriceSticker.STRUCK_BESIDE_TOP)
			assert_float(beside.end.x).override_failure_message(message).is_less_equal(
				tag.grow(CUT).position.x - PriceSticker.STRIKE_OUT
			)
			for glyph: FamilyGlyph in soup.glyphs():
				assert_bool(glyph.rim_rect().intersects(soup.strike_rect())).is_false()
			assert_bool(beside.intersects(soup.summary_text_rect())).is_false()
			assert_bool(Rect2(Vector2.ZERO, PriceSticker.SIZE).encloses(beside)).is_true()
	milk.set_pay(false, Rect2())
	assert_bool(milk.is_struck()).is_false()
	assert_bool(milk.plain_tag().visible).is_true()
	assert_bool(milk.struck_price().visible).is_false()


## A wide burst over a two-glyph row (Golden Milk at €126): at WIDE_CLEAR its die-cut meets the
## squeezed row (the second glyph at x 22), both glyphs show; at WIDE the second would be cut, so
## it hides.
func test_a_wide_burst_squeezes_two_glyphs() -> void:
	var golden: PriceSticker = auto_free(PriceSticker.new(_card("milk_golden")))
	assert_int(golden.glyphs().size()).is_equal(2)
	golden.set_pay(true, WIDE_CLEAR)
	assert_bool(golden.is_squeezed()).is_true()
	assert_float(golden.glyphs()[1].position.x).is_equal(22.0)
	for glyph: FamilyGlyph in golden.glyphs():
		assert_bool(glyph.visible).is_true()
		assert_bool(glyph.rim_rect().intersects(WIDE_CLEAR.grow(CUT))).is_false()
	golden.set_pay(true, WIDE)
	assert_bool(golden.glyphs()[0].visible).is_true()
	assert_bool(golden.glyphs()[1].visible).is_false()
	golden.set_pay(false, Rect2())
	assert_bool(golden.is_squeezed()).is_false()
	assert_float(golden.glyphs()[1].position.x).is_equal(24.0)
	assert_bool(golden.glyphs()[1].visible).is_true()


## A hovered giver's target (#71) gets a gold ring inside its outline, its face unchanged.
func test_got_rings_a_products_ticket() -> void:
	var milk: PriceSticker = auto_free(PriceSticker.new(_card("milk")))
	var face: Texture2D = (milk.face() as TextureRect).texture
	milk.set_got(true)
	assert_bool(milk.is_got()).is_true()
	assert_bool(milk.got_ring().visible).is_true()
	assert_object((milk.face() as TextureRect).texture).is_same(face)
	milk.set_got(false)
	assert_bool(milk.got_ring().visible).is_false()


## The ticket's colour has a tooltip below the ticket (ColourSpot over the whole face, under its
## glyphs): what the colour means (FamilyPalette.colour_tip).
func test_the_colour_says_what_it_means() -> void:
	var expected: Dictionary[String, String] = {
		"milk": "Breakfast colour · works with Breakfast",
		"cereal": "Dairy colour · works with Milk",
		"banana": "Produce colour · works with another Banana",
		"breakfast_sticker": "Breakfast colour · gives Breakfast",
		"batteries": "Household colour · its own family",
		"multipack": "Plain coupon: works with whatever is beside it",
	}
	for id: String in expected:
		var sticker: PriceSticker = auto_free(PriceSticker.new(_card(id)))
		add_child(sticker)
		var spot: PriceSticker.ColourSpot = _spot(sticker)
		assert_object(spot).override_failure_message(id).is_not_null()
		assert_str(spot.tip_text).override_failure_message(id).is_equal(expected[id])
		assert_bool(spot.tip_below).is_true()
		assert_object(spot.tip_anchor).is_same(sticker)
		assert_that(Rect2(spot.position, spot.size)).is_equal(
			Rect2(Vector2.ZERO, PriceSticker.SIZE)
		)
		# Under every glyph, so a glyph's own tip wins where they overlap.
		for glyph: FamilyGlyph in sticker.glyphs() + sticker.summary().glyphs():
			assert_bool(glyph.is_greater_than(spot)).override_failure_message(id).is_true()


## The glyphs' tooltips open below the ticket (GlyphTips): the row's and the text's, each with
## its paper rim.
func test_every_glyph_tips_below_its_ticket() -> void:
	var scissors: PriceSticker = auto_free(PriceSticker.new(_card("scissors")))
	var glyphs: Array[FamilyGlyph] = scissors.glyphs() + scissors.summary().glyphs()
	assert_int(scissors.summary().glyphs().size()).is_equal(1)
	assert_str(scissors.summary().glyphs()[0].family).is_equal("Coupon")
	for glyph: FamilyGlyph in glyphs:
		assert_bool(glyph.tip_below).is_true()
		assert_object(glyph.tip_anchor).is_same(scissors)
		assert_object(glyph.rim()).is_not_null()


## `id` at rest and struck under each pay tag its row could pin: the plain tag on the corner, the
## glyphs and the text clear of every tag's die-cut and of the struck price.
func _struck_problems(sticker: PriceSticker, id: String, text: Rect2) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	if sticker.plain_tag_rect() != PLAIN:
		problems.append("%s: plain tag at %s" % [id, sticker.plain_tag_rect()])
	for glyph: FamilyGlyph in sticker.glyphs():
		if glyph.rim_rect().intersects(PLAIN):
			problems.append("%s: a glyph under the plain tag" % id)
	if text.has_area() and text.intersects(PLAIN):
		problems.append("%s: the text under the plain tag" % id)
	var two: bool = sticker.glyphs().size() > 1
	var tags: Array[Rect2] = [BURST, WIDE_CLEAR if two else WIDE, PLAIN]
	for tag: Rect2 in tags:
		sticker.set_pay(true, tag)
		var cut: Rect2 = tag.grow(CUT)
		for glyph: FamilyGlyph in sticker.glyphs():
			if not glyph.visible:
				problems.append("%s: a glyph hidden under %s" % [id, tag])
			elif glyph.rim_rect().intersects(cut):
				problems.append("%s: a glyph under %s" % [id, tag])
		var struck: Rect2 = sticker.struck_rect()
		var first: Rect2 = sticker.summary().first_line_rect()
		first.position += sticker.summary().position
		if sticker.is_struck() and first.has_area() and first.intersects(struck):
			problems.append("%s: the first line under the struck price" % id)
		if sticker.is_struck() and struck.position.y == PriceSticker.STRUCK_BESIDE_TOP:
			if struck.intersects(cut) or struck.intersects(sticker.summary_text_rect()):
				problems.append("%s: the struck price beside %s cut" % [id, tag])
			for glyph: FamilyGlyph in sticker.glyphs():
				if glyph.visible and glyph.rim_rect().intersects(struck):
					problems.append("%s: the struck price over a glyph" % id)
		if not sticker.summary().fits():
			problems.append("%s: the text cut when struck" % id)
	sticker.set_pay(false, Rect2())
	return problems


static func _spot(sticker: PriceSticker) -> PriceSticker.ColourSpot:
	return sticker.get_node(PriceSticker.COLOUR_SPOT_NAME) as PriceSticker.ColourSpot


static func _hex(colour: Color) -> String:
	return colour.to_html()


static func _card(card_id: String) -> CardDefinition:
	return load("%s/%s.tres" % [CARDS, card_id]) as CardDefinition


static func _cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file: String in DirAccess.get_files_at(CARDS):
		if file.ends_with(".tres"):
			cards.append(load("%s/%s" % [CARDS, file]) as CardDefinition)
	return cards
