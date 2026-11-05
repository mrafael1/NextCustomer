class_name PrizeArt
extends Control
## The art box on a prize ticket (v0.50, mock-up premium_machine_v1.html; M5; 132x100 on V3's
## 144x244 ticket in v0.96, mock-up machine_relook_v3.html): the real sprites, never a stand-in.
## - a product: its item sprite (plain, BIG or GOLDEN as drawn), a BIG or GOLDEN one (NEW ITEMS
##   since v0.61: an item can arrive upgraded) with its tier chip; a coupon: the coupon slip with
##   its icon, or its name printed on it (ItemView.item_art, as the game shows items everywhere);
## - an item upgrade (the UPGRADE chute): the item at its new tier with a BIG / GOLDEN chip; the
##   SHELF upgrade (LEGENDARY) shows the plain item on a gold shelf plank with "SHELF +1" (its chip
##   in the art's bottom right corner), since the GOLDEN palette on it would read as a different
##   product;
## - a LOYALTY prize (the UPGRADE chute's perks): a punch card matching the top bar's loyalty card
##   (cream, a teal band, three stamp slots), centred, its first slot stamped with the perk's icon
##   (UpgradeDefinition.icon_ref; Big basket's "+1 slot" ticket) or, with none, its initials. A
##   level-up (#108, LV 2 or LV 3) stamps as many slots as its level and shows an "LV n" chip in
##   the art's bottom right corner (chip_rect): the ticket's band carries only the perk's name.
## On a LEGENDARY card (v0.97, CardFoil) the art breaks out of its window over the gold plate
## (break_out): a sprite whose top stays under BREAKOUT canvas px (6 art px, the mock-up's) above
## the window climbs up to CLIMB_MAX on landing (climb: 0.15-0.45 s, a back ease; at once under
## reduced motion), and
## what pokes over the window wears a 1 art px ink outline (a GOLDEN sprite all round, so a gold
## item keeps apart from the gold card).

const SIZE := Vector2(132, 100)
## The item's sprite (ItemView.SPRITE_SIZE) and where it sits.
const SPRITE_AT := Vector2(18, 2)
const SHELF_LIFT := 6.0
## A tier chip's top left (bottom left of the art); a level-up's and the SHELF's chip: its right
## edge and its top (bottom right of the art).
const CHIP_AT := Vector2(6, 80)
const LEVEL_CHIP_RIGHT := 128.0
const LEVEL_CHIP_TOP := 80.0
const CHIP_HEIGHT := 18.0
const CHIP_SIZE := 12
const CHIP_PAD := 6.0
## The loyalty punch card, centred, its teal band and its three stamp slots (SLOT_STEP apart).
const PUNCH_RECT := Rect2(22, 24, 88, 52)
const PUNCH_BAND := 10.0
const SLOT_AT := Vector2(6, 18)
const SLOT_STEP := 26.0
const BOLD_WEIGHT := 800
const INITIALS_SIZE := 9
const STAMP_RING := preload("res://art/icons/stamp_ring.png")
const STAMP_EMPTY := preload("res://art/icons/stamp_ring_empty.png")
## The breakout: the sprite's top climbs to BREAKOUT canvas px over the window, CLIMB_MAX at most,
## between CLIMB_FROM and CLIMB_TO seconds after landing.
const BREAKOUT := 12.0
const CLIMB_MAX := 12.0
const CLIMB_FROM := 0.15
const CLIMB_TO := 0.45
## The perk's icon on the badge: a small glyph (6 art px or less) at 3x art, else 2x or 1x art,
## whichever fits inside the badge (icon_scale).
const SMALL_ICON := 6

static var _ink_tops: Dictionary[Texture2D, int] = {}
static var _images: Dictionary[Texture2D, Image] = {}

var prize: MachinePrize
var _preview: MachinePreview
var _chip: String = ""
var _icon: Texture2D
## The breakout (break_out): the sprite, its outline's clip and outline, its rest and full climb.
var _sprite: TextureRect
var _outline_clip: Control
var _outline: TextureRect
var _sprite_rest: Vector2 = Vector2.ZERO
var _climb_full: float = 0.0


