extends GdUnitTestSuite
## The item view (#75, step 3): every card in data/cards laid out as a belt item and as a tray
## item, placed where the shift screen puts them, with the real fonts. The sprite never runs under
## the plaque (at rest, selected or scanned), the sticker covers neither the sprite nor the chips,
## center() is on the sprite, the plaque mutes at €0, the looks (selected, redraw) show, chips
## fold past two, and every undrawn item's name fits its art-pending box or its slip.

const CARDS := "res://data/cards"
const BALANCE := "res://data/balance/balance.tres"
const SCREEN := Rect2(0, 0, 1280, 720)
## Where the first belt cell and the first tray cell stand on the stage (style frame v2).
const BELT_ORIGIN := Vector2(32, 76)
const TRAY_ORIGIN := Vector2(20, 418)
## The art-pending box's dashed line (canvas, sprite coordinates) and the slip's paper.
const PENDING_BOX := Rect2(10, 20, 76, 76)
const SLIP_PAPER := Rect2(26, 30, 60, 48)
const DRAWN_MILK := "res://art/items_v2/milk.png"
const COUPON_ICON := "res://art/icons/coupon_multipack_v2.png"
## The longest names of the cards with no art yet (#75, decision 3A).
const LONG_NAMES: Array[String] = [
	"Birthday candles", "Flickering bulb", "Breakfast sticker", "Final markdown"
]

var _holder: Control


func before_test() -> void:
	_holder = auto_free(Control.new())
	_holder.size = SCREEN.size
	add_child(_holder)


## Every belt item: the sprite stands inside its cell above the sticker, the plaque on the cell's
## top rim never runs under the sprite (at rest, selected, or with both scan-lifted, a four-digit
## payout too), the sticker covers no chip, and all of it stays on screen.
func test_belt_items_keep_sprite_plaque_sticker_and_chips_apart() -> void:
	var views: Array[ItemView] = await _all_laid_out(ItemView.Form.BELT, BELT_ORIGIN)
	for view: ItemView in views:
		var message: String = view.card.definition.id
		for text: String in ["+15 · Category", "Coupon engine", "×3 · Multipack"]:
			view.add_chip(text, false)
		var cell: Rect2 = view.get_global_rect()
		assert_vector(cell.size).is_equal(ItemView.BELT_SIZE)
		var sticker: Rect2 = view.sticker().get_global_rect()
		assert_bool(cell.encloses(sticker)).override_failure_message(message).is_true()
		for chip: EffectChip in view.chips():
			var rect: Rect2 = chip.get_global_rect()
			assert_bool(sticker.intersects(rect)).override_failure_message(message).is_false()
			assert_bool(SCREEN.encloses(rect)).override_failure_message(message).is_true()
			assert_float(rect.position.x).is_greater_equal(cell.position.x)
			assert_float(rect.end.x).is_less_equal(cell.end.x)
			assert_float(rect.end.y).is_less_equal(cell.end.y - ItemView.CHIP_CLEARANCE)
		for value: int in [0, 7, 9999]:
			view.show_badge(value, false)
			_assert_sprite_clear(view, message)
			view.set_highlight(CardView.Highlight.SELECTED)
			_assert_sprite_clear(view, message)
			view.set_highlight(CardView.Highlight.NONE)
			view.body.position.y = view.scan_lift()
			view.badge.position.y = view.badge_rest_y() + view.scan_lift()
			_assert_sprite_clear(view, message)
			view.reset_motion()


