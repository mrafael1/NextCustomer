class_name GradeTags
extends Control
## A graded run's marks on one card (#182, v1.49), wherever an item shows its price (the hand's
## baskets, the belt, the cart's cards): Shrinkflation's tomato shrink sticker with the euros the
## product lost ("-1€", "-2€" once it shrank again; GradeRules.shrink_of) and Expiry dates' BEST
## BEFORE tag with the shifts it still plays (GradeRules.shifts_left; a coupon's from the day it was
## taken, a dated product's from its week's end). Both pixel art at 2x, the numbers in the number
## font. It only displays: the rules are GradeRules'. It takes no clicks.
##
## A Cart card stands for all its copies (mark_copies, v1.49 play test: a dated copy behind an
## undated one showed nothing): its tag shows the soonest date, and when only some copies are
## dated a small ink chip counts them ("1/2"); the card's tip lists each date (notes). On a Cart
## card the marks stand in two rows right of the family glyph tiles (cell_at; the user's play
## test of 2026-11-24: they covered the glyphs): the BEST BEFORE tag, then under it the copies
## chip and the shrink sticker, clear of the glyphs, the price box (row 2 starts under it), the
## START chip and the barcode (both under row 2).
## On the belt and in the baskets (mark_items) each mark explains itself in the game's hover tip
## (a TipTarget over it, which takes no clicks either, so the item still drags).

const NODE_NAME := "GradeTags"
const SHRINK := preload("res://art/icons/shrink_sticker.png")
const BEST_BEFORE := preload("res://art/icons/best_before.png")
const SCALE := 2.0
const SHRINK_TEXT := "-%d€"
## The marks' hover tips (belt and baskets) and the Cart card tip's lines (notes).
const SHRINK_TITLE := "SHRINKFLATION"
const SHRINK_TIP := "This item pays %d€ less for the rest of the run"
const BEST_BEFORE_TITLE := "BEST BEFORE"
const BEST_BEFORE_TIP := "Leaves your cart after %d more shifts"
const BEST_BEFORE_LAST := "This is its last shift: it leaves your cart after it"
const SHRINK_NOTE := "- Shrinkflation: pays %d€ less"
const DATE_NOTE := "- Best before: %s"
const DATES_NOTE := "- Best before, %d of %d: %s"
const UNDATED_NOTE := "- %d of %d never expire"
const LEFT_WORDS := "leaves after %d more shifts"
const LAST_WORDS := "last shift"
## The BEST BEFORE number's room (art px from its left: right of the hourglass).
const NUMBER_LEFT := 8.0
const FONT_SIZE := 15
## The copies chip ("1/2"): its text, size and padding, ink on paper with an ink border.
const COPIES_TEXT := "%d/%d"
const COPIES_SIZE := 12
const COPIES_PAD := Vector2(3, 1)
const COPIES_BORDER := 2
## Where the marks sit on a belt item (over its mat, above its ticket) and a basket item (over its
## sprite, clear above the basket's rim); a cart card's place is cell_at's.
const BELT_AT := Vector2(4, 144)
const BASKET_AT := Vector2(0, 36)
## A cart card's marks (cell_at): CELL_GLYPH_GAP art px right of the family glyph tiles' column,
## CELL_TOP art px under the art window's top.
const CELL_GLYPH_GAP := 2
const CELL_TOP := 2
## The gap between the two marks when both show (px).
const GAP := 2.0

## The euros off, and the shifts left (-1: never expires; a stack's soonest).
var shrink: int = 0
var shifts_left: int = -1
## A stack's dated copies and its copies (1 and 1 for a single card).
var dated: int = 0
var copies: int = 1
var _shrink_face: TextureRect
var _date_face: TextureRect
var _copies_chip: Label


## Puts `card`'s marks on `view` at `at` (its local px; the shrink sticker at the right of the
## BEST BEFORE tag), in place of the ones it wears; none (removing them) when `run` has nothing
## to mark on it. With `tips`, each mark explains itself on hover. Returns the marks, or null.
static func mark(
	view: Control, run: RunState, card: CardInstance, at: Vector2, tips: bool = false
) -> GradeTags:
	var group: Array[CardInstance] = []
	if card != null:
		group.append(card)
	var tags: GradeTags = mark_copies(view, run, group, at)
	if tags != null and tips:
		tags.add_tips()
	return tags


