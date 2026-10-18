class_name TopBar
extends HBoxContainer
## The shift screen's top bar (#80 step 10, mock-up B2): one row of teal chips on the dark teal
## band, GAP apart: SHIFT n/m, the QUOTA chip (QuotaMeter: the quota, a bar and the projected
## total, then the subtotal while counting; it takes the room left), the inspection chip (paper,
## with the mustard warning sign and "Inspection · <effect>", the name in its hover text; hidden
## on shifts without one), the
## LOYALTY chip with its stamps, the Cart button with its trolley, and the menu button (three
## drawn bars) whose menu holds Export log. Cart and the menu stay clickable behind every panel:
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
var quota_meter: QuotaMeter
var quota_label: Label
var inspection_tag: InspectionTag
var loyalty_card: LoyaltyCard
## The Cart button (the deck: "Cart" in player strings only, default 1).
var deck_button: FramedButton
var menu_button: FramedButton
## The menu's popup and its one entry.
var menu: PopupPanel
var export_button: FramedButton


func _init() -> void:
	name = "TopBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", GAP)
	position = POSITION
	size = ROW_SIZE
	var shift_chip: PanelContainer = chip(CHIP_FRAME)
	var shift_row: HBoxContainer = _row(shift_chip)
	shift_row.add_child(key_label("SHIFT"))
	shift_label = value_label(Palette.PAPER)
	shift_row.add_child(shift_label)
	add_child(shift_chip)
	var quota_chip: PanelContainer = chip(CHIP_FRAME)
	quota_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quota_meter = QuotaMeter.new()
	quota_chip.add_child(quota_meter)
	quota_label = quota_meter.quota_label
	add_child(quota_chip)
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
