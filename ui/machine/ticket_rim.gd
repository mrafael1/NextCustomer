class_name TicketRim
extends RefCounted
## A prize ticket's rarity rim, chase lights, sheen and corner glints (C2, v0.96, mock-up
## docs/art/mockups/machine_relook_v2.html and _v3.html), kept out of PrizeTicket so it stays
## under gdlint's file length. Pure statics: PrizeTicket draws them on its layers.
## - The rim (RARE and LEGENDARY): a hard pixel band RIM_WIDTH wide, RIM_GAP + RIM_WIDTH round the
##   ticket (grown RIM_AT), its corners notched; a LEGENDARY ticket adds a thin outer line at
##   OUTER_AT. The rim pulses in two steps (PULSE_S: its tier's face and light swap).
## - The chase lights: CHASE_COUNT segments, CHASE_LEN long, run round the rim's middle line at
##   CHASE_SPEED px a second, each a run of 2 art px squares, light at its ends and paper inside.
## - The sheen: a SHEEN_WIDTH band at 45° crosses the face once on landing (SHEEN_LAND_S), then
##   every SHEEN_PERIOD seconds (SHEEN_S), paper (a LEGENDARY ticket's repeat mustard pale).
## - The corner glints: RARE's two (top left, bottom right, 5x5 art px), LEGENDARY's four (7x7),
##   twinkling every GLINT_S (always on under reduced motion).
## Under reduced motion the rim keeps its face colour, the chase holds still and the sheen never
## crosses. COMMON has none of them. The picked ticket's 4 px gold rim (PICK_RINGS) replaces it.

const RIM_GAP := 2.0
const RIM_WIDTH := 4.0
const RIM_AT := 6.0
const OUTER_AT := 10.0
const OUTER_WIDTH := 2.0
const NOTCH := 2.0
const PULSE_S: Array[float] = [0.0, 0.7, 0.5]
const CHASE_LEN := 16.0
const CHASE_COUNT: Array[int] = [0, 3, 5]
const CHASE_SPEED: Array[float] = [0.0, 120.0, 180.0]
const SHEEN_WIDTH := 10.0
const SHEEN_ALPHA := 0.55
const SHEEN_LAND_S := 0.45
const SHEEN_S := 0.45
const SHEEN_PERIOD: Array[float] = [0.0, 3.2, 2.2]
## Each ticket's repeat sheen is offset by this much a ticket, so the row's don't cross together.
const SHEEN_STAGGER := 0.6
const GLINT_S := 0.4
const SMALL_GLINT: Array[String] = ["..#..", "..#..", "#####", "..#..", "..#.."]
const BIG_GLINT: Array[String] = [
	"...#...", "...#...", "..###..", "#######", "..###..", "...#...", "...#..."
]
## Each tier's rim colours: [face, light, dark] (COMMON: none).
const TIERS: Array[Array] = [
	[],
	[Palette.TEAL_BRIGHT, Palette.TEAL_PALE, Palette.TEAL],
	[Palette.GOLD, Palette.MUSTARD_PALE, Palette.MUSTARD_DARK],
]
## The picked ticket's gold rim: ink, gold, ink, grown this far round the ticket.
const PICK_RINGS: Array[float] = [8.0, 6.0, 2.0]


