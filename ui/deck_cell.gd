class_name DeckCell
extends Control
## One distinct card on the deck view's shelves (#56, deck view B, mock-up screens_deck_b.html):
## its tray item (ItemView, TRAY: the sprite over its price sticker, a BIG or GOLDEN copy's tier
## tag under the sticker) and its name under it. Its other copies stand stacked behind the first,
## dimmed, and a cream price-gun label slapped on the art counts them ("×3"). On the Cart page the
## cart reveal's marks (v0.51) sit on the art's top-left corner: the mustard padlock of a staple's
## product, the teal "+" of a starting pick's (the tomato token for the coupon). In the stock a new
## arrival carries a mustard NEW chip there instead. The name is the plain product's (the art and
## the tier tag show the tier), stepped down to fit.
##
## Hover (the pointer on its sprite or sticker) lifts the art; `ringed` draws the chooser's gold
## ring round it. It only displays its card: DeckView owns the clicks, the hover and the popup.

const SIZE := Vector2(108, 200)
## The name's line under the sticker and the tier tag (PriceSticker.TIER_TAG_RECT reaches y 182).
const NAME_TOP := 184.0
const NAME_HEIGHT := 16.0
const NAME_SIZES: Array[int] = [14, 13, 12, 11]
const NAME_WEIGHT := 700
## The name may use this much of the gap beside the cell.
const NAME_SPILL := 8.0
## Stacked copies behind the first: at most STACK_MAX, each STACK_STEP up and right of the one in
## front, dimmed to STACK_TINT.
const STACK_MAX := 2
const STACK_STEP := Vector2(8, -6)
const STACK_TINT := Color(0.55, 0.62, 0.62)
## The count label: a cream price-gun label (EffectSticker's ADD) on the art's top right.
const COUNT_POSITION := Vector2(64, 0)
const COUNT_TILT := 6.0
## The marks on the art's top left (RevealChip, the cart reveal's look).
const MARK_SIZE := Vector2(24, 24)
const MARK_POSITION := Vector2(2, 2)
const MARK_GAP := 6.0
const NEW_TEXT := "NEW"
## The chooser's ring round the item's column (sprite and sticker), outside it by RING_OUTSET.
const RING_WIDTH := 4.0
const RING_OUTSET := 4.0
## Node names (for tests).
const STAPLE_MARK := "StapleMark"
const PICK_MARK := "PickMark"
const NEW_MARK := "NewMark"
const COUNT_LABEL := "CountLabel"
const NAME_LABEL := "NameLabel"

var card: CardDefinition
## The chooser's gold ring round the item.
var ringed: bool = false:
	set(value):
		ringed = value
		queue_redraw()
var _item: ItemView
var _name: Label
var _count: EffectSticker
var _marks: Array[RevealChip] = []


## The cell of `instance` (its group's first copy) in `aisle`, with `copies` copies of it.
func _init(instance: CardInstance, aisle: AisleDefinition, copies: int) -> void:
	card = instance.definition
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE
	_item = ItemView.new(instance, aisle, ItemView.Form.TRAY)
	_add_stack(copies)
	add_child(_item)
	var shown: CardDefinition = card.product_card() if card.is_product() else card
	_name = UiKit.body_label(shown.display_name, NAME_SIZES[0], Palette.PAPER)
	_name.name = NAME_LABEL
	_name.add_theme_font_override("font", ArtStyle.bold_font(NAME_WEIGHT))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.clip_text = true
	_name.position = Vector2(-NAME_SPILL / 2.0, NAME_TOP)
	_name.size = Vector2(SIZE.x + NAME_SPILL, NAME_HEIGHT)
	_name.add_theme_font_size_override("font_size", name_size(_name.text))
	add_child(_name)
	if copies > 1:
		var spec: StickerSpec = StickerSpec.new()
		spec.text = "×%d" % copies
		_count = EffectSticker.new(spec, COUNT_TILT)
		_count.name = COUNT_LABEL
		_count.position = COUNT_POSITION
		add_child(_count)


## The largest NAME_SIZES size at which `text` fits the name's line (else the smallest), measured
## with the bold body font itself (a new cell's label is not in the tree yet).
static func name_size(text: String) -> int:
	var font: Font = ArtStyle.bold_font(NAME_WEIGHT)
	for font_size: int in NAME_SIZES:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= SIZE.x:
			return font_size
	return NAME_SIZES[-1]


## Adds the cart reveal's marks (v0.51): the padlock of a staple, then the "+" of a starting pick
## (the token of the starting coupon).
func add_origin_marks(staple: bool, picked: bool) -> void:
	if staple:
		_add_mark(STAPLE_MARK, RevealChip.new(Palette.MUSTARD, MARK_SIZE, RevealTile.LOCK_ICON))
	if picked:
		var coupon: bool = card.is_coupon()
		var chip: RevealChip = RevealChip.new(
			Palette.TOMATO if coupon else Palette.TEAL_BRIGHT,
			MARK_SIZE,
			RevealTile.COUPON_ICON if coupon else RevealTile.PICK_ICON
		)
		_add_mark(PICK_MARK, chip)


## Adds the stock's NEW chip (a new arrival).
func add_new_mark() -> void:
	var chip: RevealChip = RevealChip.new(Palette.MUSTARD, MARK_SIZE, null, NEW_TEXT, 12)
	_add_mark(NEW_MARK, chip)


func item() -> ItemView:
	return _item


func name_label() -> Label:
	return _name


## The copies' count ("×3"), or "" for one copy.
func count_text() -> String:
	return _count.text() if _count != null else ""


## The marks on the art's corner, left to right.
func marks() -> Array[RevealChip]:
	return _marks


## The item's column (its sprite and sticker), in this cell's coordinates.
func column_rect() -> Rect2:
	return Rect2(Vector2.ZERO, ItemView.TRAY_SIZE)


func _add_mark(mark_name: String, chip: RevealChip) -> void:
	chip.name = mark_name
	var x: float = MARK_POSITION.x
	if not _marks.is_empty():
		var last: RevealChip = _marks[-1]
		x = last.position.x + last.size.x + MARK_GAP
	chip.position = Vector2(x, MARK_POSITION.y)
	_marks.append(chip)
	add_child(chip)


## Up to STACK_MAX dimmed copies of the item's art behind it, farthest first.
func _add_stack(copies: int) -> void:
	var behind: int = mini(copies - 1, STACK_MAX)
	for index: int in range(behind, 0, -1):
		var copy: TextureRect = UiKit.sprite(_item.sprite().texture)
		copy.size = ItemView.SPRITE_SIZE
		copy.position = ItemView.TRAY_SPRITE + STACK_STEP * index
		copy.modulate = STACK_TINT
		add_child(copy)


func _draw() -> void:
	if ringed:
		var ring: Rect2 = column_rect().grow(RING_OUTSET)
		draw_rect(ring.grow(RING_WIDTH / 2.0 + 1.0), Palette.INK, false, 2.0)
		draw_rect(ring, Palette.GOLD, false, RING_WIDTH)
