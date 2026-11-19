class_name StockBook
extends Control
## The deck view's STOCK BOOK (2026-11-19, approved by the user, built with no mock-up; it replaces
## the Run info page's hero and MACHINE STOCK grid): what the machine can offer this run, as a
## binder in the FIGURINE BOOK's visual language (BookArt's binder, sleeves, spine rings and
## FamilyRibbon bookmark) but dressed as a store price book, so it is not taken for the cross-run
## collection: a mustard flyer cover with a tomato banner reading "THIS RUN · STOCK BOOK" and a
## price tag counting the stocked items the cart holds ("IN CART 14/32": owned distinct items over
## the stockable ones).
##
## One divider tab per section, MACHINE STOCK's groups: STAPLES (the products of no aisle), each
## stocked aisle in data order (its sign's colours and glyph), COUPONS; each tab counts its items in
## the cart ("3/5"). A section bigger than a spread (PER_SPREAD) takes more tabs. The picked tab's
## items fill the sleeves (three by two a page, the left page first): one StockIcon per item, its
## sprite on a cream insert with its ×N badge and tier mark when the cart holds it, else a dark
## silhouette with its price (a coupon: its rarity). DeckView opens a slot's card tip on hover.
## The FAMILY ribbon hangs over the cover's top edge at the right (ALL and every family printed on
## the stock): picking a family dims the other families' slots (DeckView's filter, `filter`).
##
## Everything is pixel art at 2x on even canvas px (crisp at 1280x720 and at 1920x1080's 1.5).
## It only displays RunState.

signal section_picked(index: int)
signal family_picked(family: String)

const SIZE := Vector2(1184, 480)
const ART := 2
## The book in art px: the binder, the banner and its price tag, the pages, the spine and rings.
const ART_SIZE := Vector2i(592, 240)
const BINDER := Rect2i(2, 2, 586, 234)
const BANNER := Rect2i(8, 6, 574, 22)
const TAG := Rect2i(432, 9, 112, 16)
const PAGES: Array[Rect2i] = [Rect2i(8, 46, 284, 186), Rect2i(300, 46, 284, 186)]
const SPINE := Rect2i(292, 44, 8, 190)
const RING_TOPS: Array[int] = [72, 132, 192]
## A page's sleeves: COLUMNS x ROWS, POCKET_SIZE, the first POCKET_ORIGIN inside the page, apart
## by POCKET_PITCH.
const COLUMNS := 3
const ROWS := 2
const PER_PAGE := COLUMNS * ROWS
const PER_SPREAD := PER_PAGE * 2
const POCKET_ORIGIN := Vector2i(6, 5)
const POCKET_SIZE := Vector2i(88, 86)
const POCKET_PITCH := Vector2i(92, 90)
## The tabs (art px): their row's left, gap and bottom (the pages' top), the picked one's height
## and the others'.
const TAB_LEFT := 10
const TAB_GAP := 2
const TAB_HEIGHT := 16
const TAB_SUNK := 2
## The FAMILY ribbon's top left (art px), over the banner's right end, drawn at 2x.
const RIBBON_AT := Vector2i(556, 0)
const RIBBON_SCALE := 2.0
## The banner's words (2x pixel lettering), the tag's.
const TITLE_WORDS: Array[String] = ["THIS RUN", "·", "STOCK BOOK"]
const TITLE_AT := Vector2i(16, 9)
const TALLY_WORD := "IN CART"
const TALLY := "%d/%d"
const ALL_TEXT := "ALL"
const STAPLES := "STAPLES"
const COUPONS := "COUPONS"
const STAPLES_GLYPH := preload("res://art/icons/aisle_staples.png")
const COUPON_GLYPH := preload("res://art/icons/family_coupon.png")
const SWITCH_SOUND := "ui_switch"
## Node names (for tests).
const TITLE := "Title"
const TALLY_LINE := "Tally"
const TABS := "Tabs"
const SLOTS := "Slots"

static var _backdrop: ImageTexture

