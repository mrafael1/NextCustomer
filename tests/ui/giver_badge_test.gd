extends GdUnitTestSuite
## Sticker minis (mock-up docs/art/mockups/sticker_minis_v1.html): an ITEM giver badge with a
## mini (CardDefinition.badge_mini_ref) shows that 7x7 mini alone at 2x, die-cut, centred in the
## badge's 18x18 with no token and no initials; its GOLDEN copy has a gold outline where the plain
## one has ink; an item with no mini keeps its initials token, and the coupon, loyalty and
## inspection badges stay as before. Drained, the mini greys as the token does. Pure UI: no
## screen, no saves.

const EGGS := "res://art/minis/eggs.png"
const EGGS_GOLDEN := "res://art/minis/eggs_golden.png"
## A pixel on the eggs mini's outline (its top row: "..###..") and the gold it turns GOLDEN.
const OUTLINE_PIXEL := Vector2i(2, 0)
const GOLD := Color("ffcf3f")


func test_an_item_with_a_mini_shows_the_mini_alone() -> void:
	var badge: GiverBadge = auto_free(GiverBadge.new(GiverBadge.Kind.ITEM, "Eg", EGGS))
	assert_bool(badge.shows_mini()).is_true()
	assert_str(badge.texture().resource_path).is_equal(EGGS)
	assert_str(badge.initials()).is_empty()
	assert_that(badge.size).is_equal(GiverBadge.SIZE)
	# 7x7 at 2x, centred: a 2 px margin all round, the whole mini inside the badge.
	assert_that(badge.art_rect()).is_equal(Rect2(Vector2(2, 2), GiverBadge.MINI_SIZE))
	assert_bool(Rect2(Vector2.ZERO, badge.size).encloses(badge.art_rect())).is_true()
	assert_that(badge.texture().get_size() * ArtStyle.ART_SCALE).is_equal(GiverBadge.MINI_SIZE)
	# No token, no label: the mini is the badge's only child.
	assert_int(badge.get_child_count()).is_equal(1)


func test_a_golden_givers_mini_has_a_gold_outline() -> void:
	var plain: Image = (load(EGGS) as Texture2D).get_image()
	var golden: Image = (load(EGGS_GOLDEN) as Texture2D).get_image()
	assert_that(plain.get_pixelv(OUTLINE_PIXEL)).is_equal(Palette.INK)
	assert_that(golden.get_pixelv(OUTLINE_PIXEL)).is_equal(GOLD)
	# The fill is the same: only the outline changes.
	assert_that(golden.get_pixel(3, 3)).is_equal(plain.get_pixel(3, 3))
	# The GOLDEN tier's badge picks it through the data; BIG picks the plain one.
	var golden_card: CardDefinition = load("res://data/cards/eggs_golden.tres")
	var big_card: CardDefinition = load("res://data/cards/eggs_big.tres")
	assert_str(golden_card.badge_mini_ref()).is_equal(EGGS_GOLDEN)
	assert_str(big_card.badge_mini_ref()).is_equal(EGGS)
	var badge: GiverBadge = auto_free(
		GiverBadge.new(GiverBadge.Kind.ITEM, "Go", golden_card.badge_mini_ref())
	)
	assert_str(badge.texture().resource_path).is_equal(EGGS_GOLDEN)


func test_an_item_without_a_mini_keeps_its_initials() -> void:
	for mini_ref: String in ["", "res://art/minis/no_such_mini.png"]:
		var badge: GiverBadge = auto_free(GiverBadge.new(GiverBadge.Kind.ITEM, "Mi", mini_ref))
		assert_bool(badge.shows_mini()).override_failure_message(mini_ref).is_false()
		assert_str(badge.initials()).is_equal("Mi")
		assert_object(badge.texture()).is_same(GiverBadge.ITEM_TOKEN)
		assert_that(badge.art_rect()).is_equal(Rect2(Vector2.ZERO, GiverBadge.SIZE))


