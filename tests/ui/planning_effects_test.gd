extends GdUnitTestSuite
## The planning effects on the real shift screen (#71, mock-up h1, PlanningEffects and the stage's
## PlanningLayer): every belt item shows the preview's PlanningModel (its stickers in apply order,
## its pay on the ticket, its halo and lift, its grey and stamp), with no corner disc in planning,
## following every place, remove and refresh; hovering an item, a loyalty box or the inspection
## chip relates its givers and targets at once, lights only the related stickers (the rest drain)
## and dims the rest, kept across a refresh and dropped the tuning's unfocus delay after the pointer
## leaves; a drag shows the model of each landing slot (the ghost carrying the dropped card's
## stickers and pay) and the quota chip's would-be total, never changing the run; the CHECKOUT
## click keeps only the stickers (and the denied item's stamp) for the count (#86 v6), each hidden
## once its item is bagged. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
## #60's reference row (count_up_test), with Coupon engine and Slot engine given and the Spot
## check set: Eggs lands ×2 on Bread, the 3rd product (Milk) is denied, Multipack arms ×3 and
## Coupon engine fizzles on it, Slot engine stamps the 6th product.
const FULL_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]
## Sticker minis' row: Eggs gives Bread ×2 (its mini), Mixed herbs (no sprite yet) gives Golden
## Eggs +3 (its initials), Golden Eggs gives the next 2 Food ×2 (the gold-outlined mini) and
## Multipack gives the Milk ×3 for the Cheese's Dairy (the coupon token).
const MINI_ROW: Array[String] = [
	"eggs", "bread", "mixed_herbs", "eggs_golden", "cheese", "multipack", "milk"
]
const OFF_SCREEN := Vector2(-500, -500)
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## The motion tests' slap frame and halo step: long enough that no frame outlasts one.
const SLOW_FRAME_S := 0.4
const Rush := preload("res://tests/ui/count_up_rush.gd")
## Game time runs this much faster while the motion tests wait for the motion to settle (only
## then: every check runs at 1x), and through the click test's count, which it samples per frame.
const SETTLE_FACTOR := 8.0
const COUNT_FACTOR := 4.0

var _folder: String = ""
var _window_size: Vector2i
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	Rush.restore()
	_runner = null
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Each item shows its slot of the preview's model: its stickers (texts and badges in step order),
## its pay tag and struck base, its halo rings and lift, its grey and stamp; planning shows no
## corner disc; the preview is unchanged.
func test_every_item_shows_its_model() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var result: ScoreResult = screen.run.preview()
	var model: PlanningModel = PlanningEffects.model_of(
		result, screen.run.row, screen.run, screen._effects.tuning
	)
	_assert_model_shown(screen, model, _views(screen))
	for slot: int in range(screen._row_views.size()):
		assert_object(_item(screen, slot)._mark).override_failure_message(str(slot)).is_null()
	var layer: PlanningLayer = _layer(screen)
	# Bread takes Eggs' ×2 with the item badge, Eggs' mini (sticker minis); Multipack's ×3 lands
	# with the coupon badge "Mu"; the Milk in slot 2 is stamped by the Spot check and greys; a
	# boosted Milk is raised.
	var bread: EffectSticker = _sticker_with(layer.stack(1), "×2")
	assert_object(bread).is_not_null()
	assert_int(bread.badge().kind).is_equal(GiverBadge.Kind.ITEM)
	assert_bool(bread.badge().shows_mini()).is_true()
	assert_str(bread.badge().texture().resource_path).is_equal("res://art/minis/eggs.png")
	var stamped: EffectSticker = _sticker_with(layer.stack(4), "×3")
	assert_object(stamped).is_not_null()
	assert_int(stamped.badge().kind).is_equal(GiverBadge.Kind.COUPON)
	assert_str(stamped.badge().initials()).is_equal("Mu")
	var stamp: DenyStamp = layer.stamp(2)
	assert_str(stamp.amount()).is_equal("€0")
	assert_str(stamp.caption()).is_equal(screen.run.inspections[0].display_name.to_upper())
	assert_bool(_item(screen, 2).denied).is_true()
	assert_int(layer.pay_tag(2).glyph).is_equal(PlanningModel.Glyph.WARNING)
	# Every own sticker has no badge.
	for slot: int in range(screen._row_views.size()):
		for sticker: EffectSticker in layer.stack(slot):
			var own: bool = sticker.spec().badge == GiverBadge.Kind.NONE
			assert_bool(sticker.badge() == null).is_equal(own)
	# The rail strips: Eggs' over Bread and Multipack's over the three Milks after it, both calm on
	# lane 0 with a notch on each target and no factor badge (the sticker says "×3"); the monitor's
	# brief keys the stickers.
	_assert_strips_shown(screen, model)
	var strips: Array[RailStrip] = layer.strips()
	assert_int(strips.size()).is_equal(2)
	assert_str(strips[0].spec().name).is_equal("EGGS")
	assert_array(Array(strips[0].spec().targets)).is_equal([1])
	assert_str(strips[1].spec().name).is_equal("MULTIPACK")
	assert_array(Array(strips[1].spec().targets)).is_equal([4, 5, 6])
	for strip: RailStrip in strips:
		assert_int(strip.spec().lane).is_equal(0)
		assert_array(strip.gains()).is_empty()
		assert_int(strip.lip_rects().size()).is_equal(3 + strip.spec().targets.size())
		assert_int(strip.target_centres().size()).is_equal(strip.spec().targets.size())
		assert_array(strip.find_children("*Badge*", "", true, false)).is_empty()
	var key: PackedStringArray = PackedStringArray()
	for entry: StickerSpec in model.key_entries():
		key.append(MonitorChannel.KEY_TEXT % [entry.text, PlanningModel.key_caption(entry)])
	# The entries that fit the brief's width, in order (at least the first; a wide one is skipped
	# for a later, narrower one). Since v0.39 the channel sits right of the scanner bay, 110 px
	# narrower, so two of h1's three entries fit here.
	var shown_key: PackedStringArray = screen._monitor.channel.key_texts()
	assert_int(shown_key.size()).is_greater(0)
	assert_str(shown_key[0]).is_equal(key[0])
	assert_bool(_in_order(shown_key, key)).override_failure_message(str(shown_key)).is_true()
	assert_int(shown_key.size()).is_equal(2)
	assert_object(screen._monitor.channel.key_row()).is_not_null()
	assert_int(screen.run.preview().total).is_equal(result.total)
	assert_array(screen.run.preview().payouts).is_equal(result.payouts)


