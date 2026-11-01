class_name ShiftStage
extends Control
## The shift screen's layout (#80, mock-up B2; mirrored for #83; full build plan section 6.1): a
## 1280x720 stage that ShiftScreen centres in the window over the store's bands that fill it
## (StoreBackdrop.screen_parts()). Every position is a stage constant taken from the mirrored B2
## mock-up: the register, the printer with its receipt and the cashier stand at the left, so the
## belt runs toward them and slot 1 is the slot next to the register. The stage itself never scales.
## Machine v2 (#77, Q1 = A): the stage is two layers. `world` holds the store (the monitor, the
## RECEIPT REWARDS machine in the store at MACHINE_WALL_RECT, half size, and the `fore`: the
## register, the receipt, the belt with its row, the planning layer, the bag, the hand and its
## baskets). ShiftScreen hands it to the StoreCamera, which zooms it to 2x on the machine during its
## visits (the fore drops out of frame: set_fore_drop). The stage keeps the `hud`, which never
## zooms: the top bar, the scan layer and the popup layer. Every Rect2 below is in stage coordinates
## (the world's at 1x), except the MACHINE_* rects the camera puts on screen.  On the stage, back to
## front: the checkout cheering's standees (CheckoutCrowd, #120) on the back wall, the hung monitor
## (MonitorView: two rods, its bezel and paper screen, with the scanner bay, the item column, the
## checkout column and the notices on it), the register (RegisterCabinet, the count-up's rattle
## target: the printer box on the counter top and the register column under it, with the key deck
## and its keys, Cancel, Redraw and CHECKOUT, the keypad, the seed line under Redraw and the cash
## drawer), the receipt rising from the printer's slot, the bagging shelf behind the belt's first
## cell with the store's kraft bag on it (PaperBag, #86 v6 and #123: the counted items go in), the
## belt (BeltPanel: the steel guard, the rubber top face, the lip, the apron and the price rail,
## then the row of items standing on the belt with their tickets on the rail), the planning layer
## (PlanningLayer: #71's stickers, stamps and pay tags over the items), the top bar (TopBar: the
## SHIFT, QUOTA, inspection and LOYALTY chips, Cart and the menu with Export log, all above
## PANEL_TOP), the hand's baskets on the steel ledge (HandBaskets: their backs, the hand in them,
## the basket redraw's pop layer, their fronts, and the redraw's targets and tags, BasketTags), the
## shade that darkens them while counting and the redraw layer (the basket redraw's flights into the
## Cart and its sparks, over the top bar). Over the fore's parts the quota crossing's bonus lights
## (BonusLights) and the count's rail light (RailLight, #86 kept by #105 piece 2: the price rail lit
## gold from a giver's ticket to its target's). Over them all the quota crossing (QuotaCrossing: its
## flag, streak and lap stamps), the scan layer (ScanOverlay: the scan's brackets and beam) and the
## popup layer, all taking no clicks. A belt or hand item's scan shows on the monitor (#80); the
## popup layer only parks the hidden scan popup, which opens over the offers alone, in the layer an
## offer's scan moves it to (ScanController.cover_offers). The receipt stands on the printer's slot
## and grows up as its lines print, up to under the top bar; past that it scrolls to its newest
## line.  It only builds and lays out: the screen fills the controls, and its buttons emit the
## signals below. Its controls are public on purpose: the stage is ShiftScreen's layout part (as
## ShiftDebug is its debug part), built and owned by the screen alone, so the screen fills them
## directly instead of through a setter each. No other scene reaches into it.  The receipt never
## shakes with the register, so the dessert's slam lands on a still TOTAL line.

signal checkout_pressed
signal redraw_pressed
signal cancel_pressed
signal deck_pressed
signal export_pressed

