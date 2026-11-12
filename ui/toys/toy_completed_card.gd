class_name ToyCompletedCard
extends Control
## The COMPLETED! card (v1.05, mock-up toy_shelf_unlock.html, "The COMPLETED! card"; v1.26
## polish, the user's asks): when a capsule completes its aisle (StartSetupRules.completed: every
## item of the aisle collected), the TOY MACHINES' figurine join (ToyLineupJoin) pops this card
## over its shade. On the popup frame: the aisle's sign band (its glyph and name, both at 2x), a
## COMPLETED rubber stamp slammed onto it, and OK. The stamp (stamp_art: an inked double ring
## with breaks in the ink round a pale wash, the word in tomato dark hard pixel letters) is
## stamped on the aisle's name (review fix: it sat under the band): its ring and wash cross the
## lower part of the name, which still reads above and through it. No rules, pips or stock footer
## since
## v1.26: what a completion unlocks is for the next run's tutorial to explain. It needs OK: it
## arms ResultsPanel.ARM_MS after it is shown, once the mouse is up; then OK, a click anywhere on
## the join, Enter or Space close it (`closed`). Sizes in canvas px.

signal closed

const WIDTH := 380.0
## The card's top on the stage (a taller card is centred instead) and its shadow's offset.
const TOP := 150.0
const SHADOW_OFFSET := Vector2(6, 8)
const SHADOW_ALPHA := 0.35
const FRAME := preload("res://art/frames/popup.png")
const FRAME_MARGIN := 4
const PADDING := Vector4(20, 18, 20, 18)
const SIGN_PATH := "res://art/frames/aisle_sign_%s.png"
const BASE_SIGN := preload("res://art/frames/aisle_sign.png")
## The band: BAND_HEIGHT tall, the glyph at 4x, the name's font pixels 2 art px.
const BAND_HEIGHT := 72.0
const GLYPH_SIZE := Vector2(36, 36)
const NAME_SCALE := 2
## The stamp: its word's font pixels STAMP_SCALE art px, STAMP_PADDING art px round it (its size
## a multiple of 4 art px, so the slam's 1.5x step stays on whole canvas px); it rises
## STAMP_OVERLAP px into the band, over the name's foot. Its ink breaks at uneven texels of the
## ring (a fixed scatter: 2 of every INK_BREAK) and its face is a STAMP_WASH of paper.
const STAMP_SCALE := 2
const STAMP_PADDING := Vector2i(8, 7)
const STAMP_OVERLAP := 26.0
const INK_BREAK := 23
const STAMP_WASH := 0.55
## The gap between the card's rows.
const SEPARATION := 12
const OK_SIZE := Vector2(150, 44)
const STAMP_TEXT := "COMPLETED"
const OK_TEXT := "OK"

var _shadow: ColorRect
var _frame: PanelContainer
var _column: VBoxContainer
var _band: PanelContainer
var _stamp: TextureRect
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


## Every player-facing string the card can show (the no-"gacha" check).
static func copy() -> PackedStringArray:
	return PackedStringArray([STAMP_TEXT, OK_TEXT])


## Builds the card for `aisle`, just completed. It is laid out on the stage (`stage_size`) but
## stays hidden: the join shows it and slams the stamp in.
func build(aisle: AisleDefinition, stage_size: Vector2) -> void:
	for child: Node in _frame.get_children():
		_frame.remove_child(child)
		child.free()
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", SEPARATION)
	_frame.add_child(_column)
	_band = _sign_band(aisle)
	_column.add_child(_band)
	_column.add_child(_stamp_holder())
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


## The pieces, for the join and the tests: the aisle's sign band, the COMPLETED stamp (the join
## slams it in), OK and the frame.
func band() -> PanelContainer:
	return _band


func stamp() -> TextureRect:
	return _stamp


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


