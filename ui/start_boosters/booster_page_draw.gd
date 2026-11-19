class_name BoosterPageDraw
extends RefCounted
## The shared drawing of YOUR STORE's boosters (BoosterPage, v1.32; the page itself is the aisle
## board since v1.40, AisleBoardDraw): the pouch, a booster opening on its own clock (the tear,
## the rise, the fan, the flips, a RARE's pop and sun), the particles, the keys' press-bob, the
## easings. The floor row and the top bar are BoosterChromeDraw's; the swap window is
## SwapWindowDraw's and draws its boosters with these. Motion reads the page's clock only.

## The counter top: what stands on it is clipped here (a pouch drops behind the counter).
const COUNTER_CLIP := 233 + BoosterArt.DY
const POUCH_BT := 12
const POUCH_BB := BoosterArt.BH - 8


## Draws `layer` of its page: the aisle board's layers (AisleBoardDraw), else the swap window's.
static func draw(layer: BoosterLayer) -> void:
	var page: BoosterPage = layer.page
	if page.run == null:
		return
	if not AisleBoardDraw.draw(layer.pen, page, layer.layer):
		SwapWindowDraw.draw(layer.pen, page, layer.layer)


## The hit list of the page this frame, bottom first (BoosterChromeDraw's).
static func hits(page: BoosterPage) -> Array[Dictionary]:
	return BoosterChromeDraw.hits(page)


## How lit a booster's pouch is drawn: the aisle board's are fully lit, the swap window's plain.
static func pouch_lit(b: BoosterOpening) -> int:
	return 2 if b.board else 1


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


## An armed primary key's press-bob lift in art px (v1.32 feedback: the user's pick C "press-bob"
## on docs/art/mockups/next_key_idle.html, in place of chase bulbs): 0 before `armed_t`; from it the
## arm hop holds next_hop_lifts[k] until next_hop_ends_s[k] (1, 2, 1, 0 art px); after it, every
## next_bob_s counted from next_bob_from_s, the face rises next_bob_px for next_bob_hold_s. `rest`
## (the key hovered: the player found it) keeps the idle bob down, not the hop; reduced motion
## (`still`) keeps it at 0. The key never changes size (lifted_key).
static func key_lift(
	now: float, armed_t: float, tuning: StartBoostersTuning, still: bool, rest: bool
) -> int:
	if still or now < armed_t:
		return 0
	var u: float = now - armed_t
	var ends: PackedFloat32Array = tuning.next_hop_ends_s
	for k: int in ends.size():
		if u < ends[k]:
			return tuning.next_hop_lifts[k] if k < tuning.next_hop_lifts.size() else 0
	if rest or tuning.next_bob_s <= 0.0 or u < tuning.next_bob_from_s:
		return 0
	var phase: float = fmod(u - tuning.next_bob_from_s, tuning.next_bob_s)
	return tuning.next_bob_px if phase < tuning.next_bob_hold_s else 0


## A key's 10x10 `frame` (margins 3) over art rect (`x`, `y`, `w`, `h`) with its face lifted `lift`
## art px (the mock-up's nine(..., ledge)): the 9-slice drawn `lift` px higher, then its dark ledge
## row (row 8) repeated under it down to the bottom outline (row 9), which stays on the rect's
## bottom, so the key keeps its rect and its feet.
static func lifted_key(
	pen: ArtPen, frame: Texture2D, x: float, y: float, w: float, h: float, lift: int
) -> void:
	pen.nine(frame, x, y - lift, w, h, Vector4i(3, 3, 3, 3))
	if lift <= 0:
		return
	var t: float = frame.get_width() / 10.0
	# Each column: texel x, texel width, art x, art width (left corner, stretched middle, right).
	var cols: Array[Vector4] = [
		Vector4(0, 3 * t, x, 3),
		Vector4(3 * t, 4 * t, x + 3, w - 6),
		Vector4(7 * t, 3 * t, x + w - 3, 3)
	]
	for c: Vector4 in cols:
		pen.tex_part(frame, Rect2(c.x, 8 * t, c.y, t), c.z, y + h - 2 - lift, c.w, 1 + lift)
		pen.tex_part(frame, Rect2(c.x, 9 * t, c.y, t), c.z, y + h - 1, c.w, 1)


static func aisle_def(page: BoosterPage, id: StringName) -> AisleDefinition:
	for aisle: AisleDefinition in page.run.balance.aisles:
		if aisle.id == id:
			return aisle
	return null


## A pouch at art (`x`, `y`), `w` x `h` (a squash), from row `top` (a torn top), sheared in four
## bands, lit `lit` (0: modulated down), with its sheen glint (`sheen` 0..1) and hover sweep;
## nothing below `clip` (art px; the counter top by default) is drawn.
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
		var visible: float = minf(dest_h, (o.get("clip", float(COUNTER_CLIP)) as float) - dest_y)
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