## Every tray item: the sprite and sticker inside the cell, apart, lifted or not; the selected
## look's brackets stay clear of the sticker.
func test_tray_items_keep_the_sticker_off_the_sprite() -> void:
	var views: Array[ItemView] = await _all_laid_out(ItemView.Form.TRAY, TRAY_ORIGIN)
	for view: ItemView in views:
		var message: String = view.card.definition.id
		var cell: Rect2 = view.get_global_rect()
		assert_vector(cell.size).is_equal(ItemView.TRAY_SIZE)
		var sticker: Rect2 = view.sticker().get_global_rect()
		assert_bool(cell.encloses(sticker)).override_failure_message(message).is_true()
		assert_bool(SCREEN.encloses(sticker)).override_failure_message(message).is_true()
		for highlight: CardView.Highlight in [CardView.Highlight.NONE, CardView.Highlight.SELECTED]:
			view.set_highlight(highlight)
			var sprite: Rect2 = view.body.get_global_rect()
			assert_bool(cell.encloses(sprite)).override_failure_message(message).is_true()
			assert_bool(sprite.intersects(sticker)).override_failure_message(message).is_false()
			if highlight == CardView.Highlight.SELECTED:
				var brackets: Rect2 = Rect2(
					view.global_position + view.brackets().position, view.brackets().size
				)
				(
					assert_bool(brackets.intersects(sticker))
					. override_failure_message(message)
					. is_false()
				)
				assert_bool(SCREEN.encloses(brackets)).is_true()


## center() is the sprite's middle at rest, in both forms and in a scaled row (RowStrip's 8 and
## 9 slots), not the cell's: the count-up's flights land on the sprite.
func test_center_is_on_the_sprite() -> void:
	var milk: CardDefinition = load("%s/milk.tres" % CARDS)
	for form: ItemView.Form in [ItemView.Form.BELT, ItemView.Form.TRAY]:
		var view: ItemView = await _laid_out(milk, form, BELT_ORIGIN)
		var sprite: Rect2 = view.body.get_global_rect()
		assert_vector(view.center()).is_equal_approx(sprite.get_center(), Vector2(0.01, 0.01))
		assert_bool(sprite.has_point(view.center())).is_true()
		assert_bool(view.sticker().get_global_rect().has_point(view.center())).is_false()
		view.body.position.y = view.scan_lift()
		assert_vector(view.center()).is_equal_approx(sprite.get_center(), Vector2(0.01, 0.01))
	_holder.scale = Vector2(0.8, 0.8)
	var scaled: ItemView = await _laid_out(milk, ItemView.Form.BELT, BELT_ORIGIN)
	var drawn: Rect2 = scaled.sprite().get_global_rect()
	assert_vector(scaled.center()).is_equal_approx(drawn.get_center(), Vector2(0.01, 0.01))


## An item's scan lifts its sprite and plaque by LIFT; a plain card keeps its lift. The count-up's
## motion lifts each view by its own scan_lift() and drops it back to rest.
func test_the_count_up_lifts_an_item_by_its_own_height() -> void:
	var milk: CardDefinition = load("%s/milk.tres" % CARDS)
	var view: ItemView = await _laid_out(milk, ItemView.Form.BELT, BELT_ORIGIN)
	assert_float(view.scan_lift()).is_equal(-ItemView.LIFT)
	var card: CardView = auto_free(CardView.new(CardInstance.new(milk, 1)))
	assert_float(card.scan_lift()).is_equal(CountUpMotion.SCAN_LIFT)
	var motion: CountUpMotion = CountUpMotion.new(_holder, create_tween)
	view.show_badge(3, true)
	motion.lift(view, 0.01)
	await await_millis(80)
	assert_float(view.body.position.y).is_equal_approx(-ItemView.LIFT, 0.01)
	assert_float(view.badge.position.y).is_equal_approx(view.badge_rest_y() - ItemView.LIFT, 0.01)
	motion.drop(view, 0.01)
	await await_millis(80)
	assert_float(view.body.position.y).is_equal_approx(0.0, 0.01)
	assert_float(view.badge.position.y).is_equal_approx(view.badge_rest_y(), 0.01)