## Sticker minis on the real screen: each item badge shows its giver's mini (Golden Eggs' with the
## gold outline, plain Eggs' with ink) or, for a product with no sprite (Mixed herbs), its
## initials token; the coupon badge keeps its token. Every badge stays 18x18, hangs off its
## sticker's left edge inside its stack's span (PlanningLayer._span) and lies on the screen with
## its mini inside it; drained (another item hovered) a mini greys.
func test_item_badges_show_the_givers_mini() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, MINI_ROW)
	# The slaps settle first: the geometry is the resting one.
	await _settled(1.0)
	var layer: PlanningLayer = _layer(screen)
	var shown: Dictionary[String, bool] = {}
	var minis: Array[GiverBadge] = []
	for slot: int in range(screen._row_views.size()):
		var stickers: Array[EffectSticker] = layer.stack(slot)
		var specs: Array[StickerSpec] = []
		var left: float = INF
		for sticker: EffectSticker in stickers:
			specs.append(sticker.spec())
			left = minf(left, sticker.get_global_rect().position.x)
		var span: Rect2 = PlanningLayer._span(specs, left)
		for sticker: EffectSticker in stickers:
			var badge: GiverBadge = sticker.badge()
			if badge == null:
				continue
			var spec: StickerSpec = sticker.spec()
			var message: String = "slot %d %s %s" % [slot, spec.text, spec.badge_text]
			var rect: Rect2 = badge.get_global_rect()
			assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message(message).is_true()
			(
				assert_bool(rect.position.x >= span.position.x - 0.01)
				. override_failure_message(message)
				. is_true()
			)
			assert_bool(rect.end.x <= span.end.x + 0.01).override_failure_message(message).is_true()
			var sticker_rect: Rect2 = sticker.get_global_rect()
			assert_bool(rect.get_center().y >= sticker_rect.position.y).is_true()
			assert_bool(rect.get_center().y <= sticker_rect.end.y).is_true()
			if badge.kind == GiverBadge.Kind.INSPECTION:
				continue
			assert_that(rect.size).override_failure_message(message).is_equal(GiverBadge.SIZE)
			var art: Rect2 = badge.art_rect()
			art.position += rect.position
			assert_bool(rect.encloses(art)).override_failure_message(message).is_true()
			if badge.kind != GiverBadge.Kind.ITEM:
				assert_bool(badge.shows_mini()).override_failure_message(message).is_false()
				shown[GiverBadge.Kind.keys()[badge.kind]] = true
				continue
			var giver: CardDefinition = screen.run.row[spec.cause_slot].definition
			shown[String(giver.id)] = true
			assert_bool(badge.shows_mini()).override_failure_message(message).is_equal(
				not giver.badge_mini_ref().is_empty()
			)
			if badge.shows_mini():
				assert_str(badge.texture().resource_path).is_equal(giver.badge_mini_ref())
				assert_str(badge.initials()).is_empty()
				minis.append(badge)
			else:
				assert_str(badge.initials()).is_equal(spec.badge_text)
	assert_bool(shown.has("eggs")).override_failure_message(str(shown)).is_true()
	assert_bool(shown.has("eggs_golden")).override_failure_message(str(shown)).is_true()
	assert_bool(shown.has("mixed_herbs")).override_failure_message(str(shown)).is_true()
	assert_bool(shown.has("COUPON")).override_failure_message(str(shown)).is_true()
	# Golden Eggs' mini is the gold-outlined one.
	var golden: Array[GiverBadge] = minis.filter(
		func(badge: GiverBadge) -> bool:
			return badge.texture().resource_path.ends_with("_golden.png")
	)
	assert_int(golden.size()).is_greater(0)
	# The monitor key's "from an item" entry shows the same badge: the first item sticker's giver
	# (Eggs, on Bread) with its mini, inside the channel.
	var channel: MonitorChannel = screen._monitor.channel
	var key_row: Control = channel.key_row()
	assert_object(key_row).is_not_null()
	var item_keys: Array[EffectSticker] = []
	for child: Node in key_row.get_children():
		var key_sticker: EffectSticker = child as EffectSticker
		if key_sticker != null and key_sticker.spec().badge == GiverBadge.Kind.ITEM:
			item_keys.append(key_sticker)
	assert_int(item_keys.size()).is_equal(1)
	var key_badge: GiverBadge = item_keys[0].badge()
	assert_object(key_badge).is_not_null()
	assert_bool(key_badge.shows_mini()).is_true()
	var eggs_mini: String = screen.run.row[MINI_ROW.find("eggs")].definition.badge_mini_ref()
	assert_str(key_badge.texture().resource_path).is_equal(eggs_mini)
	var key_rect: Rect2 = key_badge.get_global_rect()
	(
		assert_bool(channel.get_global_rect().encloses(key_rect))
		. override_failure_message("%s in %s" % [key_rect, channel.get_global_rect()])
		. is_true()
	)
	# Hovering the coupon drains every sticker it doesn't cause: the minis grey.
	var coupon: ItemView = _item(screen, MINI_ROW.find("multipack"))
	coupon.hovered.emit(coupon)
	await _frames(1)
	for badge: GiverBadge in minis:
		assert_bool(badge.is_drained()).is_true()
		assert_object((badge.get_child(0) as CanvasItem).material).is_same(
			ArtStyle.grey_material(ArtStyle.Grey.DRAINED)
		)