func _init(shown_prize: MachinePrize, preview: MachinePreview) -> void:
	prize = shown_prize
	_preview = preview
	name = "PrizeArt"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	match prize.kind:
		MachinePrize.Kind.PRODUCT, MachinePrize.Kind.COUPON:
			_add_sprite(prize.card, SPRITE_AT)
			if prize.kind == MachinePrize.Kind.PRODUCT:
				_chip = PriceSticker.tier_text(prize.card)
		MachinePrize.Kind.UPGRADE:
			if prize.rarity == MachinePrize.Rarity.LEGENDARY:
				_add_sprite(prize.card, SPRITE_AT - Vector2(0, SHELF_LIFT))
				_chip = "SHELF +1"
			else:
				var shown: CardDefinition = upgraded_card()
				_add_sprite(shown, SPRITE_AT)
				_chip = PriceSticker.tier_text(shown)
		MachinePrize.Kind.REGISTER:
			_add_loyalty()
			if PerkLevels.is_level_up(prize.upgrade):
				_chip = "LV %d" % prize.upgrade.level_number()


## The card an UPGRADES prize turns its copy into (the preview's), else the prize's card.
func upgraded_card() -> CardDefinition:
	if _preview != null and not _preview.to_cards.is_empty():
		return _preview.to_cards[0]
	return prize.card


## The chip's text ("BIG", "GOLDEN", "SHELF +1", a level-up's "LV 2"; "" for none).
func chip_text() -> String:
	return _chip


## The chip's rect in the art box (empty when there is none): over the sprite's foot, or a
## level-up's in the bottom right corner.
func chip_rect() -> Rect2:
	if _chip.is_empty():
		return Rect2()
	var font: Font = ArtStyle.bold_font(BOLD_WEIGHT)
	var width: float = MachineArt.snap(
		MachineArt.text_width(_chip, font, CHIP_SIZE) + CHIP_PAD * 2.0
	)
	if prize.kind == MachinePrize.Kind.REGISTER or has_shelf():
		return Rect2(Vector2(LEVEL_CHIP_RIGHT - width, LEVEL_CHIP_TOP), Vector2(width, CHIP_HEIGHT))
	return Rect2(CHIP_AT, Vector2(width, CHIP_HEIGHT))


## The loyalty prize's perk icon (null: its initials show instead).
func perk_icon() -> Texture2D:
	return _icon


## Whether the art shows the SHELF upgrade's gold plank.
func has_shelf() -> bool:
	return prize.kind == MachinePrize.Kind.UPGRADE and prize.rarity == MachinePrize.Rarity.LEGENDARY


## The perk icon of `upgrade` (its icon_ref), or null.
static func icon_of(upgrade: UpgradeDefinition) -> Texture2D:
	if upgrade == null or upgrade.icon_ref.is_empty():
		return null
	return load(upgrade.icon_ref) as Texture2D


func _add_sprite(card: CardDefinition, at: Vector2) -> void:
	var art: TextureRect = ItemView.item_art(card)
	art.name = "Sprite"
	art.position = at
	add_child(art)
	_sprite = art
	_sprite_rest = at


## The sprite (null: a LOYALTY prize's punch card).
func sprite() -> TextureRect:
	return _sprite


