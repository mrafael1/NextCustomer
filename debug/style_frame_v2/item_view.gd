class_name ItemView
extends Control
## One item in style frame v2 (#75, spec sections 3 and 4; round 2, delta sections 3, 5 and 10):
## the card shown as its sprite (a product's 48x48 item at 2x, or the shared coupon slip with the
## coupon's icon) over its price sticker. On the belt (a 120x238 cell) the sprite stands on its
## slot's mat (BeltView draws the mat at BELT_MAT, under the view) and it can carry a payout
## plaque on the mat's top rim and up to two effect chips under the sticker; in the hand tray (a
## 108x168 cell) the sprite stands on a soft shadow. Lifting raises the sprite by LIFT (the
## current scan or a hover). The numbers come from the caller (the ScoreResult); the view never
## scores.

const BELT_SIZE := Vector2(120, 238)
const TRAY_SIZE := Vector2(108, 168)
const SPRITE_SIZE := Vector2(96, 96)
const BELT_SPRITE := Vector2(12, 26)
## The slot's mat, which BeltView draws under the view: inside its ink line and 2 px brass ring
## (6 px) the sprite at rest stands at 12..108 x 26..122, over the ring's 4 px recess.
const BELT_MAT := Rect2(6, 12, 108, 116)
const BELT_STICKER := Vector2(6, 130)
const BELT_PLAQUE := Rect2(20, 0, 80, 22)
## The chips under the sticker, 2 px apart, the lower one ending CHIP_CLEARANCE above the cell's
## foot (the belt's bottom rail).
const BELT_CHIPS: Array[Vector2] = [Vector2(2, 196), Vector2(2, 216)]
const CHIP_CLEARANCE := 4.0
const TRAY_SPRITE := Vector2(6, 4)
const TRAY_SHADOW := Rect2(14, 94, 80, 8)
const TRAY_STICKER := Vector2(0, 104)
const SHADOW_ALPHA := 0.25
const SHADOW_POINTS := 16
const LIFT := 4.0
## The coupon's icon sits on the slip at art offset (14, 19).
const COUPON_ICON_RECT := Rect2(28, 38, 40, 28)
const ITEM_PATH := "res://art/items_v2/%s.png"
const COUPON_ICON_PATH := "res://art/icons/coupon_%s_v2.png"
## The plaque: "pays" in Atkinson, the payout in the number font. A €0 plaque is muted, and
## opaque: a cream-shade face in a dashed brass-dark outline, its text in brass dark.
const PLAQUE_WORD := "pays"
const PLAQUE_WORD_SIZE := 12
const PLAQUE_VALUE_SIZE := 18
const PLAQUE_MARGIN := 3
const DASH := 4.0

const COUPON_SLIP := preload("res://art/items_v2/coupon_slip.png")
const PLAQUE_FRAME := preload("res://art/frames/payout_plaque.png")

var card: CardInstance
var on_belt: bool = false

var _sprite: TextureRect
var _sticker: PriceSticker
var _plaque: Control
var _plaque_value: Label
var _plaque_zero: bool = false
var _chips: Array[EffectChip] = []
var _lifted: bool = false


func _init(
	card_instance: CardInstance, belt: bool, aisle: AisleDefinition, summary_text: String
) -> void:
	card = card_instance
	on_belt = belt
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = BELT_SIZE if belt else TRAY_SIZE
	_sprite = UiKit.sprite(sprite_texture(card.definition))
	_sprite.size = SPRITE_SIZE
	add_child(_sprite)
	var icon: Texture2D = icon_texture(card.definition)
	if icon != null:
		var overlay: TextureRect = UiKit.sprite(icon)
		overlay.position = COUPON_ICON_RECT.position
		overlay.size = COUPON_ICON_RECT.size
		_sprite.add_child(overlay)
	_sticker = PriceSticker.new(card.definition, aisle, summary_text)
	_sticker.position = BELT_STICKER if belt else TRAY_STICKER
	add_child(_sticker)
	set_lifted(false)


func _draw() -> void:
	if on_belt:
		return
	var shadow: PackedVector2Array = PackedVector2Array()
	var centre: Vector2 = TRAY_SHADOW.get_center()
	var radius: Vector2 = TRAY_SHADOW.size / 2.0
	for index: int in range(SHADOW_POINTS):
		var angle: float = TAU * index / SHADOW_POINTS
		var point: Vector2 = centre + Vector2(cos(angle), sin(angle)) * radius
		shadow.append(point.snappedf(ArtStyle.ART_SCALE))
	draw_colored_polygon(shadow, Color(StyleFrameV2.INK, SHADOW_ALPHA))


func sprite() -> TextureRect:
	return _sprite


func sticker() -> PriceSticker:
	return _sticker


## The payout plaque, or null when none is shown.
func plaque() -> Control:
	return _plaque


## The plaque's text as read ("pays €17"), or "" when none is shown.
func plaque_text() -> String:
	if _plaque == null:
		return ""
	return "%s %s" % [PLAQUE_WORD, _plaque_value.text]


