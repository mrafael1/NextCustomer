extends GdUnitTestSuite
## The game's one hover tip (the hover tips revamp, design B "paper card": TipCard, mounted by
## GlyphTips). TipCard.place() opens the card on a side of its target, GAP off it, flips to the
## opposite side where there is no room and keeps it MARGIN inside the screen (its shadow too);
## place_boxes() stacks the keyword boxes beside it, never over it. Mounted, a tip shows only after
## SHOW_DELAY_S, for the target under the pointer, inside the viewport at 1280x720 and 1920x1080
## with its boxes clear of it; Shift keeps it open (moving away no longer closes it, its footer says
## SHIFT KEPT), Esc closes a kept tip and a right-click asks for the handbook (guide_requested).
## Below a ticket's glyphs (its row's and its text's) a tip opens under the ticket. On the real
## shift screen the pointer on a belt ticket's glyph keeps the item hovered (the glyph takes no
## pointer, so a press still reaches the item for its drag), a press hides the tip, and no tip
## shows while the shift is counted. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards"
const STAGE := Rect2(0, 0, 1280, 720)
## The two window sizes the tips must fit (the game's 720p canvas and a 1080p one).
const VIEWPORTS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const CARD_SIZE := Vector2(256, 140)

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Each side: GAP off the target, centred on it; a side with no room flips to its opposite.
func test_a_card_opens_on_its_side_and_flips_at_the_edges() -> void:
	var target: Rect2 = Rect2(600, 300, 40, 20)
	var below: Array = TipCard.place(target, target, TipCard.Opens.BELOW, CARD_SIZE, STAGE)
	assert_int(below[1]).is_equal(TipCard.Opens.BELOW)
	assert_float((below[0] as Rect2).position.y).is_equal(target.end.y + TipCard.GAP)
	var above: Array = TipCard.place(target, target, TipCard.Opens.ABOVE, CARD_SIZE, STAGE)
	assert_float((above[0] as Rect2).end.y).is_equal(target.position.y - TipCard.GAP)
	var right: Array = TipCard.place(target, target, TipCard.Opens.RIGHT, CARD_SIZE, STAGE)
	assert_float((right[0] as Rect2).position.x).is_equal(target.end.x + TipCard.GAP)
	var left: Array = TipCard.place(target, target, TipCard.Opens.LEFT, CARD_SIZE, STAGE)
	assert_float((left[0] as Rect2).end.x).is_equal(target.position.x - TipCard.GAP)
	for placed: Array in [below, above]:
		var centre: float = (placed[0] as Rect2).get_center().x
		assert_float(centre).is_equal_approx(target.get_center().x, TipCard.PX)
	# At the foot, BELOW flips ABOVE; at the top, ABOVE flips BELOW; at the sides likewise.
	var foot: Rect2 = Rect2(600, 690, 40, 20)
	var flipped: Array = TipCard.place(foot, foot, TipCard.Opens.BELOW, CARD_SIZE, STAGE)
	assert_int(flipped[1]).is_equal(TipCard.Opens.ABOVE)
	var top: Rect2 = Rect2(600, 4, 40, 20)
	assert_int(TipCard.place(top, top, TipCard.Opens.ABOVE, CARD_SIZE, STAGE)[1]).is_equal(
		TipCard.Opens.BELOW
	)
	var east: Rect2 = Rect2(1240, 300, 30, 20)
	assert_int(TipCard.place(east, east, TipCard.Opens.RIGHT, CARD_SIZE, STAGE)[1]).is_equal(
		TipCard.Opens.LEFT
	)
	var west: Rect2 = Rect2(8, 300, 30, 20)
	assert_int(TipCard.place(west, west, TipCard.Opens.LEFT, CARD_SIZE, STAGE)[1]).is_equal(
		TipCard.Opens.RIGHT
	)


