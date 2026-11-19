class_name BuildRegulars
extends RefCounted
## YOUR BUILD's REGULARS crate (v1.45, the user's decision of 2026-11-19): the regulars in their
## crate in front of the staff room's lockers, each item with its families' glyphs, the SWAP key
## (once the profile has unlocked the swap: StartSetupRules.swap_limit; it opens the swap window
## over the page, StartBoard.open_swap; since round 2 of the 2026-11-19 play test branded with two
## swap arrows, no word on it, its tip naming SWAP; since round 3 a pale plate screwed on the
## crate's front, under the glyphs, with no swaps-left count: the swap window shows it) and KEEP.
## Like the BADGE PINS step, the crate is a step every run: OPEN STORE waits for KEEP (after the
## pins step when one waits; BuildPage.regulars_pending). A guided step that locks the swap
## (TutorialAnchors.SWAP_KEY) hides the SWAP key.

## The SWAP key's and KEEP's hit ids (TutorialAnchors.SWAP_KEY, REGULARS_OK).
const ID := "swap_key"
const KEEP_ID := "regulars_ok"
## The crate (art px): its sign, the crate with the items, its front with the glyphs, the keys.
## The front is two planks: the glyphs on the top one, the SWAP plate on the taller bottom one.
const BOX := Rect2i(192, 86, 236, 164)
const SIGN_Y := 86
const BACK_TOP := 106
const FRONT_TOP := 162
const FRONT_BOTTOM := 212
const KEY_Y := 222
const KEY_H := 28
## KEEP stands centred under the crate.
const KEEP_RECT := Rect2i(259, KEY_Y, 102, KEY_H)
## The SWAP plate: centred on the crate's front (x 310), on its bottom plank just under
## the seam (SEAM_Y + 3); even sizes, so its brand sits dead centre on whole pixels.
const SWAP_W := 36
const SWAP_H := 22
const SWAP_RECT := Rect2i(292, 186, SWAP_W, SWAP_H)
## The SWAP plate's brand: two swap arrows burned into it (hovered: gold; no swap left: dim).
const BRAND := preload("res://art/start/swap_brand.png")
const BRAND_HOT := preload("res://art/start/swap_brand_hot.png")
const BRAND_OFF := preload("res://art/start/swap_brand_off.png")
## The SWAP key's tip: its title, its body and its live line (the swaps left, or the undo).
const SWAP_TIP_TITLE := "SWAP"
const SWAP_TIP_BODY := "Trade one of YOUR REGULARS for a card from today's aisles."
const SWAP_TIP_LEFT := "%d left."
const SWAP_TIP_UNDO := "None left. Click to undo a swap."

## The shelf under the crate (art px): its lip past the crate's ends, its top's and face's depth,
## its brackets' height; the crate's back slats, its front's plank seam, its corner braces' arm.
const SHELF_LIP := 5
const SHELF_TOP := 3
const SHELF_FACE := 6
const BRACKET_H := 16
const SLAT_H := 9
const SEAM_Y := 183
const BRACE := 9
## The front planks' grain streaks: (x from the crate's left, y from the front's top, length).
const GRAIN: Array[Vector3] = [
	Vector3(22, 5, 14),
	Vector3(70, 13, 10),
	Vector3(118, 6, 18),
	Vector3(176, 12, 12),
	Vector3(40, 26, 16),
	Vector3(96, 31, 9),
	Vector3(150, 27, 20),
	Vector3(204, 32, 10),
	Vector3(18, 41, 14),
	Vector3(168, 43, 18)
]
## A glyph chip's tile and pitch on the crate's front (art px).
const CHIP := 12
const CHIP_PITCH := 14
## The ticker while OPEN STORE waits for KEEP.
const HINT := "KEEP OR SWAP YOUR REGULARS"


## Whether the SWAP key shows: a swap unlocked for the profile, and no tutorial lock on it.
static func swap_shown(page: BuildPage) -> bool:
	if page.run == null or page.profile == null:
		return false
	if StartBoardActions.is_locked(page.actions, TutorialAnchors.SWAP_KEY):
		return false
	return StartSetupRules.swap_limit(page.run, page.profile) > 0


## KEEP's rect: centred under the crate (the SWAP key, when it shows, stands left of it).
static func keep_rect(_page: BuildPage) -> Rect2i:
	return KEEP_RECT


## Slot `k`'s centre x of `count` regulars across the crate.
static func slot_cx(k: int, count: int) -> float:
	var inner: float = BOX.size.x - 16.0
	return BOX.position.x + 8.0 + inner * (k + 0.5) / maxi(1, count)


static func draw(pen: ArtPen, page: BuildPage) -> void:
	var x: float = BOX.position.x
	var w: float = BOX.size.x
	pen.nine(BuildPageDraw.SIGN, x + w / 2.0 - 62, SIGN_Y, 124, 14, Vector4i(3, 3, 3, 3))
	pen.chunky(
		"YOUR REGULARS", x + w / 2.0, SIGN_Y + 3, Palette.CREAM, 1.0, HORIZONTAL_ALIGNMENT_CENTER
	)
	_shelf(pen, x, w)
	_back(pen, x, w)
	var cards: Array[CardDefinition] = page.regulars
	for k: int in cards.size():
		var texture: Texture2D = BoosterChromeDraw.sprite(cards[k])
		if texture == null:
			continue
		var size: Vector2 = texture.get_size()
		var cx: float = slot_cx(k, cards.size())
		pen.tex(texture, roundf(cx - size.x / 2.0), roundf(FRONT_TOP + 6 - size.y))
	_front(pen, x, w)
	for k: int in cards.size():
		_chips(pen, cards[k], slot_cx(k, cards.size()))
	if page.regulars_pending() and not page.pins_open and not page.pins_pending():
		if not page.rm and int(floorf(page.now * 2.5)) % 2 == 1:
			var gx: float = x - 3
			var gy: float = BACK_TOP - 3
			var gw: float = w + 6
			var gh: float = FRONT_BOTTOM - BACK_TOP + 6
			pen.r(gx, gy, gw, 1, Palette.GOLD)
			pen.r(gx, gy + gh - 1, gw, 1, Palette.GOLD)
			pen.r(gx, gy, 1, gh, Palette.GOLD)
			pen.r(gx + gw - 1, gy, 1, gh, Palette.GOLD)


## The wall shelf the crate stands on (v1.45 polish, the 2026-11-19 play test: the crate floated):
## a plank on two steel brackets bolted to the lockers, the crate's cast shadow on the lockers
## (light from the upper left) and its contact shadow on the plank's top.
static func _shelf(pen: ArtPen, x: float, w: float) -> void:
	var left: float = x - SHELF_LIP
	var sw: float = w + 2 * SHELF_LIP
	var top: float = FRONT_BOTTOM - SHELF_TOP
	var face: float = FRONT_BOTTOM
	pen.d(x + w, BACK_TOP + 4, 4, face - BACK_TOP - 4, Palette.INK, 8)
	pen.d(left + 3, face + SHELF_FACE, sw, 4, Palette.INK, 8)
	for bx: float in [x + 4, x + w - 12]:
		_bracket(pen, bx, face + SHELF_FACE)
	pen.r(left, top, sw, SHELF_TOP + SHELF_FACE + 1, Palette.INK)
	pen.r(left + 1, top + 1, sw - 2, SHELF_TOP - 1, Palette.WOOD_LIGHT)
	pen.r(left + 1, face, sw - 2, 1, Palette.WOOD_PALE)
	pen.r(left + 1, face + 1, sw - 2, SHELF_FACE - 1, Palette.WOOD)
	pen.r(left + 1, face + SHELF_FACE - 1, sw - 2, 1, Palette.WOOD_DARK)
	pen.r(x + w, top + 1, SHELF_LIP - 1, SHELF_TOP - 1, Palette.WOOD_DARK)
	pen.r(x + 2, face + 1, w - 2, 1, Palette.WOOD_DARK)
	for gx: float in [left + 14, left + 61, left + 130, left + 197]:
		pen.r(gx, face + 3, 9, 1, Palette.WOOD_DARK)


