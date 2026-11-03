class_name PriceSticker
extends Control
## An item's shelf ticket (tickets v5, V5a of mock-up shift_scene_polish_v5_tickets.html, the
## user's "build its recommended", 2026-11-03): one size everywhere, always upright. On the belt it
## hangs on the price rail (mock-up B2, #80 step 6). Its face is in the colour of the family the
## card works with (TicketFace, from FamilyPalette.ticket_families: the data's colours; two
## families make a split ticket); a coupon that works with no family wears the coupon teal.
##
## It reads in one order, in three fixed zones. What the item is: the icon label, top left, its
## printed families' glyphs (FamilyPalette.shelf_families of its tags; a coupon's coupon mark) side
## by side, each with a paper rim and its own tip (FamilyGlyph: "Dairy · Milk is a Dairy item";
## while it shows PlanningEffects lights the matching items). An item that gained a family this
## shift (the Price gun's relabel, show_gained) is the TALL_SIZE ticket: its label grows a second
## row for the gained glyph, GAINED written in the face beside it; only that ticket grows,
## downward, so the prices still form one row. What it pays: the price window, top right
## (PriceWindow, the same box on every ticket), the printed price at rest and the planned or
## counted pay (set_pay) with its state's fill and texture; never a struck price: the printed
## price and the pay are in its tip and the scan popup. What it does: the rule plate, its short
## text (CardDefinition.sticker_summary, formatted in core from the card's own data) in ink on
## cream, the families it works with written as chips (FamilyWord), a keyword as its chip
## (KeywordChip). The text takes the first of TEXT_FITS that fits the plate (2 lines at 14 px,
## else 3 at 13, else 3 at 12), the same for every tier of a card (the widest tier's), and is
## never cut: a text that still doesn't fit gets the MORE chip (MORE_NAME) at the end of its last
## line with the whole rule in its tip (a safety net: the tests hold every card in data/ to fit).
## A card with no text shows its name. Every number comes from the card's data.
##
## A GOLDEN tier (#77) wears the gold ring outside its outline (GOLD_RING_NAME: two gold art px,
## brass on its lower right, then a dark rim) and two sparkles on its corners; no gold inside the
## ticket, so a boosted pay (the window's green) never reads as GOLDEN.
##
## Resting the pointer on the ticket (off its glyphs, window and chips) says what its colour
## means, below it (ColourSpot; FamilyPalette.colour_tip). Planning (#71): set_got rings a hovered
## giver's target in gold inside its outline; a batch card's wrong job (#128, set_wrong_job) turns
## its keyword chip tomato with a cross and rings the ticket WRONG_RING_WIDTH px of tomato just
## inside its outline. Neither changes a number.


## The ticket's colour as a tooltip target (#105): the whole ticket, under its glyphs (a glyph on
## it shows its own tip); its tip says what the colour means, below the ticket.
class ColourSpot:
	extends TipTarget

	func _init(text: String, ticket: Control) -> void:
		super()
		name = COLOUR_SPOT_NAME
		tip_text = text
		tip_below = true
		tip_anchor = ticket
		size = ticket.size


## The tomato ring of a wrong job (#128), inside the ticket's outline.
class WrongRing:
	extends Control

	func _init(ticket_size: Vector2) -> void:
		name = WRONG_RING_NAME
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = ticket_size
		visible = false

	func _draw() -> void:
		for side: Rect2 in PriceSticker.wrong_ring_sides(size):
			draw_rect(side, Palette.TOMATO)


## The gold ring of a hovered giver's target (#71), inside the ticket's outline.
class GotRing:
	extends Control

	func _init(ticket_size: Vector2) -> void:
		name = GOT_RING_NAME
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = ticket_size
		visible = false

	func _draw() -> void:
		var inner: Rect2 = Rect2(Vector2.ZERO, size).grow(-OUTLINE)
		for side: Rect2 in PriceSticker.ring_sides(inner, GOT_RING_WIDTH):
			draw_rect(side, Palette.GOLD)


