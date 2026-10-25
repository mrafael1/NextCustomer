class_name PrizeArt
extends Control
## The art box on a prize ticket (v0.50, mock-up premium_machine_v1.html; M5), 176x120: the real
## sprites, never a stand-in.
## - a product: its item sprite (plain, BIG or GOLDEN as drawn), a BIG or GOLDEN one (NEW ITEMS
##   since v0.61: an item can arrive upgraded) with its tier chip; a coupon: the coupon slip with
##   its icon, or its name printed on it (ItemView.item_art, as the game shows items everywhere);
## - an item upgrade (the UPGRADE chute): the item at its new tier with a BIG / GOLDEN chip; the
##   SHELF upgrade (LEGENDARY) shows the plain item on a gold shelf plank with "SHELF +1", since the
##   GOLDEN palette on it would read as a different product;
## - a LOYALTY prize (the UPGRADE chute's perks): a punch card matching the top bar's loyalty card
##   (cream, a teal band, three stamp slots, the first stamped with the perk's initials, as the top
##   bar's stamps show them) over the perk's badge: its icon (UpgradeDefinition.icon_ref; Big
##   basket's "+1 slot" ticket) on a teal shade badge, or its initials when it has none. A level-up
##   (#108, LV 2 or LV 3) stamps as many slots as its level and shows an "LV n" chip in the art's
##   bottom right corner, clear of the badge (chip_rect).

const SIZE := Vector2(176, 120)
## The item's sprite (ItemView.SPRITE_SIZE) and where it sits.
const SPRITE_AT := Vector2(40, 12)
const SHELF_LIFT := 6.0
const CHIP_AT := Vector2(42, 90)
## A level-up's chip: its right edge and its top in the art box (right of the perk's badge).
const LEVEL_CHIP_RIGHT := 170.0
const LEVEL_CHIP_TOP := 92.0
const CHIP_HEIGHT := 18.0
const CHIP_SIZE := 12
const CHIP_PAD := 6.0
const PUNCH_RECT := Rect2(42, 14, 92, 60)
const BADGE_RECT := Rect2(66, 76, 44, 36)
const BADGE_MIDDLE := Vector2(88, 94)
const BOLD_WEIGHT := 800
const INITIALS_SIZE := 9
const BADGE_INITIALS_SIZE := 14
const STAMP_RING := preload("res://art/icons/stamp_ring.png")
const STAMP_EMPTY := preload("res://art/icons/stamp_ring_empty.png")
## The perk's icon on the badge: a small glyph (6 art px or less) at 3x art, else 2x or 1x art,
## whichever fits inside the badge (icon_scale).
const SMALL_ICON := 6

var prize: MachinePrize
var _preview: MachinePreview
var _chip: String = ""
var _icon: Texture2D


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
	if prize.kind == MachinePrize.Kind.REGISTER:
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


func _add_loyalty() -> void:
	var initials: String = LoyaltyCard.initials(
		prize.upgrade.display_name if prize.upgrade != null else ""
	)
	var stamped: Label = _initials_label(initials, INITIALS_SIZE, Palette.PAPER)
	stamped.name = "StampInitials"
	stamped.position = PUNCH_RECT.position + Vector2(6, 22)
	stamped.size = STAMP_RING.get_size() * 2.0
	_icon = icon_of(prize.upgrade)
	if _icon != null:
		var k: float = icon_scale(_icon.get_size())
		var glyph: TextureRect = UiKit.sprite(_icon)
		glyph.name = "PerkIcon"
		glyph.size = _icon.get_size() * k
		glyph.position = MachineArt.snap_point(BADGE_MIDDLE - glyph.size / 2.0)
		add_child(glyph)
	else:
		var badge: Label = _initials_label(initials, BADGE_INITIALS_SIZE, Palette.PAPER)
		badge.name = "PerkInitials"
		badge.position = BADGE_RECT.position
		badge.size = BADGE_RECT.size


## The badge glyph's scale (canvas px per texel) for an icon of `texels`: 3x art for a small one
## (SMALL_ICON or less), else the largest of 2x and 1x art that stays inside the badge's ink
## border, so a larger glyph (Big basket's 13x12 "+1" ticket) never reaches the punch card.
static func icon_scale(texels: Vector2) -> float:
	var inside: Vector2 = BADGE_RECT.size - Vector2(4, 4)
	if maxf(texels.x, texels.y) <= SMALL_ICON:
		return 6.0
	for k: float in [4.0, 2.0]:
		if texels.x * k <= inside.x and texels.y * k <= inside.y:
			return k
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
	MachineArt.box(self, card, Palette.CREAM, Palette.INK)
	draw_rect(Rect2(card.position + Vector2(2, 2), Vector2(card.size.x - 4, 12)), Palette.TEAL)
	draw_rect(
		Rect2(card.position + Vector2(2, 14), Vector2(card.size.x - 4, 2)), Palette.TEAL_SHADE
	)
	draw_rect(
		Rect2(card.position + Vector2(2, card.size.y - 4), Vector2(card.size.x - 4, 2)),
		Palette.CREAM_SHADE
	)
	var stamped: int = prize.upgrade.level_number() if prize.upgrade != null else 1
	for slot: int in range(3):
		var texture: Texture2D = STAMP_RING if slot < stamped else STAMP_EMPTY
		var at: Vector2 = card.position + Vector2(6 + slot * 28, 22)
		draw_texture_rect(texture, Rect2(at, texture.get_size() * 2.0), false)
	if _icon != null and _icon.get_width() > SMALL_ICON * 2:
		return  # Big basket's +1 slot ticket stands on its own, as the mock-up draws it.
	MachineArt.box(self, BADGE_RECT, Palette.TEAL_SHADE, Palette.INK)
	draw_rect(Rect2(BADGE_RECT.position + Vector2(4, 2), Vector2(36, 2)), Palette.TEAL)
