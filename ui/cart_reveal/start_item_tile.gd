class_name StartItemTile
extends Control
## Opening-time item art above its paper price window and family glyphs.

const SIZE := Vector2(108, 132)


func _init(card: CardDefinition) -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face: Panel = StartBoardKit.panel(self, Rect2(Vector2.ZERO, SIZE), Palette.CREAM)
	StartBoardKit.item(face, card, Vector2(2, 0), 104)
	StartBoardKit.panel(face, Rect2(0, 104, 108, 28), Palette.PAPER)
	StartBoardKit.number(face, "%d€" % card.base, Rect2(56, 102, 50, 28), Palette.INK, 26)
	var left: float = 4
	for family: String in FamilyPalette.shared().shelf_families(card.tags):
		var style: FamilyStyle = FamilyPalette.shared().style(family)
		if style != null and style.glyph != null and left < 46:
			var glyph: TextureRect = UiKit.sprite(style.glyph)
			glyph.position = Vector2(left, 108)
			glyph.size = Vector2(20, 20)
			glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			face.add_child(glyph)
			left += 22
