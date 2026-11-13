class_name BoosterPageDraw
extends RefCounted
## Draws YOUR STORE (BoosterPage) layer by layer in art px, a port of the mock-up's drawPage1
## (docs/art/mockups/start_boosters_v3.html): the room and its shelf runs, the lamps with their
## cones and pools, the hung signs and the board, STOCKED!, the boosters (sealed, opening, open)
## and their fans, the RARE suns. The crate, the tray, the counter's keys, the floor row, the
## storefront and the top bar are BoosterChromeDraw's. Motion reads the page's clock only.

## The counter top: what stands on it is clipped here (a pouch drops behind the counter).
const COUNTER_CLIP := 233 + BoosterArt.DY
const CONE_BOTTOM := 229 + BoosterArt.DY
const POUCH_BT := 12
const POUCH_BB := BoosterArt.BH - 8


## Draws `layer` of its page.
static func draw(layer: BoosterLayer) -> void:
	var page: BoosterPage = layer.page
	if page.run == null:
		return
	var pen: ArtPen = layer.pen
	match layer.layer:
		"Back":
			_back(pen, page)
		"Light":
			_light(pen, page)
		"Front":
			_front(pen, page)
		"Boosters":
			_boosters(pen, page)
		"Front2":
			_front_over(pen, page)
		"Tote":
			BoosterChromeDraw.tote(pen, page)
		"Front3":
			BoosterChromeDraw.front_top(pen, page)
			_parts(pen, page)
		"Glow":
			BoosterChromeDraw.crate_glow(pen, page)
		"Pop":
			BoosterChromeDraw.pop(pen, page)
		"Facade":
			BoosterChromeDraw.storefront(pen, page)
		"Top":
			BoosterChromeDraw.top_bar(pen, page)


## The hit list of the page this frame, bottom first (BoosterChromeDraw's).
static func hits(page: BoosterPage) -> Array[Dictionary]:
	return BoosterChromeDraw.hits(page)


static func e_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


static func e_in(t: float) -> float:
	return pow(clampf(t, 0.0, 1.0), 2.0)


static func e_back(t: float, c: float = 1.7) -> float:
	var u: float = clampf(t, 0.0, 1.0)
	return 1.0 + (c + 1.0) * pow(u - 1.0, 3.0) + c * pow(u - 1.0, 2.0)


## `v` in whole steps of `s`.
static func stepped(v: float, s: float) -> float:
	return roundf(v / s) * s


static func aisle_def(page: BoosterPage, id: StringName) -> AisleDefinition:
	for aisle: AisleDefinition in page.run.balance.aisles:
		if aisle.id == id:
			return aisle
	return null


## The lamp of `opening`: 0 off, 1 on, 2 hot, 3 full (the mock-up's lampState).
static func lamp_state(page: BoosterPage, b: BoosterOpening) -> int:
	var now: float = page.now
	if b.lamp_on == INF or now < b.lamp_on:
		return 0
	if b.lamp_off != INF and now >= b.lamp_off:
		var off_u: float = now - b.lamp_off
		# A SOLD OUT lamp stays dark (its sign dimmed) once it starts to pull up into the ceiling.
		if off_u > 0.6 or page.rm or (b.sink_t != INF and now >= b.sink_t):
			return 0
		return 0 if int(floorf(off_u / 0.03)) % 3 else 1
	var u: float = now - b.lamp_on
	var flicker: float = page.tuning.lamp_flicker_s
	if not page.rm and u < flicker * 3:
		return 0 if int(floorf(u / flicker)) == 1 else 1
	if not page.rm and now >= b.lamp_flick and now < b.lamp_flick + 0.25:
		return 0 if int(floorf((now - b.lamp_flick) / 0.05)) % 2 else 1
	if page.complete_t != INF and now >= page.full_at(maxi(0, counted_index(page, b))):
		return 3
	var hot: bool = page.is_hovered("booster%d" % b.index)
	hot = hot or (b.state == BoosterOpening.State.OPENING and b.waiting_k() >= 0)
	hot = hot or now - b.lamp_hot_t < 0.4 or next_booster(page) == b
	hot = hot or (page.complete_t != INF and now >= page.complete_t)
	return 2 if hot else 1


static func counted_index(page: BoosterPage, b: BoosterOpening) -> int:
	var k: int = 0
	for other: BoosterOpening in page.boosters:
		if other == b:
			return k
		if other.is_counted():
			k += 1
	return -1


## The next sealed booster to open (its lamp runs hot), or null: none while picking, nor while
## PICK 2 OF 3's SOLD OUT booster is still on its way out (the mock-up's p2State 'resolve').
static func next_booster(page: BoosterPage) -> BoosterOpening:
	if page.shutter != BoosterPage.Shutter.UP or page.picking():
		return null
	for b: BoosterOpening in page.boosters:
		if b.sold_t != INF and b.state != BoosterOpening.State.GONE:
			return null
	for b: BoosterOpening in page.boosters:
		if b.state == BoosterOpening.State.SEALED and b.is_counted():
			return b
	return null


## How far a SOLD OUT booster's lamp has pulled up (art px; 99: gone).
static func lamp_up(page: BoosterPage, b: BoosterOpening) -> float:
	if b.state == BoosterOpening.State.GONE:
		return 99.0
	if b.sink_t != INF and page.now >= b.sink_t:
		return 99.0 if page.rm else roundf(e_in((page.now - b.sink_t) / 0.3) * 60.0)
	return 0.0


## A shelf zone's light: 8 dark, 0 lit, 5 / 2 the steps of a flicker.
static func shelf_dim(page: BoosterPage, zone: int) -> int:
	var now: float = page.now
	if page.complete_t != INF and now >= page.complete_t:
		return 0
	var off: float = page.shelf_off[zone]
	if off != -INF and now >= off:
		var off_u: float = now - off
		return 2 if off_u < 0.07 else (5 if off_u < 0.14 else 8)
	var on: float = page.shelf_on[zone]
	if on == INF or now < on:
		return 8
	if page.rm:
		return 0
	var u: float = now - on
	return 0 if u < 0.05 else (8 if u < 0.1 else 0)