## Moving Eggs after Bread changes the stickers (Eggs' ×2 has nothing after it, so Eggs' own
## charges fizzle), and emptying the row leaves no part on the layer.
func test_the_stickers_follow_the_row() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["eggs", "bread"])
	assert_bool(_texts(_layer(screen).stack(1)).has("×2")).is_true()
	var eggs: CardInstance = screen.run.row[0]
	screen._on_row_card_clicked(screen._row_views[0])
	screen._on_slot_input(_left_click(), 1)
	await _frames(3)
	assert_object(screen.run.row[1]).is_same(eggs)
	assert_bool(_texts(_layer(screen).stack(0)).has("×2")).is_false()
	assert_bool(_texts(_layer(screen).stack(1)).has("WASTED")).is_true()
	var model: PlanningModel = screen._effects.committed_model()
	_assert_model_shown(screen, model, _views(screen))
	for _card: int in range(2):
		screen._on_row_card_clicked(screen._row_views[0])
		screen._let_go()
	await _frames(2)
	assert_int(screen.run.row.size()).is_equal(0)
	assert_array(_layer(screen).parts()).is_empty()


## Hovering Bread relates Eggs (its giver), lights Bread's stickers and Eggs' given ones, drains
## the others and dims every other item and its pay tag; hovering Eggs relates Bread. The focus
## survives a refresh, stays while the pointer comes back within the unfocus delay or is still on
## the item when the delay is up, and goes once it has been off that long.
func test_hovering_an_item_highlights_its_givers_and_targets() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var effects: PlanningEffects = screen._effects
	var tuning: PlanningTuning = effects.tuning
	var delay: float = tuning.unfocus_delay_s * 2.0
	effects.pointer = func() -> Vector2: return OFF_SCREEN
	var bread: ItemView = screen._row_views[1] as ItemView
	bread.hovered.emit(bread)
	assert_int(bread.relation).is_equal(ItemView.Relation.FOCUS)
	assert_int(_item(screen, 0).relation).is_equal(ItemView.Relation.RELATED)
	assert_int(_item(screen, 4).relation).is_equal(ItemView.Relation.DIM)
	_assert_lit(screen, 1)
	assert_bool(_layer(screen).pay_tag(4).is_dimmed()).is_true()
	assert_bool(_layer(screen).pay_tag(1).is_dimmed()).is_false()
	assert_bool(_layer(screen).stamp(2).is_drained()).is_true()
	var eggs: ItemView = _item(screen, 0)
	eggs.hovered.emit(eggs)
	assert_int(_item(screen, 0).relation).is_equal(ItemView.Relation.FOCUS)
	assert_int(_item(screen, 1).relation).is_equal(ItemView.Relation.RELATED)
	_assert_lit(screen, 0)
	# A refresh rebuilds the items: the focus goes to Eggs' new view, at once.
	screen._refresh()
	await _frames(2)
	assert_object(effects.focused_card()).is_same(screen.run.row[0])
	assert_int(_item(screen, 1).relation).is_equal(ItemView.Relation.RELATED)
	assert_float(_item(screen, 4)._stand.modulate.a).is_equal_approx(tuning.dim_item_alpha, 0.001)
	assert_float(_item(screen, 4).sticker().modulate.a).is_equal_approx(
		tuning.dim_ticket_alpha, 0.001
	)
	_assert_lit(screen, 0)
	# Off and back on within the delay: kept.
	_item(screen, 0).unhovered.emit(_item(screen, 0))
	_item(screen, 0).hovered.emit(_item(screen, 0))
	await _seconds(delay)
	assert_object(effects.focused_card()).is_same(screen.run.row[0])
	# A refresh's new view gets no hover until the pointer moves: a leave with the pointer still
	# on the focused item keeps the focus once the delay is up (the pointer check), and a point on
	# the next item does not.
	screen._refresh()
	await _frames(2)
	var on_eggs: Vector2 = _hit_center(_item(screen, 0))
	effects.pointer = func() -> Vector2: return on_eggs
	_item(screen, 0).unhovered.emit(_item(screen, 0))
	await _seconds(delay)
	assert_object(effects.focused_card()).is_same(screen.run.row[0])
	assert_int(_item(screen, 1).relation).is_equal(ItemView.Relation.RELATED)
	var on_bread: Vector2 = _hit_center(_item(screen, 1))
	effects.pointer = func() -> Vector2: return on_bread
	_item(screen, 0).unhovered.emit(_item(screen, 0))
	await _seconds(delay)
	assert_object(effects.focused_card()).is_null()
	_item(screen, 0).hovered.emit(_item(screen, 0))
	effects.pointer = func() -> Vector2: return OFF_SCREEN
	# Off for good: the focus goes after the delay, and every sticker lights again.
	_item(screen, 0).unhovered.emit(_item(screen, 0))
	assert_object(effects.focused_card()).is_not_null()
	await _seconds(delay)
	assert_object(effects.focused_card()).is_null()
	for view: CardView in screen._row_views:
		assert_int((view as ItemView).relation).is_equal(ItemView.Relation.NONE)
	_assert_lit(screen, -1)


