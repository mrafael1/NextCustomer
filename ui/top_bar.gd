class_name TopBar
extends HBoxContainer
## The shift screen's top bar (#80 step 10, mock-up B2): one row of teal chips on the dark teal
## band, GAP apart: SHIFT n/m, the SPEND chip (QuotaMeter: the quota, a bar and the projected
## total, then the subtotal while counting; it takes the room left), the week chip (v0.70,
## WeekChip: "W2", the week's name, its day pips), the inspection chip (the day chip since v0.70:
## "D6" and the day's events, paper,
## with the mustard warning sign and "Inspection · <effect>", the name in its hover text; hidden
## on shifts without one), the
## LOYALTY chip with its stamps, the Cart button with its trolley, and the menu button (three
## drawn bars) whose menu holds Export log. With weeks (show_weeks, v0.82: the week and day chips
## say where the run is) the SHIFT chip hides, so the row breathes; in the training week a small
## sign swings under the week chip with the slips left (SlipSign, 2026-11-01; it replaced v0.68's
## hint in the SHIFT chip).
## Cart and the menu stay clickable behind every panel:
## the shade starts under the band (ShiftScreen), and the menu opens in its own popup window.
##
## It only builds and lays out; ShiftStage passes the buttons' signals on and the screen fills
## the chips. Its controls are public for the same reason as ShiftStage's.

signal deck_pressed
signal export_pressed

## B2's row: 16 px in, 9 px down, 38 px tall, the chips 12 px apart.
const POSITION := Vector2(16, 9)
const ROW_SIZE := Vector2(1248, 38)
const GAP := 12
## The room fit_inspection keeps free at the row's end.
const FIT_MARGIN := 8.0
## A chip's padding left and right (B2's 0 12px); the container centres its contents vertically.
const CHIP_PADDING := 12
const CHIP_SEPARATION := 8
const KEY_FONT_SIZE := 15
const VALUE_FONT_SIZE := 20
const BUTTON_FONT_SIZE := 16
## The key captions' letter spacing (B2's letter-spacing: 1px).
const KEY_SPACING := 1
## The trolley (12x9 art) and the menu's bars (9x7 art), shown at 2x.
const CART_ICON_SIZE := Vector2(24, 18)
const MENU_ICON_SIZE := Vector2(18, 14)
const MENU_BUTTON_SIZE := Vector2(44, 38)
## The menu's padding, and its gap under the menu button.
const MENU_PADDING := 6
const MENU_GAP := 4.0

const CHIP_FRAME := preload("res://art/frames/chip.png")
const BUTTON_FRAME := preload("res://art/frames/top_button.png")
const CART_ICON := preload("res://art/icons/cart.png")
const MENU_ICON := preload("res://art/icons/menu.png")

var shift_label: Label
## The SHIFT chip ("SHIFT n/m"; hidden with weeks: show_weeks).
var shift_chip: PanelContainer
## The training week's slips used, on a sign under the week chip (2026-11-01; show_training).
var slip_sign: SlipSign
var quota_meter: QuotaMeter
var quota_label: Label
## The week chip (v0.70; hidden for a balance without weeks).
var week_chip: WeekChip
var inspection_tag: InspectionTag
var loyalty_card: LoyaltyCard
## The Cart button (the deck: "Cart" in player strings only, default 1).
var deck_button: FramedButton
var menu_button: FramedButton
## The menu's popup and its one entry.
var menu: PopupPanel
var export_button: FramedButton
## The slip sign's count (show_training), and whether this count-up's SLIP stamp has landed.
var _slip_text: String = ""
var _slip_stamped: bool = false
var _weeks: bool = false
## The SHIFT chip's key caption (hidden with weeks).
var _shift_key: Label


