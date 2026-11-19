class_name AisleRoulette
extends RefCounted
## The aisle board's roulette (YOUR STORE, v1.44; mock-up docs/art/mockups/start_roulette.html,
## variant A): a light runs along the open bays, slows and lands on today's first aisle, then on
## the second; the other bays roll their shutters down, and each open bay
## throws its booster to its card row's start, beside the row's aisle tab, where it waits sealed
## for the player's click (the user's play test of 2026-11-19, round 2: no booster opens by
## itself; round 3: it waits beside its row). It only plays the result: the
## aisles and the boosters were dealt (and saved) before the page shows, on the run's own streams,
## and nothing here draws on them. A locked aisle's bay is shut behind a padlock from the start
## and the light never visits it. A click skips to the end. The guided first run, a resumed page
## and reduced motion show the landed bays at once, without the run of the light.

enum Phase { WAIT, SPIN, DEAL }

## The tag of every cue a skip drops.
const TAG := "roulette"
## Where a bay throws its booster from, below the bay's top (art px).
const THROW_DY := 62

var page: BoosterPage
var phase: Phase = Phase.WAIT
## How many bays the board has (the balance's aisles), which are locked for the profile.
var count: int = 0
var locked: Array[bool] = []
## Each bay's landing (stage clock, s) once the light landed on it, and when its shutter started
## down (-INF: down from the start).
var land_t: Dictionary[int, float] = {}
var shut_t: Dictionary[int, float] = {}
## The light's hops, each {t, bay}, when the chase starts (INF: no chase) and ends.
var hops: Array[Dictionary] = []
var spin_t: float = INF
var chase_end: float = -INF
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(owner_page: BoosterPage) -> void:
	page = owner_page


## Sets the board up for the page's run: the bays, the locked ones, each booster's bay; then the
## run of the light, or (the guided first run, a resume, reduced motion) the landed bays at once.
func setup() -> void:
	var balance: BalanceDefinition = page.run.balance
	count = balance.aisles.size()
	locked.clear()
	land_t.clear()
	shut_t.clear()
	hops.clear()
	spin_t = INF
	chase_end = -INF
	# A cosmetic stream of its own (where the light starts, which aisle lands first).
	_rng.seed = hash(page.run.run_seed) ^ 0x51A7
	for aisle: AisleDefinition in balance.aisles:
		locked.append(not RunStock.is_listable(aisle, balance, page.profile.unlocked_items))
	var any_open: bool = false
	for b: BoosterOpening in page.boosters:
		b.bay = bay_of(b.aisle)
		any_open = any_open or b.state == BoosterOpening.State.OPEN or b.restocked
	layout()
	var start: StartSetup = page.run.start_setup
	var still: bool = page.rm or page.run.guided or any_open
	still = still or start.stage == StartSetup.Stage.BUILD or ring().size() < 2
	if still:
		_show_landed()
		_deal(0.0 if page.rm else page.tuning.fixed_throw_at_s)
		return
	phase = Phase.WAIT
	page.fx.cue(page.now + page.tuning.spin_delay_s, spin, TAG)


## The bay of aisle `id` (-1: not on the board).
func bay_of(id: StringName) -> int:
	var aisles: Array[AisleDefinition] = page.run.balance.aisles
	for k: int in aisles.size():
		if aisles[k].id == id:
			return k
	return -1


## The bays the light can visit (not locked), left to right.
func ring() -> Array[int]:
	var open: Array[int] = []
	for k: int in count:
		if not locked[k]:
			open.append(k)
	return open


## The bays of the boosters on show (today's aisles), left to right.
func target_bays() -> Array[int]:
	var bays: Array[int] = []
	for b: BoosterOpening in page.boosters:
		if b.bay >= 0:
			bays.append(b.bay)
	bays.sort()
	return bays


## The booster in front of bay `bay`, or null.
func booster_at(bay: int) -> BoosterOpening:
	for b: BoosterOpening in page.boosters:
		if b.bay == bay:
			return b
	return null


