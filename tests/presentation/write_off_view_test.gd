extends GdUnitTestSuite
## Write-off's look (v1.28, the user's answers of 2026-11-11): a written-off item shows a WRITTEN
## OFF stamp, never a red fizzle. Its WRITTEN_OFF step prints a receipt line in the context style,
## plays as a tag beat, marks no fizzle on the receipt or the belt, and the planning belt labels
## the item WRITTEN OFF without denying it. Pure data, but for the label's fit.

const CARDS := "res://data/cards/%s.tres"
const PLANNING_TUNING := "res://data/balance/planning.tres"
const COUNT_TUNING := "res://data/balance/count_up.tres"
const ROW := "write_off,bread,repeat"


func test_the_receipt_prints_a_written_off_line() -> void:
	var result: ScoreResult = Scoring.score(_row(ROW))
	var step: ScoreStep = _written_off(result)
	var names: PackedStringArray = PackedStringArray(["Write-off", "Bread", "Repeat"])
	var text: PackedStringArray = ReceiptView.step_text(step, names)
	assert_array(Array(text)).is_equal(["  Write-off ×2: Bread", "WRITTEN OFF"])
	assert_int(ReceiptView.step_style(step)).is_equal(ReceiptView.LineStyle.CONTEXT)
	assert_str(ReceiptView.step_line(step, names)).is_equal("Write-off ×2: Bread  WRITTEN OFF")
	# No fizzle mark on the written-off item, or on any item of the row.
	for slot: int in range(3):
		assert_int(ReceiptView.slot_mark(result, slot)).is_equal(ReceiptView.Mark.NONE)
	assert_bool(EffectChip.qualifies(step)).is_false()


func test_the_count_up_plays_it_as_a_tag_beat() -> void:
	var result: ScoreResult = Scoring.score(_row(ROW))
	var index: int = result.steps.find(_written_off(result))
	var plan: CountUpPlan = CountUpPlan.build(
		result.steps, 40, CountUpContext.new(), load(COUNT_TUNING)
	)
	var found: Array[CountUpBeat] = []
	for beat: CountUpBeat in plan.beats:
		if beat.steps.has(index):
			found.append(beat)
	assert_int(found.size()).is_equal(1)
	assert_int(found[0].kind).is_equal(CountUpBeat.Kind.TAG)


func test_the_belt_stamps_the_written_off_item() -> void:
	var cards: Array[CardDefinition] = []
	for instance: CardInstance in _row(ROW):
		cards.append(instance.definition)
	var result: ScoreResult = Scoring.score(_row(ROW))
	var no_upgrades: Array[UpgradeDefinition] = []
	var no_inspections: Array[InspectionDefinition] = []
	var model: PlanningModel = PlanningModel.build(
		result, cards, no_upgrades, no_inspections, load(PLANNING_TUNING)
	)
	var bread: PlanningSlot = model.slots[1]
	assert_bool(bread.has_stamp()).is_true()
	assert_str(bread.stamp_caption).is_equal("WRITTEN OFF")
	assert_str(bread.stamp_amount).is_equal("10€")
	assert_bool(bread.written_off).is_true()
	assert_bool(bread.denied).is_false()
	assert_bool(PlanningModel.written_off(result, 1)).is_true()
	for slot: int in [0, 2]:
		assert_bool(model.slots[slot].has_stamp()).override_failure_message(str(slot)).is_false()
		assert_bool(model.slots[slot].written_off).is_false()
		assert_bool(PlanningModel.written_off(result, slot)).is_false()


## The written-off label's caption fits whole on one line, never cut with an ellipsis, inside the
## label (its amount hidden: the ticket shows the pay); it is no denial stamp: its own place at the
## art's foot, teal ink, no tomato.
func test_the_label_caption_fits() -> void:
	var font: Font = ArtStyle.spaced_display_font(DenyStamp.CAPTION_SPACING)
	var fitted: Array = DenyStamp.fit_caption(
		PlanningModel.WRITTEN_OFF_CAPTION, font, DenyStamp.WRITTEN_OFF_WIDTH
	)
	assert_str(fitted[0]).is_equal(PlanningModel.WRITTEN_OFF_CAPTION)
	var label: DenyStamp = auto_free(DenyStamp.new("10€", PlanningModel.WRITTEN_OFF_CAPTION, true))
	assert_str(label.caption()).is_equal("WRITTEN OFF")
	assert_str(label.amount()).is_equal("10€")
	assert_bool(label.is_written_off()).is_true()
	assert_object(label.size).is_equal(DenyStamp.WRITTEN_OFF_SIZE)
	assert_object(label.art_offset(Vector2(2, 26))).is_equal(DenyStamp.WRITTEN_OFF_AT)
	var lines: VBoxContainer = label.get_node("Lines") as VBoxContainer
	var caption: Label = lines.get_node("Caption") as Label
	assert_bool((lines.get_node("Amount") as Label).visible).is_false()
	assert_float(caption.get_combined_minimum_size().y).is_less_equal(DenyStamp.WRITTEN_OFF_SIZE.y)
	assert_object(caption.get_theme_color("font_color")).is_equal(DenyStamp.WRITTEN_OFF_INK)
	# A denial keeps its tomato stamp, its place and its two lines.
	var denial: DenyStamp = auto_free(DenyStamp.new("0€", "SPOT CHECK"))
	assert_bool(denial.is_written_off()).is_false()
	assert_object(denial.art_offset(Vector2(2, 26))).is_equal(Vector2(2, 26))
	var denial_caption: Label = denial.get_node("Lines/Caption") as Label
	assert_object(denial_caption.get_theme_color("font_color")).is_equal(Palette.TOMATO_DARK)


static func _written_off(result: ScoreResult) -> ScoreStep:
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WRITTEN_OFF:
			return step
	return null


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		row.append(CardInstance.new(load(CARDS % card_id) as CardDefinition, row.size() + 1))
	return row
