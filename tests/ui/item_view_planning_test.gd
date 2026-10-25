extends GdUnitTestSuite
## A belt item's planning looks (#71, mock-up h1, H1_BUILD_SPEC.md sections 2.3, 3.6 and 4.4):
## boosted, its sprite stands BOOST_LIFT higher on the lifted shadow inside its halo (a node behind
## the sprite, grown (rings + 1) art pixels on every side, with that ring count's halo material);
## its hit area and the slot's drop target reach the raised sprite; denied, its sprite greys
## (ArtStyle.Grey.DENIED) and comes back; DIM greys its sprite and ticket to the mix highlight's
## calm grey (#105 piece 3: brightness by modulate, saturation by a greyed material on every plain
## pixel-art part, a halo or a denied grey kept), FOCUS shows its brackets (a basket item's round
## its art down to the rim), the mix marks draw over the bracket box; and once cleared, the
## count-up's body moves are those of a plain item.

const MILK := "res://data/cards/milk.tres"
const BANANA := "res://data/cards/banana.tres"
const TUNING := "res://data/balance/planning.tres"

var _holder: Control


func before_test() -> void:
	_holder = auto_free(Control.new())
	_holder.size = Vector2(1280, 720)
	add_child(_holder)


func test_a_boost_lifts_the_sprite_in_its_halo() -> void:
	var item: ItemView = await _belt_item()
	var rest: float = item.body.position.y
	assert_object(item.sprite().get_node_or_null(ItemView.HALO_NAME)).is_null()
	for rings: int in [1, 2, 3]:
		item.boost_rings = rings
		await get_tree().process_frame
		var halo: TextureRect = item.sprite().get_node(ItemView.HALO_NAME) as TextureRect
		assert_bool(halo.visible).is_true()
		assert_bool(halo.show_behind_parent).is_true()
		var grow: float = (rings + 1) * ArtStyle.ART_SCALE
		assert_vector(halo.position).is_equal(-Vector2.ONE * grow)
		assert_vector(halo.size).is_equal(ItemView.SPRITE_SIZE + Vector2.ONE * 2.0 * grow)
		assert_object(halo.material).is_same(ArtStyle.halo_material(rings))
		assert_object(halo.texture).is_same(item.sprite().texture)
		assert_float(item.body.position.y).is_equal(rest - ItemView.BOOST_LIFT)
		# Lifted by a scan too: both lifts add up.
		item.lifted = true
		assert_float(item.body.position.y).is_equal(rest - ItemView.BOOST_LIFT - ItemView.LIFT)
		item.lifted = false
	# Clamped to the halo's rings.
	item.boost_rings = 7
	assert_int(item.boost_rings).is_equal(ArtStyle.HALO_MAX_RINGS)
	item.boost_rings = 0
	assert_bool((item.sprite().get_node(ItemView.HALO_NAME) as CanvasItem).visible).is_false()
	assert_float(item.body.position.y).is_equal(rest)


## With a halo step the rings past halo_start step out one per step (the lift at once); without
## one, or back to 0, they show at once and nothing keeps running.
func test_the_halo_steps_out_ring_by_ring() -> void:
	var tuning: PlanningTuning = load(TUNING) as PlanningTuning
	var item: ItemView = await _belt_item()
	var rest: float = item.body.position.y
	item.halo_step_s = tuning.halo_step_s
	item.halo_start = 0
	item.boost_rings = 3
	var halo: TextureRect = item.sprite().get_node(ItemView.HALO_NAME) as TextureRect
	assert_object(halo.material).is_same(ArtStyle.halo_material(1))
	assert_vector(halo.size).is_equal(ItemView.SPRITE_SIZE + Vector2.ONE * 4.0 * ArtStyle.ART_SCALE)
	assert_float(item.body.position.y).is_equal(rest - ItemView.BOOST_LIFT)
	# Ring by ring, one per step, never back.
	assert_array(_rings_stepped(item, halo, tuning.halo_step_s)).is_equal([1, 2, 3])
	# From 2 rings the card showed before: the 3rd steps out alone.
	item.boost_rings = 0
	item.halo_start = 2
	item.boost_rings = 3
	assert_array(_rings_stepped(item, halo, tuning.halo_step_s)).is_equal([2, 3])
	# No step (reduced motion): all at once.
	item.halo_step_s = 0.0
	item.boost_rings = 1
	item.boost_rings = 3
	assert_object(halo.material).is_same(ArtStyle.halo_material(3))
	await get_tree().create_timer(tuning.halo_step_s * 2.0).timeout
	assert_object(halo.material).is_same(ArtStyle.halo_material(3))