const SIZE := Vector2(1280, 720)
## The top bar's band foot (TopBar's chips stand in it): the wall starts under it, and a scan
## popup never reaches it.
const TOP_BAR_BOTTOM := 56.0
## Where the store meets the belt's back: the counter is below it. The clean scene (#123, mock-up
## docs/art/mockups/scene_123.html, direction A) brings the belt 34 px down onto the baskets, so
## the counter reads as one surface and the store above it gets the room.
const COUNTER_TOP := 360.0
## The floor under the counter and the register: the basket ledge's foot.
const FLOOR_TOP := 708.0
## The belt, from its steel guard down to the price rail's shadow (BeltPanel draws its bands).
const BELT_RECT := Rect2(348, 348, 918, 180)
## Where the 7-slot row starts: each cell (ItemView.BELT_SIZE) stands its item on the belt's top
## face and clips its ticket on the rail. Every row rests on ROW_BOTTOM: a scaled 8-slot row
## too.
const ROW_POSITION := Vector2(364, 292)
const ROW_BOTTOM := ROW_POSITION.y + ItemView.BELT_SIZE.y
## The band the row's cells stand in: across the belt's top face, from the plaques over the items
## down to the rail's foot.
const ROW_AREA := Rect2(354, ROW_POSITION.y, 904, ItemView.BELT_SIZE.y)
## The store's kraft bag (#86 v6, redrawn for #123) on the bagging shelf at the belt's back-left
## edge, behind the scanner (its foot on the shelf, BAGGING_SHELF_RECT's top): the counted items
## hop up from the scanner into it.
const BAG_RECT := Rect2(300, 246, 72, 92)
## The steel bagging shelf the bag stands on, behind the belt's first cell (StoreBackdrop's
## counter piece, in the fore under the belt), right of the receipt printer: its 12 px plank, just
## long enough for the bag, on a steel side panel between the printer's end and the belt's frame
## (2026-11-01).
const BAGGING_SHELF_RECT := Rect2(298, 338, 88, 62)
## The monitor hung from the ceiling on two rods, its bezel and paper screen, and the shade under
## it (MonitorView draws them): its one screen (#105 piece 2) holds the scanner bay, the item
## column, the checkout column and the notices.
const MONITOR_RECT := Rect2(484, 66, 424, 176)
const MONITOR_SCREEN_RECT := Rect2(493, 75, 406, 158)
const MONITOR_UNDER_RECT := Rect2(490, 240, 412, 8)
const ROD_RECTS: Array[Rect2] = [Rect2(542, 56, 8, 12), Rect2(842, 56, 8, 12)]
## The register (RegisterCabinet): the printer box on the counter top with its slot, and the
## register column under it: the key deck (the keys, the keypad and the seed line stand on it)
## and the cash drawer.
const REGISTER_RECT := Rect2(0, 330, 336, 370)
const PRINTER_RECT := Rect2(32, 330, 264, 62)
const PRINTER_SLOT_RECT := Rect2(42, 336, 244, 8)
const COLUMN_RECT := Rect2(0, 400, 336, 300)
const DECK_RECT := Rect2(12, 412, 314, 204)
const KEYPAD_RECT := Rect2(226, 516, 88, 86)
const DRAWER_RECT := Rect2(12, 624, 314, 76)
## The receipt stands on the printer's slot (RECEIPT_BOTTOM) and grows up to RECEIPT_TOP at
## most; its lines wrap as the plan's examples do.
const RECEIPT_X := 46.0
const RECEIPT_WIDTH := 236.0
const RECEIPT_BOTTOM := 340.0
const RECEIPT_TOP := 64.0
const RECEIPT_PADDING := 8
## The keys on the register's key deck (RegisterCabinet builds them). Redraw keeps its left
## edge, so a longer caption grows it toward the keypad, never off the column; Cancel (redraw
## mode only) takes the keypad's place, right of the seam.
const CHECKOUT_RECT := Rect2(20, 422, 296, 82)
const REDRAW_RECT := Rect2(20, 518, 198, 54)
const CANCEL_RECT := Rect2(232, 518, 84, 54)
## The steel ledge in front of the counter (its art, ink outline included) and the hand in its
## baskets on it (HandRow: ItemView.BASKET_SIZE cells, from the first basket's left edge to the
## last one's right edge at the natural pitch; the baskets' rims are HandBaskets'). Since the belt
## came down onto the baskets (#123) the hand's cells start at the rail's shadow: a scanned or
## picked basket item rises over the counter face, up to the rail.
const LEDGE_RECT := Rect2(346, 674, 924, 34)
const HAND_RECT := Rect2(362, 526, 892, ItemView.BASKET_SIZE.y)
## Where the hand is: from as high as a scanned basket item rises (ItemView.BASKET_LIFT over the
## cells' top, over the rail's foot since #123) down to the stage's foot, right of the register.
const HAND_AREA := Rect2(336, 512, 944, 208)
## While the shift is counted a shade darkens the hand and its baskets (ink at this alpha, mock-up
## B2's count-up), so the belt reads first.
const COUNTING_SHADE_RECT := Rect2(336, 526, 944, 186)
const COUNTING_SHADE_ALPHA := 0.4
const SEED_RECT := Rect2(20, 586, 198, 18)
## Screen panels (the deck view, the results) and their shade stay below this line, under the top
## bar, so Cart and the menu stay reachable.
const PANEL_TOP := 64.0
## The RECEIPT REWARDS machine in the store (#77 machine v2, Q1 = A; redrawn front-on in v0.50,
## mock-up premium_machine_v1.html): the 448x568 cabinet at MACHINE_WALL_SCALE. Since the clean
## scene (#123) it stands right of the stage, out of the planning view: the camera glides to it for
## its visits, and a window wider than 16:9 shows it at the right edge. Shown all run, dimmed
## between its visits. Its marquee and bulbs stand above the rect, its plinth and shadow below it.
const MACHINE_WALL_RECT := Rect2(1330, 94, 224, 284)
const MACHINE_WALL_SCALE := 0.5
## The camera at the machine (StoreCamera): CAMERA_ZOOM, and the offset (whole pixels) that puts
## the machine at MACHINE_RECT on screen, at a net scale of 1 (crisp: 0.5 x 2).
const CAMERA_ZOOM := 2.0
## (MACHINE_RECT.position - CAMERA_ZOOM x MACHINE_WALL_RECT.position).
const CAMERA_OFFSET := Vector2(-2244, -64)
## The world (the store, the counter's and the floor's bands) runs to here on the stage: the camera
## at the machine shows stage x 1122 .. 1762.
const WORLD_RIGHT := 1800.0
## Where the camera puts the machine's cabinet on screen (stage coordinates of the unzoomed
## layers: the hud and the machine's overlay), under the top bar: the marquee's bulbs reach up to
## y 58 and the plinth's shadow down to y 714, inside the screen (v0.50: the old framing cut the
## tray off).
const MACHINE_RECT := Rect2(416, 124, 448, 568)
## The cart drawer's right edge and top (left of the machine's marquee at 2x, under the top bar).
const CART_DRAWER_RIGHT := 380.0
## The drawer never starts left of this (a four-slot drawer is wider than the room left of the
## machine: it reaches over the cabinet's left edge).
const CART_DRAWER_LEFT := 8.0
## The widest drawer's right edge (four slots from CART_DRAWER_LEFT): over the cabinet's left
## 40 px (its frame, the marquee's end and the display's left end, whose lines are centred well
## clear of it).
const CART_DRAWER_REACH := 456.0
const CART_DRAWER_TOP := 64.0
## The fore fades to this much of its alpha as it drops out of frame (mock-up: 1 - 0.9 e).
const FORE_FADE := 0.9

