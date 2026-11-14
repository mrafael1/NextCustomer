class_name StoreFlight
extends RefCounted
## OPEN STORE's flight (BuildPage, v1.32; the mock-up start_boosters_v3's startStore and
## drawStore): over the dimmed board, every cart card gathers into an arc (the pack's from its
## spread, the others from the order sheet), a dither wipe turns each into its item, the items
## drop into the cart (its count punching per landing), the last landing rings the kaching with a
## white ring of rays and one confetti burst, and the cart rolls out. A click or Enter skips to
## the end (the floor's ticker says so, lit over the dim: SKIP_HINT); then the board clocks in
## (the roller shutter plays). In art px (the mock-up's screen units / 3).

const DIM := Color("0d1716")
## The ticker's line during the flight.
const SKIP_HINT := "CLICK OR ENTER TO SKIP"
const CART_X := 320.0
## v1.36: 9 px higher, so the wheels (their lowest row ends WHEELS_BOTTOM below CART_Y, a landing's
## dip 1 px more) clear the floor's ticker.
const CART_Y := 254.0
const WHEELS_BOTTOM := 71.0
## Landed items per layer of the cart's pile (pile_slot).
const PILE_ROW := 5
const CARD_SCALE := 0.55
const CONFETTI: Array[Color] = [
	Palette.GOLD, Palette.TOMATO, Palette.TEAL, Palette.PAPER, Palette.MUSTARD_LIGHT
]

var page: BuildPage
var pack: StarterPackDefinition
var t0: float = 0.0
## The cards flying, each {card, rare, from (art px, centre), scale}.
var items: Array[Dictionary] = []
var landed: int = 0
var dip_t: float = -INF
var pop_t: float = -INF
var kaching: bool = false
var confetti: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(owner_page: BuildPage, picked_pack: StarterPackDefinition) -> void:
	page = owner_page
	pack = picked_pack
	t0 = page.now
	_rng.seed = 20261113
	var run: RunState = page.run
	var lines: Array[StartCartLine] = StartSetupRules.cart_lines(
		run.starter, run.start_offer, run.balance, run.pins, pack
	)
	var slot: int = 0
	for k: int in lines.size():
		var line: StartCartLine = lines[k]
		if line.card == null:
			continue
		var from: Vector2 = Vector2(480, 60 + k * 9.7)
		var scale: float = 0.12
		if line.source == StartCartLine.Source.PACK:
			from = Vector2(
				BuildPage.SPX[mini(slot, 2)] + BoosterArt.CW / 2.0,
				BuildPage.SPY + BoosterArt.CH / 2.0
			)
			scale = 1.0
			slot += 1
		(
			items
			. append(
				{
					"card": line.card,
					"rare": BuildPageDraw.rare(line.card, run.balance),
					"from": from,
					"scale": scale,
				}
			)
		)
	var tuning: StartBoostersTuning = page.tuning
	for i: int in items.size():
		page.cue(
			t0 + tuning.store_drop_at_s + 0.3 + i * tuning.store_item_gap_s,
			page.sfx.bind("card_place_%d" % (1 + i % 3), -10.0, 0.9 + i * 0.04)
		)


func elapsed(now: float) -> float:
	return now - t0


func done(now: float) -> bool:
	return elapsed(now) >= page.tuning.store_end_s


## Skips to the end (the shutter follows at once).
func skip(now: float) -> void:
	t0 = minf(t0, now - page.tuning.store_end_s)


## Counts the landings: a dip per landing, the kaching and the confetti on the last.
func step(now: float) -> void:
	var t: float = elapsed(now)
	var tuning: StartBoostersTuning = page.tuning
	var count: int = 0
	for i: int in items.size():
		var d0: float = tuning.store_drop_at_s + i * tuning.store_item_gap_s
		if t >= d0 + tuning.store_drop_s:
			count += 1
	if count != landed:
		landed = count
		dip_t = t
		if landed == items.size() and not kaching:
			kaching = true
			pop_t = now
			page.sfx("kaching", -2.0)
			if not page.rm:
				for k: int in 26:
					(
						confetti
						. append(
							{
								"x": CART_X + (_rng.randf() * 2 - 1) * 50,
								"y": CART_Y - 23,
								"vx": (_rng.randf() * 2 - 1) * 100,
								"vy": -83 - _rng.randf() * 67,
								"t": now,
								"c": CONFETTI[k % CONFETTI.size()],
								"s": 2 if k % 3 else 3,
								"ph": _rng.randf() * 6.3,
							}
						)
					)


