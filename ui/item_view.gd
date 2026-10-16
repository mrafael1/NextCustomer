class_name ItemView
extends CardView
## A card shown as an item on the counter (#75; style frame v2's spec sections 3 and 4): its
## sprite (a product's 48x48 art at 2x, or the shared coupon slip with the coupon's icon) over
## its price sticker. It keeps CardView's API (body, badge, center, highlight, tags), so the
## count-up plays it unchanged.
##
## Three forms. On the belt (a BELT_SIZE cell; mock-up B2, #80) the sprite stands on the belt's top
## face with the payout plaque over it, the sticker is its ticket on the price rail, and up to
## EffectChip.MAX_PER_CELL effect chips sit between the sprite's foot and the ticket. In the hand's
## tray (a TRAY_SIZE cell) the sprite stands on a soft shadow. A drag's ghost (GHOST, CardDrag) is
## the sprite alone, in a SPRITE_SIZE view with no sticker. `body` holds only the sprite, so the
## count-up's punches, shakes and lifts move the sprite while the sticker and chips stay still and
## readable; `center()` is the sprite's middle. The scan lifts the sprite and plaque by LIFT
## (scan_lift), which keeps the sprite clear of its plaque.
##
## An undrawn product shows the dashed art-pending box with its name printed in it, and a coupon
## without an icon the real slip with its name in the icon's place (#75, decision 3A). The view
## is built neutrally (CardView builds it before the form is known) and then laid out for its
## form. Every number comes from the card's data or the caller (the ScoreResult): the view never
## scores.

## The pointer entered or left the item: its sprite, sticker and chips (hit_rect).
signal hovered(view: ItemView)
signal unhovered(view: ItemView)

enum Form { TRAY, BELT, GHOST }

const BELT_SIZE := Vector2(116, 232)
const TRAY_SIZE := Vector2(108, 168)
const SPRITE_SIZE := Vector2(96, 96)
## On the belt the sprite stands with its foot on the top face (the cell's top is the plaque's),
## and the sticker hangs on the price rail.
const BELT_SPRITE := Vector2(10, 28)
const TRAY_SPRITE := Vector2(6, 4)
const BELT_STICKER := Vector2(4, 166)
const TRAY_STICKER := Vector2(0, 104)
## The plaque face's top: the cell's top on the belt (the sprite, lifted, touches it and never
## runs under it), above the cell in the tray (where no count-up shows it).
const BELT_PLAQUE_Y := 0.0
const TRAY_PLAQUE_Y := -24.0
## How far a scan or a selection raises the sprite.
const LIFT := 4.0
## The chips above the sticker (from the sticker's top-left), CHIP_PITCH apart: the lower one ends
## CHIP_CLEARANCE above the ticket. Belt items only.
const CHIP_OFFSET := Vector2(-4, -42)
const CHIP_PITCH := 20.0
const CHIP_CLEARANCE := 4.0
## The tray's soft shadow under the sprite.
const TRAY_SHADOW := Rect2(14, 94, 80, 8)
const SHADOW_ALPHA := 0.25
const SHADOW_POINTS := 16
## A coupon's icon sits on the slip at art offset (14, 19), in sprite coordinates.
const COUPON_ICON_RECT := Rect2(28, 38, 40, 28)
## The undrawn item's name: inside the art-pending box's dashed line (canvas 10..86 x 20..96),
## or on the slip's paper where the icon goes. Bold Atkinson, at most NAME_LINES lines.
const PENDING_NAME_RECT := Rect2(12, 24, 72, 68)
const COUPON_NAME_RECT := Rect2(26, 32, 60, 42)
const NAME_SIZE := 12
const NAME_WEIGHT := 700
const NAME_LINE_SPACING := -2
const NAME_LINES := 3
## The printed name's node name on the art (item_art).
const PRINTED_NAME := "PrintedName"
## A redraw-marked item fades to REDRAW_ALPHA; its REDRAW tag covers the sticker's glyph corner
## (sticker coordinates), clear of the base value (or COUPON) and the summary.
const REDRAW_ALPHA := 0.55
const REDRAW_RECT := Rect2(56, 6, 48, 22)
const REDRAW_TEXT := "REDRAW"
const REDRAW_SIZE := 11
## The tag's text inside its face, in canvas pixels.
const REDRAW_PADDING := 3

