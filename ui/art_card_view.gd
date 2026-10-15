class_name ArtCardView
extends CardView
## A card in the pixel-art style (full build plan section 6.1): a 9-slice paper frame, the
## title and base value in the display font, the item's sprite at 2x (a coupon's icon at 1x),
## the tags, the rule and the aisle mark. It keeps CardView's API (body, badge, highlight,
## tags), so the count-up plays it unchanged. The shift screen's row, hand and drag ghost use it
## (#55); the deck view and the reward print-out follow in #56.
##
## The aisle mark (#55, decision 3): a product stocked from an aisle wears the aisle's sign
## colour as a band along its bottom and the aisle's glyph in the sprite box's free corner
## (opposite the price sticker). Staples and coupons have no aisle, so no band and no glyph.
## The price sticker sits top left and the glyph top right: in a full hand each card hides the
## right edge of the one before it, and the base value must stay readable (#55, decision 2).
## The caller passes the aisle (BalanceDefinition.aisle_of). The band takes room only when it
## shows, so the fit test lays every product out with an aisle, its tallest look.
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
## An aisle's glyph (art/icons/aisle_<id>.png, 9 art pixels drawn at 1x), shown at 2x in the
## sprite box's top-right corner, GLYPH_OFFSET in from it.
const GLYPH_PATH := "res://art/icons/aisle_%s.png"
const GLYPH_SCALE := 2
const GLYPH_OFFSET := Vector2(0, 2)

## The value badge is a brass payout plaque (#55, decision D2a): "pays €N" in the number font,
## its face PLAQUE_HEIGHT tall with its top PLAQUE_Y above the card, at least PLAQUE_MIN_WIDTH
## wide and centred over the card. A value of €0 (or one wiped by a denied beat) shows the muted
## face, a cream-shade plate with a brass-dark edge and brass-dark text, not a size change. The
## badge stays a Label (the count-up punches it); the face is a child drawn behind its text,
## with the sharp-pixel material that the text must not get.
const PLAQUE_WORD := "pays"
const PLAQUE_Y := -24.0
const PLAQUE_HEIGHT := 22.0
const PLAQUE_MIN_WIDTH := 80.0
const PLAQUE_FONT_SIZE := 18
## Room between the face's sides and the text, in canvas pixels.
const PLAQUE_PADDING := 8.0
## The badge Label's height, the face centred in it: at least the text's height, so the Label
## never grows past it and its rest y stays fixed (the fit test checks it).
const BADGE_HEIGHT := 26.0

const CARD_FRAME := preload("res://art/frames/card.png")
const CARD_SELECTED_FRAME := preload("res://art/frames/card_selected.png")
const COUPON_FRAME := preload("res://art/frames/coupon.png")
const COUPON_SELECTED_FRAME := preload("res://art/frames/coupon_selected.png")
const PRICE_STICKER := preload("res://art/frames/price_sticker.png")

## The aisle the card is stocked from, or null (a staple or a coupon).
var aisle: AisleDefinition
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
## The aisle's glyph in the sprite box (products only; hidden without an aisle).
var _glyph: TextureRect
## The payout plaque's face behind the badge's text, and its two looks.
var _plaque: Panel
var _plaque_face: StyleBoxTexture
var _muted_face: StyleBoxFlat


func _init(card_instance: CardInstance, card_aisle: AisleDefinition = null) -> void:
	super(card_instance)
	set_aisle(card_aisle)


func set_highlight(highlight: CardView.Highlight) -> void:
	var selected: bool = highlight == CardView.Highlight.SELECTED
	body.add_theme_stylebox_override("panel", _selected_frame if selected else _frame)
	body.position.y = -10.0 if selected else 0.0
	body.modulate = Color(1, 1, 1, 0.55) if highlight == CardView.Highlight.REDRAW else Color.WHITE
	_redraw_mark.visible = highlight == CardView.Highlight.REDRAW


## Shows the payout plaque: "pays €N" on the brass face, or on the muted face at €0. `strong`
## (the count-up's running value) looks the same: the count-up punches the plaque instead.
func show_badge(value: int, _strong: bool) -> void:
	badge.text = plaque_text(value)
	badge.visible = true
	_set_muted(value == 0)
	_fit_plaque()


## A value wiped by a denied beat: the muted face (tomato on brass would not read).
func show_fizzle_badge(value: int) -> void:
	show_badge(value, true)
	_set_muted(true)


func badge_rest_y() -> float:
	return PLAQUE_Y - (BADGE_HEIGHT - PLAQUE_HEIGHT) / 2.0


## Whether the plaque shows its muted face (for tests).
func is_badge_muted() -> bool:
	return _plaque.get_theme_stylebox("panel") == _muted_face


