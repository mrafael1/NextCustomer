class_name FigurineShelf
extends Control
## The FIGURINE SHELF (#63, mock-up capsule_63_shelf.html; full build plan 7.1): a wooden display
## cabinet with one shelf per aisle (balance.aisles order, left to right then down), each with
## its aisle's sign, its count "n / m" and the collected figurines standing on its plank. A
## figurine is the item's plain sprite at 1x (48x48), never its rules; names show on hover.
##
## Locked items are hidden (decided with the user): no space, silhouette or name. The collected
## figurines of an aisle stand packed from the left of the plank in data order (the key item
## first), so the plank never shows a gap. Every aisle's shelf is always there, so the cabinet
## keeps its size from 0 to every figurine: an aisle with nothing yet shows "None yet", a full
## one an ALL COLLECTED tag, and a new profile a line under the title. How many exist is told by
## the numbers only (n / m, FIGURINES n / total). Only the capsule items are on it.

signal back_pressed

const STAGE := Vector2(1280, 720)
const CABINET := preload("res://art/frames/display_cabinet.png")
const PLANK := preload("res://art/scenery/shelf_plank.png")
const SIGN_PATH := "res://art/frames/aisle_sign_%s.png"
const BASE_SIGN := preload("res://art/frames/aisle_sign.png")
const TAG_FRAME := preload("res://art/frames/popup.png")
const TITLE_POSITION := Vector2(24, 12)
const TITLE_HEIGHT := 56.0
const TITLE_FONT_SIZE := 30
const CHIP_POSITION := Vector2(360, 18)
const FRESH_GAP := 24.0
const FRESH_Y := 30.0
const CABINET_RECT := Rect2(32, 80, 1216, 556)
const CABINET_MARGIN := 6
## The cabinet's back (inside the frame), its grain lines and the centre divider.
const BACK_RECT := Rect2(44, 92, 1192, 532)
const GRAIN_STEP := 24.0
const DIVIDER_RECT := Rect2(638, 92, 4, 532)
## The sections: SECTION_ORIGIN + (column * SECTION_STEP.x, row * SECTION_STEP.y), two columns.
const SECTION_ORIGIN := Vector2(56, 96)
const SECTION_STEP := Vector2(592, 176)
const SECTION_SIZE := Vector2(576, 116)
const COLUMNS := 2
const SIGN_RECT := Rect2(0, 2, 160, 26)
const SIGN_FONT_SIZE := 18
const COUNT_POSITION := Vector2(172, 6)
const COUNT_FONT_SIZE := 16
const DONE_POSITION := Vector2(230, 6)
const DONE_ROTATION := -4.0
const FIGURINE_SIZE := Vector2(48, 48)
const FIGURINE_FIRST := Vector2(16, 52)
const FIGURINE_PITCH := 70.0
const FIGURINE_LIFT := 4.0
const PLANK_RECT := Rect2(0, 100, 576, 14)
const PLANK_SHADOW := Rect2(4, 114, 576, 6)
const NONE_POSITION := Vector2(16, 66)
## The hover tag stands level with the figurine, right of it (left of it near the cabinet's right
## edge, TAG_RIGHT_LIMIT), so it never covers the aisle sign.
const TAG_OFFSET := Vector2(62, 2)
const TAG_GAP := 6.0
const TAG_RIGHT_LIMIT := 1236.0
const HINT_POSITION := Vector2(56, 664)
const BACK_RECT_BUTTON := Rect2(1090, 650, 150, 52)
const PENDING_FONT_SIZE := 9
const TITLE_TEXT := "FIGURINE SHELF"
const FIGURINES_TEXT := "FIGURINES"
const COUNT_TEXT := "%d / %d"
const NONE_TEXT := "None yet"
const DONE_TEXT := "ALL COLLECTED"
const FRESH_TEXT := "Every capsule you open puts its figurine here."
const HINT_TEXT := "Hover a figurine for its name."
const BACK_TEXT := "Back"

static var _italic: FontVariation

