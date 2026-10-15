class_name StyleFrameV2
extends Control
## Style frame v2 (issue #75, for #55): three states of the shift screen in the "warm boutique"
## look (velvet wall, marble counter, brass and gold), with items in place of cards: planning,
## a frozen moment of the count-up and the scan popup. A static debug scene for review; the real
## shift screen, Palette, ShiftStage, core/ and data/ stay unchanged.
##
## What is real (StyleFrameFixture): the screen capture's fixture, the cards, upgrades and
## inspection from data/, the scores from Scoring.score (plaques, the LED, chips, the receipt and
## the stub's fizzle count), the limits from ShiftLimits and RowCapacity, the quota, the paper
## pile's heights and the build label. What is mocked: the hovered item, the frozen count-up step,
## the scanner's poses and lifts, Deck 13/15, the hand's alpha while counting, CHECKOUT disabled,
## the TOTAL key down and the customer's purse (#76) opening while counting (a mood prop: no text,
## no number). Nothing animates and nothing is saved or logged. Round 2 (delta file): items at
## 48x48 shown at 96 px on mats on a rubber belt (BeltView), the strip's status panel, the hint
## and the purse under the tray, the register's keys (RegisterView), and the paper pile shown
## only once the receipt reaches the counter, joined to its foot. Round 3: a hand item's popup
## opens beside it and never covers the belt, a chunky pistol-grip scanner, the belt's velvet
## valance, ceiling spotlights and a brass-rimmed plaque on the wall, and bigger key digits.
##
## Keys: 1-4 show PLANNING, COUNT_UP, SCAN and SCAN_BELT (a hovered belt item, for review); S
## switches between the sharp-pixel shader and plain nearest filtering (A/B).
## `godot --path . [--resolution 1920x1080] res://debug/style_frame_v2/style_frame_v2.tscn --
## --capture=docs/art` saves style_frame_v2_<planning|count_up|scan>_<w>x<h>.png at the window's
## size, then quits (--capture-belt also saves scan_belt, for review only).

enum State { PLANNING, COUNT_UP, SCAN, SCAN_BELT }

const FIXTURE := preload("res://debug/style_frame_v2/frame_fixture.gd")
## The hovered items: hand item 2 (Banana) in SCAN, belt cell 3 (Multipack) in SCAN_BELT.
const SCAN_HAND_INDEX := 2
const SCAN_BELT_INDEX := 3
const STATE_NAMES: Array[String] = ["planning", "count_up", "scan", "scan_belt"]
const CAPTURE_ARGUMENT := "--capture="
const CAPTURE_BELT_ARGUMENT := "--capture-belt"
const CAPTURE_SETTLE_FRAMES := 12

# --- The palette's colours this scene draws with (art/src/palette.txt; a test compares them).
const INK := Color("2b2420")
const INK_LIGHT := Color("4a3f38")
const GREY_DARK := Color("5e574d")
const GREY := Color("8a8172")
const GREY_LIGHT := Color("c7beab")
const CREAM_SHADE := Color("ddcba5")
const CREAM := Color("f3e9d2")
const PAPER := Color("fbf7ee")
const TOMATO_DARK := Color("a83a3c")
const TOMATO := Color("d9534f")
const MUSTARD_LIGHT := Color("f1d27a")
const MUSTARD_PALE := Color("faecbc")
const BRASS_DARKEST := Color("4a3010")
const BRASS_DARK := Color("8a5d1a")
const BRASS := Color("c8932b")
const GOLD := Color("ffcf3f")
const VELVET_DARKEST := Color("2a0e14")
const VELVET_DARK := Color("561327")
const VELVET := Color("8a1f33")
const VELVET_SHEEN := Color("b23a55")
## Each colour above by its palette key.
const PALETTE := {
	"#": INK,
	"%": INK_LIGHT,
	"=": GREY_DARK,
	"-": GREY,
	":": GREY_LIGHT,
	"b": CREAM_SHADE,
	"c": CREAM,
	"w": PAPER,
	"r": TOMATO_DARK,
	"R": TOMATO,
	"y": MUSTARD_LIGHT,
	"Y": MUSTARD_PALE,
	"k": BRASS_DARKEST,
	"l": BRASS_DARK,
	"L": BRASS,
	"n": GOLD,
	"v": VELVET_DARKEST,
	"V": VELVET_DARK,
	"x": VELVET,
	"X": VELVET_SHEEN,
}