## The plaque is #55's: "pays €N" in the number font on the brass face, centred on the cell's
## top rim; €0 and a denied value show the muted face (cream shade, a solid brass-dark edge,
## brass-dark text) and show_badge brings the brass back. Only the face is pixel art.
func test_the_plaque_mutes_at_zero_and_when_denied() -> void:
	var view: ItemView = await _laid_out(
		load("%s/milk.tres" % CARDS), ItemView.Form.BELT, BELT_ORIGIN
	)
	var plaque: PayoutPlaque = view.badge as PayoutPlaque
	assert_object(plaque).is_not_null()
	assert_bool(plaque.visible).is_false()
	view.show_badge(5, false)
	assert_str(plaque.text).is_equal("pays €5")
	assert_bool(plaque.is_muted()).is_false()
	assert_object(plaque.get_theme_color("font_color")).is_equal(ArtStyle.INK)
	view.show_badge(0, true)
	assert_bool(plaque.is_muted()).is_true()
	var muted: StyleBoxFlat = plaque.face().get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(muted).is_not_null()
	assert_object(muted.bg_color).is_equal(Palette.CREAM_SHADE)
	assert_object(muted.border_color).is_equal(Palette.BRASS_DARK)
	assert_int(muted.border_width_top).is_equal(ArtStyle.ART_SCALE)
	assert_object(plaque.get_theme_color("font_color")).is_equal(Palette.BRASS_DARK)
	view.show_fizzle_badge(4)
	assert_bool(plaque.is_muted()).is_true()
	assert_str(plaque.text).is_equal("pays €4")
	view.show_badge(4, true)
	assert_bool(plaque.is_muted()).is_false()
	await get_tree().process_frame
	var cell: Rect2 = view.get_global_rect()
	var face: Rect2 = plaque.face().get_global_rect()
	assert_float(face.position.y - cell.position.y).is_equal(ItemView.BELT_PLAQUE_Y)
	assert_float(face.size.y).is_equal(PayoutPlaque.FACE_HEIGHT)
	assert_float(face.get_center().x).is_equal_approx(cell.get_center().x, 0.5)
	assert_float(plaque.get_minimum_size().y).is_less_equal(PayoutPlaque.HEIGHT)
	assert_object(plaque.material).is_null()
	assert_object(plaque.face().material).is_same(ArtStyle.pixel_material())
	assert_bool(plaque.face().show_behind_parent).is_true()
	plaque.position.y = 40.0
	view.reset_motion()
	assert_float(plaque.position.y).is_equal(view.badge_rest_y())


## Selected: the sprite lifts by LIFT inside gold brackets. Redraw: the item fades to
## REDRAW_ALPHA and its REDRAW tag sits on the sticker's glyph corner, clear of the base value and
## the summary. NONE clears both.
func test_the_selected_and_redraw_looks() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	for definition: CardDefinition in _cards():
		var view: ItemView = await _laid_out(
			definition, ItemView.Form.TRAY, TRAY_ORIGIN, balance.aisle_of(definition)
		)
		var message: String = definition.id
		var rest: Rect2 = view.body.get_global_rect()
		view.set_highlight(CardView.Highlight.SELECTED)
		var lifted: Rect2 = view.body.get_global_rect()
		assert_float(lifted.position.y).is_equal(rest.position.y - ItemView.LIFT)
		var brackets: Rect2 = view.brackets()
		assert_bool(brackets.size != Vector2.ZERO).is_true()
		assert_float(brackets.position.y + view.global_position.y).is_equal(
			lifted.position.y - ScanOverlay.BRACKET_OUTSET
		)
		view.set_highlight(CardView.Highlight.REDRAW)
		assert_float(view.body.position.y).is_equal(0.0)
		assert_bool(view.brackets().size == Vector2.ZERO).is_true()
		assert_float(view.body.modulate.a).is_equal_approx(ItemView.REDRAW_ALPHA, 0.001)
		assert_float(view.sticker().modulate.a).is_equal_approx(ItemView.REDRAW_ALPHA, 0.001)
		var tag: Label = view._redraw_mark
		assert_bool(tag.visible).is_true()
		await get_tree().process_frame
		var tag_rect: Rect2 = tag.get_global_rect()
		var sticker: Rect2 = view.sticker().get_global_rect()
		assert_bool(sticker.encloses(tag_rect)).override_failure_message(message).is_true()
		assert_vector(tag.size).is_equal(ItemView.REDRAW_RECT.size)
		assert_float(tag.get_minimum_size().x).is_less_equal(tag.size.x)
		assert_float(tag.get_minimum_size().y).is_less_equal(tag.size.y)
		var base: Label = view.sticker().base_label()
		var base_text: Rect2 = Rect2(base.global_position, base.get_minimum_size())
		assert_bool(tag_rect.intersects(base_text)).override_failure_message(message).is_false()
		var summary: Rect2 = view.sticker().summary_label().get_global_rect()
		assert_bool(tag_rect.intersects(summary)).override_failure_message(message).is_false()
		view.set_highlight(CardView.Highlight.NONE)
		assert_bool(tag.visible).is_false()
		assert_float(view.body.modulate.a).is_equal(1.0)
		assert_float(view.sticker().modulate.a).is_equal(1.0)