const RECEIPT_PAPER := preload("res://art/frames/receipt_paper.png")
## The printer slot's steel lip with its tear teeth (art/src/scenery/printer_lip.txt), drawn 1:1
## at PRINTER_SLOT_RECT over the receipt's foot, so the paper seems to come out of the slot.
const PRINTER_LIP := preload("res://art/scenery/printer_lip.png")
## The bagging shelf the bag stands on (art/src/scenery/bagging_shelf.txt), 1:1 at
## BAGGING_SHELF_RECT.
const BAGGING_SHELF := preload("res://art/scenery/bagging_shelf.png")

## The zoomed layer (StoreCamera adopts it) and, in it, the part that drops out during the glide.
var world: Control
var fore: Control
## The RECEIPT REWARDS machine on the wall (add_machine), or null.
var machine: Control
## The checkout cheering's cardboard standees (#120): over the machine, under the monitor.
var crowd: CheckoutCrowd
var top_bar: TopBar
var shift_label: Label
var quota_label: Label
var loyalty_card: LoyaltyCard
var inspection_tag: InspectionTag
var deck_button: FramedButton
var export_button: FramedButton
## The hung monitor: its rods, bezel and screen, with the register's reading (the LED) and the
## notices on it.
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
## The planning effects over the belt (#71, PlanningLayer): the items' stickers, stamps and pay
## tags, over the items and tickets and under the top bar.
var planning_layer: PlanningLayer
## The kraft bag the counted items go into (#86 v6, #123), on its shelf behind the belt.
var bag: PaperBag
## Over everything on the stage, taking no clicks: the scan's marks, and the layer the scan
## popup opens in.
## The count's rail light over the price rail (#105 piece 2), last in the fore.
var rail_light: RailLight
## The quota crossing (A, B and E over the stage) and its bonus lights on the rail (D, in the fore
## under the rail light).
var quota_crossing: QuotaCrossing
var bonus_lights: BonusLights
var scan_layer: ScanOverlay
var popup_layer: Control
var notice_label: NoticeLabel
## The hand's baskets on their ledge (decor): their backs under the hand, their fronts over it,
## and the shade over both while counting.
var baskets: HandBaskets
var basket_fronts: HandBaskets
var hand_shade: ColorRect
## The basket redraw (plan section 3.8): the baskets' click targets and REDRAW tags over the
## fronts (BasketTags), the pop layer between the hand and the fronts (the redrawn items in the
## basket, clipped at the baskets' feet) and the redraw layer over the top bar (the flights into
## the Cart and the sparks). BasketRedraw moves them.
var basket_tags: BasketTags
var pop_layer: Control
var redraw_layer: Control
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
	world = _layer("World")
	world.set_anchors_preset(Control.PRESET_CENTER)
	world.offset_left = -SIZE.x / 2.0
	world.offset_top = -SIZE.y / 2.0
	world.offset_right = SIZE.x / 2.0
	world.offset_bottom = SIZE.y / 2.0
	add_child(world)
	fore = _layer("Fore")
	crowd = CheckoutCrowd.new()
	world.add_child(crowd)
	crowd.confetti = CheerConfetti.new()
	crowd.confetti.size = SIZE
	world.add_child(crowd.confetti)
	_build_monitor()
	world.add_child(fore)
	_build_register()
	_build_belt(slot_count)
	_build_top_bar()
	_build_counter()
	_build_keys()
	_build_scan_layers()


