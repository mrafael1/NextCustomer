class_name ShiftStage
extends Control
## The shift screen's layout (#80, mock-up B2; full build plan section 6.1): a 1280x720 stage
## that ShiftScreen centres in the window over the store's bands that fill it
## (StoreBackdrop.screen_parts()). Every position is a stage constant taken from mock-up B2's
## layout; the stage never scales. This is B2's greybox (step 3): the regions are where B2 has
## them, drawn as flat palette fills, and the art lands region by region in later steps.
##
## On the stage, back to front: the hung monitor (MonitorView: two rods, its bezel and paper
## screen, with the LED's totals, the notices, a scanned item and the count-up on it), the register
## (RegisterCabinet, the count-up's rattle target: the printer box on the counter top and the
## register column under it, with the keypad and the cash drawer), the receipt rising from the
## printer's slot, the belt (BeltPanel: the steel guard, the rubber top face, the lip, the apron
## and the price rail, then the row of items standing on the belt with their tickets on the rail),
## the top bar (the velvet shift sign, the loyalty card, the inspection tag, Deck and Export log,
## all above RewardPanel.PRINTOUT_TOP), the capacity line and the cue on the counter under the rail,
## the hand's baskets on the steel ledge (HandBaskets: their backs, the hand in them, their fronts)
## and the shade that darkens them while counting, the controls hint along the floor, Cancel, Redraw
## and CHECKOUT on the register column and the seed line under Redraw. Over them all the scan layer
## (ScanOverlay: the scan's brackets and beam) and the popup layer, both taking no clicks. A belt or
## hand item's scan shows on the monitor (#80); the popup layer only parks the hidden scan popup,
## which opens over the offers alone, in the layer an offer's scan moves it to
## (ScanController.cover_offers).
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
## The top bar's band foot: the wall starts under it, and a scan popup never reaches it.
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
## it (MonitorView draws them). Idle, the LED (LedDisplay: caption, digits and the quota line with
## its bar) and the notices are on its screen; MonitorView lays out its other states.
const MONITOR_RECT := Rect2(372, 66, 424, 176)
const MONITOR_SCREEN_RECT := Rect2(381, 75, 406, 158)
const MONITOR_UNDER_RECT := Rect2(378, 240, 412, 8)
const ROD_RECTS: Array[Rect2] = [Rect2(430, 56, 8, 12), Rect2(730, 56, 8, 12)]
const LED_RECT := Rect2(440, 80, 288, 96)
const LED_CAPTION_RECT := Rect2(452, 84, 264, 14)
const LED_DIGITS_RECT := Rect2(452, 98, 264, 52)
const LED_QUOTA_RECT := Rect2(452, 152, 264, 22)
const NOTICE_RECT := Rect2(388, 182, 392, 44)
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
## The steel ledge in front of the counter (its art, ink outline included) and the hand in its
## baskets on it (HandRow: ItemView.BASKET_SIZE cells, from the first basket's left edge to the
## last one's right edge at the natural pitch; the baskets' rims are HandBaskets').
const LEDGE_RECT := Rect2(10, 662, 924, 34)
const HAND_RECT := Rect2(26, CAPACITY_RECT.end.y, 892, ItemView.BASKET_SIZE.y)
## Where the hand is: from the counter under the rail down to the stage's foot, left of the
## register.
const HAND_AREA := Rect2(0, 494, 944, 226)
## While the shift is counted a shade darkens the hand and its baskets (ink at this alpha, mock-up
## B2's count-up), so the belt reads first.
const COUNTING_SHADE_RECT := Rect2(0, 496, 944, 204)
const COUNTING_SHADE_ALPHA := 0.4
## The controls hint, along the floor under the ledge.
const HINT_RECT := Rect2(20, 698, 904, 20)
const HINT_TEXT := (
	"Rest the pointer on an item to scan · click or drag an item onto a slot · "
	+ "tap to skip the count, hold to fast-forward"
)
const SEED_RECT := Rect2(1062, 586, 198, 18)

