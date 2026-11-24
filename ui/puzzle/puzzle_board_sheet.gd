class_name PuzzleBoardSheet
extends RefCounted
## The puzzle board's clipboard (#183): the hardboard clipboard (frames/clipboard.png) with its
## steel clip (scenery/clipboard_clip.png) and, clipped to it, the picked puzzle's sheet: its pack
## and number, its title, HIT EXACTLY and its target, YOUR HAND · n SLOTS over the hand's items as
## small compact cards (BoosterCardDraw), its perks, pins and today's events, then its hint.
## Drawn with the board's ArtPen in art px.

const PAPER_INSET := Vector4(8, 12, 8, 34)
const CARD_SCALE := 0.5
const HAND_PER_ROW := 5
const HAND_PITCH := Vector2(41, 46)
const SHEET_HEAD := "%s · %d OF %d"
const TARGET_WORDS := "HIT EXACTLY"
const HAND_TEXT := "YOUR HAND · %d SLOTS"
const PERK_TEXT := "PERK · %s"
const PIN_TEXT := "PIN · %s"
const TODAY_TEXT := "TODAY · %s"
const SOLVED_TEXT := "SOLVED"
const CLIPBOARD := preload("res://art/frames/clipboard.png")
const CLIP := preload("res://art/scenery/clipboard_clip.png")
const CHECK := preload("res://art/icons/mark_check.png")
const MARGINS := Vector4i(3, 3, 3, 3)


## Draws the clipboard over art rect `rect` with `puzzle`'s sheet (pack names from `list`).
static func draw(
	pen: ArtPen, rect: Rect2, puzzle: PuzzleDefinition, list: PuzzleList, profile: ProfileState
) -> void:
	pen.nine(CLIPBOARD, rect.position.x, rect.position.y, rect.size.x, rect.size.y, MARGINS)
	var x: float = rect.position.x + PAPER_INSET.x
	var y: float = rect.position.y + PAPER_INSET.y
	var w: float = rect.size.x - PAPER_INSET.x - PAPER_INSET.z
	var h: float = rect.size.y - PAPER_INSET.y - PAPER_INSET.w
	pen.rb(x, y, w, h, Palette.PAPER, Palette.BROWN_DARK)
	pen.r(x + 1, y + h - 2, w - 2, 1, Palette.CREAM_SHADE)
	pen.tex(CLIP, rect.position.x + floorf((rect.size.x - CLIP.get_width()) / 2.0), y - 6)
	if puzzle == null:
		return
	var left: float = x + 7
	var number: int = list.pack(puzzle.pack).find(puzzle) + 1
	var count: int = list.pack(puzzle.pack).size()
	var head: String = SHEET_HEAD % [list.pack_title(puzzle.pack), number, count]
	pen.caps(head, left, y + 8, Palette.INK_LIGHT)
	if ProfilePuzzles.is_solved(profile, puzzle):
		pen.caps(SOLVED_TEXT, x + w - 22, y + 8, Palette.GREEN_DARK, 1.0, 2)
		pen.tex(CHECK, x + w - 19, y + 4)
	pen.pix(puzzle.title, left, y + 18, Palette.INK)
	pen.caps(TARGET_WORDS, left, y + 33, Palette.TOMATO_DARK)
	pen.chunky("%d€" % puzzle.target, left + 50, y + 29, Palette.TOMATO, 2.0)
	pen.r(left, y + 48, w - 14, 1, Palette.CREAM_SHADE)
	pen.caps(HAND_TEXT % puzzle.slot_count, left, y + 53, Palette.INK_LIGHT)
	_draw_hand(pen, puzzle.hand, left, y + 61)
	var rows: int = ceili(puzzle.hand.size() / float(HAND_PER_ROW))
	var line: float = y + 63 + rows * HAND_PITCH.y
	for text: String in extras(puzzle):
		pen.caps(text, left, line, Palette.TEAL_DARK)
		line += 8
	for words: String in ArtPen.pix_wrap(puzzle.hint, w - 14):
		if line + 10 > y + h:
			break
		pen.pix(words, left, line + 2, Palette.INK_LIGHT)
		line += 10


## The sheet's extra lines: each perk (upgrade), each pin and today's events.
static func extras(puzzle: PuzzleDefinition) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for upgrade: UpgradeDefinition in puzzle.upgrades:
		lines.append(PERK_TEXT % upgrade.display_name.to_upper())
	for pin: PinDefinition in puzzle.pins:
		lines.append(PIN_TEXT % pin.display_name.to_upper())
	var chips: PackedStringArray = PackedStringArray()
	for event: InspectionDefinition in puzzle.inspections:
		chips.append((event.chip_text if event.chip_text != "" else event.display_name).to_upper())
	if not chips.is_empty():
		lines.append(TODAY_TEXT % " · ".join(chips))
	return lines


static func _draw_hand(pen: ArtPen, hand: Array[CardDefinition], x: float, y: float) -> void:
	var full: Vector2 = Vector2(BoosterArt.CW, AisleBoardArt.MH)
	var shift: Vector2 = (full * (1.0 - CARD_SCALE) / 2.0).floor()
	var options: Dictionary = {"compact": true, "still": true, "scale": CARD_SCALE}
	for index: int in hand.size():
		var at: Vector2 = Vector2(index % HAND_PER_ROW, floori(index / float(HAND_PER_ROW)))
		var top_left: Vector2 = Vector2(x, y) + at * HAND_PITCH - shift
		BoosterCardDraw.draw(pen, hand[index], false, top_left.x, top_left.y, options)