const SIZE := Vector2(108, 76)
const TALL_SIZE := Vector2(108, 96)
## The ticket's ink outline (one art pixel).
const OUTLINE := 2.0
## The icon label's glyph places (stage px): the printed families on row 1, a gained one on row 2,
## one every ICON_STEP (10 art px: a glyph's 9 columns and its rim never covered).
const ICON_FIRST := Vector2(4, 4)
const ICON_STEP := 20.0
const ICON_ROW_2 := 20.0
const ICONS_PER_ROW := 2
## GAINED (the CAPS sheet at one art px a font px) in the face beside the gained row.
const GAINED_TEXT := "GAINED"
const GAINED_AT := Vector2(52, 30)
## The price window's place (TicketFace.WINDOW at 2x).
const WINDOW_AT := Vector2(48, 2)
## The rule's text: from TEXT_LEFT, TEXT_WIDTH wide, centred down the plate; TEXT_FITS are
## (size, line pitch, lines), the first that fits.
const TEXT_LEFT := 9.0
const TEXT_WIDTH := 91.0
const TEXT_FITS: Array[Vector3i] = [Vector3i(14, 16, 2), Vector3i(13, 14, 3), Vector3i(12, 14, 3)]
## The MORE chip after a text that still doesn't fit, MORE_GAP after its last line.
const MORE_WORD := "MORE"
const MORE_GAP := 4.0
## A GOLDEN ticket's ring (art px out from the outline) and its sparkles (5x5 art at 2x, art px
## from the ticket's top-left; the first from its foot).
const GOLD_RING_ART := 3
const SPARKLE_SIZE := Vector2(10, 10)
const SPARKLE_FOOT_AT := Vector2i(50, -4)
const SPARKLE_TOP_AT := Vector2i(-3, -3)
const GOT_RING_WIDTH := 2.0
const WRONG_RING_WIDTH := 3.0
## Tips (FamilyGlyph's, PriceWindow's).
const MEMBER_TIP := "%s · %s is a %s item"
const GAINED_TIP := "%s · gained from the Price gun this shift"
const PRINTED_TIP := "%s · %s, its printed price"
const PAY_TIP := "%s pays %s (printed %s) · %s"
const ZERO_TIP := "%s pays 0€ (printed %s) · %s"
const ZERO_REASON := "nothing pays it this checkout"
const COUPON_TIP := "%s · a coupon pays nothing itself"
const WASTED_TIP := "%s · WASTED: it gave nothing this checkout"
## Node names (for tests).
const FACE_NAME := "Face"
const WINDOW_NAME := "PriceWindow"
## The name of a Price gun's gained glyph (show_gained), by family.
const GAINED_NAME := "Gained%s"
const GAINED_WORDS_NAME := "GainedWords"
const SUMMARY_NAME := "Summary"
const MORE_NAME := "More"
const GOT_RING_NAME := "GotRing"
const WRONG_RING_NAME := "WrongRing"
const GOLD_RING_NAME := "GoldRing"
const SPARKLE_NAME := "Sparkle%d"
const COLOUR_SPOT_NAME := "ColourSpot"
const TIER_TEXTS: Array[String] = ["", "BIG", "GOLDEN"]
## The tiers a card shares its text size with: its plain card's id with these suffixes.
const TIER_SUFFIXES: Array[String] = ["_big", "_golden"]

const SPARKLE := preload("res://art/effects/sparkle.png")
## The balance whose base redraws a live factor shows off the shift (#128 v3: the Cart, the deck).
const BALANCE := "res://data/balance/balance.tres"

## The first TEXT_FITS index each card's tiers share (by its plain card's id), and the gold rings'
## art by ticket height.
static var _fit_starts: Dictionary[String, int] = {}
static var _gold_rings: Dictionary[int, ImageTexture] = {}

## The shift's redraws left a live factor shows (#128 v3: Stale popcorn's ×N): set it and the
## sticker reads "×1.5 next Snack", its gold ×N chip's tooltip saying how it grows. A card with
## no live factor ignores it.
var redraws_left: int = -1:
	set(value):
		if CardText.live_rule(_definition) == null or value == redraws_left:
			return
		redraws_left = value
		if _summary != null:
			_summary.set_live(CardText.sticker_summary(_definition, value), _live_tips())
			_place_summary()

