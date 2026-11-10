extends GdUnitTestSuite
## The stuck price label (price leak, the user's pick of 2026-11-10: variant C of mock-up
## price_leak.html, yellow paper, a cap of 11 art px): a price whose 6x8 digits fit the window
## prints there as before; a wider one prints in the same digits on a label that leaks past the
## ticket's right edge and its top, never to the left, by at most the tuning's cap; past the cap
## "Nk€" in 6x8, then the 4x7 digits on a label. On screen: the label's rect and leak for the
## boundary amounts in both windows, its inks' contrast on the yellow, its dimming, its tip's
## area, and on the belt the layer that draws it over the next cell (once, following its ticket
## in the same frame, a neighbour's sparkle under it), and in the handbook's example row.

const CARDS := "res://data/cards"
const BIG := PixelWords.Sheet.DIGITS
const SMALL := PixelWords.Sheet.SMALL_DIGITS
const NORMAL := 28
const NARROW := 18
## The least an ink contrasts with the label's paper: about 3:1 (the lowered grey, a quiet ink by
## design, is 2.99:1 on the yellow).
const MIN_CONTRAST := 2.95
## The mock-up's yellow (price_leak.html?paper=yellow), and how far a channel may be from it.
const MOCKUP_YELLOW := Color("f6e3a1")
const YELLOW_TOLERANCE := 0.01