## Centres each kept booster's pouch (and a full-card fan) under its own bay
## (AisleBoardArt.fan_centres): the left fan is the left bay's, and its compact cards take the top
## row (BoosterOpening.row), the right bay's the bottom one.
func layout() -> void:
	var kept: Array[BoosterOpening] = []
	for b: BoosterOpening in page.boosters:
		if b.bay >= 0:
			kept.append(b)
	kept.sort_custom(func(a: BoosterOpening, z: BoosterOpening) -> bool: return a.bay < z.bay)
	var bays: Array[int] = []
	for b: BoosterOpening in kept:
		bays.append(b.bay)
	var centres: Array[float] = AisleBoardArt.fan_centres(bays, count)
	for k: int in kept.size():
		kept[k].cx = centres[k]
		kept[k].row = mini(k, 1)


## Whether bay `bay` is one of today's (lit, its shutter up).
func is_target(bay: int) -> bool:
	return target_bays().has(bay)


func _show_landed() -> void:
	for k: int in count:
		if is_target(k):
			land_t[k] = -10.0
		else:
			shut_t[k] = -INF
	chase_end = page.now


## The run of the light: over every open bay to the first aisle, then over the rest to the next
## (the order and the start are cosmetic), each run slowing to its landing.
func spin() -> void:
	if phase != Phase.WAIT:
		return
	phase = Phase.SPIN
	spin_t = page.now
	hops.clear()
	var tuning: StartBoostersTuning = page.tuning
	var order: Array[int] = target_bays()
	for k: int in range(order.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, k)
		var held: int = order[k]
		order[k] = order[j]
		order[j] = held
	var open: Array[int] = ring()
	var start: int = _rng.randi_range(0, open.size() - 1)
	var t: float = 0.0
	for n: int in order.size():
		if n == 0:
			t = _run(open, start, order[n], tuning.spin_first_hops, tuning.spin_first_s, 0.0)
		else:
			var at: int = open.find(order[n - 1])
			open.remove_at(at)
			t = _run(
				open,
				posmod(at - 1, maxi(1, open.size())),
				order[n],
				tuning.spin_next_hops,
				tuning.spin_next_s,
				t + tuning.spin_pause_s
			)
	chase_end = page.now + t + 0.02
	page.fx.cue(page.now + t + tuning.spin_close_at_s, _after_spin, TAG)


## One chase over `open` from place `start`, landing on bay `target` after at least `min_hops`
## hops within `total` s, from `t0` s after now: the gaps grow geometrically and the last one
## hangs. Returns when it lands (s after now).
func _run(
	open: Array[int], start: int, target: int, min_hops: int, total: float, t0: float
) -> float:
	var tuning: StartBoostersTuning = page.tuning
	var size: int = maxi(1, open.size())
	var hop_count: int = min_hops + posmod(open.find(target) - start - min_hops, size)
	if size == 1:
		# One bay left for the light: it lands at once.
		hop_count = 1
		total = minf(total, tuning.spin_pause_s)
	var first: float = tuning.spin_first_gap_s if t0 <= 0.0 else tuning.spin_next_gap_s
	var gaps: Array[float] = hop_gaps(hop_count, total, first)
	gaps[hop_count - 1] *= tuning.spin_last_stretch
	var t: float = t0
	for i: int in hop_count:
		t += gaps[i]
		var u: float = float(i) / maxi(1, hop_count - 1)
		hops.append({"t": page.now + t, "bay": open[posmod(start + i + 1, size)]})
		page.fx.cue(
			page.now + t, page.fx.sfx.bind("slot_tick", -10.0 + u * 4.0, 1.5 - u * 0.6), TAG
		)
	page.fx.cue(page.now + t + 0.02, land.bind(target, 1.0 if t0 <= 0.0 else 1.12), TAG)
	return t


## `n` hop gaps starting at `first` that grow geometrically and add up to `total` (the mock-up's
## gaps()).
static func hop_gaps(n: int, total: float, first: float) -> Array[float]:
	var out: Array[float] = []
	if n <= 1:
		out.append(total)
		return out
	var lo: float = 1.0001
	var hi: float = 3.0
	for i: int in 50:
		var g: float = (lo + hi) / 2.0
		if first * (pow(g, n) - 1.0) / (g - 1.0) > total:
			hi = g
		else:
			lo = g
	var v: float = first
	for i: int in n:
		out.append(v)
		v *= lo
	return out


## The light lands on bay `bay`: the bell, the stamp, the sign's punch.
func land(bay: int, pitch: float = 1.0) -> void:
	land_t[bay] = page.now
	page.fx.sfx("register_bell", -9.0, pitch)
	page.fx.sfx("stamp_1", -8.0)
	var sign_at: Rect2 = AisleBoardArt.sign_rect(bay, count)
	page.fx.sparkles(
		sign_at.position.x, sign_at.position.y, sign_at.size.x, sign_at.size.y, page.now, 0.07
	)


## After the last landing: the other bays shut, then the boosters come out.
func _after_spin() -> void:
	var tuning: StartBoostersTuning = page.tuning
	var n: int = 0
	for k: int in count:
		if not locked[k] and not is_target(k):
			_shut(k, n * tuning.shutter_gap_s)
			n += 1
	_deal(tuning.throw_at_s)


## Bay `bay`'s shutter rolls down `delay` s from now and thuds on the counter.
func _shut(bay: int, delay: float) -> void:
	var tuning: StartBoostersTuning = page.tuning
	if page.rm:
		shut_t[bay] = -INF
		return
	shut_t[bay] = page.now + delay
	page.fx.cue(page.now + delay, page.fx.sfx.bind("rattle_m", -12.0, 1.2), TAG)
	var x: float = AisleBoardArt.bay_x(bay, count)
	var w: float = AisleBoardArt.bay_w(count)
	page.fx.cue(
		page.now + delay + tuning.shutter_down_s,
		func() -> void:
			page.fx.dust(x + 20, AisleBoardArt.STAND, 2)
			page.fx.dust(x + w - 20, AisleBoardArt.STAND, 2)
			page.fx.sfx("card_place_2", -8.0, 0.6),
		TAG
	)


## The open bays throw their boosters, left to right, the first `at` s from now; each waits
## sealed on the counter once it has landed.
func _deal(at: float) -> void:
	phase = Phase.DEAL
	layout()
	var tuning: StartBoostersTuning = page.tuning
	var n: int = 0
	for bay: int in target_bays():
		var b: BoosterOpening = booster_at(bay)
		if b == null or b.state != BoosterOpening.State.SEALED or b.fly_t != INF:
			continue
		if page.rm:
			throw(b)
		else:
			page.fx.cue(page.now + at + n * tuning.throw_gap_s, throw.bind(b), TAG)
		n += 1


## Bay `b.bay` throws booster `b` to its row's start, beside the row's aisle tab
## (BoosterOpening.pouch_pos), where it waits sealed for its click.
func throw(b: BoosterOpening) -> void:
	var tuning: StartBoostersTuning = page.tuning
	var at: Vector2 = b.pouch_pos()
	var mid: float = at.x + BoosterArt.BW / 2.0
	var foot: float = minf(at.y + BoosterArt.BH, AisleBoardArt.STAND)
	b.fly_from = Vector2(AisleBoardArt.bay_centre(b.bay, count), AisleBoardArt.BAY_Y + THROW_DY)
	if page.rm:
		b.fly_t = -10.0
		return
	b.fly_t = page.now
	page.fx.sfx("rattle_s", -8.0)
	page.fx.cue(
		page.now + tuning.throw_s,
		func() -> void:
			page.fx.dust(mid - 30, foot, 3)
			page.fx.dust(mid + 30, foot, 3)
			page.fx.sfx("card_place_1", -4.0, 0.7)
			page.fx.sfx("tag", -10.0),
		TAG
	)