func draw(pen: ArtPen) -> void:
	var now: float = page.now
	var t: float = elapsed(now)
	var tuning: StartBoostersTuning = page.tuning
	var dim: float = 0.6 if page.rm else 0.6 * clampf(t / 0.2, 0.0, 1.0)
	pen.r(0, 0, BoosterArt.AW, BoosterArt.AH, Color(DIM, dim))
	var roll: float = clampf(
		(t - tuning.store_roll_at_s) / maxf(tuning.store_roll_s, 0.001), 0.0, 1.0
	)
	var off: float = roundf(BoosterPageDraw.e_in(roll) * 434)
	var dip: float = 1.0 if t - dip_t < 0.12 else 0.0
	_cart_back(pen, CART_X + off, CART_Y + dip)
	var n: int = items.size()
	for i: int in n:
		_item(pen, i, n, t, off, dip)
	_cart_front(pen, CART_X + off, CART_Y + dip, landed)
	if not page.rm and now - pop_t < 0.25:
		var u: float = (now - pop_t) / 0.25
		var r0: float = 40 + u * 87
		for k: int in 12:
			var a: float = k / 12.0 * TAU
			var d: float = r0 - 20
			while d < r0:
				var px: float = roundf((CART_X + cos(a) * d) / 2.0) * 2.0
				var py: float = roundf((CART_Y - 7 + sin(a) * d * 0.7) / 2.0) * 2.0
				pen.r(px, py, 2, 2, Palette.PAPER if u < 0.4 else Palette.GOLD)
				d += 4
	for p: Dictionary in confetti:
		var dt: float = now - (p.t as float)
		if dt < 0.0 or dt >= 1.2:
			continue
		var fall: float = minf(dt, 0.6)
		var x: float = (
			(p.x as float) + (p.vx as float) * dt * 0.8 + sin(dt * 11 + (p.ph as float)) * 5
		)
		var y: float = (
			(p.y as float) + (p.vy as float) * fall + 233 * fall * fall + maxf(0.0, dt - 0.6) * 53
		)
		var s: float = p.s
		var flip: bool = int(floorf(dt * 12 + (p.ph as float))) % 2 == 1
		pen.r(roundf(x), roundf(y), s, s if flip else 1.0, Palette.INK)
		pen.r(roundf(x), roundf(y) - 1, s, s if flip else 1.0, p.c as Color)
	BuildPageDraw.hint_led(pen, page)


## Card `i` of `n`: gathering into the arc, wiped into its item, dropping into the cart, landed.
func _item(pen: ArtPen, i: int, n: int, t: float, off: float, dip: float) -> void:
	var tuning: StartBoostersTuning = page.tuning
	var it: Dictionary = items[i]
	var card: CardDefinition = it.card
	var from: Vector2 = it.from
	var g: float = BoosterPageDraw.e_out(
		clampf((t - i * tuning.store_item_gap_s) / maxf(tuning.store_gather_s, 0.001), 0.0, 1.0)
	)
	var mid: float = i - (n - 1) / 2.0
	var arc: Vector2 = Vector2(320 + mid * 44, 127 + pow(mid / 6.0, 2) * 23)
	var uw: float = clampf(
		(
			(t - tuning.store_wipe_at_s - i * tuning.store_item_gap_s)
			/ maxf(tuning.store_wipe_s, 0.001)
		),
		0.0,
		1.0
	)
	var dp: float = clampf(
		(
			(t - tuning.store_drop_at_s - i * tuning.store_item_gap_s)
			/ maxf(tuning.store_drop_s, 0.001)
		),
		0.0,
		1.0
	)
	var slot: Vector2 = pile_slot(i, n)
	if uw < 1.0:
		var at: Vector2 = from.lerp(arc, g)
		var sc: float = lerpf(it.scale as float, CARD_SCALE, g)
		_card(pen, card, it.rare as bool, at, sc, uw)
	if dp >= 1.0:
		_sprite(pen, card, it.rare as bool, slot + Vector2(off, dip), 0.5, t)
	elif uw > 0.0:
		var fx: float = lerpf(arc.x, slot.x, dp)
		var fy: float = (
			arc.y + (slot.y - arc.y) * BoosterPageDraw.e_in(dp) - sin(PI * dp) * 13 * (1 - dp)
		)
		_sprite(pen, card, it.rare as bool, Vector2(fx + off, fy), 1.0 if dp < 0.5 else 0.5, t)


## Where landed item `i` of `n` rests in the cart: a pile in rising layers of PILE_ROW (5), each
## layer centred and 11 art px above the one before, so the pile climbs over the basket's rim
## (CART_Y - 20) as in the mock-up and every item stays in sight.
static func pile_slot(i: int, n: int) -> Vector2:
	var layer: int = floori(float(i) / PILE_ROW)
	var count: int = mini(PILE_ROW, n - layer * PILE_ROW)
	var k: int = i % PILE_ROW
	return Vector2(
		roundf(CART_X + (k - (count - 1) / 2.0) * 22 + (layer % 2) * 4),
		CART_Y - 26 - layer * 11 + (k % 2) * 2
	)