var _families: PackedStringArray = PackedStringArray()
var _styles: Array[FamilyStyle] = []
var _text_color: Color = Palette.INK
var _face: TextureRect
var _glyphs: Array[FamilyGlyph] = []
var _window: PriceWindow
var _summary: GlyphLabel
var _more: KeywordChip
var _got_ring: GotRing
var _wrong_ring: WrongRing
var _colour_spot: ColourSpot
var _gained_words: PixelWords
## The family a Price gun gave the item (#132), its glyph on the label's second row; null for none.
var _gained: FamilyGlyph
var _definition: CardDefinition
var _palette: FamilyPalette
## The TEXT_FITS index the card's tiers share, and the one the text shows at now (a wrong job's
## wider chip may step it down while it lasts).
var _base_fit: int = 0
var _fit: int = 0


## The ticket of `definition`, in the game's family colours (`palette`: the game's when null).
func _init(definition: CardDefinition, palette: FamilyPalette = null) -> void:
	var families: FamilyPalette = palette if palette != null else FamilyPalette.shared()
	_definition = definition
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	custom_minimum_size = SIZE
	_families = families.ticket_families(definition)
	for style: FamilyStyle in families.styles(_families):
		if style.has_ticket_colours():
			_styles.append(style)
	_text_color = families.text_color(_families) if not _styles.is_empty() else Palette.PAPER
	if _styles.is_empty():
		_styles.append(_fallback_style(definition))
	_face = UiKit.sprite(TicketFace.texture(_styles, definition.is_coupon()))
	_face.name = FACE_NAME
	_face.size = SIZE
	add_child(_face)
	if definition.tier == CardDefinition.Tier.GOLDEN:
		_add_gold()
	_colour_spot = ColourSpot.new(families.colour_tip(definition), self)
	add_child(_colour_spot)
	_add_glyphs(definition, families)
	_window = PriceWindow.new()
	_window.name = WINDOW_NAME
	_window.position = WINDOW_AT
	_window.tip_below = true
	_window.tip_anchor = self
	add_child(_window)
	clear_pay()
	# Over the window's edge too: a wrong job rings the whole ticket.
	_wrong_ring = WrongRing.new(SIZE)
	add_child(_wrong_ring)
	if CardText.live_rule(definition) != null:
		redraws_left = _base_redraws(definition)
	var line: String = CardText.sticker_summary(definition, redraws_left)
	# A card with no rule shows its name, centred, at the first fit's size.
	_palette = families
	_base_fit = _fit_start(definition, families) if not line.is_empty() else 0
	_build_summary(line if not line.is_empty() else definition.display_name, _base_fit)
	_place_summary()
	_got_ring = GotRing.new(SIZE)
	add_child(_got_ring)


## "N€": a price as tickets print it.
static func price_text(amount: int) -> String:
	return MonitorText.euros(amount)


## The pay on the ticket's window (#71, #105; tickets v5): `pay` of `amount`, `reason` the tip's
## why for a 0€ pay ("SPOT CHECK"). PLAIN shows the printed price.
func set_pay(pay: PlanningModel.Pay, amount: int, reason: String = "") -> void:
	var item: String = _definition.display_name
	var printed: String = price_text(_definition.base)
	var state: PriceWindow.State = PriceWindow.state_for(pay, _definition.is_coupon())
	var shown: int = _definition.base if state == PriceWindow.State.PRINTED else amount
	_window.show_pay(state, 0 if state == PriceWindow.State.ZERO else shown)
	match state:
		PriceWindow.State.COUPON:
			_window.tip_text = COUPON_TIP % item
		PriceWindow.State.WASTED:
			_window.tip_text = WASTED_TIP % item + (" · " + reason if not reason.is_empty() else "")
		PriceWindow.State.ZERO:
			var why: String = reason if not reason.is_empty() else ZERO_REASON
			_window.tip_text = ZERO_TIP % [item, printed, why]
		PriceWindow.State.BOOSTED, PriceWindow.State.LOWERED:
			_window.tip_text = PAY_TIP % [item, price_text(amount), printed, _window.state_name()]
		_:
			_window.tip_text = PRINTED_TIP % [item, printed]