func chips() -> Array[EffectChip]:
	return _chips


func is_lifted() -> bool:
	return _lifted


## Raises the sprite by LIFT (the current scan or a hover), or sets it down.
func set_lifted(lifted: bool) -> void:
	_lifted = lifted
	var rest: Vector2 = BELT_SPRITE if on_belt else TRAY_SPRITE
	_sprite.position = rest - Vector2(0, LIFT if lifted else 0.0)


## Shows the payout plaque with `payout` (a belt item; from ScoreResult.payouts).
func show_payout(payout: int) -> void:
	if _plaque == null:
		_plaque = Control.new()
		_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plaque.position = BELT_PLAQUE.position
		_plaque.size = BELT_PLAQUE.size
		ArtStyle.use_pixel_material(_plaque)
		_plaque.draw.connect(_draw_plaque)
		add_child(_plaque)
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		_plaque.add_child(row)
		var word: Label = UiKit.body_label(PLAQUE_WORD, PLAQUE_WORD_SIZE, StyleFrameV2.INK)
		word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		word.size_flags_vertical = Control.SIZE_FILL
		row.add_child(word)
		_plaque_value = UiKit.number_label("", PLAQUE_VALUE_SIZE, false)
		_plaque_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_plaque_value.size_flags_vertical = Control.SIZE_FILL
		row.add_child(_plaque_value)
	_plaque_value.text = "€%d" % payout
	_plaque_zero = payout == 0
	var ink: Color = StyleFrameV2.BRASS_DARK if _plaque_zero else StyleFrameV2.INK
	for label: Label in [_plaque.get_child(0).get_child(0) as Label, _plaque_value]:
		label.add_theme_color_override("font_color", ink)
	_plaque.queue_redraw()


## Whether the plaque shows €0 in its muted look.
func is_plaque_muted() -> bool:
	return _plaque != null and _plaque_zero


## Adds a chip under the sticker (at most EffectChip.MAX_PER_CELL; the caller folds the rest).
func add_chip(chip: EffectChip) -> void:
	chip.position = BELT_CHIPS[_chips.size()]
	_chips.append(chip)
	add_child(chip)


## The sprite's rect in this view's parent's coordinates.
func sprite_rect() -> Rect2:
	return Rect2(position + _sprite.position, _sprite.size)


## The sticker's rect in this view's parent's coordinates.
func sticker_rect() -> Rect2:
	return Rect2(position + _sticker.position, _sticker.size)


## What a flipped scan popup opens below, in this view's parent's coordinates: the sticker and,
## on the belt, the chips' places under it.
func below_rect() -> Rect2:
	var rect: Rect2 = sticker_rect()
	if on_belt:
		for chip: Vector2 in BELT_CHIPS:
			rect = rect.merge(Rect2(position + chip, EffectChip.SIZE))
	return rect


## The item's sprite: its own item art, or the shared coupon slip.
static func sprite_texture(definition: CardDefinition) -> Texture2D:
	if definition.is_coupon():
		return COUPON_SLIP
	var path: String = ITEM_PATH % definition.id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return ArtStyle.item_texture(definition)


## A coupon's icon over the slip, or null (products, or a coupon without its icon yet).
static func icon_texture(definition: CardDefinition) -> Texture2D:
	if not definition.is_coupon():
		return null
	var path: String = COUPON_ICON_PATH % definition.id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _draw_plaque() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _plaque.size)
	if not _plaque_zero:
		_plaque.draw_style_box(ArtStyle.frame_style(PLAQUE_FRAME, PLAQUE_MARGIN), rect)
		return
	# The muted €0 plaque: an opaque cream-shade face (corners cut on the art grid) in a dashed
	# brass-dark outline.
	var edge: float = ArtStyle.ART_SCALE
	_plaque.draw_rect(
		Rect2(edge, 0, rect.size.x - 2.0 * edge, rect.size.y), StyleFrameV2.CREAM_SHADE
	)
	_plaque.draw_rect(
		Rect2(0, edge, rect.size.x, rect.size.y - 2.0 * edge), StyleFrameV2.CREAM_SHADE
	)
	var x: float = edge
	while x < rect.size.x - edge:
		var dash: float = minf(DASH, rect.size.x - edge - x)
		_plaque.draw_rect(Rect2(x, 0, dash, edge), StyleFrameV2.BRASS_DARK)
		_plaque.draw_rect(Rect2(x, rect.size.y - edge, dash, edge), StyleFrameV2.BRASS_DARK)
		x += 2.0 * DASH
	var y: float = edge
	while y < rect.size.y - edge:
		var dash: float = minf(DASH, rect.size.y - edge - y)
		_plaque.draw_rect(Rect2(0, y, edge, dash), StyleFrameV2.BRASS_DARK)
		_plaque.draw_rect(Rect2(rect.size.x - edge, y, edge, dash), StyleFrameV2.BRASS_DARK)
		y += 2.0 * DASH