static func _shelf_aisle(page: BoosterPage, zone: int) -> AisleDefinition:
	var shown: Array[BoosterOpening] = []
	for b: BoosterOpening in page.boosters:
		if b.sold_t == INF and b.state != BoosterOpening.State.GONE:
			shown.append(b)
	for b: BoosterOpening in shown:
		if BoosterArt.zone_of(b.cx) == zone:
			return aisle_def(page, b.aisle)
	if shown.size() > zone:
		return aisle_def(page, shown[zone].aisle)
	if not shown.is_empty():
		return aisle_def(page, shown[0].aisle)
	return aisle_def(page, &"pantry")


static func _back(pen: ArtPen, page: BoosterPage) -> void:
	pen.tex(StoreDawnArt.room(), 0, 0)
	for zone: int in 2:
		var aisle: AisleDefinition = _shelf_aisle(page, zone)
		if aisle != null:
			pen.tex(StoreDawnArt.shelf(aisle, shelf_dim(page, zone) < 5), 156 + zone * 240, 70)
	if page.complete_t != INF and page.now >= page.complete_t:
		var level: int = 4 if page.rm or page.now - page.complete_t >= 0.07 else 2
		pen.d(0, 44, 112, 8, Palette.TEAL_DARK, level)
		pen.d(112, 44, 44, 186 + BoosterArt.DY, Palette.TEAL_DARK, level)
	_board(pen, page)
	_run_only(pen, page)
	_clock(pen, page)


static func _light(pen: ArtPen, page: BoosterPage) -> void:
	for b: BoosterOpening in page.boosters:
		if lamp_up(page, b) != 0.0:
			continue
		var level: int = lamp_state(page, b)
		_cone(pen, roundf(b.cx), level)
		_pool(pen, roundf(b.cx), level)


static func _lamp_colour(level: int) -> Color:
	if level >= 3:
		return Palette.MUSTARD
	return Palette.MUSTARD_DARK if level >= 2 else Palette.MUSTARD_DARKEST


static func _cone(pen: ArtPen, cx: float, level: int) -> void:
	if level <= 0:
		return
	var colour: Color = _lamp_colour(level)
	var checker: float = 0.7 if level >= 3 else (0.55 if level >= 2 else 0.3)
	var y: int = BoosterArt.CONE_TOP
	while y < CONE_BOTTOM:
		var share: float = float(y - BoosterArt.CONE_TOP) / (CONE_BOTTOM - BoosterArt.CONE_TOP)
		var w: float = floorf(lerpf(24, 104, share) / 2.0 + 0.5) * 2.0
		pen.d(cx - w / 2.0, y, w, 2, colour, 8 if share < checker else 4)
		y += 2


static func _pool(pen: ArtPen, cx: float, level: int) -> void:
	if level <= 0:
		return
	var colour: Color = _lamp_colour(level)
	var y: float = 230 + BoosterArt.DY
	pen.d(cx - 54, y, 108, 6, colour, 8)
	pen.d(cx - 66, y, 12, 6, colour, 4)
	pen.d(cx + 54, y, 12, 6, colour, 4)
	pen.d(cx - 44, y + 7, 88, 6, colour, 8 if level >= 2 else 4)
	pen.d(cx - 34, y + 13, 68, 4, colour, 4)


static func _front(pen: ArtPen, page: BoosterPage) -> void:
	for b: BoosterOpening in page.boosters:
		var up: float = lamp_up(page, b)
		if up >= 60.0:
			continue
		var level: int = lamp_state(page, b)
		var saved: Vector2 = pen.origin
		pen.origin = saved - Vector2(0, up * pen.unit.y)
		_lamp(pen, page, b, level)
		_sign(pen, page, roundf(b.cx), b.aisle, level == 0)
		pen.origin = saved
	_stocked(pen, page)
	BoosterChromeDraw.crate(pen, page)
	for b: BoosterOpening in page.boosters:
		if b.state == BoosterOpening.State.SEALED:
			_shadow(pen, page, b)


static func _lamp(pen: ArtPen, page: BoosterPage, b: BoosterOpening, level: int) -> void:
	var cx: float = roundf(b.cx)
	var top: int = BoosterArt.LAMP_TOP
	pen.r(cx - 1, 40, 2, top - 39, Palette.STEEL_DARK)
	pen.r(cx - 3, 43, 6, 2, Palette.STEEL_DARKEST)
	pen.tex(BoosterArt.LAMP, cx - 37, top - 2)
	if level <= 0:
		pen.r(cx - 34, top + 15, 68, 3, Palette.STEEL_DARKEST)
	elif level >= 3:
		pen.r(cx - 32, top + 15, 64, 3, Color.WHITE)
		pen.d(cx - 40, top + 18, 80, 3, Palette.MUSTARD_PALE, 8)
		pen.d(cx - 46, top + 21, 92, 2, Palette.MUSTARD_PALE, 4)
		var fu: float = page.now - page.full_at(maxi(0, counted_index(page, b)))
		if not page.rm and fu < 0.06:
			pen.tex(ArtPen.silhouette(BoosterArt.LAMP, Color.WHITE), cx - 37, top - 2)
			pen.r(cx - 44, top + 15, 88, 4, Color.WHITE)
	elif level >= 2:
		pen.r(cx - 30, top + 16, 60, 2, Palette.PAPER)


static func _sign(
	pen: ArtPen, page: BoosterPage, cx: float, aisle_id: StringName, dim: bool
) -> void:
	var label: String = BoosterArt.short_name(aisle_def(page, aisle_id))
	var w: float = maxf(56, ArtPen.word_texture(label, Palette.INK, true).get_width() + 14)
	var x: float = roundf(cx - w / 2.0)
	var y: float = 71
	pen.nine(BoosterArt.sign_frame(aisle_id), x, y, w, 14, Vector4i(3, 3, 3, 3))
	var light: bool = BoosterArt.LIGHT_SIGNS.has(aisle_id)
	pen.chunky(
		label, cx, y + 3, Palette.INK if light else Palette.CREAM, 1.0, HORIZONTAL_ALIGNMENT_CENTER
	)
	if dim:
		pen.r(x, y, w, 14, Color(Palette.TEAL_BLACK, 0.55))