## At every corner and edge of both screens, on every side: the card (its shadow too) stays
## MARGIN inside the screen, on the 2 px grid, and its boxes stay inside without covering it.
func test_a_card_and_its_boxes_stay_on_screen_at_both_sizes() -> void:
	var boxes: Array[Vector2] = [Vector2(172, 90), Vector2(172, 70)]
	for viewport: Vector2i in VIEWPORTS:
		var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport))
		var inside: Rect2 = screen.grow(-TipCard.MARGIN)
		for at: Vector2 in _spots(screen):
			var target: Rect2 = Rect2(at, Vector2(36, 24))
			for want: int in [0, 1, 2, 3]:
				var placed: Array = TipCard.place(
					target, target, want as TipCard.Opens, CARD_SIZE, screen
				)
				var card: Rect2 = placed[0]
				var where: String = "%s at %s opens %d: %s" % [viewport, at, want, card]
				var shadowed: Rect2 = card.merge(Rect2(card.position + TipCard.SHADOW, card.size))
				assert_bool(inside.encloses(shadowed)).override_failure_message(where).is_true()
				assert_float(fmod(card.position.x, TipCard.PX)).is_equal(0.0)
				assert_float(fmod(card.position.y, TipCard.PX)).is_equal(0.0)
				var rects: Array[Rect2] = TipCard.place_boxes(
					card, placed[1], boxes, screen, target
				)
				assert_int(rects.size()).is_equal(2)
				for rect: Rect2 in rects:
					var message: String = "%s box %s" % [where, rect]
					assert_bool(inside.encloses(rect)).override_failure_message(message).is_true()
					(
						assert_bool(rect.intersects(target))
						. override_failure_message(message + " over the target")
						. is_false()
					)
					(
						assert_bool(rect.intersects(shadowed))
						. override_failure_message(message)
						. is_false()
					)
				assert_bool(rects[0].intersects(rects[1])).is_false()


## A card flipped LEFT at the screen's right edge keeps its boxes on its far (left) side, away from
## the target it came from; a card opening RIGHT with no room on its right stacks them under itself,
## never back over the target (review of 2026-11-13).
func test_boxes_keep_off_the_target() -> void:
	var boxes: Array[Vector2] = [Vector2(172, 90), Vector2(172, 70)]
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(1280, 720))
	var east: Rect2 = Rect2(1200, 300, 40, 24)
	var placed: Array = TipCard.place(east, east, TipCard.Opens.RIGHT, CARD_SIZE, screen)
	assert_int(placed[1]).is_equal(TipCard.Opens.LEFT)
	var card: Rect2 = placed[0]
	for rect: Rect2 in TipCard.place_boxes(card, placed[1], boxes, screen, east):
		assert_bool(rect.intersects(east)).is_false()
		assert_float(rect.end.x).is_less_equal(card.position.x)
	var middle: Rect2 = Rect2(860, 200, 40, 24)
	placed = TipCard.place(middle, middle, TipCard.Opens.RIGHT, CARD_SIZE, screen)
	assert_int(placed[1]).is_equal(TipCard.Opens.RIGHT)
	card = placed[0]
	for rect: Rect2 in TipCard.place_boxes(card, placed[1], boxes, screen, middle):
		assert_bool(rect.intersects(middle)).is_false()
		assert_bool(screen.grow(-TipCard.MARGIN).encloses(rect)).is_true()
	# No room beside or under: the stack stays on screen (over the card's top, not above the screen).
	var tall: Rect2 = Rect2(0, 0, 1240, 640)
	for rect: Rect2 in TipCard.place_boxes(tall, TipCard.Opens.BELOW, boxes, screen):
		assert_float(rect.position.y).is_greater_equal(TipCard.MARGIN)


