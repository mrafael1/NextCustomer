extends GdUnitTestSuite
## Readability v2's larger giver plates: a 10x10 product drawing with a paper or GOLDEN rim
## inside a 28 px badge. Coupon and loyalty tokens share that size; inspection keeps its warning.
## The original 7x7 minis still select the plates and remain available to the monitor. Missing
## product art falls back to initials. Pure UI: no screen or saves.

const EGGS := "res://art/minis/eggs.png"
const EGGS_GOLDEN := "res://art/minis/eggs_golden.png"
## A pixel on the eggs mini's outline (its top row: "..###..") and the gold it turns GOLDEN.
const OUTLINE_PIXEL := Vector2i(2, 0)
const GOLD := Color("ffcf3f")


func test_an_item_with_a_mini_shows_its_larger_framed_plate() -> void:
	var badge: GiverBadge = auto_free(GiverBadge.new(GiverBadge.Kind.ITEM, "Eg", EGGS))
	assert_bool(badge.shows_mini()).is_true()
	assert_str(badge.texture().resource_path).is_equal(
		GiverBadge.PLATE_FOLDER.path_join("eggs.png")
	)
	assert_str(badge.initials()).is_empty()
	assert_that(badge.size).is_equal(GiverBadge.SIZE)
	# A 14x14 native plate at 2x, including the die-cut rim and ink edge.
	assert_that(badge.art_rect()).is_equal(Rect2(Vector2.ZERO, GiverBadge.SIZE))
	assert_bool(Rect2(Vector2.ZERO, badge.size).encloses(badge.art_rect())).is_true()
	assert_that(badge.texture().get_size() * ArtStyle.ART_SCALE).is_equal(GiverBadge.SIZE)
	# No token, no label: the mini is the badge's only child.
	assert_int(badge.get_child_count()).is_equal(1)


func test_every_product_mini_has_a_larger_plate() -> void:
	for file_name: String in DirAccess.get_files_at("res://art/minis"):
		if file_name.get_extension() != "png":
			continue
		var plate: Texture2D = load(GiverBadge.PLATE_FOLDER.path_join(file_name))
		assert_object(plate).override_failure_message(file_name).is_not_null()
		assert_that(plate.get_size() * ArtStyle.ART_SCALE).is_equal(GiverBadge.SIZE)
	var plain: Image = (
		(load(GiverBadge.PLATE_FOLDER.path_join("eggs.png")) as Texture2D).get_image()
	)
	var golden: Image = (
		(load(GiverBadge.PLATE_FOLDER.path_join("eggs_golden.png")) as Texture2D).get_image()
	)
	# Only the die-cut rim changes: the egg's drawing and the outer ink edge stay legible.
	assert_that(plain.get_pixel(5, 1)).is_equal(Palette.PAPER)
	assert_that(golden.get_pixel(5, 1)).is_equal(GOLD)
	assert_that(golden.get_pixel(5, 0)).is_equal(Palette.INK)
	assert_that(golden.get_pixel(5, 3)).is_equal(plain.get_pixel(5, 3))


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
	assert_str(badge.texture().resource_path).is_equal(
		GiverBadge.PLATE_FOLDER.path_join("eggs_golden.png")
	)


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


func test_coupon_and_loyalty_plates_are_larger_and_inspection_keeps_its_icon() -> void:
	# A mini given to another kind is ignored.
	var coupon: GiverBadge = auto_free(GiverBadge.new(GiverBadge.Kind.COUPON, "Mu", EGGS))
	assert_bool(coupon.shows_mini()).is_false()
	assert_object(coupon.texture()).is_same(GiverBadge.COUPON_TOKEN)
	assert_str(coupon.initials()).is_equal("Mu")
	var loyalty: GiverBadge = auto_free(GiverBadge.new(GiverBadge.Kind.LOYALTY, "RuB"))
	assert_bool(loyalty.shows_mini()).is_false()
	assert_bool(loyalty.shows_icon()).is_false()
	assert_object(loyalty.texture()).is_same(GiverBadge.LOYALTY_TOKEN)
	assert_str(loyalty.initials()).is_equal("RuB")
	var inspection: GiverBadge = auto_free(GiverBadge.new(GiverBadge.Kind.INSPECTION, "", EGGS))
	assert_bool(inspection.shows_mini()).is_false()
	assert_object(inspection.texture()).is_same(GiverBadge.WARNING)
	assert_that(inspection.size).is_equal(GiverBadge.INSPECTION_SIZE)


