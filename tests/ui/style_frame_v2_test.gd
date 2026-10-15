extends GdUnitTestSuite
## Style frame v2 (debug/style_frame_v2, #75; round 2): each state's layout on the 1280x720 stage
## (headless runs use a 1280x1280 window, so every rect is measured against the stage):
## everything inside the stage, the top bar apart and above the belt, the belt's and the tray's
## cells inside them with each sprite on its mat's face, no sticker over another sticker, a
## sprite, a chip or the purse, summaries of at most 2 lines and chip texts that fit, measured
## with the real fonts. The numbers shown are core's: plaques, the LED, the chips, the receipt
## and the stub come from Scoring.score. The mats follow core's capacity counts, the CLOSED cell
## names its inspection, the purse opens and the TOTAL key is down only while counting. The pile
## shows only once the receipt reaches the counter, joined to its foot. The scan popup sits in
## the stage, points at its item and keeps every card in the stage wherever it is hovered (a hand
## item's beside it, never over the belt); the posed scanner meets nothing. Every printed
## character has its glyph, and the scene's colours are the palette's.
const SCENE := "res://debug/style_frame_v2/style_frame_v2.tscn"
const PALETTE_FILE := "res://art/src/palette.txt"
const STATES: Array[StyleFrameV2.State] = [
	StyleFrameV2.State.PLANNING,
	StyleFrameV2.State.COUNT_UP,
	StyleFrameV2.State.SCAN,
	StyleFrameV2.State.SCAN_BELT,
]
const STAGE := Rect2(0, 0, 1280, 720)


func test_everything_lies_inside_the_stage() -> void:
	for state: StyleFrameV2.State in STATES:
		var frame: StyleFrameV2 = await _frame(state)
		var checked: int = 0
		for control: Control in _controls(frame.stage()):
			var rect: Rect2 = _rect(frame, control)
			checked += 1
			(
				assert_bool(STAGE.encloses(rect))
				. override_failure_message("%s: %s %s" % [state, control.get_path(), rect])
				. is_true()
			)
		assert_int(checked).is_greater(100)
		# The round-2 props by name: the purse, the key bed, the TOTAL key, the CLOSED cell's
		# parts and the scanner (docked or posed).
		var named: Array[Control] = [
			frame.purse(),
			frame.stage().get_node("PurseShadow") as Control,
			frame.register().get_node("Keys") as Control,
			frame.register().total_key(),
			frame.register().total_label(),
			frame.scanner(),
		]
		for closed: Control in frame.belt().closed_cells():
			named.append(closed)
			named.append_array(_controls(closed))
		for control: Control in named:
			var rect: Rect2 = _rect(frame, control)
			(
				assert_bool(STAGE.encloses(rect))
				. override_failure_message("%s: %s %s" % [state, control.name, rect])
				. is_true()
			)


func test_the_top_bar_parts_are_apart_above_the_belt() -> void:
	for state: StyleFrameV2.State in STATES:
		var frame: StyleFrameV2 = await _frame(state)
		var parts: Array[Rect2] = []
		for child: Node in frame.stage().get_node("TopBar").get_children():
			var part: Control = child as Control
			if part.visible:
				parts.append(_rect(frame, part))
		# The shift sign, the loyalty card, the inspection tag, Deck, Export log and the
		# boutique's plaque.
		assert_int(parts.size()).is_equal(6)
		for rect: Rect2 in parts:
			assert_float(rect.end.y).is_less_equal(StyleFrameV2.TOP_BAR_BOTTOM)
		_assert_apart(parts, "top bar")


func test_cells_lie_inside_the_belt_and_the_tray() -> void:
	for state: StyleFrameV2.State in STATES:
		var frame: StyleFrameV2 = await _frame(state)
		var limits: ShiftLimits = StyleFrameFixture.limits()
		var cells: Array[Control] = frame.belt_cells()
		assert_int(cells.size()).is_equal(
			RowCapacity.card_limit(limits) + limits.closed_slots + limits.closed_coupon_slots
		)
		var cell_rects: Array[Rect2] = []
		for cell: Control in cells:
			var rect: Rect2 = _rect(frame, cell)
			cell_rects.append(rect)
			(
				assert_bool(BeltView.INTERIOR.encloses(rect))
				. override_failure_message(str(rect))
				. is_true()
			)
		_assert_apart(cell_rects, "belt cells")
		# Each item's sprite (at rest or lifted) stands on its mat's face, inside the 6 px frame.
		var mats: Array[Panel] = frame.belt().mats()
		for slot: int in range(frame.item_views(true).size()):
			var face: Rect2 = _rect(frame, mats[slot]).grow(-6.0)
			var sprite: Rect2 = _rect(frame, frame.item_view(true, slot).sprite())
			assert_bool(face.encloses(sprite)).override_failure_message(str(sprite)).is_true()
		# Inside the tray's velvet rim.
		var tray: Rect2 = StyleFrameV2.TRAY_RECT.grow(-StyleFrameV2.TRAY_RIM)
		var tray_rects: Array[Rect2] = []
		for view: ItemView in frame.item_views(false):
			var rect: Rect2 = _rect(frame, view)
			tray_rects.append(rect)
			assert_bool(tray.encloses(rect)).override_failure_message(str(rect)).is_true()
			assert_bool(tray.encloses(_rect(frame, view.sticker()))).is_true()
		_assert_apart(tray_rects, "tray cells")