## The ladder (PriceLabel.print_for) at the cap of data/balance/planning.tres, in both windows:
## the widest prices that fit, the first that leak, the cap exactly reached, the first past it.
func test_the_ladder_leaks_within_the_cap() -> void:
	assert_int(PriceLabel.cap()).is_equal(11)
	assert_int(NORMAL).is_equal(TicketFace.WINDOW.size.x)
	assert_int(NARROW).is_equal(TicketFace.WINDOW_WIDE.size.x)
	var normal: Dictionary[int, Array] = {
		1: ["1€", BIG, 0],
		87: ["87€", BIG, 0],
		# The widest three-digit price fits exactly; so does a four-digit one of narrow digits.
		999: ["999€", BIG, 0],
		1111: ["1111€", BIG, 0],
		# The first that leaks, then the widest four-digit price.
		1112: ["1112€", BIG, 2],
		1250: ["1250€", BIG, 6],
		9999: ["9999€", BIG, 8],
		# The cap exactly reached, and the first past it: "Nk€" back in the window.
		11222: ["11222€", BIG, 11],
		12222: ["12k€", BIG, 0],
		12400: ["12k€", BIG, 0],
		99999: ["99k€", BIG, 0],
		# "Nk€" too wide for the window: on a label, still in 6x8.
		124000: ["124k€", BIG, 6],
		999999: ["999k€", BIG, 8],
	}
	for amount: int in normal:
		var message: String = "%d€ in the window" % amount
		(
			assert_array(PriceLabel.print_for(amount, NORMAL))
			. override_failure_message(message)
			. is_equal(normal[amount])
		)
	var narrow: Dictionary[int, Array] = {
		1: ["1€", BIG, 0],
		11: ["11€", BIG, 0],
		# The first that leaks beside three icons.
		21: ["21€", BIG, 2],
		87: ["87€", BIG, 4],
		# Every three-digit price fits the cap in 6x8 (the user's reason for a cap of 11).
		111: ["111€", BIG, 5],
		250: ["250€", BIG, 11],
		999: ["999€", BIG, 11],
		# Past the cap: "1k€" in 6x8, on a small label.
		1250: ["1k€", BIG, 2],
		9999: ["9k€", BIG, 4],
		12400: ["12k€", BIG, 9],
	}
	for amount: int in narrow:
		var message: String = "%d€ beside three icons" % amount
		(
			assert_array(PriceLabel.print_for(amount, NARROW))
			. override_failure_message(message)
			. is_equal(narrow[amount])
		)
	# One under the cap a price needs: the 4x7 digits, on a label.
	assert_array(PriceLabel.print_for(250, NARROW, 10)).is_equal(["250€", SMALL, 3])
	assert_array(PriceLabel.print_for(9999, NORMAL, 7)).is_equal(["9k€", BIG, 0])
	# Nothing fits: the last form on a label past the cap, never digits without paper.
	var last: Array = PriceLabel.print_for(88888888, NARROW, 0)
	assert_str(last[0]).is_equal("88888k€")
	assert_int(last[1]).is_equal(SMALL)
	assert_int(last[2]).is_greater(0)
	# Every price to 9999€ in the full window: in 6x8, in the window or within the cap.
	var problems: PackedStringArray = PackedStringArray()
	for amount: int in range(1, 10000):
		var form: Array = PriceLabel.print_for(amount, NORMAL)
		var digits: int = PixelWords.font_size_of(form[0], form[1]).x
		var fits: bool = digits <= PriceWindow.DIGITS_RIGHT - PriceWindow.DIGITS_LEFT + 1
		if form[0] != "%d€" % amount or form[1] != BIG or (form[2] == 0) != fits:
			problems.append("%d€: %s" % [amount, form])
		var needed: int = 0 if fits else PriceLabel.leak_for(digits, NORMAL)
		if form[2] > PriceLabel.cap() or form[2] != needed:
			problems.append("%d€ leaks %d" % [amount, form[2]])
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## On a ticket: a price that fits shows no label; a wider one's label starts at the window's left
## edge (never left of it), two art px higher than the window with its outline over it, ends its
## leak past the ticket's right edge, and holds the digits (6x8, one art px in) and their shadow.
func test_the_label_sticks_over_the_corner_and_leaks_right() -> void:
	var px: float = ArtStyle.ART_SCALE
	var milk: PriceSticker = auto_free(PriceSticker.new(_card("milk_golden")))
	add_child(milk)
	var window: PriceWindow = milk.window()
	var label: PriceLabel = window.label()
	assert_int(label.get_index()).is_equal(0)
	for amount: int in [1, 999, 1111]:
		milk.set_pay(PlanningModel.Pay.BOOSTED, amount)
		assert_bool(label.visible).override_failure_message(str(amount)).is_false()
		assert_int(label.leak()).is_equal(0)
		assert_bool(Rect2(Vector2.ZERO, window.size).encloses(window.digits_rect())).is_true()
		assert_int(window.digits().sheet).is_equal(BIG)
		assert_that(window.hover_rect()).is_equal(window.get_global_rect())
	var leaks: Dictionary[int, int] = {1112: 2, 1250: 6, 9999: 8, 11222: 11, 124000: 6}
	for amount: int in leaks:
		milk.set_pay(PlanningModel.Pay.BOOSTED, amount)
		_assert_label(milk, leaks[amount], "%d€" % amount)
	# Past the cap the short form is back in the window, the label gone.
	milk.set_pay(PlanningModel.Pay.BOOSTED, 12222)
	assert_bool(label.visible).is_false()
	assert_str(window.digits().text).is_equal("12k€")
	# Beside three icons the window is narrower and the label starts at its new left edge.
	milk.show_gained("Household")
	await get_tree().process_frame
	assert_bool(milk.is_wide()).is_true()
	var narrow: Dictionary[int, int] = {21: 2, 250: 11, 999: 11}
	for amount: int in narrow:
		milk.set_pay(PlanningModel.Pay.BOOSTED, amount)
		_assert_label(milk, narrow[amount], "%d€ beside three icons" % amount)
		assert_str(window.digits().text).is_equal("%d€" % amount)
		# The label never covers the gained glyph left of it.
		var rim: Rect2 = milk.gained().rim_rect()
		var shown: Rect2 = Rect2(window.position + label.position, label.size)
		assert_bool(rim.intersects(shown)).is_false()
	milk.set_pay(PlanningModel.Pay.BOOSTED, 1250)
	assert_str(window.digits().text).is_equal("1k€")
	_assert_label(milk, 2, "1k€")
	# A coupon keeps its scissors and has no label; the printed price is back with clear_pay.
	milk.clear_pay()
	assert_bool(label.visible).is_false()
	var coupon: PriceSticker = auto_free(PriceSticker.new(_card("multipack")))
	add_child(coupon)
	for pay: PlanningModel.Pay in [PlanningModel.Pay.PLAIN, PlanningModel.Pay.ZERO]:
		coupon.set_pay(pay, 0)
		assert_bool(coupon.window().label().visible).is_false()
		assert_bool(coupon.window().digits().visible).is_false()
	assert_float(label.size.y).is_equal((PriceWindow.ART.y + 3) * px)


