class_name HandbookMark
extends RefCounted
## A handbook entry's mark (v1.06, HandbookEntry.mark), drawn as the game draws it: a keyword's
## or a word's chip (KeywordChip, a keyword in its own face), a family's glyph, a coupon's icon (an
## item's sprite, half size, for a product card) or the entry's icon, `scale_by` times its size on
## the belt (1 in the index, 2 in an entry's heading). An entry with no mark gets an empty box.

## A coupon icon's art size, and a glyph's.
const COUPON_ICON_SIZE := Vector2(40, 28)
const GLYPH_SIZE := Vector2(18, 18)
const ITEM_SIZE := Vector2(48, 48)


## The mark of `entry` at `scale_by` (1 or 2).
static func make(entry: HandbookEntry, scale_by: int = 1) -> Control:
	var by: float = float(scale_by)
	match entry.mark:
		HandbookEntry.Mark.KEYWORD, HandbookEntry.Mark.WORD:
			var chip: KeywordChip = KeywordChip.new(entry.mark_value)
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.remove_from_group(TipTarget.GROUP)
			chip.scale = Vector2.ONE * by
			return _boxed(chip, chip.size * by)
		HandbookEntry.Mark.FAMILY:
			var palette: FamilyPalette = FamilyPalette.shared()
			var style: FamilyStyle = palette.style(entry.mark_value)
			if style != null and style.glyph != null:
				return _sprite(style.glyph, GLYPH_SIZE * by)
		HandbookEntry.Mark.CARD:
			var card: CardDefinition = FamilyPalette.data_card(entry.mark_value)
			if card != null:
				var icon: Texture2D = ArtStyle.coupon_icon(card)
				if icon != null:
					return _sprite(icon, COUPON_ICON_SIZE * by)
				return _sprite(ArtStyle.item_sprite(card), ITEM_SIZE * by)
		HandbookEntry.Mark.ICON:
			if entry.icon != null:
				return _sprite(entry.icon, entry.icon.get_size() * ArtStyle.ART_SCALE * by)
	var empty: Control = Control.new()
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty.custom_minimum_size = GLYPH_SIZE * by
	return empty


static func _sprite(texture: Texture2D, shown: Vector2) -> TextureRect:
	var sprite: TextureRect = UiKit.sprite(texture)
	sprite.size = shown
	sprite.custom_minimum_size = shown
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return sprite


## `chip` scaled inside a box of its shown size (a container lays out the box, not the chip).
static func _boxed(chip: Control, shown: Vector2) -> Control:
	var box: Control = Control.new()
	box.name = "Mark"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = shown
	box.size = shown
	box.add_child(chip)
	return box