func test_stickers_never_cover_a_sticker_a_sprite_or_a_chip() -> void:
	for state: StyleFrameV2.State in STATES:
		var frame: StyleFrameV2 = await _frame(state)
		var stickers: Array[Rect2] = []
		var others: Array[Rect2] = []
		for view: ItemView in frame.item_views(true) + frame.item_views(false):
			stickers.append(_rect(frame, view.sticker()))
			var sprite: Rect2 = _rect(frame, view.sprite())
			others.append(sprite)
			for chip: EffectChip in view.chips():
				others.append(_rect(frame, chip))
			# A sprite may touch its plaque (lifted), never run under it.
			if view.plaque() != null:
				var plaque: Rect2 = _rect(frame, view.plaque())
				(
					assert_bool(sprite.intersects(plaque))
					. override_failure_message(str(plaque))
					. is_false()
				)
		assert_int(stickers.size()).is_greater_equal(12)
		_assert_apart(stickers, "stickers")
		# Nor does the purse meet a sticker, a sprite or a chip.
		others.append(_rect(frame, frame.purse()))
		for sticker: Rect2 in stickers:
			for other: Rect2 in others:
				(
					assert_bool(sticker.intersects(other))
					. override_failure_message("%s: %s over %s" % [state, sticker, other])
					. is_false()
				)


func test_summaries_and_chip_texts_fit() -> void:
	for state: StyleFrameV2.State in STATES:
		var frame: StyleFrameV2 = await _frame(state)
		for view: ItemView in frame.item_views(true) + frame.item_views(false):
			var summary: Label = view.sticker().summary_label()
			var message: String = "%s: %s" % [view.card.definition.id, summary.text]
			assert_str(summary.text).override_failure_message(message).is_not_empty()
			assert_int(summary.get_line_count()).override_failure_message(message).is_less_equal(
				PriceSticker.MAX_SUMMARY_LINES
			)
			assert_int(summary.get_visible_line_count()).override_failure_message(message).is_equal(
				summary.get_line_count()
			)
			for chip: EffectChip in view.chips():
				var label: Label = chip.label()
				(
					assert_float(label.get_minimum_size().x)
					. override_failure_message(label.text)
					. is_less_equal(label.size.x)
				)


func test_plaques_show_the_payouts() -> void:
	var frame: StyleFrameV2 = await _frame(StyleFrameV2.State.PLANNING)
	var result: ScoreResult = frame.result()
	assert_int(frame.item_views(true).size()).is_equal(result.payouts.size())
	for slot: int in range(result.payouts.size()):
		var view: ItemView = frame.item_view(true, slot)
		assert_str(view.plaque_text()).is_equal("pays €%d" % result.payouts[slot])
		# A €0 plaque is muted, never see-through.
		assert_bool(view.is_plaque_muted()).is_equal(result.payouts[slot] == 0)
		assert_float(view.plaque().modulate.a).is_equal_approx(1.0, 0.001)
	# While counting, a plaque shows once its PAYOUT step has printed: the frozen step is the
	# first of COUNT_UP_SLOT's, before its PAYOUT.
	frame = await _frame(StyleFrameV2.State.COUNT_UP)
	result = frame.result()
	for slot: int in range(result.payouts.size()):
		var view: ItemView = frame.item_view(true, slot)
		if slot < StyleFrameFixture.COUNT_UP_SLOT:
			assert_str(view.plaque_text()).is_equal("pays €%d" % result.payouts[slot])
		else:
			assert_object(view.plaque()).is_null()


func test_the_led_shows_the_total_or_the_subtotal() -> void:
	var quota: int = StyleFrameFixture.limits().quota
	var frame: StyleFrameV2 = await _frame(StyleFrameV2.State.PLANNING)
	var total: int = frame.result().total
	var led: LedTotal = frame.register().led()
	assert_str(led.digits_label().text).is_equal("€%d" % total)
	assert_int(led.lit()).is_equal(LedTotal.lit_segments(total, quota))
	assert_str(led.quota_label().text).is_equal("QUOTA €%d" % quota)
	assert_str(frame.stub_total().text).is_equal("€%d" % total)
	frame = await _frame(StyleFrameV2.State.COUNT_UP)
	var frozen: int = EffectChip.step_indices(frame.result(), StyleFrameFixture.COUNT_UP_SLOT)[0]
	assert_int(frame.frozen_step()).is_equal(frozen)
	var subtotal: int = frame.result().steps[frozen].subtotal
	led = frame.register().led()
	assert_str(led.digits_label().text).is_equal("€%d" % subtotal)
	assert_int(led.lit()).is_equal(LedTotal.lit_segments(subtotal, quota))
	assert_int(LedTotal.lit_segments(0, quota)).is_equal(0)
	assert_int(LedTotal.lit_segments(quota * 2, quota)).is_equal(LedTotal.SEGMENTS)