var _sections: Array[Section] = []
var _tabs: Array[SectionTab] = []
var _section: int = 0
var _families: PackedStringArray = PackedStringArray([""])
var _ribbon: FamilyRibbon
var _slots: Control
var _owned: int = 0
var _stocked: int = 0
var _tally: PixelLine


## The stock book of `run`.
func _init(run: RunState) -> void:
	name = "StockBook"
	size = SIZE
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cover: TextureRect = UiKit.sprite(backdrop())
	cover.name = "Cover"
	cover.size = SIZE
	add_child(cover)
	var counts: Dictionary[StringName, Vector2i] = cart_counts(run)
	_sections = sections_of(run, counts)
	for card: CardDefinition in run.stock.cards:
		_stocked += 1
		_owned += 1 if counts.has(card.id) else 0
	_add_banner()
	_slots = Control.new()
	_slots.name = SLOTS
	_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slots)
	_add_tabs()
	for section: Section in _sections:
		for index: int in section.cards.size():
			var card: CardDefinition = section.cards[index]
			var held: Vector2i = counts.get(card.id, Vector2i.ZERO)
			var icon: StockIcon = StockIcon.new(
				card, run.balance.machine, held.x, held.y as CardDefinition.Tier, section.light
			)
			icon.position = Vector2(pocket_rect(index).position)
			section.icons.append(icon)
			_slots.add_child(icon)
	_add_ribbon(run)
	show_section(0)


## The book's art (ART_SIZE at 2x): the binder's mustard flyer cover with its tomato banner and
## price tag, two pages of empty sleeves and the spine's rings.
static func backdrop() -> ImageTexture:
	if _backdrop == null:
		var art: StorefrontArt = StorefrontArt.new(ART_SIZE, Vector2i.ZERO)
		_paint_cover(art)
		for page: Rect2i in PAGES:
			_paint_page(art, page)
		_paint_spine(art)
		_backdrop = ImageTexture.create_from_image(art.image)
	return _backdrop


## The stock's sections in order: STAPLES (products of no aisle), each stocked aisle in data order,
## COUPONS, each cut into spreads of PER_SPREAD; empty ones left out. `counts`: cart_counts.
static func sections_of(run: RunState, counts: Dictionary[StringName, Vector2i]) -> Array[Section]:
	var staples: Array[CardDefinition] = []
	var coupons: Array[CardDefinition] = []
	var by_aisle: Dictionary[StringName, Array] = {}
	for card: CardDefinition in run.stock.cards:
		if card.is_coupon():
			coupons.append(card)
			continue
		var aisle: AisleDefinition = run.balance.aisle_of(card)
		if aisle == null:
			staples.append(card)
		else:
			if not by_aisle.has(aisle.id):
				by_aisle[aisle.id] = []
			by_aisle[aisle.id].append(card)
	var found: Array[Section] = []
	var staple_ramp: Array[Color] = [Palette.TOMATO_LIGHT, Palette.TOMATO, Palette.TOMATO_DARK]
	_add_section(found, STAPLES, staple_ramp, false, STAPLES_GLYPH, staples, counts)
	for aisle: AisleDefinition in run.balance.aisles:
		if not by_aisle.has(aisle.id):
			continue
		var cards: Array[CardDefinition] = []
		cards.assign(by_aisle[aisle.id])
		_add_section(
			found,
			aisle.display_name.to_upper(),
			BoosterArt.ramp(aisle.id),
			BoosterArt.LIGHT_SIGNS.has(aisle.id),
			BoosterArt.glyph(aisle.id),
			cards,
			counts
		)
	var coupon_ramp: Array[Color] = [Palette.CREAM, Palette.GREY_LIGHT, Palette.GREY]
	_add_section(found, COUPONS, coupon_ramp, true, COUPON_GLYPH, coupons, counts)
	return found