# --- Layout (spec section 3; round 2, delta sections 2 to 8), in stage pixels.
const STAGE_SIZE := Vector2(1280, 720)
## The window's middle is the stage's (the stage is centred); the backdrop's bands are placed
## from it.
const STAGE_MIDDLE := 360.0
const COUNTER_TOP := 322.0
const PICTURE_RAIL := Rect2(0, 62, 1280, 4)
const COUNTER_EDGE := Rect2(0, 322, 1280, 6)
const KICKPLATE := Rect2(0, 708, 1280, 12)
## Spotlights (centre, radii): three hard bands of mustard pale, outermost first. The belt, the
## register, the tray and the purse.
const LIGHTS: Array[Rect2] = [
	Rect2(464, 195, 440, 127),
	Rect2(1104, 150, 180, 120),
	Rect2(470, 502, 450, 92),
	Rect2(808, 650, 120, 56),
]
const LIGHT_BANDS: Array[float] = [1.0, 0.72, 0.44]
const LIGHT_ALPHAS: Array[float] = [0.04, 0.07, 0.10]
const LIGHT_POINTS := 48
const TOP_BAR_BOTTOM := 64.0
const SIGN_RECT := Rect2(20, 6, 262, 46)
const SIGN_PADDING := Vector4(14, 2, 14, 4)
const SIGN_FONT_SIZE := 20
const SIGN_SHIFT := "SHIFT"
## The gap between SHIFT and its number.
const SIGN_WORD_GAP := 8
const LOYALTY_POSITION := Vector2(296, 7)
const TAG_POSITION := Vector2(522, 14)
const DECK_RECT := Rect2(1036, 6, 110, 44)
const EXPORT_RECT := Rect2(1158, 6, 102, 44)
const BUTTON_FONT_SIZE := 16
## The belt (BeltView): its rails, rollers and rubber, and its cells.
const BELT_RECT := Rect2(16, 68, 896, 254)
const CELL_ORIGIN := Vector2(32, 76)
const CELL_PITCH := 124.0
## The strip under the counter edge: the status panel (capacity, cue, notice), Redraw, CHECKOUT
## and the scanner's cradle.
const STATUS_RECT := Rect2(14, 330, 424, 54)
const CAPACITY_RECT := Rect2(24, 334, 404, 20)
const CAPACITY_SIZE := 14
const CUE_RECT := Rect2(24, 358, 180, 20)
const CUE_TEXT := "Scanned left to right →"
const NOTICE_RECT := Rect2(212, 358, 216, 22)
const HINT_RECT := Rect2(20, 608, 400, 40)
const HINT_TEXT := (
	"Hover to scan · click or drag an item onto a slot\n"
	+ "tap to skip the count, hold to fast-forward"
)
## Plain cream insets with a cream-shade edge behind the status and the hint, off the marble's
## veins.
const HINT_INSET := Rect2(14, 604, 412, 48)
const INSET_EDGE := 2
const BODY_SIZE := 13
const REDRAW_RECT := Rect2(452, 336, 208, 44)
const CHECKOUT_RECT := Rect2(668, 330, 200, 54)
const CHECKOUT_SIZE := 26
const CHECKOUT_OUTLINE := 4
const CRADLE_RECT := Rect2(876, 330, 60, 54)
## The docked scanner sits behind the cradle at art offset (1, 0), in its side look: its head and
## window above the low cup, its grip slanting down into it.
const DOCKED_OFFSET := Vector2(2, 0)
const DOCKED_SIZE := Vector2(56, 32)
const TRAY_RECT := Rect2(12, 410, 916, 184)
const TRAY_MARGIN := 6
## The tray's velvet rim, in canvas pixels: the cells stay inside it.
const TRAY_RIM := 6.0
const TRAY_CELL_ORIGIN := Vector2(22, 416)
const TRAY_PITCH := 112.0
const COUNTING_HAND_ALPHA := 0.7
## The rich customer's purse (#76) on the counter: a mood prop that opens while counting. It
## shows no text and no number, and calculates nothing.
const PURSE_RECT := Rect2(696, 596, 224, 108)
const PURSE_SHADOW := Rect2(720, 698, 176, 8)
const SHADOW_ALPHA := 0.25
const SHADOW_POINTS := 24
const REGISTER_RECT := Rect2(944, 68, 320, 254)
const REGISTER_MARGIN := 4
const REGISTER_FOOT_MARGIN := 6
const RECEIPT_RECT := Rect2(966, 280, 276, 0)
const RECEIPT_MARGIN := 2
const RECEIPT_PADDING := 8
## The planning stub ends above the tray.
const STUB_MAX_BOTTOM := 412.0
const STUB_HEADER := "NEXT CUSTOMER · REG 3"
const STUB_SHIFT := "SHIFT %d/%d · %d ITEMS"
const STUB_TOTAL := "PROJECTED"
## The stub's dashed rule above PROJECTED (in place of the TOTAL line's solid rule).
const STUB_RULE_DASH := 4.0
const COUNT_CAPTION := "SUBTOTAL"
const STUB_FIZZLES := "%d fizzles · see the items"
const STUB_FIZZLE := "1 fizzle · see the item"
## The paper pile: once the receipt reaches it, the receipt runs into it, the pile's top fold
## covering the receipt paper's bottom edge (PILE_JOIN); it spans the receipt (x, width) and
## stands on the counter line.
const PILE_JOIN := 4.0
const PILE_SPAN := Vector2(966, 276)
const PILE_BOTTOM := 706.0
const SEED_RECT := Rect2(20, 692, 400, 14)
const SEED_SIZE := 12
## The receipt's combo line: one faint gold band behind the whole line with a gold bar on its
## left, and the diamond after the bar; the line's text is indented past both (every wrapped
## line too), so nothing sits outside the receipt's scroll area.
const COMBO_BAR := 2.0
const COMBO_BAND_ALPHA := 0.25
const COMBO_ICON_RECT := Rect2(4, 3, 10, 10)
const COMBO_INDENT := 18.0