func _init() -> void:
	name = "TopBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", GAP)
	position = POSITION
	size = ROW_SIZE
	shift_chip = chip(CHIP_FRAME)
	var shift_row: HBoxContainer = _row(shift_chip)
	_shift_key = key_label("SHIFT")
	shift_row.add_child(_shift_key)
	shift_label = value_label(Palette.PAPER)
	shift_row.add_child(shift_label)
	add_child(shift_chip)
	var quota_chip: PanelContainer = chip(CHIP_FRAME)
	quota_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quota_meter = QuotaMeter.new()
	quota_chip.add_child(quota_meter)
	quota_label = quota_meter.quota_label
	add_child(quota_chip)
	week_chip = WeekChip.new()
	add_child(week_chip)
	slip_sign = SlipSign.new()
	slip_sign.follow(week_chip)
	slip_sign.reduced_motion = func() -> bool:
		return quota_meter.reduced_motion.is_valid() and bool(quota_meter.reduced_motion.call())
	add_child(slip_sign)
	inspection_tag = InspectionTag.new()
	add_child(inspection_tag)
	loyalty_card = LoyaltyCard.new(true)
	add_child(loyalty_card)
	# The deck view and the export sound themselves.
	deck_button = UiKit.framed_button(
		self, "", deck_pressed.emit, BUTTON_FONT_SIZE, BUTTON_FRAME, Vector2(0, ROW_SIZE.y), ""
	)
	deck_button.use_number_font()
	deck_button.set_icon(CART_ICON, CART_ICON_SIZE)
	menu_button = UiKit.framed_button(
		self, "", open_menu, BUTTON_FONT_SIZE, BUTTON_FRAME, MENU_BUTTON_SIZE
	)
	menu_button.set_icon(MENU_ICON, MENU_ICON_SIZE)
	menu_button.accessibility_name = "Menu"
	menu_button.tooltip_text = "Menu"
	_build_menu()
	# B2's button captions are plain paper on the teal, without the sign's ink outline.
	for button: FramedButton in [deck_button, export_button]:
		button.caption_label().add_theme_constant_override("outline_size", 0)


## Whether the run has weeks (WeekFlow.has_weeks): the week chip shows, the SHIFT chip hides.
func show_weeks(shown: bool) -> void:
	_weeks = shown
	week_chip.visible = shown
	_refresh_shift_chip()


## The SHIFT chip: "SHIFT n/m" without weeks, hidden with them.
func _refresh_shift_chip() -> void:
	shift_chip.visible = not _weeks


## The training week's slips used (WriteUp.hint_text) on the sign under the week chip: its
## `short_text` ("SLIPS 0/2"), else `text`; hidden when empty (with a fall: SlipSign). While a
## count-up runs, `held_text` (the count before the shift's miss) shows until the miss's SLIP
## stamp lands (follow_count), then the sign counts up to `short_text`.
func show_training(text: String, short_text: String = "", held_text: String = "") -> void:
	_slip_text = short_text if not short_text.is_empty() else text
	if held_text.is_empty():
		_slip_stamped = false
	slip_sign.show_text(held_text if not held_text.is_empty() and not _slip_stamped else _slip_text)


## Follows `count_up`: a slip's SLIP stamp counts the sign up.
func follow_count(count_up: CountUp) -> void:
	count_up.slip_stamped.connect(_on_slip_stamped)


func _on_slip_stamped() -> void:
	_slip_stamped = true
	slip_sign.show_text(_slip_text)


## Keeps the row inside ROW_SIZE.x less FIT_MARGIN: the inspection chip's text is trimmed when the
## other chips and the bonus pill (#77 machine v2) leave it too little room, after the week chip's
## name, then its pips, have given way (the day's effects come first).
func fit_inspection() -> void:
	week_chip.show_name(true)
	week_chip.show_pips(true)
	_fit_inspection_once()
	if not inspection_tag.is_trimmed():
		return
	if week_chip.name_shown():
		week_chip.show_name(false)
		_fit_inspection_once()
		if not inspection_tag.is_trimmed():
			return
	week_chip.show_pips(false)
	_fit_inspection_once()