static func _add_section(
	found: Array[Section],
	caption: String,
	ramp: Array[Color],
	ink: bool,
	glyph: Texture2D,
	cards: Array[CardDefinition],
	counts: Dictionary[StringName, Vector2i]
) -> void:
	for start: int in range(0, cards.size(), PER_SPREAD):
		var section: Section = Section.new()
		section.caption = caption
		section.light = ramp[0]
		section.colour = ramp[1]
		section.shade = ramp[2]
		section.ink = ink
		section.glyph = glyph
		section.cards.assign(cards.slice(start, start + PER_SPREAD))
		for card: CardDefinition in section.cards:
			section.owned += 1 if counts.has(card.id) else 0
		found.append(section)


## The cart's copies of each stocked card, by the stocked card's id: (copies, highest tier). A
## BIG or GOLDEN copy counts for its plain product.
static func cart_counts(run: RunState) -> Dictionary[StringName, Vector2i]:
	var counts: Dictionary[StringName, Vector2i] = {}
	for card: CardInstance in run.deck.cards:
		var id: StringName = card.definition.product_card().id
		var held: Vector2i = counts.get(id, Vector2i.ZERO)
		counts[id] = Vector2i(held.x + 1, maxi(held.y, card.definition.tier))
	return counts


## Sleeve `index` of a spread (the left page's first), in canvas px from the book's top left: the
## slot's rect inside the pocket's 1 art px rim.
static func pocket_rect(index: int) -> Rect2i:
	@warning_ignore("integer_division")
	var page: int = index / PER_PAGE
	var slot: int = index % PER_PAGE
	@warning_ignore("integer_division")
	var cell: Vector2i = Vector2i(slot % COLUMNS, slot / COLUMNS)
	var at: Vector2i = PAGES[page].position + POCKET_ORIGIN + cell * POCKET_PITCH
	return Rect2i((at + Vector2i.ONE) * ART, (POCKET_SIZE - Vector2i(2, 2)) * ART)


## Shows section `index`'s items (its tab picked).
func show_section(index: int) -> void:
	_section = clampi(index, 0, maxi(_sections.size() - 1, 0))
	for at: int in _sections.size():
		for icon: StockIcon in _sections[at].icons:
			icon.visible = at == _section
	for at: int in _tabs.size():
		_tabs[at].picked = at == _section


## The shown section's index.
func shown_section() -> int:
	return _section


func sections() -> Array[Section]:
	return _sections


func tabs() -> Array[SectionTab]:
	return _tabs


## Steps the picked tab by `step` (wrapping), as a click on it would.
func step_section(step: int) -> void:
	if _sections.size() > 1:
		_pick_tab(posmod(_section + step, _sections.size()))


## The shown section's slots, in order.
func shown_icons() -> Array[StockIcon]:
	return _sections[_section].icons if not _sections.is_empty() else [] as Array[StockIcon]


## Every slot of every section, in order.
func all_icons() -> Array[StockIcon]:
	var found: Array[StockIcon] = []
	for section: Section in _sections:
		found.append_array(section.icons)
	return found


## Owned distinct items and stockable ones (the tag's tally).
func tally() -> Vector2i:
	return Vector2i(_owned, _stocked)


func tally_line() -> PixelLine:
	return _tally


func ribbon() -> FamilyRibbon:
	return _ribbon


## The ribbon's families, in its order ("" for ALL first).
func families() -> PackedStringArray:
	return _families


## Dims every slot whose card lacks `family`'s printed tag ("": none dimmed); the ribbon shows it.
func filter(family: String) -> void:
	for icon: StockIcon in all_icons():
		icon.dimmed = not family.is_empty() and not icon.card.tags.has(family)
	var index: int = _families.find(family)
	_ribbon.show_value(maxi(index, 0))