## A card centred on `at` at `sc`, wiped away from the top by `uw` under a paper dither band.
func _card(
	pen: ArtPen, card: CardDefinition, is_rare: bool, at: Vector2, sc: float, uw: float
) -> void:
	var w: float = BoosterArt.CW * sc
	var h: float = BoosterArt.CH * sc
	var left: float = at.x - w / 2.0
	var top: float = at.y - h / 2.0
	if uw <= 0.0:
		BoosterCardDraw.draw(
			pen,
			card,
			is_rare,
			at.x - BoosterArt.CW / 2.0,
			at.y - BoosterArt.CH / 2.0,
			{"scale": sc, "still": true}
		)
		return
	# The face's paper fades out with the wipe (v1.36: its blank lower half used to linger as a
	# white rectangle under the flying item), the dither band thinning with it.
	var cut: float = roundf(BoosterArt.CH * uw)
	var face: ImageTexture = BoosterArt.face(card, is_rare)
	var shown: float = BoosterArt.CH - cut
	if shown > 0:
		pen.canvas.draw_texture_rect_region(
			face,
			Rect2(pen.at(left, top + cut * sc), Vector2(w, shown * sc) * pen.unit),
			Rect2(0, cut, BoosterArt.CW, shown),
			Color(1, 1, 1, 1.0 - uw)
		)
	pen.d(left - 1, top + cut * sc - 6, w + 2, 6, Palette.PAPER, roundi(8 * (1.0 - uw)))


func _sprite(
	pen: ArtPen, card: CardDefinition, is_rare: bool, at: Vector2, scale: float, t: float
) -> void:
	var texture: Texture2D = BoosterChromeDraw.sprite(card)
	if texture == null:
		return
	var half: Vector2 = (texture.get_size() * scale / 2.0).round()
	pen.tex(texture, at.x - half.x, at.y - half.y, Color.WHITE, scale)
	if is_rare and int(floorf(t * 8)) % 2 == 0:
		pen.tex_c(BoosterArt.SPARKLE, at.x + 10, at.y - 10)


func _cart_back(pen: ArtPen, x: float, y: float) -> void:
	var left: float = roundf(x - 70)
	var top: float = y - 20
	pen.r(left - 2, top - 2, 144, 3, Palette.INK)
	pen.r(left, top - 1, 140, 1, Palette.TEAL_LIGHT)


## The cart's basket (a wire trapezoid), rim, handle, legs, wheels and its count box.
func _cart_front(pen: ArtPen, x: float, y: float, count: int) -> void:
	var bw: float = 140.0
	var left: float = roundf(x - bw / 2.0)
	var top: float = roundf(y - 20)
	var bot: float = roundf(y + 40)
	var rows: float = bot + 2 - top
	var row: float = top
	while row < bot + 2:
		var inset: float = roundf(10 * (row - top) / rows)
		pen.r(left - 2 + inset, row, bw + 4 - inset * 2, 1, Palette.INK)
		if row < bot:
			var i0: float = left + inset
			var i1: float = left + bw - inset
			pen.r(i0, row, i1 - i0, 1, Color(Palette.TEAL, 0.35))
			if int(row - top - 10) % 14 < 2:
				pen.r(i0, row, i1 - i0, 1, Palette.TEAL)
			else:
				var gx: float = left + 4
				while gx < i1:
					if gx >= i0:
						pen.r(gx, row, 2, 1, Palette.TEAL)
					gx += 8
		row += 1
	pen.r(left - 2, top - 1, bw + 4, 4, Palette.TEAL)
	pen.r(left - 2, top - 1, bw + 4, 1, Palette.TEAL_LIGHT)
	pen.r(left + 8, bot, bw - 16, 4, Palette.TEAL_SHADE)
	pen.r(left + bw + 2, top - 16, 4, 20, Palette.INK)
	pen.r(left + bw + 3, top - 15, 2, 18, Palette.TEAL)
	pen.r(left + bw + 2, top - 18, 20, 5, Palette.INK)
	pen.r(left + bw + 3, top - 17, 18, 3, Palette.TOMATO)
	pen.r(left + 10, bot + 4, 2, 14, Palette.INK)
	pen.r(left + bw - 12, bot + 4, 2, 14, Palette.INK)
	pen.r(left + 8, bot + 16, bw - 16, 3, Palette.INK)
	for wx: float in [left + 18, left + bw - 18]:
		_wheel(pen, wx, bot + 24)
	pen.rb(left + bw / 2.0 - 22, top + 18, 44, 22, Palette.PAPER)
	pen.chunky(str(count), left + bw / 2.0, top + 22, Palette.INK, 2.0, HORIZONTAL_ALIGNMENT_CENTER)


func _wheel(pen: ArtPen, cx: float, cy: float) -> void:
	for dy: int in range(-6, 7):
		var hw: float = floorf(sqrt(maxf(0.0, 36 - dy * dy)))
		pen.r(cx - hw, cy + dy, hw * 2 + 1, 1, Palette.INK)
		if absi(dy) <= 3:
			var mw: float = floorf(sqrt(maxf(0.0, 9 - dy * dy)))
			pen.r(cx - mw, cy + dy, mw * 2 + 1, 1, Palette.STEEL)
