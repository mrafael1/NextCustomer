class_name DeckCell
extends Control
## One distinct card on the deck view's shelves (#56, deck view B, mock-up screens_deck_b.html):
## its tray item (ItemView, TRAY: the sprite over its price sticker, a BIG or GOLDEN copy's tier
## tag under the sticker) and its name under it. Its other copies stand stacked behind the first,
## dimmed, and a cream price-gun label slapped on the art counts them ("×3"). On the Cart page the
## cart reveal's pick marks (v0.51) sit on the art's top-left corner: the teal "+" of a starting
## pick's product (the tomato token for the coupon); the staple padlock shows only on the cart
## reveal (#105). In the stock a new arrival carries a mustard NEW chip there instead. The name is
## the plain product's (the art and the tier tag show the tier), stepped down to fit.
##
## Hover (the pointer on its sprite or sticker) lifts the art; `ringed` draws the chooser's gold
## ring round it. The mix highlight (#105 piece 3, mock-up readability v3's Cart) greys the whole
## cell for GREY and FAINT (`mix_look`; FAINT also draws a faint dashed outline round it,
## FAINT_RECT, and never a check: the Cart has no order). It only displays its card: DeckView owns
## the clicks, the hover, the highlight and the popup.

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
const PICK_MARK := "PickMark"
const NEW_MARK := "NewMark"
const COUNT_LABEL := "CountLabel"
const NAME_LABEL := "NameLabel"
## A faint match's dashed outline (mock-up readability v3: 112 wide from 2 px left of the cell).
const FAINT_RECT := Rect2(-2, 2, 112, 196)

var card: CardDefinition
## The chooser's gold ring round the item.
var ringed: bool = false:
	set(value):
		ringed = value
		queue_redraw()
## The mix highlight's look (#105 piece 3): GREY and FAINT grey every part (ArtStyle.set_mix_grey
## to `mix_greyness`), FAINT adds its dashed outline. Set the greyness first.
var mix_look: MixModel.Look = MixModel.Look.NONE:
	set(value):
		mix_look = value
		_show_mix()
## The calm grey's brightness (x) and saturation (y), PlanningTuning's.
var mix_greyness: Vector2 = Vector2.ONE
var _item: ItemView
var _name: Label
var _count: EffectSticker
var _marks: Array[RevealChip] = []
var _mix_mark: MixMark


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


## Adds the cart reveal's pick mark (v0.51): the "+" of a starting pick (the token of the
## starting coupon). A staple carries no mark here: its padlock is the cart reveal's (#105).
func add_origin_marks(picked: bool) -> void:
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


## The mix look on every part but the outline, and the outline (made at the first FAINT).
func _show_mix() -> void:
	var grey: float = 1.0 if MixModel.greys(mix_look) else 0.0
	for child: Node in get_children():
		if child != _mix_mark and child is CanvasItem:
			ArtStyle.set_mix_grey(child as CanvasItem, grey, mix_greyness)
	if _mix_mark == null and mix_look != MixModel.Look.FAINT:
		return
	if _mix_mark == null:
		_mix_mark = MixMark.new()
		add_child(_mix_mark)
	var faint: bool = mix_look == MixModel.Look.FAINT
	_mix_mark.show_look(
		MixModel.Look.FAINT if faint else MixModel.Look.NONE, FAINT_RECT.grow(MixMark.INSET)
	)


## The faint outline (this cell's coordinates), or null before the first one.
func mix_mark() -> MixMark:
	return _mix_mark


## Up to STACK_MAX dimmed copies of the item's art behind it, farthest first.
func _add_stack(copies: int) -> void:
	var behind: int = mini(copies - 1, STACK_MAX)
	for index: int in range(behind, 0, -1):
		var copy: TextureRect = UiKit.sprite(_item.sprite().texture)
		copy.size = ItemView.SPRITE_SIZE
		copy.position = ItemView.TRAY_SPRITE + STACK_STEP * index
		# Its own tint (self_modulate), so the mix highlight's grey (the modulate) adds to it.
		copy.self_modulate = STACK_TINT
		add_child(copy)


func _draw() -> void:
	if ringed:
		var ring: Rect2 = column_rect().grow(RING_OUTSET)
		draw_rect(ring.grow(RING_WIDTH / 2.0 + 1.0), Palette.INK, false, 2.0)
		draw_rect(ring, Palette.GOLD, false, RING_WIDTH)
