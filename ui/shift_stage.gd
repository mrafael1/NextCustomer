class_name ShiftStage
extends Control
## The shift screen's layout (#80, mock-up B2; full build plan section 6.1): a 1280x720 stage
## that ShiftScreen centres in the window over the store's bands that fill it
## (StoreBackdrop.screen_parts()). Every position is a stage constant taken from mock-up B2's
## layout; the stage never scales. This is B2's greybox (step 3): the regions are where B2 has
## them, drawn as flat palette fills, and the art lands region by region in later steps.
##
## On the stage, back to front: the hung monitor (two rods, its bezel and paper screen, with the
## LED's totals and the notices on it), the register (RegisterCabinet, the count-up's rattle
## target: the printer box on the counter top and the register column under it, with the keypad
## and the cash drawer), the receipt rising from the printer's slot, the belt (BeltPanel: the
## steel guard, the rubber top face, the lip, the apron and the price rail, then the row of items
## standing on the belt with their tickets on the rail), the top bar (the velvet shift sign, the
## loyalty card, the inspection tag, Deck and Export log, all above RewardPanel.PRINTOUT_TOP),
## the capacity line and the cue on the counter under the rail, the hand's baskets on the steel
## ledge with the hand in them, the controls hint along the floor, Cancel, Redraw and CHECKOUT on
## the register column and the seed line under Redraw. Over them all the scan layer (ScanOverlay:
## the scan's brackets and beam) and the popup layer (where ScanController opens the scan
## popup), both taking no clicks.
##
## The receipt stands on the printer's slot and grows up as its lines print, up to under the top
## bar; past that it scrolls to its newest line.
##
## It only builds and lays out: the screen fills the controls, and its buttons emit the signals
## below. Its controls are public on purpose: the stage is ShiftScreen's layout part (as
## ShiftDebug is its debug part), built and owned by the screen alone, so the screen fills
## them directly instead of through a setter each. No other scene reaches into it.
##
## The receipt never shakes with the register, so the dessert's slam lands on a still TOTAL
## line.

signal checkout_pressed
signal redraw_pressed
signal cancel_pressed
signal deck_pressed
signal export_pressed

