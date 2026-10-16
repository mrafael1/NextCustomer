class_name ShiftStage
extends Control
## The shift screen's layout (#55, #75; full build plan section 6.1): a 1280x720 stage that
## ShiftScreen centres in the window over the velvet wall and the marble counter that fill it
## (BoutiqueBackdrop.screen_parts()). Every position is a stage constant taken from style frame
## v2's layout; the stage never scales. On the stage, back to front: the
## register cabinet (RegisterCabinet, the count-up's rattle target: its plate, the LED with both
## totals, the key bed with the TOTAL key and the printer slot) under its pool of light, the
## receipt hanging from the printer slot and the paper pile it runs into on the counter, the belt
## (BeltPanel: on its rubber the valance, the spotlights and the belt's pool of light, then the
## row of items on their mats, its cells filling the rubber), the top bar (the velvet shift
## sign, the loyalty card, the inspection tag, the FINE GROCERIES plaque, Deck and Export log,
## all above RewardPanel.PRINTOUT_TOP), and on the counter the hand's velvet tray under its
## pool of light, the status panel (a cream inset with the capacity line, the cue and the
## notices), Cancel and Redraw (brass), CHECKOUT (velvet, gold caption) and the docked scanner,
## the hand in the tray, the controls hint in a cream inset under it, the closed purse on its
## shadow and its pool of light (static decor; #76 opens it) and the seed line. Over them all the
## scan layer (ScanOverlay: the scan's brackets, beam and posed scanner) and the popup layer
## (where ScanController opens the scan popup), both taking no clicks. The lights
## (BoutiqueBackdrop) take no clicks; the spotlights start in the top bar's gaps
## (_place_spots()).
##
## The paper pile shows only once the receipt's lines reach its top (style frame v2's rule): a
## short receipt hangs clear of the counter, with no lone strip of paper under it.
##
## The status panel makes room as it needs: while a notice shows (NoticeLabel.showing_changed)
## the notice takes both rows and the capacity line and cue hide; in redraw mode (Cancel shown)
## the panel narrows so Cancel fits before Redraw, the capacity line wraps over both rows and
## the cue hides.
##
## It only builds and lays out: the screen fills the controls, and its buttons emit the signals
## below. Its controls are public on purpose: the stage is ShiftScreen's layout part (as
## ShiftDebug is its debug part), built and owned by the screen alone, so the screen fills
## them directly instead of through a setter each. No other scene reaches into it.
##
## The receipt and the pile never shake with the register, so the dessert's slam lands on a
## still TOTAL line.

signal checkout_pressed
signal redraw_pressed
signal cancel_pressed
signal deck_pressed
signal export_pressed