## A steel shelf bracket seen edge-on under the shelf at `bx`, from `top` down: a top plate under
## the plank, the arm tapering down the lockers with its screw, and its shadow on the lockers.
static func _bracket(pen: ArtPen, bx: float, top: float) -> void:
	pen.d(bx + 6, top + 2, 2, BRACKET_H - 4, Palette.INK, 8)
	pen.r(bx, top, 8, 3, Palette.INK)
	pen.r(bx + 1, top, 6, 2, Palette.STEEL)
	pen.r(bx + 1, top, 6, 1, Palette.STEEL_LIGHT)
	pen.r(bx + 2, top + 2, 4, BRACKET_H - 6, Palette.INK)
	pen.r(bx + 3, top + 2, 2, BRACKET_H - 7, Palette.STEEL)
	pen.r(bx + 3, top + 2, 1, BRACKET_H - 7, Palette.STEEL_LIGHT)
	pen.r(bx + 3, top + BRACKET_H - 4, 2, 4, Palette.INK)
	pen.r(bx + 3, top + 6, 2, 2, Palette.STEEL_DARKEST)
	pen.r(bx + 3, top + 6, 1, 1, Palette.STEEL_HIGHLIGHT)


## The crate's inside behind the items: slatted back boards with gaps, the back rim's lit top edge,
## the lit left inner side and the shaded right one, and the end posts rising behind the front.
static func _back(pen: ArtPen, x: float, w: float) -> void:
	var h: float = FRONT_BOTTOM - BACK_TOP
	pen.r(x, BACK_TOP, w, h, Palette.INK)
	pen.r(x + 1, BACK_TOP + 1, w - 2, h - 2, Palette.WOOD_DARKEST)
	var slat_y: float = BACK_TOP + 4
	while slat_y < FRONT_TOP:
		pen.r(x + 8, slat_y, w - 16, SLAT_H, Palette.WOOD_DARK)
		pen.r(x + 8, slat_y, w - 16, 1, Palette.BROWN_DARK)
		slat_y += SLAT_H + 2
	pen.d(x + 8, BACK_TOP + 4, w - 16, 6, Palette.INK, 6)
	pen.r(x + 1, BACK_TOP + 1, w - 2, 3, Palette.WOOD)
	pen.r(x + 1, BACK_TOP + 1, w - 2, 1, Palette.WOOD_PALE)
	pen.r(x + 1, BACK_TOP + 3, w - 2, 1, Palette.WOOD_DARK)
	pen.r(x + 1, BACK_TOP + 4, 7, FRONT_TOP - BACK_TOP - 4, Palette.WOOD)
	pen.r(x + 7, BACK_TOP + 4, 1, FRONT_TOP - BACK_TOP - 4, Palette.WOOD_DARK)
	pen.r(x + w - 8, BACK_TOP + 4, 7, FRONT_TOP - BACK_TOP - 4, Palette.WOOD_DARK)
	pen.d(x + w - 8, BACK_TOP + 4, 7, FRONT_TOP - BACK_TOP - 4, Palette.INK, 6)