## Puts the marks of a stack of `cards` (copies of one card) on `view` at `at`: the shrink, the
## soonest date and, when not every copy is dated, the copies chip; in two rows when `rows` (a
## Cart card: the class comment). Returns the marks, or null.
static func mark_copies(
	view: Control, run: RunState, cards: Array[CardInstance], at: Vector2, rows: bool = false
) -> GradeTags:
	var old: Node = view.get_node_or_null(NodePath(NODE_NAME))
	if old != null:
		view.remove_child(old)
		old.queue_free()
	if run == null or cards.is_empty() or run.balance.twists.is_empty():
		return null
	var off: int = GradeRules.shrink_of(run, cards[0].definition)
	var lefts: Array[int] = _dates(run, cards)
	var soonest: int = lefts.min() if not lefts.is_empty() else -1
	if off <= 0 and soonest < 0:
		return null
	var tags: GradeTags = GradeTags.new(off, soonest, lefts.size(), cards.size(), rows)
	tags.position = at
	view.add_child(tags)
	return tags


## Where a Cart card in `look` wears its marks (cell px, DeckCell.UNIT a card art px): right of
## its family glyph tiles' column, under the art window's top.
static func cell_at(look: BoosterArt.Look) -> Vector2:
	var tile: Rect2i = CartCardDraw.chip_rect(look, 0)
	var win: Rect2i = CartCardDraw.window(look)
	return (Vector2(tile.end.x + CELL_GLYPH_GAP, win.position.y + CELL_TOP) * DeckCell.UNIT).round()


## Marks the belt's items (`belt`) and the hand's (`hand`, its basket items) of `run`, each mark
## with its hover tip; and a promo day's items with their promo tag (PromoTag: the belt's from its
## score `result`, when known).
static func mark_items(
	run: RunState, belt: Array[CardView], hand: Array[Control], result: ScoreResult = null
) -> void:
	PromoTag.mark_items(run, belt, hand, result)
	for view: CardView in belt:
		mark(view, run, view.card, BELT_AT, true)
	for item: Control in hand:
		var view: CardView = item as CardView
		if view != null:
			mark(view, run, view.card, BASKET_AT, true)


## The lines a Cart card's tip adds for its `cards` (its copies): the shrink, then each date ("1
## of 2: leaves after 2 more shifts") and the undated copies; none without marks.
static func notes(run: RunState, cards: Array[CardInstance]) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if run == null or cards.is_empty() or run.balance.twists.is_empty():
		return found
	var off: int = GradeRules.shrink_of(run, cards[0].definition)
	if off > 0:
		found.append(SHRINK_NOTE % off)
	var lefts: Array[int] = _dates(run, cards)
	if lefts.is_empty():
		return found
	if cards.size() == 1:
		found.append(DATE_NOTE % _left_words(lefts[0]))
		return found
	var counts: Dictionary[int, int] = {}
	for left: int in lefts:
		counts[left] = counts.get(left, 0) + 1
	var order: Array[int] = []
	order.assign(counts.keys())
	order.sort()
	for left: int in order:
		found.append(DATES_NOTE % [counts[left], cards.size(), _left_words(left)])
	if lefts.size() < cards.size():
		found.append(UNDATED_NOTE % [cards.size() - lefts.size(), cards.size()])
	return found


## The shifts left of `cards`' dated copies.
static func _dates(run: RunState, cards: Array[CardInstance]) -> Array[int]:
	var lefts: Array[int] = []
	for card: CardInstance in cards:
		var left: int = GradeRules.shifts_left(run, card)
		if left >= 0:
			lefts.append(left)
	return lefts


static func _left_words(left: int) -> String:
	return LAST_WORDS if left <= 1 else LEFT_WORDS % (left - 1)