const SIZE := Vector2(1280, 720)
const MARGIN := 20.0
## Where the counter's top edge is; the wall is above it. The belt and the register stand on it.
const COUNTER_TOP := 322.0
const TOP_BAR_POSITION := Vector2(20, 6)
const TOP_BAR_GAP := 14
## The top bar's foot: a belt item's scan popup flips below its item rather than reach it.
const TOP_BAR_BOTTOM := 64.0
const SIGN_PADDING := Vector4(14, 2, 14, 4)
const SIGN_FONT_SIZE := 20
const TOP_BUTTON_SIZE := Vector2(0, 44)
## The belt (a fixed size; BeltPanel draws its rails, rollers and rubber).
const BELT_RECT := Rect2(16, 68, 896, 254)
## Where the 7-slot row starts: its cells (ItemView.BELT_SIZE) fill the rubber between the
## rails and the rollers. Every row rests on ROW_BOTTOM: a scaled 8- or 9-slot row too, with
## the empty band above it.
const ROW_POSITION := Vector2(32, 76)
const ROW_BOTTOM := ROW_POSITION.y + ItemView.BELT_SIZE.y
## The scanner, docked in its cradle right of CHECKOUT: the handheld sits behind the cradle at
## one art pixel in, in its side look.
const CRADLE_RECT := Rect2(880, 330, 60, 54)
const DOCKED_OFFSET := Vector2(2, 0)
const DOCKED_SIZE := Vector2(56, 32)
## The register cabinet (RegisterCabinet) with its name plate, its LED (LedDisplay: caption,
## digits and the quota line with its bar), its key bed with the TOTAL key, and its printer
## slot, which the receipt hangs from. The plate, the LED and the key bed are REGISTER_FACE wide,
## centred on the cabinet; the TOTAL key stands in the key bed's TOTAL well (TOTAL_WELL in from
## the bed's left end, in canvas pixels).
const REGISTER_RECT := Rect2(944, 68, 320, 254)
const REGISTER_FACE := 288.0
const REGISTER_FACE_X := REGISTER_RECT.position.x + (REGISTER_RECT.size.x - REGISTER_FACE) / 2.0
const PLATE_RECT := Rect2(REGISTER_FACE_X, 76, REGISTER_FACE, 20)
const LED_RECT := Rect2(REGISTER_FACE_X, 100, REGISTER_FACE, 96)
const LED_CAPTION_RECT := Rect2(REGISTER_FACE_X + 12, 104, 264, 14)
const LED_DIGITS_RECT := Rect2(REGISTER_FACE_X + 12, 118, 264, 52)
const LED_QUOTA_RECT := Rect2(REGISTER_FACE_X + 12, 172, 264, 22)
const KEYS_RECT := Rect2(REGISTER_FACE_X, 204, REGISTER_FACE, 56)
const TOTAL_WELL := 156.0
const TOTAL_KEY_RECT := Rect2(KEYS_RECT.position.x + TOTAL_WELL, 208, 128, 48)
## The cabinet frame's width (its 9-slice margin), in canvas pixels.
const REGISTER_FRAME := RegisterCabinet.BODY_MARGIN * ArtStyle.ART_SCALE
## The printer slot spans the cabinet between its frame's inner edges, PRINTER_SLOT_GAP under
## the key bed.
const PRINTER_SLOT_GAP := 4.0
const PRINTER_SLOT_RECT := Rect2(
	REGISTER_RECT.position.x + REGISTER_FRAME,
	KEYS_RECT.position.y + KEYS_RECT.size.y + PRINTER_SLOT_GAP,
	REGISTER_RECT.size.x - 2 * REGISTER_FRAME,
	16
)
## The receipt hangs from the printer slot's mouth, RECEIPT_MOUTH_GAP inside it at each side; its
## lines wrap as the plan's examples do.
const RECEIPT_MOUTH_GAP := 6.0
const RECEIPT_ORIGIN := Vector2(
	PRINTER_SLOT_RECT.position.x + RegisterCabinet.PRINTER_SLOT_INSET + RECEIPT_MOUTH_GAP,
	PRINTER_SLOT_RECT.end.y
)
const RECEIPT_WIDTH := (
	PRINTER_SLOT_RECT.size.x - 2.0 * (RegisterCabinet.PRINTER_SLOT_INSET + RECEIPT_MOUTH_GAP)
)
const RECEIPT_PADDING := 8
## The paper pile stands on the counter here; the receipt ends at most PILE_JOIN below its top.
const PILE_BOTTOM := 706.0
const PILE_JOIN := 4.0
## The status panel on the counter (narrower in redraw mode, where Cancel takes the gap), with
## the capacity line, the cue under it and the notice over both.
const STATUS_RECT := Rect2(14, 330, 410, 52)
const STATUS_REDRAW_RECT := Rect2(14, 330, 292, 52)
const CAPACITY_RECT := Rect2(24, 334, 390, 20)
## In redraw mode the capacity line wraps over both rows (at its longest it is wider than the
## narrowed panel) and the cue makes way.
const CAPACITY_REDRAW_RECT := Rect2(24, 334, 272, 44)
const CUE_RECT := Rect2(24, 358, 390, 20)
const CUE_TEXT := "Scanned left to right →"
const NOTICE_RECT := Rect2(24, 334, 390, 44)
const NOTICE_REDRAW_RECT := Rect2(24, 334, 272, 44)
## Two lines of the notice's font run 47 px with its own leading; this pulls them into 44.
const NOTICE_LINE_SPACING := -4
## The buttons beside the status panel. Redraw keeps its right edge, so a longer caption never
## grows it into CHECKOUT.
const CANCEL_RECT := Rect2(314, 334, 104, 44)
const REDRAW_RECT := Rect2(432, 334, 228, 44)
const CHECKOUT_RECT := Rect2(668, 329, 200, 54)
const BUTTON_FONT_SIZE := 16
const CHECKOUT_FONT_SIZE := 26
## The ink outline of CHECKOUT's gold caption, in canvas pixels.
const CHECKOUT_OUTLINE := 4
## The hand's tray and the hand inside its velvet rim (style frame v2), then the bottom band: the
## controls hint's inset, the purse and the seed line. The hand's items (ItemView.TRAY_SIZE
## cells; a full hand of 8 at HandRow's natural pitch) start inside the rim, so a selected item's
## lifted sprite and its brackets stay on the tray, and the tray stops at the purse.
const TRAY_RECT := Rect2(12, 410, 916, 184)
const HAND_RECT := Rect2(22, 416, 900, 168)
## While the shift is counted the hand and its tray fade to this alpha (style frame v2), so the
## belt reads first.
const COUNTING_HAND_ALPHA := 0.7
const HINT_RECT := Rect2(14, 604, 412, 48)
## The hint's padding inside its inset, left and right.
const HINT_PADDING := 8.0
## The controls hint, on two lines (a wrap could break "fast-forward" at its hyphen).
const HINT_TEXT := (
	"Hover to scan · click or drag an item onto a slot\n"
	+ "tap to skip the count, hold to fast-forward"
)
## The customer's purse (closed, static decor; #76 opens it) on a soft ink shadow.
const PURSE_RECT := Rect2(696, 596, 224, 108)
const PURSE_SHADOW_RECT := Rect2(720, 698, 176, 8)
const PURSE_SHADOW_ALPHA := 0.25
const PURSE_SHADOW_POINTS := 24
const SEED_RECT := Rect2(20, 688, 400, 18)

