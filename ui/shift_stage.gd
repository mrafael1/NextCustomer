class_name ShiftStage
extends Control
## The shift screen's layout (#80, mock-up B2; full build plan section 6.1): a 1280x720 stage
## that ShiftScreen centres in the window over the store's bands that fill it
## (StoreBackdrop.screen_parts()). Every position is a stage constant taken from mock-up B2's
## layout; the stage never scales.
##
## On the stage, back to front: the hung monitor (MonitorView: two rods, its bezel and paper screen,
## with the LED's totals, the notices, a scanned item and the count-up on it), the register
## (RegisterCabinet, the count-up's rattle target: the printer box on the counter top and the
## register column under it, with the key deck and its keys, Cancel, Redraw and CHECKOUT, the
## keypad, the seed line under Redraw and the cash drawer), the receipt rising from the printer's
## slot, the belt (BeltPanel: the steel guard, the rubber top face, the lip, the apron and the price
## rail, then the row of items standing on the belt with their tickets on the rail), the top bar
## (TopBar: the SHIFT, QUOTA, inspection and LOYALTY chips, Cart and the menu with Export log,
## all above RewardPanel.PRINTOUT_TOP), the hand's baskets on the steel ledge (HandBaskets: their
## backs, the hand in them, their fronts) and the shade that darkens them while counting.
## Over them all the scan layer (ScanOverlay: the scan's brackets and beam) and the popup layer,
## both taking no clicks. A belt or hand item's scan shows on the monitor (#80); the popup layer
## only parks the hidden scan popup, which opens over the offers alone, in the layer an offer's
## scan moves it to (ScanController.cover_offers).
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
## The top bar's band foot (TopBar's chips stand in it): the wall starts under it, and a scan
## popup never reaches it.
const TOP_BAR_BOTTOM := 56.0
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
## register column under it: the key deck (the keys, the keypad and the seed line stand on it)
## and the cash drawer.
const REGISTER_RECT := Rect2(944, 330, 336, 370)
const PRINTER_RECT := Rect2(984, 330, 264, 62)
const PRINTER_SLOT_RECT := Rect2(994, 336, 244, 8)
const COLUMN_RECT := Rect2(944, 400, 336, 300)
const DECK_RECT := Rect2(954, 412, 314, 204)
const KEYPAD_RECT := Rect2(966, 516, 88, 86)
const DRAWER_RECT := Rect2(954, 624, 314, 76)
## The receipt stands on the printer's slot (RECEIPT_BOTTOM) and grows up to RECEIPT_TOP at
## most; its lines wrap as the plan's examples do.
const RECEIPT_X := 998.0
const RECEIPT_WIDTH := 236.0
const RECEIPT_BOTTOM := 340.0
const RECEIPT_TOP := 64.0
const RECEIPT_PADDING := 8
## The keys on the register's key deck (RegisterCabinet builds them). Redraw keeps its right
## edge, so a longer caption never grows it off the column; Cancel (redraw mode only) takes the
## keypad's place, left of the seam.
const CHECKOUT_RECT := Rect2(964, 422, 296, 82)
const REDRAW_RECT := Rect2(1062, 518, 198, 54)
const CANCEL_RECT := Rect2(964, 518, 84, 54)
## The steel ledge in front of the counter (its art, ink outline included) and the hand in its
## baskets on it (HandRow: ItemView.BASKET_SIZE cells, from the first basket's left edge to the
## last one's right edge at the natural pitch; the baskets' rims are HandBaskets'). The hand
## starts 20 px under the rail's shadow: a scanned or picked basket item rises into that gap.
const LEDGE_RECT := Rect2(10, 662, 924, 34)
const HAND_RECT := Rect2(26, 514, 892, ItemView.BASKET_SIZE.y)
## Where the hand is: from the counter under the rail down to the stage's foot, left of the
## register.
const HAND_AREA := Rect2(0, 494, 944, 226)
## While the shift is counted a shade darkens the hand and its baskets (ink at this alpha, mock-up
## B2's count-up), so the belt reads first.
const COUNTING_SHADE_RECT := Rect2(0, 496, 944, 204)
const COUNTING_SHADE_ALPHA := 0.4
const SEED_RECT := Rect2(1062, 586, 198, 18)

const RECEIPT_PAPER := preload("res://art/frames/receipt_paper.png")
## The printer slot's steel lip with its tear teeth (art/src/scenery/printer_lip.txt), drawn 1:1
## at PRINTER_SLOT_RECT over the receipt's foot, so the paper seems to come out of the slot.
const PRINTER_LIP := preload("res://art/scenery/printer_lip.png")

var top_bar: TopBar
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
var notice_label: NoticeLabel
## The hand's baskets on their ledge (decor): their backs under the hand, their fronts over it,
## and the shade over both while counting.
var baskets: HandBaskets
var basket_fronts: HandBaskets
var hand_shade: ColorRect
## The register's keys (the cabinet's, so they rattle with it).
var cancel_button: RegisterKey
var redraw_button: RegisterKey
var checkout_button: RegisterKey
var hand: HandRow
var seed_label: Label


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


func _build_top_bar() -> void:
	top_bar = TopBar.new()
	add_child(top_bar)
	top_bar.deck_pressed.connect(deck_pressed.emit)
	top_bar.export_pressed.connect(export_pressed.emit)
	top_bar.quota_meter.follow(led)
	shift_label = top_bar.shift_label
	quota_label = top_bar.quota_label
	loyalty_card = top_bar.loyalty_card
	inspection_tag = top_bar.inspection_tag
	deck_button = top_bar.deck_button
	export_button = top_bar.export_button


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


## On the counter: the ledge and the baskets with the hand in them, and the counting shade over
## them.
func _build_counter() -> void:
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


## The register's keys (CHECKOUT, Redraw, Cancel in redraw mode only) and seed line, wired to the
## stage's signals. Cancel clicks; Redraw and CHECKOUT sound themselves.
func _build_keys() -> void:
	cancel_button = cabinet.cancel_key
	cancel_button.pressed.connect(func() -> void: Sfx.play_at(cancel_button, "ui_back"))
	cancel_button.pressed.connect(cancel_pressed.emit)
	redraw_button = cabinet.redraw_key
	redraw_button.pressed.connect(redraw_pressed.emit)
	checkout_button = cabinet.checkout_key
	checkout_button.pressed.connect(checkout_pressed.emit)
	seed_label = cabinet.seed_label


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