## The denied Milk names the Spot check on the ringed inspection chip; hovering a loyalty box
## relates its targets, lights only its stickers and rings it; hovering the chip relates the
## inspection's target, drains every sticker and keeps its stamp lit.
func test_the_top_bar_relates_both_ways() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var effects: PlanningEffects = screen._effects
	var tag: InspectionTag = screen._inspection_tag
	var milk: ItemView = _item(screen, 2)
	milk.hovered.emit(milk)
	assert_bool(tag.has_relation()).is_true()
	assert_str(tag.label().text).is_equal(screen.run.inspections[0].display_name)
	effects.unfocus()
	assert_bool(tag.has_relation()).is_false()
	assert_str(tag.label().text).is_not_equal(screen.run.inspections[0].display_name)
	# Slot engine (the 2nd upgrade) stamps the 6th product.
	screen._loyalty_card.box_hovered.emit(1)
	assert_bool(screen._loyalty_card.has_relation(1)).is_true()
	assert_bool(screen._loyalty_card.has_relation(0)).is_false()
	var targets: int = 0
	for link: EffectLink in effects.committed_model().graph.by_upgrade(1):
		assert_int(_item(screen, link.target_slot).relation).is_equal(ItemView.Relation.RELATED)
		targets += 1
	assert_int(targets).is_greater(0)
	for slot: int in range(screen._row_views.size()):
		for sticker: EffectSticker in _layer(screen).stack(slot):
			var spec: StickerSpec = sticker.spec()
			var mine: bool = (
				spec.cause_kind == ScoreStep.SourceKind.UPGRADE and spec.cause_index == 1
			)
			var lit: bool = mine and slot != 2
			assert_bool(sticker.is_drained()).override_failure_message(str(slot)).is_equal(not lit)
	tag.hovered.emit()
	assert_bool(screen._loyalty_card.has_relation(1)).is_false()
	assert_bool(tag.has_relation()).is_true()
	assert_int(_item(screen, 2).relation).is_equal(ItemView.Relation.RELATED)
	assert_int(_item(screen, 0).relation).is_equal(ItemView.Relation.DIM)
	assert_bool(_layer(screen).stamp(2).is_drained()).is_false()
	for slot: int in range(screen._row_views.size()):
		for sticker: EffectSticker in _layer(screen).stack(slot):
			assert_bool(sticker.is_drained()).is_true()