const RECEIPT_PAPER := preload("res://art/frames/receipt_paper.png")
const SCANNER_CRADLE := preload("res://art/scenery/scanner_cradle.png")
const SCANNER_HANDHELD := preload("res://art/scenery/scanner_handheld.png")
const PURSE_CLOSED := preload("res://art/scenery/purse_closed.png")

var top_bar: HBoxContainer
var shift_label: Label
var quota_label: Label
var loyalty_card: LoyaltyCard
var inspection_tag: InspectionTag
## The FINE GROCERIES plaque (decor), between the spacer and Deck.
var plaque: PanelContainer
var deck_button: FramedButton
var export_button: FramedButton
## The register cabinet: the count-up's rattle target (the same node as `cabinet`).
var register: Control
var cabinet: RegisterCabinet
## The register's LED: the projected total, the count-up's subtotal and the total.
var led: LedDisplay
var paper_pile: PaperPile
var receipt: ReceiptView
## The belt under the row (a fixed size; the row rests on its bottom).
var belt: BeltPanel
var row_strip: RowStrip
## The docked scanner: its cradle with the handheld behind it (the scan layer borrows the
## handheld for a scan and docks it again).
var scanner: Control
var handheld: TextureRect
## Over everything on the stage, taking no clicks: the scan's marks and posed scanner, and the
## layer the scan popup opens in.
var scan_layer: ScanOverlay
var popup_layer: Control
## The status panel's cream inset (narrower in redraw mode) and its texts.
var status_panel: Panel
var capacity_label: Label
var cue_label: Label
var notice_label: NoticeLabel
## The hand's velvet tray, and the controls hint's cream inset under it.
var tray: PanelContainer
var hint_inset: Panel
var hint_label: Label
## The closed purse (decor) and its shadow.
var purse: TextureRect
var purse_shadow: Control
var cancel_button: FramedButton
var redraw_button: FramedButton
var checkout_button: FramedButton
var hand: HandRow
var seed_label: Label
## The belt's light canvas (the spotlights and the belt's pool of light), and the spotlights' x
## (BoutiqueBackdrop.spot_xs()), set again whenever the top bar lays out.
var _belt_lights: Control
var _spot_xs: Array[float] = BoutiqueBackdrop.SPOT_XS
## The top bar's spacer, between the inspection tag and the plaque.
var _top_bar_spacer: Control
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
	_build_register()
	_build_belt(slot_count)
	_build_top_bar()
	_build_tray()
	_build_status()
	_build_counter_top()
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
	_top_bar_spacer = Control.new()
	_top_bar_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(_top_bar_spacer)
	plaque = BoutiqueBackdrop.plaque()
	plaque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(plaque)
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
	# Sorted after its parts are placed (a longer text or the inspection tag showing moves them).
	top_bar.sort_children.connect(_place_spots)


