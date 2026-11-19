class_name AisleBoardDraw
extends RefCounted
## Draws the aisle board (BoosterPage, v1.44) layer by layer in art px, a port of variant A of
## mock-up docs/art/mockups/start_roulette.html: the room, the bays (seven, v1.45) with their
## shutters, padlocks and hung signs (no bulb rims since round 3 of the 2026-11-19 play test: a
## landed bay just stays lit), the running light, the pouches thrown to their rows, the fans, a
## RESTOCK's cards flying back, the full card a hovered compact card pops up, and the keys and
## bars (BoosterChromeDraw). Motion reads the page's clock only.

## The light's first flicker over every open bay as the chase starts (s), a landing's white flash
## and its sign's punch and dip.
const POWER_S := 0.16
const FLASH_S := 0.07
const PUNCH_S := 0.28
const PUNCH_AMP := 0.35
const DIP_S := 0.2
## A bay shakes this long as it throws its booster; a pouch squashes this long as it lands.
const KICK_S := 0.18
const SQUASH_S := 0.12
## How high a thrown pouch's arc rises over its straight path to its row (art px).
const THROW_ARC := 24.0
## A returning card turns over in TURN_S, then flies; the arc's rise (art px).
const TURN_S := 0.12
const RETURN_RISE := 18.0
## The full card a hovered compact card pops up stands this far above the counter's line.
const HOVER_LIFT := 4
## The hovered full card's shadow offset (art px).
const HOVER_SHADOW := Vector2(3, 5)
## A sealed booster waiting for its click: every IDLE_S (each pouch on its own phase) a glint runs
## down it over GLINT_S while it wiggles WIGGLE_PX for WIGGLE_S; hovered, it rises HOVER_RISE art
## px and its sheen sweeps across (the page's pointer is the hand).
const IDLE_S := 2.4
const GLINT_S := 0.5
const WIGGLE_S := 0.32
const WIGGLE_PX := 2.0
const HOVER_RISE := 3


## Draws `layer` of `page`; false when the layer is not the board's (the swap window's).
static func draw(pen: ArtPen, page: BoosterPage, layer: String) -> bool:
	match layer:
		"Back":
			pen.tex(AisleBoardArt.room(), 0, 0)
			for k: int in page.roulette.count:
				_bay(pen, page, k)
		"Light":
			_light(pen, page)
		"Boosters":
			_boosters(pen, page)
		"Front":
			_front(pen, page)
		"Top":
			BoosterChromeDraw.floor_row(pen, page)
			BoosterChromeDraw.top_bar(pen, page)
		_:
			return false
	return true


## Whether the light has landed on bay `k` (one of today's, lit for good).
static func landed(page: BoosterPage, k: int) -> bool:
	var roulette: AisleRoulette = page.roulette
	return roulette.land_t.has(k) and page.now >= roulette.land_t[k]


## Whether bay `k` is lit now: landed, under the running light, or in the chase's first flicker.
static func bay_lit(page: BoosterPage, k: int) -> bool:
	var roulette: AisleRoulette = page.roulette
	if roulette.locked[k]:
		return false
	if landed(page, k) or roulette.chase_bay() == k:
		return true
	var age: float = page.now - roulette.spin_t
	return (
		not page.rm
		and roulette.phase == AisleRoulette.Phase.SPIN
		and age < POWER_S
		and int(floorf(age / 0.04)) % 2 == 0
	)


## A landing's age on bay `k` (s; INF: not landed).
static func _land_age(page: BoosterPage, k: int) -> float:
	return page.now - page.roulette.land_t[k] if landed(page, k) else INF