## The rim's bars round a ticket of `ticket_size` for `rarity` (none for COMMON): the rim's four
## bars (notched corners), then a LEGENDARY ticket's outer line's.
static func rim_rects(rarity: int, ticket_size: Vector2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if rarity <= MachinePrize.Rarity.COMMON:
		return rects
	rects.append_array(_bars(ticket_size, RIM_AT, RIM_WIDTH))
	if rarity == MachinePrize.Rarity.LEGENDARY:
		rects.append_array(_bars(ticket_size, OUTER_AT, OUTER_WIDTH))
	return rects


## The chase lights' squares' top lefts (2 art px each) at `time` (held at 0 under reduced
## motion) round a ticket of `ticket_size`.
static func chase_points(
	rarity: int, time: float, rm: bool, ticket_size: Vector2
) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if rarity <= MachinePrize.Rarity.COMMON:
		return points
	var p: float = MachineArt.PIXEL
	var w: float = ticket_size.x + 2.0 * RIM_AT - 2.0 * p
	var h: float = ticket_size.y + 2.0 * RIM_AT - 2.0 * p
	var length: float = 2.0 * (w + h)
	var count: int = CHASE_COUNT[rarity]
	var travelled: float = 0.0 if rm else time * CHASE_SPEED[rarity]
	for segment: int in range(count):
		var base: float = travelled + segment * length / count
		var step: float = 0.0
		while step < CHASE_LEN:
			points.append(_round(base + step, w, h, length) - Vector2(RIM_AT, RIM_AT))
			step += p
	return points


## How far the sheen has crossed (0 .. 1) `since` seconds after landing at `idle` (the machine's
## idle time) on ticket `index`, or -1 when it isn't crossing.
static func sheen_at(rarity: int, since: float, idle: float, rm: bool, index: int = 0) -> float:
	if rm or rarity <= MachinePrize.Rarity.COMMON or since < 0.0:
		return -1.0
	if since < SHEEN_LAND_S:
		return since / SHEEN_LAND_S
	var phase: float = fposmod(idle + index * SHEEN_STAGGER, SHEEN_PERIOD[rarity]) / SHEEN_S
	return phase if phase < 1.0 else -1.0


## The rim and the chase lights behind a ticket of `ticket_size` on `item`, `idle` seconds in.
static func draw_back(
	item: CanvasItem, rarity: int, idle: float, rm: bool, ticket_size: Vector2
) -> void:
	if rarity <= MachinePrize.Rarity.COMMON:
		return
	var tier: Array = TIERS[rarity]
	var pulse: bool = not rm and int(floorf(idle / PULSE_S[rarity])) % 2 == 1
	var rects: Array[Rect2] = rim_rects(rarity, ticket_size)
	for index: int in range(rects.size()):
		var outer: bool = index >= 4
		var colour: Color = tier[0]
		if outer:
			colour = tier[0] if pulse else tier[2]
		elif pulse:
			colour = tier[1]
		item.draw_rect(rects[index], colour)
	var p: float = MachineArt.PIXEL
	var points: Array[Vector2] = chase_points(rarity, idle, rm, ticket_size)
	var per: int = int(CHASE_LEN / p)
	for index: int in range(points.size()):
		var step: int = index % per
		var end: bool = step < 2 or step > per - 3
		var square: Rect2 = Rect2(points[index], Vector2(2.0 * p, 2.0 * p))
		item.draw_rect(square, tier[1] if end else Palette.PAPER)


## The picked ticket's gold rim behind it.
static func draw_pick(item: CanvasItem, ticket_size: Vector2) -> void:
	var face: Rect2 = Rect2(Vector2.ZERO, ticket_size)
	item.draw_rect(face.grow(PICK_RINGS[0]), Palette.INK)
	item.draw_rect(face.grow(PICK_RINGS[1]), Palette.GOLD)
	item.draw_rect(face.grow(PICK_RINGS[2]), Palette.INK)


## The sheen over the ticket's face at `k` (0 .. 1 across), in `colour`, clipped to the face.
static func draw_sheen(item: CanvasItem, k: float, colour: Color, ticket_size: Vector2) -> void:
	if k < 0.0:
		return
	var p: float = MachineArt.PIXEL
	var w: float = ticket_size.x
	var h: float = ticket_size.y
	var start: float = MachineArt.snap(-h + k * (w + 2.0 * h))
	var tint: Color = Color(colour, SHEEN_ALPHA)
	var y: float = 0.0
	while y < h:
		var left: float = maxf(start + y, 0.0)
		var right: float = minf(start + y + SHEEN_WIDTH, w)
		if right > left:
			item.draw_rect(Rect2(left, y, right - left, p), tint)
		y += p


## The corner glints round a ticket of `ticket_size`, twinkling on `idle`.
static func draw_glints(
	item: CanvasItem, rarity: int, idle: float, rm: bool, ticket_size: Vector2
) -> void:
	if rarity <= MachinePrize.Rarity.COMMON:
		return
	var p: float = MachineArt.PIXEL
	var w: float = ticket_size.x
	var h: float = ticket_size.y
	var corners: Array[Vector2] = [Vector2(-5, -5), Vector2(w + 5, h + 5)]
	var pattern: Array[String] = SMALL_GLINT
	if rarity == MachinePrize.Rarity.LEGENDARY:
		corners = [Vector2(-5, -5), Vector2(w + 5, -5), Vector2(w + 5, h + 5), Vector2(-5, h + 5)]
		pattern = BIG_GLINT
	for index: int in range(corners.size()):
		var at: Vector2 = MachineArt.snap_point(corners[index])
		var on: bool = rm or int(floorf(idle / GLINT_S + index * 1.5)) % 3 != 0
		if not on:
			item.draw_rect(Rect2(at - Vector2(p, p) / 2.0, Vector2(p, p)), Palette.PAPER)
			continue
		var half: float = floorf(pattern.size() / 2.0) * p
		for y: int in range(pattern.size()):
			for x: int in range(pattern[y].length()):
				if pattern[y][x] == "#":
					var cell: Vector2 = at - Vector2(half, half) + Vector2(x, y) * p
					item.draw_rect(Rect2(cell, Vector2(p, p)), Palette.PAPER)


## The four bars of a rim `at` px round the ticket, `width` thick, its corners notched.
static func _bars(ticket_size: Vector2, at: float, width: float) -> Array[Rect2]:
	var outer: Rect2 = Rect2(Vector2.ZERO, ticket_size).grow(at)
	var n: float = NOTCH
	return [
		Rect2(outer.position.x + n, outer.position.y, outer.size.x - 2.0 * n, width),
		Rect2(outer.position.x + n, outer.end.y - width, outer.size.x - 2.0 * n, width),
		Rect2(outer.position.x, outer.position.y + n, width, outer.size.y - 2.0 * n),
		Rect2(outer.end.x - width, outer.position.y + n, width, outer.size.y - 2.0 * n),
	]


## The point `along` px round a w x h loop from its top left, clockwise (its middle line).
static func _round(along: float, w: float, h: float, length: float) -> Vector2:
	var d: float = fposmod(along, length)
	if d < w:
		return Vector2(d, 0)
	d -= w
	if d < h:
		return Vector2(w, d)
	d -= h
	if d < w:
		return Vector2(w - d, h)
	d -= w
	return Vector2(0, h - d)