## Follows `count_up`'s checkouts: the checkout cheering's standees (#120) and the quota
## crossing.
func follow_count(count_up: CountUp) -> void:
	crowd.follow(count_up)
	quota_crossing.follow(count_up, top_bar.quota_meter, bonus_lights)


## Puts the machine in the store right of the stage, behind the fore, at half size.
func add_machine(view: Control) -> void:
	machine = view
	world.add_child(view)
	world.move_child(view, crowd.get_index())
	view.position = MACHINE_WALL_RECT.position
	view.scale = Vector2.ONE * MACHINE_WALL_SCALE


## The fore during the camera's glide (`e`, the eased progress: 0 in planning, 1 at the machine):
## it drops `drop_px` and fades (reduced motion: it only fades out).
func set_fore_drop(e: float, reduced: bool, drop_px: float) -> void:
	fore.position.y = 0.0 if reduced else roundf(e * drop_px)
	fore.modulate.a = 1.0 - e if reduced else 1.0 - e * FORE_FADE


## The screen theme on every layer that had it before the world moved to the camera: the hud
## (the stage), the monitor and the fore. The machine keeps the default font, as before.
func apply_theme(screen_theme: Theme) -> void:
	theme = screen_theme
	monitor.theme = screen_theme
	fore.theme = screen_theme


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
	world.add_child(monitor)
	led = monitor.led
	notice_label = monitor.notice_label


func _build_register() -> void:
	cabinet = RegisterCabinet.new()
	fore.add_child(cabinet)
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
	fore.add_child(receipt)
	receipt.fit_up(RECEIPT_BOTTOM, RECEIPT_TOP)
	printer_lip = UiKit.sprite(PRINTER_LIP)
	printer_lip.name = "PrinterLip"
	printer_lip.position = PRINTER_SLOT_RECT.position
	printer_lip.size = PRINTER_SLOT_RECT.size
	fore.add_child(printer_lip)


## Darkens the hand and its baskets while the shift is counted (`counting`), or lifts the shade.
func dim_hand(counting: bool) -> void:
	hand_shade.visible = counting