## Puts the printed price back in the window, undimmed.
func clear_pay() -> void:
	set_pay(PlanningModel.Pay.PLAIN, _definition.base)
	_window.set_dimmed(false)


## The price window.
func window() -> PriceWindow:
	return _window


## The ticket's wrong job (#128): `reason` (the WASTED step's tooltip text) turns its keyword
## chips tomato and rings it in tomato; "" puts it back. The chips are summary().keywords(), the
## ring the child WRONG_RING_NAME, the reason summary().keyword_wasted().
func set_wrong_job(reason: String) -> void:
	_wrong_ring.visible = not reason.is_empty()
	if reason != _summary.keyword_wasted():
		_summary.set_keyword_wasted(reason)
		_place_summary()


## The ring's sides (`width` wide) just inside `rect`, in its coordinates: top, bottom, left, right.
static func ring_sides(rect: Rect2, width: float) -> Array[Rect2]:
	return [
		Rect2(rect.position, Vector2(rect.size.x, width)),
		Rect2(rect.position.x, rect.end.y - width, rect.size.x, width),
		Rect2(rect.position.x, rect.position.y + width, width, rect.size.y - 2.0 * width),
		Rect2(rect.end.x - width, rect.position.y + width, width, rect.size.y - 2.0 * width),
	]


## A wrong job's tomato ring's sides in the coordinates of a ticket `ticket_size` big:
## WRONG_RING_WIDTH just inside its outline (BatchFrame redraws the parts its foot covers).
static func wrong_ring_sides(ticket_size: Vector2 = SIZE) -> Array[Rect2]:
	return ring_sides(Rect2(Vector2.ZERO, ticket_size).grow(-OUTLINE), WRONG_RING_WIDTH)


## Rings a product's ticket in gold as a hovered giver's target (#71), or takes the ring off. A
## coupon's ticket is never ringed.
func set_got(got: bool) -> void:
	_got_ring.visible = got and not _definition.is_coupon()
	_got_ring.queue_redraw()


## The ring of a hovered giver's target (visible while ringed).
func got_ring() -> Control:
	return _got_ring


## The families its face is coloured by (none: the coupon teal).
func face_families() -> PackedStringArray:
	return _families


## The face (a TextureRect of TicketFace's art).
func face() -> TextureRect:
	return _face


## The family glyphs in its icon label (a coupon's coupon mark), the gained one last.
func glyphs() -> Array[FamilyGlyph]:
	return _glyphs


## Shows the family `family` a Price gun gave the item this shift (#132) on the label's second
## row, the ticket growing to TALL_SIZE; "" takes it off. Products only (none for a family it has).
func show_gained(family: String) -> void:
	if _definition.is_coupon():
		return
	var style: FamilyStyle = FamilyPalette.shared().style(family)
	if _gained != null and (style == null or _gained.name != GAINED_NAME % family):
		_glyphs.erase(_gained)
		# Hidden and freed at the frame's end, never left out of the tree.
		_gained.visible = false
		_gained.name = "Removed"
		_gained.queue_free()
		_gained = null
	var has: bool = _families.has(family) or _definition.tags.has(family)
	if _gained == null and style != null and style.glyph != null and not has:
		_gained = _new_glyph(style, GAINED_TIP % style.display_name)
		_gained.name = GAINED_NAME % family
		add_child(_gained)
		_glyphs.append(_gained)
	_set_tall(_gained != null)
	_lay_out_glyphs()


## Whether it is the tall ticket (a gained family).
func is_tall() -> bool:
	return _gained != null


## The rule plate's rect (this ticket's coordinates).
func plate_rect() -> Rect2:
	var plate: Rect2i = TicketFace.plate_rect(is_tall())
	return Rect2(plate.position * ArtStyle.ART_SCALE, plate.size * ArtStyle.ART_SCALE)