func _init(
	euros: int, left: int, dated_copies: int = 0, all_copies: int = 1, rows: bool = false
) -> void:
	name = NODE_NAME
	shrink = euros
	shifts_left = left
	dated = dated_copies
	copies = all_copies
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x: float = 0.0
	var y: float = 0.0
	var width: float = 0.0
	if shifts_left >= 0:
		_date_face = _face(BEST_BEFORE, str(shifts_left), Palette.INK, NUMBER_LEFT)
		_date_face.name = "BestBefore"
		_date_face.position = Vector2(x, y)
		x += _date_face.size.x + GAP
		if rows:
			# The second row: the copies chip under the tag, then the shrink sticker.
			width = _date_face.size.x
			x = 0.0
			y = _date_face.size.y + GAP
		if dated < copies:
			_copies_chip = _chip(COPIES_TEXT % [dated, copies])
			var top: float = y if rows else roundf((_date_face.size.y - _copies_chip.size.y) / 2.0)
			_copies_chip.position = Vector2(x, top)
			x += _copies_chip.size.x + GAP
	if shrink > 0:
		_shrink_face = _face(SHRINK, SHRINK_TEXT % shrink, Palette.PAPER, 0.0)
		_shrink_face.name = "Shrink"
		_shrink_face.position = Vector2(x, y)
		x += _shrink_face.size.x + GAP
	width = maxf(width, x - GAP)
	size = Vector2(maxf(width, 0.0), _height())
	ArtStyle.use_pixel_material(self)


## Each mark's hover tip (a TipTarget over it; see the class comment).
func add_tips() -> void:
	if _date_face != null:
		var words: String = (
			BEST_BEFORE_LAST if shifts_left <= 1 else BEST_BEFORE_TIP % (shifts_left - 1)
		)
		TipTarget.cover_text(_date_face, words, TipSpec.Kind.WORD, "", "", BEST_BEFORE_TITLE)
	if _shrink_face != null:
		TipTarget.cover_text(
			_shrink_face, SHRINK_TIP % shrink, TipSpec.Kind.WORD, "", "", SHRINK_TITLE
		)


## The shrink sticker, or null.
func shrink_face() -> TextureRect:
	return _shrink_face


## The BEST BEFORE tag, or null.
func date_face() -> TextureRect:
	return _date_face


## The copies chip ("1/2"), or null.
func copies_chip() -> Label:
	return _copies_chip


func _height() -> float:
	var lowest: float = 0.0
	for part: Control in [_shrink_face, _date_face, _copies_chip]:
		if part != null:
			lowest = maxf(lowest, part.position.y + part.size.y)
	return lowest


## One mark: `texture` at SCALE with `text` centred right of `left` art px.
func _face(texture: Texture2D, text: String, ink: Color, left: float) -> TextureRect:
	var face: TextureRect = TextureRect.new()
	face.texture = texture
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.size = texture.get_size() * SCALE
	face.pivot_offset = face.size / 2.0
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(face)
	add_child(face)
	var label: Label = UiKit.number_label(text, FONT_SIZE, false)
	label.add_theme_color_override("font_color", ink)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(left * SCALE, 0)
	label.size = Vector2(face.size.x - left * SCALE, face.size.y)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(label)
	return face


## The copies chip: `text` in the number font, ink on paper in an ink border, sized to fit.
func _chip(text: String) -> Label:
	var chip: Label = UiKit.number_label(text, COPIES_SIZE, false)
	chip.name = "Copies"
	chip.add_theme_color_override("font_color", Palette.INK)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.PAPER
	box.border_color = Palette.INK
	box.set_border_width_all(COPIES_BORDER)
	box.content_margin_left = COPIES_PAD.x + COPIES_BORDER
	box.content_margin_right = COPIES_PAD.x + COPIES_BORDER
	box.content_margin_top = COPIES_PAD.y + COPIES_BORDER
	box.content_margin_bottom = COPIES_PAD.y + COPIES_BORDER
	chip.add_theme_stylebox_override("normal", box)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)
	chip.size = chip.get_combined_minimum_size()
	return chip