## A card's tail sits on the edge facing its target and points at the target's middle.
func test_a_cards_tail_points_at_its_target() -> void:
	var card: TipCard = auto_free(TipCard.new())
	add_child(card)
	card.show_spec(TipWords.box(CardText.BATCH_WORD))
	var target: Rect2 = Rect2(600, 300, 40, 20)
	for want: int in [0, 1, 2, 3]:
		var placed: Array = TipCard.place(target, target, want as TipCard.Opens, card.size, STAGE)
		card.position = (placed[0] as Rect2).position
		card.point_tail(placed[1], target)
		# Its true middle (a side's tail is turned a quarter, which its rect ignores).
		var tip_end: Vector2 = card.tail().get_global_transform() * (TipCard.TAIL_SIZE / 2.0)
		var middle: Vector2 = target.get_center()
		var message: String = "opens %d: tail at %s" % [want, tip_end]
		if want == TipCard.Opens.BELOW or want == TipCard.Opens.ABOVE:
			assert_float(tip_end.x).override_failure_message(message).is_equal_approx(
				middle.x, TipCard.PX
			)
		else:
			assert_float(tip_end.y).override_failure_message(message).is_equal_approx(
				middle.y, TipCard.PX
			)
		var card_rect: Rect2 = Rect2(card.position, card.size)
		assert_bool(target.has_point(tip_end)).override_failure_message(message).is_false()
		(
			assert_bool(card_rect.grow(TipCard.TAIL_OUT).has_point(tip_end))
			. override_failure_message(message)
			. is_true()
		)


## A spec's parts: the title in capitals, the kind's band, the body's chips, the footer's keys
## (CLICK <action>, RIGHT-CLICK HANDBOOK when it opens a page, SHIFT KEPT when kept).
func test_a_card_draws_its_spec() -> void:
	var card: TipCard = auto_free(TipCard.new())
	add_child(card)
	var made: TipSpec = TipSpec.make(TipSpec.Kind.PERK, "Coupon engine", "Pays [BATCH] {x2}.")
	made.tag = "PERK · LV 1"
	made.click = "PICK"
	made.guide = true
	card.show_spec(made)
	assert_str(card.title_text()).is_equal("COUPON ENGINE")
	assert_object(card.band_colour()).is_equal(TipCard.KIND_BANDS[TipSpec.Kind.PERK][0])
	assert_int(card.body().chips().size()).is_equal(1)
	assert_array(card.keys()).is_equal(["CLICK", "PICK", "RIGHT-CLICK", "HANDBOOK"])
	card.show_spec(made, true)
	assert_array(card.keys()).is_equal(
		["SHIFT", "KEPT", "CLICK", "PICK", "RIGHT-CLICK", "HANDBOOK"]
	)
	for part: Control in [card.body()]:
		var rect: Rect2 = Rect2(part.position, part.size)
		assert_bool(Rect2(Vector2.ZERO, card.size).encloses(rect)).is_true()
	assert_float(card.size.x).is_equal(TipCard.WIDTH)
	await _frames(1)  # The first build's parts are freed.
	# Three key pairs need more than one row: every key cap stays inside the card's padding.
	var inner: Rect2 = Rect2(
		Vector2.ONE * TipCard.BORDER, card.size - Vector2.ONE * 2.0 * TipCard.BORDER
	)
	var caps: Array[Rect2] = []
	for child: Node in card.get_children():
		var part: Control = child as Control
		if part == null or not part.name.begins_with("KeyCap"):
			continue
		var rect: Rect2 = Rect2(part.position, part.size)
		caps.append(rect)
		var said: String = "%s %s" % [part.name, rect]
		assert_bool(inner.encloses(rect)).override_failure_message(said).is_true()
	assert_int(caps.size()).is_equal(3)
	for index: int in range(caps.size()):
		for other: int in range(index + 1, caps.size()):
			assert_bool(caps[index].intersects(caps[other])).is_false()