## The opening and open booster on its own clock: its fan cards (behind the pouch while they
## rise, spread and flip), the pouch's grab, rattle, tear and drop away (nothing of it below
## `clip`). The swap
## window draws its boosters with it too, its pen moved up.
static func open_booster(
	pen: ArtPen, page: BoosterPage, b: BoosterOpening, clip: float = COUNTER_CLIP
) -> void:
	var tuning: StartBoostersTuning = page.tuning
	var t: float = b.lt
	var at: Vector2 = b.pouch_pos()
	if b.rm:
		var u: float = clampf(t / maxf(tuning.rm_fade_s, 0.001), 0.0, 1.0)
		if u < 1.0 and b.state == BoosterOpening.State.OPENING:
			pouch(pen, b.aisle, pouch_lit(b), at.x, at.y, {"clip": clip})
		for k: int in b.cards.size():
			var p: Vector2 = b.fan_pos(k)
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
				if b.tabs:
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
			pouch_lit(b),
			x,
			y,
			{"w": w, "h": h, "top": top, "shear": shear, "clip": clip}
		)
		if t >= tuning.rattle_end_s and t < tuning.burst_s:
			var torn: float = roundf(
				(
					clampf(
						(t - tuning.rattle_end_s) / (tuning.burst_s - tuning.rattle_end_s), 0.0, 1.0
					)
					* (BoosterArt.BW - 4)
				)
			)
			pen.r(x + 1, y + 11, torn, 2, Palette.INK)
			pen.r(x + torn - 1, y + 10, 3, 4, Color.WHITE)
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
	if b.compact:
		o["compact"] = true
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
	var p: Vector2 = b.fan_pos(k)
	var at: Vector2 = b.pouch_pos()
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
			pen.r(x + ox + 2, y + oy + b.card_h(), BoosterArt.CW - 4, 1, Palette.INK)
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
	pen.r(x + 2, y + b.card_h(), BoosterArt.CW - 4, 1, Palette.INK)


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
		pen.tex_c(BoosterArt.SPARKLE, x + BoosterArt.CW - 3, y + b.card_h() - 12)
	if not b.tabs:
		return
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
	var ch: float = b.card_h()
	pen.d(x - 5, yy - 5, BoosterArt.CW + 10, ch + 10, Palette.GOLD, 6 if hot else 3)
	pen.r(x - 2, yy - 2, BoosterArt.CW + 4, ch + 4, Palette.GOLD if hot else Palette.BRASS)
	card(pen, page, b, k, x, yy, {"back": BoosterCardDraw.Back.HIT})
	pen.r(x + 2, y + ch + 1, BoosterArt.CW - 4, 1, Palette.INK)
	if not page.rm:
		var g: int = int(floorf(now / 0.15)) % 4
		var corners: Array[Vector2] = [
			Vector2(x + 4, yy + 4),
			Vector2(x + BoosterArt.CW - 5, yy + 4),
			Vector2(x + BoosterArt.CW - 5, yy + ch - 5),
			Vector2(x + 4, yy + ch - 5),
		]
		pen.tex_c(BoosterArt.SPARKLE, corners[g].x, corners[g].y)


## Stage-clock age of a landed card's sun.
static func _sun_age(page: BoosterPage, b: BoosterOpening, k: int) -> float:
	if b.land_t[k] != -INF:
		return page.now - b.land_t[k]
	return b.lt - b.flip_at[k] - page.tuning.flip_s


static func _sun_done(tuning: StartBoostersTuning) -> float:
	return tuning.sun_grow_s + tuning.sun_hold_s + tuning.sun_shrink_s


static func sun_glows(pen: ArtPen, page: BoosterPage, b: BoosterOpening) -> void:
	if b.rm:
		return
	for k: int in b.cards.size():
		if not b.rares[k] or not b.landed(k, page.tuning):
			continue
		if _sun_age(page, b, k) >= _sun_done(page.tuning):
			var p: Vector2 = b.fan_pos(k)
			pen.d(p.x - 3, p.y - 3, BoosterArt.CW + 6, b.card_h() + 6, Palette.TEAL_LIGHT, 3)


## Booster `b`'s tear flash and the foil strip flying off as it bursts open.
static func tear(pen: ArtPen, page: BoosterPage, b: BoosterOpening) -> void:
	var tuning: StartBoostersTuning = page.tuning
	if b.state != BoosterOpening.State.OPENING or b.rm:
		return
	var at: Vector2 = b.pouch_pos()
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


static func suns_top(pen: ArtPen, page: BoosterPage, b: BoosterOpening) -> void:
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
		var p: Vector2 = b.fan_pos(k)
		BoosterCardDraw.sun(pen, p.x + BoosterArt.CW / 2.0, p.y + b.card_h() / 2.0, s * 1.4)
		fan_card(pen, page, b, k, null)


## The particles `list` (dust, foil scraps, sparkles) on the page's clock.
static func parts(pen: ArtPen, page: BoosterPage, list: Array[Dictionary]) -> void:
	for p: Dictionary in list:
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