## The spotlights' x (BoutiqueBackdrop.spot_xs() for the top bar as laid out).
func spot_xs() -> Array[float]:
	return _spot_xs


## Starts each spotlight on velvet between the top bar's visible parts.
func _place_spots() -> void:
	var parts: Array[Rect2] = []
	for child: Node in top_bar.get_children():
		var part: Control = child as Control
		if part.visible and part != _top_bar_spacer:
			parts.append(Rect2(top_bar.position + part.position, part.size))
	_spot_xs = BoutiqueBackdrop.spot_xs(parts)
	_belt_lights.queue_redraw()


func _build_register() -> void:
	cabinet = RegisterCabinet.new()
	add_child(cabinet)
	register = cabinet
	led = cabinet.led
	# Its pool of light: over the cabinet (which rattles under the still light) and under the
	# receipt, whose paper stays unlit.
	add_child(
		BoutiqueBackdrop.pool(BoutiqueBackdrop.REGISTER_LIGHT_NAME, BoutiqueBackdrop.REGISTER_LIGHT)
	)
	receipt = ReceiptView.new()
	var paper: StyleBoxTexture = ArtStyle.frame_style(RECEIPT_PAPER, 2)
	paper.set_content_margin_all(RECEIPT_PADDING)
	receipt.add_theme_stylebox_override("panel", paper)
	ArtStyle.use_pixel_material(receipt)
	receipt.position = RECEIPT_ORIGIN
	receipt.size = Vector2(RECEIPT_WIDTH, 0.0)
	add_child(receipt)
	# The pile stands on the counter under the receipt, its paper running on from the receipt's
	# foot (added after it, so its top fold covers that foot). The receipt grows to fit its lines
	# down to the pile's top, and fits again whenever the pile grows or curls. The pile shows once
	# the receipt reaches it (connected after the fit, so it sees the fitted receipt).
	paper_pile = PaperPile.new()
	add_child(paper_pile)
	paper_pile.join(receipt, PILE_BOTTOM)
	receipt.fit_mode(receipt_bottom)
	paper_pile.height_changed.connect(receipt.fit_height)
	receipt.resized.connect(_update_pile_shown)
	paper_pile.height_changed.connect(_update_pile_shown)
	_update_pile_shown()


## The lowest the receipt may end (stage coordinates): PILE_JOIN under the paper pile's top, and
## never past the pile's foot (an empty pile).
func receipt_bottom() -> float:
	return minf(PILE_BOTTOM, paper_pile.top_y() + PILE_JOIN)


## Whether the receipt's lines reach the paper pile's top: its natural foot (its size stops at
## the pile) is at or under it.
func receipt_reaches_pile() -> bool:
	return receipt.position.y + receipt.natural_height() >= paper_pile.top_y()


## Fades the hand and its tray to COUNTING_HAND_ALPHA while the shift is counted (`counting`),
## or back to full.
func dim_hand(counting: bool) -> void:
	var alpha: float = COUNTING_HAND_ALPHA if counting else 1.0
	tray.modulate.a = alpha
	hand.modulate.a = alpha


## Shows the paper pile only when it has paper and the receipt reaches it.
func _update_pile_shown() -> void:
	paper_pile.visible = paper_pile.height_px > 0.0 and receipt_reaches_pile()