## Mounted in a viewport of each size, a family glyph at every corner: no tip before SHOW_DELAY_S,
## its tip after it, the card inside the viewport and its keyword box (FAMILY) beside it, clear of
## it and inside too.
func test_mounted_tips_wait_and_stay_inside_both_viewports() -> void:
	for viewport: Vector2i in VIEWPORTS:
		var sub: SubViewport = auto_free(SubViewport.new())
		sub.size = viewport
		add_child(sub)
		var holder: Control = Control.new()
		holder.size = Vector2(viewport)
		sub.add_child(holder)
		var tips: GlyphTips = GlyphTips.new()
		tips.reduced_motion = func() -> bool: return true
		holder.add_child(tips)
		var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport))
		var glyphs: Array[FamilyGlyph] = []
		for at: Vector2 in _spots(screen):
			var glyph: FamilyGlyph = FamilyGlyph.new(FamilyPalette.shared().style("Dairy"))
			glyph.position = at
			holder.add_child(glyph)
			glyphs.append(glyph)
		holder.move_child(tips, -1)
		await _frames(2)
		for glyph: FamilyGlyph in glyphs:
			var where: String = "%s at %s" % [viewport, glyph.position]
			tips.hide_tip()
			tips.point_at(Vector2(-50, -50))
			await _frames(1)
			tips.point_at(glyph.get_global_rect().get_center())
			await _seconds(GlyphTips.SHOW_DELAY_S * 0.4)
			assert_object(tips.shown_glyph()).override_failure_message(where).is_null()
			await _seconds(GlyphTips.SHOW_DELAY_S * 0.6 + 0.1)
			assert_object(tips.shown_glyph()).override_failure_message(where).is_same(glyph)
			var card: Rect2 = tips.tip().get_global_rect()
			(
				assert_bool(screen.grow(-TipCard.MARGIN).encloses(card))
				. override_failure_message("%s: %s" % [where, card])
				. is_true()
			)
			(
				assert_bool(card.intersects(glyph.get_global_rect()))
				. override_failure_message(where)
				. is_false()
			)
			assert_int(tips.boxes().size()).override_failure_message(where).is_equal(1)
			for box: TipCard in tips.boxes():
				var rect: Rect2 = box.get_global_rect()
				var message: String = "%s box %s card %s" % [where, rect, card]
				assert_bool(screen.encloses(rect)).override_failure_message(message).is_true()
				assert_bool(rect.intersects(card)).override_failure_message(message).is_false()
				assert_str(box.title_text()).is_equal(TipWords.title_of("FAMILY").to_upper())
		sub.remove_child(holder)
		holder.free()


## Shift keeps the shown tip: moving away no longer closes it and its footer says SHIFT KEPT; Esc
## closes it. A right-click on a shown tip asks for its handbook page and closes it.
func test_shift_keeps_a_tip_and_a_right_click_asks_for_the_handbook() -> void:
	var holder: Control = auto_free(Control.new())
	holder.size = STAGE.size
	add_child(holder)
	var glyph: FamilyGlyph = FamilyGlyph.new(FamilyPalette.shared().style("Bakery"))
	glyph.position = Vector2(600, 400)
	holder.add_child(glyph)
	var tips: GlyphTips = GlyphTips.new()
	tips.guide_for = func(_target: TipTarget) -> bool: return true
	holder.add_child(tips)
	await _frames(2)
	await _tip_for(tips, glyph)
	assert_bool(tips.tip().keys().has(TipCard.KEY_RIGHT_CLICK)).is_true()
	tips._input(_key(KEY_SHIFT))
	assert_bool(tips.is_kept()).is_true()
	assert_array(tips.tip().keys().slice(0, 2)).is_equal([TipCard.KEY_SHIFT, TipCard.KEPT_WORD])
	tips.point_at(Vector2(5, 5))
	await _frames(3)
	assert_object(tips.shown_glyph()).is_same(glyph)
	tips._input(_key(KEY_ESCAPE))
	assert_object(tips.shown_glyph()).is_null()
	assert_bool(tips.is_kept()).is_false()
	# Right-click: guide_requested with the target, the tip closed.
	var asked: Array[TipTarget] = []
	tips.guide_requested.connect(func(target: TipTarget) -> void: asked.append(target))
	await _tip_for(tips, glyph)
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = glyph.get_global_rect().get_center()
	tips._input(press)
	assert_array(asked).is_equal([glyph])
	assert_object(tips.shown_glyph()).is_null()


