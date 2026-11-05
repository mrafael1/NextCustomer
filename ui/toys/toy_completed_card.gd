class_name ToyCompletedCard
extends Control
## The COMPLETED! card (v1.05, mock-up toy_shelf_unlock.html, "The COMPLETED! card"): when a
## capsule completes its aisle (StartSetupRules.completed: every item of the aisle collected),
## the TOY MACHINES' figurine join (ToyLineupJoin) pops this card over its shade. On the popup
## frame: the aisle's sign band (its glyph and name), COMPLETED! in hard pixel lettering, one row
## per start-screen rule the completion unlocks (lines: each row is a rule that already exists,
## its numbers read from the balance and the regulars), the completed aisles' pips (the new one
## stamps in, ToyLineupJoin), the next unlock ("Next at 3 completed aisles: RESTOCK"), the stock
## footer and OK. It needs OK (it is rare and explains rules): it arms ResultsPanel.ARM_MS after
## it is shown, once the mouse is up; then OK, a click anywhere on the join, Enter or Space close
## it (`closed`). Sizes in canvas px.

signal closed

## What a row's icon shows: the aisle's glyph between swap arrows, the RESTOCK cart, the aisles.
enum Icon { SWAP, CART, AISLES }

const WIDTH := 420.0
## The card's top on the stage (a taller card is centred instead) and its shadow's offset.
const TOP := 64.0
const SHADOW_OFFSET := Vector2(6, 8)
const SHADOW_ALPHA := 0.35
const FRAME := preload("res://art/frames/popup.png")
const FRAME_MARGIN := 4
const PADDING := Vector4(20, 16, 20, 18)
const SIGN_PATH := "res://art/frames/aisle_sign_%s.png"
const BASE_SIGN := preload("res://art/frames/aisle_sign.png")
const BAND_HEIGHT := 36.0
const GLYPH_SIZE := Vector2(18, 18)
const CART := preload("res://art/icons/cart.png")
const PADLOCK := preload("res://art/icons/padlock_dim.png")
const ICON_BOX := Vector2(44, 44)
const PIP_SIZE := Vector2(36, 36)
const PIP_GAP := 8
const TITLE_SIZE := 16
const TEXT_SIZE := 13
const TEXT_WIDTH := 300.0
const NEXT_SIZE := 14
const STOCK_SIZE := 15
const STOCK_ROTATION := -2.0
const OK_SIZE := Vector2(150, 44)
const HEADING_TEXT := "COMPLETED!"
const SWAP_TITLE := "+1 REGULAR SWAP"
const SWAP_TEXT := (
	"You can now swap up to %d of your %d regulars for a plain product of a completed aisle. "
	+ "%s joins the choices (max %d per aisle)."
)
const CHOICES_TITLE := "NEW SWAP CHOICES"
const CHOICES_TEXT := (
	"Plain %s products can now replace a regular. Still up to %d of your %d regulars "
	+ "(max %d per aisle)."
)
const RESTOCK_TITLE := "RESTOCK UNLOCKED"
const RESTOCK_TEXT := "Once a run, swap both items of one starting basket for a new pair."
const RESTOCK_TEXT_PLURAL := (
	"%d times a run, swap both items of one starting basket " + "for a new pair."
)
const RESTOCK_NAME := "RESTOCK"
const AISLES_TITLE := "CHOOSE YOUR AISLES"
const AISLES_TEXT := "Pick today's STARTER CART and RUN ONLY aisles yourself."
const NEXT_TEXT := "Next at %d completed aisles: %s"
const ALL_TEXT := "Every aisle completed."
const PIPS_TEXT := "COMPLETED AISLES %d/%d"
const NEXT_RUN_TEXT := "From your next run"
const SAVED_RUN_TEXT := "After your saved run"
const OK_TEXT := "OK"

var _shadow: ColorRect
var _frame: PanelContainer
var _column: VBoxContainer
var _rows: Array[Control] = []
var _pips: Array[Control] = []
var _new_pip: Control
var _ok: FramedButton
var _armed: bool = false
var _arm_at_ms: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_shadow = ColorRect.new()
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.color = Color(Palette.INK, SHADOW_ALPHA)
	add_child(_shadow)
	_frame = UiKit.frame_panel(FRAME, FRAME_MARGIN, PADDING)
	_frame.custom_minimum_size.x = WIDTH
	add_child(_frame)


