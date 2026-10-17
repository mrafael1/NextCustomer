class_name ItemView
extends CardView
## A card shown as an item on the counter (#75; style frame v2's spec sections 3 and 4): its
## sprite (a product's 48x48 art at 2x, or the shared coupon slip with the coupon's icon) over
## its price sticker. It keeps CardView's API (body, badge, center, highlight, tags), so the
## count-up plays it unchanged.
##
## Four forms. On the belt (a BELT_SIZE cell; mock-up B2, #80) the sprite stands on the belt's top
## face, the sticker is its ticket on the price rail, an EffectMark may sit on the art's visible
## top-right corner and, in the count-up, the paid chip (PayoutPlaque) pops above the art. In a
## hand basket (BASKET, a BASKET_SIZE cell; #80, step 8) the sprite alone, with no sticker (the
## monitor shows its price and rule), sinks a third of its art's visible height under the basket's
## front rim (BASKET_RIM_Y); a selected one gets a mustard outline round its art, a redraw-marked
## one dims and shows a small REDRAW flag above its art. In the offers' tray (a TRAY_SIZE cell) the
## sprite stands on a soft shadow over its sticker. A drag's ghost (GHOST, CardDrag) is the sprite
## alone, in a SPRITE_SIZE view with no sticker. A belt item stands on a contact shadow
## (BELT_SHADOW, on the cell's ground line; smaller and fainter while the sprite is lifted): its
## sprite drops by the art's transparent rows under its opaque foot (the coupon slip's 8), so every
## item's visible foot stands on that line (mock-up B2's `base`).
## `body` holds only the sprite, so the count-up's punches, shakes and lifts move the sprite while
## the sticker and mark stay still and readable; `center()` is the sprite's middle. The scan
## lifts the sprite and paid chip by LIFT (scan_lift; a basket item rises BASKET_LIFT out of its
## basket instead, mock-up B2); a hover or a selection lifts the mark too.
##
## An undrawn product shows the dashed art-pending box with its name printed in it, and a coupon
## without an icon the real slip with its name in the icon's place (#75, decision 3A). The view
## is built neutrally (CardView builds it before the form is known) and then laid out for its
## form. Every number comes from the card's data or the caller (the ScoreResult): the view never
## scores.

## The pointer entered or left the item: its sprite or sticker (hit_rect).
signal hovered(view: ItemView)
signal unhovered(view: ItemView)

enum Form { TRAY, BELT, GHOST, BASKET }

const BELT_SIZE := Vector2(116, 232)
const TRAY_SIZE := Vector2(108, 168)
## A basket item's cell (HandRow), from under the capacity line down past every sprite's foot. A
## short art's transparent top rows may stand above it; its hit area starts at the art.
const BASKET_SIZE := Vector2(96, 110)
const SPRITE_SIZE := Vector2(96, 96)
## On the belt the sprite stands with its foot on the top face (BELT_GROUND_Y is the foot's
## line), and the sticker hangs on the price rail.
const BELT_SPRITE := Vector2(10, 28)
const BELT_GROUND_Y := BELT_SPRITE.y + SPRITE_SIZE.y
const TRAY_SPRITE := Vector2(6, 4)
const BELT_STICKER := Vector2(4, 166)
const TRAY_STICKER := Vector2(0, 104)
## In a basket the art's visible foot sinks under the front rim (BASKET_RIM_Y, the cell's
## coordinates: HandBaskets.RIM_FRONT_Y on the stage) by 1/BASKET_SINK_PARTS of its visible height,
## on the 2 px grid, so about two thirds of it shows above the rim (mock-up B2). A coupon's slip
## rides BASKET_COUPON_RISE higher, leaning on its neighbour, so its icon clears the lip.
const BASKET_RIM_Y := 78.0
const BASKET_SINK_PARTS := 3.0
const BASKET_COUPON_RISE := 8.0
## How far a scan or a selection raises the sprite; a scan raises a basket item BASKET_LIFT out
## of its basket (mock-up B2: about 16 px; 14 keeps the tallest art, outlined, under the
## capacity line, ShiftStage.CAPACITY_RECT).
const LIFT := 4.0
const BASKET_LIFT := 14.0
## The paid chip (PayoutPlaque) over the art's visible top at rest (mock-up B2's count-up): the
## current one's face top PAID_CURRENT_ABOVE over it, an earlier one's PAID_SETTLED_ABOVE (its
## foot then clears the mark's top by 2 px; B2's 32 would sit on it), never above the MIN_Y lines,
## which keep a tall item's chip (lifted too) under the hung monitor and its shadow off the art; the
## pop's brief echo may reach the monitor's foot. The count-up's brackets hug the art's top
## (ScanOverlay.scan_frame), so a low item's chip and echo end over them; a tall item's, held by
## the MIN_Y line, share the top arms' rows (a narrow one's, kept off the mark, may cross the left
## arm: the monitor leaves no room above). A current chip whose rows reach the mark's top
## keeps MARK_GAP left of the mark's column (from three digits on a narrow item it may still reach
## the mark).
const PAID_CURRENT_ABOVE := 64.0
const PAID_SETTLED_ABOVE := 40.0
const PAID_CURRENT_MIN_Y := -6.0
const PAID_SETTLED_MIN_Y := -8.0
const MARK_GAP := 2.0
## A hovered or selected item's mark moves this far sideways (with the sprite's LIFT up), inside
## the scan brackets' corner (mock-up B2's hovered coupon).
const MARK_LIFTED_NUDGE := -6.0
## The tray's soft shadow under the sprite.
const TRAY_SHADOW := Rect2(14, 94, 80, 8)
const SHADOW_ALPHA := 0.25
const SHADOW_POINTS := 16
## A belt item's contact shadow (mock-up B2), from the sprite's left edge and the ground line: a
## stepped ellipse a little right of the sprite's middle (the light is top left), and the lifted
## sprite's, smaller and fainter. Drawn with ContactShadow.
const BELT_SHADOW := Rect2(18, -10, 74, 14)
const BELT_SHADOW_ALPHA := ContactShadow.ALPHA
const BELT_LIFTED_SHADOW := Rect2(28, -8, 52, 12)
const BELT_LIFTED_SHADOW_ALPHA := 0.25
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
## (sticker coordinates), clear of the base value (or COUPON) and the summary. In a basket the tag
## is a flag centred over the art, overlapping its top by REDRAW_FLAG_OVERLAP and never above
## REDRAW_FLAG_MIN_Y (the cell's coordinates), which keeps it in the cell, under the capacity
## line.
const REDRAW_ALPHA := 0.55
const REDRAW_RECT := Rect2(56, 6, 48, 22)
const REDRAW_FLAG_OVERLAP := 4.0
const REDRAW_FLAG_MIN_Y := 2.0
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
## The corner mark, or null (no step marks the item, or cleared).
var _mark: EffectMark
## A selected basket item's outline, behind its sprite, or null until one is first selected.
var _outline: TextureRect


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


## Lays the item out as a belt item, a basket item, a tray item or a drag's ghost: its size, the
## sprite's, sticker's, REDRAW tag's, paid chip's and mark's places.
func set_form(item_form: Form) -> void:
	form = item_form
	var belt: bool = form == Form.BELT
	var ghost: bool = form == Form.GHOST
	var basket: bool = form == Form.BASKET
	var sizes: Dictionary[Form, Vector2] = {
		Form.BELT: BELT_SIZE, Form.GHOST: SPRITE_SIZE, Form.BASKET: BASKET_SIZE
	}
	custom_minimum_size = sizes.get(form, TRAY_SIZE)
	size = custom_minimum_size
	var stand: Vector2 = Vector2.ZERO if ghost else TRAY_SPRITE
	if basket:
		stand = Vector2(0, _basket_stand_y())
	_stand.position = BELT_SPRITE + Vector2(0, _belt_drop()) if belt else stand
	_sticker.position = BELT_STICKER if belt else TRAY_STICKER
	_sticker.visible = not ghost and not basket
	_redraw_mark.position = _sticker.position + REDRAW_RECT.position
	# In a basket an undrawn item's name keeps to the box's top, above the rim.
	if _name_label != null:
		_name_label.vertical_alignment = (
			VERTICAL_ALIGNMENT_TOP if basket else VERTICAL_ALIGNMENT_CENTER
		)
	if basket:
		var flag_y: float = _art_top() - REDRAW_RECT.size.y + REDRAW_FLAG_OVERLAP
		_redraw_mark.position = Vector2(
			(SPRITE_SIZE.x - REDRAW_RECT.size.x) / 2.0, maxf(flag_y, REDRAW_FLAG_MIN_Y)
		)
	_place_badge(_plaque.is_current())
	_plaque.set_current(_plaque.is_current())
	_plaque.position.y = badge_rest_y()
	_place_mark()
	queue_redraw()


## SELECTED lifts the sprite by LIFT inside gold brackets (in a basket: with a mustard outline
## round its art instead); REDRAW fades the item to REDRAW_ALPHA and shows the REDRAW tag on its
## sticker (in a basket: the flag over its art).
func set_highlight(highlight: CardView.Highlight) -> void:
	_highlight = highlight
	_place_body()
	var alpha: float = REDRAW_ALPHA if highlight == CardView.Highlight.REDRAW else 1.0
	body.modulate = Color(1, 1, 1, alpha)
	_sticker.modulate.a = alpha
	_redraw_mark.visible = highlight == CardView.Highlight.REDRAW
	var outlined: bool = form == Form.BASKET and highlight == CardView.Highlight.SELECTED
	if outlined and _outline == null:
		_outline = UiKit.sprite(ArtOutline.texture_for(_sprite.texture))
		_outline.name = "Outline"
		_outline.show_behind_parent = true
		_outline.position = -Vector2.ONE * ArtStyle.ART_SCALE
		_outline.size = SPRITE_SIZE + Vector2.ONE * 2.0 * ArtStyle.ART_SCALE
		_sprite.add_child(_outline)
	if _outline != null:
		_outline.visible = outlined
	queue_redraw()


## Shows the paid chip, "€N" (muted at €0). `strong` (the count-up's running value) looks the
## same: the count-up punches the chip instead, and set_badge_current picks its face.
func show_badge(value: int, _strong: bool) -> void:
	_plaque.show_value(value, value == 0)


## A value wiped by a denied beat: the muted face.
func show_fizzle_badge(value: int) -> void:
	_plaque.show_value(value, true)


## Gives the paid chip the current item's face (big mustard; `with_echo`: its next pop shows the
## echo frame) or an earlier item's (small paper), at that face's rest place.
func set_badge_current(current: bool, with_echo: bool = false) -> void:
	_place_badge(current)
	_plaque.set_current(current, with_echo)
	_plaque.position.y = badge_rest_y()


## The paid chip's rest y for its face: over the art's visible top, under the MIN_Y lines.
func badge_rest_y() -> float:
	if _plaque.is_current():
		return maxf(_art_top() - PAID_CURRENT_ABOVE, PAID_CURRENT_MIN_Y)
	return maxf(_art_top() - PAID_SETTLED_ABOVE, PAID_SETTLED_MIN_Y)


func scan_lift() -> float:
	return -BASKET_LIFT if form == Form.BASKET else -LIFT


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


## Shows the corner mark, a fizzle disc or a check (one per item: a shown mark changes kind in
## place). Returns it.
func show_mark(fizzle: bool) -> EffectMark:
	if _mark == null:
		_mark = EffectMark.new(fizzle)
		add_child(_mark)
		move_child(_mark, _plaque.get_index())
		_place_mark()
	_mark.set_fizzle(fizzle)
	return _mark


func clear_mark() -> void:
	if _mark != null:
		_mark.free()
		_mark = null


## The selected item's gold brackets (this view's coordinates), or an empty rect (and always in a
## basket, which outlines a selected item instead).
func brackets() -> Rect2:
	if _highlight != CardView.Highlight.SELECTED or form == Form.BASKET:
		return Rect2()
	return Rect2(_stand.position + body.position, SPRITE_SIZE).grow(ScanOverlay.BRACKET_OUTSET)


## Where the pointer hovers and clicks the item (this view's coordinates): the sprite (lifted or
## not) and the sticker. A basket item has no sticker, and its area starts at its art's visible
## top (raised as high as it is now), not at the sprite's transparent rows. The mark and the
## paid chip are decor.
func hit_rect() -> Rect2:
	var rect: Rect2 = Rect2(_stand.position - Vector2(0, LIFT), SPRITE_SIZE + Vector2(0, LIFT))
	if form == Form.BASKET:
		var top: float = _art_top() - maxf(LIFT, _lift_height())
		return Rect2(rect.position.x, top, rect.size.x, rect.end.y - top)
	return rect.merge(Rect2(_sticker.position, PriceSticker.SIZE))


## What a flipped scan popup opens below (global): the sticker.
func below_rect() -> Rect2:
	return get_global_transform() * Rect2(_sticker.position, PriceSticker.SIZE)


func _has_point(point: Vector2) -> bool:
	return hit_rect().has_point(point)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hovered.emit(self)
	elif what == NOTIFICATION_MOUSE_EXIT:
		unhovered.emit(self)


## How far a belt sprite drops so its art's opaque foot stands on BELT_GROUND_Y: the art's
## transparent rows under it, in view pixels (0 for art that reaches its canvas's bottom).
func _belt_drop() -> float:
	var texture: Texture2D = _sprite.texture
	var empty_rows: int = texture.get_height() - ContactShadow.opaque_bottom(texture)
	return empty_rows * SPRITE_SIZE.y / texture.get_height()


## Where a basket item's sprite stands in its cell: its art's visible foot 1/BASKET_SINK_PARTS of
## the art's visible height under BASKET_RIM_Y (on the 2 px grid), a coupon's slip
## BASKET_COUPON_RISE higher.
func _basket_stand_y() -> float:
	var texture: Texture2D = _sprite.texture
	var box: Rect2i = ContactShadow.opaque_rect(texture)
	var texel: float = SPRITE_SIZE.y / texture.get_height()
	var sink: float = box.size.y * texel / BASKET_SINK_PARTS
	var foot: float = BASKET_RIM_Y + snappedf(sink, ArtStyle.ART_SCALE)
	var rise: float = BASKET_COUPON_RISE if card.definition.is_coupon() else 0.0
	return foot - box.end.y * texel - rise


## A belt item's contact shadow (this view's coordinates; empty in another form): on the ground
## line under the sprite, the lifted one while the sprite is lifted.
func _belt_shadow() -> Rect2:
	if form != Form.BELT:
		return Rect2()
	var shape: Rect2 = BELT_LIFTED_SHADOW if _is_up() else BELT_SHADOW
	return Rect2(Vector2(BELT_SPRITE.x, BELT_GROUND_Y) + shape.position, shape.size)


## The tray's soft shadow or a belt item's contact shadow under the sprite, and a selected item's
## gold brackets.
func _draw() -> void:
	if form == Form.BELT:
		var alpha: float = BELT_LIFTED_SHADOW_ALPHA if _is_up() else BELT_SHADOW_ALPHA
		ContactShadow.draw_on(self, _belt_shadow(), alpha)
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


## Lifts the sprite by _lift_height() while it is selected or scanned, else rests it (its shadow
## and mark follow).
func _place_body() -> void:
	body.position.y = -_lift_height() if _is_up() else 0.0
	_place_mark()
	queue_redraw()


## The art's visible top at rest, in this view's coordinates (ContactShadow.opaque_rect).
func _art_top() -> float:
	var texture: Texture2D = _sprite.texture
	var box: Rect2i = ContactShadow.opaque_rect(texture)
	return _stand.position.y + box.position.y * SPRITE_SIZE.y / texture.get_height()


## The mark's place at rest (this view's coordinates): on the art's visible top-right corner.
func _mark_rest() -> Vector2:
	return EffectMark.corner(_sprite.texture, Rect2(_stand.position, SPRITE_SIZE))


## Puts the mark on its corner, nudged and lifted with a hovered or selected sprite.
func _place_mark() -> void:
	if _mark == null:
		return
	var lift: Vector2 = Vector2(MARK_LIFTED_NUDGE, -_lift_height()) if _is_up() else Vector2.ZERO
	_mark.position = _mark_rest() + lift


## The paid chip's horizontal limits for the `current` face: centred on the sprite, inside the
## cell, and a current chip whose lifted rows reach the mark's top kept MARK_GAP left of the
## mark's column.
func _place_badge(current: bool) -> void:
	_plaque.centre_x = _stand.position.x + SPRITE_SIZE.x / 2.0
	_plaque.left_limit = 0.0
	_plaque.right_limit = size.x
	if current:
		var top: float = maxf(_art_top() - PAID_CURRENT_ABOVE, PAID_CURRENT_MIN_Y) - LIFT
		var foot: float = top + PayoutPlaque.CURRENT_HEIGHT + PayoutPlaque.CURRENT_SHADOW
		var corner: Vector2 = _mark_rest()
		if foot + MARK_GAP > corner.y:
			_plaque.right_limit = minf(size.x, corner.x - MARK_GAP)


## Whether the sprite is lifted: scanned or selected.
func _is_up() -> bool:
	return lifted or _highlight == CardView.Highlight.SELECTED


## How far the sprite rises when it is up: a scanned basket item BASKET_LIFT, else LIFT.
func _lift_height() -> float:
	return BASKET_LIFT if form == Form.BASKET and lifted else LIFT


## Snaps the sprite and the REDRAW tag back to their sizes: built outside the tree, a Label
## measures its text in the default font, and a Control never shrinks back by itself.
func _fit_body() -> void:
	body.size = SPRITE_SIZE
	_redraw_mark.size = REDRAW_RECT.size


## The form-neutral parts: the sprite in `body` on its stand, the REDRAW tag and the paid chip.
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
	# Teal panel and ink, not tomato: tomato is the fizzle's, CHECKOUT's and CLOSED's (B2).
	var tag_face: StyleBoxFlat = StyleBoxFlat.new()
	tag_face.bg_color = Palette.PANEL
	tag_face.border_color = Palette.INK
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
