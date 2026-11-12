extends GdUnitTestSuite
## The starter pack crate's loyalty perk (v1.29, StarterPackDefinition.loyalty_perk): a pack that
## names a perk shows it on its label (a teal strip with the perk's icon and name), so the player
## sees which perk the first UPGRADE visit guarantees; the glyph and the family line make room above
## it. Every part sits inside the label, nothing overlaps and the words fit. A pack with no perk
## keeps the plain label (no strip).

const PACKS_DIR := "res://data/starter_packs"


func test_a_pack_crate_names_its_perk() -> void:
	var with_perk: int = 0
	for file: String in DirAccess.get_files_at(PACKS_DIR):
		if not file.ends_with(".tres"):
			continue
		var pack: StarterPackDefinition = load(PACKS_DIR.path_join(file))
		var crate: PackCrate = auto_free(PackCrate.new(pack, 0, false))
		add_child(crate)
		await get_tree().process_frame
		var face: Rect2 = crate.label.get_global_rect()
		var family: Rect2 = _caps(crate.label.get_node("Family"))
		var strip: Control = crate.label.get_node_or_null("Perk") as Control
		if pack.loyalty_perk == null:
			assert_object(strip).override_failure_message(file).is_null()
			continue
		with_perk += 1
		assert_object(strip).override_failure_message(file).is_not_null()
		var strip_rect: Rect2 = strip.get_global_rect()
		assert_bool(face.encloses(strip_rect)).override_failure_message(file).is_true()
		# The strip keeps clear of the label's bottom edge (not jammed against the frame).
		var bottom_gap: float = face.end.y - strip_rect.end.y
		assert_float(bottom_gap).override_failure_message(file).is_greater_equal(4.0)
		assert_bool(face.encloses(family)).is_true()
		assert_bool(family.intersects(strip_rect)).override_failure_message(file).is_false()
		var glyph: Control = crate.label.get_node_or_null("Glyph") as Control
		if glyph != null:
			assert_bool(glyph.get_global_rect().intersects(family)).is_false()
			assert_bool(glyph.get_global_rect().intersects(strip_rect)).is_false()
		var name_bar: Rect2 = _caps(crate.label.get_node("Name"))
		assert_bool(name_bar.intersects(strip_rect)).is_false()
		var words: Label = strip.get_node("PerkName") as Label
		assert_str(words.text.replace("  ", " ")).is_equal(
			pack.loyalty_perk.display_name.to_upper()
		)
		var caps: Rect2 = _caps(words)
		assert_bool(strip_rect.encloses(caps)).override_failure_message(file).is_true()
		var icon: TextureRect = strip.get_node("PerkIcon") as TextureRect
		assert_object(icon.texture).is_not_null()
		assert_bool(strip_rect.encloses(icon.get_global_rect())).is_true()
		assert_bool(icon.get_global_rect().intersects(caps)).is_false()
		# The icon draws at a whole multiple of its art (no smeared pixels).
		var art: Vector2 = icon.texture.get_size()
		var drawn: float = minf(icon.size.x / art.x, icon.size.y / art.y)
		assert_float(drawn).is_equal(floorf(drawn))
	assert_int(with_perk).is_equal(4)


func _caps(pixel: Label) -> Rect2:
	var font: Font = ArtStyle.pixel_display_font()
	var cap_top: float = font.get_ascent(ArtStyle.PIXEL_TEXT_SIZE) - ArtStyle.PIXEL_CAP_HEIGHT
	var factor: Vector2 = pixel.get_global_transform().get_scale()
	var local: Vector2 = Vector2(StartBoardKit.text_width(pixel.text, 1), ArtStyle.PIXEL_CAP_HEIGHT)
	return Rect2(pixel.global_position + Vector2(0, cap_top) * factor, local * factor)
