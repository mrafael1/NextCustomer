class_name ToyMachinesScreen
extends Control
## The TOY MACHINES (#63, mock-up capsule_63_a.html look A, decided with the user; full build plan
## 7.1): a camera cut to the store's exit, where one globe toy machine per aisle (balance.aisles
## order) stands on the tiled floor by the sliding doors. Pick a machine to spend a capsule's
## price on a capsule: CapsuleCounter draws, saves and logs it, the coin clinks, the counts drop
## and the plain reveal (ToyReveal) shows the figurine. "Figurine shelf" opens the FIGURINE SHELF
## (its Back returns here); Done closes the screen. Coins can be kept: nothing asks to spend them.
##
## A full-screen overlay that blocks clicks behind it, holding a 1280x720 stage centred in the
## window (never scaled; the bands outside it are the background colour), laid out at the
## mock-up's coordinates. Reached from the results (ShiftScreen) and the title (TitleScreen),
## which build the CapsuleCounter: it knows the profile, the stock line and whether saves work.
##
## States, never by colour alone: COINS ? and every machine OUT OF ORDER with a notice when the
## profile can't be saved; every machine ALL COLLECTED with the COLLECTION COMPLETE banner once
## the collection is complete; dimmed machines and a notice with 0 coins; otherwise the hint.

signal closed

const STAGE := Vector2(1280, 720)
const BACKDROP := preload("res://art/scenery/exit_vestibule.png")
const COIN := preload("res://art/icons/coin.png")
const WARNING := preload("res://art/icons/warning.png")
const LABEL_FRAME := preload("res://art/effects/sticker_label.png")
## The player-facing words (DECIDE_63's wording: TOY MACHINES, capsule, figurine), in one place.
const TITLE_TEXT := "TOY MACHINES"
const EXIT_TEXT := "EXIT ›"
const COINS_TEXT := "COINS"
const FIGURINES_TEXT := "FIGURINES"
const COUNT_TEXT := "%d / %d"
const UNKNOWN_COINS := "?"
const LEFT_TEXT := "%d of %d left"
const COLLECTED_TEXT := "All %d collected"
const HINT_TEXT := "Pick a machine: %s a capsule."
const FULL_BANNER := "COLLECTION COMPLETE · every figurine is on your shelf"
const FULL_HINT := "Your coins keep adding up on the final receipt."
const BROKE_NOTICE := "No coins left. Runs that pass shift 4 pay coins on the final receipt."
const OFF_NOTICE := (
	"Your collection can't be saved right now, " + "so the toy machines are switched off."
)
const SHELF_TEXT := "Figurine shelf"
const DONE_TEXT := "Done ›"
## Layout (stage px).
const COINS_CHIP_POSITION := Vector2(20, 14)
const FIGURINES_CHIP_POSITION := Vector2(206, 14)
const COIN_ICON_SIZE := Vector2(24, 24)
const BOARD_RECT := Rect2(330, 70, 360, 64)
const BOARD_FONT_SIZE := 34
const CHAIN_XS: Array[float] = [372.0, 644.0]
const CHAIN_TOP := 12.0
const CHAIN_SIZE := Vector2(4, 64)
const EXIT_RECT := Rect2(1086, 20, 108, 36)
const EXIT_FONT_SIZE := 20
const BANNER_RECT := Rect2(210, 150, 600, 24)
const MACHINE_TOP := 250.0
const MACHINE_PITCH := 160.0
## The machines stand left of the doors: six from MACHINE_X0, fewer centred in 0..ROW_WIDTH.
const MACHINE_X0 := 40.0
const ROW_WIDTH := 1000.0
const FULL_ROW := 6
const FLOOR_LABEL_Y := 538.0
const FLOOR_LABEL_HEIGHT := 34.0
const HINT_Y := 596.0
const NOTICE_Y := 588.0
const SHELF_BUTTON_RECT := Rect2(40, 640, 230, 56)
const DONE_BUTTON_RECT := Rect2(1080, 640, 160, 56)
## The coins chip pops when its number drops.
const POP_SCALE := 1.15
const POP_SECONDS := 0.25