## The label's rect, leak and digits on `sticker` (leaking `leak` art px).
func _assert_label(sticker: PriceSticker, leak: int, message: String) -> void:
	var px: float = ArtStyle.ART_SCALE
	var window: PriceWindow = sticker.window()
	var label: PriceLabel = window.label()
	assert_bool(label.visible).override_failure_message(message).is_true()
	assert_int(label.leak()).override_failure_message(message).is_equal(leak)
	var ticket: Rect2 = sticker.get_global_rect()
	var box: Rect2 = window.get_global_rect()
	var shown: Rect2 = label.get_global_rect()
	# Never left of the window; up by the label's rise and its outline; down to the window's foot.
	assert_float(shown.position.x).override_failure_message(message).is_equal(box.position.x)
	assert_float(shown.position.y).is_equal(box.position.y - (PriceLabel.UP + 1) * px)
	assert_float(shown.end.y).is_equal(box.end.y)
	assert_float(shown.position.y).is_less(ticket.position.y)
	# Past the ticket's right edge by its leak, within the cap.
	assert_float(shown.end.x).override_failure_message(message).is_equal(ticket.end.x + leak * px)
	assert_int(leak).is_less_equal(PriceLabel.cap())
	# The digits: 6x8, one art px from the label's left, their shadow's column on the paper.
	var digits: Rect2 = window.digits().get_global_rect()
	assert_int(window.digits().sheet).override_failure_message(message).is_equal(BIG)
	assert_float(digits.position.x).is_equal(box.position.x + PriceLabel.DIGITS_LEFT * px)
	assert_bool(shown.encloses(digits)).override_failure_message(message).is_true()
	assert_float(digits.end.x + PriceLabel.TAIL * px).is_equal(shown.end.x)
	var rows: Array[Vector3i] = PriceLabel.paper_rows(roundi(window.size.x / px), leak)
	assert_int(rows.size()).is_equal(PriceWindow.ART.y)
	var top: float = box.position.y + rows[0].x * px
	assert_float(digits.position.y).is_greater_equal(top)
	assert_float(digits.end.y + px).is_less_equal(box.position.y + (rows[-1].x + 1) * px)
	for run: Vector3i in rows:
		# Each paper row holds the digits and their shadow; a tooth row reaches one px further.
		assert_int(run.y).is_equal(0)
		var paper_end: float = box.position.x + (run.z + 1) * px
		assert_float(paper_end).is_greater_equal(digits.end.x + px)
		assert_float(paper_end).is_less(shown.end.x)
	assert_int(rows[1].z).is_equal(rows[0].z + 1)
	assert_int(rows[2].z).is_equal(rows[0].z + 1)
	assert_int(rows[3].z).is_equal(rows[0].z)
	# The tip shows anywhere on the window and the label.
	assert_that(window.hover_rect()).is_equal(box.merge(shown))