const SIZE := Vector2(1280, 720)
const MARGIN := 20.0
const TOP_BAR_POSITION := Vector2(20, 6)
const TOP_BAR_GAP := 14
## The top bar's band foot: the wall starts under it, and a belt item's scan popup flips below
## its item rather than reach it.
const TOP_BAR_BOTTOM := 56.0
const SIGN_PADDING := Vector4(14, 2, 14, 4)
const SIGN_FONT_SIZE := 20
const TOP_BUTTON_SIZE := Vector2(0, 44)
## Where the wall meets the belt's back: the counter is below it.
const COUNTER_TOP := 326.0
## The floor under the counter and the register.
const FLOOR_TOP := 700.0
## The belt, from its steel guard down to the price rail's shadow (BeltPanel draws its bands).
const BELT_RECT := Rect2(14, 314, 918, 180)
## Where the 7-slot row starts: each cell (ItemView.BELT_SIZE) stands its item on the belt's top
## face and clips its ticket on the rail. Every row rests on ROW_BOTTOM: a scaled 8- or 9-slot
## row too.
const ROW_POSITION := Vector2(32, 258)
const ROW_BOTTOM := ROW_POSITION.y + ItemView.BELT_SIZE.y
## The band the row's cells stand in: across the belt's top face, from the plaques over the items
## down to the rail's foot.
const ROW_AREA := Rect2(22, ROW_POSITION.y, 904, ItemView.BELT_SIZE.y)
## The monitor hung from the ceiling on two rods, its bezel and paper screen, and the shade under
## it. The LED (LedDisplay: caption, digits and the quota line with its bar) and the notices are
## on its screen.
const MONITOR_RECT := Rect2(372, 66, 424, 176)
const MONITOR_SCREEN_RECT := Rect2(381, 75, 406, 158)
const MONITOR_UNDER_RECT := Rect2(378, 240, 412, 8)
const ROD_RECTS: Array[Rect2] = [Rect2(430, 56, 8, 12), Rect2(730, 56, 8, 12)]
const LED_RECT := Rect2(440, 80, 288, 96)
const LED_CAPTION_RECT := Rect2(452, 84, 264, 14)
const LED_DIGITS_RECT := Rect2(452, 98, 264, 52)
const LED_QUOTA_RECT := Rect2(452, 152, 264, 22)
const NOTICE_RECT := Rect2(388, 182, 392, 44)
## Two lines of the notice's font run 47 px with its own leading; this pulls them into 44.
const NOTICE_LINE_SPACING := -4
## The register (RegisterCabinet): the printer box on the counter top with its slot, and the
## register column under it with the keypad and the cash drawer and its pull.
const REGISTER_RECT := Rect2(944, 330, 336, 370)
const PRINTER_RECT := Rect2(984, 330, 264, 62)
const PRINTER_SLOT_RECT := Rect2(994, 336, 244, 8)
const COLUMN_RECT := Rect2(944, 400, 336, 300)
const KEYPAD_RECT := Rect2(964, 518, 90, 54)
const DRAWER_RECT := Rect2(954, 624, 314, 76)
const DRAWER_PULL_RECT := Rect2(1054, 660, 112, 10)
## The receipt stands on the printer's slot (RECEIPT_BOTTOM) and grows up to RECEIPT_TOP at
## most; its lines wrap as the plan's examples do.
const RECEIPT_X := 998.0
const RECEIPT_WIDTH := 236.0
const RECEIPT_BOTTOM := 340.0
const RECEIPT_TOP := 64.0
const RECEIPT_PADDING := 8
## The capacity line and the cue on the counter under the rail's shadow.
const CAPACITY_RECT := Rect2(20, 494, 600, 20)
const CUE_RECT := Rect2(628, 494, 296, 20)
const CUE_TEXT := "Scanned left to right →"
## The keys on the register column. Redraw keeps its right edge, so a longer caption never grows
## it off the column; Cancel (redraw mode only) takes the keypad's place.
const CHECKOUT_RECT := Rect2(964, 422, 296, 82)
const REDRAW_RECT := Rect2(1062, 518, 198, 54)
const CANCEL_RECT := Rect2(964, 518, 90, 54)
const BUTTON_FONT_SIZE := 16
const CHECKOUT_FONT_SIZE := 26
## The ink outline of CHECKOUT's caption, in canvas pixels.
const CHECKOUT_OUTLINE := 4
## The hand's baskets (four, two items each) on the steel ledge in front of the counter, and the
## hand over them (ItemView.TRAY_SIZE cells; a full hand of 8 at HandRow's natural pitch).
const BASKET_RECTS: Array[Rect2] = [
	Rect2(26, 576, 208, 96),
	Rect2(254, 576, 208, 96),
	Rect2(482, 576, 208, 96),
	Rect2(710, 576, 208, 96)
]
const LEDGE_RECT := Rect2(0, 664, 944, 30)
const HAND_RECT := Rect2(16, 520, 912, 168)
## Where the hand is: a hand item's scan popup opens beside it there, never above HAND_TOP.
const HAND_AREA := Rect2(0, 494, 944, 226)
const HAND_TOP := 494.0
## While the shift is counted the hand and its baskets fade to this alpha, so the belt reads
## first.
const COUNTING_HAND_ALPHA := 0.7
## The controls hint, along the floor under the ledge.
const HINT_RECT := Rect2(20, 698, 904, 20)
const HINT_TEXT := (
	"Rest the pointer on an item to scan · click or drag an item onto a slot · "
	+ "tap to skip the count, hold to fast-forward"
)
const SEED_RECT := Rect2(1062, 586, 198, 18)
const OUTLINE := 2

const RECEIPT_PAPER := preload("res://art/frames/receipt_paper.png")