const WALL := preload("res://art/scenery/wall_velvet.png")
const MARBLE := preload("res://art/scenery/marble_tile.png")
const SIGN_FRAME := preload("res://art/frames/sign_velvet.png")
const BUTTON_VELVET := preload("res://art/frames/button_velvet.png")
const BUTTON_BRASS := preload("res://art/frames/button_brass.png")
const TRAY_FRAME := preload("res://art/frames/tray.png")
const REGISTER_FRAME := preload("res://art/frames/register_v2.png")
const PURSE_CLOSED := preload("res://art/scenery/purse_closed.png")
const PURSE_OPEN := preload("res://art/scenery/purse_open.png")
const CRADLE := preload("res://art/scenery/scanner_cradle.png")
const SCANNER := preload("res://art/scenery/scanner_handheld.png")
const RECEIPT_PAPER := preload("res://art/frames/receipt_paper.png")
const COMBO_DIAMOND := preload("res://art/icons/combo_diamond.png")

## Where capture() reports a failed save (push_error by default), so tests never print errors.
var report_error: Callable = Callable()
## Grabs the screen for capture() (the viewport's image by default; tests pass their own).
var grab_image: Callable = Callable()

var _state: State = State.PLANNING
var _sharp: bool = true
var _next_id: int = 1
var _stage: Control
var _belt: BeltView
var _register: RegisterView
var _belt_views: Array[ItemView] = []
var _hand_views: Array[ItemView] = []
var _belt_cells: Array[Control] = []
var _receipt: ReceiptView
## The pile's height once the receipt reaches the counter (count_up.tres, through the fixture).
var _pile_height: float = 0.0
var _purse: TextureRect
var _step_lines: Array[Control] = []
var _combo_line: Control
var _stub_total: Label
var _led: LedTotal
var _pile: ReceiptPile
var _popup: ScanPopup
var _scanner: TextureRect
var _overlay: ScanOverlay
var _checkout: FramedButton
var _result: ScoreResult
var _row: Array[CardInstance] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	show_state(State.PLANNING)
	var folder: String = _capture_folder()
	if folder != "":
		var states: Array[State] = [State.PLANNING, State.COUNT_UP, State.SCAN]
		if OS.get_cmdline_user_args().has(CAPTURE_BELT_ARGUMENT):
			states.append(State.SCAN_BELT)
		await capture(folder, states)
		get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			show_state(State.PLANNING)
		KEY_2:
			show_state(State.COUNT_UP)
		KEY_3:
			show_state(State.SCAN)
		KEY_4:
			show_state(State.SCAN_BELT)
		KEY_S:
			_sharp = not _sharp
			ArtStyle.set_sharp(self, _sharp)
		_:
			return
	get_viewport().set_input_as_handled()


## Shows one state, rebuilding the stage from the fixture.
func show_state(state: State) -> void:
	_state = state
	if _stage != null:
		remove_child(_stage)
		_stage.queue_free()
	_belt_views.clear()
	_hand_views.clear()
	_belt_cells.clear()
	_step_lines.clear()
	_combo_line = null
	_stub_total = null
	_popup = null
	_next_id = 1
	var counting: bool = state == State.COUNT_UP
	_row = _cards(FIXTURE.COUNT_UP_ROW_IDS if counting else FIXTURE.CAPTURE.ROW_IDS)
	var hand: Array[CardInstance] = _cards(
		FIXTURE.COUNT_UP_HAND_IDS if counting else FIXTURE.CAPTURE.HAND_IDS
	)
	_result = Scoring.score(_row, FIXTURE.upgrades(), FIXTURE.inspections())
	_build_stage()
	_build_belt(counting)
	_build_strip(counting)
	_build_tray(hand, counting)
	_build_purse(counting)
	_build_register(counting)
	_build_receipt(counting)
	_overlay = _rect_node(ScanOverlay.new(), Rect2(Vector2.ZERO, STAGE_SIZE)) as ScanOverlay
	_overlay.name = "ScanLayer"
	_rect_node(Control.new(), Rect2(Vector2.ZERO, STAGE_SIZE)).name = "PopupLayer"
	_build_top_bar()
	match state:
		State.COUNT_UP:
			_pose_scan(_belt_views[FIXTURE.COUNT_UP_SLOT], GOLD, false)
		State.SCAN:
			_pose_scan(_hand_views[SCAN_HAND_INDEX], TOMATO, true)
		State.SCAN_BELT:
			_pose_scan(_belt_views[SCAN_BELT_INDEX], TOMATO, true)
	if not _sharp:
		ArtStyle.set_sharp(_stage, false)


## The 1280x720 stage everything is laid out on.
func stage() -> Control:
	return _stage


## A belt item (`on_belt`, by slot) or a hand item (by hand position), or null.
func item_view(on_belt: bool, index: int) -> ItemView:
	var views: Array[ItemView] = item_views(on_belt)
	return views[index] if index >= 0 and index < views.size() else null


## The belt items or the hand items now shown.
func item_views(on_belt: bool) -> Array[ItemView]:
	return _belt_views if on_belt else _hand_views


## The belt's cells (an item, an empty open slot's mat or the CLOSED cell), left to right.
func belt_cells() -> Array[Control]:
	return _belt_cells


## The rich customer's purse (#76).
func purse() -> TextureRect:
	return _purse


func receipt() -> ReceiptView:
	return _receipt


## The receipt lines printed for steps[0..k] in COUNT_UP (add_step's non-null lines).
func step_lines() -> Array[Control]:
	return _step_lines


## The stub's PROJECTED amount (PLANNING and the scans), or null.
func stub_total() -> Label:
	return _stub_total


## The receipt line marked as the combo line (COUNT_UP), or null.
func combo_line() -> Control:
	return _combo_line