## The short text.
func summary() -> GlyphLabel:
	return _summary


## Where the short text's lines are drawn (this sticker's coordinates; empty with no text), with
## the MORE chip (the child MORE_NAME, its tip the whole rule) when it shows.
func summary_text_rect() -> Rect2:
	var rect: Rect2 = _summary.text_rect()
	if not rect.has_area():
		return Rect2()
	var drawn: Rect2 = Rect2(_summary.position + rect.position, rect.size)
	if _more != null:
		drawn = drawn.merge(Rect2(_more.position, _more.size))
	return drawn


## The GOLDEN ring (null on any other tier).
func gold_ring() -> TextureRect:
	return get_node_or_null(GOLD_RING_NAME) as TextureRect


## A card's tier tag ("BIG", "GOLDEN"), or "" for a plain card.
static func tier_text(definition: CardDefinition) -> String:
	return TIER_TEXTS[definition.tier] if definition != null else ""


## The TEXT_FITS index `line` takes on the plate, from `start` on: the first that fits (its
## lines and its room), else -1.
static func fit_for(line: String, start: int, palette: FamilyPalette, live: Dictionary = {}) -> int:
	for index: int in range(start, TEXT_FITS.size()):
		var label: GlyphLabel = _label_at(line, index, palette)
		label.set_live(line, live)
		var fits: bool = label.fits()
		label.free()
		if fits:
			return index
	return -1


func _live_tips() -> Dictionary:
	return CardText.live_tips(_definition, redraws_left)


func _add_glyphs(definition: CardDefinition, families: FamilyPalette) -> void:
	var shown: PackedStringArray = PackedStringArray(["Coupon"])
	if not definition.is_coupon():
		shown = families.shelf_families(definition.tags)
	for family: String in shown:
		var style: FamilyStyle = families.style(family)
		if style == null or style.glyph == null:
			continue
		var name_shown: String = style.display_name
		var glyph: FamilyGlyph = _new_glyph(
			style, MEMBER_TIP % [name_shown, definition.display_name, name_shown]
		)
		add_child(glyph)
		_glyphs.append(glyph)
	_lay_out_glyphs()


## The look of a ticket with no family colours: the coupon teal (a plain coupon), else cream.
static func _fallback_style(definition: CardDefinition) -> FamilyStyle:
	var style: FamilyStyle = FamilyStyle.new()
	if definition.is_coupon():
		style.face = Palette.TEAL_SHADE
		style.light = Palette.TEAL
		style.shade = Palette.TEAL_DARK
		style.paper_text = true
	else:
		style.face = Palette.CREAM_SHADE
		style.light = Palette.CREAM
		style.shade = Palette.CREAM_DARKEST
	return style


## The first TEXT_FITS index every tier of `definition`'s card fits from (cached by its plain
## card's id), so two Milks on a belt always match.
static func _fit_start(definition: CardDefinition, palette: FamilyPalette) -> int:
	var stem: CardDefinition = definition
	while stem.variant_of != null:
		stem = stem.variant_of
	var key: String = String(stem.id)
	if _fit_starts.has(key):
		return _fit_starts[key]
	var tiers: Array[CardDefinition] = [stem]
	for suffix: String in TIER_SUFFIXES:
		var tier: CardDefinition = FamilyPalette.data_card(key + suffix)
		if tier != null:
			tiers.append(tier)
	if not tiers.has(definition):
		tiers.append(definition)
	var start: int = 0
	for tier: CardDefinition in tiers:
		var redraws: int = _base_redraws(tier)
		var line: String = CardText.sticker_summary(tier, redraws)
		if line.is_empty():
			continue
		var fit: int = fit_for(line, 0, palette, CardText.live_tips(tier, redraws))
		start = maxi(start, fit if fit >= 0 else TEXT_FITS.size() - 1)
	_fit_starts[key] = start
	return start


static func _base_redraws(definition: CardDefinition) -> int:
	if CardText.live_rule(definition) == null:
		return -1
	return (load(BALANCE) as BalanceDefinition).base_redraws