var _chip: PanelContainer
var _chip_value: Label
var _fresh: Label
var _hint: Label
var _sections: Control
var _tag: PanelContainer
var _tag_name: Label
var _tag_glyph: TextureRect
var _tag_aisle: Label
var _back: FramedButton
var _section_rects: Array[Rect2] = []
var _figurines: Array[Array] = []
var _counts: Array[Label] = []
var _nones: Array[Label] = []
var _dones: Array[Control] = []


func _init() -> void:
	size = STAGE
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var background: ColorRect = ColorRect.new()
	background.color = Palette.BACKGROUND
	background.size = STAGE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var dots: Control = Control.new()
	dots.size = STAGE
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.draw.connect(_draw_dots.bind(dots))
	add_child(dots)
	_build_header()
	_build_cabinet()
	_sections = Control.new()
	_sections.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sections.size = STAGE
	add_child(_sections)
	_hint = UiKit.body_label(HINT_TEXT, 16, Palette.CREAM)
	_hint.add_theme_font_override("font", ArtStyle.bold_font(600))
	_hint.position = HINT_POSITION
	add_child(_hint)
	_back = UiKit.framed_button(
		self, BACK_TEXT, back_pressed.emit, 22, UiKit.SIGN_FRAME, BACK_RECT_BUTTON.size, "ui_back"
	)
	_back.position = BACK_RECT_BUTTON.position
	_build_tag()


## Lays out the shelves of `balance`'s aisles with the figurines of `unlocked`.
func show_collection(balance: BalanceDefinition, unlocked: Dictionary[StringName, int]) -> void:
	for child: Node in _sections.get_children():
		_sections.remove_child(child)
		child.queue_free()
	_section_rects = []
	_figurines = []
	_counts = []
	_nones = []
	_dones = []
	_tag.visible = false
	var owned: int = 0
	var total: int = 0
	for index: int in range(balance.aisles.size()):
		var aisle: AisleDefinition = balance.aisles[index]
		owned += _build_section(index, aisle, unlocked)
		total += aisle.capsule_cards.size()
	_chip_value.text = COUNT_TEXT % [owned, total]
	_fresh.visible = owned == 0
	_fresh.position.x = CHIP_POSITION.x + _chip.get_combined_minimum_size().x + FRESH_GAP
	_hint.visible = owned > 0


## The shelf's rect of aisle `index` (stage coordinates), its figurines, count, None yet label
## and ALL COLLECTED tag (null when not full), and the hover tag (for tests).
func section_rect(index: int) -> Rect2:
	return _section_rects[index]


func figurines(index: int) -> Array[TextureRect]:
	var found: Array[TextureRect] = []
	found.assign(_figurines[index])
	return found


func count_label(index: int) -> Label:
	return _counts[index]


func none_label(index: int) -> Label:
	return _nones[index]


func done_tag(index: int) -> Control:
	return _dones[index]


func tag() -> PanelContainer:
	return _tag


func fresh_label() -> Label:
	return _fresh


func hint_label() -> Label:
	return _hint


func back_button() -> FramedButton:
	return _back


func cabinet_rect() -> Rect2:
	return CABINET_RECT


## Shows the hover tag for `figurine` (one of figurines()), as a hover does.
func show_tag(figurine: TextureRect) -> void:
	var card: CardDefinition = figurine.get_meta(&"card") as CardDefinition
	var aisle: AisleDefinition = figurine.get_meta(&"aisle") as AisleDefinition
	_tag_name.text = card.display_name
	_tag_glyph.texture = load(ArtStyle.glyph_path(aisle)) as Texture2D
	_tag_aisle.text = aisle.display_name
	_tag.size = _tag.get_combined_minimum_size()
	var at: Vector2 = figurine.position + TAG_OFFSET
	if at.x + _tag.size.x > TAG_RIGHT_LIMIT:
		at.x = figurine.position.x - TAG_GAP - _tag.size.x
	_tag.position = at
	_tag.visible = true


static func section_origin(index: int) -> Vector2:
	@warning_ignore("integer_division")
	var row: int = index / COLUMNS
	return SECTION_ORIGIN + Vector2((index % COLUMNS) * SECTION_STEP.x, row * SECTION_STEP.y)