## The belt: its rubber, rails and rollers, its mats and its CLOSED cells.
func belt() -> BeltView:
	return _belt


## The register's front: the LED, the keys and the printer slot.
func register() -> RegisterView:
	return _register


func pile() -> ReceiptPile:
	return _pile


## The scan popup (SCAN and SCAN_BELT), or null.
func popup() -> ScanPopup:
	return _popup


## The handheld scanner: docked behind its cradle, or at the scanned item.
func scanner() -> TextureRect:
	return _scanner


## The scan's brackets and beam.
func overlay() -> ScanOverlay:
	return _overlay


func checkout_button() -> FramedButton:
	return _checkout


## The score shown: the row's ScoreResult.
func result() -> ScoreResult:
	return _result


## The step index the count-up is frozen at: the first step of COUNT_UP_SLOT.
func frozen_step() -> int:
	var indices: PackedInt32Array = EffectChip.step_indices(_result, FIXTURE.COUNT_UP_SLOT)
	return indices[0] if not indices.is_empty() else _result.steps.size() - 1


## Shows each of `states` in turn and saves it into `folder` as
## style_frame_v2_<state>_<w>x<h>.png. A failed save goes to report_error.
func capture(folder: String, states: Array[State]) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for state: State in states:
		show_state(state)
		for _frame: int in range(CAPTURE_SETTLE_FRAMES):
			# A headless run (the tests) draws nothing, so it waits for frames instead.
			if DisplayServer.get_name() == "headless":
				await get_tree().process_frame
			else:
				await RenderingServer.frame_post_draw
		var window: Vector2i = get_window().size
		var path: String = folder.path_join(
			"style_frame_v2_%s_%dx%d.png" % [STATE_NAMES[state], window.x, window.y]
		)
		var image: Image = (
			grab_image.call() as Image
			if grab_image.is_valid()
			else get_viewport().get_texture().get_image()
		)
		var error: Error = ERR_UNAVAILABLE if image == null else image.save_png(path)
		if error != OK:
			if report_error.is_valid():
				report_error.call("Can't save %s (error %d)" % [path, error])
			else:
				push_error("Can't save %s (error %d)" % [path, error])


# --- Building --------------------------------------------------------------------------------


func _cards(ids: Array[String]) -> Array[CardInstance]:
	var found: Array[CardInstance] = []
	for card_id: String in ids:
		found.append(CardInstance.new(FIXTURE.card(card_id), _next_id))
		_next_id += 1
	return found


## The wall, counter, rails and kickplate fill the window behind the stage (the stage is centred,
## so its middle is the window's; the counter line sits COUNTER_TOP - STAGE_MIDDLE from it).
func _build_backdrop() -> void:
	var wall: TextureRect = UiKit.tiled(WALL)
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall.anchor_bottom = 0.5
	wall.offset_bottom = COUNTER_TOP - STAGE_MIDDLE
	add_child(wall)
	var counter: TextureRect = UiKit.tiled(MARBLE)
	counter.set_anchors_preset(Control.PRESET_FULL_RECT)
	counter.anchor_top = 0.5
	counter.offset_top = COUNTER_TOP - STAGE_MIDDLE
	add_child(counter)
	add_child(_band(RegisterView.rail(PICTURE_RAIL.size.y), PICTURE_RAIL))
	add_child(_band(RegisterView.rail(COUNTER_EDGE.size.y), COUNTER_EDGE))
	var kickplate: ColorRect = ColorRect.new()
	kickplate.color = VELVET_DARK
	kickplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band(kickplate, KICKPLATE))


## Spans `item` across the window at the stage's `rect` rows.
func _band(item: Control, rect: Rect2) -> Control:
	item.anchor_left = 0.0
	item.anchor_right = 1.0
	item.anchor_top = 0.5
	item.anchor_bottom = 0.5
	item.offset_top = rect.position.y - STAGE_MIDDLE
	item.offset_bottom = rect.end.y - STAGE_MIDDLE
	return item


## The stage and its fixed scenery: the belt and its valance, the status and hint panels, the
## tray's frame, the register's cabinet and the spotlights over them.
func _build_stage() -> void:
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.theme = UiKit.screen_theme()
	_stage.set_anchors_preset(Control.PRESET_CENTER)
	_stage.size = STAGE_SIZE
	_stage.position = -STAGE_SIZE / 2.0
	add_child(_stage)
	_belt = _rect_node(BeltView.new(), BELT_RECT) as BeltView
	_belt.name = "Belt"
	# Plain cream panels: the marble's veins and specks would run through their small text.
	_rect_node(_inset(), STATUS_RECT).name = "StatusPanel"
	_rect_node(_inset(), HINT_INSET).name = "HintInset"
	_rect_node(UiKit.frame_panel(TRAY_FRAME, TRAY_MARGIN), TRAY_RECT).name = "TrayFrame"
	var cabinet: PanelContainer = UiKit.frame_panel(REGISTER_FRAME, REGISTER_MARGIN)
	var style: StyleBoxTexture = cabinet.get_theme_stylebox("panel") as StyleBoxTexture
	style.texture_margin_bottom = REGISTER_FOOT_MARGIN * ArtStyle.ART_SCALE
	_rect_node(cabinet, REGISTER_RECT).name = "Register"
	_rect_node(BoutiqueDecor.valance(), BoutiqueDecor.VALANCE_RECT).name = "Valance"
	var lights: Control = _rect_node(Control.new(), Rect2(Vector2.ZERO, STAGE_SIZE))
	lights.name = "Lights"
	lights.draw.connect(_draw_lights.bind(lights))