## The hit area reaches the boosted sprite's top (lifted by a scan as well), and so does the
## slot's drop target (RowStrip.DROP_TOP).
func test_the_hit_area_and_the_drop_target_reach_the_raised_sprite() -> void:
	var item: ItemView = await _belt_item()
	var plain: Rect2 = item.hit_rect()
	assert_float(plain.position.y).is_equal(ItemView.BELT_SPRITE.y + _drop(item) - ItemView.LIFT)
	item.boost_rings = 2
	var raised: Rect2 = item.hit_rect()
	assert_float(raised.position.y).is_equal(plain.position.y - ItemView.BOOST_LIFT)
	assert_float(raised.end.y).is_equal(plain.end.y)
	var sprite_top: float = item._stand.position.y - ItemView.BOOST_LIFT - ItemView.LIFT
	assert_float(raised.position.y).is_less_equal(sprite_top)
	assert_float(RowStrip.DROP_TOP).is_less_equal(
		ItemView.BELT_SPRITE.y - ItemView.LIFT - ItemView.BOOST_LIFT
	)


func test_a_denied_sprite_greys_and_comes_back() -> void:
	var item: ItemView = await _belt_item()
	assert_object(item.sprite().material).is_same(ArtStyle.pixel_material())
	item.denied = true
	assert_object(item.sprite().material).is_same(ArtStyle.grey_material(ArtStyle.Grey.DENIED))
	# The capture's sharp switch keeps the look.
	ArtStyle.set_sharp(item, false)
	assert_object(item.sprite().material).is_same(ArtStyle.grey_material(ArtStyle.Grey.DENIED))
	ArtStyle.set_sharp(item, true)
	item.denied = false
	assert_object(item.sprite().material).is_same(ArtStyle.pixel_material())


## DIM greys the sprite (its stand) and the ticket to the tuning's calm grey, through a highlight
## change too; FOCUS shows the gold brackets; NONE puts it back; a fade tweens there.
func test_relations_grey_and_frame_the_item() -> void:
	var tuning: PlanningTuning = load(TUNING) as PlanningTuning
	var greyness: Vector2 = Vector2(tuning.mix_brightness, tuning.mix_saturation)
	var item: ItemView = await _belt_item()
	item.dim_greyness = greyness
	item.relation = ItemView.Relation.DIM
	_assert_grey(item, greyness)
	item.set_highlight(CardView.Highlight.SELECTED)
	_assert_grey(item, greyness)
	item.set_highlight(CardView.Highlight.NONE)
	assert_vector(item.brackets().size).is_equal(Vector2.ZERO)
	item.relation = ItemView.Relation.FOCUS
	_assert_plain(item)
	assert_bool(item.brackets().has_area()).is_true()
	item.relation = ItemView.Relation.RELATED
	assert_vector(item.brackets().size).is_equal(Vector2.ZERO)
	item.relation = ItemView.Relation.NONE
	_assert_plain(item)
	# A fade tweens there.
	item.relation_fade = tuning.mix_fade_s
	item.relation = ItemView.Relation.DIM
	assert_float(item._stand.modulate.r).is_equal(1.0)
	await get_tree().create_timer(tuning.mix_fade_s + 0.05).timeout
	_assert_grey(item, greyness)
	item.relation_fade = 0.0
	item.relation = ItemView.Relation.NONE
	_assert_plain(item)


