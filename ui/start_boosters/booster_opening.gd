class_name BoosterOpening
extends RefCounted
## One aisle booster on YOUR STORE (v1.32, mock-up docs/art/mockups/start_boosters_v3.html): its
## place on the counter and its cosmetic opening on its own clock (`lt`), so a skip plays it
## `boost` times as fast and OPEN ALL offsets each booster. The rules (what it holds, whether it
## is opened, SOLD OUT or restocked) are StartBooster's in the run's setup; this only plays them.
## The plan (the mock-up's buildPlan): the commons flip by themselves on a rising note ladder, the
## hit card rises, trembles and then waits for a click (TAP IT) unless the opening is fast (OPEN
## ALL, a skip), and a RARE flips last with its own beat.

enum State { SEALED, OPENING, OPEN, GONE }
enum Beat { COMMON, HEAVY, RARE }

var index: int = 0
var aisle: StringName = &""
var cards: Array[CardDefinition] = []
var hits: Array[bool] = []
var rares: Array[bool] = []
var state: State = State.SEALED
## The booster's centre (art px), and where a move to its zone started and goes.
var cx: float = 0.0
## The booster's own clock (s) while it opens, and how fast it runs (a skip's boost).
var lt: float = 0.0
var boost: float = 1.0
## When it drops from the ceiling (stage clock, s; INF: not yet).
var drop_t: float = INF
var restocked: bool = false
var open_order: int = 0
## The plan: each card's flip time, beat, anticipation start and whether it waits for a click.
var flip_at: Array[float] = []
var beats: Array[Beat] = []
var antic: Array[float] = []
var waits: Array[bool] = []
var specials: Array[int] = []
var plain_end: float = 0.0
var fast: bool = false
var rm: bool = false
## Stage-clock times: each card's landing (and note), the tear flash, the hover start.
var land_t: Array[float] = []
var notes: Array[int] = []
var flash_t: float = -INF
var hover_t: float = -INF
var hovered: bool = false
## PICK 2 OF 3: picked (and when), SOLD OUT (when its stamp lands), when it sinks away.
var picked: bool = false
var pick_t: float = -INF
var sold_t: float = INF
var sink_t: float = INF
## A move to its zone after the pick: from, to, start (stage clock) and length.
var move_from: float = 0.0
var move_to: float = 0.0
var move_t0: float = INF
var move_s: float = 0.0
## Its lamp: on at, off at, last hot at, a flick at (stage clock).
var lamp_on: float = INF
var lamp_off: float = INF
var lamp_hot_t: float = -INF
var lamp_flick: float = -INF


func _init(booster: StartBooster, booster_index: int, centre: float) -> void:
	index = booster_index
	cx = centre
	take(booster)


## Takes the booster's cards and flags (a deal, a RESTOCK).
func take(booster: StartBooster) -> void:
	aisle = booster.aisle
	cards = booster.cards.duplicate()
	hits.clear()
	rares.clear()
	land_t.clear()
	notes.clear()
	for k: int in cards.size():
		hits.append(booster.is_hit(k))
		rares.append(booster.is_rare(k))
		land_t.append(-INF)
		notes.append(-1)
	restocked = booster.restocked


## Shown already open at rest (a resume, or coming back from page 2): every card face up.
func show_open() -> void:
	state = State.OPEN
	rm = true
	boost = 1.0
	flip_at.clear()
	beats.clear()
	antic.clear()
	waits.clear()
	specials.clear()
	for k: int in cards.size():
		flip_at.append(-1.0)
		beats.append(Beat.RARE if rares[k] else (Beat.HEAVY if hits[k] else Beat.COMMON))
		antic.append(INF)
		waits.append(false)
	plain_end = 0.0
	lt = 10.0


## The opening plan (the mock-up's buildPlan): `is_fast` for OPEN ALL and skips, `auto_hit` flips
## the hit card by itself, `reduced` fades it open at once.
func build_plan(tuning: StartBoostersTuning, is_fast: bool, auto_hit: bool, reduced: bool) -> void:
	fast = is_fast
	rm = reduced
	flip_at.clear()
	beats.clear()
	antic.clear()
	waits.clear()
	specials.clear()
	for k: int in cards.size():
		flip_at.append(0.0)
		beats.append(Beat.RARE if rares[k] else (Beat.HEAVY if hits[k] else Beat.COMMON))
		antic.append(INF)
		waits.append(false)
	if reduced:
		for k: int in cards.size():
			flip_at[k] = 0.03 + k * 0.05
		plain_end = 0.2
		return
	var step: float = tuning.open_all_flip_s if fast else tuning.flip_step_s
	var plain: Array[int] = []
	for k: int in cards.size():
		if hits[k] or rares[k]:
			specials.append(k)
		else:
			plain.append(k)
	for j: int in plain.size():
		flip_at[plain[j]] = tuning.spread_end_s + j * step
	var after: float = tuning.spread_end_s + maxi(0, plain.size() - 1) * step + tuning.flip_s + 0.02
	for k: int in specials:
		antic[k] = after
		var wait: bool = hits[k] and not auto_hit
		waits[k] = wait
		var lead: float = (
			0.05 if fast else tuning.hit_hang_s + (tuning.hit_tremble_s if hits[k] else 0.12)
		)
		flip_at[k] = INF if wait else after + lead
		var rest: float = tuning.rare_rest_s if rares[k] else tuning.heavy_rest_s
		after = (after + lead if wait else flip_at[k]) + tuning.flip_s + rest
	plain_end = tuning.spread_end_s + plain.size() * step


## The card waiting for its click (-1: none).
func waiting_k() -> int:
	return waits.find(true)


## Whether the waiting hit card has risen and waits at rest for its click.
func at_rest(tuning: StartBoostersTuning) -> bool:
	var k: int = waiting_k()
	return k >= 0 and lt >= antic[k] + tuning.hit_hang_s


func land_end(k: int, tuning: StartBoostersTuning) -> float:
	if flip_at[k] == INF:
		return INF
	var rest: float = 0.12
	if beats[k] == Beat.RARE:
		rest = tuning.rare_rest_s + 0.3
	elif beats[k] == Beat.HEAVY:
		rest = tuning.heavy_rest_s
	return flip_at[k] + tuning.flip_s + rest


func plan_end(tuning: StartBoostersTuning) -> float:
	var end: float = tuning.rm_fade_s + 0.15 if rm else tuning.spread_end_s
	for k: int in cards.size():
		end = maxf(end, land_end(k, tuning))
	return end


## Flips the waiting hit card `k` (its click): it turns at once, from its rest.
func reveal_hit(k: int) -> bool:
	if k < 0 or k >= waits.size() or not waits[k]:
		return false
	waits[k] = false
	flip_at[k] = maxf(lt, antic[k]) + 0.06
	return true


## Whether the card k has landed face up.
func landed(k: int, tuning: StartBoostersTuning) -> bool:
	if state == State.OPEN:
		return true
	if state != State.OPENING:
		return false
	return flip_at[k] != INF and lt >= flip_at[k] + tuning.flip_s


func is_counted() -> bool:
	return state != State.GONE and sold_t == INF