func _build_belt(slot_count: int) -> void:
	belt = BeltPanel.new()
	belt.position = BELT_RECT.position
	belt.size = BELT_RECT.size
	add_child(belt)
	# On the rubber and under the row, whose value plaques hang over the valance's braid: the
	# valance (it sticks out above the belt), then the spotlights and the belt's pool of light,
	# in the stage's coordinates.
	belt.add_child(BoutiqueBackdrop.valance(BELT_RECT.position))
	_belt_lights = BoutiqueBackdrop.light_canvas(BoutiqueBackdrop.LIGHTS_NAME, BELT_RECT.position)
	_belt_lights.draw.connect(_draw_belt_lights)
	belt.add_child(_belt_lights)
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


func _draw_belt_lights() -> void:
	BoutiqueBackdrop.draw_spots(_belt_lights, _spot_xs)
	BoutiqueBackdrop.draw_pool(_belt_lights, BoutiqueBackdrop.BELT_LIGHT)


## The hand's velvet tray under its pool of light (the hand goes over both in
## _build_counter_top()). Built before the status panel and the buttons, so the light stays off
## their texts.
func _build_tray() -> void:
	tray = UiKit.frame_panel(UiKit.TRAY_FRAME, UiKit.TRAY_MARGIN)
	tray.name = "Tray"
	tray.position = TRAY_RECT.position
	tray.size = TRAY_RECT.size
	add_child(tray)
	add_child(BoutiqueBackdrop.pool(BoutiqueBackdrop.TRAY_LIGHT_NAME, BoutiqueBackdrop.TRAY_LIGHT))


func _build_status() -> void:
	# A plain cream panel: the marble's veins would run through the small text.
	status_panel = _inset(STATUS_RECT)
	status_panel.name = "StatusPanel"
	capacity_label = UiKit.body_label("", 14, Palette.INK)
	capacity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(capacity_label)
	_place_label(capacity_label, CAPACITY_RECT)
	cue_label = UiKit.body_label(CUE_TEXT, 13, Color(Palette.INK, 0.75))
	# Atkinson Hyperlegible Next has no "→".
	cue_label.add_theme_font_override("font", ArtStyle.body_font_with_symbols())
	cue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(cue_label)
	_place_label(cue_label, CUE_RECT)
	# Plain dark tomato on the cream panel (no outline), on up to two lines.
	notice_label = NoticeLabel.new()
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.add_theme_color_override("font_color", Palette.TOMATO_DARK)
	notice_label.add_theme_constant_override("outline_size", 0)
	notice_label.add_theme_constant_override("line_spacing", NOTICE_LINE_SPACING)
	add_child(notice_label)
	_place_label(notice_label, NOTICE_RECT)
	notice_label.showing_changed.connect(_lay_out_status.unbind(1))


func _build_counter_top() -> void:
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
	# Shown in redraw mode only (the screen shows it); the status panel narrows for it.
	cancel_button.visible = false
	cancel_button.visibility_changed.connect(_lay_out_status)
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
	checkout_caption.add_theme_color_override("font_color", Palette.GOLD)
	checkout_caption.add_theme_constant_override("outline_size", CHECKOUT_OUTLINE)
	scanner = Control.new()
	scanner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanner.position = CRADLE_RECT.position
	scanner.size = CRADLE_RECT.size
	add_child(scanner)
	handheld = UiKit.sprite(SCANNER_HANDHELD)
	handheld.position = DOCKED_OFFSET
	handheld.size = DOCKED_SIZE
	scanner.add_child(handheld)
	var cradle: TextureRect = UiKit.sprite(SCANNER_CRADLE)
	cradle.size = CRADLE_RECT.size
	scanner.add_child(cradle)
	hand = HandRow.new()
	hand.position = HAND_RECT.position
	hand.size = HAND_RECT.size
	add_child(hand)
	hint_inset = _inset(HINT_RECT)
	hint_inset.name = "HintInset"
	hint_label = UiKit.body_label(HINT_TEXT, 13, Color(Palette.INK, 0.8))
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(hint_label)
	_place_label(hint_label, HINT_RECT.grow_individual(-HINT_PADDING, 0, -HINT_PADDING, 0))
	add_child(
		BoutiqueBackdrop.pool(BoutiqueBackdrop.PURSE_LIGHT_NAME, BoutiqueBackdrop.PURSE_LIGHT)
	)
	purse_shadow = Control.new()
	purse_shadow.name = "PurseShadow"
	purse_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purse_shadow.position = PURSE_SHADOW_RECT.position
	purse_shadow.size = PURSE_SHADOW_RECT.size
	purse_shadow.draw.connect(_draw_purse_shadow)
	add_child(purse_shadow)
	purse = UiKit.sprite(PURSE_CLOSED)
	purse.name = "Purse"
	purse.position = PURSE_RECT.position
	purse.size = PURSE_RECT.size
	add_child(purse)
	seed_label = UiKit.body_label("", 13, Color(Palette.INK, 0.6))
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(seed_label)
	_place_label(seed_label, SEED_RECT)