## Breaks the art out of a window whose top is `window_top` (art box px) on a LEGENDARY card: an
## ink outline (clipped to above the window, or all round for a GOLDEN item) behind the sprite,
## and the climb it makes on landing (climb).
func break_out(window_top: float) -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var texture: Texture2D = _sprite.texture
	var texel: float = _sprite.size.x / texture.get_size().x
	var ink_top: float = _sprite_rest.y + ink_top_of(texture) * texel
	_climb_full = clampf(ink_top - (window_top - BREAKOUT), 0.0, CLIMB_MAX)
	var golden: bool = _shown_tier() == CardDefinition.Tier.GOLDEN
	_outline_clip = Control.new()
	_outline_clip.name = "BreakoutClip"
	_outline_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline_clip.clip_contents = not golden
	_outline_clip.position = Vector2(-SIZE.x, -SIZE.y)
	_outline_clip.size = Vector2(SIZE.x * 3.0, (SIZE.y * 3.0) if golden else (SIZE.y + window_top))
	_outline = TextureRect.new()
	_outline.name = "BreakoutOutline"
	_outline.texture = texture
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_outline.stretch_mode = TextureRect.STRETCH_SCALE
	_outline.material = ArtStyle.rim_material(
		PackedColorArray([Palette.INK, Color(Palette.INK, 0.0)])
	)
	_outline.size = _sprite.size + Vector2.ONE * 4.0 * texel
	_outline_clip.add_child(_outline)
	add_child(_outline_clip)
	move_child(_outline_clip, _sprite.get_index())
	climb(-1.0, false)


## The breakout's climb `since` seconds after landing (below 0: at rest in the window; reduced
## motion `rm`: all the way at once).
func climb(since: float, rm: bool) -> void:
	if _outline == null:
		return
	var k: float = 0.0
	if rm and since >= 0.0:
		k = 1.0
	elif since >= 0.0:
		k = MachineArt.ease_back(MachineArt.seg(since, CLIMB_FROM, CLIMB_TO))
	_sprite.position = _sprite_rest - Vector2(0, MachineArt.snap(_climb_full * k))
	var texel: float = _sprite.size.x / _sprite.texture.get_size().x
	_outline.position = _sprite.position - Vector2.ONE * 2.0 * texel - _outline_clip.position


## How far the breakout climbs at most (canvas px), and its outline (null: none).
func climb_full() -> float:
	return _climb_full


func breakout_outline() -> TextureRect:
	return _outline


## The first texel row of `texture` with ink (cached per texture).
static func ink_top_of(texture: Texture2D) -> int:
	if not _ink_tops.has(texture):
		var image: Image = _image_of(texture)
		_ink_tops[texture] = image.get_used_rect().position.y if image != null else 0
	return _ink_tops[texture]


## How many of the sprite's ink texels, at its full climb (climb_full), fall in `rect` (art box
## px); 0 without a sprite. The ticket places a LEGENDARY card's chips and price by it.
func ink_texels(rect: Rect2) -> int:
	if _sprite == null or _sprite.texture == null:
		return 0
	var image: Image = _image_of(_sprite.texture)
	if image == null:
		return 0
	var texel: float = _sprite.size.x / image.get_width()
	var at: Vector2 = _sprite_rest - Vector2(0, MachineArt.snap(_climb_full))
	var from: Vector2i = Vector2i(((rect.position - at) / texel).floor()).max(Vector2i.ZERO)
	var to: Vector2i = Vector2i(((rect.end - at) / texel).ceil()).min(image.get_size())
	var count: int = 0
	for y: int in range(from.y, to.y):
		for x: int in range(from.x, to.x):
			if image.get_pixel(x, y).a > 0.0:
				count += 1
	return count


## `texture`'s image, decompressed (cached per texture; null: none).
static func _image_of(texture: Texture2D) -> Image:
	if not _images.has(texture):
		var image: Image = texture.get_image()
		if image != null and image.is_compressed():
			image.decompress()
		_images[texture] = image
	return _images[texture]


## Keeps the art's words (a coupon's printed name, a perk's initials) on linear filtering under
## the card's nearest-filtered icons.
func keep_text_smooth() -> void:
	for found: Node in find_children("*", "Label", true, false):
		(found as Label).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## The tier the art shows (an upgrade's new tier; PLAIN for a perk).
func _shown_tier() -> int:
	match prize.kind:
		MachinePrize.Kind.REGISTER:
			return CardDefinition.Tier.PLAIN
		MachinePrize.Kind.UPGRADE:
			return upgraded_card().tier if not has_shelf() else prize.card.tier
	return prize.card.tier if prize.card != null else CardDefinition.Tier.PLAIN