## Whether booster `b` has landed on the counter (thrown and its flight over).
func landed(b: BoosterOpening) -> bool:
	return b.fly_t != INF and page.now >= b.fly_t + page.tuning.throw_s


## Whether the board is still arriving: the light runs, or a booster is on its way out (not
## thrown yet, or still in the air).
func busy() -> bool:
	if phase == Phase.WAIT or phase == Phase.SPIN:
		return true
	if phase == Phase.DEAL:
		for b: BoosterOpening in page.boosters:
			if b.state == BoosterOpening.State.SEALED:
				if not landed(b):
					return true
	return false


## Skips to the end (a click, Enter): every bay landed, the others shut, no late cues; the
## boosters stand sealed on the counter, waiting for their clicks.
func skip() -> bool:
	if not busy():
		return false
	page.fx.drop_cues(TAG)
	for k: int in count:
		if is_target(k):
			land_t[k] = minf(land_t.get(k, INF), page.now - 1.0)
		else:
			shut_t[k] = -INF
	chase_end = page.now
	phase = Phase.DEAL
	layout()
	for b: BoosterOpening in page.boosters:
		if b.state == BoosterOpening.State.SEALED:
			b.fly_from = Vector2(
				AisleBoardArt.bay_centre(b.bay, count), AisleBoardArt.BAY_Y + THROW_DY
			)
			b.fly_t = minf(b.fly_t, page.now - 10.0)
			b.return_t = INF
	return true


## The bay the light is on now (-1: none).
func chase_bay() -> int:
	if page.now >= chase_end:
		return -1
	var bay: int = -1
	for hop: Dictionary in hops:
		if (hop.t as float) <= page.now:
			bay = hop.bay
		else:
			break
	return bay


## How far bay `bay`'s shutter is down (0: up, 1: down, a little more while it bounces).
func shut_frac(bay: int) -> float:
	if locked[bay]:
		return 1.0
	if not shut_t.has(bay):
		return 0.0
	var tuning: StartBoostersTuning = page.tuning
	var age: float = page.now - shut_t[bay]
	if age < 0.0:
		return 0.0
	if age < tuning.shutter_down_s:
		return BoosterPageDraw.e_in(age / maxf(tuning.shutter_down_s, 0.001))
	var v: float = (age - tuning.shutter_down_s) / maxf(tuning.shutter_bounce_s, 0.001)
	return 1.0 - 0.035 * sin(PI * v) if v < 1.0 else 1.0


## A RESTOCK's staging for booster `b` (already dealt again and sealed): its old cards turn over
## and fly back into its bay, the bay's sign punches, and it throws the fresh booster.
func restock(b: BoosterOpening) -> void:
	var tuning: StartBoostersTuning = page.tuning
	phase = Phase.DEAL
	b.fly_t = INF
	b.fly_from = Vector2(AisleBoardArt.bay_centre(b.bay, count), AisleBoardArt.BAY_Y + THROW_DY)
	if page.rm:
		b.return_t = INF
		page.fx.sfx("shuffle", -6.0)
		throw(b)
		return
	b.return_t = page.now
	page.fx.sfx("shuffle", -8.0)
	for k: int in b.old_cards.size():
		page.fx.cue(
			page.now + 0.06 + k * tuning.restock_flip_s, page.fx.sfx.bind("card_return", -6.0), TAG
		)
	page.fx.cue(
		page.now + tuning.restock_land_at_s,
		func() -> void:
			land_t[b.bay] = page.now
			page.fx.sfx("stamp_1", -8.0),
		TAG
	)
	page.fx.cue(page.now + tuning.restock_land_at_s + tuning.restock_throw_at_s, throw.bind(b), TAG)