## The crate's wooden front, over the items' feet: two planks with a seam and grain, a lit top
## edge, end posts with darker end grain and nails, and steel corner braces.
static func _front(pen: ArtPen, x: float, w: float) -> void:
	var h: float = FRONT_BOTTOM - FRONT_TOP
	pen.r(x, FRONT_TOP, w, h, Palette.INK)
	pen.r(x + 1, FRONT_TOP + 1, w - 2, h - 2, Palette.WOOD)
	pen.r(x + 1, FRONT_TOP + 1, w - 2, 1, Palette.WOOD_PALE)
	pen.r(x + 1, FRONT_TOP + 2, w - 2, 1, Palette.WOOD_LIGHT)
	pen.r(x + 1, SEAM_Y, w - 2, 1, Palette.WOOD_DARKEST)
	pen.r(x + 1, SEAM_Y + 1, w - 2, 1, Palette.WOOD_LIGHT)
	pen.r(x + 1, SEAM_Y - 1, w - 2, 1, Palette.WOOD_DARK)
	pen.r(x + 1, FRONT_TOP + h - 3, w - 2, 2, Palette.WOOD_DARK)
	for g: Vector3 in GRAIN:
		pen.r(x + g.x, FRONT_TOP + g.y, g.z, 1, Palette.WOOD_DARK)
	for px: float in [x + 1, x + w - 8]:
		pen.r(px, FRONT_TOP + 1, 7, h - 2, Palette.WOOD_DARK)
		pen.r(px, FRONT_TOP + 1, 1, h - 2, Palette.WOOD)
		pen.r(px + 6, FRONT_TOP + 1, 1, h - 2, Palette.WOOD_DARKEST)
		pen.r(px, FRONT_TOP + 1, 7, 1, Palette.WOOD_LIGHT)
		for ny: float in [FRONT_TOP + 6, SEAM_Y + 6]:
			pen.r(px + 3, ny, 1, 1, Palette.STEEL_LIGHT)
			pen.r(px + 3, ny + 1, 1, 1, Palette.WOOD_DARKEST)
	_braces(pen, x, w, h)


## Steel L braces on the front's four corners, each with a nail.
static func _braces(pen: ArtPen, x: float, w: float, h: float) -> void:
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var bx: float = x + 1 if corner.x == 0 else x + w - 1 - BRACE
		var by: float = FRONT_TOP + 1.0 if corner.y == 0 else FRONT_TOP + h - 4
		var vy: float = FRONT_TOP + 1.0 if corner.y == 0 else FRONT_TOP + h - 1 - BRACE
		var vx: float = bx if corner.x == 0 else x + w - 4
		pen.r(bx, by, BRACE, 3, Palette.STEEL_DARK)
		pen.r(vx, vy, 3, BRACE, Palette.STEEL_DARK)
		pen.r(bx, by, BRACE, 1, Palette.STEEL_LIGHT)
		pen.r(vx, vy, 1, BRACE, Palette.STEEL)
		pen.r(vx + 1, by + 1, 1, 1, Palette.STEEL_HIGHLIGHT)


## A regular's family glyphs on the crate's front, centred under it (as on the booster cards).
static func _chips(pen: ArtPen, card: CardDefinition, cx: float) -> void:
	var styles: Array[FamilyStyle] = CartCardDraw.chip_families(card)
	styles = styles.slice(0, BoosterArt.MAX_CHIPS)
	var total: float = styles.size() * CHIP_PITCH - (CHIP_PITCH - CHIP)
	var left: float = roundf(cx - total / 2.0)
	var top: float = FRONT_TOP + 8
	for k: int in styles.size():
		var x0: float = left + k * CHIP_PITCH
		pen.r(x0, top, CHIP, CHIP, Palette.INK)
		pen.r(x0 + 1, top + 1, CHIP - 2, CHIP - 2, styles[k].face)
		pen.r(x0 + 1, top + 1, CHIP - 2, 1, styles[k].light)
		if styles[k].glyph != null:
			pen.tex(styles[k].glyph, x0 + 2, top + 2)


## SWAP (the plate on the crate's front) and KEEP (lit while OPEN STORE waits for it; KEPT once
## pressed). Drawn on the floor layer, over the room.
static func draw_keys(pen: ArtPen, page: BuildPage) -> void:
	if swap_shown(page):
		_swap_key(pen, page)
	var live: bool = page.regulars_pending() and not page.pins_pending()
	BuildPageDraw.key_button(
		pen,
		page,
		Rect2(keep_rect(page)),
		"KEEP" if page.regulars_pending() else "KEPT",
		"THESE REGULARS" if page.regulars_pending() else "REGULARS OK",
		live,
		KEEP_ID,
		page.page_t + 0.3 if live else INF
	)