## One chip per qualifying step (at most 2 per cell, the rest as "+N more"), worded by the
## measured fallback chain; chips of steps after the frozen one are dimmed while counting.
func test_chips_follow_the_steps() -> void:
	for state: StyleFrameV2.State in [StyleFrameV2.State.PLANNING, StyleFrameV2.State.COUNT_UP]:
		var frame: StyleFrameV2 = await _frame(state)
		var result: ScoreResult = frame.result()
		var row: Array[CardInstance] = _row(frame)
		var frozen: int = (
			frame.frozen_step() if state == StyleFrameV2.State.COUNT_UP else result.steps.size()
		)
		var total_chips: int = 0
		for slot: int in range(result.payouts.size()):
			var indices: PackedInt32Array = EffectChip.step_indices(result, slot)
			var chips: Array[EffectChip] = frame.item_view(true, slot).chips()
			assert_int(chips.size()).is_equal(mini(indices.size(), EffectChip.MAX_PER_CELL))
			total_chips += chips.size()
			for place: int in range(chips.size()):
				var step: ScoreStep = result.steps[indices[place]]
				var expected: String = EffectChip.chip_text(
					step,
					StyleFrameFixture.names(row),
					StyleFrameFixture.upgrade_names(),
					StyleFrameFixture.inspection_names(),
					EffectChip.font(),
					EffectChip.FONT_SIZE
				)
				var folded: bool = (
					place == EffectChip.MAX_PER_CELL - 1
					and indices.size() > EffectChip.MAX_PER_CELL
				)
				if folded:
					expected = EffectChip.MORE_TEXT % (indices.size() - place)
				assert_str(chips[place].label().text).is_equal(expected)
				var fizzle: bool = step.step_type == ScoreStep.StepType.WASTED and not folded
				assert_bool(chips[place].is_fizzle()).is_equal(fizzle)
				# A chip still to come is dimmed inside, over an opaque face.
				assert_bool(chips[place].is_dimmed()).is_equal(indices[place] > frozen)
				assert_float(chips[place].modulate.a).is_equal_approx(1.0, 0.001)
		assert_int(total_chips).is_greater_equal(3)
	# Frozen at Batteries' +15: its ×2 is still to come. Multipack's Coupon engine fizzle has
	# landed; core reports its own ×3 fizzle at the end of the row, so that one is still to come.
	var counting: StyleFrameV2 = await _frame(StyleFrameV2.State.COUNT_UP)
	var batteries: Array[EffectChip] = (
		counting.item_view(true, StyleFrameFixture.COUNT_UP_SLOT).chips()
	)
	assert_int(batteries.size()).is_equal(2)
	assert_bool(batteries[0].is_dimmed()).is_false()
	assert_bool(batteries[1].is_dimmed()).is_true()
	var multipack: Array[EffectChip] = counting.item_view(true, 4).chips()
	assert_int(multipack.size()).is_equal(2)
	for chip: EffectChip in multipack:
		assert_bool(chip.is_fizzle()).is_true()
	assert_bool(multipack[0].is_dimmed()).is_false()
	assert_bool(multipack[1].is_dimmed()).is_true()


## Every chip rests on the belt, CHIP_CLEARANCE clear of the bottom rail (its lowest one too).
func test_chips_clear_the_belts_bottom_rail() -> void:
	var checked: int = 0
	for state: StyleFrameV2.State in STATES:
		var frame: StyleFrameV2 = await _frame(state)
		for view: ItemView in frame.item_views(true):
			for chip: EffectChip in view.chips():
				var rect: Rect2 = _rect(frame, chip)
				checked += 1
				(
					assert_float(rect.end.y)
					. override_failure_message("%s: %s" % [state, rect])
					. is_less_equal(BeltView.INTERIOR.end.y - ItemView.CHIP_CLEARANCE)
				)
	assert_int(checked).is_greater(6)
	assert_float(ItemView.CHIP_CLEARANCE).is_greater_equal(4.0)


## The belt's treads run across the rubber at their rhythm, the last one above the bottom rail;
## the rollers' rings are thin grooves every 8 art rows inside the rubber's height.
func test_the_belt_treads_and_rings_keep_their_rhythm() -> void:
	var treads: Array[Rect2] = BeltView.tread_rects()
	assert_int(treads.size()).is_equal(BeltView.TREAD_COUNT)
	for index: int in range(treads.size()):
		assert_bool(BeltView.INTERIOR.encloses(treads[index])).is_true()
		assert_float(treads[index].position.y).is_equal(
			BeltView.TREAD_FIRST + index * BeltView.TREAD_EVERY
		)
	assert_float(treads[treads.size() - 1].end.y).is_less_equal(312.0)
	var rings: Array[Rect2] = BeltView.ring_rects()
	assert_int(rings.size()).is_greater(20)
	var belt: Rect2 = StyleFrameV2.BELT_RECT
	var every: float = 8.0 * ArtStyle.ART_SCALE
	for ring: Rect2 in rings:
		assert_float(ring.size.y).is_equal(BeltView.RING_HEIGHT)
		assert_float(ring.position.y).is_greater_equal(BeltView.INTERIOR.position.y)
		assert_float(ring.end.y).is_less_equal(BeltView.INTERIOR.end.y)
		assert_float(fmod(ring.position.y - BeltView.RING_FIRST, every)).is_equal(0.0)
		# On a roller: in the frame's side margins, inside its ink line.
		var on_left: bool = ring.end.x <= BeltView.INTERIOR.position.x
		var on_right: bool = ring.position.x >= BeltView.INTERIOR.end.x
		assert_bool(on_left or on_right).is_true()
		assert_bool(belt.grow(-ArtStyle.ART_SCALE).encloses(ring)).is_true()


## The chip text keeps whole words, in order: the receipt's source text when it fits, else the
## source's display name, else its first word; never a word cut short.
func test_chip_text_falls_back_by_measuring() -> void:
	var font: Font = EffectChip.font()
	var size: int = EffectChip.FONT_SIZE
	var none: PackedStringArray = PackedStringArray()
	# 1. The receipt's text fits: a card's own receipt text ("Coffee").
	var card_step: ScoreStep = ScoreStep.new()
	card_step.step_type = ScoreStep.StepType.FLAT
	card_step.slot = 2
	card_step.value = 3
	card_step.source_kind = ScoreStep.SourceKind.CARD
	card_step.source_slot = 1
	card_step.text = "Coffee"
	var card_names: PackedStringArray = ["Croissant", "A much longer card name"]
	var source: String = ReceiptView.source_text(card_step, none, none)
	assert_str(source).is_equal("Coffee")
	assert_bool(EffectChip.fits("+3 · " + source, font, size)).is_true()
	assert_str(EffectChip.chip_text(card_step, card_names, none, none, font, size)).is_equal(
		"+3 · " + source
	)
	# An upgrade step without its own text: the receipt names the upgrade, which fits.
	var step: ScoreStep = ScoreStep.new()
	step.step_type = ScoreStep.StepType.FLAT
	step.slot = 4
	step.value = 15
	step.source_kind = ScoreStep.SourceKind.UPGRADE
	step.source_index = 0
	step.text = ""
	var upgrade_names: PackedStringArray = ["Tip jar"]
	source = ReceiptView.source_text(step, upgrade_names, none)
	assert_str(source).is_equal("Tip jar")
	assert_bool(EffectChip.fits("+15 · " + source, font, size)).is_true()
	assert_str(EffectChip.chip_text(step, none, upgrade_names, none, font, size)).is_equal(
		"+15 · Tip jar"
	)
	# 2. The receipt's text ("<text> (Tip jar)") is too long, but the display name fits.
	step.text = "A very long receipt text for this upgrade"
	var long_source: String = ReceiptView.source_text(step, upgrade_names, none)
	assert_bool(EffectChip.fits("+15 · " + long_source, font, size)).is_false()
	assert_str(EffectChip.chip_text(step, none, upgrade_names, none, font, size)).is_equal(
		"+15 · Tip jar"
	)
	# 3. The display name is too long too (Slot engine's ×2 on the belt): its first word, whole.
	step.step_type = ScoreStep.StepType.MULTIPLIER
	step.value = 2
	step.text = ""
	upgrade_names = ["Slot engine"]
	assert_bool(EffectChip.fits("×2 · Slot engine", font, size)).is_false()
	var text: String = EffectChip.chip_text(step, none, upgrade_names, none, font, size)
	assert_str(text).is_equal("×2 · Slot")
	assert_bool(EffectChip.fits(text, font, size)).is_true()