## The belt's cells (delta section 3): every open cell's mat (BeltView.mat_kinds), the row's
## items on theirs, an engraved slot number on each empty mat, and the CLOSED cells.
func _build_belt(counting: bool) -> void:
	var frozen: int = frozen_step() if counting else _result.steps.size() - 1
	var kinds: Array[int] = BeltView.mat_kinds(FIXTURE.limits(), _row)
	var grounds: Array[Control] = _belt.lay_out(
		kinds, _row.size(), _closing_name(false), _closing_name(true)
	)
	for cell: int in range(kinds.size()):
		if cell >= _row.size():
			_belt_cells.append(grounds[cell])
			continue
		var view: ItemView = _item(_row[cell], true)
		view.position = CELL_ORIGIN + Vector2(cell * CELL_PITCH, 0)
		_stage.add_child(view)
		_belt_views.append(view)
		_belt_cells.append(view)
		if not counting or _payout_printed(cell, frozen):
			view.show_payout(_result.payouts[cell])
		_add_chips(view, cell, frozen)


func _item(instance: CardInstance, on_belt: bool) -> ItemView:
	var definition: CardDefinition = instance.definition
	return ItemView.new(
		instance,
		on_belt,
		FIXTURE.BALANCE.aisle_of(definition),
		FIXTURE.STICKERS.summary(definition)
	)


func _payout_printed(slot: int, frozen: int) -> bool:
	for index: int in range(frozen + 1):
		var step: ScoreStep = _result.steps[index]
		if step.step_type == ScoreStep.StepType.PAYOUT and step.slot == slot:
			return true
	return false


## The chips of `slot`'s steps (at most EffectChip.MAX_PER_CELL, the rest folded into the last
## as "+N more"); a chip whose step comes after the `frozen` one is dimmed.
func _add_chips(view: ItemView, slot: int, frozen: int) -> void:
	var indices: PackedInt32Array = EffectChip.step_indices(_result, slot)
	for place: int in range(mini(indices.size(), EffectChip.MAX_PER_CELL)):
		var step: ScoreStep = _result.steps[indices[place]]
		var text: String = EffectChip.chip_text(
			step,
			FIXTURE.names(_row),
			FIXTURE.upgrade_names(),
			FIXTURE.inspection_names(),
			EffectChip.font(),
			EffectChip.FONT_SIZE
		)
		var fizzle: bool = step.step_type == ScoreStep.StepType.WASTED
		if place == EffectChip.MAX_PER_CELL - 1 and indices.size() > EffectChip.MAX_PER_CELL:
			text = EffectChip.MORE_TEXT % (indices.size() - place)
			fizzle = false
		var chip: EffectChip = EffectChip.new(text, fizzle)
		chip.set_dimmed(indices[place] > frozen)
		view.add_chip(chip)


## The display name of the inspection that closed a product slot (or, with `coupon`, a coupon
## slot), from data.
func _closing_name(coupon: bool) -> String:
	for inspection: InspectionDefinition in FIXTURE.inspections():
		var closes: int = inspection.extra_coupon_slots if coupon else inspection.extra_slots
		if closes < 0:
			return inspection.display_name
	return ""


## The status panel's texts (capacity, cue, notice), the strip (Redraw, CHECKOUT, the scanner's
## cradle), and under the tray the hint and the seed line.
func _build_strip(counting: bool) -> void:
	var limits: ShiftLimits = FIXTURE.limits()
	var capacity: String = FIXTURE.capacity_text(_row)
	_rect_node(UiKit.body_label(capacity, CAPACITY_SIZE, INK), CAPACITY_RECT).name = "Capacity"
	var cue: Label = UiKit.body_label(CUE_TEXT, BODY_SIZE, INK)
	cue.add_theme_font_override("font", ArtStyle.body_font_with_symbols())
	_rect_node(cue, CUE_RECT).name = "Cue"
	var notice: Label = UiKit.body_label("", UiKit.NOTICE_FONT_SIZE, TOMATO_DARK)
	_rect_node(notice, NOTICE_RECT).name = "Notice"
	_rect_node(UiKit.body_label(HINT_TEXT, BODY_SIZE, INK), HINT_RECT).name = "Hint"
	var redraw: FramedButton = _framed_button(
		"Redraw up to %d (%d left)" % [FIXTURE.BALANCE.redraw_limit, limits.redraws],
		BUTTON_FONT_SIZE,
		BUTTON_BRASS,
		REDRAW_RECT
	)
	redraw.name = "Redraw"
	redraw.use_number_font()
	redraw.caption_label().add_theme_color_override("font_color", INK)
	redraw.caption_label().add_theme_constant_override("outline_size", 0)
	_checkout = _framed_button("CHECKOUT", CHECKOUT_SIZE, BUTTON_VELVET, CHECKOUT_RECT)
	_checkout.name = "Checkout"
	_checkout.caption_label().add_theme_color_override("font_color", GOLD)
	_checkout.caption_label().add_theme_constant_override("outline_size", CHECKOUT_OUTLINE)
	_checkout.disabled = counting
	_scanner = UiKit.sprite(SCANNER)
	_scanner.name = "Scanner"
	_scanner.size = DOCKED_SIZE
	if _state == State.PLANNING:
		_scanner.position = CRADLE_RECT.position + DOCKED_OFFSET
		_stage.add_child(_scanner)
	_rect_node(UiKit.sprite(CRADLE), CRADLE_RECT).name = "Cradle"
	var build_label: String = str(ProjectSettings.get_setting("next_customer/build_label", ""))
	var seed_text: String = "Seed %d  ·  %s" % [FIXTURE.CAPTURE.SEED, build_label]
	_rect_node(UiKit.body_label(seed_text, SEED_SIZE, INK_LIGHT), SEED_RECT).name = "SeedLine"


