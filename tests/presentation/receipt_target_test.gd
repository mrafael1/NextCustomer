extends GdUnitTestSuite
## The receipt's header (ReceiptTarget; main scene v2's H2, 2026-11-08): hidden without a quota;
## BEAT TODAY'S TARGET over the quota as whole euros with the € after them ("80€") in the 6x8 pixel
## digits at the target's cell (ReceiptTarget.cells.y), the target with its check centred inside
## the block over its double rule; on a ReceiptView it opens the paper, outside the scrolled lines;
## a pending medal's metal on the PROJECTED number and PAID stamped on the over row (2026-11-09).
## No saves, no logs.


func test_hidden_without_a_quota() -> void:
	var target: ReceiptTarget = auto_free(ReceiptTarget.new())
	assert_bool(target.visible).is_false()
	assert_int(target.shown_quota()).is_equal(-1)
	target.show_quota(80)
	assert_bool(target.visible).is_true()
	assert_int(target.shown_quota()).is_equal(80)
	target.show_quota(-1)
	assert_bool(target.visible).is_false()
	assert_int(target.shown_quota()).is_equal(-1)


func test_the_quota_prints_in_whole_euros_with_the_euro_after() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, 300)
	add_child(receipt)
	var target: ReceiptTarget = receipt.target
	target.show_quota(80)
	for line: int in range(30):
		receipt.add_line("Milk %d" % line, "1€", ReceiptView.LineStyle.ITEM)
	await _frames(3)
	assert_str(target.caption.text).is_equal(ReceiptTarget.CAPTION_TEXT)
	assert_str(target.beat.text).is_equal(ReceiptTarget.BEAT_TEXT)
	# The caption in ink, BEAT and the number in tomato dark.
	assert_that(target.caption.get_theme_color("font_color")).is_equal(Palette.INK)
	assert_that(target.beat.color).is_equal(ReceiptTarget.COLOR)
	assert_str(target.amount.text).is_equal("80€")
	assert_that(target.amount.color).is_equal(Palette.TOMATO_DARK)
	var block: Rect2 = target.get_global_rect()
	assert_bool(receipt.get_global_rect().encloses(block)).is_true()
	var digits: Rect2 = target.digits_rect()
	digits.position += target.global_position
	assert_bool(block.encloses(digits)).override_failure_message(str(digits)).is_true()
	# The target (no check before the quota is met) centred on the block.
	var group: Rect2 = target.digits_rect()
	var middle: float = group.get_center().x + target.global_position.x
	assert_float(absf(middle - block.get_center().x)).is_less_equal(4.0)
	# The 6x8 digits at the target's cell, on the grid.
	var cell: float = target.cells.y
	assert_float(digits.size.y).is_equal(8.0 * cell)
	assert_float(fmod(target.amount.position.x, 2.0)).is_equal(0.0)
	# The digits and the €: "80€" is 6 + 1 + 6 + 1 + 6 font px wide.
	assert_float(digits.size.x).is_equal(20.0 * cell)
	# A wide number stays inside the block.
	target.show_quota(888888)
	await _frames(2)
	var wide: Rect2 = target.digits_rect()
	wide.position += target.global_position
	assert_bool(block.encloses(wide)).override_failure_message(str(wide)).is_true()
	target.show_quota(80)
	await _frames(2)
	# The lines scroll under it: the block stays above the scroll area.
	receipt.scroll_to_end()
	await _frames(2)
	assert_float(block.end.y).is_less_equal(receipt._scroll.get_global_rect().position.y)
	assert_that(target.get_global_rect()).is_equal(block)