static func _label_at(line: String, index: int, palette: FamilyPalette) -> GlyphLabel:
	var fit: Vector3i = TEXT_FITS[index]
	return GlyphLabel.new(
		line,
		ArtStyle.bold_font(ArtStyle.TICKET_TEXT_WEIGHT),
		fit.x,
		Palette.INK,
		fit.y,
		TEXT_WIDTH,
		fit.z,
		false,
		palette,
		true
	)


func _new_glyph(style: FamilyStyle, tip: String) -> FamilyGlyph:
	var glyph: FamilyGlyph = FamilyGlyph.new(style, true)
	glyph.tip_text = tip
	glyph.tip_below = true
	glyph.tip_anchor = self
	return glyph


## The short text `line` at TEXT_FITS[`fit`], in place of the one shown (its wrong job kept).
func _build_summary(line: String, fit: int) -> void:
	var wasted: String = ""
	var at: int = -1
	if _summary != null:
		wasted = _summary.keyword_wasted()
		at = _summary.get_index()
		remove_child(_summary)
		_summary.free()
	_fit = fit
	_summary = _label_at(line, fit, _palette)
	_summary.name = SUMMARY_NAME
	_summary.set_tip(true, self)
	_summary.set_live(_summary.text, _live_tips())
	if not wasted.is_empty():
		_summary.set_keyword_wasted(wasted)
	add_child(_summary)
	if at >= 0:
		move_child(_summary, at)


## Fits the text to its plate: at the tiers' shared fit, a smaller one only while a wrong job's
## wider chip needs it, the MORE chip when it still doesn't fit; then centred down the plate on
## the art grid (a card's name centred across it too).
func _place_summary() -> void:
	if _more != null:
		remove_child(_more)
		_more.queue_free()
		_more = null
	if _fit != _base_fit:
		_build_summary(_summary.text, _base_fit)
	while not _summary.fits() and _fit < TEXT_FITS.size() - 1:
		_build_summary(_summary.text, _fit + 1)
	_summary.set_end_inset(0.0)
	if not _summary.fits():
		var full: String = _definition.rule_text.strip_edges()
		_more = KeywordChip.new(MORE_WORD, "", full if not full.is_empty() else _summary.text)
		_more.name = MORE_NAME
		_more.tip_below = true
		_more.tip_anchor = self
		_summary.set_end_inset(_more.size.x + MORE_GAP)
		add_child(_more)
	var plate: Rect2 = plate_rect()
	var lines: int = maxi(_summary.line_count(), 1)
	var room: float = plate.size.y - lines * _summary.pitch()
	var top: float = (
		plate.position.y + floorf(room / (2.0 * ArtStyle.ART_SCALE)) * ArtStyle.ART_SCALE
	)
	var left: float = TEXT_LEFT
	if CardText.sticker_summary(_definition, redraws_left).is_empty():
		left = roundf(plate.get_center().x - _summary.text_rect().size.x / 2.0)
	_summary.position = Vector2(left, top)
	if _more != null:
		var most: float = plate.end.x - ArtStyle.ART_SCALE - _more.size.x
		_more.position = Vector2(
			minf(snappedf(left + _summary.last_line_end() + MORE_GAP, ArtStyle.ART_SCALE), most),
			(
				top
				+ (lines - 1) * _summary.pitch()
				+ floorf((_summary.pitch() - KeywordChip.HEIGHT) / 2.0)
			)
		)


func _lay_out_glyphs() -> void:
	var printed: int = 0
	for glyph: FamilyGlyph in _glyphs:
		if glyph == _gained:
			glyph.position = ICON_FIRST + Vector2(0, ICON_ROW_2)
			continue
		var row: int = floori(printed / float(ICONS_PER_ROW))
		var column: int = printed % ICONS_PER_ROW
		glyph.position = ICON_FIRST + Vector2(ICON_STEP * column, ICON_ROW_2 * row)
		printed += 1