## The count-up's receipt prints exactly add_step's lines for steps[0..k], the newest FLAT line
## marked as the combo line; it reaches the counter, so it ends at the pile's top, scrolled to its
## newest line, and the pile continues its paper from its foot down to the counter line.
func test_the_count_up_receipt_prints_the_steps_so_far() -> void:
	var frame: StyleFrameV2 = await _frame(StyleFrameV2.State.COUNT_UP)
	var result: ScoreResult = frame.result()
	var row: Array[CardInstance] = _row(frame)
	var expected: ReceiptView = ReceiptView.new()
	add_child(expected)
	var expected_lines: Array[Control] = []
	var newest_flat: int = -1
	for index: int in range(frame.frozen_step() + 1):
		var line: Control = expected.add_step(
			result.steps[index],
			StyleFrameFixture.names(row),
			StyleFrameFixture.upgrade_names(),
			StyleFrameFixture.inspection_names()
		)
		if line != null:
			expected_lines.append(line)
			if result.steps[index].step_type == ScoreStep.StepType.FLAT:
				newest_flat = expected_lines.size() - 1
	var shown: Array[Control] = frame.step_lines()
	assert_int(shown.size()).is_equal(expected_lines.size())
	assert_int(shown.size()).is_greater(3)
	var hung: int = 0
	for index: int in range(shown.size()):
		assert_str(_printed_text(shown[index])).is_equal(_printed_text(expected_lines[index]))
		# The amount sits on the line's last row; an indented line hangs past its lead and
		# marker on every row.
		var right: Label = shown[index].get_child(1) as Label
		assert_int(right.vertical_alignment).is_equal(VERTICAL_ALIGNMENT_BOTTOM)
		assert_float(right.size.y).is_equal(shown[index].size.y)
		# add_step hangs the expected line too (ReceiptView.hang_parts()).
		var expected_left: Label = expected_lines[index].get_child(0) as Label
		if not expected_left.has_theme_stylebox_override("normal"):
			continue
		hung += 1
		var left: Label = shown[index].get_child(0) as Label
		assert_bool(left.has_theme_stylebox_override("normal")).is_true()
		var indent: float = left.get_theme_stylebox("normal").content_margin_left
		assert_float(indent).is_greater(0.0)
		var marker: Label = left.get_node_or_null("Marker") as Label
		if marker != null:
			assert_float(marker.position.x + marker.get_minimum_size().x).is_less_equal(indent)
	assert_int(hung).is_greater(1)
	expected.free()
	assert_int(newest_flat).is_greater_equal(0)
	assert_object(frame.combo_line()).is_same(shown[newest_flat])
	var diamond: Control = frame.combo_line().find_child("ComboDiamond", true, false) as Control
	assert_object(diamond).is_not_null()
	var receipt: Rect2 = _rect(frame, frame.receipt())
	# The combo marks sit inside the receipt's visible scroll area (scrolled to its end).
	var scroll: Rect2 = _rect(frame, frame.receipt().get_child(0) as Control)
	assert_bool(scroll.encloses(_rect(frame, diamond))).is_true()
	assert_bool(scroll.encloses(_rect(frame, frame.combo_line()))).is_true()
	var pile: ReceiptPile = frame.pile()
	assert_bool(pile.visible).is_true()
	assert_float(pile.height_px).is_equal(StyleFrameFixture.pile_height(shown.size()))
	var paper: Rect2 = _paper(frame)
	assert_float(paper.end.y).is_equal(StyleFrameV2.PILE_BOTTOM)
	assert_float(paper.position.y).is_equal(receipt.end.y - StyleFrameV2.PILE_JOIN)
	# The top fold continues the receipt's paper; the fan folds stay in the cabinet's span, clear
	# of the purse.
	var top_fold: Rect2 = pile.fold_rect(0)
	assert_float(top_fold.position.x).is_equal(receipt.position.x)
	assert_float(top_fold.size.x).is_equal(receipt.size.x)
	assert_int(pile.fold_count()).is_greater(1)
	for fold: int in range(pile.fold_count()):
		var rect: Rect2 = pile.fold_rect(fold)
		# Fan-folded: odd folds shift left, even folds (after the top one) right.
		var shift: float = 0.0
		if fold > 0:
			shift = -ReceiptPile.FOLD_SHIFT if fold % 2 == 1 else ReceiptPile.FOLD_SHIFT
		assert_float(rect.position.x).is_equal(receipt.position.x + shift)
		assert_float(rect.size.x).is_equal(receipt.size.x)
		assert_float(rect.end.x).is_less_equal(StyleFrameV2.REGISTER_RECT.end.x)
	assert_bool(paper.intersects(_rect(frame, frame.purse()))).is_false()
	assert_bool(frame.checkout_button().disabled).is_true()
	assert_float((frame.stage().get_node("Tray") as Control).modulate.a).is_equal_approx(
		StyleFrameV2.COUNTING_HAND_ALPHA, 0.001
	)