## The rows the completion of the `completed_count`th aisle (`aisle`) unlocks, each
## {"icon": Icon, "title": String, "text": String}, for `regulars` regulars. Every number is the
## balance's: the swap cap (one per completed aisle, at most one per regular), its per-aisle
## limit (staple_swap_aisle_max, 0: no swaps, no row), RESTOCK at restock_min_completed and
## CHOOSE YOUR AISLES at pair_choice_min_completed (0: off, no row).
static func lines(
	balance: BalanceDefinition, completed_count: int, aisle: AisleDefinition, regulars: int
) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var aisle_max: int = balance.staple_swap_aisle_max
	if aisle_max > 0 and regulars > 0:
		var cap: int = mini(completed_count, regulars)
		var aisle_name: String = aisle.display_name
		if cap > mini(completed_count - 1, regulars):
			var text: String = SWAP_TEXT % [cap, regulars, aisle_name, aisle_max]
			found.append({"icon": Icon.SWAP, "title": SWAP_TITLE, "text": text})
		else:
			var text: String = CHOICES_TEXT % [aisle_name, cap, regulars, aisle_max]
			found.append({"icon": Icon.SWAP, "title": CHOICES_TITLE, "text": text})
	if balance.restock_min_completed > 0 and completed_count == balance.restock_min_completed:
		var times: int = balance.restocks_per_run
		var text: String = RESTOCK_TEXT if times == 1 else RESTOCK_TEXT_PLURAL % times
		found.append({"icon": Icon.CART, "title": RESTOCK_TITLE, "text": text})
	var pair_min: int = balance.pair_choice_min_completed
	if pair_min > 0 and completed_count == pair_min:
		found.append({"icon": Icon.AISLES, "title": AISLES_TITLE, "text": AISLES_TEXT})
	return found


## The next unlock after `completed_count` completed aisles (the nearest threshold still ahead),
## "Every aisle completed." once all are, else "".
static func next_line(balance: BalanceDefinition, completed_count: int) -> String:
	var best: int = 0
	var best_name: String = ""
	var ahead: Array = [
		[balance.restock_min_completed, RESTOCK_NAME],
		[balance.pair_choice_min_completed, AISLES_TITLE],
	]
	for entry: Array in ahead:
		var at: int = entry[0]
		if at > completed_count and (best == 0 or at < best):
			best = at
			best_name = entry[1]
	if best > 0:
		return NEXT_TEXT % [best, best_name]
	if completed_count >= balance.aisles.size():
		return ALL_TEXT
	return ""


## Every player-facing string the card can show (the no-"gacha" check).
static func copy() -> PackedStringArray:
	return PackedStringArray(
		[
			HEADING_TEXT,
			SWAP_TITLE,
			SWAP_TEXT,
			CHOICES_TITLE,
			CHOICES_TEXT,
			RESTOCK_TITLE,
			RESTOCK_TEXT,
			RESTOCK_TEXT_PLURAL,
			AISLES_TITLE,
			AISLES_TEXT,
			NEXT_TEXT,
			ALL_TEXT,
			PIPS_TEXT,
			NEXT_RUN_TEXT,
			SAVED_RUN_TEXT,
			OK_TEXT,
		]
	)


