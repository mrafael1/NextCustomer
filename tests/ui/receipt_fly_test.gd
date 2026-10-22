extends GdUnitTestSuite
## ReceiptFly (#86 v6): a payout's paper "+€N" chip flies from its item's rect to its receipt line,
## following the line while it moves (the receipt scrolling), on whole pixels and inside the
## overlay every frame; it lands with its centre on the line's amount end, and the line fades in
## as it lands (a line already shown, not to reveal, keeps its look). No line: nothing flies.
## Reduced motion: nothing flies and the line shows at once. On a plain node's tweens here (the
## count-up gives its own). The real saves and logs are never
## touched: both go to a temporary folder.

const OVERLAY_SIZE := Vector2(1280, 720)
## The item at the scanner, roughly where the belt ride's scanner cell is.
const ITEM_RECT := Rect2(374, 286, 96, 96)
const FLIGHT := 0.3

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_receipt_fly_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The chip starts on the item's centre, stays inside the overlay on whole pixels every frame,
## follows the line as it scrolls up, lands on the line's amount end (inside the line) and the
## line fades in fully after it.
func test_the_chip_flies_to_the_moving_line_and_the_line_fades_in() -> void:
	var overlay: Control = _overlay()
	var receipt: Control = _receipt(overlay)
	var line: Label = _line(receipt)
	var fly: ReceiptFly = ReceiptFly.new(overlay, overlay.create_tween)
	await _frames(1)
	line.modulate.a = 0.0
	fly.fly(ReceiptFly.amount_text(7), ITEM_RECT, line, FLIGHT)
	var chips: Array[Node] = _chips(overlay)
	assert_int(chips.size()).is_equal(1)
	var chip: PanelContainer = chips[0] as PanelContainer
	assert_str((chip.get_child(0) as Label).text).is_equal("+€7")
	var start: Vector2 = chip.get_global_rect().get_center()
	assert_float(start.distance_to(ITEM_RECT.get_center())).is_less_equal(1.0)
	var landing: Array[float] = []
	chip.tree_exiting.connect(
		func() -> void:
			var at: Vector2 = chip.get_global_rect().get_center()
			landing.append(at.distance_to(ReceiptFly.landing_point(line, chip.size)))
			landing.append(1.0 if line.get_global_rect().has_point(at) else 0.0)
	)
	var failures: Array[String] = []
	var area: Rect2 = overlay.get_global_rect()
	var receipt_start: float = receipt.position.y
	while is_instance_valid(chip) and chip.is_inside_tree():
		# The receipt scrolls up under the flight.
		receipt.position.y -= 2.0
		await get_tree().process_frame
		if not is_instance_valid(chip) or chip.is_queued_for_deletion():
			break
		var rect: Rect2 = chip.get_global_rect()
		if not area.encloses(rect):
			failures.append("chip at %s" % rect)
		if rect.position != rect.position.round():
			failures.append("chip off the pixel grid at %s" % rect.position)
	await _frames(2)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	assert_float(receipt_start - receipt.position.y).is_greater(10.0)
	assert_int(landing.size()).is_equal(2)
	assert_float(landing[0]).is_less_equal(1.0)
	assert_float(landing[1]).is_equal(1.0)
	var start_ms: int = Time.get_ticks_msec()
	while line.modulate.a < 1.0 and Time.get_ticks_msec() - start_ms < 1000:
		await get_tree().process_frame
	assert_float(line.modulate.a).is_equal(1.0)
	assert_int(_chips(overlay).size()).is_equal(0)


## A chip from off the overlay (an item's rect above or left of it) starts clamped inside it.
func test_the_chip_stays_inside_the_overlay() -> void:
	var overlay: Control = _overlay()
	var line: Label = _line(_receipt(overlay))
	var fly: ReceiptFly = ReceiptFly.new(overlay, overlay.create_tween)
	await _frames(1)
	fly.fly("+€1234", Rect2(-300, -200, 40, 40), line, FLIGHT)
	var chip: Control = _chips(overlay)[0] as Control
	var rect: Rect2 = chip.get_global_rect()
	(
		assert_bool(overlay.get_global_rect().encloses(rect))
		. override_failure_message(str(rect))
		. is_true()
	)
	assert_vector(rect.position).is_equal(Vector2.ZERO)
	# The chip's look: ink on paper in an ink border, in the number font.
	var style: StyleBoxFlat = chip.get_theme_stylebox("panel") as StyleBoxFlat
	assert_that(style.bg_color).is_equal(Palette.PAPER)
	assert_that(style.border_color).is_equal(Palette.INK)
	var label: Label = chip.get_child(0) as Label
	assert_that(label.get_theme_color("font_color")).is_equal(Palette.INK)
	assert_object(label.get_theme_font("font")).is_same(ArtStyle.number_font())
	assert_int(label.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(chip.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	await _frames(int(FLIGHT * 60) + 20)


## Reduced motion: no chip, the line shows at once. No line (a payout already shown): nothing
## flies. The amounts: "+€N", "€0" for nothing.
func test_reduced_motion_and_no_line_fly_nothing() -> void:
	var overlay: Control = _overlay()
	var line: Label = _line(_receipt(overlay))
	var fly: ReceiptFly = ReceiptFly.new(overlay, overlay.create_tween)
	fly.reduced_motion = true
	line.modulate.a = 0.0
	fly.fly("+€5", ITEM_RECT, line, FLIGHT)
	assert_float(line.modulate.a).is_equal(1.0)
	assert_int(_chips(overlay).size()).is_equal(0)
	fly.reduced_motion = false
	fly.fly("+€5", ITEM_RECT, null, FLIGHT)
	assert_int(_chips(overlay).size()).is_equal(0)
	assert_str(ReceiptFly.amount_text(5)).is_equal("+€5")
	assert_str(ReceiptFly.amount_text(0)).is_equal("€0")


## A chip to a line already shown (reveal false: a payout that prints no line) still flies and
## lands, and the line keeps its look: it is never hidden or faded.
func test_a_chip_to_a_shown_line_leaves_the_line_as_it_is() -> void:
	var overlay: Control = _overlay()
	var line: Label = _line(_receipt(overlay))
	var fly: ReceiptFly = ReceiptFly.new(overlay, overlay.create_tween)
	await _frames(1)
	line.modulate.a = 0.5
	fly.fly(ReceiptFly.amount_text(9), ITEM_RECT, line, FLIGHT, false)
	assert_int(_chips(overlay).size()).is_equal(1)
	await _frames(int(FLIGHT * 60) + 20)
	assert_int(_chips(overlay).size()).is_equal(0)
	assert_float(line.modulate.a).is_equal(0.5)


## The flying chips among the overlay's children.
static func _chips(overlay: Control) -> Array[Node]:
	var chips: Array[Node] = []
	for child: Node in overlay.get_children():
		if ReceiptFly.is_chip(child) and not child.is_queued_for_deletion():
			chips.append(child)
	return chips


func _overlay() -> Control:
	var overlay: Control = auto_free(Control.new())
	overlay.size = OVERLAY_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(overlay)
	return overlay


## A stand-in for the receipt's scroll content, about where the receipt hangs.
func _receipt(overlay: Control) -> Control:
	var receipt: Control = Control.new()
	receipt.position = Vector2(46, 260)
	receipt.size = Vector2(236, 80)
	overlay.add_child(receipt)
	return receipt


## A payout's amount label on its line.
func _line(receipt: Control) -> Label:
	var line: Label = Label.new()
	line.text = "€7.00"
	line.position = Vector2(8, 40)
	line.size = Vector2(220, 20)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	receipt.add_child(line)
	return line


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