## The yellow is a mix of two shades of the palette's mustard ramp, the mock-up's yellow to the
## eye, that is no gold and no ticket paper; every digit ink reads on it (about 3:1 or more), the
## two semi strong steps one shade darker than in the window, each on a darker shadow.
func test_every_ink_reads_on_the_yellow_label() -> void:
	var paper: Color = PriceLabel.yellow()
	assert_that(PriceLabel.PAPER_FROM).is_equal(Palette.MUSTARD_LIGHT)
	assert_that(PriceLabel.PAPER_TO).is_equal(Palette.MUSTARD_PALE)
	var mixed: Color = Palette.MUSTARD_LIGHT.lerp(Palette.MUSTARD_PALE, PriceLabel.PAPER_MIX)
	assert_that(paper).is_equal(mixed)
	for channel: int in 3:
		assert_float(paper[channel]).is_equal_approx(MOCKUP_YELLOW[channel], YELLOW_TOLERANCE)
	# Paler than every gold of the GOLDEN ring, yellower than the ticket's papers (their blue
	# channel is the one that tells cream from yellow).
	for gold: Color in [Palette.GOLD, Palette.MUSTARD, Palette.MUSTARD_LIGHT, Palette.BRASS]:
		assert_float(paper.b).is_greater(gold.b + 0.1)
	for ticket_paper: Color in [PriceWindow.FILL, Palette.CREAM, Palette.MUSTARD_PALE]:
		assert_float(paper.b).is_less(ticket_paper.b - 0.1)
	var printed: Color = PriceWindow.digit_color(PriceWindow.State.PRINTED, 1, true)
	var lowered: Color = PriceWindow.digit_color(PriceWindow.State.LOWERED, 1, true)
	assert_that(printed).is_equal(Palette.INK)
	assert_that(lowered).is_equal(PriceWindow.NEGATIVE_INK)
	assert_float(_contrast(printed, paper)).is_greater_equal(MIN_CONTRAST)
	assert_float(_contrast(lowered, paper)).is_greater_equal(MIN_CONTRAST)
	assert_int(PriceLabel.BOOST_INKS.size()).is_equal(PriceWindow.BOOST_INKS.size())
	var seen: Array[Color] = [printed, lowered]
	for step: int in range(1, PriceLabel.BOOST_INKS.size() + 1):
		var ink: Color = PriceWindow.digit_color(PriceWindow.State.BOOSTED, step, true)
		var shadow: Color = PriceWindow.shadow_color(PriceWindow.State.BOOSTED, step, true)
		var message: String = "step %d" % step
		assert_that(ink).is_equal(PriceLabel.BOOST_INKS[step - 1][0])
		assert_float(_contrast(ink, paper)).override_failure_message(message).is_greater_equal(
			MIN_CONTRAST
		)
		assert_float(_contrast(shadow, paper)).is_greater(_contrast(ink, paper))
		assert_bool(seen.has(ink)).override_failure_message(message).is_false()
		seen.append(ink)
		# The window's own ink where it reads on the yellow, else a darker one.
		var plain: Color = PriceWindow.digit_color(PriceWindow.State.BOOSTED, step)
		if _contrast(plain, paper) >= MIN_CONTRAST:
			assert_that(ink).is_equal(plain)
		else:
			assert_float(_contrast(ink, paper)).is_greater(_contrast(plain, paper))
	# On a ticket: the label's digits wear the label's inks, the window's digits the window's.
	var milk: PriceSticker = auto_free(PriceSticker.new(_card("milk")))
	add_child(milk)
	var base: int = _card("milk").base
	milk.set_pay(PlanningModel.Pay.BOOSTED, 1250)
	var window: PriceWindow = milk.window()
	assert_int(window.boost_level()).is_equal(PriceWindow.STRONG_STEP)
	assert_that(window.digits().color).is_equal(PriceLabel.BOOST_INKS[-1][0])
	assert_bool(window.shadow().visible).is_true()
	var offset: Vector2 = Vector2(PriceWindow.SHADOW_OFFSET) * ArtStyle.ART_SCALE
	assert_vector(window.shadow().position).is_equal(window.digits().position + offset)
	window.show_pay(PriceWindow.State.BOOSTED, 1250, 1249)
	assert_that(window.digits().color).is_equal(Palette.MUSTARD_DARKEST)
	assert_that(window.shadow().color).is_equal(Palette.BRASS_DARKEST)
	milk.set_pay(PlanningModel.Pay.BOOSTED, base + 1)
	assert_that(window.digits().color).is_equal(PriceWindow.BOOST_INKS[0][0])
	# The label's paper greys with its item (ItemView's mix grey), back to yellow after.
	var label: PriceLabel = window.label()
	assert_that(label.paper()).is_equal(paper)
	label.grey = 1.0
	var grey: Color = label.paper()
	assert_float(grey.r).is_equal_approx(grey.b, 0.001)
	label.grey = 0.0
	assert_that(label.paper()).is_equal(paper)