## Grows the ticket to TALL_SIZE (a gained family) or back: its face, rings, spot and text.
func _set_tall(tall: bool) -> void:
	var ticket: Vector2 = TALL_SIZE if tall else SIZE
	if size == ticket:
		return
	# The minimum first: a size under the old minimum would not take.
	custom_minimum_size = ticket
	size = ticket
	_face.texture = TicketFace.texture(_styles, _definition.is_coupon(), tall)
	_face.size = ticket
	for part: Control in [_wrong_ring, _got_ring, _colour_spot]:
		part.size = ticket
	if _gained_words == null:
		_gained_words = PixelWords.new(
			GAINED_TEXT, PixelWords.Sheet.CAPS, ArtStyle.ART_SCALE, _text_color
		)
		_gained_words.name = GAINED_WORDS_NAME
		_gained_words.position = GAINED_AT
		add_child(_gained_words)
	_gained_words.visible = tall
	if _definition.tier == CardDefinition.Tier.GOLDEN:
		_place_gold()
	_place_summary()


func _add_gold() -> void:
	var ring: TextureRect = UiKit.sprite(_gold_ring(false))
	ring.name = GOLD_RING_NAME
	add_child(ring)
	for index: int in 2:
		var sparkle: TextureRect = UiKit.sprite(SPARKLE)
		sparkle.name = SPARKLE_NAME % index
		sparkle.size = SPARKLE_SIZE
		sparkle.z_index = 1
		add_child(sparkle)
	_place_gold()


func _place_gold() -> void:
	var ring: TextureRect = gold_ring()
	var tall: bool = size.y > SIZE.y
	ring.texture = _gold_ring(tall)
	var grow: float = GOLD_RING_ART * ArtStyle.ART_SCALE
	ring.position = -Vector2.ONE * grow
	ring.size = size + Vector2.ONE * 2.0 * grow
	var foot: Vector2i = SPARKLE_FOOT_AT + Vector2i(0, TicketFace.art_size(tall).y)
	(get_node(SPARKLE_NAME % 0) as Control).position = Vector2(foot * ArtStyle.ART_SCALE)
	(get_node(SPARKLE_NAME % 1) as Control).position = Vector2(SPARKLE_TOP_AT * ArtStyle.ART_SCALE)


## The GOLDEN ring's art round a ticket, tall or not (mock-up V5a): the ticket's shape grown by
## one art px three times (8 neighbours, so the cut corners follow), the first two rings gold with
## brass on the lower right, the third brass's darkest. Cached by height.
static func _gold_ring(tall: bool) -> ImageTexture:
	var art: Vector2i = TicketFace.art_size(tall)
	if _gold_rings.has(art.y):
		return _gold_rings[art.y]
	var pad: int = GOLD_RING_ART
	var out: Image = Image.create_empty(art.x + 2 * pad, art.y + 2 * pad, false, Image.FORMAT_RGBA8)
	var shape: Dictionary[Vector2i, bool] = {}
	for y: int in art.y:
		var inset: int = 2 if y == 0 or y == art.y - 1 else (1 if y == 1 or y == art.y - 2 else 0)
		for x: int in range(inset, art.x - inset):
			shape[Vector2i(x, y)] = true
	var rings: Array[Array] = [
		[Palette.GOLD, Palette.BRASS], [Palette.GOLD, Palette.BRASS], [Palette.BRASS_DARKEST]
	]
	for ring: Array in rings:
		var grown: Dictionary[Vector2i, bool] = shape.duplicate()
		for y: int in range(-pad, art.y + pad):
			for x: int in range(-pad, art.x + pad):
				var at: Vector2i = Vector2i(x, y)
				if shape.has(at) or not _touches(shape, at):
					continue
				grown[at] = true
				var lower_right: bool = y >= art.y - 1 or (x >= art.x - 1 and y >= 2)
				var colour: Color = ring[ring.size() - 1] if lower_right else ring[0]
				out.set_pixel(x + pad, y + pad, colour)
		shape = grown
	_gold_rings[art.y] = ImageTexture.create_from_image(out)
	return _gold_rings[art.y]


static func _touches(shape: Dictionary[Vector2i, bool], at: Vector2i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if shape.has(at + Vector2i(dx, dy)):
				return true
	return false
