class_name DeckCell
extends Control
## One distinct card on the deck view's Cart page as a card (the cart as cards, mock-up
## docs/art/mockups/cart_cards.html, its "2x8 cart face", approved by the user on 2026-11-13:
## "perfect with your recommended"): the booster's card face at the cart face's width
## (CartCardDraw: the art, the price, the family chips, the name band, the rarity tab COMMON, RARE
## or LEGENDARY with the RARE's teal and the LEGENDARY's gold foil, a BIG or GOLDEN copy's tier
## sticker on the art), drawn UNIT px an art px, and the card's FULL rule under the name band
## (a GlyphLabel: its keywords and families as chips, each with its tooltip), at the largest of
## RULE_SIZES that fits its box; a rule that fits none stops at the smallest with "…" (the full
## text is in the hover's tip). Its other copies stand stacked behind it (narrowed to the column
## gap, fit_stack) and a cream price-gun label counts them ("×3"), clear of the rarity tab. An
## item picked at the start (the pack's, a counted booster's) wears the green START chip over its
## barcode, its tooltip naming where it came from (StartTip). A
## Family sticker shows the family it is set to after its rule ("(set: Breakfast)"). The family
## chips down the art window's left edge (CartCardDraw.chip_families: a product's main family,
## then its other printed families, as the FIGURINE BOOK's cards show them) carry their glyphs as
## FamilyGlyphs (family_glyphs), each naming its family in the game's tip (GlyphTips) when the
## pointer rests on it; they take no clicks, so the card keeps its hover and its clicks.
##
## Hover (the pointer on the card) lifts the face LIFT px; `ringed` draws the chooser's gold ring
## round it, and `out_marked` (a held prize over it, CartPlacing: dropping swaps it out) a tomato
## ring, a tomato tint and a tilted OUT ✕ tag over it. The mix highlight (#105 piece 3) greys the
## whole card for GREY and FAINT (`mix_look`; FAINT also draws a faint dashed outline round it).
## It only displays its card: DeckView owns the clicks, the hover, the highlight and the popup.

signal hovered(cell: DeckCell)
signal unhovered(cell: DeckCell)
signal clicked(cell: DeckCell)

## Screen px per art px: two rows of 8 cards fit the 1184x480 page (the mock-up's 1.56).
const UNIT := 1.55
const SIZE := Vector2(CartCardDraw.CW * UNIT, CartCardDraw.CH * UNIT)
## The room the tab takes above the card (px).
const TOP_ROOM := CartCardDraw.TAB_RISE * UNIT
## How far a hovered card lifts.
const LIFT := 8.0
## The rule's text sizes, largest first: the smallest is about 7 art px (the mock-up's least).
const RULE_SIZES: Array[int] = [13, 12, 11]
const RULE_WEIGHT := 650
## The rule's line pitch over its text size (a keyword chip is 15 px tall).
const RULE_LEADING := 2
## Data's text of a card without a rule, and what the card says instead (greyed).
const NO_RULE := "No rule"
const NO_RULE_TEXT := "No rule: pays its price"
const NO_RULE_COLOR := Palette.GREY
## What ends a rule cut short.
const ELLIPSIS := "…"
## A Family sticker's set family, after its rule.
const STICKER_SET := "(set: %s)"
## Lower-case keywords a rule writes ("its Bakery batch") drawn as their chips.
const LOWER_KEYWORDS := "\\b(batch|chain)\\b"
## The copies' count label (a cream price-gun label, at COUNT_SCALE: the mock-up's 8 art px text)
## over the top right corner, tilted, overhanging it COUNT_OVERHANG art px (the mock-up's 5 out, 9
## up) and always COUNT_TAB_GAP px right of the rarity tab's end (a wide LEGENDARY tab). DeckView
## draws each card over the next column's, so beside a LEGENDARY tab in the narrowest gap the
## label shows whole over that card's top left corner, which holds no tab.
const COUNT_TILT := 7.0
const COUNT_SCALE := 0.5
const COUNT_OVERHANG := Vector2(5, -9)
const COUNT_TAB_GAP := 2.0
## The START chip over the barcode: its least size, text size, word and tilt; its top left in
## art px from the art window's bottom left.
const START_SIZE := Vector2(24, 20)
const START_FONT := 12
const START_TEXT := "START"
const START_TILT := -5.0
const START_AT := Vector2(-2, -13)
## The chooser's ring round the card, outside it by RING_OUTSET.
const RING_WIDTH := 4.0
const RING_OUTSET := 4.0
## The OUT ✕ tag over the card's top: its rect, tilt and text; the face's tint while marked.
const OUT_RECT := Rect2(-6, 16, SIZE.x + 12, 26)
const OUT_TINT := Palette.TOMATO_PALE
const OUT_TILT := -8.0
const OUT_TEXT := "OUT ✕"
const OUT_SIZE := 16
const OUT_WEIGHT := 800
## Node names (for tests).
const FACE := "Face"
const RULE_LABEL := "Rule"
const OUT_TAG := "OutTag"
const START_MARK := "StartMark"
const COUNT_LABEL := "CountLabel"

static var _fits: Dictionary[String, Array] = {}

var card: CardDefinition
var instance: CardInstance
var look: BoosterArt.Look = BoosterArt.Look.COMMON
var copies: int = 1
## The pointer rests on it: the face lifts.
var lifted: bool = false:
	set(value):
		lifted = value
		if _face != null:
			_face.position.y = -LIFT if value else 0.0
## The chooser's gold ring round the card.
var ringed: bool = false:
	set(value):
		ringed = value
		queue_redraw()
## A held prize is over it (CartPlacing): the tomato ring and the OUT ✕ tag; the face lifts.
var out_marked: bool = false:
	set(value):
		out_marked = value
		_show_out()
## The mix highlight's look (#105 piece 3): GREY and FAINT grey the card (ArtStyle.set_mix_grey to
## `mix_greyness`), FAINT adds its dashed outline. Set the greyness first.
var mix_look: MixModel.Look = MixModel.Look.NONE:
	set(value):
		mix_look = value
		_show_mix()
## The calm grey's brightness (x) and saturation (y), PlanningTuning's.
var mix_greyness: Vector2 = Vector2.ONE
## How far right each copy behind it stands (art px; fit_stack keeps the stack in the column gap).
var stack_step: int = CartCardDraw.STACK_STEP_X
var _face: Face
var _rule: GlyphLabel
var _rule_size: int = 0
var _clipped: bool = false
var _shown_rule: String = ""
var _count: EffectSticker
var _marks: Array[RevealChip] = []
var _glyphs: Array[FamilyGlyph] = []
var _mix_mark: MixMark
var _out: Label


## The card face of `card_instance` (its group's first copy) with `copy_count` copies, its look
## from `machine` (a coupon's rarity; null: COMMON), and the family a Family sticker is set to
## (`sticker_family`, "" for none).
func _init(
	card_instance: CardInstance,
	machine: MachineDefinition,
	copy_count: int,
	sticker_family: String = ""
) -> void:
	instance = card_instance
	card = card_instance.definition
	copies = copy_count
	look = CartCardDraw.look_of(card, machine)
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = SIZE
	size = SIZE
	_face = Face.new(self)
	add_child(_face)
	_add_glyphs()
	_add_rule(sticker_family)
	if copies > 1:
		var spec: StickerSpec = StickerSpec.new()
		spec.text = "×%d" % copies
		_count = EffectSticker.new(spec, COUNT_TILT)
		_count.name = COUNT_LABEL
		_count.scale = Vector2.ONE * COUNT_SCALE
		var tab_end: float = CartCardDraw.tab_rect(look).end.x * UNIT
		_count.position = Vector2(
			maxf(
				tab_end + COUNT_TAB_GAP,
				SIZE.x + COUNT_OVERHANG.x * UNIT - _count.size.x * COUNT_SCALE
			),
			COUNT_OVERHANG.y * UNIT
		)
		_face.add_child(_count)


## Narrows the copies' stack (stack_step, down to CartCardDraw.STACK_STEP_MIN) so it stays in
## `gap` px, the gap to the next column (CartLayout.gap): the next card never covers it.
func fit_stack(gap: float) -> void:
	var room: int = floori((gap - 1.0) / (UNIT * CartCardDraw.STACK_MAX))
	stack_step = clampi(room, CartCardDraw.STACK_STEP_MIN, CartCardDraw.STACK_STEP_X)
	_face.queue_redraw()


## How far right of the card its stack reaches (px).
func stack_reach() -> float:
	return mini(copies - 1, CartCardDraw.STACK_MAX) * stack_step * UNIT


## The rule `card` shows: its rule text on one line, its lower-case keywords in capitals (so they
## draw as chips), a Family sticker's set family after it; "" for a card without a rule.
static func rule_line(definition: CardDefinition, sticker_family: String = "") -> String:
	var text: String = definition.rule_text.strip_edges().replace("\n", " ")
	if text == NO_RULE:
		text = ""
	if not text.is_empty():
		var lower: RegEx = RegEx.create_from_string(LOWER_KEYWORDS)
		for found: RegExMatch in lower.search_all(text):
			text = (
				text.substr(0, found.get_start())
				+ found.get_string().to_upper()
				+ text.substr(found.get_end())
			)
	if not sticker_family.is_empty() and FamilySticker.is_family_sticker(definition):
		var named: String = FamilyPalette.shared().display_name(sticker_family)
		text = (text + " " + STICKER_SET % named).strip_edges()
	return text


## The rule's fit in a box `width` x `height` px: [text size, the text shown, cut short]: the
## largest RULE_SIZES size whose lines fit; else the smallest, the text cut at a word with "…".
static func fit_rule(text: String, width: float, height: float) -> Array:
	var key: String = "%s|%d|%d" % [text, roundi(width), roundi(height)]
	if _fits.has(key):
		return _fits[key]
	var found: Array = []
	for text_size: int in RULE_SIZES:
		if _fits_box(text, text_size, width, height):
			found = [text_size, text, false]
			break
	if found.is_empty():
		found = [RULE_SIZES[-1], _cut_to_fit(text, RULE_SIZES[-1], width, height), true]
	_fits[key] = found
	return found


## `text` cut short to fit the box at `text_size`, ending with "…": at a word, else (one word too
## wide) at a character; "…" alone at worst.
static func _cut_to_fit(text: String, text_size: int, width: float, height: float) -> String:
	var words: PackedStringArray = text.split(" ", false)
	while words.size() > 1:
		words.remove_at(words.size() - 1)
		var cut: String = " ".join(words).rstrip(",.:;(") + ELLIPSIS
		if _fits_box(cut, text_size, width, height):
			return cut
	var word: String = words[0] if not words.is_empty() else ""
	while word.length() > 1:
		word = word.left(word.length() - 1)
		if _fits_box(word + ELLIPSIS, text_size, width, height):
			return word + ELLIPSIS
	return ELLIPSIS


static func rule_font() -> Font:
	return ArtStyle.bold_font(RULE_WEIGHT)


static func _fits_box(text: String, text_size: int, width: float, height: float) -> bool:
	var label: GlyphLabel = _rule_label(text, text_size, width)
	var fits: bool = label.fits() and label.size.y <= height + 0.5
	label.free()
	return fits


static func _rule_label(text: String, text_size: int, width: float) -> GlyphLabel:
	return GlyphLabel.new(
		text,
		rule_font(),
		text_size,
		Palette.INK,
		text_size + RULE_LEADING,
		width,
		0,
		false,
		null,
		true
	)


## Adds the START chip (the item came in the starting cart), its tooltip `tip` (StartTip: where
## it came from), over the barcode.
func add_start_mark(tip: String) -> void:
	var chip: RevealChip = make_start_chip()
	chip.name = START_MARK
	chip.add_child(StartTip.new(tip))
	var win: Rect2i = CartCardDraw.window(look)
	chip.position = (Vector2(win.position.x, win.end.y) + START_AT) * UNIT
	chip.pivot_offset = chip.size / 2.0
	chip.rotation_degrees = START_TILT
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.append(chip)
	_face.add_child(chip)


## A START chip (the card's mark and the Cart's legend share it).
static func make_start_chip() -> RevealChip:
	var chip: RevealChip = RevealChip.new(
		Palette.GREEN_DARK, START_SIZE, null, START_TEXT, START_FONT, Palette.PAPER
	)
	chip.ledge = Palette.INK
	return chip


## The item's tags: the card's own; none for a coupon.
func tags() -> PackedStringArray:
	return card.tags.duplicate() if card.is_product() else PackedStringArray()


## The drawn face (it lifts on hover; its children are the rule, the marks and the count).
func face() -> Control:
	return _face


## The rule's label, its text size, the text it shows and whether it was cut short.
func rule_label() -> GlyphLabel:
	return _rule


func rule_size() -> int:
	return _rule_size


func shown_rule() -> String:
	return _shown_rule


func rule_clipped() -> bool:
	return _clipped


## The copies' count ("×3"), or "" for one copy.
func count_text() -> String:
	return _count.text() if _count != null else ""


func count_label() -> EffectSticker:
	return _count


## The family chips' glyphs, top down (the main family's first).
func family_glyphs() -> Array[FamilyGlyph]:
	return _glyphs


## The marks on the card, left to right.
func marks() -> Array[RevealChip]:
	return _marks


## The card's rect, in this cell's coordinates.
func column_rect() -> Rect2:
	return Rect2(Vector2.ZERO, SIZE)


## The rule's box on the face, in this cell's coordinates.
func rule_rect() -> Rect2:
	var box: Rect2 = CartCardDraw.rule_box(card, look)
	return Rect2(box.position * UNIT, box.size * UNIT)