## A product with no mini in its data (every live product has one since v0.52, so a live card
## with its minis cleared stands in for one added before its art): its plain, BIG and GOLDEN
## cards give no badge mini, and the badge built from them shows the name's initials on the item
## token.
func test_a_product_with_no_mini_in_its_data_shows_its_initials() -> void:
	var plain: CardDefinition = (load("res://data/cards/eggs.tres") as CardDefinition).duplicate()
	plain.mini_art_ref = ""
	plain.mini_golden_art_ref = ""
	var tiers: Array[CardDefinition] = [plain]
	for path: String in ["res://data/cards/eggs_big.tres", "res://data/cards/eggs_golden.tres"]:
		var tier: CardDefinition = (load(path) as CardDefinition).duplicate()
		tier.variant_of = plain
		tiers.append(tier)
	for card: CardDefinition in tiers:
		assert_str(card.badge_mini_ref()).override_failure_message(card.id).is_empty()
		var initials: String = GiverBadge.initials_for(GiverBadge.Kind.ITEM, card.display_name)
		var badge: GiverBadge = auto_free(
			GiverBadge.new(GiverBadge.Kind.ITEM, initials, card.badge_mini_ref())
		)
		assert_bool(badge.shows_mini()).override_failure_message(card.id).is_false()
		assert_str(badge.initials()).override_failure_message(card.id).is_not_empty()
		assert_str(badge.initials()).is_equal(initials)
		assert_object(badge.texture()).is_same(GiverBadge.ITEM_TOKEN)


func test_coupon_loyalty_and_inspection_badges_are_unchanged() -> void:
	# A mini given to another kind is ignored.
	var coupon: GiverBadge = auto_free(GiverBadge.new(GiverBadge.Kind.COUPON, "Mu", EGGS))
	assert_bool(coupon.shows_mini()).is_false()
	assert_object(coupon.texture()).is_same(GiverBadge.COUPON_TOKEN)
	assert_str(coupon.initials()).is_equal("Mu")
	var loyalty: GiverBadge = auto_free(GiverBadge.new(GiverBadge.Kind.LOYALTY, "SlE", EGGS))
	assert_bool(loyalty.shows_mini()).is_false()
	assert_object(loyalty.texture()).is_same(GiverBadge.LOYALTY_TOKEN)
	assert_str(loyalty.initials()).is_equal("SlE")
	var inspection: GiverBadge = auto_free(GiverBadge.new(GiverBadge.Kind.INSPECTION, "", EGGS))
	assert_bool(inspection.shows_mini()).is_false()
	assert_object(inspection.texture()).is_same(GiverBadge.WARNING)
	assert_that(inspection.size).is_equal(GiverBadge.INSPECTION_SIZE)


func test_a_drained_mini_greys() -> void:
	var badge: GiverBadge = auto_free(GiverBadge.new(GiverBadge.Kind.ITEM, "Eg", EGGS))
	var drawn: TextureRect = badge.get_child(0) as TextureRect
	badge.set_drained(true)
	assert_bool(badge.is_drained()).is_true()
	assert_object(drawn.material).is_same(ArtStyle.grey_material(ArtStyle.Grey.DRAINED))
	badge.set_drained(false)
	assert_object(drawn.material).is_same(ArtStyle.pixel_material())


## On a sticker, the mini badge hangs off the sticker's left edge as the token did, vertically
## centred on it: the stack's layout is unchanged.
func test_a_sticker_hangs_the_mini_badge_as_before() -> void:
	for kind: StickerSpec.Kind in [StickerSpec.Kind.ADD, StickerSpec.Kind.MULTIPLY]:
		var spec: StickerSpec = StickerSpec.new()
		spec.kind = kind
		spec.text = "×2" if kind == StickerSpec.Kind.MULTIPLY else "+3"
		spec.badge = GiverBadge.Kind.ITEM
		spec.badge_text = "Eg"
		spec.badge_mini = EGGS
		var sticker: EffectSticker = auto_free(EffectSticker.new(spec))
		var badge: GiverBadge = sticker.badge()
		assert_bool(badge.shows_mini()).is_true()
		assert_float(badge.position.x).is_equal(-EffectSticker.badge_overhang(spec))
		var art: Rect2 = badge.art_rect()
		art.position += badge.position
		assert_bool(art.position.y >= 0.0).is_true()
		assert_bool(art.end.y <= sticker.size.y).is_true()
		assert_bool(art.end.x > 0.0).is_true()  # it overlaps the sticker's left edge