## The switch grace and the leaving: a tip that isn't kept closes as the pointer leaves; the next
## target within SWITCH_GRACE_S opens at once, one after it waits SHOW_DELAY_S again. A click on a
## kept tip closes it and is used up.
func test_a_tip_leaves_switches_at_once_and_a_click_closes_a_kept_one() -> void:
	var holder: Control = auto_free(Control.new())
	holder.size = STAGE.size
	add_child(holder)
	var bakery: FamilyGlyph = FamilyGlyph.new(FamilyPalette.shared().style("Bakery"))
	bakery.position = Vector2(500, 400)
	holder.add_child(bakery)
	var dairy: FamilyGlyph = FamilyGlyph.new(FamilyPalette.shared().style("Dairy"))
	dairy.position = Vector2(700, 400)
	holder.add_child(dairy)
	var tips: GlyphTips = GlyphTips.new()
	holder.add_child(tips)
	await _frames(2)
	# Not kept: leaving closes it.
	await _tip_for(tips, bakery)
	tips.point_at(Vector2(5, 5))
	await _frames(2)
	assert_object(tips.shown_glyph()).is_null()
	# Within the grace: the next target's tip opens on the next frame.
	await _tip_for(tips, bakery)
	tips.point_at(dairy.get_global_rect().get_center())
	await _frames(2)
	assert_object(tips.shown_glyph()).is_same(dairy)
	# After the grace: it waits again.
	tips.point_at(Vector2(5, 5))
	await _seconds(GlyphTips.SWITCH_GRACE_S + 0.15)
	tips.point_at(bakery.get_global_rect().get_center())
	await _frames(2)
	assert_object(tips.shown_glyph()).is_null()
	await _seconds(GlyphTips.SHOW_DELAY_S + 0.1)
	assert_object(tips.shown_glyph()).is_same(bakery)
	# Kept: a left click closes it and the click is used up.
	tips._input(_key(KEY_SHIFT))
	assert_bool(tips.is_kept()).is_true()
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(5, 5)
	tips._input(press)
	assert_object(tips.shown_glyph()).is_null()
	assert_bool(tips.is_kept()).is_false()
	assert_bool(get_viewport().is_input_handled()).is_true()


## Mounted over a ticket and a popup (standing for the offers' popup, which stays while the
## pointer is on it): the ticket's glyphs (its row's and its text's) and its price window tip under
## the ticket (or over it at the screen's foot) without covering it, the popup's clear of their
## glyph; inside the screen; off the glyph, or `blocked`, no tip.
func test_mounted_tips_show_for_the_glyph_under_the_pointer() -> void:
	var holder: Control = auto_free(Control.new())
	holder.size = STAGE.size
	get_tree().root.add_child(holder)
	var scissors: PriceSticker = PriceSticker.new(_card("scissors"))
	scissors.position = Vector2(300, 300)
	holder.add_child(scissors)
	var popup: ScanPopup = ScanPopup.new()
	holder.add_child(popup)
	var milk: CardDefinition = _card("milk")
	popup.show_card(milk, milk.tags)
	popup.position = Vector2(700, 300)
	var tips: GlyphTips = GlyphTips.new()
	tips.reduced_motion = func() -> bool: return true
	var blocked: Array[bool] = [false]
	tips.blocked = func() -> bool: return blocked[0]
	holder.add_child(tips)
	await _frames(2)
	var glyphs: Array[TipTarget] = [scissors.window()]
	for glyph: FamilyGlyph in scissors.glyphs() + scissors.summary().glyphs():
		glyphs.append(glyph)
	for word: FamilyWord in scissors.summary().words():
		glyphs.append(word)
	assert_int(glyphs.size()).is_greater_equal(2)
	var ticket: Rect2 = scissors.get_global_rect()
	for glyph: TipTarget in glyphs:
		var shown: TipCard = await _tip_for(tips, glyph)
		var box: Rect2 = shown.get_global_rect()
		var message: String = "%s: %s" % [glyph.name, box]
		assert_str(shown.tip_text()).is_equal(glyph.full_tip())
		assert_float(box.position.y).override_failure_message(message).is_equal(
			ticket.end.y + TipCard.GAP
		)
		assert_bool(STAGE.encloses(box)).override_failure_message(message).is_true()
		assert_bool(box.intersects(ticket)).override_failure_message(message).is_false()
	assert_int(popup.glyphs().size()).is_greater_equal(1)
	for glyph: FamilyGlyph in popup.glyphs():
		var shown: TipCard = await _tip_for(tips, glyph)
		var box: Rect2 = shown.get_global_rect()
		var message: String = "%s: %s" % [glyph.family, box]
		(
			assert_bool(box.intersects(glyph.get_global_rect()))
			. override_failure_message(message)
			. is_false()
		)
		assert_bool(STAGE.encloses(box)).override_failure_message(message).is_true()
	# Off every glyph: none.
	tips.point_at(Vector2(5, 5))
	await _frames(2)
	assert_object(tips.shown_glyph()).is_null()
	# Blocked (a drag, the count-up): none, even resting on a glyph.
	blocked[0] = true
	tips.point_at(glyphs[0].get_global_rect().get_center())
	await _seconds(GlyphTips.SHOW_DELAY_S * 2.0)
	assert_object(tips.shown_glyph()).is_null()