## Builds the card for `aisle`, just completed, with `completed` the completed aisles (data
## order, the new one among them), `regulars` regulars and the saved-run footer when
## `saved_run`. It is laid out on the stage (`stage_size`) but stays hidden: the join shows it.
func build(
	balance: BalanceDefinition,
	aisle: AisleDefinition,
	completed: Array[AisleDefinition],
	regulars: int,
	saved_run: bool,
	stage_size: Vector2
) -> void:
	for child: Node in _frame.get_children():
		_frame.remove_child(child)
		child.free()
	_rows = []
	_pips = []
	_new_pip = null
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 10)
	_frame.add_child(_column)
	_column.add_child(_band(aisle))
	_column.add_child(_centred(_pixel_line([HEADING_TEXT], Palette.INK, 2)))
	for row: Dictionary in lines(balance, completed.size(), aisle, regulars):
		var built: Control = _row(row, aisle, balance)
		_column.add_child(built)
		_rows.append(built)
	var pips_line: String = PIPS_TEXT % [completed.size(), balance.aisles.size()]
	_column.add_child(_centred(_pixel_line(PixelLine.split(pips_line), Palette.INK_LIGHT, 1)))
	_column.add_child(_pip_row(balance, aisle, completed))
	var next: String = next_line(balance, completed.size())
	if next != "":
		var next_label: Label = UiKit.body_label(next, NEXT_SIZE, Palette.INK_LIGHT)
		next_label.add_theme_font_override("font", ArtStyle.bold_font(700))
		next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_column.add_child(next_label)
	_column.add_child(_centred(_stock(SAVED_RUN_TEXT if saved_run else NEXT_RUN_TEXT)))
	_ok = UiKit.framed_button(null, OK_TEXT, close, 22, UiKit.BUTTON_FRAME, OK_SIZE, "")
	_ok.disabled = true
	_column.add_child(_centred(_ok))
	_frame.reset_size()
	_frame.size = _frame.get_combined_minimum_size()
	size = _frame.size
	_shadow.position = SHADOW_OFFSET
	_shadow.size = size
	pivot_offset = size / 2.0
	var top: float = (
		TOP if TOP + size.y <= stage_size.y - TOP / 2.0 else (stage_size.y - size.y) / 2
	)
	position = Vector2(roundf((stage_size.x - size.x) / 2.0), roundf(top))
	_armed = false


## Shows the card: armed ResultsPanel.ARM_MS from now, once the mouse is up.
func open() -> void:
	visible = true
	_armed = false
	_ok.disabled = true
	_arm_at_ms = Time.get_ticks_msec() + ResultsPanel.ARM_MS


## Arms the shown card at once (the screen capture's stills past it).
func arm_now() -> void:
	if visible:
		_armed = true
		_ok.disabled = false


func is_armed() -> bool:
	return _armed


## Closes the armed card and reports it (OK, a click on the join, Enter or Space).
func close() -> void:
	if not visible or not _armed:
		return
	_armed = false
	_ok.disabled = true
	Sfx.play_at(self, UiKit.CLICK_SOUND)
	closed.emit()


## The pieces, for the join and the tests.
func rows() -> Array[Control]:
	return _rows


func pips() -> Array[Control]:
	return _pips


## The completed aisle's pip (it stamps in).
func new_pip() -> Control:
	return _new_pip


func ok_button() -> FramedButton:
	return _ok


func frame() -> PanelContainer:
	return _frame


func _process(_delta: float) -> void:
	if not visible or _armed or _ok == null or Time.get_ticks_msec() < _arm_at_ms:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_armed = true
		_ok.disabled = false


## The aisle's sign band: its frame, glyph and name.
func _band(aisle: AisleDefinition) -> Control:
	var path: String = SIGN_PATH % aisle.id
	var sign_frame: Texture2D = (
		load(path) as Texture2D if ResourceLoader.exists(path) else BASE_SIGN
	)
	var band: PanelContainer = UiKit.frame_panel(sign_frame, 3, Vector4(8, 0, 8, 2))
	band.custom_minimum_size.y = BAND_HEIGHT
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	band.add_child(row)
	row.add_child(_glyph(aisle))
	var name_line: Control = _pixel_line([aisle.display_name.to_upper()], Palette.PAPER, 1)
	name_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_line)
	return band


## One rule's row: its icon box, title and text.
func _row(row: Dictionary, aisle: AisleDefinition, balance: BalanceDefinition) -> Control:
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 12)
	var box: PanelContainer = PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = ICON_BOX
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_theme_stylebox_override("panel", _box_style(Palette.TEAL_DARK))
	box.add_child(_icon(row["icon"], aisle, balance))
	line.add_child(box)
	var words: VBoxContainer = VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 2)
	var title: Label = UiKit.body_label(str(row["title"]), TITLE_SIZE, Palette.INK)
	title.add_theme_font_override("font", ArtStyle.bold_font(800))
	words.add_child(title)
	var text: Label = UiKit.body_label(str(row["text"]), TEXT_SIZE, Palette.GREY_DARK)
	text.add_theme_font_override("font", ArtStyle.bold_font(500))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = TEXT_WIDTH
	words.add_child(text)
	line.add_child(words)
	return line