## The aisle the item is stocked from, or null (a staple or a coupon).
var aisle: AisleDefinition
var form: Form = Form.TRAY
## A hover scan (ScanController) lifts the sprite by LIFT, as a selection does; let go, the
## sprite goes back to where its highlight puts it.
var lifted: bool = false:
	set(value):
		lifted = value
		_place_body()
## Holds `body` at the sprite's rest place: the count-up moves `body` from (0, 0).
var _stand: Control
var _sprite: TextureRect
var _name_label: Label
var _sticker: PriceSticker
var _plaque: PayoutPlaque
var _highlight: CardView.Highlight = CardView.Highlight.NONE
var _tags: PackedStringArray = PackedStringArray()
## Every chip added, in order; the shown ones fold past EffectChip.MAX_PER_CELL.
var _chip_texts: PackedStringArray = PackedStringArray()
var _chip_fizzles: Array[bool] = []
var _chips: Array[EffectChip] = []


func _init(
	card_instance: CardInstance, card_aisle: AisleDefinition = null, item_form: Form = Form.TRAY
) -> void:
	super(card_instance)
	var definition: CardDefinition = card.definition
	aisle = card_aisle if definition.is_product() else null
	if definition.is_product():
		_tags = definition.tags.duplicate()
	_sticker = PriceSticker.new(definition, aisle)
	add_child(_sticker)
	move_child(_sticker, _stand.get_index() + 1)
	set_form(item_form)


## Lays the item out as a belt item, a tray item or a drag's ghost: its size, the sprite's,
## sticker's, plaque's and chips' places.
func set_form(item_form: Form) -> void:
	form = item_form
	var belt: bool = form == Form.BELT
	var ghost: bool = form == Form.GHOST
	custom_minimum_size = BELT_SIZE if belt else (SPRITE_SIZE if ghost else TRAY_SIZE)
	size = custom_minimum_size
	_stand.position = BELT_SPRITE if belt else (Vector2.ZERO if ghost else TRAY_SPRITE)
	_sticker.position = BELT_STICKER if belt else TRAY_STICKER
	_sticker.visible = not ghost
	_redraw_mark.position = _sticker.position + REDRAW_RECT.position
	_plaque.centre_x = size.x / 2.0
	_plaque.position.x = (size.x - _plaque.size.x) / 2.0
	_plaque.position.y = badge_rest_y()
	_lay_out_chips()
	queue_redraw()


## SELECTED lifts the sprite by LIFT inside gold brackets; REDRAW fades the item to REDRAW_ALPHA
## and shows the REDRAW tag on its sticker.
func set_highlight(highlight: CardView.Highlight) -> void:
	_highlight = highlight
	_place_body()
	var alpha: float = REDRAW_ALPHA if highlight == CardView.Highlight.REDRAW else 1.0
	body.modulate = Color(1, 1, 1, alpha)
	_sticker.modulate.a = alpha
	_redraw_mark.visible = highlight == CardView.Highlight.REDRAW
	queue_redraw()


## Shows the payout plaque: "pays €N" on the brass face, or on the muted face at €0. `strong`
## (the count-up's running value) looks the same: the count-up punches the plaque instead.
func show_badge(value: int, _strong: bool) -> void:
	_plaque.show_value(value, value == 0)


## A value wiped by a denied beat: the muted face.
func show_fizzle_badge(value: int) -> void:
	_plaque.show_value(value, true)


func badge_rest_y() -> float:
	return PayoutPlaque.rest_y(BELT_PLAQUE_Y if form == Form.BELT else TRAY_PLAQUE_Y)


func scan_lift() -> float:
	return -LIFT


## The sprite's middle at rest, global: the count-up's flights, stamps and links land on it.
func center() -> Vector2:
	return _stand.get_global_rect().get_center()


## Keeps the tags after the context pass (e.g. Breakfast from a sticker) for the scan popup's
## tag line. Products only.
func set_tags(item_tags: PackedStringArray) -> void:
	if card.definition.is_product():
		_tags = item_tags.duplicate()


func add_tag(tag: String) -> void:
	if card.definition.is_product() and not _tags.has(tag):
		_tags.append(tag)


## The item's tags: its own, or as set_tags and add_tag left them. None for a coupon.
func tags() -> PackedStringArray:
	return _tags.duplicate()