## Dimmed, a window fades whole over its ticket's paper; with a label only the digits fade, the
## label's paper kept (the belt lies under its leak), and the state follows the price.
func test_a_dimmed_label_keeps_its_paper() -> void:
	var milk: PriceSticker = auto_free(PriceSticker.new(_card("milk")))
	add_child(milk)
	var window: PriceWindow = milk.window()
	window.dimmed_alpha = 0.45
	milk.set_pay(PlanningModel.Pay.BOOSTED, 18)
	window.set_dimmed(true)
	assert_bool(window.is_dimmed()).is_true()
	assert_float(window.modulate.a).is_equal_approx(0.45, 0.001)
	assert_float(window.digits().modulate.a).is_equal(1.0)
	milk.set_pay(PlanningModel.Pay.BOOSTED, 1250)
	assert_bool(window.label().visible).is_true()
	assert_float(window.modulate.a).is_equal(1.0)
	assert_float(window.label().modulate.a).is_equal(1.0)
	assert_float(window.digits().modulate.a).is_equal_approx(0.45, 0.001)
	assert_float(window.shadow().modulate.a).is_equal_approx(0.45, 0.001)
	assert_bool(window.is_shown()).is_true()
	window.set_dimmed(false)
	assert_float(window.digits().modulate.a).is_equal(1.0)
	window.set_dimmed(true)
	milk.set_pay(PlanningModel.Pay.BOOSTED, 18)
	assert_float(window.modulate.a).is_equal_approx(0.45, 0.001)
	assert_float(window.digits().modulate.a).is_equal(1.0)
	milk.clear_pay()
	assert_float(window.modulate.a).is_equal(1.0)
	# An item's mix grey reaches its label's paper.
	var card: CardInstance = CardInstance.new(_card("milk"), 1)
	var item: ItemView = auto_free(ItemView.new(card, null, ItemView.Form.BELT))
	add_child(item)
	item.sticker().set_pay(PlanningModel.Pay.BOOSTED, 9999)
	item.dim_greyness = Vector2(0.78, 0.2)
	item.relation = ItemView.Relation.DIM
	assert_float(item.sticker().window().label().grey).is_equal_approx(0.8, 0.001)
	item.relation = ItemView.Relation.NONE
	assert_float(item.sticker().window().label().grey).is_equal(0.0)