static func _bay(pen: ArtPen, page: BoosterPage, k: int) -> void:
	var roulette: AisleRoulette = page.roulette
	var aisle: AisleDefinition = page.run.balance.aisles[k]
	var count: int = roulette.count
	var x: float = AisleBoardArt.bay_x(k, count)
	var w: float = AisleBoardArt.bay_w(count)
	var y: float = AisleBoardArt.BAY_Y
	var h: float = AisleBoardArt.BAY_H
	var on: bool = landed(page, k)
	var lit: bool = bay_lit(page, k)
	var light: bool = roulette.chase_bay() == k
	var b: BoosterOpening = roulette.booster_at(k)
	var shake: float = 0.0
	if b != null and not page.rm and b.fly_t != INF:
		var kick: float = page.now - b.fly_t
		if kick >= 0.0 and kick < KICK_S:
			shake = [1.0, -1.0, 1.0, 0.0][int(floorf(kick / 0.045)) % 4]
	pen.r(x + 20, 43, 1, 4, Palette.STEEL_DARK)
	pen.r(x + w - 21, 43, 1, 4, Palette.STEEL_DARK)
	pen.tex(AisleBoardArt.bay(aisle, int(w), lit), x + shake, y)
	var frac: float = roulette.shut_frac(k)
	_shutter(pen, x, w, frac, light)
	if roulette.locked[k]:
		pen.tex(BoosterArt.PADLOCK, x + w / 2.0 - 4, y + AisleBoardArt.PADLOCK_DY)
	var age: float = _land_age(page, k)
	if on:
		if not page.rm and age < FLASH_S:
			pen.r(x, y, w, h, Color(1, 1, 1, 0.75))
	elif light:
		pen.r(x - 2, y - 2, w + 4, 2, Palette.GOLD)
		pen.r(x - 2, y - 2, 2, h + 2, Palette.GOLD)
		pen.r(x + w, y - 2, 2, h + 2, Palette.GOLD)
	var dip: float = 0.0
	var scale: float = 1.0
	if on and not page.rm:
		if age < DIP_S:
			dip = roundf(3 * sin(PI * age / DIP_S))
		if age < PUNCH_S:
			scale = 1.0 + PUNCH_AMP * (1.0 - BoosterPageDraw.e_back(age / PUNCH_S, 2.4))
	_sign(pen, aisle, AisleBoardArt.sign_rect(k, count), dip, scale, not lit)


## Bay shutter, `frac` down (the mock-up's drawShutter): steel slats, a heavier bottom bar with
## its grip; `light`: the running light is on it.
static func _shutter(pen: ArtPen, x: float, w: float, frac: float, light: bool) -> void:
	var full: float = AisleBoardArt.BAY_H - 6
	var h: float = roundf(clampf(frac, 0.0, 1.05) * full)
	if h <= 0.0:
		return
	var y0: float = AisleBoardArt.BAY_Y + 6
	var shown: float = minf(h, full)
	var bottom: float = y0 + shown
	var base: Color = Palette.STEEL if light else Palette.STEEL_DARK
	var low: Color = Palette.STEEL_DARK if light else Palette.STEEL_DARKEST
	var high: Color = Palette.STEEL_LIGHT if light else Palette.STEEL_SHADE
	pen.r(x + 4, y0, w - 8, shown, base)
	var y: float = y0 + h - 13
	while y > y0 - 6:
		if y >= y0 and y + 2 <= bottom:
			pen.r(x + 4, y, w - 8, 1, low)
			pen.r(x + 4, y + 1, w - 8, 1, high)
		y -= 6
	var bar: float = maxf(y0, bottom - 8)
	pen.r(x + 4, bar, w - 8, bottom - bar, low)
	pen.r(x + 4, bar, w - 8, 1, high)
	pen.r(x + 4, bottom - 1, w - 8, 1, Palette.INK)
	if bottom - bar >= 6:
		pen.r(x + w / 2.0 - 8, bottom - 5, 16, 2, high)