## Hovering Multipack (as mock-up h1's hover): its own rail strip turns hot, drawn again on top in
## lane 0 with each Milk's gain; its calm copy hides and Eggs' strip dims; its ticket is ringed,
## the Milks' tickets get the "got" face; the receipt frames its line, puts "×3" on each Milk's
## line and names it in the footer. Hovering a Milk makes Multipack's strip hot with that Milk's
## gain only. A loyalty box's or the chip's hover dims every strip; unfocused, all is calm again.
func test_a_hovered_giver_lights_its_strip_and_explains_it() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var effects: PlanningEffects = screen._effects
	effects.pointer = func() -> Vector2: return OFF_SCREEN
	var layer: PlanningLayer = _layer(screen)
	var receipt: ReceiptView = screen._stage.receipt
	var multipack: ItemView = _item(screen, 3)
	multipack.hovered.emit(multipack)
	var spec: RailStripSpec = effects.committed_model().strips[1]
	assert_int(spec.giver_slot).is_equal(3)
	var hot: Array[RailStrip] = layer.hot_strips()
	assert_int(hot.size()).is_equal(1)
	assert_object(hot[0].spec()).is_same(spec)
	assert_bool(hot[0].is_hot()).is_true()
	assert_float(hot[0].body_rect().position.y).is_equal(RailStrip.LANE_RECTS[0].position.y)
	var gains: PackedStringArray = PackedStringArray()
	for gain: int in spec.gains:
		gains.append(RailStrip.GAIN_TEXT % gain)
	assert_array(Array(hot[0].gain_texts())).is_equal(Array(gains))
	# Each gain stands on its Milk, centred over the notch (no factor badge beside it).
	var shown_gains: Array[Control] = hot[0].gains()
	assert_int(shown_gains.size()).is_equal(spec.targets.size())
	for index: int in range(shown_gains.size()):
		var centre: float = shown_gains[index].position.x + shown_gains[index].size.x / 2.0
		assert_float(centre).is_equal_approx(hot[0].target_centres()[index], 2.0)
	assert_array(layer.find_children("FactorBadge*", "", true, false)).is_empty()
	var parts: Array[Control] = layer.parts()
	for strip: RailStrip in layer.strips():
		var mine: bool = strip.spec().giver_slot == 3
		assert_bool(parts.has(strip)).is_equal(not mine)
		assert_bool(strip.is_dimmed()).is_equal(not mine)
	assert_bool(parts.has(hot[0])).is_true()
	# The hot strip draws over every other part of the layer.
	assert_int(hot[0].get_parent().get_index()).is_equal(layer.get_child_count() - 1)
	var ticket: Rect2 = Rect2(
		layer.get_global_transform().affine_inverse() * multipack.sticker().get_global_position(),
		PriceSticker.SIZE
	)
	assert_bool(layer.ticket_ring().encloses(ticket)).is_true()
	for slot: int in range(screen._row_views.size()):
		assert_bool(_item(screen, slot).sticker().is_got()).is_equal(slot in [4, 5, 6])
	assert_object(receipt._framed_line()).is_same(receipt._items[3])
	for slot: int in [4, 5, 6]:
		assert_str(ReceiptDecor.relation_chip(receipt._items[slot]).text).is_equal("×3")
	assert_object(ReceiptDecor.relation_chip(receipt._items[1])).is_null()
	var hovered: String = ReceiptView.HOVERED_HINT % "Multipack"
	assert_str(receipt._footer.get_child(1).text).is_equal(ReceiptView.HINT_TEXT % hovered)
	# A Milk: Multipack's strip hot in its lane with that Milk's gain only.
	var milk: ItemView = _item(screen, 5)
	milk.hovered.emit(milk)
	hot = layer.hot_strips()
	assert_int(hot.size()).is_equal(1)
	assert_array(Array(hot[0].gain_texts())).is_equal([RailStrip.GAIN_TEXT % spec.gains[1]])
	assert_bool(layer.strips()[0].is_dimmed()).is_true()
	assert_bool(_item(screen, 4).sticker().is_got()).is_false()
	assert_str(receipt._footer.get_child(1).text).is_equal(
		ReceiptView.HINT_TEXT % (ReceiptView.HOVERED_HINT % "Milk")
	)
	# A box, then the chip: no strip hot, every strip dimmed.
	for hover: Callable in [
		func() -> void: screen._loyalty_card.box_hovered.emit(1),
		func() -> void: screen._inspection_tag.hovered.emit(),
	]:
		hover.call()
		assert_array(layer.hot_strips()).is_empty()
		for strip: RailStrip in layer.strips():
			assert_bool(strip.is_dimmed()).is_true()
			assert_bool(layer.parts().has(strip)).is_true()
		assert_object(receipt._framed_line()).is_null()
	effects.unfocus()
	assert_array(layer.hot_strips()).is_empty()
	assert_object(layer.ticket_ring()).is_equal(Rect2())
	for strip: RailStrip in layer.strips():
		assert_bool(strip.is_dimmed()).is_false()
	_assert_strips_shown(screen, effects.committed_model())
	for slot: int in range(screen._row_views.size()):
		assert_bool(_item(screen, slot).sticker().is_got()).is_false()
		assert_object(ReceiptDecor.relation_chip(receipt._items[slot])).is_null()
	assert_str(receipt._footer.get_child(1).text).is_equal(
		ReceiptView.HINT_TEXT % ReceiptView.DEFAULT_HINT
	)


## With motion on, a refresh slaps on only the stickers that are new, a boosted item's halo steps
## out from the rings its card showed before, and the strips' chevrons step once; all of it ends
## and nothing loops.
func test_motion_plays_once() -> void:
	await _assert_motion(false)


## Under reduced motion no sticker slaps, no halo steps and no chevron steps.
func test_reduced_motion_stills_the_effects() -> void:
	await _assert_motion(true)