## The aisle's sign band: its frame, glyph and name, at 2x.
func _sign_band(aisle: AisleDefinition) -> PanelContainer:
	var path: String = SIGN_PATH % aisle.id
	var sign_frame: Texture2D = (
		load(path) as Texture2D if ResourceLoader.exists(path) else BASE_SIGN
	)
	var plate: PanelContainer = UiKit.frame_panel(sign_frame, 3, Vector4(12, 0, 12, 2))
	plate.custom_minimum_size.y = BAND_HEIGHT
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	plate.add_child(row)
	var glyph: TextureRect = UiKit.sprite(load(ArtStyle.glyph_path(aisle)) as Texture2D)
	glyph.custom_minimum_size = GLYPH_SIZE
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var name_line: Control = _pixel_line(aisle.display_name.to_upper(), Palette.PAPER, NAME_SCALE)
	name_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_line)
	return plate


## The stamp, centred on the band and raised STAMP_OVERLAP px into it, over the name's lower
## part (drawn over it: it comes later in the column).
func _stamp_holder() -> Control:
	var art: float = ArtStyle.ART_SCALE
	var word: Control = _pixel_line(STAMP_TEXT, Palette.TOMATO_DARK, STAMP_SCALE)
	var inside: Vector2i = Vector2i((word.custom_minimum_size / art).ceil()) + STAMP_PADDING * 2
	var cells: Vector2i = Vector2i(ceili(inside.x / 4.0) * 4, ceili(inside.y / 4.0) * 4)
	_stamp = UiKit.sprite(stamp_art(cells))
	_stamp.name = "Stamp"
	_stamp.size = Vector2(cells) * art
	word.position = ((_stamp.size - word.custom_minimum_size) / 2.0 / art).floor() * art
	_stamp.add_child(word)
	# Its holder is a plain Control, so the join's scale isn't reset by a container's layout.
	_stamp.pivot_offset = _stamp.size / 2.0
	_stamp.position = Vector2(0, -STAMP_OVERLAP - SEPARATION)
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.custom_minimum_size = _stamp.size - Vector2(0, STAMP_OVERLAP + SEPARATION)
	holder.add_child(_stamp)
	return holder


## The rubber stamp's face `cells` art px: a tomato dark double ring (corners clipped, a texel
## of wash between the rings) whose ink breaks at a fixed scatter of texels round it, as a real
## stamp prints, round a STAMP_WASH paper face.
static func stamp_art(cells: Vector2i) -> ImageTexture:
	var art: StorefrontArt = StorefrontArt.new(cells, Vector2i.ZERO)
	var w: int = cells.x
	var h: int = cells.y
	art.rect(Rect2i(1, 1, w - 2, h - 2), Color(Palette.PAPER, STAMP_WASH))
	var ink: Color = Palette.TOMATO_DARK
	var step: int = 0
	for ring: int in [0, 2]:
		var box: Rect2i = Rect2i(ring, ring, w - ring * 2, h - ring * 2)
		var path: Array[Vector2i] = []
		for x: int in range(box.position.x + 1, box.end.x - 1):
			path.append_array([Vector2i(x, box.position.y), Vector2i(x, box.end.y - 1)])
		for y: int in range(box.position.y + 1, box.end.y - 1):
			path.append_array([Vector2i(box.position.x, y), Vector2i(box.end.x - 1, y)])
		for at: Vector2i in path:
			step += 1
			if (step * 37) % INK_BREAK >= 2:
				art.px(at.x, at.y, ink)
	return ImageTexture.create_from_image(art.image)


## A PixelLine a container can lay out (its minimum size is its line).
static func _pixel_line(text: String, colour: Color, word_scale: int) -> Control:
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: PixelLine = PixelLine.new()
	line.show_tokens(PixelLine.split(text), colour, colour, word_scale)
	holder.add_child(line)
	holder.custom_minimum_size = Vector2(line.width(), line.size.y)
	return holder


static func _centred(control: Control) -> Control:
	var holder: CenterContainer = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(control)
	return holder
