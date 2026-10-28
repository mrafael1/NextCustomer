extends GdUnitTestSuite
## The top bar's planning-effect parts (#71, mock-up h1): a stamped loyalty box reports hovering
## by its upgrade's index, takes a gold ring just outside it (decor, cleared by clear_relations and
## by a rebuild), and keeps its tooltip; the inspection chip reports hovering, rings in gold and
## names the inspection causing the hovered item's effect (keeping its width) until the ring comes
## off. h1's top bar shows no fizzle icon and no hit count: the belt's stickers and stamps do.
## Everything stays inside the bar and takes no clicks.

const UPGRADES := "res://data/upgrades"
const INSPECTIONS := "res://data/inspections"


func test_loyalty_boxes_report_hovers_and_take_rings() -> void:
	var bar: TopBar = await _bar()
	var card: LoyaltyCard = bar.loyalty_card
	var upgrades: Array[UpgradeDefinition] = _upgrades(["coupon_engine", "slot_engine"])
	card.show_upgrades(4, upgrades)
	await _frames(2)
	var seen: Array[String] = []
	card.box_hovered.connect(func(index: int) -> void: seen.append("in:%d" % index))
	card.box_unhovered.connect(func(index: int) -> void: seen.append("out:%d" % index))
	for index: int in range(upgrades.size()):
		card.box(index).mouse_entered.emit()
		card.box(index).mouse_exited.emit()
	assert_array(seen).is_equal(["in:0", "out:0", "in:1", "out:1"])
	# An empty box reports nothing and takes nothing.
	assert_object(card.box(2)).is_null()
	card.set_relation(2, true)
	assert_bool(card.has_relation(2)).is_false()
	var bar_rect: Rect2 = bar.get_global_rect()
	for index: int in range(upgrades.size()):
		var box: Control = card.box(index)
		assert_str(box.tooltip_text).is_equal(LoyaltyCard.tooltip_for(upgrades[index]))
		assert_bool(card.has_relation(index)).is_false()
		card.set_relation(index, true)
		await _frames(1)
		assert_bool(card.has_relation(index)).is_true()
		var ring: Panel = box.get_node(LoyaltyCard.RING_NAME) as Panel
		var line: StyleBoxFlat = ring.get_theme_stylebox("panel") as StyleBoxFlat
		assert_object(line.border_color).is_equal(Palette.GOLD)
		assert_bool(line.draw_center).is_false()
		var drawn: Rect2 = ring.get_global_rect().grow(LoyaltyCard.RING_OUTSET)
		assert_bool(drawn.encloses(box.get_global_rect())).is_true()
		assert_bool(bar_rect.encloses(drawn)).override_failure_message(str(drawn)).is_true()
		assert_int(ring.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		# h1: no fizzle corner on the box: its only art is its perk icon (#108 follow-up).
		for art: Node in box.find_children("*", "TextureRect", true, false):
			assert_str(art.get_parent().name).is_equal(LoyaltyCard.ICON_NAME)
		assert_str((box.get_child(0) as Label).text).is_equal(
			LoyaltyCard.stamp_text(upgrades[index], true)
		)
	card.set_relation(0, false)
	assert_bool(card.has_relation(0)).is_false()
	assert_bool(card.has_relation(1)).is_true()
	card.clear_relations()
	assert_bool(card.has_relation(1)).is_false()
	# A rebuild (the upgrades changed) starts clean.
	card.set_relation(0, true)
	card.show_upgrades(4, _upgrades(["coupon_engine", "slot_engine", "category_engine"]))
	assert_bool(card.has_relation(0)).is_false()
	assert_int(card.box_texts().size()).is_equal(4)
	# The old boxes are freed at the frame's end.
	await _frames(1)


func test_the_inspection_chip_rings_and_names_its_cause() -> void:
	var bar: TopBar = await _bar()
	var tag: InspectionTag = bar.inspection_tag
	var inspections: Array[InspectionDefinition] = [
		load(INSPECTIONS.path_join("spot_check.tres")) as InspectionDefinition,
		load(INSPECTIONS.path_join("short_belt.tres")) as InspectionDefinition,
	]
	tag.show_inspections(inspections)
	await _frames(2)
	var effects: String = tag.text()
	var seen: Array[String] = []
	tag.hovered.connect(func() -> void: seen.append("in"))
	tag.unhovered.connect(func() -> void: seen.append("out"))
	tag.notification(Control.NOTIFICATION_MOUSE_ENTER)
	tag.notification(Control.NOTIFICATION_MOUSE_EXIT)
	assert_array(seen).is_equal(["in", "out"])
	# h1: no hit count on the chip.
	assert_object(tag.find_child("Hits", true, false)).is_null()
	assert_bool(bar.get_global_rect().encloses(tag.get_global_rect())).is_true()
	assert_bool(tag.has_relation()).is_false()
	var width: float = tag.size.x
	tag.set_relation(true, 0)
	assert_bool(tag.has_relation()).is_true()
	assert_str(tag.text()).is_equal(inspections[0].display_name)
	# Named, the chip keeps its width: the top bar doesn't shift under the pointer.
	await _frames(2)
	assert_float(tag.size.x).is_equal_approx(width, 0.01)
	tag.set_relation(true, 1)
	assert_str(tag.text()).is_equal(inspections[1].display_name)
	# Hovering the chip itself rings it with its effects shown.
	tag.set_relation(true)
	assert_str(tag.text()).is_equal(effects)
	tag.set_relation(true, 5)
	assert_str(tag.text()).is_equal(effects)
	tag.set_relation(false, 0)
	assert_bool(tag.has_relation()).is_false()
	assert_str(tag.text()).is_equal(effects)
	assert_int(tag.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_str(tag.tooltip_text).contains(inspections[0].display_name)
	for node: Node in tag.find_children("*", "Control", true, false):
		assert_int((node as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	# A new shift's inspections drop the named cause.
	tag.set_relation(true, 0)
	tag.show_inspections(inspections.slice(0, 1))
	assert_str(tag.text()).is_equal("Inspection · %s" % inspections[0].chip_text)
	assert_float(tag.custom_minimum_size.x).is_equal(0.0)


func _bar() -> TopBar:
	var bar: TopBar = auto_free(TopBar.new())
	add_child(bar)
	await _frames(2)
	return bar


static func _upgrades(ids: Array[String]) -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = []
	for id: String in ids:
		result.append(load(UPGRADES.path_join("%s.tres" % id)) as UpgradeDefinition)
	return result


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame
