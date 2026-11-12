class_name FamilyRibbon
extends PixelDropdown
## The FIGURINE BOOK's FAMILY pick as a ribbon bookmark (v1.30 round 8, the user: "instead of a
## classic button for family, maybe it can be a bookmark"; one ribbon): a cloth ribbon
## (icons/book_ribbon) hanging over the binder's top edge, in the picked family's colours (its
## FamilyStyle's light, face and shade; ALL's neutral cream), its glyph on the ribbon (ALL: the
## ALL mark, icons/book_all_mark) and the NEW dot on its top corner when any option has one. The
## mouse over it lifts it LIFT px (it stays lifted while its list is open). A click unrolls the
## list downward from behind the ribbon's tail: a paper strip (frames/book_strip, its rolled top
## under the tail, its foot cut in the ribbon's notched tail, frames/book_strip_tail) with an
## option a row (frames/book_strip_row, marked frames/book_strip_row_lit with the price-gun
## tick), its glyph and name in ink, the picked one on a swatch of its family's ribbon cloth
## (frames/book_strip_swatch, recoloured like the ribbon; paper words on a family that prints
## them). The strip unrolls over UNROLL_SECONDS, at once when `still` (reduced motion).
## Round 9 (the user: "perfect, maybe it can be a tad bigger to stands out a bit more but
## execution is perfect"): the ribbon, its glyph or ALL mark and its NEW dot are drawn a size
## larger, SCALE (3x) instead of the book's 2x; the art and its look are unchanged.
##
## Everything else is PixelDropdown's: the options, the picking, the marking, the keys (Up and
## Down step, Enter or Space picks, Esc closes), the catcher, pass_through and the signals.

## The ribbon, the ALL mark, the strip's pieces and its rows' frames (9-slices, STRIP_MARGIN art
## px margins).
const RIBBON := preload("res://art/icons/book_ribbon.png")
const ALL_MARK := preload("res://art/icons/book_all_mark.png")
const STRIP := preload("res://art/frames/book_strip.png")
const STRIP_TAIL := preload("res://art/frames/book_strip_tail.png")
const SWATCH := preload("res://art/frames/book_strip_swatch.png")
const ROW_FRAMES: Array[Texture2D] = [
	preload("res://art/frames/book_strip_row.png"),
	preload("res://art/frames/book_strip_row_lit.png"),
]
const STRIP_MARGIN := 3
## The ribbon's own scale (canvas px an art px; round 9): one size over ArtStyle.ART_SCALE, so it
## stands out; its glyph, ALL mark and NEW dot share it.
const SCALE := 3.0
## On the ribbon (art px from its top left): a family's 9x9 glyph, the ALL mark, the NEW dot.
const GLYPH_AT := Vector2i(3, 8)
const ALL_AT := Vector2i(2, 10)
const DOT_AT := Vector2i(11, 4)
## The hover lift (canvas px): one ribbon art px.
const LIFT := SCALE
## The strip (canvas px): its top TUCK above the ribbon's foot (behind its tail: 8 ribbon art
## px, the 5 px notch and 3 more), its first row
## ROWS_BELOW under the foot, the rows ROW_HEIGHT tall and ROW_GAP apart, ROW_SIDE inside its
## sides (room for the tick and the lit shift), their words ROW_PADDING clear of their ends;
## BOTTOM_PADDING of paper under the last row, then the tail, TAIL_HEIGHT tall in teeth TOOTH
## wide (the strip is a whole number of teeth wide); STAGE_MARGIN clear of the area's sides.
const TUCK := 8.0 * SCALE
const ROWS_BELOW := 6.0
const ROW_HEIGHT := 36.0
const ROW_GAP := 4.0
const ROW_SIDE := 20.0
const ROW_PADDING := 16.0
const BOTTOM_PADDING := 6.0
const TAIL_HEIGHT := 6.0
const TOOTH := 12.0
const STAGE_MARGIN := 8.0
const UNROLL_SECONDS := 0.16

## Reduced motion: the strip shows at once.
var still: bool = false

var _styles: Array[FamilyStyle] = []
## The recoloured ribbons and swatches made so far (tinted), by texture and colours. Kept on the
## ribbon, not in a static var: a static one kept the scripts it reaches alive at exit.
var _tinted: Dictionary[String, Texture2D] = {}
var _cloth: Control
var _cloth_art: TextureRect
var _emblem: TextureRect
var _hovered: bool = false
var _roll: Control
var _unroll: Tween


## A ribbon with its top left at `at` (canvas px) in a control covering `area`.
func _init(at: Vector2, area: Vector2) -> void:
	super("", Rect2(at, Vector2(RIBBON.get_size()) * SCALE), true, area)
	move_child(_plate, -1)  # Over the strip: its tail lies on the strip's rolled top.


## Each option's family look, in the options' order (null: ALL's neutral cream); set before
## set_options.
func set_styles(styles: Array[FamilyStyle]) -> void:
	_styles = styles.duplicate()


## The pieces, for tests and the screen capture: the ribbon's cloth (its art), the glyph or ALL
## mark on it, the strip's clipping roll, and whether it is lifted.
func cloth() -> TextureRect:
	return _cloth_art


func emblem() -> TextureRect:
	return _emblem


func roll() -> Control:
	return _roll


func is_lifted() -> bool:
	return _cloth.position.y < 0.0


## `texture` (drawn in the cream ramp) in `style`'s ribbon colours: paper to its light, cream to
## its face, cream shade to its shade; unchanged for ALL (null) or a style with no colours.
func tinted(texture: Texture2D, style: FamilyStyle) -> Texture2D:
	if style == null or not style.has_ticket_colours():
		return texture
	var key: String = (
		"%s|%s|%s|%s"
		% [
			texture.resource_path,
			style.light.to_html(),
			style.face.to_html(),
			style.shade.to_html()
		]
	)
	if _tinted.has(key):
		return _tinted[key]
	var swaps: Dictionary[String, Color] = {
		Palette.PAPER.to_html(false): _exact(style.light),
		Palette.CREAM.to_html(false): _exact(style.face),
		Palette.CREAM_SHADE.to_html(false): _exact(style.shade),
	}
	var image: Image = texture.get_image().duplicate() as Image
	if image.is_compressed():
		image.decompress()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var colour: Color = image.get_pixel(x, y)
			var html: String = colour.to_html(false)
			if colour.a > 0.0 and swaps.has(html):
				image.set_pixel(x, y, swaps[html])
	var made: ImageTexture = ImageTexture.create_from_image(image)
	_tinted[key] = made
	return made


## `colour` nudged a quarter step up each channel, so an 8-bit image (which truncates) stores its
## exact palette byte.
static func _exact(colour: Color) -> Color:
	var nudge: float = 0.25 / 255.0
	return Color(
		roundf(colour.r * 255.0) / 255.0 + nudge,
		roundf(colour.g * 255.0) / 255.0 + nudge,
		roundf(colour.b * 255.0) / 255.0 + nudge,
		1.0
	)


func _build_plate(rect: Rect2) -> BaseButton:
	var button: TextureButton = TextureButton.new()
	button.ignore_texture_size = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.position = rect.position
	button.size = rect.size
	_cloth = Control.new()
	_cloth.name = "Cloth"
	_cloth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cloth.size = rect.size
	button.add_child(_cloth)
	_cloth_art = UiKit.sprite(RIBBON)
	_cloth_art.name = "Ribbon"
	_cloth_art.size = rect.size
	_cloth.add_child(_cloth_art)
	_emblem = UiKit.sprite(ALL_MARK)
	_emblem.name = "Emblem"
	_cloth.add_child(_emblem)
	button.mouse_entered.connect(_hover.bind(true))
	button.mouse_exited.connect(_hover.bind(false))
	return button


func _layout_list(count: int) -> void:
	var art: float = ArtStyle.ART_SCALE
	var widest: float = 0.0
	for index: int in count:
		var line: PixelLine = PixelLine.new()
		line.show_tokens(_tokens(index, false), Palette.INK, Palette.INK)
		widest = maxf(widest, line.width() + (DOT_GAP + DOT) * art)
		line.free()
	var width: float = widest + ROW_PADDING * 2.0 + ROW_SIDE * 2.0 + MenuPlate.HOT_SHIFT
	width = TOOTH * ceilf(width / TOOTH)
	var height: float = (
		TUCK
		+ ROWS_BELOW
		+ count * ROW_HEIGHT
		+ maxi(count - 1, 0) * ROW_GAP
		+ BOTTOM_PADDING
		+ TAIL_HEIGHT
	)
	var left: float = _plate_rect.get_center().x - width / 2.0
	left = clampf(left, STAGE_MARGIN, size.x - STAGE_MARGIN - width)
	_list.position = Vector2(art * roundf(left / art), _plate_rect.end.y - TUCK)
	_list.size = Vector2(width, height)
	_roll = Control.new()
	_roll.name = "Roll"
	_roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll.clip_contents = true
	_roll.size = _list.size
	_list.add_child(_roll)
	var body: PanelContainer = UiKit.frame_panel(STRIP, STRIP_MARGIN)
	body.name = "Strip"
	body.size = Vector2(width, height - TAIL_HEIGHT)
	_roll.add_child(body)
	var tail: TextureRect = UiKit.tiled(STRIP_TAIL)
	tail.name = "Tail"
	tail.position = Vector2(0.0, height - TAIL_HEIGHT)
	tail.size = Vector2(width, TAIL_HEIGHT)
	_roll.add_child(tail)


func _option_rect(index: int) -> Rect2:
	var top: float = TUCK + ROWS_BELOW + index * (ROW_HEIGHT + ROW_GAP)
	var width: float = _list.size.x - ROW_SIDE * 2.0 - MenuPlate.HOT_SHIFT
	return Rect2(ROW_SIDE, top, width, ROW_HEIGHT)


func _options_parent() -> Control:
	return _roll


func _dress_option(index: int, is_picked: bool) -> void:
	var option: MenuPlate = _options[index]
	var style: FamilyStyle = _style(index)
	if is_picked:
		var swatch: Texture2D = tinted(SWATCH, style)
		var frames: Array[Texture2D] = [swatch, swatch]
		option.use_frames(frames)
	else:
		option.use_frames(ROW_FRAMES)
	var paper: bool = (
		is_picked and style != null and style.has_ticket_colours() and style.paper_text
	)
	_put_words(option, _tokens(index, false), _dots[index], Palette.PAPER if paper else Palette.INK)


func _show_on_plate(index: int) -> void:
	var art: float = SCALE
	_cloth_art.texture = tinted(RIBBON, _style(index))
	var icon: Texture2D = _icons[index] if index < _icons.size() else null
	_emblem.texture = icon if icon != null else ALL_MARK
	_emblem.size = Vector2(_emblem.texture.get_size()) * art
	_emblem.position = Vector2(GLYPH_AT if icon != null else ALL_AT) * art
	var old: Node = _cloth.get_node_or_null("Dot")
	if old != null:
		_cloth.remove_child(old)
		old.free()
	if _dots.has(true):
		var pip: ColorRect = make_dot(art)
		pip.position = Vector2(DOT_AT) * art
		_cloth.add_child(pip)
	_plate.accessibility_description = "FAMILY: " + _captions[index]


func _open_changed(open: bool) -> void:
	_show_lift()
	if _unroll != null:
		_unroll.kill()
		_unroll = null
	if _roll == null:
		return
	_roll.size.y = _list.size.y
	if not open or still or not is_inside_tree():
		return
	_roll.size.y = TUCK
	_unroll = create_tween()
	(
		_unroll
		. tween_property(_roll, "size:y", _list.size.y, UNROLL_SECONDS)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)


func _style(index: int) -> FamilyStyle:
	return _styles[index] if index < _styles.size() else null


func _hover(on: bool) -> void:
	_hovered = on
	_show_lift()


## Lifted under the mouse and while the list is open.
func _show_lift() -> void:
	_cloth.position.y = -LIFT if _hovered or is_open() else 0.0