const RECEIPT_PAPER := preload("res://art/frames/receipt_paper.png")
## The printer slot's steel lip with its tear teeth (art/src/scenery/printer_lip.txt), drawn 1:1
## at PRINTER_SLOT_RECT over the receipt's foot, so the paper seems to come out of the slot.
const PRINTER_LIP := preload("res://art/scenery/printer_lip.png")

var top_bar: HBoxContainer
var shift_label: Label
var quota_label: Label
var loyalty_card: LoyaltyCard
var inspection_tag: InspectionTag
var deck_button: FramedButton
var export_button: FramedButton
## The hung monitor: its rods, bezel and screen, with the LED and the notices on it.
var monitor: MonitorView
## The register: the count-up's rattle target (the same node as `cabinet`).
var register: Control
var cabinet: RegisterCabinet
## The monitor's LED: the projected total, the count-up's subtotal and the total.
var led: LedDisplay
var receipt: ReceiptView
## The printer slot's lip, over the receipt's foot (fixed: it never scrolls or shakes).
var printer_lip: TextureRect
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
## The hand's baskets on their ledge (decor): their backs under the hand, their fronts over it,
## and the shade over both while counting.
var baskets: HandBaskets
var basket_fronts: HandBaskets
var hand_shade: ColorRect
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


## The hung monitor, with the LED and the notices on its screen.
func _build_monitor() -> void:
	monitor = MonitorView.new()
	add_child(monitor)
	led = monitor.led
	notice_label = monitor.notice_label


func _build_register() -> void:
	cabinet = RegisterCabinet.new()
	add_child(cabinet)
	register = cabinet
	receipt = ReceiptView.new()
	var paper: StyleBoxTexture = ArtStyle.frame_style(RECEIPT_PAPER, 2)
	paper.set_content_margin_all(RECEIPT_PADDING)
	# The receipt's inset holds its framed line's frame past the text (ReceiptView.FRAME_OUT).
	paper.content_margin_left = RECEIPT_PADDING - ReceiptView.FRAME_OUT
	paper.content_margin_right = RECEIPT_PADDING - ReceiptView.FRAME_OUT
	receipt.add_theme_stylebox_override("panel", paper)
	ArtStyle.use_pixel_material(receipt)
	receipt.position = Vector2(RECEIPT_X, RECEIPT_BOTTOM)
	receipt.size = Vector2(RECEIPT_WIDTH, 0.0)
	add_child(receipt)
	receipt.fit_up(RECEIPT_BOTTOM, RECEIPT_TOP)
	printer_lip = UiKit.sprite(PRINTER_LIP)
	printer_lip.name = "PrinterLip"
	printer_lip.position = PRINTER_SLOT_RECT.position
	printer_lip.size = PRINTER_SLOT_RECT.size
	add_child(printer_lip)


## Darkens the hand and its baskets while the shift is counted (`counting`), or lifts the shade.
func dim_hand(counting: bool) -> void:
	hand_shade.visible = counting


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
## the hand in them, the counting shade over them, and the hint along the floor.
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
	hand = HandRow.new()
	hand.position = HAND_RECT.position
	hand.size = HAND_RECT.size
	baskets = HandBaskets.new(HandBaskets.Layer.BACK, hand)
	add_child(baskets)
	add_child(hand)
	basket_fronts = HandBaskets.new(HandBaskets.Layer.FRONT, hand)
	add_child(basket_fronts)
	hand_shade = ColorRect.new()
	hand_shade.name = "HandShade"
	hand_shade.color = Color(Palette.INK, COUNTING_SHADE_ALPHA)
	hand_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_shade.position = COUNTING_SHADE_RECT.position
	hand_shade.size = COUNTING_SHADE_RECT.size
	hand_shade.visible = false
	add_child(hand_shade)
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


## The scan layer and the popup layer (where the hidden scan popup waits) over the whole stage.
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