## A ticket's colour (#105): resting the pointer on the ticket off its glyphs shows its card (the
## family's, or the coupon's), below the ticket; on a glyph the glyph's tip wins. A ticket clipped
## by its parent (a scrolled shelf) shows nothing where it is cut off, its glyphs included.
func test_a_tickets_colour_tips_below_it_and_a_clipped_ticket_shows_none() -> void:
	var holder: Control = auto_free(Control.new())
	holder.size = STAGE.size
	get_tree().root.add_child(holder)
	var milk: PriceSticker = PriceSticker.new(_card("milk"))
	milk.position = Vector2(300, 400)
	holder.add_child(milk)
	var clip: Control = Control.new()
	clip.clip_contents = true
	clip.position = Vector2(600, 400)
	clip.size = Vector2(PriceSticker.SIZE.x, 30)
	holder.add_child(clip)
	var cut: PriceSticker = PriceSticker.new(_card("cereal"))
	# Scrolled up: only its lower half shows, its glyph row is cut off.
	cut.position = Vector2(0, -34)
	clip.add_child(cut)
	var tips: GlyphTips = GlyphTips.new()
	tips.reduced_motion = func() -> bool: return true
	holder.add_child(tips)
	await _frames(2)
	var spot: PriceSticker.ColourSpot = _spot(milk)
	var shown: TipCard = await _tip_for(
		tips, spot, milk.get_global_rect().position + Vector2(4, 60)
	)
	assert_str(shown.tip_text()).is_equal(spot.full_tip())
	assert_str(shown.title_text()).is_not_empty()
	assert_int(shown.side).is_equal(TipCard.Opens.BELOW)
	var box: Rect2 = shown.get_global_rect()
	assert_float(box.position.y).is_equal(milk.get_global_rect().end.y + TipCard.GAP)
	assert_bool(STAGE.encloses(box)).override_failure_message(str(box)).is_true()
	# On a glyph, the glyph's tip.
	var glyph: FamilyGlyph = milk.glyphs()[0]
	await _tip_for(tips, glyph, glyph.get_global_rect().get_center())
	# The clipped ticket: its cut-off glyph and colour show nothing, its shown part its colour.
	var hidden: FamilyGlyph = cut.glyphs()[0]
	assert_bool(clip.get_global_rect().intersects(hidden.get_global_rect())).is_false()
	tips.hide_tip()
	tips.point_at(hidden.get_global_rect().get_center())
	await _seconds(GlyphTips.SHOW_DELAY_S + 0.1)
	assert_object(tips.shown_glyph()).is_null()
	assert_bool(GlyphTips.is_clipped(hidden, hidden.get_global_rect().get_center())).is_true()
	await _tip_for(tips, _spot(cut), clip.get_global_rect().get_center())