## An aisle's hung sign in `rect`, dropped `dip` art px, `scale` times its size about its centre
## (the landing's punch), dimmed while its bay is dark: the aisle's glyph on a paper tile, then
## its name (the glyph is left out when the name needs the room).
static func _sign(
	pen: ArtPen, aisle: AisleDefinition, rect: Rect2, dip: float, scale: float, dim: bool
) -> void:
	var w: float = rect.size.x
	var h: float = rect.size.y
	var saved_origin: Vector2 = pen.origin
	var saved_unit: Vector2 = pen.unit
	var sw: float = roundf(w * scale)
	var sh: float = roundf(h * scale)
	pen.origin = pen.at(
		roundf(rect.position.x + w / 2.0 - sw / 2.0),
		roundf(rect.position.y + dip + h / 2.0 - sh / 2.0)
	)
	pen.unit = saved_unit * Vector2(sw / w, sh / h)
	pen.nine(BoosterArt.sign_frame(aisle.id), 0, 0, w, h, Vector4i(3, 3, 3, 3))
	var label: String = BoosterArt.short_name(aisle)
	var words: float = ArtPen.word_texture(label, Palette.INK, true).get_width()
	var glyph: Texture2D = BoosterArt.glyph(aisle.id)
	var tile: float = 14.0 if glyph != null and words + 14 <= w - 6 else 0.0
	var x0: float = roundf((w - tile - words) / 2.0)
	if tile > 0.0:
		pen.rn(x0, 2, 11, 12, Palette.PAPER)
		pen.tex(glyph, x0 + 1, 3)
	var ink: Color = Palette.INK if BoosterArt.LIGHT_SIGNS.has(aisle.id) else Palette.CREAM
	pen.chunky(label, x0 + tile, 4, ink)
	if dim:
		pen.r(0, 0, w, h, Color(Palette.TEAL_BLACK, 0.6))
	pen.origin = saved_origin
	pen.unit = saved_unit


## The additive light: each lit bay's warm glow.
static func _light(pen: ArtPen, page: BoosterPage) -> void:
	var roulette: AisleRoulette = page.roulette
	var count: int = roulette.count
	var w: float = AisleBoardArt.bay_w(count)
	for k: int in count:
		if not bay_lit(page, k) or roulette.shut_frac(k) > 0.5:
			continue
		var x: float = AisleBoardArt.bay_x(k, count)
		var top: float = AisleBoardArt.BAY_Y + 6
		pen.d(x + 4, top, w - 8, 60, Palette.MUSTARD_DARKEST, 8)
		pen.d(x + 4, top + 60, w - 8, 60, Palette.MUSTARD_DARKEST, 4)
		pen.d(x + 4, top + 120, w - 8, AisleBoardArt.BAY_H - 126, Palette.MUSTARD_DARKEST, 2)


## Inside the counter clip: the settled RARE glows, a RESTOCK's cards flying back, the thrown
## pouches, the opening boosters and the fans.
static func _boosters(pen: ArtPen, page: BoosterPage) -> void:
	for b: BoosterOpening in page.boosters:
		if b.in_row() and page.roulette.landed(b):
			row_tab(pen, b)
	for b: BoosterOpening in page.boosters:
		if b.state == BoosterOpening.State.OPENING or b.state == BoosterOpening.State.OPEN:
			BoosterPageDraw.sun_glows(pen, page, b)
	for b: BoosterOpening in page.boosters:
		if b.state == BoosterOpening.State.SEALED:
			_returning(pen, page, b)
			_thrown(pen, page, b)
		else:
			BoosterPageDraw.open_booster(pen, page, b, b.pouch_clip())


## Booster `b`'s row tab (AisleBoardArt.row_tab_rect): a strip of its aisle's hung sign, standing
## at the row's left end with the aisle's glyph on a paper tile dead centre in it
## (AisleBoardArt.row_tile_rect), so the row reads as that bay's.
static func row_tab(pen: ArtPen, b: BoosterOpening) -> void:
	var r: Rect2 = AisleBoardArt.row_tab_rect(b.row)
	var frame: Texture2D = BoosterArt.sign_frame(b.aisle)
	pen.nine(frame, r.position.x, r.position.y, r.size.x, r.size.y, Vector4i(3, 3, 3, 3))
	var glyph: Texture2D = BoosterArt.glyph(b.aisle)
	if glyph == null:
		return
	var tile: Rect2 = AisleBoardArt.row_tile_rect(b.row)
	pen.rn(tile.position.x, tile.position.y, tile.size.x, tile.size.y, Palette.PAPER)
	pen.tex(
		glyph,
		tile.position.x + floorf((tile.size.x - glyph.get_width()) / 2.0),
		tile.position.y + floorf((tile.size.y - glyph.get_height()) / 2.0)
	)


