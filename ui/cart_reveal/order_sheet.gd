class_name OrderSheet
extends Control
## The staff-room clipboard: one line per card, real provenance, preview and family counts.

## One line's height on the sheet, in stage px.
const ROW := 19.4

var shown_cards: Array[CardDefinition] = []
## The cart equation under the title, and its red "+n when you pick a crate" tail (null once a
## pack is picked or previewed).
var equation: Label
var waiting_note: Label
## The highlight behind the pack's lines (null while no pack is picked or previewed).
var pack_rows: PackFrame


func show_cart(run: StartBuildView, pack: StarterPackDefinition, preview: bool) -> void:
	StartBoardKit.clear(self)
	size = Vector2(388, 504)
	StartBoardKit.panel(self, Rect2(Vector2.ZERO, size), Palette.BROWN)
	var paper: Panel = StartBoardKit.panel(self, Rect2(14, 16, 360, 472), Palette.PAPER)
	StartBoardKit.panel(self, Rect2(154, -6, 80, 32), Palette.BRASS)
	StartBoardKit.panel(self, Rect2(172, 4, 44, 8), Palette.STEEL_LIGHT)
	StartBoardKit.words(paper, "ORDER SHEET", Rect2(10, 10, 176, 40))
	# The cart's lines come from core (StartSetupRules.cart_lines), so the sheet, the trolley and
	# the board's count never disagree.
	var cart: Array[StartCartLine] = StartSetupRules.cart_lines(
		run.starter, run.start_offer, run.balance, run.pins, pack, preview
	)
	var lines: Array[Dictionary] = []
	var sources: Dictionary[StartCartLine.Source, int] = {}
	for line: StartCartLine in cart:
		sources[line.source] = int(sources.get(line.source, 0)) + 1
		var from: String = line.origin_name
		match line.source:
			StartCartLine.Source.REGULAR:
				from = "regular"
			StartCartLine.Source.DEALT:
				from = line.origin_name if line.origin != &"" else "Staples shelf"
			StartCartLine.Source.PACK:
				if line.card == null:
					from = (
						"press 1, 2 or 3" if lines.size() == run.starter.core_cards.size() else ""
					)
		(
			lines
			. append(
				{
					"card": line.card,
					"from": from,
					"source": line.source,
					"preview": line.preview,
					"want": line.card == null,
				}
			)
		)
	shown_cards = StartSetupRules.cart_cards(cart)
	StartBoardKit.panel(paper, Rect2(190, 10, 158, 40), Palette.CHARCOAL)
	StartBoardKit.icon(paper, TopBar.CART_ICON, Vector2(198, 21), 2)
	var count: Label = StartBoardKit.number(
		paper,
		"%d/%d" % [shown_cards.size(), run.balance.deck_limit],
		Rect2(224, 6, 120, 44),
		Palette.GOLD,
		42
	)
	count.name = "Count"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var regulars: int = int(sources.get(StartCartLine.Source.REGULAR, 0))
	var dealt: int = int(sources.get(StartCartLine.Source.DEALT, 0))
	var packed: int = int(sources.get(StartCartLine.Source.PACK, 0))
	var equation_text: String = "%d regulars + %d dealt" % [regulars, dealt]
	if pack != null:
		equation_text = (
			"%d regulars + %d %s + %d dealt" % [regulars, packed, pack.display_name, dealt]
		)
		if preview:
			equation_text += " · preview"
	equation = StartBoardKit.body(
		paper, equation_text, Rect2(10, 62, 340, 22), Palette.INK_LIGHT, 13
	)
	equation.name = "Equation"
	waiting_note = null
	if pack == null and packed > 0:
		var used: float = ceilf(
			ArtStyle.BODY_FONT.get_string_size(equation_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		)
		equation.size.x = used + 2
		waiting_note = StartBoardKit.body(
			paper,
			"· +%d when you pick a crate" % packed,
			Rect2(14 + used, 62, 336 - used, 22),
			Palette.TOMATO_DARK,
			13
		)
		waiting_note.name = "WaitingNote"
		waiting_note.add_theme_font_override("font", ArtStyle.bold_font(700))
	while lines.size() < run.balance.deck_limit:
		lines.append({"card": null, "from": "for pin cards"})
	pack_rows = null
	var tint: Color = PackFrame.pack_colour(pack) if pack != null else Palette.TOMATO
	var first_pack: int = -1
	var pack_count: int = 0
	for index: int in lines.size():
		if lines[index].get("source", -1) == StartCartLine.Source.PACK:
			first_pack = index if first_pack < 0 else first_pack
			pack_count += 1
	if first_pack >= 0 and pack != null:
		# The pack's lines (agreed rule): a pale tint of its family colour with a BAR px left bar,
		# both dashed while the pack is only previewed.
		pack_rows = PackFrame.add(
			paper, Rect2(4, 90 + first_pack * ROW - 1, 346, pack_count * ROW), tint, preview
		)
		pack_rows.name = "PackRows"
		pack_rows.fill = PackFrame.pale(tint)
		pack_rows.bar = true
	for index: int in lines.size():
		var line: Dictionary = lines[index]
		var y: float = 90 + index * ROW
		var waiting: bool = line.get("want", false)
		StartBoardKit.panel(
			paper, Rect2(10, y + 18, 340, 1), Palette.CREAM_SHADE, Palette.CREAM_SHADE
		)
		StartBoardKit.number(
			paper, "%02d" % (index + 1), Rect2(10, y - 1, 30, 18), Palette.GREY, 18
		)
		var card: CardDefinition = line.card
		var name_text: String = (
			card.display_name if card != null else "pick a crate" if waiting else "free line"
		)
		if card != null:
			StartBoardKit.item(paper, card, Vector2(40, y), 18)
		elif waiting:
			var box: PackFrame = PackFrame.add(
				paper, Rect2(40, y + 1, 18, 16), Palette.TOMATO, true
			)
			box.outline = true
			var mark: Label = StartBoardKit.body(
				box, "?", Rect2(0, 0, 18, 16), Palette.TOMATO_DARK, 12
			)
			mark.clip_text = false
			mark.add_theme_font_override("font", ArtStyle.bold_font(800))
			mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		else:
			StartBoardKit.panel(paper, Rect2(40, y + 2, 18, 14), Palette.CREAM, Palette.GREY_LIGHT)
		var name_color: Color = Palette.INK
		if waiting:
			name_color = Palette.TOMATO_DARK
		elif card == null or line.get("preview", false):
			name_color = Palette.GREY
		var name_label: Label = StartBoardKit.body(
			paper, name_text, Rect2(64, y - 1, 138, 20), name_color, 12
		)
		if waiting:
			name_label.add_theme_font_override("font", ArtStyle.bold_font(700))
		if waiting and line.from != "":
			var press: Panel = StartBoardKit.panel(
				paper, Rect2(202, y + 1, 96, 17), Palette.MUSTARD_PALE, Palette.MUSTARD
			)
			press.name = "PressTag"
			StartBoardKit.body(press, line.from, Rect2(4, -1, 90, 18), Palette.INK, 11)
		elif not waiting:
			StartBoardKit.body(paper, line.from, Rect2(204, y, 94, 18), Palette.INK_LIGHT, 11)
		if card != null:
			StartBoardKit.number(
				paper,
				"–" if card.is_coupon() else "%d€" % card.base,
				Rect2(300, y - 2, 42, 20),
				Palette.INK,
				18
			)
		if waiting:
			var tick: PackFrame = PackFrame.add(
				paper, Rect2(342, y + 3, 12, 12), Palette.TOMATO, true
			)
			tick.outline = true
		else:
			StartBoardKit.panel(paper, Rect2(342, y + 3, 12, 12), Palette.PAPER, Palette.GREY_LIGHT)
		if card != null and not line.get("preview", false):
			StartBoardKit.icon(paper, StartBoardKit.CHECK, Vector2(342, y + 1), 1)
	StartBoardKit.words(paper, "BY FAMILY", Rect2(10, 386, 124, 20), Palette.INK_LIGHT)
	StartBoardKit.body(
		paper, "top 3 · a card can be in 2", Rect2(124, 386, 220, 20), Palette.GREY_DARK, 11
	)
	var counts: Dictionary[String, int] = {}
	for card: CardDefinition in shown_cards:
		for tag: String in card.tags:
			counts[tag] = counts.get(tag, 0) + 1
	var families: Array[String] = []
	families.assign(counts.keys())
	families.sort_custom(
		func(a: String, b: String) -> bool:
			return counts[a] > counts[b] if counts[a] != counts[b] else a < b
	)
	# A local palette, not FamilyPalette.shared().style(...): see PackCrate._init.
	var palette: FamilyPalette = FamilyPalette.shared()
	for index: int in mini(3, families.size()):
		var family: String = families[index]
		# Three equal cells across the sheet; glyph and count centred as one group over the name.
		var cell: Panel = StartBoardKit.panel(
			paper, Rect2(10 + index * 116, 410, 108, 56), Palette.CREAM
		)
		var text: String = str(counts[family])
		var digits: float = ceilf(
			ArtStyle.pixel_number_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		)
		var style: FamilyStyle = palette.style(family)
		var has_glyph: bool = style != null and style.glyph != null
		var left: float = floorf((108.0 - digits - (28.0 if has_glyph else 0.0)) / 2.0)
		if has_glyph:
			var glyph: TextureRect = UiKit.sprite(style.glyph)
			glyph.position = Vector2(left, 9)
			glyph.size = Vector2(22, 22)
			glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cell.add_child(glyph)
			left += 28
		StartBoardKit.number(cell, text, Rect2(left, 0, digits + 6, 40), Palette.INK, 36)
		var family_label: Label = StartBoardKit.body(
			cell, family, Rect2(4, 36, 100, 18), Palette.INK, 12
		)
		family_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
