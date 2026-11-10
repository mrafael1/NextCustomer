class_name TopBar
extends HBoxContainer
## The shift screen's top bar (#80 step 10, mock-up B2): one row on the dark teal band, right of
## the register's tower (the shift scene polish, mock-up shift_scene_polish_v2.html section 2, A2:
## the SPEND chip is gone; the quota is the receipt's TODAY'S TARGET). Since left column v2 (the
## user's pick of 2026-11-09, mock-up docs/art/mockups/left_column_v2.html) it holds, between the
## register's tower and LOYALTY, the quota gauge lying on its side (GaugePanel: one steel-bezelled
## instrument on the band, no chip since the play test of 2026-11-09, in a clipping room it slides
## up out of at CHECKOUT); then the LOYALTY chip with its
## stamps where it stood (LOYALTY_X, its look unchanged), then (pushed to the row's end by a
## spacer) the Cart button with its trolley and the menu button (three drawn bars) whose menu holds
## Guide (the staff handbook, v1.06) and Export log. The day is the desk calendar on the register's
## top (DayCalendar, ShiftStage.DESK_CALENDAR_RECT), the week the register's week glass (WeekGlass)
## and its medals the medal case (MedalCase). A run without weeks shows the SHIFT chip
## ("SHIFT n/m") first, and the gauge's chip shortens. Cart and the menu stay clickable behind
## every panel: the shade starts under the band (ShiftScreen), and the menu opens in its own popup
## window.
##
## It only builds and lays out; ShiftStage passes the buttons' signals on and the screen fills
## the chips. Its controls are public for the same reason as ShiftStage's.

signal deck_pressed
signal export_pressed
## The menu's Guide was pressed (v1.06): the staff handbook opens (HandbookPage.mount).
signal guide_pressed

## B2's row: 9 px down, 38 px tall, the chips 12 px apart, from over the belt's left end (right of
## the register's tower) to 16 px short of the stage's right edge.
const POSITION := Vector2(348, 9)
const ROW_SIZE := Vector2(916, 38)
const GAP := 12
## The row's height: v1.12's week chip's, kept so LOYALTY, Cart and the menu keep their look.
const ROW_HEIGHT := 42.0
## LOYALTY's left edge, where the week and day chips left it in the default run (measured on
## 2026-11-08); the gauge's chip (ShiftStage.GAUGE_PANEL_RECT) stands in the room before it.
const LOYALTY_X := 834.0
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
## The quota gauge's chip (left column v2), in the gauge's room before LOYALTY.
var gauge_panel: GaugePanel
var loyalty_card: LoyaltyCard
## The Cart button (the deck: "Cart" in player strings only, default 1).
var deck_button: FramedButton
var menu_button: FramedButton
## The menu's popup and its entries.
var menu: PopupPanel
var guide_button: FramedButton
var export_button: FramedButton

## The spacer pushing Cart to the row's end.
var _spacer: Control
## The room before LOYALTY (fit_day): the gauge's chip stands in it, clipped to the bar's row.
var _day_room: Control
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
	_day_room = Control.new()
	_day_room.name = "GaugeRoom"
	_day_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_room.clip_contents = true
	_day_room.custom_minimum_size = Vector2(LOYALTY_X - POSITION.x - GAP, ROW_HEIGHT)
	add_child(_day_room)
	gauge_panel = GaugePanel.new()
	_day_room.add_child(gauge_panel)
	_place_gauge(_day_room.custom_minimum_size.x)
	loyalty_card = LoyaltyCard.new(true)
	add_child(loyalty_card)
	_spacer = Control.new()
	_spacer.name = "Spacer"
	_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_spacer)
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


## Whether the run has weeks (WeekFlow.has_weeks): the SHIFT chip hides (the desk calendar and the
## week glass say where the run is).
func show_weeks(shown: bool) -> void:
	shift_chip.visible = not shown


## Keeps LOYALTY at LOYALTY_X and the gauge's chip in the room before it: the room takes what the
## SHIFT chip (a run without weeks) leaves, and the chip fills it.
func fit_day() -> void:
	var start: float = POSITION.x
	if shift_chip.visible:
		start += fresh_width(shift_chip) + GAP
	var room: float = maxf(LOYALTY_X - GAP - start, 0.0)
	_day_room.custom_minimum_size.x = room
	_place_gauge(room)


## The gauge's chip at ShiftStage.GAUGE_PANEL_RECT's height, from its left inset in the room to
## the room's end (`room` px wide).
func _place_gauge(room: float) -> void:
	var inset: Vector2 = ShiftStage.GAUGE_PANEL_RECT.position - POSITION
	var height: float = ShiftStage.GAUGE_PANEL_RECT.size.y
	gauge_panel.place(inset, Vector2(maxf(room - inset.x, 0.0), height))


## The minimum width `control` needs now: a container learns of a child's new text or visibility
## only on the next idle frame, so every cached minimum under it is dropped first.
static func fresh_width(control: Control) -> float:
	for child: Node in control.find_children("*", "Control", true, false):
		(child as Control).update_minimum_size()
	control.update_minimum_size()
	return control.get_combined_minimum_size().x


## A teal chip (or the inspection's paper one): the frame, B2's padding, the row's height.
static func chip(frame: Texture2D) -> PanelContainer:
	var panel: PanelContainer = UiKit.frame_panel(
		frame, FramedButton.FRAME_MARGIN, Vector4(CHIP_PADDING, 0, CHIP_PADDING, 0)
	)
	panel.custom_minimum_size.y = ROW_SIZE.y
	return panel


## A chip's key caption (SHIFT, LOYALTY): the letter-spaced display font in mustard pale.
static func key_label(text: String) -> Label:
	var label: Label = UiKit.display_label(text, KEY_FONT_SIZE, false)
	label.add_theme_font_override("font", ArtStyle.spaced_display_font(KEY_SPACING))
	label.add_theme_color_override("font_color", Palette.MUSTARD_PALE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## A chip's value (5/8): the number font, no outline on the teal.
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
	guide_button = UiKit.framed_button(
		column, "Guide", _on_guide, BUTTON_FONT_SIZE, BUTTON_FRAME, Vector2(0, ROW_SIZE.y)
	)
	export_button = UiKit.framed_button(
		column, "Export log", _on_export, BUTTON_FONT_SIZE, BUTTON_FRAME, Vector2(0, ROW_SIZE.y), ""
	)
	# Internal, so the bar's children are its chips and buttons alone.
	add_child(menu, false, Node.INTERNAL_MODE_BACK)


func _on_guide() -> void:
	menu.hide()
	guide_pressed.emit()


func _on_export() -> void:
	menu.hide()
	export_pressed.emit()


func _row(panel: PanelContainer) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", CHIP_SEPARATION)
	panel.add_child(row)
	return row