## While planning's projection would spend a medal still free this week (ReceiptGold's pending
## metal, the 2026-11-09 play test) the PROJECTED digits take its metal, gold over silver, in shades
## that read on the cream paper (3:1 or more, the hero's large digits) apart from the over line's
## green and tomato; plain ink with no medal pending, and the count's TOTAL always ink.
func test_a_pending_medal_tints_the_projected_number() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, 300)
	add_child(receipt)
	var target: ReceiptTarget = receipt.target
	var ink: Array[Color] = [ReceiptTarget.HERO_COLOR, ReceiptTarget.NO_SHADOW]
	var silver: Array[Color] = [ReceiptTarget.SILVER_HERO_COLOR, ReceiptTarget.SILVER_HERO_SHADOW]
	var gold: Array[Color] = [ReceiptTarget.GOLD_HERO_COLOR, ReceiptTarget.GOLD_HERO_SHADOW]
	target.show_quota(50)
	target.show_planned(150, 50)
	assert_array(target.hero_ink()).is_equal(ink)
	receipt.gold.show_pending(ReceiptGold.PENDING_SILVER, true)
	assert_array(target.hero_ink()).is_equal(silver)
	receipt.gold.show_pending(ReceiptGold.PENDING_GOLD, true)
	assert_array(target.hero_ink()).is_equal(gold)
	# The metal's shadow (one font px down and right) stays on the paper, a wide total too.
	for total: int in [150, 888]:
		target.show_planned(total, 50, true)
		await get_tree().process_frame
		var shadowed: Rect2 = target.hero_rect()
		shadowed.size += Vector2.ONE * target.hero.cell
		assert_float(shadowed.end.x).override_failure_message(str(total)).is_less_equal(
			target.size.x
		)
	target.show_planned(160, 50, true)  # A new projection keeps the metal until told otherwise.
	assert_array(target.hero_ink()).is_equal(gold)
	receipt.gold.show_pending(ReceiptGold.PENDING_NONE, true)
	assert_array(target.hero_ink()).is_equal(ink)
	receipt.gold.show_pending(ReceiptGold.PENDING_GOLD, true)
	target.begin_count(0)
	assert_array(target.hero_ink()).is_equal(ink)
	for body: Color in [ReceiptTarget.SILVER_HERO_COLOR, ReceiptTarget.GOLD_HERO_COLOR]:
		assert_float(_contrast(body, Palette.PAPER)).is_greater_equal(3.0)
		for line: Color in [Palette.GREEN_DARK, Palette.TOMATO_DARK, ReceiptTarget.HERO_COLOR]:
			assert_bool(body.is_equal_approx(line)).is_false()
	# The shadow a step darker than its body.
	var pairs: Array[Array] = [silver, gold]
	for pair: Array in pairs:
		assert_float((pair[1] as Color).get_luminance()).is_less((pair[0] as Color).get_luminance())


## An anchored count's PAID (or SLIP) stamps the header's over row right after the margin's words
## (the 2026-11-09 play test: no paper line under the rows), inside the header, the words sized to
## leave it room; the next shift's stamp lands on the same label, and a new projection clears it.
func test_paid_stamps_the_header_after_the_margin_words() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, 300)
	add_child(receipt)
	var target: ReceiptTarget = receipt.target
	target.show_quota(50)
	target.show_planned(888, 50)
	target.begin_count(0)
	target.show_running(888)
	assert_bool(target.stamp.visible).is_false()
	var row: HBoxContainer = target.show_margin_words(ShiftMargin.of(888, 50))
	assert_object(row).is_same(target.over_row)
	assert_object(ReceiptStamps.stamp_paid(row)).is_same(target.stamp)
	await _frames(3)
	assert_str(target.stamp.text).is_equal(ReceiptStamps.PAID_TEXT)
	assert_bool(target.stamp.visible).is_true()
	var words: Rect2 = target.over.get_global_rect()
	var stamp: Rect2 = target.stamp.get_global_rect()
	assert_float(stamp.position.x).is_greater_equal(words.end.x - 1.0)
	# The stamp's box (untilted) inside the header's width: its layout rect, not its drawn rect.
	var block: Rect2 = target.get_global_rect().grow(1.0)
	var box: Rect2 = Rect2(target.stamp.global_position, target.stamp.size)
	box.position = target.over_row.global_position + target.stamp.position
	assert_bool(block.encloses(box)).override_failure_message("%s %s" % [box, block]).is_true()
	var font: Font = target.over.get_theme_font("font")
	var font_size: int = target.over.get_theme_font_size("font_size")
	var wide: float = (
		font.get_string_size(target.over.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	)
	assert_float(wide).is_less_equal(words.size.x + 1.0)
	assert_float(target.stamp.rotation).is_not_equal(0.0)
	assert_array(receipt.printed_rows()).is_empty()
	ReceiptStamps.stamp_write_up(row, "SLIP 1/2")
	assert_str(target.stamp.text).is_equal("SLIP 1/2")
	target.show_planned(90, 50)
	assert_bool(target.stamp.visible).is_false()
	assert_str(target.stamp.text).is_empty()


## The WCAG contrast ratio of two colours.
static func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(color: Color) -> float:
	var linear: Color = color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame
