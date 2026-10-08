class_name ArtCardView
extends CardView
## A card in the pixel-art style (full build plan section 6.1): a 9-slice paper frame, the
## title and base value in the display font, the item's sprite at 2x (a coupon's icon at 1x),
## the tags, the rule and the aisle band. It keeps CardView's API (body, badge, highlight,
## tags), so the count-up plays it unchanged. The style frame uses it; the real screens adopt it
## in phase 3.
##
## SIZE.y is set by the fit test (tests/ui/art_card_view_test.gd): every card's title, tags and
## rule must fit.

const SIZE := Vector2(120, 200)
## The frame textures' margin, in art pixels (outline, highlight, one pixel of paper).
const FRAME_MARGIN := 3
const PADDING := Vector2(7, 6)
## A coupon's text stays inside its perforation (4 art pixels in).
const COUPON_PADDING := Vector2(11, 10)
const SEPARATION := 2
const LINE_SPACING := 0
const TITLE_SIZE := 15
const VALUE_SIZE := 22
const TAG_SIZE := 11
const RULE_SIZE := 12
## The sprite's box: 32 art pixels at 2x for a product, a 32-pixel icon at 1x for a coupon.
## A product's box crops the sprite's top 2 art rows (4 canvas pixels), which every item leaves
## empty: tools/pixel_art.py checks it (ITEM_EMPTY_TOP_ROWS).
const PRODUCT_ART_SCALE := 2
const PRODUCT_ART_CROP := 4
const COUPON_ART_SCALE := 1
const ART_SPRITE_SIZE := 32
## The price sticker's margin, in art pixels.
const STICKER_MARGIN := 2
## The aisle band along the bottom of a product (section 7.2), in canvas pixels.
const BAND_HEIGHT := 6

const CARD_FRAME := preload("res://art/frames/card.png")
const CARD_SELECTED_FRAME := preload("res://art/frames/card_selected.png")
const COUPON_FRAME := preload("res://art/frames/coupon.png")
const COUPON_SELECTED_FRAME := preload("res://art/frames/coupon_selected.png")
const PRICE_STICKER := preload("res://art/frames/price_sticker.png")

var _frame: StyleBoxTexture
var _selected_frame: StyleBoxTexture
## The content column, exposed for the fit test.
var _column: VBoxContainer
var _rule_label: Label
var _band: ColorRect
## The base value's price sticker (products only), exposed for the fit test.
var _sticker: PanelContainer
## The sprite's box, exposed for the fit test.
var _art: Control


func set_highlight(highlight: CardView.Highlight) -> void:
	var selected: bool = highlight == CardView.Highlight.SELECTED
	body.add_theme_stylebox_override("panel", _selected_frame if selected else _frame)
	body.position.y = -10.0 if selected else 0.0
	body.modulate = Color(1, 1, 1, 0.55) if highlight == CardView.Highlight.REDRAW else Color.WHITE
	_redraw_mark.visible = highlight == CardView.Highlight.REDRAW


## The band's colour: the card's aisle sign, when the caller knows it.
func set_band_color(color: Color) -> void:
	_band.color = color


## The space between the frame's edge and the text.
func padding() -> Vector2:
	return COUPON_PADDING if card.definition.is_coupon() else PADDING


func _fit_body() -> void:
	body.size = SIZE


func _on_body_resized() -> void:
	if body.size != SIZE:
		_fit_body.call_deferred()


func _build() -> void:
	var definition: CardDefinition = card.definition
	var coupon: bool = definition.is_coupon()
	custom_minimum_size = SIZE
	body = PanelContainer.new()
	body.size = SIZE
	body.pivot_offset = SIZE / 2.0
	body.clip_contents = true
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(body)
	_frame = _frame_style(COUPON_FRAME if coupon else CARD_FRAME)
	_selected_frame = _frame_style(COUPON_SELECTED_FRAME if coupon else CARD_SELECTED_FRAME)
	body.add_theme_stylebox_override("panel", _frame)
	add_child(body)
	# A card built inside a hidden panel measures its wrapped text at width 0 and grows very
	# tall; a Control never shrinks back by itself, so the body snaps back to its size once its
	# text is measured again.
	body.resized.connect(_on_body_resized)
	body.minimum_size_changed.connect(_on_body_resized)

	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A fixed width from the start, so wrapped text is never measured at width 0.
	_column.custom_minimum_size = Vector2(SIZE.x - 2.0 * padding().x, 0)
	_column.add_theme_constant_override("separation", SEPARATION)
	body.add_child(_column)

	var title: Label = _text(definition.display_name, ArtStyle.DISPLAY_FONT, TITLE_SIZE)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(title)
	_art = _art_box(definition)
	_column.add_child(_art)

	var kind_text: String = "COUPON" if coupon else " · ".join(definition.tags)
	_tags_label = _text(kind_text, ArtStyle.BODY_FONT, TAG_SIZE)
	_tags_label.modulate = Color(1, 1, 1, 0.75)
	_tags_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_tags_label)

	_rule_label = _text(definition.rule_text, ArtStyle.BODY_FONT, RULE_SIZE)
	_rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rule_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rule_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_column.add_child(_rule_label)

	_band = ColorRect.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.custom_minimum_size = Vector2(0, BAND_HEIGHT if definition.is_product() else 0)
	_band.color = Palette.TEAL
	_band.visible = definition.is_product()
	_column.add_child(_band)

	_redraw_mark = _text("REDRAW", ArtStyle.DISPLAY_FONT, 18)
	_redraw_mark.add_theme_color_override("font_color", Palette.TOMATO)
	_redraw_mark.add_theme_constant_override("outline_size", 4)
	_redraw_mark.add_theme_color_override("font_outline_color", Palette.PAPER)
	_redraw_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_redraw_mark.position = Vector2(0, SIZE.y / 2.0 - 12)
	_redraw_mark.size = Vector2(SIZE.x, 24)
	_redraw_mark.visible = false
	add_child(_redraw_mark)

	badge = Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.size = Vector2(SIZE.x, 36)
	badge.position = Vector2(0, BADGE_Y)
	badge.pivot_offset = badge.size / 2.0
	badge.add_theme_font_override("font", ArtStyle.number_font())
	badge.add_theme_constant_override("outline_size", 6)
	badge.add_theme_color_override("font_outline_color", ArtStyle.INK)
	badge.visible = false
	add_child(badge)


## The sprite at its pixel scale, centred in the column; a product's base value sits on a
## price sticker in the box's top-right corner.
func _art_box(definition: CardDefinition) -> Control:
	var coupon: bool = definition.is_coupon()
	var art_scale: int = COUPON_ART_SCALE if coupon else PRODUCT_ART_SCALE
	var crop: int = 0 if coupon else PRODUCT_ART_CROP
	var sprite_size: float = ART_SPRITE_SIZE * art_scale
	var box: Control = Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.clip_contents = true
	box.custom_minimum_size = Vector2(0, sprite_size - crop)
	var art: TextureRect = TextureRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = ArtStyle.item_texture(definition)
	ArtStyle.use_pixel_material(art)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.position = Vector2((_column.custom_minimum_size.x - sprite_size) / 2.0, -crop)
	art.size = Vector2(sprite_size, sprite_size)
	box.add_child(art)
	if definition.is_product():
		var sticker: PanelContainer = PanelContainer.new()
		_sticker = sticker
		sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ArtStyle.use_pixel_material(sticker)
		var style: StyleBoxTexture = ArtStyle.frame_style(PRICE_STICKER, STICKER_MARGIN)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 0
		style.content_margin_bottom = 2
		sticker.add_theme_stylebox_override("panel", style)
		var value: Label = _text(str(definition.base), ArtStyle.number_font(), VALUE_SIZE)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sticker.add_child(value)
		box.add_child(sticker)
		sticker.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		sticker.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	return box


func _frame_style(texture: Texture2D) -> StyleBoxTexture:
	var style: StyleBoxTexture = ArtStyle.frame_style(texture, FRAME_MARGIN)
	style.content_margin_left = padding().x
	style.content_margin_right = padding().x
	style.content_margin_top = padding().y
	style.content_margin_bottom = padding().y
	return style


func _text(text: String, font: Font, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ArtStyle.INK)
	# The fonts carry their own line gap; Label's default extra spacing makes rules too tall.
	label.add_theme_constant_override("line_spacing", LINE_SPACING)
	return label