func _add_loyalty() -> void:
	var initials: String = LoyaltyCard.initials(
		prize.upgrade.display_name if prize.upgrade != null else ""
	)
	var slot: Rect2 = Rect2(PUNCH_RECT.position + SLOT_AT, STAMP_RING.get_size() * 2.0)
	_icon = icon_of(prize.upgrade)
	if _icon != null:
		var k: float = icon_scale(_icon.get_size())
		var glyph: TextureRect = UiKit.sprite(_icon)
		glyph.name = "PerkIcon"
		glyph.size = _icon.get_size() * k
		glyph.position = MachineArt.snap_point(slot.get_center() - glyph.size / 2.0)
		add_child(glyph)
	else:
		var stamped: Label = _initials_label(initials, INITIALS_SIZE, Palette.PAPER)
		stamped.name = "StampInitials"
		stamped.position = slot.position
		stamped.size = slot.size


## The stamped slot's glyph scale (canvas px per texel) for an icon of `texels`: 2x art for a
## small one (SMALL_ICON or less), else 1x art, so it stays inside the stamp ring.
static func icon_scale(texels: Vector2) -> float:
	if maxf(texels.x, texels.y) <= SMALL_ICON:
		return 4.0
	return 2.0


func _initials_label(text: String, font_size: int, colour: Color) -> Label:
	var label: Label = UiKit.body_label(text, font_size, colour)
	label.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _draw() -> void:
	if prize.kind == MachinePrize.Kind.REGISTER:
		_draw_punch_card()
		return
	if has_shelf():
		var plank: Rect2 = Rect2(SPRITE_AT + Vector2(8, 82), Vector2(80, 12))
		MachineArt.box(self, plank, Palette.GOLD, Palette.BRASS_DARKEST)
		draw_rect(Rect2(plank.position + Vector2(2, 2), Vector2(76, 2)), Palette.MUSTARD_PALE)
		draw_rect(Rect2(plank.position + Vector2(2, 8), Vector2(76, 2)), Palette.BRASS)
		draw_rect(Rect2(plank.position + Vector2(8, 12), Vector2(4, 6)), Palette.BRASS_DARK)
		draw_rect(Rect2(plank.position + Vector2(68, 12), Vector2(4, 6)), Palette.BRASS_DARK)


## The chip over the sprite's foot (drawn by the ticket, over the sprite: see draw_chip).
func draw_chip(item: CanvasItem, origin: Vector2) -> void:
	if _chip.is_empty():
		return
	var font: Font = ArtStyle.bold_font(BOLD_WEIGHT)
	var rect: Rect2 = chip_rect()
	rect.position += origin
	MachineArt.box(item, rect, Palette.MUSTARD_LIGHT, Palette.INK)
	MachineArt.centred_text(item, _chip, rect.get_center(), font, CHIP_SIZE, Palette.INK)


## The punch card (the top bar's stamp slots on a card, the first stamped, as many as a level-up's
## level) and the perk's badge.
func _draw_punch_card() -> void:
	var card: Rect2 = PUNCH_RECT
	MachineArt.box(self, card, Palette.PAPER, Palette.INK)
	draw_rect(
		Rect2(card.position + Vector2(2, 2), Vector2(card.size.x - 4, PUNCH_BAND)), Palette.TEAL
	)
	draw_rect(
		Rect2(card.position + Vector2(2, card.size.y - 4), Vector2(card.size.x - 4, 2)),
		Palette.CREAM_SHADE
	)
	var stamped: int = prize.upgrade.level_number() if prize.upgrade != null else 1
	for slot: int in range(3):
		var texture: Texture2D = STAMP_RING if slot < stamped else STAMP_EMPTY
		var at: Vector2 = card.position + SLOT_AT + Vector2(slot * SLOT_STEP, 0)
		draw_texture_rect(texture, Rect2(at, texture.get_size() * 2.0), false)