func _build_tray(hand: Array[CardInstance], counting: bool) -> void:
	var tray: Control = _rect_node(Control.new(), Rect2(Vector2.ZERO, STAGE_SIZE))
	tray.name = "Tray"
	if counting:
		tray.modulate.a = COUNTING_HAND_ALPHA
		(_stage.get_node("TrayFrame") as Control).modulate.a = COUNTING_HAND_ALPHA
	for index: int in range(hand.size()):
		var view: ItemView = _item(hand[index], false)
		view.position = TRAY_CELL_ORIGIN + Vector2(index * TRAY_PITCH, 0)
		tray.add_child(view)
		_hand_views.append(view)


## The rich customer's purse (#76) on the counter, on its soft shadow: calm and shut while
## planning or scanning, open with its cash showing while counting. A mood prop: no text, no
## number, nothing calculated.
func _build_purse(counting: bool) -> void:
	var shadow: Control = _rect_node(Control.new(), PURSE_SHADOW)
	shadow.name = "PurseShadow"
	shadow.draw.connect(_draw_shadow.bind(shadow))
	_purse = UiKit.sprite(PURSE_OPEN if counting else PURSE_CLOSED)
	_rect_node(_purse, PURSE_RECT).name = "Purse"


## The register's front (RegisterView), its TOTAL key down while counting.
func _build_register(counting: bool) -> void:
	_register = RegisterView.new(counting)
	_register.name = "RegisterFront"
	_stage.add_child(_register)
	_led = _register.led()


## The receipt, then the paper pile over its foot: the planning stub (header, PROJECTED total,
## the fizzle count, the tear) or, while counting, the header and the lines of steps[0..k].
func _build_receipt(counting: bool) -> void:
	var quota: int = FIXTURE.limits().quota
	_pile_height = 0.0
	_receipt = ReceiptView.new()
	_receipt.name = "Receipt"
	var paper: StyleBoxTexture = ArtStyle.frame_style(RECEIPT_PAPER, RECEIPT_MARGIN)
	paper.set_content_margin_all(RECEIPT_PADDING)
	_receipt.add_theme_stylebox_override("panel", paper)
	ArtStyle.use_pixel_material(_receipt)
	_receipt.position = RECEIPT_RECT.position
	_receipt.size = Vector2(RECEIPT_RECT.size.x, 0)
	_stage.add_child(_receipt)
	# Added after the receipt: the pile's top fold covers the receipt paper's foot.
	_pile = ReceiptPile.new()
	_pile.name = "PaperPile"
	_stage.add_child(_pile)
	# The receipt is refitted whenever its lines' laid-out height changes; once it reaches the
	# pile it scrolls to its newest line, with no scroll bar.
	var scroll: ScrollContainer = _receipt.get_child(0) as ScrollContainer
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.get_v_scroll_bar().changed.connect(_scroll_to_end.bind(scroll))
	var lines: Control = scroll.get_child(0) as Control
	lines.minimum_size_changed.connect(_fit_receipt.bind(lines))
	_receipt.add_line(STUB_HEADER, "", ReceiptView.LineStyle.DETAIL)
	var shift_line: String = (
		STUB_SHIFT % [FIXTURE.CAPTURE.SHIFT, FIXTURE.BALANCE.quotas.size(), _row.size()]
	)
	_receipt.add_line(shift_line, "", ReceiptView.LineStyle.DETAIL)
	if counting:
		var frozen: int = frozen_step()
		var newest_flat: Control = null
		for index: int in range(frozen + 1):
			var step: ScoreStep = _result.steps[index]
			var line: Control = _receipt.add_step(
				step, FIXTURE.names(_row), FIXTURE.upgrade_names(), FIXTURE.inspection_names()
			)
			if line == null:
				continue
			_step_lines.append(line)
			if step.step_type == ScoreStep.StepType.FLAT:
				newest_flat = line
		if newest_flat != null:
			_mark_combo(newest_flat)
		_led.show_amount(COUNT_CAPTION, _result.steps[frozen].subtotal, quota)
	else:
		var total: Control = _receipt.add_line(
			STUB_TOTAL, "€%d" % _result.total, ReceiptView.LineStyle.TOTAL
		)
		_stub_total = total.get_child(1) as Label
		_dash_rule(total.get_parent().get_child(total.get_index() - 1) as HSeparator)
		var fizzles: int = _wasted_count()
		if fizzles > 0:
			var text: String = STUB_FIZZLE if fizzles == 1 else STUB_FIZZLES % fizzles
			var notice: Control = _receipt.add_line(text, "", ReceiptView.LineStyle.DETAIL)
			(notice.get_child(0) as Label).add_theme_color_override("font_color", TOMATO_DARK)
		_receipt.add_tear()
		_led.show_amount(STUB_TOTAL, _result.total, quota)
	var printed: float = FIXTURE.pile_height(_step_lines.size())
	_pile_height = minf(printed, FIXTURE.TUNING.pile_cap_px)
	_fit_receipt(lines)