## A loyalty badge holds its perk's icon on the stamp token (#108 follow-up), centred on the art
## grid, with no initials; an icon too big for the token (Big basket's ticket) or a missing one
## keeps the initials. Drained, the icon greys with the token.
func test_a_loyalty_badge_shows_its_perk_icon() -> void:
	var glyph: String = "res://art/icons/aisle_fruit_and_veg.png"
	var badge: GiverBadge = auto_free(GiverBadge.new(GiverBadge.Kind.LOYALTY, "PrR", glyph))
	assert_bool(badge.shows_icon()).is_true()
	assert_bool(badge.shows_mini()).is_false()
	# The thin-rimmed token, whose middle holds a 9x9 icon (polish pass).
	assert_object(badge.texture()).is_same(GiverBadge.LOYALTY_ICON_TOKEN)
	assert_str(badge.icon_texture().resource_path).is_equal(glyph)
	assert_str(badge.initials()).is_empty()
	var icon: TextureRect = badge.get_node("Icon") as TextureRect
	assert_vector(icon.size).is_equal(Vector2(18, 18))
	(
		assert_bool(Rect2(Vector2.ZERO, GiverBadge.SIZE).encloses(Rect2(icon.position, icon.size)))
		. is_true()
	)
	assert_float(fmod(icon.position.x, ArtStyle.ART_SCALE)).is_equal(0.0)
	badge.set_drained(true)
	assert_object(icon.material).is_same(ArtStyle.grey_material(ArtStyle.Grey.DRAINED))
	var big: GiverBadge = auto_free(
		GiverBadge.new(GiverBadge.Kind.LOYALTY, "BiB", "res://art/icons/plus_slot.png")
	)
	assert_bool(big.shows_icon()).is_false()
	assert_object(big.texture()).is_same(GiverBadge.LOYALTY_TOKEN)
	assert_str(big.initials()).is_equal("BiB")
	var missing: GiverBadge = auto_free(
		GiverBadge.new(GiverBadge.Kind.LOYALTY, "CoE", "res://art/icons/no_such_icon.png")
	)
	assert_bool(missing.shows_icon()).is_false()
	assert_str(missing.initials()).is_equal("CoE")


## An Aisle run's loyalty badge wears the loyalty box's "×" tag at its top left (#108 follow-up),
## so Produce regulars and Produce aisle run differ on the stickers; drained, the tag greys. A
## Regulars badge has none.
func test_an_aisle_run_badge_wears_the_run_tag() -> void:
	var run: UpgradeDefinition = load("res://data/upgrades/produce_aisle_run.tres")
	var regulars: UpgradeDefinition = load("res://data/upgrades/produce_regulars.tres")
	var colour: Color = LoyaltyCard.run_mark_colour(run)
	assert_object(colour).is_equal(FamilyPalette.shared().style("Produce").face)
	assert_object(LoyaltyCard.run_mark_colour(regulars)).is_equal(Color())
	var badge: GiverBadge = auto_free(
		GiverBadge.new(GiverBadge.Kind.LOYALTY, "PrA", run.icon_ref, colour)
	)
	assert_bool(badge.shows_icon()).is_true()
	var tag: Control = badge.run_tag()
	assert_object(tag).is_not_null()
	assert_object(tag.get_parent()).is_same(badge)
	assert_vector(tag.position).is_equal(Vector2.ZERO)
	assert_vector(tag.size).is_equal(LoyaltyCard.RUN_MARK_SIZE)
	assert_object(tag.get_meta(LoyaltyCard.RUN_MARK_FACE)).is_equal(colour)
	badge.set_drained(true)
	assert_object(tag.get_meta(LoyaltyCard.RUN_MARK_FACE)).is_equal(Palette.GREY_LIGHT)
	badge.set_drained(false)
	assert_object(tag.get_meta(LoyaltyCard.RUN_MARK_FACE)).is_equal(colour)
	var plain: GiverBadge = auto_free(
		GiverBadge.new(GiverBadge.Kind.LOYALTY, "PrR", regulars.icon_ref)
	)
	assert_object(plain.run_tag()).is_null()


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
func test_a_sticker_hangs_the_larger_badge_clear_of_its_amount() -> void:
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