func _add_banner() -> void:
	var title: PixelLine = PixelLine.new()
	title.name = TITLE
	title.show_tokens(TITLE_WORDS, Palette.PAPER, Palette.PAPER, 2)
	title.position = Vector2(TITLE_AT * ART)
	add_child(title)
	_tally = PixelLine.new()
	_tally.name = TALLY_LINE
	_tally.show_tokens([TALLY_WORD, TALLY % [_owned, _stocked]], Palette.INK, Palette.TOMATO_DARK)
	var tag_inside: Vector2 = Vector2(TAG.position * ART) + Vector2(12, 0) * ART
	var room: float = (TAG.size.x - 14) * ART
	_tally.position = Vector2(
		tag_inside.x + ART * floorf((room - _tally.size.x) / (2.0 * ART)),
		(TAG.position.y + 5) * ART
	)
	add_child(_tally)


func _add_tabs() -> void:
	var row: Control = Control.new()
	row.name = TABS
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var x: int = TAB_LEFT
	for index: int in _sections.size():
		var tab: SectionTab = SectionTab.new(_sections[index])
		tab.position = Vector2(x, PAGES[0].position.y - TAB_HEIGHT) * ART
		tab.pressed.connect(_pick_tab.bind(index))
		row.add_child(tab)
		_tabs.append(tab)
		x += roundi(tab.size.x / ART) + TAB_GAP


func _pick_tab(index: int) -> void:
	if index == _section:
		return
	Sfx.play_at(self, SWITCH_SOUND)
	show_section(index)
	section_picked.emit(index)


## The FAMILY ribbon: ALL, then every family printed on the stock, in the palette's order.
func _add_ribbon(run: RunState) -> void:
	_ribbon = FamilyRibbon.new(Vector2(RIBBON_AT * ART), SIZE, RIBBON_SCALE)
	_ribbon.name = "FamilyMenu"
	var palette: FamilyPalette = FamilyPalette.shared()
	var captions: Array[String] = [ALL_TEXT]
	var icons: Array[Texture2D] = [null]
	var styles: Array[FamilyStyle] = [null]
	for style: FamilyStyle in palette.families:
		if style.glyph == null:
			continue
		var printed: bool = run.stock.cards.any(
			func(card: CardDefinition) -> bool: return card.tags.has(style.id)
		)
		if printed:
			_families.append(style.id)
			captions.append(style.display_name.to_upper())
			icons.append(style.glyph)
			styles.append(style)
	_ribbon.set_styles(styles)
	_ribbon.set_options(captions, icons)
	_ribbon.picked.connect(func(index: int) -> void: family_picked.emit(_families[index]))
	add_child(_ribbon)