## On the belt (8 slots, the tightest gaps with tickets): a label reaches over the next cell, and
## the row's label layer, after its cells, draws it there: over the next cell's ticket, at the
## window's place and scale, in its item's tint. The layer is what covers the label for its tip.
func test_the_row_draws_its_labels_over_the_next_cell() -> void:
	var strip: RowStrip = auto_free(RowStrip.new())
	add_child(strip)
	strip.set_slot_count(8)
	var row: Array[CardInstance] = []
	for slot: int in range(3):
		row.append(CardInstance.new(_card("milk_golden"), slot + 1))
	var views: Array[CardView] = strip.show_cards(row, -1, func(_view: CardView) -> void: pass)
	await get_tree().process_frame
	var layer: PriceLabelLayer = strip.labels
	assert_int(layer.get_index()).is_greater(strip.box.get_index())
	assert_int(layer.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_array(layer.labelled()).is_empty()
	assert_array(layer.drawn_rects()).is_empty()
	var first: ItemView = views[0] as ItemView
	var second: ItemView = views[1] as ItemView
	var window: PriceWindow = first.sticker().window()
	first.sticker().show_gained("Household")
	# The window tells the layer itself: no frame passes with the label under the next cell.
	first.sticker().set_pay(PlanningModel.Pay.BOOSTED, 999)
	assert_int(layer.labelled().size()).is_equal(1)
	assert_object(layer.labelled()[0]).is_same(window)
	assert_int(window.label().leak()).is_equal(PriceLabel.cap())
	# The label passes its ticket, the gap and the next ticket's gold ring and left edge.
	var shown: Rect2 = window.label().get_global_rect()
	var next: Rect2 = second.sticker().get_global_rect()
	assert_float(shown.end.x).is_greater(next.position.x)
	assert_bool(shown.intersects(second.sticker().gold_ring().get_global_rect())).is_true()
	assert_float(shown.end.x).is_less(second.sticker().glyphs()[0].get_global_rect().end.x)
	# Drawn after every cell: the next cell's item is earlier in the tree than the layer.
	assert_bool(layer.is_greater_than(second)).is_true()
	assert_bool(layer.is_greater_than(second.sticker().gold_ring())).is_true()
	assert_bool(window.is_greater_than(second)).is_false()
	assert_object(window.tip_cover).is_same(layer)
	assert_object(window.drawn_from()).is_same(layer)
	assert_that(layer.tint_of(window)).is_equal(Color.WHITE)
	# The label shows once: the layer draws it and its digits, the window neither.
	assert_bool(window.label().covered).is_true()
	assert_float(window.digits().self_modulate.a).is_equal(0.0)
	assert_float(window.shadow().self_modulate.a).is_equal(0.0)
	assert_bool(window.digits().visible).is_true()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_array(layer.drawn_rects()).has_size(1)
	_assert_rect(layer.drawn_rects()[0], shown)
	# The next GOLDEN ticket's corner sparkle is raised over the row: hidden under the label,
	# its foot sparkle (clear of the label) and the labelled ticket's own kept.
	var sparkles: Array[TextureRect] = second.sticker().sparkles()
	assert_int(sparkles.size()).is_equal(2)
	assert_bool(shown.intersects(sparkles[1].get_global_rect())).is_true()
	assert_float(sparkles[1].self_modulate.a).is_equal(0.0)
	assert_float(sparkles[0].self_modulate.a).is_equal(1.0)
	for sparkle: TextureRect in first.sticker().sparkles():
		assert_float(sparkle.self_modulate.a).is_equal(1.0)
	# A tween moves the row after the layer's own frame (the belt's slide): the window tells the
	# layer, which draws the label at the ticket's new place in that same frame.
	var slide: Tween = create_tween()
	slide.tween_property(strip.box, "position:x", 40.0, 0.05)
	await slide.finished
	await get_tree().process_frame
	var moved: Rect2 = window.label().get_global_rect()
	assert_float(moved.position.x).is_equal_approx(shown.position.x + 40.0, 0.01)
	assert_array(layer.drawn_rects()).has_size(1)
	_assert_rect(layer.drawn_rects()[0], moved)
	# So does a pop of the window alone (a counted pay's).
	window.pivot_offset = window.size / 2.0
	window.scale = Vector2.ONE * 1.5
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_rect(layer.drawn_rects()[0], window.label().get_global_rect())
	assert_float(layer.drawn_rects()[0].size.x).is_equal_approx(moved.size.x * 1.5, 0.01)
	window.scale = Vector2.ONE
	strip.box.position.x = 0.0
	# Its tint is its item's (the mix grey darkens the ticket), and a hidden cell draws none: its
	# window draws itself again, and the neighbour's sparkle is back.
	first.dim_greyness = Vector2(0.78, 0.2)
	first.relation = ItemView.Relation.DIM
	assert_float(layer.tint_of(window).r).is_equal_approx(0.78, 0.001)
	first.relation = ItemView.Relation.NONE
	strip.slots[0].visible = false
	assert_array(layer.labelled()).is_empty()
	assert_object(window.tip_cover).is_null()
	assert_bool(window.label().covered).is_false()
	assert_float(sparkles[1].self_modulate.a).is_equal(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_array(layer.drawn_rects()).is_empty()
	strip.slots[0].visible = true
	assert_object(window.tip_cover).is_same(layer)
	# A hidden layer draws nothing: the windows draw their own labels.
	layer.visible = false
	assert_bool(window.label().covered).is_false()
	assert_float(window.digits().self_modulate.a).is_equal(1.0)
	layer.visible = true
	assert_bool(window.label().covered).is_true()
	# A ticket that leaves the row takes its label back.
	var cell: Node = first.get_parent()
	cell.remove_child(first)
	layer.refresh()
	assert_object(window.tip_cover).is_null()
	assert_bool(window.label().covered).is_false()
	cell.add_child(first)
	layer.refresh()
	assert_bool(window.label().covered).is_true()
	# Back in the window: no label, and the window draws itself again for its tip.
	first.sticker().clear_pay()
	assert_array(layer.labelled()).is_empty()
	assert_object(window.tip_cover).is_null()
	assert_object(window.drawn_from()).is_same(window)
	assert_float(window.digits().self_modulate.a).is_equal(1.0)
	assert_float(sparkles[1].self_modulate.a).is_equal(1.0)
	# A layer that leaves the tree gives every label back.
	first.sticker().set_pay(PlanningModel.Pay.BOOSTED, 999)
	assert_bool(window.label().covered).is_true()
	strip.remove_child(layer)
	assert_bool(window.label().covered).is_false()
	assert_float(sparkles[1].self_modulate.a).is_equal(1.0)
	strip.add_child(layer)
	layer.refresh()
	assert_bool(window.label().covered).is_true()


## A drag's ghost carries its pay in a framed window off a ticket: its label's outline runs down
## the left too (no divider covers that side); a ticket's label has none there.
func test_a_framed_window_closes_its_label_on_the_left() -> void:
	var framed: PriceWindow = auto_free(PriceWindow.new(PriceWindow.State.BOOSTED, 1250, true, 3))
	add_child(framed)
	assert_bool(framed.label().visible).is_true()
	assert_bool(framed.label().left_edge).is_true()
	var milk: PriceSticker = auto_free(PriceSticker.new(_card("milk")))
	add_child(milk)
	milk.set_pay(PlanningModel.Pay.BOOSTED, 1250)
	assert_bool(milk.window().label().left_edge).is_false()
	var leak: int = milk.window().label().leak()
	var room: Rect2i = PriceLabel.art_rect(NORMAL, leak)
	var open: Array = PriceLabel._shape(NORMAL, leak, false)
	var closed: Array = PriceLabel._shape(NORMAL, leak, true)
	for cell: Vector2i in open[0]:
		# Nothing left of the window; the outline and the shadow stay in the label's rect.
		assert_bool(room.has_point(cell)).is_true()
	for cell: Vector2i in open[1]:
		assert_bool(room.has_point(cell)).is_true()
	var left_cells: int = 0
	for cell: Vector2i in closed[0]:
		if cell.x < 0:
			left_cells += 1
			assert_int(cell.x).is_equal(-1)
	assert_int(left_cells).is_equal(PriceWindow.ART.y)
	assert_int((closed[0] as Array).size()).is_equal((open[0] as Array).size() + left_cells)


## The handbook's example rows draw their labels over the row and its frames too; no example's
## pay needs one today.
func test_the_handbook_row_has_its_label_layer() -> void:
	var book: HandbookBook = HandbookBook.shared()
	var checked: int = 0
	for entry: HandbookEntry in book.entries:
		var example: HandbookExample = HandbookExample.of(entry)
		if not example.is_scored():
			continue
		var clip: HandbookClip = auto_free(HandbookClip.new(example, 640.0))
		add_child(clip)
		clip.stop()
		var layer: PriceLabelLayer = clip.price_labels()
		assert_bool(layer.is_greater_than(clip.chain_frames())).is_true()
		for ticket: PriceSticker in clip.tickets():
			assert_bool(layer.is_greater_than(ticket)).is_true()
		layer.refresh()
		assert_array(layer.labelled()).override_failure_message(entry.id).is_empty()
		if checked == 0:
			# A price too wide there goes on a label the layer draws.
			var window: PriceWindow = clip.tickets()[0].window()
			clip.tickets()[0].set_pay(PlanningModel.Pay.BOOSTED, 9999)
			assert_object(layer.labelled()[0]).is_same(window)
			assert_bool(window.label().covered).is_true()
		checked += 1
	assert_int(checked).is_greater(0)


func _assert_rect(rect: Rect2, expected: Rect2) -> void:
	assert_float(rect.position.x).is_equal_approx(expected.position.x, 0.01)
	assert_float(rect.position.y).is_equal_approx(expected.position.y, 0.01)
	assert_float(rect.size.x).is_equal_approx(expected.size.x, 0.01)
	assert_float(rect.size.y).is_equal_approx(expected.size.y, 0.01)


## The tooltip watches a label's whole rect: resting on its leak, over the next ticket, shows the
## labelled ticket's price tip, not the next ticket's.
func test_the_tip_shows_on_the_whole_label() -> void:
	var host: Control = auto_free(Control.new())
	host.size = Vector2(1280, 720)
	add_child(host)
	var strip: RowStrip = RowStrip.new()
	host.add_child(strip)
	var tips: GlyphTips = GlyphTips.new()
	host.add_child(tips)
	strip.set_slot_count(8)
	var row: Array[CardInstance] = []
	for slot: int in range(2):
		row.append(CardInstance.new(_card("milk"), slot + 1))
	var views: Array[CardView] = strip.show_cards(row, -1, func(_view: CardView) -> void: pass)
	await get_tree().process_frame
	var first: PriceSticker = (views[0] as ItemView).sticker()
	var second: PriceSticker = (views[1] as ItemView).sticker()
	first.show_gained("Household")
	first.set_pay(PlanningModel.Pay.BOOSTED, 999)
	var window: PriceWindow = first.window()
	var shown: Rect2 = window.label().get_global_rect()
	var over_gap: Vector2 = Vector2(first.get_global_rect().end.x + 2.0, shown.get_center().y)
	var over_next: Vector2 = Vector2(shown.end.x - 2.0, shown.get_center().y)
	assert_bool(second.get_global_rect().has_point(over_next)).is_true()
	assert_object(tips.glyph_at(shown.get_center())).is_same(window)
	assert_object(tips.glyph_at(over_gap)).is_same(window)
	assert_object(tips.glyph_at(over_next)).is_same(window)
	# Off the label the next ticket's own targets serve.
	var below: Vector2 = Vector2(over_next.x, shown.end.y + 20.0)
	assert_object(tips.glyph_at(below)).is_not_same(window)
	# Without the label the window is its own rect again.
	first.clear_pay()
	assert_object(tips.glyph_at(over_next)).is_not_same(window)


## The WCAG contrast of two colours.
static func _contrast(a: Color, b: Color) -> float:
	var la: float = a.srgb_to_linear().get_luminance()
	var lb: float = b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _card(card_id: String) -> CardDefinition:
	return load("%s/%s.tres" % [CARDS, card_id]) as CardDefinition