## At each landing slot the views and the ghost show the model of the preview with the card placed
## there (the ghost carrying its slot's stickers, halo, grey and pay tag as its own children), no
## item is related, and the quota chip shows its total and change; the run never changes; leaving
## the row and the release show the committed model again, with the ghost plain off the row.
func test_a_drag_previews_each_landing() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["bread", "milk", "bread"])
	var committed: Array[CardInstance] = screen.run.row.duplicate()
	var total: int = screen.run.preview().total
	var key: PackedStringArray = screen._monitor.channel.key_texts()
	screen._debug.add_card("eggs")
	var eggs: CardInstance = screen.run.hand()[-1]
	screen._on_hand_card_clicked(_view_for(screen, eggs))
	for target: int in [0, 1, 2, 3]:
		_move(screen, _slot_center(screen, target))
		await _frames(2)
		assert_int(screen._drag.hovered_slot()).is_equal(target)
		var result: ScoreResult = screen.run.preview(eggs, target)
		var row: Array[CardInstance] = screen.run.row.duplicate()
		row.insert(target, eggs)
		var model: PlanningModel = PlanningEffects.model_of(
			result, row, screen.run, screen._effects.tuning
		)
		var ghost: ItemView = screen._drag.ghost()
		var items: Array[ItemView] = PlanningEffects._items_in(screen._row_views, target, ghost)
		_assert_model_shown(screen, model, items)
		for sticker: EffectSticker in _layer(screen).stack(target):
			assert_bool(ghost.is_ancestor_of(sticker)).is_true()
			var rect: Rect2 = sticker.get_global_rect()
			assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message(str(rect)).is_true()
		for view: CardView in screen._row_views:
			assert_int((view as ItemView).relation).is_equal(ItemView.Relation.NONE)
		# The rail strips hide while the ghost is over the row; the key stays the committed one.
		for part: Control in _layer(screen).parts():
			assert_bool(part is RailStrip).override_failure_message(part.name).is_false()
		assert_array(Array(screen._monitor.channel.key_texts())).is_equal(Array(key))
		var expected: String = QuotaMeter.HYPOTHETICAL_TEXT % [result.total, result.total - total]
		assert_str(screen._quota_meter.shown_text()).is_equal(expected)
		var font: Font = screen._quota_meter.amount_label.get_theme_font("font")
		for character: String in expected.replace(" ", ""):
			(
				assert_bool(font.has_char(character.unicode_at(0)))
				. override_failure_message(character)
				. is_true()
			)
		assert_array(screen.run.row).is_equal(committed)
	# At the end Eggs' charges have nothing after them: the ghost wears its own "WASTED".
	var carried: ItemView = screen._drag.ghost()
	assert_bool(_texts(_layer(screen).stack(3)).has("WASTED")).is_true()
	# Off the row: the committed model and total, and the ghost plain again.
	_move(screen, OFF_SCREEN + Vector2(600, 0))
	await _frames(2)
	_assert_model_shown(screen, screen._effects.committed_model(), _views(screen))
	_assert_strips_shown(screen, screen._effects.committed_model())
	assert_object(carried.get_node_or_null("PlanningParts")).is_null()
	assert_int(carried.boost_rings).is_equal(0)
	assert_bool(carried.denied).is_false()
	assert_str(screen._quota_meter.amount_label.text).is_equal("€%d" % total)
	_move(screen, _slot_center(screen, 0))
	_release(screen, _slot_center(screen, 0))
	await _frames(3)
	assert_object(screen.run.row[0]).is_same(eggs)
	var landed: ScoreResult = screen.run.preview()
	var placed: PlanningModel = PlanningEffects.model_of(
		landed, screen.run.row, screen.run, screen._effects.tuning
	)
	_assert_model_shown(screen, placed, _views(screen))
	_assert_strips_shown(screen, placed)
	assert_str(screen._quota_meter.amount_label.text).is_equal("€%d" % landed.total)


## The CHECKOUT click (#86 v6, show_count) keeps only the stickers, unslapped, and the denied
## item's stamp and grey, for the count: the rail strips, pay tags, sparkles, halos, lifts,
## strikes, relations, rings, the key and the focus go; nothing loops, with or without reduced
## motion. Through the count only stickers and stamps show, each on a view still on the belt (a
## bagged item's parts hide with its cell), and by the end every one has gone with its item.
func test_the_click_keeps_only_the_stickers() -> void:
	for reduced: bool in [false, true]:
		var screen: ShiftScreen = await _screen()
		screen._debug.set_reduced_motion(reduced)
		await _full_row(screen)
		var milk: ItemView = _item(screen, 2)
		milk.hovered.emit(milk)
		await _frames(2)
		assert_int(_looping_tweens()).is_equal(0)
		assert_array(_layer(screen).strips()).is_not_empty()
		assert_array(Array(screen._monitor.channel.key_texts())).is_not_empty()
		var model: PlanningModel = screen._effects.committed_model()
		screen._on_checkout_pressed()
		await _frames(2)
		assert_array(_layer(screen).strips()).is_empty()
		assert_array(Array(screen._monitor.channel.key_texts())).is_empty()
		assert_object(screen._monitor.channel.key_row()).is_null()
		var stickers: int = 0
		for slot: int in range(screen._row_views.size()):
			var item: ItemView = _item(screen, slot)
			var planned: PlanningSlot = model.slots[slot]
			var planned_texts: PackedStringArray = PackedStringArray()
			for spec: StickerSpec in planned.stickers:
				planned_texts.append(spec.text)
			var shown: PackedStringArray = _texts(_layer(screen).stack(slot))
			if shown.is_empty() or not shown[0].begins_with("…"):
				assert_array(Array(shown)).is_equal(Array(planned_texts))
			stickers += shown.size()
			assert_bool(shown.is_empty()).is_equal(planned.stickers.is_empty())
			for sticker: EffectSticker in _layer(screen).stack(slot):
				assert_bool(sticker.is_slapping()).is_false()
			assert_object(_layer(screen).pay_tag(slot)).is_null()
			assert_array(_layer(screen).sparkles(slot)).is_empty()
			assert_bool(_layer(screen).stamp(slot) != null).is_equal(planned.has_stamp())
			assert_int(item.relation).is_equal(ItemView.Relation.NONE)
			assert_int(item.boost_rings).is_equal(0)
			assert_bool(item.denied).is_equal(planned.denied)
			assert_bool(item.sticker().is_struck()).is_false()
			assert_float(item._stand.modulate.a).is_equal(1.0)
		assert_int(stickers).is_greater(3)
		for index: int in range(screen.run.upgrades.size()):
			assert_bool(screen._loyalty_card.has_relation(index)).is_false()
		assert_bool(screen._inspection_tag.has_relation()).is_false()
		assert_object(screen._effects.focused_card()).is_null()
		var failures: Array[String] = []
		# Every check above ran at 1x: the count's start is the subject there.
		Rush.speed_up(_runner, COUNT_FACTOR)
		while screen._counting:
			await get_tree().process_frame
			for part: Control in _layer(screen).parts():
				if not (part is EffectSticker or part is DenyStamp):
					failures.append("%s shows in the count" % part.name)
			for slot: int in range(screen._row_views.size()):
				var shown: bool = _item(screen, slot).is_visible_in_tree()
				for sticker: EffectSticker in _layer(screen).stack(slot):
					if sticker.visible != shown:
						failures.append("slot %d: a sticker shown %s" % [slot, sticker.visible])
		assert_array(failures.slice(0, 5)).override_failure_message(str(failures)).is_empty()
		assert_array(_layer(screen).parts()).is_empty()