## The scan layer (with the docked handheld) and the popup layer over the whole stage.
func _build_scan_layers() -> void:
	scan_layer = ScanOverlay.new()
	scan_layer.name = "ScanLayer"
	scan_layer.size = SIZE
	add_child(scan_layer)
	scan_layer.set_handheld(handheld)
	popup_layer = Control.new()
	popup_layer.name = "PopupLayer"
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.size = SIZE
	add_child(popup_layer)


## Where a scan popup may open, in global coordinates: the stage, the tray, the counter line and
## the top bar's foot, wherever the stage sits in the window.
func scan_layout() -> ScanLayout:
	var layout: ScanLayout = ScanLayout.new(
		Rect2(Vector2.ZERO, SIZE), TRAY_RECT, COUNTER_TOP, TOP_BAR_BOTTOM
	)
	return layout.transformed(get_global_transform())


## A plain cream inset at `rect` (the status panel and the hint's), taking no clicks.
func _inset(rect: Rect2) -> Panel:
	var inset: Panel = Panel.new()
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_theme_stylebox_override("panel", UiKit.inset_style())
	inset.position = rect.position
	inset.size = rect.size
	add_child(inset)
	return inset


## Plain ink caption on a brass button (Cancel, Redraw).
static func _ink_caption(button: FramedButton) -> void:
	button.caption_label().add_theme_color_override("font_color", Palette.INK)
	button.caption_label().add_theme_constant_override("outline_size", 0)


## Lays the status panel out for the redraw mode (Cancel shown) and the notice: see the class
## comment.
func _lay_out_status() -> void:
	var redraw: bool = cancel_button.visible
	var showing: bool = notice_label.is_showing()
	var panel: Rect2 = STATUS_REDRAW_RECT if redraw else STATUS_RECT
	status_panel.position = panel.position
	status_panel.size = panel.size
	_place_label(notice_label, NOTICE_REDRAW_RECT if redraw else NOTICE_RECT)
	capacity_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART if redraw else TextServer.AUTOWRAP_OFF
	)
	# Its cached minimum size is still the old mode's, which would clamp the new rect.
	capacity_label.update_minimum_size()
	_place_label(capacity_label, CAPACITY_REDRAW_RECT if redraw else CAPACITY_RECT)
	capacity_label.visible = not showing
	cue_label.visible = not showing and not redraw


## A soft ink ellipse under the purse, on the 2 px art grid.
func _draw_purse_shadow() -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var centre: Vector2 = purse_shadow.size / 2.0
	for index: int in range(PURSE_SHADOW_POINTS):
		var angle: float = TAU * index / PURSE_SHADOW_POINTS
		var point: Vector2 = centre + Vector2(cos(angle), sin(angle)) * centre
		points.append(point.snappedf(ArtStyle.ART_SCALE))
	purse_shadow.draw_colored_polygon(points, Color(Palette.INK, PURSE_SHADOW_ALPHA))


func _place_label(label: Label, rect: Rect2) -> void:
	_label_rects[label] = rect
	label.position = rect.position
	label.size = rect.size


## Redraw keeps its right edge: a caption longer than REDRAW_RECT grows it to the left.
func _keep_redraw_edge() -> void:
	redraw_button.position.x = REDRAW_RECT.end.x - redraw_button.size.x
