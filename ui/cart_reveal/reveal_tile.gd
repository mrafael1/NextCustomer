class_name RevealTile
extends Control
## One card in the cart reveal's cart (mock-up cart_reveal_v1.html, v0.51): a 100x120 tile with
## the item's art (ItemView.item_art) and its name under it. A STAPLE is cream with a mustard
## padlock at its corner (known, never a surprise); a PICK is paper with a teal frame and a teal
## "+"; the COUPON is paper with a tomato scissors-line border, a COUPON tab and a tomato coupon
## token. A pick that is a staple's 2nd copy carries a mustard padlock "×2". The tile pops and
## flashes white as it lands (set_landing).

enum Kind { STAPLE, PICK, COUPON }

const SIZE := Vector2(100, 120)
const SPRITE_POSITION := Vector2(2, 0)
const NAME_TOP := 98.0
const NAME_HEIGHT := 18.0
const NAME_SIZE := 12
## The corner badges, in tile coordinates.
const LOCK_RECT := Rect2(-8, -8, 28, 28)
const SPARK_RECT := Rect2(80, -8, 26, 26)
const DUP_POSITION := Vector2(4, 4)
const DUP_HEIGHT := 24.0
const TAB_RECT := Rect2(22, -18, 56, 18)
## The coupon's scissors-line border, inset from the tile's sides (left, top, right, bottom).
const CUT_INSET := Vector4(4, 4, 4, 8)
const DASH := 6.0
const LOCK_ICON := preload("res://art/icons/padlock.png")
const PICK_ICON := preload("res://art/effects/sparkle.png")
const COUPON_ICON := preload("res://art/effects/badge_coupon.png")
## The coupon's paper bottom band: tomato light over paper.
const COUPON_BAND := Color(Palette.TOMATO_LIGHT, 0.5)

var kind: Kind = Kind.PICK
var card: CardDefinition
## The staples' padlock (STAPLE), the "+" or coupon token (PICK, COUPON), the 2nd copy's "×2".
var lock_badge: RevealChip
var spark_badge: RevealChip
var dup_badge: RevealChip
var tab: RevealChip
var _art: TextureRect
var _name: Label
## The landing's white flash, over the art and the badges.
var _veil: Control
var _flash: float = 0.0


## A tile of `tile_kind` for `definition`; `second_copy`: a pick that is a staple's 2nd copy.
func _init(definition: CardDefinition, tile_kind: Kind, second_copy: bool = false) -> void:
	card = definition
	kind = tile_kind
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	pivot_offset = Vector2(SIZE.x / 2.0, SIZE.y * 0.7)
	_art = ItemView.item_art(definition)
	_art.position = SPRITE_POSITION
	add_child(_art)
	# A coupon whose name is printed on its slip doesn't repeat it under it.
	if not definition.is_coupon() or ArtStyle.coupon_icon(definition) != null:
		_name = UiKit.body_label(definition.display_name, NAME_SIZE, Palette.INK)
		_name.add_theme_font_override("font", ArtStyle.bold_font(700))
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.clip_text = true
		_name.position = Vector2(0, NAME_TOP)
		_name.size = Vector2(SIZE.x, NAME_HEIGHT)
		add_child(_name)
	match kind:
		Kind.STAPLE:
			lock_badge = _badge(Palette.MUSTARD, LOCK_RECT, LOCK_ICON)
		Kind.PICK:
			spark_badge = _badge(Palette.TEAL_BRIGHT, SPARK_RECT, PICK_ICON)
		Kind.COUPON:
			spark_badge = _badge(Palette.TOMATO, SPARK_RECT, COUPON_ICON)
			tab = RevealChip.new(Palette.TOMATO, TAB_RECT.size, null, "COUPON", 11, Palette.PAPER)
			tab.position = TAB_RECT.position
			add_child(tab)
	if second_copy:
		dup_badge = RevealChip.new(
			Palette.MUSTARD, Vector2(0, DUP_HEIGHT), LOCK_ICON, "×2", 13, Palette.INK
		)
		dup_badge.position = DUP_POSITION
		add_child(dup_badge)
	_veil = Control.new()
	_veil.name = "Flash"
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.size = SIZE
	_veil.draw.connect(_draw_flash)
	add_child(_veil)


## The name label under the art (for tests), or null for a coupon whose slip prints it.
func name_label() -> Label:
	return _name


## The landing's pop and flash: `pop` scales the tile about its lower middle, `flash` (0 to 1)
## whitens it (paper white over everything).
func set_landing(pop: float, flash: float) -> void:
	scale = Vector2.ONE * (1.0 + pop)
	if not is_equal_approx(flash, _flash):
		_flash = flash
		_veil.queue_redraw()


## The flash's strength now (for tests).
func flash_strength() -> float:
	return _flash


func _draw_flash() -> void:
	if _flash > 0.0:
		_veil.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(Palette.PAPER, _flash))


func _badge(color: Color, rect: Rect2, icon: Texture2D) -> RevealChip:
	var badge: RevealChip = RevealChip.new(color, rect.size, icon)
	badge.position = rect.position
	add_child(badge)
	return badge


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	draw_rect(rect.grow(2), Palette.INK)
	match kind:
		Kind.STAPLE:
			draw_rect(rect, Palette.CREAM)
			draw_rect(Rect2(0, SIZE.y - 4, SIZE.x, 4), Palette.CREAM_SHADE)
		Kind.PICK:
			draw_rect(rect, Palette.PAPER)
			draw_rect(Rect2(0, SIZE.y - 6, SIZE.x, 6), Palette.TEAL_PALE)
			draw_rect(rect.grow(-1), Palette.TEAL_BRIGHT, false, 2.0)
		Kind.COUPON:
			draw_rect(rect, Palette.PAPER)
			draw_rect(Rect2(0, SIZE.y - 6, SIZE.x, 6), COUPON_BAND)
			var cut: Rect2 = Rect2(
				CUT_INSET.x,
				CUT_INSET.y,
				SIZE.x - CUT_INSET.x - CUT_INSET.z,
				SIZE.y - CUT_INSET.y - CUT_INSET.w
			)
			RevealSlot.dashed_rect(self, cut, Palette.TOMATO, DASH)