## A product keeps its tags for the scan popup (its own, then the context pass's); a coupon has
## none.
func test_tags_are_kept_for_the_popup() -> void:
	var coffee: CardDefinition = load("%s/coffee.tres" % CARDS)
	var view: ItemView = await _laid_out(coffee, ItemView.Form.BELT, BELT_ORIGIN)
	assert_array(Array(view.tags())).is_equal(Array(coffee.tags))
	view.add_tag("Clearance")
	view.add_tag("Clearance")
	assert_int(view.tags().count("Clearance")).is_equal(1)
	view.set_tags(PackedStringArray(["Food"]))
	assert_array(Array(view.tags())).is_equal(["Food"])
	var coupon: ItemView = await _laid_out(
		load("%s/repeat.tres" % CARDS), ItemView.Form.BELT, BELT_ORIGIN
	)
	coupon.add_tag("Breakfast")
	assert_int(coupon.tags().size()).is_equal(0)


## The item answers the pointer on its sprite (lifted or not), sticker and chips only, not on the
## cell's empty corners, and says when the pointer enters and leaves.
func test_hover_signals_and_the_hit_area() -> void:
	var view: ItemView = await _laid_out(
		load("%s/milk.tres" % CARDS), ItemView.Form.BELT, BELT_ORIGIN
	)
	var local_sprite: Rect2 = Rect2(
		view.body.global_position - view.global_position, view.body.size
	)
	var local_sticker: Rect2 = Rect2(view.sticker().position, view.sticker().size)
	assert_bool(view._has_point(local_sprite.get_center())).is_true()
	assert_bool(view._has_point(local_sprite.position + Vector2(1, -ItemView.LIFT + 1))).is_true()
	assert_bool(view._has_point(local_sticker.get_center())).is_true()
	assert_bool(view._has_point(Vector2(1, 1))).is_false()
	assert_bool(view._has_point(Vector2(2, ItemView.BELT_SIZE.y - 10))).is_false()
	var chip: EffectChip = view.add_chip("+15 · Category", false)
	assert_bool(view._has_point(chip.position + chip.size / 2.0)).is_true()
	var seen: Array[String] = []
	view.hovered.connect(
		func(item: ItemView) -> void: seen.append("in:%s" % item.card.definition.id)
	)
	view.unhovered.connect(
		func(item: ItemView) -> void: seen.append("out:%s" % item.card.definition.id)
	)
	view.notification(Control.NOTIFICATION_MOUSE_ENTER)
	view.notification(Control.NOTIFICATION_MOUSE_EXIT)
	assert_array(seen).is_equal(["in:milk", "out:milk"])
	# A flipped popup opens below the sticker and both chip places.
	var below: Rect2 = view.below_rect()
	assert_bool(below.encloses(view.sticker().get_global_rect())).is_true()
	assert_float(below.end.y).is_equal(
		view.global_position.y + ItemView.BELT_SIZE.y - ItemView.CHIP_CLEARANCE
	)


