class_name GoldPaperArt
extends RefCounted
## The gold receipt's material (2026-11-05, the user's "it should feel golden like the previous
## text box"): the PREMIUM / PAYDAY NEXT announce's gold slip (PremiumAnnounce) drawn over a
## receipt's paper, under its ink. Its face is the slip's gold with a darker brass edge and a
## brass trim inside it, the slip's pale highlight along its top with a light dither under it and a
## dark dither over its foot (the shading), a pixel star (the announce's) in each top corner, a
## glint sweeping across it every SHINE_PERIOD (PremiumAnnounce's tag's) and, as it turns gold, a
## few sparkles round its edge. ReceiptGold draws it on the paper's own canvas (under its lines),
## `k` of the way in (its fade). The SILVER receipt (the overtime ticket's ×2, 2026-11-05 review:
## "x2 bonus ticket should transform receipt to silver") is the same material in Palette's steels
## (`silver`: SILVER's face, edge, trim, highlight, dithers and star). While planning's projection
## would spend a week medal (2026-11-06) only the paper's edges glow faintly in its metal
## (draw_glow). Display only.

const FACE := Palette.GOLD
const EDGE := Palette.BRASS_DARKEST
const TRIM := Palette.BRASS
const HIGHLIGHT := Palette.MUSTARD_PALE
const LIGHT_DITHER := Palette.MUSTARD_LIGHT
const DARK_DITHER := Palette.MUSTARD_DARK
const STAR := Palette.BRASS_DARK
## The silver material, in GOLD's order: face, edge, trim, highlight, light dither, dark dither,
## star.
## Its face is the lightest steel, so every ink keeps 3:1 or more on it as on the gold (the mid
## steel left the dark green and teal under it); the steel edge, trim, dithers and stars make it
## silver.
const SILVER: Array[Color] = [
	Palette.STEEL_HIGHLIGHT,
	Palette.STEEL_DARKEST,
	Palette.STEEL,
	Palette.PAPER,
	Palette.STEEL_LIGHT,
	Palette.STEEL_PALE,
	Palette.STEEL_SHADE,
]
const GOLD: Array[Color] = [FACE, EDGE, TRIM, HIGHLIGHT, LIGHT_DITHER, DARK_DITHER, STAR]
## The announce's glint: every SHINE_PERIOD, SHINE_LENGTH long, after SHINE_DELAY; a paper band
## GLINT_BAND art px wide, at most GLINT_ALPHA (it passes under the ink).
const SHINE_PERIOD := PremiumAnnounce.SHINE_PERIOD
const SHINE_LENGTH := 0.7
const SHINE_DELAY := 0.4
const GLINT_BAND := 6.0
const GLINT_ALPHA := 0.55
## The sparkles as the paper turns gold: SPARKLE_SECONDS long, at these spots (shares of the paper)
## each SPARKLE_STAGGER after the one before.
const SPARKLE_SECONDS := 1.2
const SPARKLE_STAGGER := 0.12
const SPARKLE_SPOTS: Array[Vector2] = [
	Vector2(0.08, 0.04),
	Vector2(0.92, 0.1),
	Vector2(0.03, 0.42),
	Vector2(0.97, 0.55),
	Vector2(0.12, 0.93),
	Vector2(0.88, 0.97),
]
## The star in each top corner: STAR_INSET art px in from the trim, its centre STAR_DROP down.
const STAR_INSET := 5.0
const STAR_DROP := 5.0
## The shading's dither: DITHER_ROWS art px rows under the highlight and over the foot's trim.
const DITHER_ROWS := 2
## The pending glow (draw_glow): the edge in the metal's trim at GLOW_EDGE_ALPHA, two rings of its
## face inside it fading, a paper glint GLOW_RUN_LENGTH art px long at GLOW_RUN_ALPHA going round
## every GLOW_RUN_PERIOD seconds.
const GLOW_EDGE_ALPHA := 0.85
const GLOW_INNER_ALPHA := 0.45
const GLOW_RUN_LENGTH := 14.0
const GLOW_RUN_ALPHA := 0.8
const GLOW_RUN_PERIOD := 2.4
## The silver glow's own steels (its face is near the paper's white, so its rings would not show):
## a darker steel edge, then mid steel rings, one ring wider than the gold's.
const SILVER_GLOW: Array[Color] = [Palette.STEEL_SHADE, Palette.STEEL_PALE, Palette.STEEL_LIGHT]
const GLOW_WIDE_ALPHA := 0.3