func sprite() -> TextureRect:
	return _sprite


## Tints the sprite itself: `body` draws nothing, so its self_modulate would not show. The
## sprite's printed name and overlay keep their colours.
func set_push_tint(tint: Color) -> void:
	_sprite.self_modulate = tint


func sticker() -> PriceSticker:
	return _sticker


## The undrawn item's printed name, or null when its art is drawn.
func name_label() -> Label:
	return _name_label


## Adds an effect chip above the sticker (a belt item's). Past EffectChip.MAX_PER_CELL chips the
## last shown one reads "+N more" for itself and the rest. Returns the chip that shows this one;
## it stays the same node, updated in place, until clear_chips.
func add_chip(text: String, fizzle: bool) -> EffectChip:
	_chip_texts.append(text)
	_chip_fizzles.append(fizzle)
	_lay_out_chips()
	return _chips[_chips.size() - 1]


func clear_chips() -> void:
	_chip_texts.clear()
	_chip_fizzles.clear()
	for chip: EffectChip in _chips:
		chip.free()
	_chips.clear()


## The chips shown (at most EffectChip.MAX_PER_CELL).
func chips() -> Array[EffectChip]:
	return _chips.duplicate()


## The selected item's gold brackets (this view's coordinates), or an empty rect.
func brackets() -> Rect2:
	if _highlight != CardView.Highlight.SELECTED:
		return Rect2()
	return Rect2(_stand.position + body.position, SPRITE_SIZE).grow(ScanOverlay.BRACKET_OUTSET)


## Where the pointer hovers and clicks the item (this view's coordinates): the sprite (lifted or
## not), the sticker and the chips shown.
func hit_rect() -> Rect2:
	var rect: Rect2 = Rect2(_stand.position - Vector2(0, LIFT), SPRITE_SIZE + Vector2(0, LIFT))
	rect = rect.merge(Rect2(_sticker.position, PriceSticker.SIZE))
	for chip: EffectChip in _chips:
		rect = rect.merge(Rect2(chip.position, EffectChip.SIZE))
	return rect


## What a flipped scan popup opens below (global): the sticker and, on the belt, the chips'
## places under it, shown or not.
func below_rect() -> Rect2:
	var rect: Rect2 = Rect2(_sticker.position, PriceSticker.SIZE)
	if form == Form.BELT:
		for place: int in range(EffectChip.MAX_PER_CELL):
			rect = rect.merge(Rect2(_chip_position(place), EffectChip.SIZE))
	return get_global_transform() * rect


func _has_point(point: Vector2) -> bool:
	return hit_rect().has_point(point)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hovered.emit(self)
	elif what == NOTIFICATION_MOUSE_EXIT:
		unhovered.emit(self)


## The tray's soft shadow under the sprite, and a selected item's gold brackets.
func _draw() -> void:
	if form == Form.TRAY:
		var shadow: PackedVector2Array = PackedVector2Array()
		var centre: Vector2 = TRAY_SHADOW.get_center()
		var radius: Vector2 = TRAY_SHADOW.size / 2.0
		for index: int in range(SHADOW_POINTS):
			var angle: float = TAU * index / SHADOW_POINTS
			var point: Vector2 = centre + Vector2(cos(angle), sin(angle)) * radius
			shadow.append(point.snappedf(ArtStyle.ART_SCALE))
		draw_colored_polygon(shadow, Color(Palette.INK, SHADOW_ALPHA))
	var marked: Rect2 = brackets()
	if marked.size != Vector2.ZERO:
		ScanOverlay.draw_brackets(self, marked, Palette.GOLD)


## Lifts the sprite by LIFT while it is selected or scanned, else rests it.
func _place_body() -> void:
	var up: bool = lifted or _highlight == CardView.Highlight.SELECTED
	body.position.y = -LIFT if up else 0.0


## Snaps the sprite and the REDRAW tag back to their sizes: built outside the tree, a Label
## measures its text in the default font, and a Control never shrinks back by itself.
func _fit_body() -> void:
	body.size = SPRITE_SIZE
	_redraw_mark.size = REDRAW_RECT.size


## The form-neutral parts: the sprite in `body` on its stand, the REDRAW tag and the plaque.
## _init adds the sticker and lays them out for the form.
func _build() -> void:
	var definition: CardDefinition = card.definition
	_stand = Control.new()
	_stand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stand.size = SPRITE_SIZE
	add_child(_stand)
	body = PanelContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	body.size = SPRITE_SIZE
	body.pivot_offset = SPRITE_SIZE / 2.0
	_stand.add_child(body)
	_sprite = item_art(definition)
	body.add_child(_sprite)
	_name_label = _sprite.get_node_or_null(PRINTED_NAME) as Label
	_redraw_mark = UiKit.display_label(REDRAW_TEXT, REDRAW_SIZE, false)
	_redraw_mark.add_theme_color_override("font_color", Palette.PAPER)
	var tag_face: StyleBoxFlat = StyleBoxFlat.new()
	tag_face.bg_color = Palette.TOMATO
	tag_face.border_color = Palette.TOMATO_DARK
	tag_face.set_border_width_all(ArtStyle.ART_SCALE)
	tag_face.set_content_margin_all(0)
	tag_face.content_margin_left = REDRAW_PADDING
	tag_face.content_margin_right = REDRAW_PADDING
	_redraw_mark.add_theme_constant_override("outline_size", 0)
	_redraw_mark.add_theme_stylebox_override("normal", tag_face)
	_redraw_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_redraw_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_redraw_mark.size = REDRAW_RECT.size
	_redraw_mark.visible = false
	add_child(_redraw_mark)
	_plaque = PayoutPlaque.new()
	badge = _plaque
	add_child(_plaque)


## An item's SPRITE_SIZE art, as the item shows it (and the monitor, #80): its sprite, with a
## coupon's icon on its slip, or the item's name printed (PRINTED_NAME) on an art-pending box or
## on a slip without an icon.
static func item_art(definition: CardDefinition) -> TextureRect:
	var art: TextureRect = UiKit.sprite(ArtStyle.item_sprite(definition))
	art.size = SPRITE_SIZE
	var icon: Texture2D = ArtStyle.coupon_icon(definition)
	if icon != null:
		var overlay: TextureRect = UiKit.sprite(icon)
		overlay.position = COUPON_ICON_RECT.position
		overlay.size = COUPON_ICON_RECT.size
		art.add_child(overlay)
	elif definition.is_coupon() or art.texture == ArtStyle.ITEM_PENDING:
		art.add_child(_printed_name(definition))
	return art


## The item's name printed on its art-pending box, or on a coupon's slip.
static func _printed_name(definition: CardDefinition) -> Label:
	var coupon: bool = definition.is_coupon()
	var label: Label = UiKit.body_label(
		definition.display_name, NAME_SIZE, Palette.INK if coupon else Palette.GREY_DARK
	)
	label.add_theme_font_override("font", ArtStyle.bold_font(NAME_WEIGHT))
	label.add_theme_constant_override("line_spacing", NAME_LINE_SPACING)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var rect: Rect2 = COUPON_NAME_RECT if coupon else PENDING_NAME_RECT
	label.name = PRINTED_NAME
	label.position = rect.position
	label.size = rect.size
	return label


## Shows the chips added in place: the first MAX_PER_CELL - 1, then the last shown one, or
## "+N more" for it and the rest. Existing chips are updated, never rebuilt, so a chip that
## add_chip returned stays valid (and keeps any tween on it) until clear_chips.
func _lay_out_chips() -> void:
	var count: int = _chip_texts.size()
	for place: int in range(mini(count, EffectChip.MAX_PER_CELL)):
		var text: String = _chip_texts[place]
		var fizzle: bool = _chip_fizzles[place]
		if place == EffectChip.MAX_PER_CELL - 1 and count > EffectChip.MAX_PER_CELL:
			text = EffectChip.MORE_TEXT % (count - place)
			fizzle = false
		if place == _chips.size():
			var chip: EffectChip = EffectChip.new(text, fizzle)
			_chips.append(chip)
			add_child(chip)
		elif _chips[place].label().text != text or _chips[place].is_fizzle() != fizzle:
			_chips[place].set_content(text, fizzle)
		_chips[place].position = _chip_position(place)


func _chip_position(place: int) -> Vector2:
	return _sticker.position + CHIP_OFFSET + Vector2(0, place * CHIP_PITCH)
