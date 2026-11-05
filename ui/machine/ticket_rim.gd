class_name TicketRim
extends RefCounted
## A prize ticket's sheen timing, corner glints and pick rim (C2, v0.98, mock-up
## docs/art/mockups/machine_relook_v2.html and _v3.html), kept out of PrizeTicket so it stays
## under gdlint's file length. Pure statics: PrizeTicket and its CardFoil use them.
## - The sheen (RARE and LEGENDARY): crosses the card once on landing (SHEEN_LAND_S), then every
##   SHEEN_PERIOD seconds (SHEEN_S), staggered per ticket; since v0.99 it is the card foil's sweep
##   (CardFoil), under the art and the words.
## - The corner glints: RARE's two (top left, bottom right, 5x5 art px), LEGENDARY's four (7x7),
##   twinkling every GLINT_S (always on under reduced motion).
## Under reduced motion the sheen never crosses. COMMON has neither. The picked ticket wears a 4 px
## gold rim (PICK_RINGS). The C2 rim and chase lights behind RARE and LEGENDARY tickets went in
## v0.99: the card itself carries its rarity (CardFoil, look B's foil).

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
## The picked ticket's gold rim: ink, gold, ink, grown this far round the ticket.
const PICK_RINGS: Array[float] = [8.0, 6.0, 2.0]


## How far the sheen has crossed (0 .. 1) `since` seconds after landing at `idle` (the machine's
## idle time) on ticket `index`, or -1 when it isn't crossing.
static func sheen_at(rarity: int, since: float, idle: float, rm: bool, index: int = 0) -> float:
	if rm or rarity <= MachinePrize.Rarity.COMMON or since < 0.0:
		return -1.0
	if since < SHEEN_LAND_S:
		return since / SHEEN_LAND_S
	var phase: float = fposmod(idle + index * SHEEN_STAGGER, SHEEN_PERIOD[rarity]) / SHEEN_S
	return phase if phase < 1.0 else -1.0


## The picked ticket's gold rim behind it.
static func draw_pick(item: CanvasItem, ticket_size: Vector2) -> void:
	var face: Rect2 = Rect2(Vector2.ZERO, ticket_size)
	item.draw_rect(face.grow(PICK_RINGS[0]), Palette.INK)
	item.draw_rect(face.grow(PICK_RINGS[1]), Palette.GOLD)
	item.draw_rect(face.grow(PICK_RINGS[2]), Palette.INK)


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