func _build_belt(slot_count: int) -> void:
	# The bagging shelf and the bag on it stand behind the belt: the scanner's item is in front.
	var shelf: TextureRect = UiKit.sprite(BAGGING_SHELF)
	shelf.name = "BaggingShelf"
	shelf.position = BAGGING_SHELF_RECT.position
	shelf.size = BAGGING_SHELF_RECT.size
	fore.add_child(shelf)
	bag = PaperBag.new()
	bag.position = BAG_RECT.position
	fore.add_child(bag)
	belt = BeltPanel.new()
	belt.position = BELT_RECT.position
	belt.size = BELT_RECT.size
	fore.add_child(belt)
	# 7 slots fit the belt beside the register (plan section 3.1); a wider row scales to them.
	row_strip = RowStrip.new()
	belt.add_child(row_strip)
	row_strip.set_slot_count(slot_count)
	# The standees' shadows fall forward onto the guard's lit face, under the row's items (#120).
	crowd.lay_shadows(belt, Rect2(Vector2.ZERO, BeltPanel.TOP_RECT.size), row_strip.get_index())
	row_strip.minimum_size_changed.connect(_place_row)
	_place_row()
	# Over the items and their tickets, under the top bar, the hand and the scan layers (#71).
	planning_layer = PlanningLayer.new()
	fore.add_child(planning_layer)


## Rests the row on ROW_BOTTOM: a scaled row is shorter, so it starts lower. The scanner's plate
## goes under its first cell.
func _place_row() -> void:
	var height: float = row_strip.get_combined_minimum_size().y
	row_strip.position = Vector2(ROW_POSITION.x, ROW_BOTTOM - height) - BELT_RECT.position
	var half_cell: float = RowStrip.CELL_SIZE.x * row_strip.box.scale.x / 2.0
	belt.place_scanner(row_strip.position.x + half_cell)


## On the counter: the ledge and the baskets with the hand in them, and the counting shade over
## them.
func _build_counter() -> void:
	hand = HandRow.new()
	hand.position = HAND_RECT.position
	hand.size = HAND_RECT.size
	baskets = HandBaskets.new(HandBaskets.Layer.BACK, hand)
	fore.add_child(baskets)
	fore.add_child(hand)
	pop_layer = Control.new()
	pop_layer.name = "PopLayer"
	pop_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop_layer.clip_contents = true
	pop_layer.size = Vector2(SIZE.x, HandBaskets.FACE_FOOT_Y)
	fore.add_child(pop_layer)
	basket_fronts = HandBaskets.new(HandBaskets.Layer.FRONT, hand)
	fore.add_child(basket_fronts)
	basket_tags = BasketTags.new()
	fore.add_child(basket_tags)
	hand_shade = ColorRect.new()
	hand_shade.name = "HandShade"
	hand_shade.color = Color(Palette.INK, COUNTING_SHADE_ALPHA)
	hand_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_shade.position = COUNTING_SHADE_RECT.position
	hand_shade.size = COUNTING_SHADE_RECT.size
	hand_shade.visible = false
	fore.add_child(hand_shade)
	redraw_layer = Control.new()
	redraw_layer.name = "RedrawLayer"
	redraw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	redraw_layer.size = SIZE
	add_child(redraw_layer)


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


## The bonus lights and the rail light (last in the fore), then the quota crossing, the scan layer
## and the popup layer (where the hidden scan popup waits) over the whole stage.
func _build_scan_layers() -> void:
	bonus_lights = BonusLights.new()
	bonus_lights.size = SIZE
	fore.add_child(bonus_lights)
	rail_light = RailLight.new()
	rail_light.size = SIZE
	fore.add_child(rail_light)
	quota_crossing = QuotaCrossing.new()
	quota_crossing.size = SIZE
	add_child(quota_crossing)
	scan_layer = ScanOverlay.new()
	scan_layer.name = "ScanLayer"
	scan_layer.size = SIZE
	add_child(scan_layer)
	popup_layer = Control.new()
	popup_layer.name = "PopupLayer"
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.size = SIZE
	add_child(popup_layer)


func _layer(layer_name: String) -> Control:
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = SIZE
	return layer