var _counter: CapsuleCounter
var _balance: BalanceDefinition
var _stage: Control
var _machines_layer: Control
var _machines: Array[ToyMachineView] = []
var _floor_labels: Array[Label] = []
var _floor_panels: Array[PanelContainer] = []
var _coins_chip: PanelContainer
var _coins_value: Label
var _figurines_value: Label
var _banner: Label
var _hint: Label
var _notice: PanelContainer
var _notice_label: Label
var _shelf_button: FramedButton
var _done_button: FramedButton
var _reveal: ToyReveal
var _shelf: FigurineShelf
var _shown_coins: int = -1


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bands: ColorRect = ColorRect.new()
	bands.color = Palette.BACKGROUND
	bands.set_anchors_preset(Control.PRESET_FULL_RECT)
	bands.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bands)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.clip_contents = true
	_stage.set_anchors_preset(Control.PRESET_CENTER)
	_stage.offset_left = -STAGE.x / 2.0
	_stage.offset_top = -STAGE.y / 2.0
	_stage.offset_right = STAGE.x / 2.0
	_stage.offset_bottom = STAGE.y / 2.0
	add_child(_stage)
	_machines_layer = Control.new()
	_machines_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_machines_layer.size = STAGE
	_stage.add_child(_machines_layer)
	var backdrop: TextureRect = UiKit.sprite(BACKDROP)
	backdrop.size = STAGE
	_machines_layer.add_child(backdrop)
	_build_header()
	_build_footer()
	_reveal = ToyReveal.new()
	_reveal.dismissed.connect(_refresh)
	_stage.add_child(_reveal)
	_shelf = FigurineShelf.new()
	_shelf.back_pressed.connect(_close_shelf)
	_stage.add_child(_shelf)


## Opens the machines for the `capsules` counter's profile, one per aisle of `balance`.
func open(capsules: CapsuleCounter, balance: BalanceDefinition) -> void:
	if _counter != null and _counter.switched_off.is_connected(_refresh):
		_counter.switched_off.disconnect(_refresh)
	_counter = capsules
	_counter.switched_off.connect(_refresh)
	_balance = balance
	_build_machines()
	_reveal.visible = false
	_shelf.visible = false
	_machines_layer.visible = true
	_shown_coins = -1
	visible = true
	_refresh()


## Hides the screen and reports it (Done).
func close() -> void:
	if not visible:
		return
	_reveal.visible = false
	_shelf.visible = false
	visible = false
	closed.emit()


func counter() -> CapsuleCounter:
	return _counter


## The pieces, for tests and the screen capture.
func stage() -> Control:
	return _stage


func machines() -> Array[ToyMachineView]:
	return _machines


func floor_labels() -> Array[Label]:
	return _floor_labels


func coins_label() -> Label:
	return _coins_value


func coins_chip() -> PanelContainer:
	return _coins_chip


func figurines_label() -> Label:
	return _figurines_value


func notice_label() -> Label:
	return _notice_label


func notice_panel() -> PanelContainer:
	return _notice


func hint_label() -> Label:
	return _hint


func banner_label() -> Label:
	return _banner


func shelf() -> FigurineShelf:
	return _shelf


func reveal() -> ToyReveal:
	return _reveal


func shelf_button() -> FramedButton:
	return _shelf_button


func done_button() -> FramedButton:
	return _done_button


## Every player-facing string the screen can show (the no-"gacha" check).
static func copy() -> PackedStringArray:
	return PackedStringArray(
		[
			TITLE_TEXT,
			EXIT_TEXT,
			COINS_TEXT,
			FIGURINES_TEXT,
			LEFT_TEXT,
			COLLECTED_TEXT,
			HINT_TEXT,
			FULL_BANNER,
			FULL_HINT,
			BROKE_NOTICE,
			OFF_NOTICE,
			SHELF_TEXT,
			DONE_TEXT,
			CapsuleCounter.NEXT_RUN_LINE,
			CapsuleCounter.AFTER_SAVED_RUN_LINE,
			ToyMachineView.ROSETTE_TEXT,
			ToyMachineView.PAPER_TEXT,
			ToyMachineView.PRICE_TEXT,
			ToyMachineView.PRICE_TEXT_PLURAL,
			ToyReveal.NEW_TEXT,
			ToyReveal.OK_TEXT,
			ToyReveal.TIP_TEXT,
			FigurineShelf.TITLE_TEXT,
			FigurineShelf.NONE_TEXT,
			FigurineShelf.DONE_TEXT,
			FigurineShelf.FRESH_TEXT,
			FigurineShelf.HINT_TEXT,
			FigurineShelf.BACK_TEXT,
		]
	)


## The left edge of the machine row for `count` machines: MACHINE_X0 for a full row, else the
## row centred in 0..ROW_WIDTH.
static func row_x0(count: int) -> float:
	if count >= FULL_ROW:
		return MACHINE_X0
	return roundf(
		(ROW_WIDTH - (count * MACHINE_PITCH - (MACHINE_PITCH - ToyMachineView.SIZE.x))) / 2.0
	)


func _unhandled_key_input(event: InputEvent) -> void:
	# The screen's own keys: nothing starts behind it (the title's Enter and Space).
	var key: InputEventKey = event as InputEventKey
	if visible and key != null and key.pressed:
		get_viewport().set_input_as_handled()