## Where each of a shift's events (WeekSchedule.shift_events: the day's, then the week's) is shown,
## indexed like a step's source_index, for the count-up: the week event on the week chip, the day
## events on the day chip.
func event_sources(events: Array[InspectionDefinition]) -> Array[Control]:
	var controls: Array[Control] = []
	for event: InspectionDefinition in events:
		var source: Control = inspection_tag
		if event.is_week():
			source = week_chip
		controls.append(source)
	return controls


## The minimum width `control` needs now: a container learns of a child's new text or visibility
## only on the next idle frame, so every cached minimum under it is dropped first.
static func fresh_width(control: Control) -> float:
	for child: Node in control.find_children("*", "Control", true, false):
		(child as Control).update_minimum_size()
	control.update_minimum_size()
	return control.get_combined_minimum_size().x


func _fit_inspection_once() -> void:
	_refresh_shift_chip()
	var used: float = 0.0
	var shown: int = 0
	for child: Node in get_children():
		var control: Control = child as Control
		if control == null or not control.visible or control == inspection_tag:
			continue
		used += fresh_width(control)
		shown += 1
	used += GAP * shown
	inspection_tag.fit_width(ROW_SIZE.x - FIT_MARGIN - used)


## A teal chip (or the inspection's paper one): the frame, B2's padding, the row's height.
static func chip(frame: Texture2D) -> PanelContainer:
	var panel: PanelContainer = UiKit.frame_panel(
		frame, FramedButton.FRAME_MARGIN, Vector4(CHIP_PADDING, 0, CHIP_PADDING, 0)
	)
	panel.custom_minimum_size.y = ROW_SIZE.y
	return panel


## A chip's key caption (SHIFT, QUOTA, LOYALTY): the letter-spaced display font in mustard pale.
static func key_label(text: String) -> Label:
	var label: Label = UiKit.display_label(text, KEY_FONT_SIZE, false)
	label.add_theme_font_override("font", ArtStyle.spaced_display_font(KEY_SPACING))
	label.add_theme_color_override("font_color", Palette.MUSTARD_PALE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## A chip's value (5/8, €73): the number font, no outline on the teal.
static func value_label(color: Color) -> Label:
	var label: Label = UiKit.number_label("", VALUE_FONT_SIZE, false)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## Opens the menu under the menu button, right-aligned with it (in screen coordinates, as
## Godot's MenuButton places its popup).
func open_menu() -> void:
	var button: Rect2 = menu_screen_rect()
	var menu_size: Vector2 = Vector2(menu.get_contents_minimum_size())
	var at: Vector2 = Vector2(button.end.x - menu_size.x, button.end.y + MENU_GAP)
	menu.popup(Rect2i(Vector2i(at.round()), Vector2i(menu_size.ceil())))


## The menu button's rect in screen coordinates (the menu popup's).
func menu_screen_rect() -> Rect2:
	var scale_by: Vector2 = menu_button.get_global_transform_with_canvas().get_scale()
	return Rect2(menu_button.get_screen_position(), menu_button.size * scale_by)


func _build_menu() -> void:
	menu = PopupPanel.new()
	menu.name = "Menu"
	# The frame goes on a panel inside the popup, not on the popup's own style: a Window is no
	# CanvasItem, so it would miss the sharp-pixel material and blur when the window is scaled.
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var frame: PanelContainer = UiKit.frame_panel(
		CHIP_FRAME, FramedButton.FRAME_MARGIN, Vector4.ONE * MENU_PADDING
	)
	frame.name = "Frame"
	menu.add_child(frame)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(column)
	export_button = UiKit.framed_button(
		column, "Export log", _on_export, BUTTON_FONT_SIZE, BUTTON_FRAME, Vector2(0, ROW_SIZE.y), ""
	)
	# Internal, so the bar's children are its chips and buttons alone.
	add_child(menu, false, Node.INTERNAL_MODE_BACK)


func _on_export() -> void:
	menu.hide()
	export_pressed.emit()


func _row(panel: PanelContainer) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", CHIP_SEPARATION)
	panel.add_child(row)
	return row