func test_the_planning_stub_counts_the_fizzles() -> void:
	var frame: StyleFrameV2 = await _frame(StyleFrameV2.State.PLANNING)
	var wasted: int = 0
	for step: ScoreStep in frame.result().steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			wasted += 1
	assert_int(wasted).is_greater(1)
	var texts: PackedStringArray = PackedStringArray()
	for line: Node in frame.receipt().find_children("*", "HBoxContainer", true, false):
		texts.append(_line_text(line as Control))
	assert_bool(texts.has(StyleFrameV2.STUB_FIZZLES % wasted + "|")).is_true()
	# A dashed rule (not the TOTAL line's solid one) right above PROJECTED.
	var rule: HSeparator = frame.receipt().find_child("StubRule", true, false) as HSeparator
	assert_object(rule).is_not_null()
	assert_object(rule.get_theme_stylebox("separator")).is_instanceof(StyleBoxEmpty)
	var total_line: Control = rule.get_parent().get_child(rule.get_index() + 1) as Control
	assert_object(total_line.get_child(1)).is_same(frame.stub_total())
	var receipt: Rect2 = _rect(frame, frame.receipt())
	assert_float(receipt.end.y).is_less_equal(StyleFrameV2.STUB_MAX_BOTTOM)
	assert_bool(frame.checkout_button().disabled).is_false()
	# The stub hangs short of the counter, so there is no pile yet.
	for state: StyleFrameV2.State in [
		StyleFrameV2.State.PLANNING, StyleFrameV2.State.SCAN, StyleFrameV2.State.SCAN_BELT
	]:
		var shown: StyleFrameV2 = await _frame(state)
		assert_bool(shown.pile().visible).override_failure_message(str(state)).is_false()
		assert_float(shown.pile().height_px).is_equal(0.0)
		assert_float(_rect(shown, shown.receipt()).end.y).is_less_equal(
			StyleFrameV2.STUB_MAX_BOTTOM
		)
	# The scanner rests in its cradle, in its side look, under the counter line and clear of
	# CHECKOUT.
	frame = await _frame(StyleFrameV2.State.PLANNING)
	var cradle: Rect2 = _rect(frame, frame.stage().get_node("Cradle") as Control)
	var docked: Rect2 = _rect(frame, frame.scanner())
	assert_bool(cradle.encloses(docked)).override_failure_message(str(docked)).is_true()
	assert_float(docked.position.y).is_greater_equal(StyleFrameV2.COUNTER_EDGE.end.y)
	for part: Rect2 in [docked, cradle]:
		assert_bool(part.intersects(_rect(frame, frame.checkout_button()))).is_false()
	var expected: Rect2 = Rect2(
		StyleFrameV2.CRADLE_RECT.position + StyleFrameV2.DOCKED_OFFSET, StyleFrameV2.DOCKED_SIZE
	)
	assert_bool(docked == expected).override_failure_message(str(docked)).is_true()
	assert_object(frame.scanner().texture).is_same(StyleFrameV2.SCANNER)
	assert_object(frame.popup()).is_null()