## The cover: the binder's shadow, the mustard vinyl lit along its top and left with darker
## stitching, the tomato banner with its paper rule and the price tag (a punched hole at its left).
static func _paint_cover(art: StorefrontArt) -> void:
	var b: Rect2i = BINDER
	art.dither(Rect2i(b.position.x + 2, b.end.y, b.size.x, 2), Palette.INK, 2)
	art.dither(Rect2i(b.end.x, b.position.y + 2, 2, b.size.y), Palette.INK, 2)
	art.rect(Rect2i(b.position.x + 1, b.position.y, b.size.x - 2, b.size.y), Palette.INK)
	art.rect(Rect2i(b.position.x, b.position.y + 1, b.size.x, b.size.y - 2), Palette.INK)
	var cover: Rect2i = b.grow(-1)
	art.rect(cover, Palette.MUSTARD)
	art.rect(Rect2i(cover.position, Vector2i(cover.size.x, 1)), Palette.MUSTARD_LIGHT)
	art.rect(Rect2i(cover.position, Vector2i(1, cover.size.y)), Palette.MUSTARD_LIGHT)
	art.rect(Rect2i(cover.position.x, cover.end.y - 1, cover.size.x, 1), Palette.MUSTARD_DARKEST)
	art.rect(Rect2i(cover.end.x - 1, cover.position.y, 1, cover.size.y), Palette.MUSTARD_DARKEST)
	var foot: Rect2i = Rect2i(cover.position.x + 1, cover.end.y - 8, cover.size.x - 2, 7)
	art.dither(foot, Palette.MUSTARD_DARK, 1)
	var stitch: Rect2i = b.grow(-3)
	for x: int in range(stitch.position.x + 2, stitch.end.x - 2, 4):
		art.rect(Rect2i(x, stitch.end.y - 1, 2, 1), Palette.MUSTARD_DARK)
	for y: int in range(BANNER.end.y + 2, stitch.end.y - 2, 4):
		art.rect(Rect2i(stitch.position.x, y, 1, 2), Palette.MUSTARD_DARK)
		art.rect(Rect2i(stitch.end.x - 1, y, 1, 2), Palette.MUSTARD_DARK)
	var n: Rect2i = BANNER
	art.rect(Rect2i(n.position.x + 1, n.position.y, n.size.x - 2, n.size.y), Palette.INK)
	art.rect(Rect2i(n.position.x, n.position.y + 1, n.size.x, n.size.y - 2), Palette.INK)
	var band: Rect2i = n.grow(-1)
	art.rect(band, Palette.TOMATO)
	art.rect(Rect2i(band.position, Vector2i(band.size.x, 1)), Palette.TOMATO_LIGHT)
	art.rect(Rect2i(band.position.x, band.end.y - 2, band.size.x, 2), Palette.TOMATO_DARK)
	var t: Rect2i = TAG
	art.rect(Rect2i(t.position.x + 1, t.position.y, t.size.x - 2, t.size.y), Palette.INK)
	art.rect(Rect2i(t.position.x, t.position.y + 1, t.size.x, t.size.y - 2), Palette.INK)
	var face: Rect2i = t.grow(-1)
	art.rect(face, Palette.MUSTARD_LIGHT)
	art.rect(Rect2i(face.position.x, face.end.y - 1, face.size.x, 1), Palette.MUSTARD)
	art.rect(Rect2i(face.position.x + 3, face.position.y + 5, 4, 4), Palette.INK)
	art.rect(Rect2i(face.position.x + 4, face.position.y + 6, 2, 2), Palette.TOMATO_DARK)
	art.rect(Rect2i(face.position.x + 9, face.position.y + 1, 1, face.size.y - 2), Palette.MUSTARD)


## One page of sleeves (BookArt's look): the page stack's edges on its outer side, the slate
## backing and its pockets (an outline lit along the top, each pocket's open lip).
static func _paint_page(art: StorefrontArt, page: Rect2i) -> void:
	var outer_left: bool = page.position.x < SPINE.position.x
	for step: int in 2:
		var edge_x: int = page.position.x - 1 - step if outer_left else page.end.x + step
		art.rect(
			Rect2i(edge_x, page.position.y + 1 + step, 1, page.size.y - 2 - step * 2),
			Palette.CREAM_SHADE if step % 2 == 0 else Palette.INK
		)
	art.rect(page, Palette.INK)
	var inner: Rect2i = page.grow(-1)
	art.rect(inner, Palette.SLATE_DARK)
	art.rect(Rect2i(inner.position, Vector2i(inner.size.x, 1)), Palette.SLATE)
	for slot: int in PER_PAGE:
		@warning_ignore("integer_division")
		var cell: Vector2i = Vector2i(slot % COLUMNS, slot / COLUMNS)
		var at: Vector2i = page.position + POCKET_ORIGIN + cell * POCKET_PITCH
		var pocket: Rect2i = Rect2i(at, POCKET_SIZE)
		art.rect(pocket, Palette.TEAL_SHADE)
		art.rect(pocket.grow(-1), Palette.TEAL_BLACK)
		art.dither(pocket.grow(-1), Palette.SLATE, 1)
		art.rect(Rect2i(at.x + 1, at.y + 1, POCKET_SIZE.x - 2, 1), Palette.TEAL_DARK)
		art.rect(Rect2i(at.x + 6, at.y, POCKET_SIZE.x - 12, 1), Palette.TEAL_PALE)


