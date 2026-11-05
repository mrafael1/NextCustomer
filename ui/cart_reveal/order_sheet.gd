class_name OrderSheet
extends Control
## The staff-room clipboard: one line per card, real provenance, preview and family counts.

## One line's height on the sheet, in stage px.
const ROW := 19.4
## The clipboard and its paper (v1.01: the paper's content runs PAD px in from each side, the
## count box, the rules, the ticks and the family cells all ending on the same right edge).
const SIZE := Vector2(380, 504)
const PAPER_RECT := Rect2(10, 16, 360, 472)
const PAD := 10.0
const TICK := 12.0
## Every line's text is centred on one line, ROW_CENTRE px below the line's top (v1.02: the
## names and sources sat higher than the numbers and prices).
const ROW_CENTRE := 9.0
## The count box clears the brass clip (v1.02: they touched) and the title shares its centre line;
## COUNT_BASELINE puts the digits' ink in the middle of the box.
const COUNT_TOP := 14.0
const COUNT_HEIGHT := 40.0
const COUNT_FONT := 38
const COUNT_BASELINE := 46.0

var shown_cards: Array[CardDefinition] = []
## The cart equation under the title, and its red "+n when you pick a crate" tail (null once a
## pack is picked or previewed).
var equation: Label
var waiting_note: Label
## The highlight behind the pack's lines (null while no pack is picked or previewed).
var pack_rows: PackFrame


func show_cart(run: StartBuildView, pack: StarterPackDefinition, preview: bool) -> void:
	StartBoardKit.clear(self)
	size = SIZE
	StartBoardKit.panel(self, Rect2(Vector2.ZERO, size), Palette.BROWN)
	var paper: Panel = StartBoardKit.panel(self, PAPER_RECT, Palette.PAPER)
	paper.name = "Paper"
	var clip: Panel = StartBoardKit.panel(self, Rect2(SIZE.x / 2 - 40, -6, 80, 32), Palette.BRASS)
	clip.name = "Clip"
	StartBoardKit.panel(self, Rect2(SIZE.x / 2 - 22, 4, 44, 8), Palette.STEEL_LIGHT)
	var right: float = PAPER_RECT.size.x - PAD
	StartBoardKit.words(paper, "ORDER SHEET", Rect2(10, COUNT_TOP, 176, COUNT_HEIGHT))
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
	var count_box: Panel = StartBoardKit.panel(
		paper, Rect2(190, COUNT_TOP, right - 190, COUNT_HEIGHT), Palette.CHARCOAL
	)
	count_box.name = "CountBox"
	var cart_icon: TextureRect = StartBoardKit.icon(
		paper,
		TopBar.CART_ICON,
		Vector2(198, COUNT_TOP + (COUNT_HEIGHT - TopBar.CART_ICON.get_height() * 2.0) / 2.0),
		2
	)
	cart_icon.name = "CountIcon"
	var count: Label = StartBoardKit.number(
		paper,
		"%d/%d" % [shown_cards.size(), run.balance.deck_limit],
		Rect2(224, 0, right - 228, 0),
		Palette.GOLD,
		COUNT_FONT
	)
	count.name = "Count"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	on_baseline(count, COUNT_BASELINE)
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
			paper,
			Rect2(4, 90 + first_pack * ROW - 1, PAPER_RECT.size.x - 8, pack_count * ROW),
			tint,
			preview
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
		var row_number: Label = StartBoardKit.number(
			paper, "%02d" % (index + 1), Rect2(10, y, 30, 0), Palette.GREY, 18
		)
		row_number.name = "RowNumber%d" % index
		on_centre(row_number, y + ROW_CENTRE)
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
			paper, name_text, Rect2(64, y, 138, 0), name_color, 12
		)
		name_label.name = "RowName%d" % index
		on_centre(name_label, y + ROW_CENTRE)
		if waiting:
			name_label.add_theme_font_override("font", ArtStyle.bold_font(700))
		if waiting and line.from != "":
			var press: Panel = StartBoardKit.panel(
				paper, Rect2(202, y + 1, 96, 17), Palette.MUSTARD_PALE, Palette.MUSTARD
			)
			press.name = "PressTag"
			var press_text: Label = StartBoardKit.body(
				press, line.from, Rect2(4, 0, 90, 0), Palette.INK, 11
			)
			on_centre(press_text, press.size.y / 2.0)
		elif not waiting:
			var source: Label = StartBoardKit.body(
				paper, line.from, Rect2(204, y, 94, 0), Palette.INK_LIGHT, 11
			)
			source.name = "RowSource%d" % index
			on_centre(source, y + ROW_CENTRE)
		if card != null:
			var price: Label = StartBoardKit.number(
				paper,
				"–" if card.is_coupon() else "%d€" % card.base,
				Rect2(300, y, right - TICK - 302, 0),
				Palette.INK,
				18
			)
			price.name = "RowPrice%d" % index
			on_centre(price, y + ROW_CENTRE)
		if waiting:
			var tick: PackFrame = PackFrame.add(
				paper, Rect2(right - TICK, y + 3, TICK, TICK), Palette.TOMATO, true
			)
			tick.outline = true
		else:
			var tick_rect: Rect2 = Rect2(right - TICK, y + 3, TICK, TICK)
			var empty: Panel = StartBoardKit.panel(
				paper, tick_rect, Palette.PAPER, Palette.GREY_LIGHT
			)
			empty.name = "Tick%d" % index
		if card != null and not line.get("preview", false):
			StartBoardKit.icon(paper, StartBoardKit.CHECK, Vector2(right - TICK, y + 1), 1)
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
			paper, Rect2(PAD + index * 116, 410, 108, 52), Palette.CREAM
		)
		cell.name = "Family%d" % index
		var text: String = str(counts[family])
		var digits: float = ceilf(
			ArtStyle.pixel_number_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		)
		var style: FamilyStyle = palette.style(family)
		var has_glyph: bool = style != null and style.glyph != null
		var left: float = floorf((108.0 - digits - (28.0 if has_glyph else 0.0)) / 2.0)
		if has_glyph:
			var glyph: TextureRect = UiKit.sprite(style.glyph)
			glyph.position = Vector2(left, 7)
			glyph.size = Vector2(22, 22)
			glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cell.add_child(glyph)
			left += 28
		StartBoardKit.number(cell, text, Rect2(left, -2, digits + 6, 40), Palette.INK, 36)
		var family_label: Label = StartBoardKit.body(
			cell, family, Rect2(4, 33, 100, 18), Palette.INK, 12
		)
		family_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Puts `label`'s first baseline at `baseline` (its parent's px), its height one line of its font.
static func on_baseline(label: Label, baseline: float) -> void:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.position.y = baseline - font.get_ascent(font_size)
	label.size.y = font.get_height(font_size)


## Centres `label`'s line of text (its font's ascent plus descent) on `centre`, on whole px.
static func on_centre(label: Label, centre: float) -> void:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.size.y = font.get_height(font_size)
	label.position.y = roundf(centre - label.size.y / 2.0)