## The gold (`silver`: the silver) over `rect` of `item`, `k` (0 .. 1) of the way in; the glint at
## `shine` (0 .. 1 across; none outside) and the sparkles `sparkle` seconds after it turned gold
## (none below 0).
static func draw(
	item: CanvasItem, rect: Rect2, k: float, shine: float, sparkle: float, silver: bool = false
) -> void:
	if k <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var metal: Array[Color] = SILVER if silver else GOLD
	var p: float = MachineArt.PIXEL
	MachineArt.box(item, rect, _faded(metal[0], k), _faded(metal[1], k))
	var inner: Rect2 = rect.grow(-p)
	MachineArt.ring(item, inner, _faded(metal[2], k))
	var face: Rect2 = inner.grow(-p)
	item.draw_rect(Rect2(face.position, Vector2(face.size.x, p)), _faded(metal[3], k))
	var rows: float = DITHER_ROWS * p
	_dither(item, Rect2(face.position.x, face.position.y + p, face.size.x, rows), metal[4], k)
	_dither(item, Rect2(face.position.x, face.end.y - rows, face.size.x, rows), metal[5], k)
	for x: float in [face.position.x + STAR_INSET * p, face.end.x - STAR_INSET * p]:
		_star(item, Vector2(x, face.position.y + STAR_DROP * p), _faded(metal[6], k))
	if shine > 0.0 and shine < 1.0:
		var glint: Color = Color(Palette.PAPER, GLINT_ALPHA * k)
		MachineArt.shine(item, face, shine, glint, GLINT_BAND)
	if sparkle < 0.0:
		return
	for index: int in SPARKLE_SPOTS.size():
		var age: float = (sparkle - index * SPARKLE_STAGGER) / (SPARKLE_SECONDS * 0.6)
		if age <= 0.0 or age >= 1.0:
			continue
		var at: Vector2 = rect.position + rect.size * SPARKLE_SPOTS[index]
		MachineArt.sparkle(item, at, 2.0 if age < 0.35 else 1.0, sin(PI * age))


## The pending glow (2026-11-06, the week medals): while planning's projection would spend a
## medal, the paper's edges glow faintly in its metal (`silver`, else gold), `k` (0 .. 1) of the
## way in, a short paper glint running round the edge at `run` (0 .. 1 of the way round, from the
## top left, clockwise; below 0: none). Only the edge: the full metal waits for the checkout. The
## silver's rings are SILVER_GLOW's darker steels, one ring wider, so it shows on the cream.
static func draw_glow(item: CanvasItem, rect: Rect2, k: float, run: float, silver: bool) -> void:
	if k <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var p: float = MachineArt.PIXEL
	var rings: Array[Color] = [GOLD[2], GOLD[0], GOLD[0]]
	if silver:
		rings = [SILVER_GLOW[0], SILVER_GLOW[1], SILVER_GLOW[1], SILVER_GLOW[2]]
	var alphas: Array[float] = [
		GLOW_EDGE_ALPHA, GLOW_INNER_ALPHA, GLOW_INNER_ALPHA * 0.5, GLOW_WIDE_ALPHA
	]
	for index: int in range(rings.size()):
		MachineArt.ring(item, rect.grow(-index * p), Color(rings[index], alphas[index] * k))
	if run < 0.0:
		return
	var glint: Color = Color(Palette.PAPER, GLOW_RUN_ALPHA * k)
	var perimeter: float = 2.0 * (rect.size.x + rect.size.y)
	var steps: int = roundi(GLOW_RUN_LENGTH)
	for step: int in range(steps):
		var along: float = fposmod(run * perimeter + step * p, perimeter)
		var at: Vector2 = _on_edge(rect, along)
		item.draw_rect(Rect2(MachineArt.snap_point(at), Vector2(p, p)), glint)


## The point `along` px round `rect`'s edge from its top left, clockwise (inside the edge's pixel).
static func _on_edge(rect: Rect2, along: float) -> Vector2:
	var p: float = MachineArt.PIXEL
	var w: float = rect.size.x - p
	var h: float = rect.size.y - p
	if along < w:
		return rect.position + Vector2(along, 0.0)
	along -= w
	if along < h:
		return rect.position + Vector2(w, along)
	along -= h
	if along < w:
		return rect.position + Vector2(w - along, h)
	return rect.position + Vector2(0.0, maxf(h - (along - w), 0.0))


## The glint's progress `time` seconds after the paper turned gold (below 0 or 1 and over: none).
static func shine_at(time: float) -> float:
	if time < SHINE_DELAY:
		return -1.0
	return fmod(time - SHINE_DELAY, SHINE_PERIOD) / SHINE_LENGTH


static func _faded(colour: Color, k: float) -> Color:
	return Color(colour, colour.a * clampf(k, 0.0, 1.0))


## A checker of `colour` over `rect`: every other art px, the rows alternating.
static func _dither(item: CanvasItem, rect: Rect2, colour: Color, k: float) -> void:
	var p: float = MachineArt.PIXEL
	var ink: Color = _faded(colour, k)
	var row: int = 0
	var y: float = rect.position.y
	while y < rect.end.y:
		var x: float = rect.position.x + (row % 2) * p
		while x < rect.end.x:
			item.draw_rect(Rect2(x, y, p, p), ink)
			x += 2.0 * p
		y += p
		row += 1


## The announce's 5x5 pixel star centred on `centre`.
static func _star(item: CanvasItem, centre: Vector2, colour: Color) -> void:
	var p: float = MachineArt.PIXEL
	var origin: Vector2 = MachineArt.snap_point(centre - Vector2(5, 5))
	for cell: int in range(25):
		if PremiumAnnounce.STAR_GRID[cell] == "x":
			var at: Vector2 = origin + Vector2(cell % 5, floori(cell / 5.0)) * p
			item.draw_rect(Rect2(at, Vector2(p, p)), colour)