## The plaque's face (for tests and layout checks).
func plaque() -> Control:
	return _plaque


## The plaque's text for a value.
static func plaque_text(value: int) -> String:
	return "%s €%d" % [PLAQUE_WORD, value]


## Marks a product with its aisle: the band in the aisle's sign colour and the aisle's glyph.
## Null (a staple), or any coupon, shows neither.
func set_aisle(card_aisle: AisleDefinition) -> void:
	aisle = card_aisle if card.definition.is_product() else null
	_band.visible = aisle != null
	_band.color = aisle.sign_color if aisle != null else Color.TRANSPARENT
	if _glyph == null:
		return
	var path: String = glyph_path(aisle) if aisle != null else ""
	_glyph.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_glyph.visible = _glyph.texture != null
	if _glyph.texture != null:
		_glyph.size = _glyph.texture.get_size() * GLYPH_SCALE
		var right: float = _column.custom_minimum_size.x - GLYPH_OFFSET.x
		_glyph.position = Vector2(right - _glyph.size.x, GLYPH_OFFSET.y)
	var aisle_text: String = "%s aisle" % aisle.display_name if aisle != null else ""
	_glyph.tooltip_text = aisle_text
	_glyph.accessibility_name = aisle_text


## Whether the aisle band shows (for tests and the screens).
func has_band() -> bool:
	return _band.visible


func band_color() -> Color:
	return _band.color


## The aisle glyph, or null when it isn't shown.
func glyph() -> TextureRect:
	return _glyph if _glyph != null and _glyph.visible else null


## The glyph texture's path for an aisle.
static func glyph_path(card_aisle: AisleDefinition) -> String:
	return GLYPH_PATH % card_aisle.id


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
	_band.custom_minimum_size = Vector2(0, BAND_HEIGHT)
	# Shown by set_aisle: no aisle, no band.
	_band.visible = false
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

	_build_plaque()


## The badge Label (the plaque's text) and its face, a child drawn behind the text.
func _build_plaque() -> void:
	badge = Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_override("font", ArtStyle.number_font())
	badge.add_theme_font_size_override("font_size", PLAQUE_FONT_SIZE)
	badge.add_theme_color_override("font_color", ArtStyle.INK)
	badge.add_theme_constant_override("outline_size", 0)
	badge.visible = false
	add_child(badge)
	_plaque_face = ArtStyle.frame_style(UiKit.PLAQUE_FRAME, UiKit.PLAQUE_MARGIN)
	_muted_face = StyleBoxFlat.new()
	_muted_face.bg_color = Palette.CREAM_SHADE
	_muted_face.border_color = Palette.BRASS_DARK
	_muted_face.set_border_width_all(ArtStyle.ART_SCALE)
	_plaque = Panel.new()
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.show_behind_parent = true
	ArtStyle.use_pixel_material(_plaque)
	badge.add_child(_plaque)
	_set_muted(false)
	badge.text = plaque_text(0)
	_fit_plaque()
	badge.position.y = badge_rest_y()


func _set_muted(muted: bool) -> void:
	var face: StyleBox = _plaque_face
	if muted:
		face = _muted_face
	_plaque.add_theme_stylebox_override("panel", face)
	badge.add_theme_color_override("font_color", Palette.BRASS_DARK if muted else ArtStyle.INK)


## Sizes the badge to its text (at least the plaque's size), centres it over the card and the
## face in it. Its y is left alone: the count-up's scan may be lifting it.
func _fit_plaque() -> void:
	var text: Vector2 = badge.get_minimum_size()
	var width: float = maxf(PLAQUE_MIN_WIDTH, text.x + 2.0 * PLAQUE_PADDING)
	badge.size = Vector2(width, BADGE_HEIGHT)
	badge.position.x = (SIZE.x - width) / 2.0
	badge.pivot_offset = badge.size / 2.0
	_plaque.position = Vector2(0, (BADGE_HEIGHT - PLAQUE_HEIGHT) / 2.0)
	_plaque.size = Vector2(width, PLAQUE_HEIGHT)


## The sprite at its pixel scale, centred in the column; a product's base value sits on a
## price sticker in the box's top-left corner, and its aisle glyph in the top-right one.
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
		_glyph = TextureRect.new()
		# PASS: the glyph shows its tooltip, and a click still reaches the card.
		_glyph.mouse_filter = Control.MOUSE_FILTER_PASS
		_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_glyph.stretch_mode = TextureRect.STRETCH_SCALE
		ArtStyle.use_pixel_material(_glyph)
		_glyph.position = GLYPH_OFFSET
		_glyph.visible = false
		box.add_child(_glyph)
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
		sticker.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
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