## A FamilyGlyph over each family chip's tile (CartCardDraw draws the tiles), at the face's UNIT.
func _add_glyphs() -> void:
	var chips: Array[FamilyStyle] = CartCardDraw.chip_families(card)
	for index: int in chips.size():
		if chips[index].glyph == null:
			continue
		var glyph: FamilyGlyph = FamilyGlyph.new(chips[index])
		var tile: Rect2i = CartCardDraw.chip_rect(look, index)
		glyph.position = (
			Vector2(tile.position + Vector2i.ONE * CartCardDraw.CHIP_GLYPH_INSET) * UNIT
		)
		glyph.custom_minimum_size = Vector2.ZERO
		glyph.size = chips[index].glyph.get_size() * UNIT
		_glyphs.append(glyph)
		_face.add_child(glyph)


func _add_rule(sticker_family: String) -> void:
	var text: String = rule_line(card, sticker_family)
	var box: Rect2 = rule_rect()
	if text.is_empty():
		_rule_size = RULE_SIZES[0]
		_shown_rule = NO_RULE_TEXT
		_rule = _rule_label(NO_RULE_TEXT, _rule_size, box.size.x)
		_rule.set_color(NO_RULE_COLOR)
	else:
		var fit: Array = fit_rule(text, box.size.x, box.size.y)
		_rule_size = fit[0]
		_shown_rule = fit[1]
		_clipped = fit[2]
		_rule = _rule_label(_shown_rule, _rule_size, box.size.x)
	_rule.name = RULE_LABEL
	_rule.set_centred(true)
	_rule.position = Vector2(
		box.position.x, box.position.y + maxf(0.0, floorf((box.size.y - _rule.size.y) / 2.0))
	)
	_face.add_child(_rule)


## The mix look on the face, and the outline (made at the first FAINT).
func _show_mix() -> void:
	ArtStyle.set_mix_grey(_face, 1.0 if MixModel.greys(mix_look) else 0.0, mix_greyness)
	if _mix_mark == null and mix_look != MixModel.Look.FAINT:
		return
	if _mix_mark == null:
		_mix_mark = MixMark.new()
		add_child(_mix_mark)
	var faint: bool = mix_look == MixModel.Look.FAINT
	_mix_mark.show_look(
		MixModel.Look.FAINT if faint else MixModel.Look.NONE, column_rect().grow(MixMark.INSET)
	)


## The faint outline (this cell's coordinates), or null before the first one.
func mix_mark() -> MixMark:
	return _mix_mark


func _show_out() -> void:
	if out_marked and _out == null:
		_out = UiKit.body_label(OUT_TEXT, OUT_SIZE, Palette.PAPER)
		_out.name = OUT_TAG
		_out.add_theme_font_override("font", MachineDisplay.marked_font(OUT_WEIGHT))
		_out.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_out.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var tag: StyleBoxFlat = StyleBoxFlat.new()
		tag.bg_color = Palette.TOMATO
		tag.border_color = Palette.INK
		tag.set_border_width_all(2)
		tag.border_width_bottom = 4
		_out.add_theme_stylebox_override("normal", tag)
		_out.position = OUT_RECT.position
		_out.size = OUT_RECT.size
		_out.pivot_offset = OUT_RECT.size / 2.0
		_out.rotation_degrees = OUT_TILT
		_out.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_out)
	if _out != null:
		_out.visible = out_marked
	lifted = out_marked
	_face.self_modulate = OUT_TINT if out_marked else Color.WHITE
	queue_redraw()


## The OUT ✕ tag (null until first marked; for tests).
func out_tag() -> Label:
	return _out


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hovered.emit(self)
	elif what == NOTIFICATION_MOUSE_EXIT:
		unhovered.emit(self)


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)


func _draw() -> void:
	var ring: Rect2 = column_rect().grow(RING_OUTSET)
	if out_marked:
		draw_rect(ring.grow(RING_WIDTH / 2.0 + 1.0), Palette.INK, false, 2.0)
		draw_rect(ring, Palette.TOMATO, false, RING_WIDTH)
	elif ringed:
		draw_rect(ring.grow(RING_WIDTH / 2.0 + 1.0), Palette.INK, false, 2.0)
		draw_rect(ring, Palette.GOLD, false, RING_WIDTH)


## The drawn card (CartCardDraw at UNIT): the copies behind it, the foil, the face, its words, the
## tab and the tier sticker; a RARE's and a LEGENDARY's foil moves.
class Face:
	extends Control

	var _cell: DeckCell
	var _pen: ArtPen
	var _now: float = 0.0

	func _init(cell: DeckCell) -> void:
		_cell = cell
		name = FACE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = SIZE
		ArtStyle.use_pixel_material(self)
		_pen = ArtPen.new(self)
		_pen.unit = Vector2.ONE * UNIT
		set_process(cell.look != BoosterArt.Look.COMMON)

	func _process(delta: float) -> void:
		_now += delta
		queue_redraw()

	func _draw() -> void:
		CartCardDraw.draw(_pen, _cell.card, _cell.look, _cell.copies, _now, false, _cell.stack_step)