## Turns the TOTAL line's solid rule into the stub's dashed one.
func _dash_rule(rule: HSeparator) -> void:
	rule.name = "StubRule"
	rule.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	rule.draw.connect(_draw_dashes.bind(rule))


func _draw_dashes(rule: HSeparator) -> void:
	var y: float = roundf((rule.size.y - ArtStyle.ART_SCALE) / 2.0)
	var x: float = 0.0
	while x < rule.size.x:
		var dash: float = minf(STUB_RULE_DASH, rule.size.x - x)
		rule.draw_rect(Rect2(x, y, dash, ArtStyle.ART_SCALE), GREY)
		x += 2.0 * STUB_RULE_DASH


## Fits the receipt to its lines (delta section 8). Once it would reach the paper pile's top, it
## ends there (its foot under the pile's top fold, PILE_JOIN), scrolled to its newest line, and
## the pile shows; otherwise the pile is hidden and the receipt is as tall as its lines (the
## planning stub at most down to STUB_MAX_BOTTOM).
func _fit_receipt(lines: Control) -> void:
	if not is_instance_valid(_receipt) or _receipt.get_child(0).get_child(0) != lines:
		return
	var top: float = RECEIPT_RECT.position.y
	var natural: float = lines.get_combined_minimum_size().y + 2.0 * RECEIPT_PADDING
	var pile_top: float = PILE_BOTTOM - _pile_height
	if _pile_height > 0.0 and top + natural >= pile_top:
		_receipt.size = Vector2(RECEIPT_RECT.size.x, pile_top + PILE_JOIN - top)
		_pile.show_joined(PILE_SPAN, pile_top, PILE_BOTTOM)
		return
	_pile.hide_pile()
	var most: float = natural if _state == State.COUNT_UP else STUB_MAX_BOTTOM - top
	_receipt.size = Vector2(RECEIPT_RECT.size.x, minf(natural, most))


## Keeps the receipt scrolled to its newest line whenever its scroll range changes.
func _scroll_to_end(scroll: ScrollContainer) -> void:
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _wasted_count() -> int:
	var count: int = 0
	for step: ScoreStep in _result.steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			count += 1
	return count


## The combo line: a faint gold band behind the whole line (both sides and every wrapped line)
## with a gold bar on its left, and the diamond beside the bar, so it is marked by shape, not
## colour alone. COMBO_INDENT takes the place of the line's leading spaces (ReceiptView hangs
## the line: its lead and marker are the left label's margin, ReceiptView.hang_parts).
func _mark_combo(line: Control) -> void:
	_combo_line = line
	var left: Label = line.get_child(0) as Label
	var hung: StyleBoxEmpty = null
	if left.has_theme_stylebox_override("normal"):
		hung = left.get_theme_stylebox("normal") as StyleBoxEmpty
	var lead: float = 0.0
	var marker: Label = left.get_node_or_null("Marker") as Label
	if marker != null:
		lead = marker.position.x
		marker.position.x = COMBO_INDENT
	var indent: StyleBoxEmpty = StyleBoxEmpty.new()
	indent.content_margin_left = COMBO_INDENT
	if hung != null:
		indent.content_margin_left += hung.content_margin_left - lead
	left.add_theme_stylebox_override("normal", indent)
	line.draw.connect(_draw_combo_band.bind(line))
	var diamond: TextureRect = UiKit.sprite(COMBO_DIAMOND)
	diamond.name = "ComboDiamond"
	diamond.position = COMBO_ICON_RECT.position
	diamond.size = COMBO_ICON_RECT.size
	left.add_child(diamond)


func _draw_combo_band(line: Control) -> void:
	line.draw_rect(Rect2(Vector2.ZERO, line.size), Color(GOLD, COMBO_BAND_ALPHA))
	line.draw_rect(Rect2(0, 0, COMBO_BAR, line.size.y), GOLD)