static func _board(pen: ArtPen, page: BoosterPage) -> void:
	if page.openings.pick_layout():
		return
	var label: String = "YOUR STORE"
	var w: float = ArtPen.word_texture(label, Palette.INK, true).get_width() + 18
	var x: float = roundf(396 - w / 2.0)
	var y: float = 50
	var h: float = 17
	for cx: float in [x + 8, x + w - 9]:
		var yy: float = 41
		while yy < y:
			pen.r(cx, yy, 1, 1, Palette.STEEL_SHADE)
			yy += 2
	pen.rn(x, y, w, h, Palette.TEAL_BLACK)
	pen.r(x + 1, y + 1, w - 2, 1, Palette.TEAL_DARK)
	pen.r(x + 2, y + h - 3, w - 4, 1, Palette.TOMATO_DARK)
	var done: bool = page.page_done()
	pen.chunky(
		label,
		396,
		y + 4,
		Palette.PAPER if done else Palette.CREAM_SHADE,
		1.0,
		HORIZONTAL_ALIGNMENT_CENTER
	)


## STOCKED! under the board: slams at 2.5x, 1.4x, then hangs 1 px low on two strings.
static func _stocked(pen: ArtPen, page: BoosterPage) -> void:
	if page.stocked_t == INF or page.now < page.stocked_t:
		return
	var u: float = page.now - page.stocked_t
	var size: Vector2 = BoosterArt.STOCKED.get_size()
	var sc: float = 1.0 if page.rm else (2.5 if u < 0.05 else (1.4 if u < 0.1 else 1.0))
	var dy: float = 1.0 if page.rm else (0.0 if u < 0.1 else (3.0 if u < 0.16 else 1.0))
	var centre: Vector2 = Vector2(BoosterArt.STOCKED_CENTRE)
	if not page.rm and u >= 0.05 and u < 0.09:
		pen.r(
			centre.x - size.x / 2.0 - 4,
			centre.y - size.y / 2.0 - 4 + dy,
			size.x + 8,
			size.y + 8,
			Color.WHITE
		)
	for x: float in [centre.x - size.x / 2.0 + 10, centre.x + size.x / 2.0 - 11]:
		pen.r(roundf(x), 67, 1, roundf(centre.y - size.y / 2.0 + dy - 67), Palette.STEEL_SHADE)
	var w: float = roundf(size.x * sc)
	var h: float = roundf(size.y * sc)
	pen.canvas.draw_texture_rect(
		BoosterArt.STOCKED,
		Rect2(
			pen.at(roundf(centre.x - w / 2.0), roundf(centre.y - h / 2.0 + dy)), pen.size_of(w, h)
		),
		false
	)


static func _clock(pen: ArtPen, page: BoosterPage) -> void:
	var x: float = 112
	var y: float = 88
	pen.tex(BoosterArt.WALL_CLOCK, x, y)
	var cx: float = x + 22
	var cy: float = y + 22
	for row: int in range(-12, 13):
		var hw: float = floorf(sqrt(156.0 - row * row))
		pen.r(cx - hw, cy + row, hw * 2 + 1, 1, Palette.PAPER)
	for mark: Vector2 in [Vector2(0, -12), Vector2(12, 0), Vector2(0, 12), Vector2(-12, 0)]:
		pen.r(cx + mark.x - signf(mark.x), cy + mark.y - signf(mark.y), 1, 1, Palette.INK)
	var minutes: int = page.clock_minutes % 60
	var hour: int = 7 if page.clock_minutes >= 60 else 6
	_hand(pen, cx, cy, (hour % 12 + minutes / 60.0) / 12.0 * TAU, 6, Palette.INK)
	_hand(pen, cx, cy, minutes / 60.0 * TAU, 10, Palette.INK)
	var seconds: int = 0 if page.rm else int(floorf(page.now)) % 60
	_hand(pen, cx, cy, seconds / 60.0 * TAU, 10, Palette.TOMATO)
	pen.r(cx - 1, cy - 1, 2, 2, Palette.INK)


static func _hand(
	pen: ArtPen, cx: float, cy: float, angle: float, length: int, colour: Color
) -> void:
	for i: int in length + 1:
		pen.r(cx + roundf(sin(angle) * i), cy - roundf(cos(angle) * i), 1, 1, colour)