func _build_header() -> void:
	# The board's chains first, so the chips hang in front of them (as in the mock-up).
	for x: float in CHAIN_XS:
		var chain: Control = Control.new()
		chain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chain.position = Vector2(x, CHAIN_TOP)
		chain.size = CHAIN_SIZE
		chain.draw.connect(_draw_chain.bind(chain))
		_machines_layer.add_child(chain)
	_coins_chip = TopBar.chip(TopBar.CHIP_FRAME)
	_coins_chip.position = COINS_CHIP_POSITION
	_machines_layer.add_child(_coins_chip)
	var coins_row: HBoxContainer = _chip_row(_coins_chip)
	var coin: TextureRect = UiKit.sprite(COIN)
	coin.custom_minimum_size = COIN_ICON_SIZE
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coins_row.add_child(coin)
	coins_row.add_child(TopBar.key_label(COINS_TEXT))
	_coins_value = TopBar.value_label(Palette.PAPER)
	coins_row.add_child(_coins_value)
	var figurines_chip: PanelContainer = TopBar.chip(TopBar.CHIP_FRAME)
	figurines_chip.position = FIGURINES_CHIP_POSITION
	_machines_layer.add_child(figurines_chip)
	var figurines_row: HBoxContainer = _chip_row(figurines_chip)
	figurines_row.add_child(TopBar.key_label(FIGURINES_TEXT))
	_figurines_value = TopBar.value_label(Palette.PAPER)
	figurines_row.add_child(_figurines_value)
	var board: PanelContainer = UiKit.frame_panel(UiKit.SIGN_FRAME, 3, Vector4(0, 0, 0, 4))
	board.position = BOARD_RECT.position
	board.size = BOARD_RECT.size
	_machines_layer.add_child(board)
	var title: Label = UiKit.display_label(TITLE_TEXT, BOARD_FONT_SIZE, true)
	title.add_theme_font_override("font", ArtStyle.spaced_display_font(2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board.add_child(title)
	var exit_label: Label = UiKit.display_label(EXIT_TEXT, EXIT_FONT_SIZE, true)
	exit_label.add_theme_constant_override("outline_size", 4)
	exit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exit_label.position = EXIT_RECT.position
	exit_label.size = EXIT_RECT.size
	_machines_layer.add_child(exit_label)
	_banner = UiKit.body_label("", 16, Palette.MUSTARD_DARKEST)
	_banner.add_theme_font_override("font", ArtStyle.bold_font(700))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = BANNER_RECT.position
	_banner.size = BANNER_RECT.size
	_machines_layer.add_child(_banner)


func _build_footer() -> void:
	_hint = UiKit.body_label("", 16, Palette.INK_LIGHT)
	_hint.add_theme_font_override("font", ArtStyle.bold_font(600))
	_machines_layer.add_child(_hint)
	_notice = PanelContainer.new()
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.INK
	style.set_border_width_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(Palette.INK, 0.35)
	style.shadow_offset = Vector2(4, 4)
	_notice.add_theme_stylebox_override("panel", style)
	_machines_layer.add_child(_notice)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_notice.add_child(row)
	var warning: TextureRect = UiKit.sprite(WARNING)
	warning.custom_minimum_size = Vector2(WARNING.get_size()) * ArtStyle.ART_SCALE
	warning.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(warning)
	_notice_label = UiKit.body_label("", UiKit.NOTICE_FONT_SIZE, Palette.TOMATO_DARK)
	_notice_label.add_theme_font_override("font", ArtStyle.bold_font(700))
	_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_notice_label)
	_shelf_button = UiKit.framed_button(
		_machines_layer, SHELF_TEXT, _open_shelf, 22, UiKit.SIGN_FRAME, SHELF_BUTTON_RECT.size
	)
	_shelf_button.position = SHELF_BUTTON_RECT.position
	_done_button = UiKit.framed_button(
		_machines_layer, DONE_TEXT, close, 24, UiKit.BUTTON_FRAME, DONE_BUTTON_RECT.size, "ui_back"
	)
	_done_button.position = DONE_BUTTON_RECT.position


func _chip_row(chip: PanelContainer) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	chip.add_child(row)
	return row


## One machine and one floor label per aisle, laid out for their count.
func _build_machines() -> void:
	for machine: ToyMachineView in _machines:
		_machines_layer.remove_child(machine)
		machine.queue_free()
	for panel: PanelContainer in _floor_panels:
		_machines_layer.remove_child(panel)
		panel.queue_free()
	_machines = []
	_floor_labels = []
	_floor_panels = []
	var x0: float = row_x0(_balance.aisles.size())
	for index: int in range(_balance.aisles.size()):
		var machine: ToyMachineView = ToyMachineView.new()
		machine.position = Vector2(x0 + index * MACHINE_PITCH, MACHINE_TOP)
		machine.picked.connect(_on_machine_picked)
		_machines_layer.add_child(machine)
		_machines.append(machine)
		var panel: PanelContainer = UiKit.frame_panel(LABEL_FRAME, 3, Vector4(12, 0, 12, 4))
		panel.custom_minimum_size.y = FLOOR_LABEL_HEIGHT
		_machines_layer.add_child(panel)
		var label: Label = UiKit.body_label("", 16, Palette.INK)
		label.add_theme_font_override("font", ArtStyle.bold_font(ArtStyle.NUMBER_WEIGHT))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(label)
		_floor_panels.append(panel)
		_floor_labels.append(label)
	# The reveal and the shelf stay above the machines.
	_machines_layer.move_child(_hint, -1)
	_machines_layer.move_child(_notice, -1)


## Shows the counter's coins, the collection's counts and every machine's state, then the one
## line under the machines that fits (OFF's notice, the full collection's banner and hint, the
## 0 coins notice, or the hint).
func _refresh() -> void:
	if _counter == null:
		return
	var profile: ProfileState = _counter.profile
	var can_save: bool = _counter.can_save()
	var coins: int = profile.coins
	_coins_value.text = str(coins) if can_save else UNKNOWN_COINS
	if can_save and _shown_coins >= 0 and coins < _shown_coins:
		_pop_coins()
	_shown_coins = coins if can_save else -1
	_figurines_value.text = (
		COUNT_TEXT % [profile.owned_capsules(_balance), CapsuleDraw.capsule_count(_balance)]
	)
	var all_empty: bool = true
	var broke: bool = false
	for index: int in range(_machines.size()):
		var aisle: AisleDefinition = _balance.aisles[index]
		var left: int = _counter.items_left(aisle)
		var total: int = aisle.capsule_cards.size()
		var state: CapsuleCounter.State = _counter.machine_state(aisle)
		_machines[index].set_machine(aisle, left, total, state, _counter.price())
		all_empty = all_empty and left == 0
		broke = broke or state == CapsuleCounter.State.BROKE
		_floor_labels[index].text = (
			(COLLECTED_TEXT % total) if left == 0 else (LEFT_TEXT % [left, total])
		)
		var panel: PanelContainer = _floor_panels[index]
		panel.size = panel.get_combined_minimum_size()
		panel.position = Vector2(
			roundf(_machines[index].position.x + ToyMachineView.SIZE.x / 2.0 - panel.size.x / 2.0),
			FLOOR_LABEL_Y
		)
	_banner.text = FULL_BANNER if can_save and all_empty else ""
	_hint.visible = false
	_notice.visible = false
	if not can_save:
		_show_notice(OFF_NOTICE)
	elif all_empty:
		_show_hint(FULL_HINT)
	elif broke:
		_show_notice(BROKE_NOTICE)
	else:
		_show_hint(HINT_TEXT % ToyMachineView.price_text(_counter.price()))


func _show_hint(text: String) -> void:
	_hint.text = text
	_hint.size = _hint.get_combined_minimum_size()
	_hint.position = Vector2(roundf(STAGE.x / 2.0 - _hint.size.x / 2.0), HINT_Y)
	_hint.visible = true


func _show_notice(text: String) -> void:
	_notice_label.text = text
	_notice.size = _notice.get_combined_minimum_size()
	_notice.position = Vector2(roundf(STAGE.x / 2.0 - _notice.size.x / 2.0), NOTICE_Y)
	_notice.visible = true


func _pop_coins() -> void:
	_coins_chip.pivot_offset = _coins_chip.size / 2.0
	_coins_chip.scale = Vector2.ONE * POP_SCALE
	var tween: Tween = _coins_chip.create_tween()
	tween.tween_property(_coins_chip, "scale", Vector2.ONE, POP_SECONDS)


func _on_machine_picked(aisle: AisleDefinition) -> void:
	if _reveal.visible or _shelf.visible or _counter == null:
		return
	var card: CardDefinition = _counter.draw(aisle)
	_refresh()
	if card == null:
		return
	Sfx.play_at(self, "coin")
	_hint.visible = false
	_reveal.show_card(card, aisle, _counter.stock_line())


func _open_shelf() -> void:
	if _reveal.visible:
		return
	_shelf.show_collection(_balance, _counter.profile.unlocked_items)
	_shelf.visible = true
	_machines_layer.visible = false


func _close_shelf() -> void:
	_shelf.visible = false
	_machines_layer.visible = true
	_refresh()


func _draw_chain(chain: Control) -> void:
	var link: float = 4.0
	var y: float = 0.0
	var dark: bool = true
	while y < chain.size.y:
		var colour: Color = Palette.STEEL_DARK if dark else Palette.STEEL_LIGHT
		chain.draw_rect(Rect2(0, y, chain.size.x, minf(link, chain.size.y - y)), colour)
		y += link
		dark = not dark