## Places Eggs, Bread and Milk, then another Milk (`reduced`: under reduced motion): Bread's
## stickers stay still, the new Milk's slap on, the strips' chevrons step and its 3-ring halo
## steps out from 1 ring, or (`reduced`) none of it, all 3 rings at once; then it has all ended,
## nothing loops, and a refresh shows the Milk's 3 rings at once (never replayed). The tuning is
## slowed (and every boost given 3 rings) so the checks never race the frame time.
func _assert_motion(reduced: bool) -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.set_reduced_motion(reduced)
	var tuning: PlanningTuning = screen._effects.tuning.duplicate() as PlanningTuning
	tuning.slap_frame_s = SLOW_FRAME_S
	tuning.halo_step_s = SLOW_FRAME_S
	tuning.halo_ratios = PackedInt32Array([1, 1])
	screen._effects.tuning = tuning
	_layer(screen).tuning = tuning
	await _place(screen, ["eggs", "bread", "milk"])
	var layer: PlanningLayer = _layer(screen)
	var settle: float = tuning.halo_step_s * 4.0 + tuning.slap_frame_s * 4.0
	await _settled(settle)
	var bread_texts: PackedStringArray = _texts(layer.stack(1))
	screen._debug.add_card("milk")
	screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
	screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_array(Array(_texts(layer.stack(1)))).is_equal(Array(bread_texts))
	for sticker: EffectSticker in layer.stack(1):
		assert_bool(sticker.is_slapping()).is_false()
	var fresh: Array[EffectSticker] = layer.stack(3)
	assert_array(fresh).is_not_empty()
	for sticker: EffectSticker in fresh:
		assert_bool(sticker.is_slapping()).is_equal(not reduced)
	assert_array(layer.strips()).is_not_empty()
	for strip: RailStrip in layer.strips():
		assert_bool(strip.is_stepping()).is_equal(not reduced)
	var milk: ItemView = _item(screen, 3)
	assert_int(milk.boost_rings).is_equal(ArtStyle.HALO_MAX_RINGS)
	assert_float(milk.halo_step_s).is_equal(0.0 if reduced else tuning.halo_step_s)
	var halo: TextureRect = milk.sprite().get_node(ItemView.HALO_NAME) as TextureRect
	var first: int = milk.boost_rings if reduced else 1
	assert_object(halo.material).is_same(ArtStyle.halo_material(first))
	assert_int(_looping_tweens()).is_equal(0)
	await _settled(settle)
	for sticker: EffectSticker in fresh:
		assert_bool(sticker.is_slapping()).is_false()
		assert_vector(sticker.get_node("Slap").scale).is_equal(Vector2.ONE)
	for strip: RailStrip in layer.strips():
		assert_bool(strip.is_stepping()).is_false()
	assert_object(halo.material).is_same(ArtStyle.halo_material(milk.boost_rings))
	# A refresh: the rings the Milk showed come back at once.
	screen._effects.show_all(screen.run.preview(), screen._row_views, screen.run)
	milk = _item(screen, 3)
	assert_int(milk.halo_start).is_equal(ArtStyle.HALO_MAX_RINGS)
	halo = milk.sprite().get_node(ItemView.HALO_NAME) as TextureRect
	assert_object(halo.material).is_same(ArtStyle.halo_material(ArtStyle.HALO_MAX_RINGS))


## `items` (the view showing each slot) show `model`: each stack's texts are its stickers' (the
## earliest folded into "…+N" when they don't fit), each pay tag's text and glyph, each struck
## base, each stamp, each halo and grey.
func _assert_model_shown(screen: ShiftScreen, model: PlanningModel, items: Array[ItemView]) -> void:
	var layer: PlanningLayer = _layer(screen)
	assert_int(items.size()).is_equal(model.slots.size())
	for slot: int in range(model.slots.size()):
		var planning: PlanningSlot = model.slots[slot]
		var item: ItemView = items[slot]
		var message: String = "slot %d" % slot
		var expected: PackedStringArray = PackedStringArray()
		for spec: StickerSpec in planning.stickers:
			expected.append(spec.text)
		var shown: PackedStringArray = _texts(layer.stack(slot))
		if not shown.is_empty() and shown[0].begins_with("…"):
			var kept: int = shown.size() - 1
			assert_str(shown[0]).is_equal(StickerSpec.MORE_TEXT % (expected.size() - kept))
			shown = shown.slice(1)
			expected = expected.slice(expected.size() - kept)
		assert_array(shown).override_failure_message(message).is_equal(expected)
		var tag: PayTag = layer.pay_tag(slot)
		if planning.pay == PlanningModel.Pay.PLAIN:
			assert_object(tag).override_failure_message(message).is_null()
		else:
			assert_str(tag.text()).override_failure_message(message).is_equal(planning.pay_text)
			assert_int(tag.glyph).override_failure_message(message).is_equal(planning.glyph)
		assert_bool(layer.stamp(slot) != null).override_failure_message(message).is_equal(
			planning.has_stamp()
		)
		assert_int(item.boost_rings).override_failure_message(message).is_equal(planning.rings)
		assert_bool(item.denied).override_failure_message(message).is_equal(planning.denied)
		if item.form == ItemView.Form.BELT:
			assert_bool(item.sticker().is_struck()).override_failure_message(message).is_equal(
				planning.struck
			)