## Chips stack under the sticker; past EffectChip.MAX_PER_CELL the last one shown reads
## "+N more" for itself and the rest, and clear_chips empties them.
func test_chips_fold_past_two() -> void:
	var view: ItemView = await _laid_out(
		load("%s/milk.tres" % CARDS), ItemView.Form.BELT, BELT_ORIGIN
	)
	var first: EffectChip = view.add_chip("+15 · Category", false)
	assert_int(view.chips().size()).is_equal(1)
	assert_str(first.label().text).is_equal("+15 · Category")
	var second: EffectChip = view.add_chip("Coupon engine", true)
	assert_bool(second.is_fizzle()).is_true()
	assert_int(view.chips().size()).is_equal(2)
	var folded: EffectChip = view.add_chip("×3 · Multipack", false)
	assert_int(view.chips().size()).is_equal(EffectChip.MAX_PER_CELL)
	assert_str(folded.label().text).is_equal(EffectChip.MORE_TEXT % 2)
	assert_bool(folded.is_fizzle()).is_false()
	assert_str(view.chips()[0].label().text).is_equal("+15 · Category")
	view.add_chip("+2 · Slot engine", false)
	assert_str(view.chips()[1].label().text).is_equal(EffectChip.MORE_TEXT % 3)
	# The chips returned stay the same nodes, updated in place: the fizzle became the fold.
	assert_bool(is_instance_valid(first)).is_true()
	assert_bool(is_instance_valid(second)).is_true()
	assert_object(view.chips()[0]).is_same(first)
	assert_object(view.chips()[1]).is_same(second)
	assert_object(folded).is_same(second)
	assert_bool(second.is_fizzle()).is_false()
	var sticker: Rect2 = Rect2(view.sticker().position, PriceSticker.SIZE)
	var above: float = sticker.end.y
	for chip: EffectChip in view.chips():
		assert_float(chip.position.y).is_greater_equal(above)
		above = chip.position.y + EffectChip.SIZE.y
	view.clear_chips()
	assert_int(view.chips().size()).is_equal(0)
	await get_tree().process_frame
	(
		assert_int(
			view.get_children().filter(func(node: Node) -> bool: return node is EffectChip).size()
		)
		. is_equal(0)
	)


## The sprite comes from art_ref (48x48 at 2x): a drawn product shows its sprite and no name; an
## undrawn one the art-pending box with its name; every coupon the shared slip, with its icon from
## art_ref or, without one, its name.
func test_sprites_come_from_art_ref() -> void:
	var milk: CardDefinition = (load("%s/milk.tres" % CARDS) as CardDefinition).duplicate()
	milk.art_ref = DRAWN_MILK
	var drawn: ItemView = await _laid_out(milk, ItemView.Form.BELT, BELT_ORIGIN)
	assert_str(drawn.sprite().texture.resource_path).is_equal(DRAWN_MILK)
	assert_object(drawn.name_label()).is_null()
	assert_vector(drawn.sprite().texture.get_size() * ArtStyle.ART_SCALE).is_equal(
		ItemView.SPRITE_SIZE
	)
	var bread: ItemView = await _laid_out(
		load("%s/bread.tres" % CARDS), ItemView.Form.TRAY, TRAY_ORIGIN
	)
	assert_object(bread.sprite().texture).is_same(ArtStyle.ITEM_PENDING)
	assert_vector(ArtStyle.ITEM_PENDING.get_size() * ArtStyle.ART_SCALE).is_equal(
		ItemView.SPRITE_SIZE
	)
	assert_str(bread.name_label().text).is_equal("Bread")
	var repeat: ItemView = await _laid_out(
		load("%s/repeat.tres" % CARDS), ItemView.Form.BELT, BELT_ORIGIN
	)
	assert_object(repeat.sprite().texture).is_same(ArtStyle.COUPON_SLIP)
	assert_str(repeat.name_label().text).is_equal("Repeat")
	var multipack: CardDefinition = (
		(load("%s/multipack.tres" % CARDS) as CardDefinition).duplicate()
	)
	multipack.art_ref = COUPON_ICON
	var iconed: ItemView = await _laid_out(multipack, ItemView.Form.BELT, BELT_ORIGIN)
	assert_object(iconed.sprite().texture).is_same(ArtStyle.COUPON_SLIP)
	assert_object(iconed.name_label()).is_null()
	var icons: Array[Node] = iconed.sprite().get_children()
	assert_int(icons.size()).is_equal(1)
	var icon: TextureRect = icons[0] as TextureRect
	assert_str(icon.texture.resource_path).is_equal(COUPON_ICON)
	assert_vector(icon.size).is_equal(icon.texture.get_size() * ArtStyle.ART_SCALE)