## A sealed booster: flying from its bay on an arc, growing, to its row's start beside the row's
## aisle tab (BoosterOpening.pouch_pos); then standing there (a squash as it lands) until the
## player opens it, with an idle glint and wiggle while it waits (none under reduced motion) and a
## rise and sweep while hovered.
static func _thrown(pen: ArtPen, page: BoosterPage, b: BoosterOpening) -> void:
	if b.fly_t == INF or page.now < b.fly_t:
		return
	var tuning: StartBoostersTuning = page.tuning
	var age: float = page.now - b.fly_t
	var at: Vector2 = b.pouch_pos()
	var bw: float = BoosterArt.BW
	var bh: float = BoosterArt.BH
	var clip: float = b.pouch_clip()
	if not page.rm and age < tuning.throw_s:
		var u: float = age / maxf(tuning.throw_s, 0.001)
		var s: float = lerpf(0.3, 1.0, u)
		var cx: float = lerpf(b.fly_from.x, at.x + bw / 2.0, u)
		var foot: float = lerpf(b.fly_from.y, at.y + bh, BoosterPageDraw.e_in(u))
		foot -= sin(PI * u) * THROW_ARC
		BoosterPageDraw.pouch(
			pen,
			b.aisle,
			2,
			roundf(cx - bw / 2.0),
			roundf(foot - bh),
			{"w": roundf(bw * s), "h": roundf(bh * s), "clip": clip}
		)
		return
	var o: Dictionary = {"clip": clip}
	var rest: float = age - tuning.throw_s
	var y: float = at.y
	if not page.rm and rest < SQUASH_S:
		var v: float = 1.0 - rest / SQUASH_S
		o["w"] = bw + roundf(6 * v)
		o["h"] = bh - roundf(11 * v)
	elif not page.roulette.busy():
		if page.is_hovered("booster%d" % b.index):
			y -= HOVER_RISE
			if not page.rm:
				o["sheen"] = fmod(page.now - page.hover_t0, 1.2) / GLINT_S
				o["sweep"] = true
		elif not page.rm:
			var cycle: float = fmod(rest + b.index * IDLE_S / 2.0, IDLE_S)
			o["sheen"] = cycle / GLINT_S
			if cycle < WIGGLE_S:
				o["shear"] = WIGGLE_PX if int(cycle / (WIGGLE_S / 4.0)) % 2 == 0 else -WIGGLE_PX
	BoosterPageDraw.pouch(pen, b.aisle, 2, at.x, y, o)


## A RESTOCK's old cards: each turns over where it stood, then flies back into its bay, shrinking.
static func _returning(pen: ArtPen, page: BoosterPage, b: BoosterOpening) -> void:
	if b.return_t == INF or page.rm:
		return
	var tuning: StartBoostersTuning = page.tuning
	var ch: float = b.card_h()
	for k: int in b.old_cards.size():
		var age: float = page.now - b.return_t - k * tuning.restock_flip_s
		var home: Vector2 = b.fan_pos(k)
		var back: BoosterCardDraw.Back = (
			BoosterCardDraw.Back.HIT
			if k < b.old_hits.size() and b.old_hits[k]
			else BoosterCardDraw.Back.PLAIN
		)
		var o: Dictionary = {"compact": b.compact, "still": true, "now": page.now}
		if age < 0.0:
			BoosterCardDraw.draw(pen, b.old_cards[k], false, home.x, home.y, o)
		elif age < TURN_S:
			o["sx"] = absf(1.0 - age / (TURN_S / 2.0))
			if age > TURN_S / 2.0:
				o["back"] = back
			BoosterCardDraw.draw(pen, b.old_cards[k], false, home.x, home.y - 3, o)
		else:
			var u: float = (age - TURN_S) / maxf(tuning.restock_return_s, 0.001)
			if u >= 1.0:
				continue
			var e: float = BoosterPageDraw.e_in(u)
			var cx: float = lerpf(home.x + BoosterArt.CW / 2.0, b.fly_from.x, e)
			var cy: float = lerpf(home.y + ch / 2.0, b.fly_from.y, e) - sin(PI * u) * RETURN_RISE
			o["back"] = back
			o["scale"] = roundf(lerpf(1.0, 0.25, e) * 20.0) / 20.0
			BoosterCardDraw.draw(
				pen, b.old_cards[k], false, cx - BoosterArt.CW / 2.0, cy - ch / 2.0, o
			)