## The grey keeps a part's own look (a halo, a denied sprite) and only dims it; taking the denial
## off a greyed item greys its sprite again; the material set_sharp keeps is the grey.
func test_the_grey_keeps_own_looks() -> void:
	var greyness: Vector2 = Vector2(0.78, 0.2)
	var item: ItemView = await _belt_item()
	item.boost_rings = 2
	item.denied = true
	item.dim_greyness = greyness
	item.relation = ItemView.Relation.DIM
	var halo: TextureRect = item.sprite().get_node(ItemView.HALO_NAME) as TextureRect
	assert_object(halo.material).is_same(ArtStyle.halo_material(2))
	assert_object(item.sprite().material).is_same(ArtStyle.grey_material(ArtStyle.Grey.DENIED))
	assert_float(item._stand.modulate.r).is_equal_approx(greyness.x, 0.001)
	item.denied = false
	var mix: ShaderMaterial = item._stand.get_meta(ArtStyle.MIX_META) as ShaderMaterial
	assert_object(item.sprite().material).is_same(mix)
	ArtStyle.set_sharp(item, false)
	assert_object(item.sprite().material).is_same(mix)
	ArtStyle.set_sharp(item, true)
	item.relation = ItemView.Relation.NONE
	assert_object(item.sprite().material).is_same(ArtStyle.pixel_material())
	assert_object(halo.material).is_same(ArtStyle.halo_material(2))


## The mix marks (MixMark) over the bracket box: FAINT's dashed outline inside it, NOW's check and
## PENALTY's "!" tile at its top right, inside it and above the ticket; NONE, SELF and LIT draw
## none. A basket item's FOCUS brackets hug its art down to the rim, in mustard.
func test_mix_marks_sit_in_the_bracket_box() -> void:
	var item: ItemView = await _belt_item()
	var box: Rect2 = item._bracket_box()
	assert_object(item._mix_mark).is_null()
	item.mix_look = MixModel.Look.FAINT
	var mark: MixMark = item._mix_mark
	assert_bool(mark.visible).is_true()
	assert_object(mark.get_parent()).is_same(item)
	assert_int(mark.get_index()).is_equal(item.get_child_count() - 1)
	assert_bool(box.encloses(mark.mark_rect())).is_true()
	assert_vector(mark.mark_rect().position).is_equal(box.position + Vector2.ONE * MixMark.INSET)
	var ticket: Rect2 = Rect2(item.sticker().position, PriceSticker.SIZE)
	for look: MixModel.Look in [MixModel.Look.NOW, MixModel.Look.PENALTY]:
		item.mix_look = look
		var rect: Rect2 = mark.mark_rect()
		assert_bool(mark.visible).is_true()
		assert_bool(box.encloses(rect)).override_failure_message(str(look)).is_true()
		assert_bool(rect.intersects(ticket)).is_false()
		assert_float(rect.end.x).is_less_equal(box.end.x)
		assert_float(rect.position.y).is_equal(box.position.y + 2.0)
	for look: MixModel.Look in [MixModel.Look.NONE, MixModel.Look.SELF, MixModel.Look.LIT]:
		item.mix_look = look
		assert_bool(mark.visible).is_false()
	# A basket item: no brackets unless focused, then round its art down to the rim.
	var card: CardInstance = CardInstance.new(load(BANANA) as CardDefinition, 2)
	var basket: ItemView = ItemView.new(card, null, ItemView.Form.BASKET)
	_holder.add_child(basket)
	await get_tree().process_frame
	assert_vector(basket.brackets().size).is_equal(Vector2.ZERO)
	basket.set_highlight(CardView.Highlight.SELECTED)
	assert_vector(basket.brackets().size).is_equal(Vector2.ZERO)
	basket.set_highlight(CardView.Highlight.NONE)
	basket.relation = ItemView.Relation.FOCUS
	var frame: Rect2 = basket.brackets()
	assert_bool(frame.has_area()).is_true()
	assert_float(frame.end.y).is_equal(ItemView.BASKET_RIM_Y)
	assert_float(frame.position.y).is_equal(basket._art_top() - ScanOverlay.BRACKET_OUTSET)
	assert_bool(Rect2(Vector2.ZERO, ItemView.BASKET_SIZE).grow(8.0).encloses(frame)).is_true()
	# Its faint outline keeps a pad round the art (the bracket box's own outset): it never runs
	# along the art's edge.
	basket.mix_look = MixModel.Look.FAINT
	assert_that(basket._mix_mark.mark_rect()).is_equal(basket._bracket_box())
	assert_float(basket._mix_mark.mark_rect().position.y).is_equal(
		basket._art_top() - ScanOverlay.BRACKET_OUTSET
	)
	basket.mix_look = MixModel.Look.NONE
	# Lifted by a hover scan, the scan's brackets mark it: its own go (one frame, not two).
	basket.lifted = true
	assert_vector(basket.brackets().size).is_equal(Vector2.ZERO)
	basket.lifted = false
	assert_bool(basket.brackets().has_area()).is_true()
	item.relation = ItemView.Relation.FOCUS
	assert_bool(item.brackets().has_area()).is_true()
	item.lifted = true
	assert_vector(item.brackets().size).is_equal(Vector2.ZERO)
	item.lifted = false
	item.relation = ItemView.Relation.NONE