## The layer draws a calm rail strip for each of `model`'s strips in a lane (none for an overflow),
## in giver order, none with a factor or gain badge while calm.
func _assert_strips_shown(screen: ShiftScreen, model: PlanningModel) -> void:
	var expected: Array[int] = []
	for spec: RailStripSpec in model.strips:
		if spec.lane >= 0:
			expected.append(spec.giver_slot)
	var shown: Array[int] = []
	var parts: Array[Control] = _layer(screen).parts()
	for strip: RailStrip in _layer(screen).strips():
		shown.append(strip.spec().giver_slot)
		assert_bool(parts.has(strip)).is_true()
		assert_array(strip.gains()).is_empty()
	for part: Control in parts:
		assert_str(String(part.name)).not_contains("FactorBadge")
	assert_array(shown).is_equal(expected)


## With item `focused` hovered (-1: none), exactly the stickers on it or caused by it are lit
## (none on a stamped item), and every sticker is lit with no focus but a stamped item's.
func _assert_lit(screen: ShiftScreen, focused: int) -> void:
	var layer: PlanningLayer = _layer(screen)
	for slot: int in range(screen._row_views.size()):
		for sticker: EffectSticker in layer.stack(slot):
			var lit: bool = focused < 0 or slot == focused or sticker.spec().caused_by_card(focused)
			lit = lit and layer.stamp(slot) == null
			(
				assert_bool(sticker.is_drained())
				. override_failure_message("slot %d %s" % [slot, sticker.text()])
				. is_equal(not lit)
			)


static func _texts(stickers: Array[EffectSticker]) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for sticker: EffectSticker in stickers:
		texts.append(sticker.text())
	return texts


static func _sticker_with(stickers: Array[EffectSticker], text: String) -> EffectSticker:
	for sticker: EffectSticker in stickers:
		if sticker.text() == text:
			return sticker
	return null


static func _layer(screen: ShiftScreen) -> PlanningLayer:
	return screen._stage.planning_layer


static func _views(screen: ShiftScreen) -> Array[ItemView]:
	return PlanningEffects._items_in(screen._row_views, -1, null)


static func _item(screen: ShiftScreen, slot: int) -> ItemView:
	return screen._row_views[slot] as ItemView


## A new run's screen: an earlier screen's run save in the test folder is removed first, so the
## screen never resumes it (since #77 a new run saves at once, with no impulse rack before it).
func _screen() -> ShiftScreen:
	if FileAccess.file_exists(_folder.path_join(SaveService.RUN_FILE)):
		DirAccess.remove_absolute(_folder.path_join(SaveService.RUN_FILE))
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(2)
	return screen


## The reference row on shift 1: Coupon engine and Slot engine given, the Spot check set.
func _full_row(screen: ShiftScreen) -> void:
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("slot_engine")
	screen._debug.set_inspection("spot_check")
	await _place(screen, FULL_ROW)


## Places each card at the row's end as the player does: picked from the hand, then its slot
## clicked.
func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	var placed: int = screen.run.row.size()
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(placed + ids.size())
	await _frames(3)


func _move(screen: ShiftScreen, point: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	screen._drag._input(motion)


func _release(screen: ShiftScreen, point: Vector2) -> void:
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	screen._drag._input(release)


static func _slot_center(screen: ShiftScreen, slot: int) -> Vector2:
	return screen._slots[slot].get_global_rect().get_center()


func _looping_tweens() -> int:
	var count: int = 0
	for tween: Tween in get_tree().get_processed_tweens():
		if tween.is_valid() and tween.get_loops_left() < 0:
			count += 1
	return count


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Waits `seconds` of game time for the planning motion (tweens and timers, all in game time) to
## settle, at SETTLE_FACTOR, then puts game time back to 1x.
func _settled(seconds: float) -> void:
	Rush.speed_up(_runner, SETTLE_FACTOR)
	await _seconds(seconds)
	Rush.speed_up(_runner, 1.0)


## The global centre of `item`'s hit area (where a pointer on it would be).
static func _hit_center(item: ItemView) -> Vector2:
	return item.get_global_transform() * item.hit_rect().get_center()


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for child: Node in screen._hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")


## Whether every text of `shown` is in `all`, in the same order (a subsequence).
static func _in_order(shown: PackedStringArray, all: PackedStringArray) -> bool:
	var at: int = 0
	for text: String in shown:
		at = all.find(text, at)
		if at < 0:
			return false
		at += 1
	return true