## On the real shift screen: the pointer on a belt ticket's glyph keeps its item hovered (a press
## there reaches the item, which drags), the glyph's tip opens off the ticket (under it, or over it
## where the screen's foot leaves no room) inside the screen, a press hides it, and none shows
## while the shift is counted.
func test_a_belt_glyph_tips_and_keeps_its_item() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()  # The time card (v0.70) stays out of the way.
	await _frames(3)
	var run: RunState = screen.run
	var milk: CardInstance = run.debug_add_to_hand(_card("milk"))
	assert_bool(run.place(milk, run.row.size())).is_true()
	screen._refresh()
	await _frames(3)
	var view: ItemView = screen._row_views[run.row.find(milk)] as ItemView
	var sticker: PriceSticker = view.sticker()
	var glyph: FamilyGlyph = sticker.glyphs()[0]
	assert_int(glyph.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var at: Vector2 = glyph.get_global_rect().get_center()
	_move(at)
	await _seconds(GlyphTips.SHOW_DELAY_S + 0.1)
	var hovered: Control = screen.get_viewport().gui_get_hovered_control()
	assert_object(hovered).is_not_null()
	(
		assert_bool(hovered == view or view.is_ancestor_of(hovered))
		. override_failure_message(str(hovered))
		. is_true()
	)
	var tips: GlyphTips = screen._glyph_tips
	assert_object(tips.shown_glyph()).is_same(glyph)
	var tip: TipCard = tips.tip()
	var box: Rect2 = tip.get_global_rect()
	assert_str(tip.tip_text()).is_equal(glyph.full_tip())
	# On the belt the membership tip names the family's other items there (tickets v5).
	assert_str(glyph.tip_more).is_equal("No other Breakfast item in the row")
	(
		assert_bool(box.intersects(sticker.get_global_rect()))
		. override_failure_message(str(box))
		. is_false()
	)
	assert_bool(screen.get_global_rect().encloses(box)).override_failure_message(str(box)).is_true()
	# A press hides it (the item takes the press).
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	press.global_position = at
	tips._input(press)
	assert_object(tips.shown_glyph()).is_null()
	# While counting: none.
	screen._counting = true
	_move(at + Vector2(1, 0))
	await _seconds(GlyphTips.SHOW_DELAY_S * 2.0)
	assert_object(tips.shown_glyph()).is_null()
	screen._counting = false


## v1.11 (the user's "a small bag glyph beside the giver and put the wording in its tooltip"): the
## count blocks the tips, but not a monitor count row's bag glyph, whose row shows only then:
## resting the pointer on it during the count opens its "From the bag" tip, and the next step
## (which rebuilds the rows) hands the tip to the rebuilt glyph without closing it. Other tips stay
## blocked (test_a_belt_glyph_tips_and_keeps_its_item).
func test_the_bag_glyph_tips_during_the_count() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	await _frames(3)
	screen._counting = true
	var column: MonitorItemColumn = screen._monitor.item_column()
	column.reduced_motion = func() -> bool: return true
	column.start_item(_card("banana"), PackedStringArray(["Produce"]), false)
	var eggs_mini: Texture2D = load("res://art/minis/eggs.png")
	column.show_step("Eggs  ×2", false, true, eggs_mini, true, false, "Eggs")
	await _frames(2)
	var bag: TipTarget = column.step_rows()[-1].get_node("FromBag") as TipTarget
	var tips: GlyphTips = screen._glyph_tips
	var at: Vector2 = bag.get_global_rect().get_center()
	_move(at)
	await _seconds(GlyphTips.SHOW_DELAY_S + 0.1)
	assert_object(tips.shown_glyph()).is_same(bag)
	assert_str(tips.tip().tip_text()).is_equal(MonitorStepRow.bag_tip_of("Eggs"))
	assert_str(tips.tip().tip_text()).starts_with("From Eggs (already scanned)")
	# The rows rebuilt (a step's line added under it): the glyph under the pointer keeps the tip.
	column.show_step("Eggs  ×2", false, true, eggs_mini, true, false, "Eggs")
	await _frames(2)
	var rebuilt: TipTarget = column.step_rows()[0].get_node("FromBag") as TipTarget
	assert_bool(rebuilt.get_global_rect().has_point(at)).is_true()
	assert_object(tips.shown_glyph()).is_same(rebuilt)
	assert_str(tips.tip().tip_text()).is_equal(MonitorStepRow.bag_tip_of("Eggs"))
	screen._counting = false


## shown_changed says which tip shows, once per change (#105 piece 3: the mix highlight follows
## it): the glyph when its tip shows, null when it hides, nothing for a repeat.
func test_the_shown_tip_is_signalled_once_per_change() -> void:
	var holder: Control = auto_free(Control.new())
	holder.size = STAGE.size
	add_child(holder)
	var palette: FamilyPalette = FamilyPalette.shared()
	var breakfast: FamilyGlyph = FamilyGlyph.new(palette.style("Breakfast"))
	var dairy: FamilyGlyph = FamilyGlyph.new(palette.style("Dairy"))
	breakfast.position = Vector2(100, 200)
	dairy.position = Vector2(300, 200)
	holder.add_child(breakfast)
	holder.add_child(dairy)
	var tips: GlyphTips = GlyphTips.new()
	holder.add_child(tips)
	var seen: Array[TipTarget] = []
	tips.shown_changed.connect(func(target: TipTarget) -> void: seen.append(target))
	tips.show_tip(breakfast)
	tips.show_tip(breakfast)
	tips.show_tip(dairy)
	tips.hide_tip()
	tips.hide_tip()
	assert_array(seen).is_equal([breakfast, dairy, null])
	assert_str((seen[0] as FamilyGlyph).family).is_equal("Breakfast")


## Rests the pointer on `glyph` (at `at`, else its middle) for the wait, returning the shown tip.
func _tip_for(tips: GlyphTips, glyph: TipTarget, at: Vector2 = Vector2.INF) -> TipCard:
	tips.hide_tip()
	tips.point_at(Vector2(-50, -50))
	tips.point_at(glyph.get_global_rect().get_center() if at == Vector2.INF else at)
	await _seconds(GlyphTips.SHOW_DELAY_S + 0.1)
	assert_object(tips.shown_glyph()).override_failure_message(glyph.tip_text).is_same(glyph)
	return tips.tip()


## A key press (`code`), as the keyboard sends it.
func _key(code: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = code
	key.pressed = true
	return key


## Spots for a target on `screen`: its corners, its edges' middles and its centre (4 px in).
static func _spots(screen: Rect2) -> Array[Vector2]:
	var right: float = screen.end.x - 40.0
	var foot: float = screen.end.y - 30.0
	var middle: Vector2 = screen.get_center()
	return [
		Vector2(4, 4),
		Vector2(right, 4),
		Vector2(4, foot),
		Vector2(right, foot),
		Vector2(middle.x, 4),
		Vector2(middle.x, foot),
		Vector2(4, middle.y),
		Vector2(right, middle.y),
		middle,
	]


## The pointer moves to `at` (the viewport's coordinates), as a real mouse motion.
func _move(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	# In the viewport's own coordinates (no window stretch applied).
	get_tree().root.push_input(motion, true)


func _seconds(seconds: float) -> void:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < seconds * 1000.0:
		await get_tree().process_frame


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _spot(sticker: PriceSticker) -> PriceSticker.ColourSpot:
	return sticker.get_node(PriceSticker.COLOUR_SPOT_NAME) as PriceSticker.ColourSpot


static func _card(card_id: String) -> CardDefinition:
	return load("%s/%s.tres" % [CARDS, card_id]) as CardDefinition


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