## A hand item's popup (round 3) opens beside it over the tray, never over the belt: every belt
## item's sprite, sticker, plaque and chips stay in view while a hand item is read.
func test_the_scan_popup_points_at_the_hovered_item() -> void:
	var frame: StyleFrameV2 = await _frame(StyleFrameV2.State.SCAN)
	var view: ItemView = frame.item_view(false, StyleFrameV2.SCAN_HAND_INDEX)
	var popup: ScanPopup = frame.popup()
	assert_bool(view.is_lifted()).is_true()
	var rect: Rect2 = _rect(frame, popup)
	assert_bool(STAGE.encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_float(rect.position.y).is_greater_equal(StyleFrameV2.COUNTER_TOP)
	assert_bool(rect.intersects(StyleFrameV2.BELT_RECT)).is_false()
	assert_float(rect.position.x).is_greater_equal(StyleFrameV2.TRAY_RECT.position.x)
	assert_float(rect.end.x).is_less_equal(StyleFrameV2.TRAY_RECT.end.x)
	for belt_view: ItemView in frame.item_views(true):
		var covered: Array[Control] = [belt_view.sprite(), belt_view.sticker()]
		covered.append_array(belt_view.chips())
		for part: Control in covered:
			assert_bool(rect.intersects(_rect(frame, part))).is_false()
	# On the item's right (it fits over the tray), level with the lifted sprite, clear of the
	# item's own sprite and sticker; the side tail spans the gap at the sprite's middle and
	# points at the item.
	assert_int(popup.placement).is_equal(ScanPopup.Placement.RIGHT)
	var sticker: Rect2 = _rect(frame, view.sticker())
	var sprite: Rect2 = _rect(frame, view.sprite())
	assert_float(rect.position.y).is_equal(sprite.position.y)
	assert_float(rect.position.x).is_equal(maxf(sprite.end.x, sticker.end.x) + ScanPopup.SIDE_GAP)
	var tail: Rect2 = _rect(frame, popup.tail())
	assert_object(popup.tail().texture).is_same(ScanPopup.TAIL_SIDE)
	for part: Rect2 in [sprite, sticker]:
		assert_bool(rect.intersects(part)).is_false()
		assert_bool(tail.intersects(part)).is_false()
	assert_float(tail.get_center().y).is_equal(sprite.get_center().y)
	assert_float(popup.tail_tip().x).is_equal(maxf(sprite.end.x, sticker.end.x))
	assert_float(popup.tail_tip().y).is_equal(sprite.get_center().y)
	assert_str(popup.rule_label().text).is_equal(view.card.definition.rule_text)
	assert_str(popup.name_label().text).is_equal(view.card.definition.display_name)
	assert_array(popup.footer_texts()).is_empty()
	_assert_popup_holds_its_text(frame, popup)
	_assert_scanner_posed(frame, view)


func test_a_hovered_belt_item_flips_its_popup_and_lists_its_fizzles() -> void:
	var frame: StyleFrameV2 = await _frame(StyleFrameV2.State.SCAN_BELT)
	var view: ItemView = frame.item_view(true, StyleFrameV2.SCAN_BELT_INDEX)
	var popup: ScanPopup = frame.popup()
	assert_int(popup.placement).is_equal(ScanPopup.Placement.BELOW)
	assert_object(popup.tail().texture).is_same(ScanPopup.TAIL)
	var rect: Rect2 = _rect(frame, popup)
	assert_bool(STAGE.encloses(rect)).override_failure_message(str(rect)).is_true()
	# It opens below the cell's chips, so it never covers what its footer lists.
	var chips: Array[EffectChip] = view.chips()
	assert_int(chips.size()).is_equal(2)
	var last_chip: Rect2 = _rect(frame, chips[1])
	assert_float(rect.position.y).is_equal(last_chip.end.y + ScanPopup.FLIP_GAP)
	assert_float(rect.position.y).is_equal(318.0)
	for chip: EffectChip in chips:
		assert_bool(rect.intersects(_rect(frame, chip))).is_false()
	var sprite: Rect2 = _rect(frame, view.sprite())
	assert_float(_rect(frame, popup.tail()).get_center().x).is_equal(sprite.get_center().x)
	var footer: PackedStringArray = popup.footer_texts()
	assert_str(footer[0]).is_equal(
		"Pays €%d" % frame.result().payouts[StyleFrameV2.SCAN_BELT_INDEX]
	)
	var fizzles: int = 0
	for index: int in EffectChip.step_indices(frame.result(), StyleFrameV2.SCAN_BELT_INDEX):
		var step: ScoreStep = frame.result().steps[index]
		if step.step_type == ScoreStep.StepType.WASTED:
			fizzles += 1
			var line: String = EffectChip.full_line(
				step, StyleFrameFixture.upgrade_names(), StyleFrameFixture.inspection_names()
			)
			assert_bool(footer.has(line)).override_failure_message(str(footer)).is_true()
	assert_int(fizzles).is_equal(2)
	_assert_popup_holds_its_text(frame, popup)
	_assert_scanner_posed(frame, view)


## The count-up's current item (Batteries) has the gold brackets and the posed scanner, clear of
## everything around it.
func test_the_count_up_scanner_marks_the_current_item() -> void:
	var frame: StyleFrameV2 = await _frame(StyleFrameV2.State.COUNT_UP)
	var view: ItemView = frame.item_view(true, StyleFrameFixture.COUNT_UP_SLOT)
	assert_bool(view.is_lifted()).is_true()
	assert_object(frame.popup()).is_null()
	_assert_scanner_posed(frame, view)
	var sprite: Rect2 = _rect(frame, view.sprite())
	assert_bool(frame.overlay().brackets() == sprite.grow(ScanOverlay.BRACKET_OUTSET)).is_true()


## Wherever any of the 12 cards is hovered (each hand position and each belt cell), its popup
## stays in the stage, under the top bar and off the item's sprite and sticker (and chips, on the
## belt); a hand item's opens beside it, off the belt (at or below the counter line).
func test_the_popup_keeps_every_card_in_the_stage() -> void:
	var frame: StyleFrameV2 = await _frame(StyleFrameV2.State.PLANNING)
	var popup: ScanPopup = ScanPopup.new()
	frame.stage().add_child(popup)
	var balance: BalanceDefinition = StyleFrameFixture.BALANCE
	for card_id: String in StyleFrameFixture.card_ids():
		var definition: CardDefinition = StyleFrameFixture.card(card_id)
		var aisle: AisleDefinition = balance.aisle_of(definition)
		var fizzles: Array[bool] = [true, true]
		for on_belt: bool in [false, true]:
			var footer: PackedStringArray = PackedStringArray()
			if on_belt:
				footer = ["Coupon engine: a long reason that needs a second line", "Multipack ×3"]
			popup.show_card(definition, aisle, 0 if on_belt else -1, footer, fizzles)
			await get_tree().process_frame
			_assert_popup_holds_its_text(frame, popup)
			for index: int in range(7 if on_belt else 8):
				var sprite: Rect2
				var below: Rect2
				if on_belt:
					var x: float = StyleFrameV2.CELL_ORIGIN.x + index * StyleFrameV2.CELL_PITCH
					sprite = Rect2(x + 12, 98, 96, 96)
					below = Rect2(x + 2, 206, 116, 108)
				else:
					var x: float = StyleFrameV2.TRAY_CELL_ORIGIN.x + index * StyleFrameV2.TRAY_PITCH
					sprite = Rect2(x + 6, 416, 96, 96)
					below = Rect2(x, 520, 108, 64)
				var rect: Rect2 = ScanPopup.place(sprite, below, popup.size, STAGE, on_belt)
				var message: String = "%s at %d: %s" % [card_id, index, rect]
				popup.place_at(sprite, below, STAGE, on_belt)
				assert_bool(Rect2(popup.position, popup.size) == rect).is_true()
				assert_bool(STAGE.encloses(rect)).override_failure_message(message).is_true()
				assert_float(rect.position.y).override_failure_message(message).is_greater_equal(
					StyleFrameV2.TOP_BAR_BOTTOM
				)
				assert_bool(rect.intersects(below)).override_failure_message(message).is_false()
				assert_bool(rect.intersects(sprite)).override_failure_message(message).is_false()
				var placement: ScanPopup.Placement = ScanPopup.placement_of(rect, sprite)
				if on_belt:
					assert_int(placement).override_failure_message(message).is_equal(
						ScanPopup.Placement.BELOW
					)
					continue
				# On the right while it fits over the tray (hand slots 1 to 5), else on the left,
				# its side tail spanning the gap and its tip at the column's edge, level with the
				# sprite's middle.
				var expected: ScanPopup.Placement = (
					ScanPopup.Placement.RIGHT if index < 5 else ScanPopup.Placement.LEFT
				)
				assert_int(placement).override_failure_message(message).is_equal(expected)
				assert_int(popup.placement).override_failure_message(message).is_equal(expected)
				var column: Rect2 = sprite.merge(below)
				var tip_x: float = (
					column.end.x if expected == ScanPopup.Placement.RIGHT else column.position.x
				)
				(
					assert_bool(popup.tail_tip() == Vector2(tip_x, sprite.get_center().y))
					. override_failure_message("%s tip %s" % [message, popup.tail_tip()])
					. is_true()
				)
				var tail: Rect2 = Rect2(popup.position + popup.tail().position, popup.tail().size)
				assert_bool(tail.intersects(sprite)).override_failure_message(message).is_false()
				assert_bool(tail.intersects(below)).override_failure_message(message).is_false()
				assert_bool(popup.tail().flip_h).is_equal(expected == ScanPopup.Placement.LEFT)
				assert_float(rect.position.y).override_failure_message(message).is_greater_equal(
					StyleFrameV2.COUNTER_TOP
				)
				(
					assert_bool(rect.intersects(StyleFrameV2.BELT_RECT))
					. override_failure_message(message)
					. is_false()
				)
				# Across the tray's width (it may hang below the tray's foot).
				var tray: Rect2 = StyleFrameV2.TRAY_RECT
				assert_float(rect.position.x).override_failure_message(message).is_greater_equal(
					tray.position.x
				)
				assert_float(rect.end.x).override_failure_message(message).is_less_equal(tray.end.x)


func test_every_printed_character_has_its_glyph() -> void:
	var checked: int = 0
	var printed: PackedStringArray = PackedStringArray()
	for state: StyleFrameV2.State in STATES:
		var frame: StyleFrameV2 = await _frame(state)
		for label: Node in _labels(frame.stage()):
			var text: Label = label as Label
			printed.append(text.text)
			var font: Font = text.get_theme_font("font")
			for character: String in text.text:
				if character.strip_edges().is_empty():
					continue
				checked += 1
				var code: int = character.unicode_at(0)
				(
					assert_bool(font.has_char(code))
					. override_failure_message(
						"%s lacks '%s' (U+%04X) in %s" % [font, character, code, text.get_path()]
					)
					. is_true()
				)
	assert_int(checked).is_greater(800)
	var caption: String = StyleFrameFixture.inspections()[0].display_name
	for required: String in ["CLOSED", "TOTAL", "COUPON", caption, "5", "6"]:
		assert_bool(printed.has(required)).override_failure_message(required).is_true()


## No text goes through the sharp-pixel material, and the S key's switch reaches every piece of
## art.
func test_text_never_carries_the_pixel_material() -> void:
	var frame: StyleFrameV2 = await _frame(StyleFrameV2.State.SCAN)
	for label: Node in _labels(frame.stage()):
		(
			assert_object((label as Label).material)
			. override_failure_message(str(label.get_path()))
			. is_null()
		)
	# ArtStyle.set_sharp walks the plain children (as on the shift screen), so the A/B switch
	# reaches every piece of art that isn't a FramedButton's internal face.
	var marked: Array[CanvasItem] = _pixel_art(frame.stage())
	assert_int(marked.size()).is_greater(40)
	ArtStyle.set_sharp(frame, false)
	for node: CanvasItem in marked:
		assert_object(node.material).is_null()
	ArtStyle.set_sharp(frame, true)


## The scene's colours are art/src/palette.txt's, the belt's treads and the pile's crease too.
func test_the_scene_colours_are_the_palettes() -> void:
	var palette: Dictionary[String, Color] = {}
	var file: FileAccess = FileAccess.open(PALETTE_FILE, FileAccess.READ)
	assert_object(file).is_not_null()
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with(";"):
			continue
		var parts: PackedStringArray = line.split(" ", false)
		if parts.size() >= 2 and parts[1].is_valid_html_color():
			palette[parts[0]] = Color(parts[1])
	assert_int(palette.size()).is_equal(40)
	for key: String in StyleFrameV2.PALETTE:
		assert_bool(palette.has(key)).override_failure_message(key).is_true()
		(
			assert_str(Color(StyleFrameV2.PALETTE[key]).to_html(false))
			. override_failure_message(key)
			. is_equal(palette[key].to_html(false))
		)
	# Code-drawn: the treads (%, :, -), the rollers' rings (k), the strings (#), the muted
	# plaque (b, l), the pile's paper, crease and caps.
	var drawn: Dictionary[String, Color] = {
		"k": StyleFrameV2.BRASS_DARKEST,
		"b": StyleFrameV2.CREAM_SHADE,
		"l": StyleFrameV2.BRASS_DARK,
		"%": StyleFrameV2.INK_LIGHT,
		":": StyleFrameV2.GREY_LIGHT,
		"-": StyleFrameV2.GREY,
		"#": StyleFrameV2.INK,
		"w": PaperPile.PAPER,
	}
	for key: String in drawn:
		assert_str(drawn[key].to_html(false)).override_failure_message(key).is_equal(
			palette[key].to_html(false)
		)
	assert_str(PaperPile.FOLD.to_html(false)).is_equal(palette[":"].to_html(false))
	assert_str(PaperPile.EDGE.to_html(false)).is_equal(palette["#"].to_html(false))


# --- Helpers ---------------------------------------------------------------------------------


func _frame(state: StyleFrameV2.State) -> StyleFrameV2:
	var runner: GdUnitSceneRunner = scene_runner(SCENE)
	var frame: StyleFrameV2 = runner.scene() as StyleFrameV2
	frame.show_state(state)
	for _index: int in range(3):
		await get_tree().process_frame
	return frame


## `control`'s rect in stage coordinates.
static func _rect(frame: StyleFrameV2, control: Control) -> Rect2:
	var origin: Vector2 = frame.stage().get_global_rect().position
	var rect: Rect2 = control.get_global_rect()
	return Rect2(rect.position - origin, rect.size)


func _assert_apart(rects: Array[Rect2], what: String) -> void:
	for first: int in range(rects.size()):
		for second: int in range(first + 1, rects.size()):
			(
				assert_bool(rects[first].intersects(rects[second]))
				. override_failure_message(
					"%s overlap: %s %s" % [what, rects[first], rects[second]]
				)
				. is_false()
			)


func _assert_popup_holds_its_text(frame: StyleFrameV2, popup: ScanPopup) -> void:
	var rect: Rect2 = _rect(frame, popup)
	for label: Label in popup.text_labels():
		var inner: Rect2 = _rect(frame, label)
		(
			assert_bool(rect.encloses(inner))
			. override_failure_message("'%s' %s outside %s" % [label.text, inner, rect])
			. is_true()
		)
	assert_float(popup.size.y).is_between(ScanPopup.MIN_HEIGHT, ScanPopup.MAX_HEIGHT)


## The scanner in its posed look overhead beside `view`'s lifted sprite (on its left, flipped, when
## the popup opens on its right), clear of every sprite, sticker, plaque and chip, of the popup and
## its tail, and of the strip's texts and buttons.
func _assert_scanner_posed(frame: StyleFrameV2, view: ItemView) -> void:
	var sprite: Rect2 = _rect(frame, view.sprite())
	var scanner: Rect2 = _rect(frame, frame.scanner())
	var on_left: bool = (
		frame.popup() != null and frame.popup().placement == ScanPopup.Placement.RIGHT
	)
	var expected: Rect2 = ScanOverlay.scanner_rect(sprite, on_left)
	assert_float(expected.end.y).is_equal(sprite.position.y)
	assert_float(expected.size.x).is_equal(ScanOverlay.SCANNER_SIZE.x)
	var tucked: float = (
		expected.end.x - sprite.position.x if on_left else sprite.end.x - expected.position.x
	)
	assert_float(tucked).is_equal(ScanOverlay.SCANNER_TUCK)
	assert_bool(scanner == expected).override_failure_message(str(scanner)).is_true()
	assert_object(frame.scanner().texture).is_same(ScanOverlay.SCANNER_AIM)
	assert_bool(frame.scanner().flip_h).is_equal(on_left)
	# Under the strip over a hand item, and clear of the strip's texts and buttons.
	var others: Array[Control] = []
	for part: String in ["Capacity", "Cue", "Notice", "Redraw", "Checkout", "Cradle"]:
		others.append(frame.stage().get_node(part) as Control)
	for other: ItemView in frame.item_views(true) + frame.item_views(false):
		others.append(other.sprite())
		others.append(other.sticker())
		if other.plaque() != null:
			others.append(other.plaque())
		for chip: EffectChip in other.chips():
			others.append(chip)
	if frame.popup() != null:
		others.append(frame.popup())
		others.append(frame.popup().tail())
	for other: Control in others:
		(
			assert_bool(scanner.intersects(_rect(frame, other)))
			. override_failure_message("%s over %s" % [scanner, other.get_path()])
			. is_false()
		)


## The pile's paper in stage coordinates.
func _paper(frame: StyleFrameV2) -> Rect2:
	var paper: Rect2 = frame.pile().paper_rect()
	paper.position -= frame.stage().get_global_rect().position
	return paper


## The belt's row, from its items.
static func _row(frame: StyleFrameV2) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for view: ItemView in frame.item_views(true):
		row.append(view.card)
	return row


## A receipt line's text: "left|right".
static func _line_text(line: Control) -> String:
	return "%s|%s" % [(line.get_child(0) as Label).text, (line.get_child(1) as Label).text]


## A hung step line's printed text, "marker rest|right" (its leading spaces are now the indent).
static func _printed_text(line: Control) -> String:
	var left: Label = line.get_child(0) as Label
	var marker: Label = left.get_node_or_null("Marker") as Label
	var text: String = left.text if marker == null else "%s %s" % [marker.text, left.text]
	return "%s|%s" % [text, (line.get_child(1) as Label).text]


## Every visible control under `node` with a size, internal children included.
static func _controls(node: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in node.get_children(true):
		var control: Control = child as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control.size.x > 0.0 and control.size.y > 0.0:
			found.append(control)
		found.append_array(_controls(control))
	return found


## Every visible label with text under `node`, internal children included.
static func _labels(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	for control: Control in _controls(node):
		var label: Label = control as Label
		if label != null and not label.text.is_empty():
			found.append(label)
	return found


static func _pixel_art(node: Node) -> Array[CanvasItem]:
	var found: Array[CanvasItem] = []
	var item: CanvasItem = node as CanvasItem
	if item != null and item.has_meta(ArtStyle.PIXEL_ART_META):
		found.append(item)
	for child: Node in node.get_children():
		found.append_array(_pixel_art(child))
	return found