func _build_top_bar() -> void:
	var bar: Control = _rect_node(Control.new(), Rect2(Vector2.ZERO, STAGE_SIZE))
	bar.name = "TopBar"
	var sign_panel: PanelContainer = UiKit.frame_panel(SIGN_FRAME, 3, SIGN_PADDING)
	sign_panel.name = "ShiftSign"
	sign_panel.position = SIGN_RECT.position
	sign_panel.size = SIGN_RECT.size
	bar.add_child(sign_panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	sign_panel.add_child(row)
	# Every number in the number font (plan 6.1.2): Pixelify's 5 reads as an S.
	var shift_row: HBoxContainer = HBoxContainer.new()
	shift_row.add_theme_constant_override("separation", SIGN_WORD_GAP)
	row.add_child(shift_row)
	shift_row.add_child(UiKit.display_label(SIGN_SHIFT, SIGN_FONT_SIZE, true))
	var shift: String = "%d / %d" % [FIXTURE.CAPTURE.SHIFT, FIXTURE.BALANCE.quotas.size()]
	shift_row.add_child(UiKit.number_label(shift, SIGN_FONT_SIZE, true))
	var quota: Label = UiKit.number_label(
		"QUOTA €%d" % FIXTURE.limits().quota, SIGN_FONT_SIZE, true
	)
	quota.add_theme_color_override("font_color", GOLD)
	row.add_child(quota)
	var loyalty: LoyaltyCard = LoyaltyCard.new()
	loyalty.position = LOYALTY_POSITION
	bar.add_child(loyalty)
	loyalty.show_upgrades(FIXTURE.BALANCE.upgrade_shifts.size() + 1, FIXTURE.upgrades())
	var tag: InspectionTag = InspectionTag.new()
	tag.position = TAG_POSITION
	bar.add_child(tag)
	tag.show_inspections(FIXTURE.inspections())
	var deck_text: String = "Deck %d/%d" % [FIXTURE.DECK_COUNT, FIXTURE.BALANCE.deck_limit]
	var deck: FramedButton = FramedButton.new(
		deck_text, BUTTON_FONT_SIZE, SIGN_FRAME, DECK_RECT.size
	)
	deck.use_number_font()
	deck.position = DECK_RECT.position
	bar.add_child(deck)
	var export: FramedButton = FramedButton.new(
		"Export log", BUTTON_FONT_SIZE, SIGN_FRAME, EXPORT_RECT.size
	)
	export.position = EXPORT_RECT.position
	bar.add_child(export)
	bar.add_child(BoutiqueDecor.plaque())


## Lifts `view`, brackets its sprite in `color`, brings the scanner to it with its beam and, for a
## hover (`hover`), opens the scan popup; the scanner stands overhead-left when the popup opens on
## the item's right.
func _pose_scan(view: ItemView, color: Color, hover: bool) -> void:
	view.set_lifted(true)
	var sprite: Rect2 = _stage_rect(view, view.sprite_rect())
	if not hover:
		_overlay.pose(_scanner, sprite, color, false)
		return
	_popup = ScanPopup.new()
	_popup.name = "ScanPopup"
	_stage.get_node("PopupLayer").add_child(_popup)
	var lines: PackedStringArray = PackedStringArray()
	var fizzles: Array[bool] = []
	var payout: int = -1
	if view.on_belt:
		var slot: int = _belt_views.find(view)
		payout = _result.payouts[slot]
		for index: int in EffectChip.step_indices(_result, slot):
			var step: ScoreStep = _result.steps[index]
			lines.append(
				EffectChip.full_line(step, FIXTURE.upgrade_names(), FIXTURE.inspection_names())
			)
			fizzles.append(step.step_type == ScoreStep.StepType.WASTED)
	var definition: CardDefinition = view.card.definition
	_popup.show_card(definition, FIXTURE.BALANCE.aisle_of(definition), payout, lines, fizzles)
	var below: Rect2 = _stage_rect(view, view.below_rect())
	_popup.place_at(sprite, below, Rect2(Vector2.ZERO, STAGE_SIZE), view.on_belt)
	# The scanner stands on the side away from a hand item's popup.
	_overlay.pose(_scanner, sprite, color, _popup.placement == ScanPopup.Placement.RIGHT)


## `rect` in `view`'s parent's coordinates, as stage coordinates.
func _stage_rect(view: ItemView, rect: Rect2) -> Rect2:
	var parent: Control = view.get_parent() as Control
	if parent == _stage:
		return rect
	return Rect2(rect.position + parent.position, rect.size)


func _framed_button(text: String, font_size: int, frame: Texture2D, rect: Rect2) -> FramedButton:
	var button: FramedButton = FramedButton.new(text, font_size, frame, rect.size)
	button.position = rect.position
	_stage.add_child(button)
	return button


## Adds `node` to the stage at `rect` and returns it.
func _rect_node(node: Control, rect: Rect2) -> Control:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	_stage.add_child(node)
	return node


## A plain cream panel with a cream-shade edge (the status panel and the hint's inset).
func _inset() -> Panel:
	var inset: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = CREAM_SHADE
	style.set_border_width_all(INSET_EDGE)
	inset.add_theme_stylebox_override("panel", style)
	return inset


## A soft ink ellipse filling `node` (the purse's shadow), on the 2 px art grid.
func _draw_shadow(node: Control) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var centre: Vector2 = node.size / 2.0
	for index: int in range(SHADOW_POINTS):
		var angle: float = TAU * index / SHADOW_POINTS
		var point: Vector2 = centre + Vector2(cos(angle), sin(angle)) * centre
		points.append(point.snappedf(ArtStyle.ART_SCALE))
	node.draw_colored_polygon(points, Color(INK, SHADOW_ALPHA))


func _draw_lights(lights: Control) -> void:
	BoutiqueDecor.draw_spots(lights)
	for light: Rect2 in LIGHTS:
		var shown: float = 0.0
		for band: int in range(LIGHT_BANDS.size()):
			# Each band over the ones under it adds up to LIGHT_ALPHAS[band].
			var alpha: float = (LIGHT_ALPHAS[band] - shown) / (1.0 - shown)
			shown = LIGHT_ALPHAS[band]
			var points: PackedVector2Array = PackedVector2Array()
			for index: int in range(LIGHT_POINTS):
				var angle: float = TAU * index / LIGHT_POINTS
				var radius: Vector2 = light.size * LIGHT_BANDS[band]
				var point: Vector2 = light.position + Vector2(cos(angle), sin(angle)) * radius
				points.append(point.snappedf(ArtStyle.ART_SCALE))
			lights.draw_colored_polygon(points, Color(MUSTARD_PALE, alpha))


func _capture_folder() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(CAPTURE_ARGUMENT):
			return argument.trim_prefix(CAPTURE_ARGUMENT)
	return ""