## Cleared (no boost, no grey, no relation: PlanningEffects.clear before the count-up), the
## count-up's body moves and resets are a plain item's.
func test_the_count_ups_moves_are_unaffected_after_clear() -> void:
	var plain: ItemView = await _belt_item()
	var item: ItemView = await _belt_item()
	item.boost_rings = 3
	item.denied = true
	item.dim_greyness = Vector2(0.78, 0.2)
	item.relation = ItemView.Relation.DIM
	item.boost_rings = 0
	item.denied = false
	item.relation = ItemView.Relation.NONE
	for view: ItemView in [plain, item]:
		view.lifted = true
		view.body.position.x = 5.0
	assert_vector(item.body.position).is_equal(plain.body.position)
	for view: ItemView in [plain, item]:
		view.lifted = false
		view.reset_motion()
	assert_vector(item.body.position).is_equal(plain.body.position)
	assert_float(item.body.position.y).is_equal(0.0)
	assert_float(item._stand.modulate.a).is_equal(1.0)
	assert_object(item.sprite().material).is_same(ArtStyle.pixel_material())


## The halo's ring counts shown, in order: now, then after each `step` seconds of the item's
## halo tween, stepped by hand (paused, so the frame time never matters) until it ends.
static func _rings_stepped(item: ItemView, halo: TextureRect, step: float) -> Array[int]:
	var seen: Array[int] = [_rings_of(halo)]
	var tween: Tween = item._halo_tween
	if tween == null:
		return seen
	tween.pause()
	var running: bool = true
	while running:
		running = tween.custom_step(step * 1.01)
		var rings: int = _rings_of(halo)
		if rings != seen[-1]:
			seen.append(rings)
	return seen


static func _rings_of(halo: TextureRect) -> int:
	for rings: int in range(1, ArtStyle.HALO_MAX_RINGS + 1):
		if halo.material == ArtStyle.halo_material(rings):
			return rings
	return 0


func _belt_item() -> ItemView:
	var card: CardInstance = CardInstance.new(load(MILK) as CardDefinition, 1)
	var item: ItemView = ItemView.new(card, null, ItemView.Form.BELT)
	_holder.add_child(item)
	await get_tree().process_frame
	return item


## The calm grey on the sprite and the ticket: their modulate at the brightness and the greyed
## material (keeping the saturation) on the sprite and the ticket's face.
func _assert_grey(item: ItemView, greyness: Vector2) -> void:
	for root: CanvasItem in [item._stand, item.sticker()]:
		assert_float(root.modulate.r).is_equal_approx(greyness.x, 0.001)
		assert_float(root.modulate.a).is_equal(1.0)
		var mix: ShaderMaterial = root.get_meta(ArtStyle.MIX_META) as ShaderMaterial
		assert_object(mix).is_not_null()
		assert_float(mix.get_shader_parameter(&"saturation")).is_equal_approx(greyness.y, 0.001)
	assert_object(item.sprite().material).is_same(item._stand.get_meta(ArtStyle.MIX_META))
	assert_object(item.sticker().face().material).is_same(
		item.sticker().get_meta(ArtStyle.MIX_META)
	)


func _assert_plain(item: ItemView) -> void:
	for root: CanvasItem in [item._stand, item.sticker()]:
		assert_float(root.modulate.r).is_equal(1.0)
		assert_bool(root.has_meta(ArtStyle.MIX_META)).is_false()
	assert_object(item.sprite().material).is_same(ArtStyle.pixel_material())
	assert_object(item.sticker().face().material).is_same(ArtStyle.pixel_material())


## How far the belt sprite drops so its art's foot stands on the ground line.
static func _drop(item: ItemView) -> float:
	return item._stand.position.y - ItemView.BELT_SPRITE.y