## Over the counter clip: each tear's flash and flying strip, the live RARE suns, RESTOCK's call,
## the particles, the hovered card in full (no counter plates since round 3 of the 2026-11-19
## play test: each row's aisle tab names its aisle).
static func _front(pen: ArtPen, page: BoosterPage) -> void:
	for b: BoosterOpening in page.boosters:
		BoosterPageDraw.tear(pen, page, b)
	for b: BoosterOpening in page.boosters:
		if b.state == BoosterOpening.State.OPENING or b.state == BoosterOpening.State.OPEN:
			BoosterPageDraw.suns_top(pen, page, b)
	BoosterChromeDraw.restock_call(pen, page)
	BoosterPageDraw.parts(pen, page, page.fx.parts)
	hover_card(pen, page)


## The hovered fan card's place {b, k} ({}: none hovered, or the fan shows full cards already).
static func hovered(page: BoosterPage) -> Dictionary:
	if not page.hover_id.begins_with("card"):
		return {}
	for b: BoosterOpening in page.boosters:
		if b.state != BoosterOpening.State.OPEN or not b.compact:
			continue
		for k: int in b.cards.size():
			if page.is_hovered("card%d_%d" % [b.index, k]):
				return {"b": b, "k": k}
	return {}


## Where the full card of booster `b`'s hovered card k pops up: over its compact card, its foot
## HOVER_LIFT above the compact card's foot (its row's, or the counter's line); in the bottom row
## it hangs down from HOVER_LIFT above the compact card's top instead, over the counter, so it
## never hides the top row (round 2 of the 2026-11-19 play test).
static func hover_rect(b: BoosterOpening, k: int) -> Rect2:
	var at: Vector2 = b.fan_pos(k)
	if b.in_row() and b.row == 1:
		return Rect2(at.x, at.y - HOVER_LIFT, BoosterArt.CW, BoosterArt.CH)
	var foot: float = at.y + b.card_h()
	return Rect2(at.x, foot - BoosterArt.CH - HOVER_LIFT, BoosterArt.CW, BoosterArt.CH)


## The hovered full card's drawn rect: hover_rect with its soft shadow (HOVER_SHADOW).
static func hover_drawn_rect(b: BoosterOpening, k: int) -> Rect2:
	var r: Rect2 = hover_rect(b, k)
	return Rect2(r.position, r.size + HOVER_SHADOW)


## The hovered compact card in full (its rule), over a soft shadow.
static func hover_card(pen: ArtPen, page: BoosterPage) -> void:
	var found: Dictionary = hovered(page)
	if found.is_empty():
		return
	var b: BoosterOpening = found.b
	var k: int = found.k
	var r: Rect2 = hover_rect(b, k)
	pen.r(
		r.position.x + HOVER_SHADOW.x,
		r.position.y + HOVER_SHADOW.y,
		r.size.x,
		r.size.y,
		Color(Palette.INK, 0.45)
	)
	BoosterCardDraw.draw(
		pen,
		b.cards[k],
		b.rares[k],
		r.position.x,
		r.position.y,
		{"pop": 2, "now": page.now, "still": page.rm, "hot": true}
	)