## A row's icon, centred in its box.
func _icon(kind: Icon, aisle: AisleDefinition, balance: BalanceDefinition) -> Control:
	var holder: CenterContainer = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match kind:
		Icon.CART:
			var cart: TextureRect = UiKit.sprite(CART)
			cart.custom_minimum_size = Vector2(CART.get_size()) * ArtStyle.ART_SCALE
			holder.add_child(cart)
		Icon.AISLES:
			var grid: GridContainer = GridContainer.new()
			grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 2)
			grid.add_theme_constant_override("v_separation", 2)
			for shown: AisleDefinition in balance.aisles.slice(0, 4):
				grid.add_child(_glyph(shown))
			holder.add_child(grid)
		_:
			var swap: Control = Control.new()
			swap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swap.custom_minimum_size = Vector2(28, 36)
			var glyph: TextureRect = _glyph(aisle)
			glyph.position = Vector2(5, 9)
			glyph.size = GLYPH_SIZE
			swap.add_child(glyph)
			swap.draw.connect(_draw_arrows.bind(swap))
			holder.add_child(swap)
	return holder


## The swap icon's two gold arrows over and under the glyph (whole art px).
func _draw_arrows(swap: Control) -> void:
	var gold: Color = Palette.GOLD
	swap.draw_rect(Rect2(0, 2, 26, 2), gold)
	swap.draw_rect(Rect2(22, 0, 2, 6), gold)
	swap.draw_rect(Rect2(24, 2, 2, 2), gold)
	swap.draw_rect(Rect2(2, 32, 26, 2), gold)
	swap.draw_rect(Rect2(4, 30, 2, 6), gold)
	swap.draw_rect(Rect2(2, 32, 2, 2), gold)


## The completed aisles' pips: an aisle's sign colour with its glyph, a padlock while open.
func _pip_row(
	balance: BalanceDefinition, aisle: AisleDefinition, completed: Array[AisleDefinition]
) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", PIP_GAP)
	for shown: AisleDefinition in balance.aisles:
		var pip: PanelContainer
		var inside: TextureRect
		if completed.has(shown):
			var path: String = SIGN_PATH % shown.id
			var art: Texture2D = (
				load(path) as Texture2D if ResourceLoader.exists(path) else BASE_SIGN
			)
			pip = UiKit.frame_panel(art, 3, Vector4.ZERO)
			inside = _glyph(shown)
		else:
			pip = PanelContainer.new()
			pip.add_theme_stylebox_override("panel", _box_style(Palette.TEAL_DARK))
			inside = UiKit.sprite(PADLOCK)
			inside.custom_minimum_size = Vector2(PADLOCK.get_size()) * ArtStyle.ART_SCALE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.custom_minimum_size = PIP_SIZE
		var centre: CenterContainer = CenterContainer.new()
		centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		centre.add_child(inside)
		pip.add_child(centre)
		row.add_child(pip)
		_pips.append(pip)
		if shown == aisle:
			_new_pip = pip
	return row


## The footer: the reveal's stock panel look, tilted.
func _stock(text: String) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = _box_style(Palette.TEAL_DARK)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 3
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	panel.rotation_degrees = STOCK_ROTATION
	var label: Label = UiKit.body_label(text, STOCK_SIZE, Palette.PAPER)
	label.add_theme_font_override("font", ArtStyle.bold_font(700))
	panel.add_child(label)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)
	return panel


static func _box_style(fill: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Palette.INK
	style.set_border_width_all(2)
	return style


static func _glyph(aisle: AisleDefinition) -> TextureRect:
	var glyph: TextureRect = UiKit.sprite(load(ArtStyle.glyph_path(aisle)) as Texture2D)
	glyph.custom_minimum_size = GLYPH_SIZE
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return glyph


## A PixelLine a container can lay out (its minimum size is its line).
static func _pixel_line(tokens: Array, colour: Color, word_scale: int) -> Control:
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: PixelLine = PixelLine.new()
	line.show_tokens(tokens, colour, colour, word_scale)
	holder.add_child(line)
	holder.custom_minimum_size = Vector2(line.width(), line.size.y)
	return holder


static func _centred(control: Control) -> Control:
	var holder: CenterContainer = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(control)
	return holder