## Every card's name fits its art-pending box (a product) or its slip's paper (a coupon) in at
## most NAME_LINES lines, measured with the real font, no word broken, the longest names
## included.
func test_every_name_fits_its_pending_box_or_slip() -> void:
	var names: Array[String] = []
	var too_long: Array[String] = []
	for source: CardDefinition in _cards():
		var definition: CardDefinition = source.duplicate()
		definition.art_ref = ""
		names.append(definition.display_name)
		var view: ItemView = await _laid_out(definition, ItemView.Form.BELT, BELT_ORIGIN)
		var label: Label = view.name_label()
		var message: String = '%s: "%s"' % [definition.id, definition.display_name]
		assert_object(label).override_failure_message(message).is_not_null()
		var room: Rect2 = SLIP_PAPER if definition.is_coupon() else PENDING_BOX.grow(-2.0)
		var rect: Rect2 = Rect2(label.position, label.size)
		assert_bool(room.encloses(rect)).override_failure_message(message).is_true()
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		var widest: float = 0.0
		for word: String in definition.display_name.split(" "):
			widest = maxf(
				widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			)
		var clipped: bool = label.get_visible_line_count() < label.get_line_count()
		if (
			label.get_line_count() > ItemView.NAME_LINES
			or clipped
			or widest > rect.size.x
			or label.get_minimum_size().y > rect.size.y
		):
			too_long.append(message)
	assert_array(too_long).is_empty()
	for long_name: String in LONG_NAMES:
		assert_bool(names.has(long_name)).override_failure_message(long_name).is_true()


func _assert_sprite_clear(view: ItemView, message: String) -> void:
	var sprite: Rect2 = view.body.get_global_rect()
	var face: Rect2 = (view.badge as PayoutPlaque).face().get_global_rect()
	var cell: Rect2 = view.get_global_rect()
	assert_bool(sprite.intersects(face)).override_failure_message(message).is_false()
	(
		assert_bool(sprite.intersects(view.sticker().get_global_rect()))
		. override_failure_message(message)
		. is_false()
	)
	assert_bool(cell.encloses(sprite)).override_failure_message(message).is_true()
	assert_float(face.position.x).is_greater_equal(cell.position.x)
	assert_float(face.end.x).is_less_equal(cell.end.x)
	assert_bool(SCREEN.encloses(face)).override_failure_message(message).is_true()
	assert_bool(SCREEN.encloses(sprite)).override_failure_message(message).is_true()


## Every card as an item of `form`, side by side from `origin` (wrapping inside the screen), each
## with its aisle.
func _all_laid_out(form: ItemView.Form, origin: Vector2) -> Array[ItemView]:
	var balance: BalanceDefinition = load(BALANCE)
	var views: Array[ItemView] = []
	var index: int = 0
	for definition: CardDefinition in _cards():
		var view: ItemView = auto_free(
			ItemView.new(CardInstance.new(definition, 1), balance.aisle_of(definition), form)
		)
		view.position = origin + Vector2((index % 8) * 124, 0)
		_holder.add_child(view)
		views.append(view)
		index += 1
	await get_tree().process_frame
	await get_tree().process_frame
	return views


func _laid_out(
	definition: CardDefinition, form: ItemView.Form, at: Vector2, aisle: AisleDefinition = null
) -> ItemView:
	var view: ItemView = auto_free(ItemView.new(CardInstance.new(definition, 1), aisle, form))
	view.position = at
	_holder.add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	return view


func _cards() -> Array[CardDefinition]:
	var result: Array[CardDefinition] = []
	for file: String in DirAccess.get_files_at(CARDS):
		if file.ends_with(".tres"):
			result.append(load("%s/%s" % [CARDS, file]) as CardDefinition)
	return result