func _build_header() -> void:
	var title: PanelContainer = UiKit.frame_panel(UiKit.SIGN_FRAME, 3, Vector4(26, 0, 26, 4))
	title.position = TITLE_POSITION
	title.custom_minimum_size.y = TITLE_HEIGHT
	add_child(title)
	var title_label: Label = UiKit.display_label(TITLE_TEXT, TITLE_FONT_SIZE, true)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_child(title_label)
	_chip = TopBar.chip(TopBar.CHIP_FRAME)
	_chip.position = CHIP_POSITION
	add_child(_chip)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_chip.add_child(row)
	row.add_child(TopBar.key_label(FIGURINES_TEXT))
	_chip_value = TopBar.value_label(Palette.PAPER)
	row.add_child(_chip_value)
	_fresh = UiKit.body_label(FRESH_TEXT, 16, Palette.CREAM)
	_fresh.add_theme_font_override("font", ArtStyle.bold_font(600))
	_fresh.position = Vector2(CHIP_POSITION.x, FRESH_Y)
	add_child(_fresh)


func _build_cabinet() -> void:
	var cabinet: PanelContainer = UiKit.frame_panel(CABINET, CABINET_MARGIN)
	cabinet.position = CABINET_RECT.position
	cabinet.size = CABINET_RECT.size
	add_child(cabinet)
	var x: float = BACK_RECT.position.x + GRAIN_STEP / 2.0
	while x < BACK_RECT.end.x - 2.0:
		var grain: ColorRect = ColorRect.new()
		grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grain.color = Palette.PLASTER
		grain.position = Vector2(x, BACK_RECT.position.y + 4.0)
		grain.size = Vector2(2, BACK_RECT.size.y - 8.0)
		add_child(grain)
		x += GRAIN_STEP
	var divider: ColorRect = ColorRect.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.color = Palette.WOOD
	divider.position = DIVIDER_RECT.position
	divider.size = DIVIDER_RECT.size
	add_child(divider)


## One aisle's shelf; returns how many of its figurines are collected.
func _build_section(index: int, aisle: AisleDefinition, unlocked: Dictionary) -> int:
	var origin: Vector2 = section_origin(index)
	_section_rects.append(Rect2(origin, SECTION_SIZE))
	var plank: PanelContainer = UiKit.frame_panel(PLANK, 3)
	plank.position = origin + PLANK_RECT.position
	plank.size = PLANK_RECT.size
	var shadow: ColorRect = ColorRect.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.color = Color(Palette.INK, 0.18)
	shadow.position = origin + PLANK_SHADOW.position
	shadow.size = PLANK_SHADOW.size
	_sections.add_child(shadow)
	_sections.add_child(plank)
	_build_sign(origin, aisle)
	var shown: Array[TextureRect] = []
	for card: CardDefinition in aisle.capsule_cards:
		if not unlocked.has(card.id):
			continue
		var at: Vector2 = origin + FIGURINE_FIRST + Vector2(shown.size() * FIGURINE_PITCH, 0)
		shown.append(_build_figurine(card, aisle, at))
	_figurines.append(shown)
	var total: int = aisle.capsule_cards.size()
	var count: Label = UiKit.number_label(
		COUNT_TEXT % [shown.size(), total], COUNT_FONT_SIZE, false
	)
	count.add_theme_color_override("font_color", Palette.INK_LIGHT)
	count.position = origin + COUNT_POSITION
	_sections.add_child(count)
	_counts.append(count)
	var none: Label = UiKit.body_label(NONE_TEXT, 14, Palette.GREY)
	none.add_theme_font_override("font", _italic_font())
	none.position = origin + NONE_POSITION
	none.visible = shown.is_empty()
	_sections.add_child(none)
	_nones.append(none)
	var done: Control = null
	if shown.size() == total:
		done = _done_tag()
		done.position = origin + DONE_POSITION
		_sections.add_child(done)
	_dones.append(done)
	return shown.size()