## The RUN-ONLY aisle's small unlit sign far back at the top right.
static func _run_only(pen: ArtPen, page: BoosterPage) -> void:
	if page.openings.pick_layout():
		return
	var ids: Array[StringName] = page.run.start_setup.run_only_ids(page.run.balance)
	if ids.is_empty():
		return
	var label: String = BoosterArt.short_name(aisle_def(page, ids[0]))
	var w: float = ArtPen.word_texture(label, Palette.INK, false).get_width() + 10
	var cx: float = 600
	var x: float = roundf(cx - w / 2.0)
	var y: float = 50
	pen.r(x + 4, 41, 1, 9, Palette.STEEL_DARKEST)
	pen.r(x + w - 5, 41, 1, 9, Palette.STEEL_DARKEST)
	pen.nine(BoosterArt.sign_frame(ids[0]), x, y, w, 9, Vector4i(3, 3, 3, 3))
	pen.r(x, y, w, 9, Color(Palette.TEAL_BLACK, 0.62))
	pen.caps(label, cx, y + 2, Palette.CREAM_DARKEST, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	var tw: float = ArtPen.word_texture("RUN-ONLY", Palette.INK, false).get_width() + 8
	pen.r(cx, y + 9, 1, 2, Palette.STEEL_DARKEST)
	pen.rn(roundf(cx - tw / 2.0), y + 11, tw, 9, Palette.SLATE_DARK, Palette.INK)
	pen.caps("RUN-ONLY", cx, y + 13, Palette.STEEL_SHADE, 1.0, HORIZONTAL_ALIGNMENT_CENTER)


## A sealed pouch's landing y and drop progress (the mock-up's drawSealed motion).
static func _drop(page: BoosterPage, b: BoosterOpening) -> float:
	if b.drop_t == INF:
		return -1.0
	return (page.now - b.drop_t) / maxf(page.tuning.drop_s, 0.001)


static func _shadow(pen: ArtPen, page: BoosterPage, b: BoosterOpening) -> void:
	var du: float = _drop(page, b)
	if du < 0.0 or (b.sink_t != INF and page.now >= b.sink_t):
		return
	var x: float = BoosterArt.pouch_pos(b.cx).x
	var w: float = (
		float(BoosterArt.BW) if page.rm or du >= 1.0 else roundf(lerpf(24, BoosterArt.BW, e_in(du)))
	)
	var left: float = roundf(x + BoosterArt.BW / 2.0 - w / 2.0)
	pen.r(left + 5, 230 + BoosterArt.DY, w, 4, Palette.WOOD_DARKEST)
	pen.r(left + 7, 234 + BoosterArt.DY, w - 4, 2, Palette.WOOD_DARKEST)


## Inside the counter clip: the settled RARE glows, the boosters and their fans.
static func _boosters(pen: ArtPen, page: BoosterPage) -> void:
	for b: BoosterOpening in page.boosters:
		if b.state == BoosterOpening.State.OPENING or b.state == BoosterOpening.State.OPEN:
			_sun_glows(pen, page, b)
	for b: BoosterOpening in page.boosters:
		if b.state == BoosterOpening.State.SEALED:
			_sealed(pen, page, b)
		elif b.state != BoosterOpening.State.GONE:
			_open_booster(pen, page, b)


## A pouch at art (`x`, `y`), `w` x `h` (a squash), from row `top` (a torn top), sheared in four
## bands, lit `lit` (0: modulated down), with its sheen glint (`sheen` 0..1) and hover sweep.
static func pouch(
	pen: ArtPen, aisle_id: StringName, lit: int, x: float, y: float, o: Dictionary = {}
) -> void:
	var texture: Texture2D = BoosterArt.pouch(aisle_id)
	var w: float = o.get("w", float(BoosterArt.BW))
	var h: float = o.get("h", float(BoosterArt.BH))
	var top: int = o.get("top", 0)
	var shear: float = o.get("shear", 0.0)
	var dx: float = roundf(x + (BoosterArt.BW - w) / 2.0)
	var dy: float = roundf(y + BoosterArt.BH - h)
	var tint: Color = BoosterArt.UNLIT if lit <= 0 else Color.WHITE
	var bands: int = 4 if shear != 0.0 else 1
	for i: int in bands:
		var sy: float = roundf(i * BoosterArt.BH / float(bands))
		var sh: float = roundf((i + 1) * BoosterArt.BH / float(bands)) - sy
		if sy + sh <= top:
			continue
		var from: float = maxf(sy, top)
		var rows: float = sh - maxf(0.0, top - sy)
		var off: float = roundf(shear * (bands - 1 - i) / maxf(1, bands - 1)) if bands > 1 else 0.0
		var dest_y: float = dy + roundf(from * h / BoosterArt.BH)
		var dest_h: float = roundf(rows * h / BoosterArt.BH)
		var visible: float = minf(dest_h, COUNTER_CLIP - dest_y)
		if visible <= 0:
			continue
		var src_rows: float = rows * visible / dest_h
		pen.tex_part(
			texture, Rect2(0, from, BoosterArt.BW, src_rows), dx + off, dest_y, w, visible, tint
		)
	if lit >= 2:
		var lit_y: float = dy + roundf((POUCH_BT + 3) * h / BoosterArt.BH)
		pen.r(dx + 9, lit_y, w - 24, 1, Palette.PAPER)
		pen.d(dx + 9, lit_y + 1, w - 24, 1, Palette.PAPER, 8)
	var sheen: float = o.get("sheen", -1.0)
	if sheen < 0.0 or sheen > 1.0:
		return
	if o.get("sweep", false):
		var sx: float = roundf(lerpf(-60, BoosterArt.BW + 10, sheen))
		for row: int in range(13, BoosterArt.BH - 8):
			var xx: float = sx + floorf((BoosterArt.BH - row) / 2.0)
			var a: float = maxf(2, xx)
			var b2: float = minf(BoosterArt.BW - 2, xx + 6)
			if b2 > a:
				pen.d(dx + a, dy + row, b2 - a, 1, Palette.PAPER, 4)
	var gy: float = roundf(lerpf(POUCH_BT + 3, POUCH_BB - 16, sheen) * h / BoosterArt.BH)
	var gx: float = dx + roundf(14 * w / BoosterArt.BW)
	pen.r(gx, dy + gy, 4, 8, Palette.PAPER)
	pen.r(gx + 1, dy + gy - 2, 2, 12, Color.WHITE)
	pen.r(gx - 1, dy + gy + 3, 6, 2, Color.WHITE)


static func _sheen_phase(page: BoosterPage, b: BoosterOpening, hovered: bool) -> float:
	if page.rm:
		return -1.0
	if hovered:
		return fmod(page.now - page.hover_t0, 1.2) / 0.45
	return fmod(page.now + b.index * 0.6, 3.2) / 0.45


static func _sealed(pen: ArtPen, page: BoosterPage, b: BoosterOpening) -> void:
	var du: float = _drop(page, b)
	if du < 0.0:
		return
	var tuning: StartBoostersTuning = page.tuning
	var at: Vector2 = BoosterArt.pouch_pos(b.cx)
	var x: float = at.x
	var y: float = at.y
	var w: float = BoosterArt.BW
	var h: float = BoosterArt.BH
	var squash_end: float = (
		1.0 + (tuning.squash_in_s + tuning.squash_out_s) / maxf(tuning.drop_s, 0.001)
	)
	if not page.rm and du < 1.0:
		y = lerpf(-140 - BoosterArt.BH, at.y, e_back(du, tuning.drop_overshoot))
	elif not page.rm and du < squash_end:
		var lu: float = page.now - b.drop_t - tuning.drop_s
		var s: float = (
			lu / tuning.squash_in_s
			if lu < tuning.squash_in_s
			else 1.0 - (lu - tuning.squash_in_s) / tuning.squash_out_s
		)
		w = BoosterArt.BW + roundf(4 * s)
		h = BoosterArt.BH - roundf(9 * s)
	y = roundf(y)
	var hovered: bool = (
		page.is_hovered("booster%d" % b.index) and page.shutter == BoosterPage.Shutter.UP
	)
	var lift: float = 0.0
	var shear: float = 0.0
	if not page.rm and du >= 1.7:
		if hovered:
			var hu: float = page.now - page.hover_t0
			lift = minf(4, floorf(hu / 0.02))
			shear = roundf(2.7 * sin(11 * hu) * maxf(0.0, 1.0 - hu / 1.15))
		else:
			y += int(floorf((page.now + b.index * 0.17) / 0.5)) % 2
	if b.picked and not page.rm:
		lift += 6 if page.now - b.pick_t < 0.12 else 3
	if b.sink_t != INF and page.now >= b.sink_t:
		y += 200.0 if page.rm else roundf(e_in((page.now - b.sink_t) / tuning.pick_sink_s) * 140)
	var lit: int = lamp_state(page, b)
	pouch(
		pen,
		b.aisle,
		lit,
		x,
		y - lift,
		{"w": w, "h": h, "shear": shear, "sheen": _sheen_phase(page, b, hovered), "sweep": hovered}
	)
	if b.restocked:
		_stamp(
			pen, page, "RESTOCKED", x + BoosterArt.BW / 2.0, y - lift + 40, b.drop_t + tuning.drop_s
		)
	if b.sold_t != INF and page.now >= b.sold_t:
		_sold_out(pen, page, b, x + BoosterArt.BW / 2.0, y - lift)


## A teal stamp slammed on a pouch: 2x for 70 ms, settles 2 px by 140 ms.
static func _stamp(
	pen: ArtPen, page: BoosterPage, word: String, cx: float, cy: float, t0: float
) -> void:
	var u: float = page.now - t0
	if u < 0.0:
		return
	var sc: float = 1.0 if page.rm or u >= 0.07 else 2.0
	var settle: float = 0.0 if page.rm or u < 0.07 or u >= 0.14 else -2.0
	var tw: float = ArtPen.word_texture(word, Palette.INK, true).get_width() + 10
	var th: float = 14
	var saved_origin: Vector2 = pen.origin
	var saved_unit: Vector2 = pen.unit
	pen.origin = pen.at(roundf(cx - tw * sc / 2.0), roundf(cy - th * sc / 2.0 + settle))
	pen.unit = saved_unit * sc
	pen.rn(0, 0, tw, th, Palette.PAPER, Palette.TEAL)
	pen.r(2, 2, tw - 4, th - 4, Palette.PAPER)
	pen.r(1, 1, tw - 2, 1, Palette.TEAL)
	pen.r(1, th - 2, tw - 2, 1, Palette.TEAL)
	pen.chunky(word, tw / 2.0, 3, Palette.TEAL, 1.0, HORIZONTAL_ALIGNMENT_CENTER)
	pen.origin = saved_origin
	pen.unit = saved_unit


## SOLD OUT drops on its string and swings to rest (the rotation is drawn with a transform).
static func _sold_out(
	pen: ArtPen, page: BoosterPage, b: BoosterOpening, cx: float, top: float
) -> void:
	var u: float = page.now - b.sold_t
	var dy: float = 0.0 if page.rm else roundf(-46 * (1.0 - clampf(u / 0.15, 0.0, 1.0)))
	var angle: float = 0.0
	if not page.rm and u >= 0.15:
		angle = deg_to_rad(22 * exp(-(u - 0.15) * 5) * cos((u - 0.15) * 14))
	var label: String = "SOLD OUT"
	var w: float = ArtPen.word_texture(label, Palette.INK, true).get_width() + 10
	var h: float = 14
	var pivot: Vector2 = pen.at(roundf(cx), roundf(top + 30 + dy))
	var saved: Vector2 = pen.origin
	pen.canvas.draw_set_transform(pivot, angle, Vector2.ONE)
	pen.origin = Vector2.ZERO
	pen.r(-1, -30, 1, 20, Palette.STEEL_DARK)
	pen.r(-w / 2.0, -10, w, h, Palette.INK)
	pen.r(-w / 2.0 + 1, -9, w - 2, h - 2, Palette.PAPER)
	pen.r(-w / 2.0 + 2, -8, w - 4, h - 4, Palette.TOMATO)
	pen.r(-w / 2.0 + 3, -7, w - 6, h - 6, Palette.PAPER)
	var words: ImageTexture = ArtPen.word_texture(label, Palette.TOMATO, true)
	pen.tex(words, -roundf(words.get_width() / 2.0), -7)
	pen.canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	pen.origin = saved


## The opening and open booster: its fan cards (behind the pouch while they rise), the pouch's
## grab, rattle, tear and drop away.
static func _open_booster(pen: ArtPen, page: BoosterPage, b: BoosterOpening) -> void:
	var tuning: StartBoostersTuning = page.tuning
	var t: float = b.lt
	var at: Vector2 = BoosterArt.pouch_pos(b.cx)
	if b.rm:
		var u: float = clampf(t / maxf(tuning.rm_fade_s, 0.001), 0.0, 1.0)
		if u < 1.0 and b.state == BoosterOpening.State.OPENING:
			pouch(pen, b.aisle, lamp_state(page, b), at.x, at.y)
		for k: int in b.cards.size():
			var p: Vector2 = BoosterArt.fan_pos(b.cx, k)
			if u >= 1.0 or b.state == BoosterOpening.State.OPEN:
				card(
					pen,
					page,
					b,
					k,
					p.x,
					p.y - (3 if _rest_hovered(page, b, k) else 0),
					{"still": true}
				)
				BoosterCardDraw.tab(pen, b.rares[k], p.x + BoosterArt.CW / 2.0, p.y - 1)
		return
	var veil: BoosterOpening = _anticipation(page)
	var order: Array[int] = []
	var hovered_k: int = _hovered_card(page, b)
	for k: int in b.cards.size():
		if k != hovered_k:
			order.append(k)
	if hovered_k >= 0:
		order.append(hovered_k)
	if t >= tuning.rise_start_s:
		for k: int in order:
			fan_card(pen, page, b, k, veil)
	if t < tuning.rise_start_s + tuning.pouch_drop_s:
		var x: float = at.x
		var y: float = at.y
		var w: float = BoosterArt.BW
		var h: float = BoosterArt.BH
		var top: int = 0
		var shear: float = 0.0
		if t < tuning.grab_s:
			var s: float = t / 0.04 if t < 0.04 else 1.0
			w = BoosterArt.BW + roundf(7 * s)
			h = BoosterArt.BH - roundf(13 * s)
		elif t < tuning.rattle_end_s:
			var phase: int = int(floorf((t - tuning.grab_s) * 25)) % 2
			x += 4 if phase else -4
			shear = 3 if phase else -3
			var s2: float = 1.0 - (t - tuning.grab_s) / 0.12
			w = BoosterArt.BW + roundf(3 * s2)
			h = BoosterArt.BH - roundf(6 * s2)
		if t >= tuning.burst_s:
			top = 12
			y += 5 if t < tuning.burst_s + 0.18 else 0
		if t >= tuning.rise_start_s:
			y += roundf(e_in((t - tuning.rise_start_s) / tuning.pouch_drop_s) * 140)
		pouch(
			pen,
			b.aisle,
			maxi(1, lamp_state(page, b)),
			x,
			y,
			{"w": w, "h": h, "top": top, "shear": shear}
		)
		if t >= tuning.rattle_end_s and t < tuning.burst_s:
			var tear: float = roundf(
				(
					clampf(
						(t - tuning.rattle_end_s) / (tuning.burst_s - tuning.rattle_end_s), 0.0, 1.0
					)
					* (BoosterArt.BW - 4)
				)
			)
			pen.r(x + 1, y + 11, tear, 2, Palette.INK)
			pen.r(x + tear - 1, y + 10, 3, 4, Color.WHITE)
		if t >= tuning.grab_s and t < tuning.rattle_end_s:
			pen.r(x + 1, y, BoosterArt.BW - 2, 1, Palette.INK)


## Card k of an open booster hovered at rest (it lifts 3 px).
static func _rest_hovered(page: BoosterPage, b: BoosterOpening, k: int) -> bool:
	return b.state == BoosterOpening.State.OPEN and page.is_hovered("card%d_%d" % [b.index, k])


static func _hovered_card(page: BoosterPage, b: BoosterOpening) -> int:
	for k: int in b.cards.size():
		if page.is_hovered("card%d_%d" % [b.index, k]):
			return k
	return -1


## The booster whose hit card is rising right now (the others' art windows veil), or null.
static func _anticipation(page: BoosterPage) -> BoosterOpening:
	for b: BoosterOpening in page.boosters:
		if b.state != BoosterOpening.State.OPENING:
			continue
		for k: int in b.specials:
			if b.lt >= b.antic[k] and b.lt < b.antic[k] + page.tuning.hit_hang_s:
				return b
	return null


## Card k of `b` through the pen (the page clock and the hot foil filled in).
static func card(
	pen: ArtPen,
	page: BoosterPage,
	b: BoosterOpening,
	k: int,
	x: float,
	y: float,
	o: Dictionary = {}
) -> void:
	o["now"] = page.now
	if page.rm:
		o["still"] = true
	BoosterCardDraw.draw(pen, b.cards[k], b.rares[k], x, y, o)


static func _back_of(b: BoosterOpening, k: int) -> BoosterCardDraw.Back:
	return BoosterCardDraw.Back.HIT if b.hits[k] else BoosterCardDraw.Back.PLAIN


## One fan card of an opening booster: rising, spreading, face down (the hit trembles or waits),
## flipping, or landed (a RARE pops with its tab and sparkles), with the anticipation veil.
static func fan_card(
	pen: ArtPen, page: BoosterPage, b: BoosterOpening, k: int, veil: BoosterOpening
) -> void:
	var tuning: StartBoostersTuning = page.tuning
	var t: float = b.lt
	var now: float = page.now
	var p: Vector2 = BoosterArt.fan_pos(b.cx, k)
	var at: Vector2 = BoosterArt.pouch_pos(b.cx)
	var x: float = p.x
	var y: float = p.y
	var sx0: float = at.x + 4 + (k - 1)
	var sy0: float = at.y + 6 - k
	if t < tuning.rise_end_s:
		var u: float = e_out((t - tuning.rise_start_s) / (tuning.rise_end_s - tuning.rise_start_s))
		x = sx0
		y = roundf(lerpf(sy0, sy0 - 40, u))
	elif t < tuning.spread_end_s:
		var u2: float = e_back(
			(t - tuning.rise_end_s) / (tuning.spread_end_s - tuning.rise_end_s), 1.9
		)
		x = roundf(lerpf(sx0, p.x, u2))
		y = roundf(lerpf(sy0 - 40, p.y, u2))
	var f: float = b.flip_at[k]
	var rest_hover: bool = _rest_hovered(page, b, k)
	if rest_hover:
		y -= 3
	if (
		page.restock_armed
		and page.counter.restockable(b.index)
		and page.is_hovered("rcards%d" % b.index)
		and not page.rm
	):
		x += 1 if sin(now * TAU * 55) > 0 else -1
		y += 1 if sin(now * TAU * 47) > 0 else 0
	if page.complete_t != INF:
		var hu: float = now - page.complete_t - 0.05 * (4 + b.index * 3 + k)
		if hu > 0 and hu < 0.1:
			y -= 2
	if t < f:
		var start: float = b.antic[k]
		if b.waits[k] and t >= start + tuning.hit_hang_s:
			_hit_wait(pen, page, b, k, x, y)
			return
		var ox: float = 0.0
		var oy: float = 0.0
		if t >= start + tuning.hit_hang_s:
			ox = 1 if sin(now * TAU * 55) > 0 else -1
			oy = 0 if sin(now * TAU * 47) > 0 else 1
		elif t >= start:
			oy = -roundf(6 * (t - start) / tuning.hit_hang_s)
		card(pen, page, b, k, x + ox, y + oy, {"back": _back_of(b, k)})
		if t >= start:
			pen.r(x + ox + 2, y + oy + BoosterArt.CH, BoosterArt.CW - 4, 1, Palette.INK)
	elif t < f + tuning.flip_s:
		var q: float = (t - f) / tuning.flip_s
		var squeeze: float = absf(cos(PI * q))
		var lift: float = 1 if q > 0.25 and q < 0.75 else 0
		if q < 0.5:
			card(pen, page, b, k, x, y - lift, {"back": _back_of(b, k), "sx": squeeze})
		else:
			var rare_beat: bool = b.beats[k] == BoosterOpening.Beat.RARE
			card(pen, page, b, k, x, y - lift, {"sx": squeeze, "flash": 1.0 if rare_beat else 0.0})
	else:
		_landed(pen, page, b, k, x, y, t - f - tuning.flip_s, rest_hover)
	var own: bool = veil == b and not b.specials.has(k)
	if veil != null and (veil != b or own) and t >= tuning.spread_end_s and t >= f + tuning.flip_s:
		pen.r(x + 2, y + 2, BoosterArt.CW - 4, 51, Color(Palette.TEAL_BLACK, 0.5))
	pen.r(x + 2, y + BoosterArt.CH, BoosterArt.CW - 4, 1, Palette.INK)


static func _landed(
	pen: ArtPen,
	page: BoosterPage,
	b: BoosterOpening,
	k: int,
	x: float,
	y: float,
	lu: float,
	rest_hover: bool
) -> void:
	var tuning: StartBoostersTuning = page.tuning
	var rare: bool = b.rares[k]
	var o: Dictionary = {"hot": rest_hover}
	var scale: float = 1.0
	if rare:
		if lu < 0.03:
			o["flash"] = 1.0
			scale = 1.15
		elif lu < 0.03 + tuning.rare_pop_s:
			scale = 1.0 + 0.15 * (1.0 - e_out((lu - 0.03) / tuning.rare_pop_s))
		var sweep: float = (
			lu / 0.45 if lu < 0.45 else fmod(page.now + k * 0.6, 1.2 if rest_hover else 3.2) / 0.45
		)
		o["sweep"] = -1.0 if lu < 0.03 else sweep
	elif lu < 0.12:
		y -= roundf((6 if b.beats[k] == BoosterOpening.Beat.HEAVY else 4) * (1.0 - lu / 0.12))
	scale = roundf(scale * 20) / 20.0
	o["scale"] = scale
	card(pen, page, b, k, x, y, o)
	if rare and not page.rm and int(floorf(page.now / 0.4)) % 2:
		pen.tex_c(BoosterArt.SPARKLE, x + 3, y + 3)
		pen.tex_c(BoosterArt.SPARKLE, x + BoosterArt.CW - 3, y + BoosterArt.CH - 12)
	var pop_px: float = roundf((scale - 1.0) * BoosterArt.CH / 2.0)
	var tab_scale: float = 1.0
	if rare and lu < 0.2:
		tab_scale = lerpf(1.5, 1.0, e_back(lu / 0.2))
	BoosterCardDraw.tab(
		pen, rare, x + BoosterArt.CW / 2.0, y - 1 - pop_px, roundf(tab_scale * 4) / 4.0
	)


## The hit card waiting for its click: it breathes, its rim pulses gold, glints walk its corners.
static func _hit_wait(
	pen: ArtPen, page: BoosterPage, b: BoosterOpening, k: int, x: float, y: float
) -> void:
	var now: float = page.now
	var phase: float = 0.0 if page.rm else fmod(now, 0.9) / 0.9
	var rise: float = 0.0 if page.rm else roundf((1.0 - cos(phase * TAU)) / 2.0 * 3.0)
	var yy: float = y - rise
	var hot: bool = not page.rm and int(floorf(now / 0.18)) % 2 == 0
	pen.d(x - 5, yy - 5, BoosterArt.CW + 10, BoosterArt.CH + 10, Palette.GOLD, 6 if hot else 3)
	pen.r(
		x - 2, yy - 2, BoosterArt.CW + 4, BoosterArt.CH + 4, Palette.GOLD if hot else Palette.BRASS
	)
	card(pen, page, b, k, x, yy, {"back": BoosterCardDraw.Back.HIT})
	pen.r(x + 2, y + BoosterArt.CH + 1, BoosterArt.CW - 4, 1, Palette.INK)
	if not page.rm:
		var g: int = int(floorf(now / 0.15)) % 4
		var corners: Array[Vector2] = [
			Vector2(x + 4, yy + 4),
			Vector2(x + BoosterArt.CW - 5, yy + 4),
			Vector2(x + BoosterArt.CW - 5, yy + BoosterArt.CH - 5),
			Vector2(x + 4, yy + BoosterArt.CH - 5),
		]
		pen.tex_c(BoosterArt.SPARKLE, corners[g].x, corners[g].y)


## Stage-clock age of a landed card's sun.
static func _sun_age(page: BoosterPage, b: BoosterOpening, k: int) -> float:
	if b.land_t[k] != -INF:
		return page.now - b.land_t[k]
	return b.lt - b.flip_at[k] - page.tuning.flip_s


static func _sun_done(tuning: StartBoostersTuning) -> float:
	return tuning.sun_grow_s + tuning.sun_hold_s + tuning.sun_shrink_s


static func _sun_glows(pen: ArtPen, page: BoosterPage, b: BoosterOpening) -> void:
	if b.rm:
		return
	for k: int in b.cards.size():
		if not b.rares[k] or not b.landed(k, page.tuning):
			continue
		if _sun_age(page, b, k) >= _sun_done(page.tuning):
			var p: Vector2 = BoosterArt.fan_pos(b.cx, k)
			pen.d(p.x - 3, p.y - 3, BoosterArt.CW + 6, BoosterArt.CH + 6, Palette.TEAL_LIGHT, 3)


## Over the counter clip: the tear flash and the flying foil strip, the live RARE suns (the RARE
## redrawn over them), the RESTOCK call round each returnable fan, the counter plates.
static func _front_over(pen: ArtPen, page: BoosterPage) -> void:
	var tuning: StartBoostersTuning = page.tuning
	for b: BoosterOpening in page.boosters:
		if b.state != BoosterOpening.State.OPENING or b.rm:
			continue
		var at: Vector2 = BoosterArt.pouch_pos(b.cx)
		var fu: float = page.now - b.flash_t
		if not page.rm and fu >= 0.0 and fu < 0.04:
			var second: bool = fu >= 0.02
			var y0: float = at.y + (8 if second else 2)
			var hh: float = 6 if second else 16
			pen.r(at.x - 10, y0, BoosterArt.BW + 20, hh, Color.WHITE)
			pen.r(at.x - 4, y0 - 3, BoosterArt.BW + 8, 2, Palette.MUSTARD_PALE)
			pen.r(at.x - 4, y0 + hh + 1, BoosterArt.BW + 8, 2, Palette.MUSTARD_PALE)
		if b.lt >= tuning.burst_s and b.lt < tuning.burst_s + 0.36:
			# The torn strip arcs up and away to the right and rips off at an angle (mock-up v3's
			# tear step): it tilts, rising to the left, in 15 degree steps up to 30 (capped, so a
			# still frame never shows it standing upright on the divider), turned about its centre.
			var u: float = (b.lt - tuning.burst_s) / 0.36
			var texture: Texture2D = BoosterArt.strip(b.aisle)
			var half: Vector2 = texture.get_size() / 2.0
			var cx: float = roundf(at.x + u * 120 + half.x)
			var cy: float = roundf(at.y - sin(u * PI) * 60 - u * 20 + half.y)
			var angle: float = deg_to_rad(minf(30.0, 15.0 + floorf(u * 3.0) * 15.0))
			var saved: Vector2 = pen.origin
			pen.canvas.draw_set_transform(pen.at(cx, cy), angle, Vector2.ONE)
			pen.origin = Vector2.ZERO
			pen.tex(texture, -half.x, -half.y)
			pen.canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			pen.origin = saved
	for b: BoosterOpening in page.boosters:
		if b.state == BoosterOpening.State.OPENING or b.state == BoosterOpening.State.OPEN:
			_suns_top(pen, page, b)
	BoosterChromeDraw.restock_call(pen, page)
	BoosterChromeDraw.counter_plates(pen, page)
	BoosterChromeDraw.bay(pen, page)


static func _suns_top(pen: ArtPen, page: BoosterPage, b: BoosterOpening) -> void:
	if b.rm:
		return
	var tuning: StartBoostersTuning = page.tuning
	for k: int in b.cards.size():
		if not b.rares[k] or not b.landed(k, tuning) or b.flip_at[k] == -1.0:
			continue
		var lu: float = _sun_age(page, b, k)
		var s: float = 1.0
		if lu < tuning.sun_grow_s:
			s = ceilf(lu / tuning.sun_grow_s * 4) / 4.0
		elif lu < tuning.sun_grow_s + tuning.sun_hold_s:
			s = 1.0
		elif lu < _sun_done(tuning):
			var q: float = (
				ceilf((lu - tuning.sun_grow_s - tuning.sun_hold_s) / tuning.sun_shrink_s * 4) / 4.0
			)
			s = maxf(0.28, 1.0 - q * 0.72)
		else:
			continue
		var p: Vector2 = BoosterArt.fan_pos(b.cx, k)
		BoosterCardDraw.sun(pen, p.x + BoosterArt.CW / 2.0, p.y + BoosterArt.CH / 2.0, s * 1.4)
		fan_card(pen, page, b, k, null)


static func _parts(pen: ArtPen, page: BoosterPage) -> void:
	for p: Dictionary in page.fx.parts:
		var dt: float = page.now - (p.t as float)
		if dt < 0.0:
			continue
		var u: float = dt / (p.life as float)
		if p.type == "spark":
			pen.tex_c(BoosterArt.SPARKLE, p.x, p.y)
			continue
		var x: float = roundf((p.x as float) + (p.vx as float) * dt)
		var y: float = roundf(
			(p.y as float) + (p.vy as float) * dt + 0.5 * (p.g as float) * dt * dt
		)
		if p.type == "dust":
			var s: float = 2 if u < 0.5 else 1
			pen.r(x, y, s, s, Palette.PLASTER_LIGHT)
		elif p.type == "scrap":
			var flip: bool = int(floorf(dt / 0.08)) % 2 == 1
			var size: float = (p.s as float) - (2 if u > 0.75 else 0)
			var w: float = size if flip else maxf(2, size - 3)
			var h: float = maxf(2, size - 3) if flip else size
			pen.r(x - 1, y - 1, w + 2, h + 2, Palette.INK)
			pen.r(x, y, w, h, p.c)
			if size > 3:
				pen.r(x, y, 1, 1, Color.WHITE)