## The spine (BookArt's): a dark gutter between the pages and the steel rings over it.
static func _paint_spine(art: StorefrontArt) -> void:
	var s: Rect2i = SPINE
	art.rect(Rect2i(s.position.x, s.position.y + 2, s.size.x, s.size.y - 4), Palette.INK)
	art.rect(Rect2i(s.position.x + 3, s.position.y + 2, 2, s.size.y - 4), Palette.MUSTARD_DARKEST)
	for top: int in RING_TOPS:
		var x0: int = s.position.x - 6
		art.rect(Rect2i(x0 + 1, top, 18, 8), Palette.INK)
		art.rect(Rect2i(x0, top + 1, 20, 6), Palette.INK)
		art.rect(Rect2i(x0 + 1, top + 1, 18, 6), Palette.STEEL_DARK)
		art.rect(Rect2i(x0 + 2, top + 1, 16, 1), Palette.STEEL_PALE)
		art.rect(Rect2i(x0 + 1, top + 2, 18, 2), Palette.STEEL)
		art.rect(Rect2i(x0 + 2, top + 6, 16, 1), Palette.STEEL_DARKEST)
		art.rect(Rect2i(x0 + 4, top + 3, 12, 2), Palette.INK)


## A tab's section: its words, its sign's colours (light, face, shade; `ink` words on a light
## sign), glyph, cards, how many of them the cart holds and their slots.
class Section:
	extends RefCounted

	var caption: String = ""
	var light: Color
	var colour: Color
	var shade: Color
	var ink: bool = false
	var glyph: Texture2D
	var cards: Array[CardDefinition] = []
	var owned: int = 0
	var icons: Array[StockIcon] = []


## A divider tab on the pages' top edge in its section's sign colours: its glyph on a paper square,
## its name and "owned/total" in pixel lettering. The picked one stands TAB_HEIGHT art px tall in
## its face colour; the others TAB_SUNK lower in their shade. The mouse lifts it; a click picks it.
class SectionTab:
	extends Control

	signal pressed

	const PAD := 4
	const GLYPH := 9

	var picked: bool = false:
		set(value):
			picked = value
			_relayout()
	var section: Section
	var _line: PixelLine
	var _hovered: bool = false

	func _init(shown: Section) -> void:
		section = shown
		name = "Tab%s" % shown.caption.to_pascal_case()
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_line = PixelLine.new()
		_line.name = "Words"
		var ink: Color = Palette.INK if shown.ink else Palette.PAPER
		var words: Array = [shown.glyph, shown.caption, "%d/%d" % [shown.owned, shown.cards.size()]]
		_line.show_tokens(words, ink, ink)
		add_child(_line)
		var width: int = PAD * 2 + ceili(_line.size.x / ART)
		size = Vector2(width, TAB_HEIGHT) * ART
		_relayout()

	## The tab's words (for tests).
	func line() -> PixelLine:
		return _line

	func _relayout() -> void:
		if _line == null:
			return
		var top: int = _top()
		var spare: int = TAB_HEIGHT - top - ArtStyle.PIXEL_CAP_HEIGHT
		_line.position = Vector2(PAD, top + floori(spare / 2.0)) * ART
		queue_redraw()

	func _top() -> int:
		return 0 if picked or _hovered else TAB_SUNK

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
			_hovered = what == NOTIFICATION_MOUSE_ENTER
			_relayout()

	func _gui_input(event: InputEvent) -> void:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

	func _draw() -> void:
		var w: int = roundi(size.x / ART)
		var top: int = _top()
		var fill: Color = section.colour if picked else section.shade
		_px(Rect2i(1, top, w - 2, TAB_HEIGHT - top), Palette.INK)
		_px(Rect2i(0, top + 1, w, TAB_HEIGHT - top - 1), Palette.INK)
		_px(Rect2i(1, top + 1, w - 2, TAB_HEIGHT - top - 1), fill)
		_px(Rect2i(2, top + 1, w - 4, 1), section.light if picked else section.colour)
		if picked:
			# Joined to the page: no ink line under it.
			_px(Rect2i(1, TAB_HEIGHT - 1, w - 2, 1), fill)

	func _px(area: Rect2i, colour: Color) -> void:
		draw_rect(Rect2(area.position * ART, area.size * ART), colour)