var top_bar: HBoxContainer
var shift_label: Label
var quota_label: Label
var loyalty_card: LoyaltyCard
var inspection_tag: InspectionTag
var deck_button: FramedButton
var export_button: FramedButton
## The hung monitor (decor: its rods, bezel and screen; the LED and the notices are on it).
var monitor: Control
## The register: the count-up's rattle target (the same node as `cabinet`).
var register: Control
var cabinet: RegisterCabinet
## The monitor's LED: the projected total, the count-up's subtotal and the total.
var led: LedDisplay
var receipt: ReceiptView
## The belt under the row (a fixed size; the row rests on its rail).
var belt: BeltPanel
var row_strip: RowStrip
## Over everything on the stage, taking no clicks: the scan's marks, and the layer the scan
## popup opens in.
var scan_layer: ScanOverlay
var popup_layer: Control
var capacity_label: Label
var cue_label: Label
var notice_label: NoticeLabel
## The hand's baskets and their ledge (decor), faded with the hand while counting.
var baskets: Control
var hint_label: Label
var cancel_button: FramedButton
var redraw_button: FramedButton
var checkout_button: FramedButton
var hand: HandRow
var seed_label: Label
## Each label's layout rect, set again once the stage is in the tree: before that, a label's
## minimum size isn't its real one, and a label never shrinks back to its rect by itself.
var _label_rects: Dictionary[Label, Rect2] = {}