func _build_sign(origin: Vector2, aisle: AisleDefinition) -> void:
	var path: String = SIGN_PATH % aisle.id
	var frame: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else BASE_SIGN
	var plate: PanelContainer = UiKit.frame_panel(frame, 3, Vector4(6, 0, 6, 2))
	plate.position = origin + SIGN_RECT.position
	plate.size = SIGN_RECT.size
	_sections.add_child(plate)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 6)
	plate.add_child(row)
	var glyph: TextureRect = UiKit.sprite(load(ArtStyle.glyph_path(aisle)) as Texture2D)
	glyph.custom_minimum_size = Vector2(18, 18)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var label: Label = UiKit.display_label(aisle.display_name, SIGN_FONT_SIZE, true)
	label.add_theme_constant_override("outline_size", 4)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)


func _build_figurine(card: CardDefinition, aisle: AisleDefinition, at: Vector2) -> TextureRect:
	var figurine: TextureRect = UiKit.sprite(ArtStyle.item_sprite(card))
	figurine.size = FIGURINE_SIZE
	figurine.position = at
	figurine.mouse_filter = Control.MOUSE_FILTER_STOP
	figurine.set_meta(&"card", card)
	figurine.set_meta(&"aisle", aisle)
	figurine.set_meta(&"rest_y", at.y)
	if figurine.texture == ArtStyle.ITEM_PENDING:
		var name_label: Label = UiKit.body_label(
			card.display_name, PENDING_FONT_SIZE, Palette.INK_LIGHT
		)
		name_label.add_theme_font_override("font", ArtStyle.bold_font(700))
		name_label.add_theme_constant_override("line_spacing", -3)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.position = Vector2(5, 10)
		name_label.size = Vector2(38, 34)
		figurine.add_child(name_label)
	figurine.mouse_entered.connect(_on_figurine_hover.bind(figurine, true))
	figurine.mouse_exited.connect(_on_figurine_hover.bind(figurine, false))
	_sections.add_child(figurine)
	return figurine


func _on_figurine_hover(figurine: TextureRect, inside: bool) -> void:
	var rest_y: float = float(figurine.get_meta(&"rest_y"))
	figurine.position.y = rest_y - FIGURINE_LIFT if inside else rest_y
	if inside:
		show_tag(figurine)
	else:
		_tag.visible = false


func _done_tag() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.MUSTARD_LIGHT
	style.border_color = Palette.MUSTARD_DARKEST
	style.set_border_width_all(2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	panel.rotation_degrees = DONE_ROTATION
	var label: Label = UiKit.body_label(DONE_TEXT, 12, Palette.MUSTARD_DARKEST)
	label.add_theme_font_override("font", ArtStyle.bold_font(800))
	panel.add_child(label)
	return panel


func _build_tag() -> void:
	_tag = UiKit.frame_panel(TAG_FRAME, 3, Vector4(14, 8, 14, 10))
	_tag.visible = false
	add_child(_tag)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	_tag.add_child(column)
	_tag_name = UiKit.display_label("", 22, false)
	column.add_child(_tag_name)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	_tag_glyph = UiKit.sprite(null)
	_tag_glyph.custom_minimum_size = Vector2(18, 18)
	_tag_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_tag_glyph)
	_tag_aisle = UiKit.body_label("", 16, Palette.INK_LIGHT)
	_tag_aisle.add_theme_font_override("font", ArtStyle.bold_font(700))
	row.add_child(_tag_aisle)


## The back's teal-black dots, one art pixel every 8 (the mock-up's backdrop).
func _draw_dots(canvas: Control) -> void:
	var step: float = 8.0 * ArtStyle.ART_SCALE
	var y: float = step / 2.0
	while y < STAGE.y:
		var x: float = step / 2.0
		while x < STAGE.x:
			canvas.draw_rect(
				Rect2(x, y, ArtStyle.ART_SCALE, ArtStyle.ART_SCALE), Palette.TEAL_BLACK
			)
			x += step
		y += step


## The body font at 600, slanted (the muted "None yet").
static func _italic_font() -> Font:
	if _italic == null:
		_italic = ArtStyle.bold_font(600).duplicate() as FontVariation
		_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	return _italic