## The SWAP plate screwed on the crate's front: an ink outline over a dark drop shadow, a pale
## wooden face (lit top, shaded foot), four screws and the brand burned dead centre. Hovered, it
## lifts 1 art px, turns dark with the brand's arrows gold, in a gold dashed ring; with no swap
## left it stays clickable (the undo) but dims: a darker face and the dim brand.
static func _swap_key(pen: ArtPen, page: BuildPage) -> void:
	var left: int = StartSetupRules.swaps_left(page.run, page.profile)
	var hv: bool = page.is_hovered(ID)
	var x: float = SWAP_RECT.position.x
	var w: float = SWAP_RECT.size.x
	var h: float = SWAP_RECT.size.y
	var base: float = SWAP_RECT.position.y
	var y: float = base - (1 if hv and not page.rm else 0)
	pen.r(x + 1, base + 1, w, h, Palette.WOOD_DARKEST)
	pen.r(x, y, w, h, Palette.INK)
	var face: Color = Palette.WOOD_PALE
	var top: Color = Palette.CREAM
	var foot: Color = Palette.WOOD_LIGHT
	if hv:
		face = Palette.WOOD_DARK
		top = Palette.WOOD
		foot = Palette.WOOD_DARKEST
	elif left <= 0:
		face = Palette.WOOD
		top = Palette.WOOD_LIGHT
		foot = Palette.WOOD_DARK
	pen.r(x + 1, y + 1, w - 2, h - 2, face)
	pen.r(x + 1, y + 1, w - 2, 1, top)
	pen.r(x + 1, y + h - 2, w - 2, 1, foot)
	var screws: Array[Vector2] = [
		Vector2(2, 2), Vector2(w - 3, 2), Vector2(2, h - 4), Vector2(w - 3, h - 4)
	]
	for corner: Vector2 in screws:
		pen.r(x + corner.x, y + corner.y, 1, 1, Palette.STEEL_LIGHT)
		pen.r(x + corner.x, y + corner.y + 1, 1, 1, Palette.STEEL_DARKEST)
	var brand: Texture2D = BRAND_HOT if hv else (BRAND if left > 0 else BRAND_OFF)
	pen.tex(
		brand, x + floorf((w - brand.get_width()) / 2.0), y + floorf((h - brand.get_height()) / 2.0)
	)
	if hv:
		var phase: int = 0 if page.rm else int(floorf(page.now / 0.12)) % 2
		SwapWindowDraw.dashes(pen, Rect2(x - 2, y - 2, w + 4, h + 4), Palette.GOLD, phase)


## The SWAP key's hover tip (a StartTips entry list; none while the key hides).
static func tip_entries(page: BuildPage) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if page.run == null or not swap_shown(page):
		return list
	var left: int = StartSetupRules.swaps_left(page.run, page.profile)
	var live: String = SWAP_TIP_LEFT % left if left > 0 else SWAP_TIP_UNDO
	list.append(StartTips.entry_of(Rect2(SWAP_RECT), "swap|%s" % live, swap_spec.bind(live)))
	return list


## The SWAP key's tip: SWAP, what it does, and `live` (the swaps left, or the undo).
static func swap_spec(live: String) -> TipSpec:
	var spec: TipSpec = TipSpec.make(TipSpec.Kind.WORD, SWAP_TIP_TITLE, SWAP_TIP_BODY)
	spec.tag = "YOUR REGULARS"
	spec.live = live
	spec.source = spec.plain()
	return spec


## The crate's hits: SWAP while it shows, KEEP while it waits.
static func hits(page: BuildPage, list: Array[Dictionary]) -> void:
	if swap_shown(page):
		list.append({"rect": Rect2(SWAP_RECT), "id": ID, "act": page.swap_pressed.emit})
	if page.regulars_pending() and not page.pins_pending():
		list.append(
			{"rect": Rect2(keep_rect(page)), "id": KEEP_ID, "act": page.keep_regulars.bind("click")}
		)