## A stage whose row starts with `slot_count` slots.
func _init(slot_count: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -SIZE.x / 2.0
	offset_top = -SIZE.y / 2.0
	offset_right = SIZE.x / 2.0
	offset_bottom = SIZE.y / 2.0
	_build_monitor()
	_build_register()
	_build_belt(slot_count)
	_build_top_bar()
	_build_counter()
	_build_keys()
	_build_scan_layers()


func _ready() -> void:
	for label: Label in _label_rects:
		label.position = _label_rects[label].position
		label.size = _label_rects[label].size


func _build_top_bar() -> void:
	top_bar = HBoxContainer.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_constant_override("separation", TOP_BAR_GAP)
	top_bar.position = TOP_BAR_POSITION
	top_bar.size = Vector2(SIZE.x - 2.0 * MARGIN, 0)
	add_child(top_bar)
	var shift_sign: PanelContainer = UiKit.frame_panel(UiKit.SIGN_VELVET_FRAME, 3, SIGN_PADDING)
	shift_sign.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(shift_sign)
	var sign_row: HBoxContainer = HBoxContainer.new()
	sign_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign_row.add_theme_constant_override("separation", 10)
	shift_sign.add_child(sign_row)
	sign_row.add_child(UiKit.display_label("SHIFT", SIGN_FONT_SIZE, true))
	shift_label = UiKit.number_label("", SIGN_FONT_SIZE, true)
	sign_row.add_child(shift_label)
	var quota_title: Label = UiKit.display_label("QUOTA", SIGN_FONT_SIZE, true)
	quota_title.custom_minimum_size.x = quota_title.get_minimum_size().x + 8
	quota_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quota_title.add_theme_color_override("font_color", Palette.GOLD)
	sign_row.add_child(quota_title)
	quota_label = UiKit.number_label("", SIGN_FONT_SIZE, true)
	quota_label.add_theme_color_override("font_color", Palette.GOLD)
	sign_row.add_child(quota_label)
	loyalty_card = LoyaltyCard.new()
	loyalty_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(loyalty_card)
	inspection_tag = InspectionTag.new()
	inspection_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(inspection_tag)
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	# The deck view and the export sound themselves.
	deck_button = UiKit.framed_button(
		top_bar, "", deck_pressed.emit, 16, UiKit.SIGN_VELVET_FRAME, TOP_BUTTON_SIZE, ""
	)
	deck_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deck_button.use_number_font()
	export_button = UiKit.framed_button(
		top_bar, "Export log", export_pressed.emit, 16, UiKit.SIGN_VELVET_FRAME, TOP_BUTTON_SIZE, ""
	)
	export_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## The hung monitor: its rods, the shade under it, its bezel and paper screen, then the LED and
## the notices on the screen.
func _build_monitor() -> void:
	monitor = Control.new()
	monitor.name = "Monitor"
	monitor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(monitor)
	for rod: Rect2 in ROD_RECTS:
		_rect_in(monitor, rod, Palette.RUBBER).name = "Rod"
	_rect_in(monitor, MONITOR_UNDER_RECT, Palette.CHARCOAL).name = "Under"
	_rect_in(monitor, MONITOR_RECT, Palette.RUBBER).name = "Bezel"
	_rect_in(monitor, MONITOR_SCREEN_RECT, Palette.PAPER).name = "Screen"
	led = LedDisplay.new()
	led.position = LED_RECT.position
	add_child(led)
	# Plain dark tomato on the paper screen (no outline), on up to two lines.
	notice_label = NoticeLabel.new()
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.add_theme_color_override("font_color", Palette.TOMATO_DARK)
	notice_label.add_theme_constant_override("outline_size", 0)
	notice_label.add_theme_constant_override("line_spacing", NOTICE_LINE_SPACING)
	add_child(notice_label)
	_place_label(notice_label, NOTICE_RECT)


func _build_register() -> void:
	cabinet = RegisterCabinet.new()
	add_child(cabinet)
	register = cabinet
	receipt = ReceiptView.new()
	var paper: StyleBoxTexture = ArtStyle.frame_style(RECEIPT_PAPER, 2)
	paper.set_content_margin_all(RECEIPT_PADDING)
	receipt.add_theme_stylebox_override("panel", paper)
	ArtStyle.use_pixel_material(receipt)
	receipt.position = Vector2(RECEIPT_X, RECEIPT_BOTTOM)
	receipt.size = Vector2(RECEIPT_WIDTH, 0.0)
	add_child(receipt)
	receipt.fit_up(RECEIPT_BOTTOM, RECEIPT_TOP)


## Fades the hand and its baskets to COUNTING_HAND_ALPHA while the shift is counted
## (`counting`), or back to full.
func dim_hand(counting: bool) -> void:
	var alpha: float = COUNTING_HAND_ALPHA if counting else 1.0
	baskets.modulate.a = alpha
	hand.modulate.a = alpha


func _build_belt(slot_count: int) -> void:
	belt = BeltPanel.new()
	belt.position = BELT_RECT.position
	belt.size = BELT_RECT.size
	add_child(belt)
	# 7 slots fit the belt beside the register (plan section 3.1); a wider row scales to them.
	row_strip = RowStrip.new()
	belt.add_child(row_strip)
	row_strip.set_slot_count(slot_count)
	row_strip.minimum_size_changed.connect(_place_row)
	_place_row()


## Rests the row on ROW_BOTTOM: a scaled row is shorter, so it starts lower.
func _place_row() -> void:
	var height: float = row_strip.get_combined_minimum_size().y
	row_strip.position = Vector2(ROW_POSITION.x, ROW_BOTTOM - height) - BELT_RECT.position


## On the counter: the capacity line and the cue under the rail, the ledge and the baskets with
## the hand in them, and the hint along the floor.
func _build_counter() -> void:
	capacity_label = UiKit.body_label("", 14, Palette.CREAM)
	capacity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(capacity_label)
	_place_label(capacity_label, CAPACITY_RECT)
	cue_label = UiKit.body_label(CUE_TEXT, 13, Color(Palette.CREAM, 0.8))
	# Atkinson Hyperlegible Next has no "→".
	cue_label.add_theme_font_override("font", ArtStyle.body_font_with_symbols())
	cue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(cue_label)
	_place_label(cue_label, CUE_RECT)
	baskets = Control.new()
	baskets.name = "Baskets"
	baskets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(baskets)
	_rect_in(baskets, LEDGE_RECT, Palette.STEEL).name = "Ledge"
	for rect: Rect2 in BASKET_RECTS:
		_rect_in(baskets, rect, Palette.TEAL).name = "Basket"
	hand = HandRow.new()
	hand.position = HAND_RECT.position
	hand.size = HAND_RECT.size
	add_child(hand)
	hint_label = UiKit.body_label(HINT_TEXT, 13, Color(Palette.CREAM, 0.8))
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(hint_label)
	_place_label(hint_label, HINT_RECT)


## The keys on the register column: CHECKOUT, Redraw, Cancel (redraw mode only), and the seed
## line under Redraw.
func _build_keys() -> void:
	cancel_button = UiKit.framed_button(
		self,
		"Cancel",
		cancel_pressed.emit,
		BUTTON_FONT_SIZE,
		UiKit.BUTTON_BRASS_FRAME,
		CANCEL_RECT.size,
		"ui_back"
	)
	cancel_button.position = CANCEL_RECT.position
	_ink_caption(cancel_button)
	# Shown in redraw mode only (the screen shows it).
	cancel_button.visible = false
	# The redraw and CHECKOUT sound themselves.
	redraw_button = UiKit.framed_button(
		self,
		"",
		redraw_pressed.emit,
		BUTTON_FONT_SIZE,
		UiKit.BUTTON_BRASS_FRAME,
		REDRAW_RECT.size,
		""
	)
	redraw_button.use_number_font()
	_ink_caption(redraw_button)
	redraw_button.position = REDRAW_RECT.position
	redraw_button.resized.connect(_keep_redraw_edge)
	checkout_button = UiKit.framed_button(
		self,
		"CHECKOUT",
		checkout_pressed.emit,
		CHECKOUT_FONT_SIZE,
		UiKit.BUTTON_VELVET_FRAME,
		CHECKOUT_RECT.size,
		""
	)
	checkout_button.position = CHECKOUT_RECT.position
	var checkout_caption: Label = checkout_button.caption_label()
	checkout_caption.add_theme_color_override("font_color", Palette.PAPER)
	checkout_caption.add_theme_constant_override("outline_size", CHECKOUT_OUTLINE)
	seed_label = UiKit.body_label("", 12, Color(Palette.CREAM_SHADE, 0.85))
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(seed_label)
	_place_label(seed_label, SEED_RECT)


## The scan layer and the popup layer over the whole stage.
func _build_scan_layers() -> void:
	scan_layer = ScanOverlay.new()
	scan_layer.name = "ScanLayer"
	scan_layer.size = SIZE
	add_child(scan_layer)
	popup_layer = Control.new()
	popup_layer.name = "PopupLayer"
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.size = SIZE
	add_child(popup_layer)


## Where a scan popup may open, in global coordinates: the stage, the hand's area, the top of it
## and the top bar's foot, wherever the stage sits in the window.
func scan_layout() -> ScanLayout:
	var layout: ScanLayout = ScanLayout.new(
		Rect2(Vector2.ZERO, SIZE), HAND_AREA, HAND_TOP, TOP_BAR_BOTTOM
	)
	return layout.transformed(get_global_transform())


## A flat `color` rect with an ink outline at `rect` (stage coordinates) in `parent`, which
## stands at the stage's origin; it takes no clicks.
static func _rect_in(parent: Control, rect: Rect2, color: Color) -> Panel:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Palette.INK
	style.set_border_width_all(OUTLINE)
	var panel: Panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	panel.position = rect.position
	panel.size = rect.size
	parent.add_child(panel)
	return panel


## Plain ink caption on a brass button (Cancel, Redraw).
static func _ink_caption(button: FramedButton) -> void:
	button.caption_label().add_theme_color_override("font_color", Palette.INK)
	button.caption_label().add_theme_constant_override("outline_size", 0)


func _place_label(label: Label, rect: Rect2) -> void:
	_label_rects[label] = rect
	label.position = rect.position
	label.size = rect.size


## Redraw keeps its right edge: a caption longer than REDRAW_RECT grows it to the left.
func _keep_redraw_edge() -> void:
	redraw_button.position.x = REDRAW_RECT.end.x - redraw_button.size.x
