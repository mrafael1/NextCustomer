class_name CheckoutCrowd
extends Control
## The checkout cheering (#120, mock-up docs/art/mockups/checkout_cheering.html, the user's
## answers of 2026-10-30): cardboard promo standees pop up behind the counter as the items pay
## and grow into a crowd over the checkout. Decor only: it reads the count-up's plan (each payout
## beat's cheer tier and count, CountUpPlan) and never scores.
##
## Where (ShiftStage builds it in the world, over the back wall, the store sections and the
## RECEIPT REWARDS machine, under the monitor and the fore): anywhere in the band from the top
## bar's foot down to the counter's top (FOOT_Y, where it clips, so the standees' legs and easel
## stay hidden behind the belt and the counter), across the whole visible width, the extra wall
## of a window wider than 16:9 included (refitted at every pop, so a resized window keeps it).
## Never in front of `avoid` (the hung monitor with its rods and under-strip): a standee there
## only peeks below it, down to the belt's top, and its ink never reaches it, hops included.
## Placement is seeded per checkout (from its plan, never the global RNG): of CANDIDATES x
## positions the one with the most room wins, so new standees fill the gaps before they overlap,
## and later ones layer over the earlier; ink hidden behind `cover` (the receipt column, the bag)
## costs room, so open wall wins until it is crowded, but no spot is off-limits.
##
## When: every paid item pops cheer_count standees (one more and bigger as the payout is bigger
## or a combo, CountUpTuning's cheer_*), the first at its tier's scale, with card_place pitched
## up per standee and tier, each rising into a hop as high as its tier and the ladder's note
## (a crowd-wide hop leaves a standee alone while its pop runs); a payout of 0 (WASTED, denied)
## slumps the newest one (card_return); the ding makes everyone hop; a passed verdict hops them
## all, then folds them down before the printer feed; a missed one sinks them. The printer feed
## and the count's end hard-hide the crowd, a new count clears it, and a resumed checkout
## (CountUp.show_end_state) shows none.
##
## Motion runs on the count-up's tweens (tween_maker: the ding's hit-stop freezes it, taps and
## holds speed it up), one tween per standee, killed and replaced, never stacked; reduced motion
## makes standees appear and go at once, with no hop.

## The art (art/src/standees/): each design's rest frame, and its arms-up cheer frame at the same
## index.
const REST_FRAMES: Array[Texture2D] = [
	preload("res://art/standees/standee_sale.png"),
	preload("res://art/standees/standee_milk.png"),
	preload("res://art/standees/standee_mascot.png"),
	preload("res://art/standees/standee_milk_green.png"),
	preload("res://art/standees/standee_mascot_red.png"),
]
const CHEER_FRAMES: Array[Texture2D] = [
	preload("res://art/standees/standee_sale_cheer.png"),
	preload("res://art/standees/standee_milk_cheer.png"),
	preload("res://art/standees/standee_mascot_cheer.png"),
	preload("res://art/standees/standee_milk_green_cheer.png"),
	preload("res://art/standees/standee_mascot_red_cheer.png"),
]
## The band the crowd stands in, in stage px: from the top bar's foot down to the counter's top.
const TOP_Y := ShiftStage.TOP_BAR_BOTTOM
const FOOT_Y := ShiftStage.COUNTER_TOP
## The art row (art px) on the foot line when a standee stands: just under the figure's belt.
const STAND_ROW := 56
## A standee stands up to this many art rows lower (seeded), for depth.
const STAND_JITTER_ROWS := 4
## Under `avoid` a standee only peeks; where it would show less than this it goes elsewhere.
const MIN_PEEK_PX := 40.0
## Over the belt's columns the belt and the row in front hide the crowd below the belt's top
## (stage px): a peek is measured to it.
const BELT_RECT := ShiftStage.BELT_RECT
## Room kept for the pop's back-ease overshoot above a peeking standee.
const OVERSHOOT_PX := 8.0
## Candidate x positions tried per standee.
const CANDIDATES := 16
## A candidate's room counts its sinking under `avoid` this many times over: a standee peeks under
## the monitor only when the open wall is crowded (a big one would hide its size there).
const SINK_COST := 2.0
## A candidate's room shrinks with the square of the share of its standing ink that shows past
## `cover` (half hidden keeps a quarter of its room), and loses this many px more for all of it
## hidden (a share of it for a share): a hidden spot wins only when every open one overlaps a
## standee by more than that (a crowded wall).
const COVER_COST_PX := 48.0
const GRID := CheerStandee.GRID

## The rects no standee's ink may reach (stage px): the hung monitor, its rods and under-strip
## (set in _init; a redrawn scene may change them).
var avoid: Array[Rect2] = []
## The foreground in front of the crowd (stage px): the receipt column at its full height and the
## paper bag (set in _init). Placement prefers ink that shows; a spot behind them is still open.
var cover: Array[Rect2] = []
## The visible width (stage px), read at every pop: the viewport's by default.
var view_width: Callable
## Makes the standees' tweens (CountUp.tween_maker once it follows a count-up).
var make_tween: Callable
var reduced_motion: bool = false
var _tuning: CountUpTuning
var _count_up: CountUp
## The standees up, oldest first.
var _standees: Array[CheerStandee] = []
## The payout beat that started last and pays above 0 (it pops at payout_landed).
var _pending: CountUpBeat
## The ladder's note of the latest gain beat.
var _note: int = 0
## Standees popped this checkout (they take the designs in turn).
var _popped: int = 0
var _design_offset: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(tuning: CountUpTuning = null) -> void:
	name = "CheckoutCrowd"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visible = false
	make_tween = create_tween
	var monitor: Rect2 = ShiftStage.MONITOR_RECT.merge(ShiftStage.MONITOR_UNDER_RECT)
	for rod: Rect2 in ShiftStage.ROD_RECTS:
		monitor = monitor.merge(rod)
	avoid = [monitor]
	var receipt := Rect2(
		ShiftStage.RECEIPT_X,
		ShiftStage.RECEIPT_TOP,
		ShiftStage.RECEIPT_WIDTH,
		ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
	)
	cover = [receipt, ShiftStage.BAG_RECT]
	view_width = func() -> float: return get_viewport_rect().size.x
	_tuning = tuning if tuning != null else load(CountUp.TUNING_PATH) as CountUpTuning
	position = Vector2(0.0, TOP_Y)
	size = Vector2(ShiftStage.SIZE.x, FOOT_Y - TOP_Y)


## Cheers along with `count_up`'s checkouts, on its tweens.
func follow(count_up: CountUp) -> void:
	_count_up = count_up
	make_tween = count_up.tween_maker()
	count_up.count_started.connect(func(_views: Array[CardView]) -> void: _on_count_started())
	count_up.beat_started.connect(_on_beat_started)
	count_up.payout_landed.connect(_on_payout_landed)
	count_up.quota_met.connect(_on_quota_met)
	count_up.total_landed.connect(_on_total_landed)
	count_up.printer_feed.connect(clear)
	count_up.finished.connect(clear)


## A new checkout: the crowd empties and spans the visible width; `seed_value` places it.
func begin(seed_value: int, reduced: bool) -> void:
	clear()
	visible = true
	reduced_motion = reduced
	_rng.seed = seed_value
	_note = 0
	_popped = 0
	_design_offset = _rng.randi_range(0, REST_FRAMES.size() - 1)
	_fit_band()


## Pops `count` standees for a payout of `tier` (the first at its tier's scale), each hopping
## for the ladder's `note` (-1: the latest gain beat's).
func pop(tier: int, count: int, note: int = -1) -> void:
	_fit_band()
	var hop_px: float = _hop_px(tier, note if note >= 0 else _note)
	for index: int in range(count):
		if _standees.size() >= _tuning.cheer_max:
			hop_all()
			return
		var scale_factor: int = _scale_of(tier if index == 0 else 1)
		var design: int = (_design_offset + _popped) % REST_FRAMES.size()
		_popped += 1
		var standee: CheerStandee = CheerStandee.new(
			REST_FRAMES[design], CHEER_FRAMES[design], scale_factor, tier
		)
		standee.foot_y = size.y
		add_child(standee)
		_place(standee)
		_standees.append(standee)
		var pitch: float = _tuning.cheer_pitch_base + _tuning.cheer_pitch_step * (index + tier - 1)
		if reduced_motion:
			standee.level = 1.0
			_play("card_place", pitch)
			continue
		var tween: Tween = _restart(standee)
		standee.popping = true
		tween.tween_interval(index * _tuning.cheer_stagger_ms / 1000.0)
		tween.tween_callback(_play.bind("card_place", pitch))
		tween.tween_callback(standee.set_cheering.bind(true))
		(
			tween
			. tween_property(standee, "level", 1.0, _tuning.cheer_pop_ms / 1000.0)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
		_hop(tween, standee, hop_px)
		tween.tween_callback(standee.end_pop)


## A payout of 0: the newest standee sags, then sinks out of sight (an "aww").
func slump() -> void:
	if _standees.is_empty():
		return
	var standee: CheerStandee = _standees.pop_back()
	_play("card_return", 1.0)
	if reduced_motion:
		_drop(standee)
		return
	var tween: Tween = _restart(standee)
	standee.set_cheering(false)
	tween.tween_property(standee, "hop", -_tuning.cheer_slump_px, _tuning.cheer_slump_ms / 1000.0)
	_sink(tween, standee)


## Everyone hops (the ding, a full crowd's pop), as high as the tier and the ladder's note say;
## a standee whose pop still runs keeps it (its own hop is on the way).
func hop_all() -> void:
	if reduced_motion:
		return
	for standee: CheerStandee in _standees:
		if not standee.popping:
			_hop(_restart(standee), standee, _hop_px(standee.tier, _note))


## A missed verdict: the whole crowd sinks.
func sink_all() -> void:
	if not _standees.is_empty():
		_play("card_return", 1.0)
	for standee: CheerStandee in _standees.duplicate():
		_standees.erase(standee)
		if reduced_motion:
			_drop(standee)
		else:
			_sink(_restart(standee), standee)


## A passed verdict: everyone hops, then folds down cheer_fold_delay_ms later.
func cheer_and_fold() -> void:
	if reduced_motion:
		return
	for standee: CheerStandee in _standees:
		var tween: Tween = _restart(standee)
		_hop(tween, standee, _hop_px(standee.tier, _note))
		var waited: float = _tuning.cheer_fold_delay_ms / 1000.0 - _hop_s()
		tween.tween_interval(maxf(0.0, waited))
		tween.tween_property(standee, "fold", 0.0, _tuning.cheer_fold_ms / 1000.0).set_ease(
			Tween.EASE_IN
		)


## The crowd goes at once (the printer feed, the count's end, a new count).
func clear() -> void:
	for standee: CheerStandee in _standees.duplicate():
		_drop(standee)
	_standees.clear()
	for child: Node in get_children():
		if child is CheerStandee:
			_drop(child as CheerStandee)
	_pending = null
	visible = false


## The standees up, oldest first.
func standees() -> Array[CheerStandee]:
	return _standees.duplicate()


## Every standee's ink that can show, in the crowd's parent's coordinates (stage px).
func standee_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for child: Node in get_children():
		var standee: CheerStandee = child as CheerStandee
		if standee != null:
			var rect: Rect2 = standee.visible_rect()
			rects.append(Rect2(rect.position + position, rect.size))
	return rects


## The highest a standee of `tier` can hop, in px (the ladder's top note).
func max_hop(tier: int) -> float:
	return _hop_px(tier, maxi(0, _tuning.note_count - 1))


func _on_count_started() -> void:
	var plan: CountUpPlan = _count_up.plan
	begin(hash([plan.total, plan.step_count, plan.best, plan.beats.size()]), plan.reduced_motion)


func _on_quota_met(with_pop: bool) -> void:
	if with_pop:
		hop_all()


func _on_beat_started(
	beat: CountUpBeat, _step: ScoreStep, _line: String, _view: CardView, _items: int
) -> void:
	if beat.note >= 0:
		_note = beat.note
	if not CountUpPlan.is_payout_beat(beat):
		return
	if beat.cheer_count > 0:
		_pending = beat
	else:
		slump()


func _on_payout_landed(_payout: int, _subtotal: int) -> void:
	if _pending != null:
		pop(_pending.cheer_tier, _pending.cheer_count, _note)
	_pending = null


func _on_total_landed() -> void:
	if _count_up.plan.quota_reached:
		cheer_and_fold()
	else:
		sink_all()


## Places `standee` (x seeded, standing height, the peek under `avoid`) out of sight.
func _place(standee: CheerStandee) -> void:
	var s: float = standee.art_scale
	var width: float = standee.ink.size.x * s
	var ink_x: float = standee.ink.position.x * s
	var best_x: float = 0.0
	var best_room: float = -INF
	var best_top: float = 0.0
	var best_limit: float = -INF
	var hop_room: float = max_hop(standee.tier) + OVERSHOOT_PX
	for _try: int in range(CANDIDATES):
		var left: float = _rng.randf_range(GRID, size.x - width - GRID) - ink_x
		var ink_left: float = snappedf(left, GRID) + ink_x
		var jitter: int = _rng.randi_range(0, STAND_JITTER_ROWS)
		var standing: float = size.y - (STAND_ROW - standee.ink.position.y - jitter) * s
		var top: float = standing
		var limit: float = _limit_under_avoid(ink_left, width)
		if limit > -INF:
			top = maxf(top, ceilf((limit + hop_room) / GRID) * GRID)
			if _floor_at(ink_left, width) - top < MIN_PEEK_PX:
				continue
		var room: float = minf(_room(ink_left, width), size.x) - SINK_COST * (top - standing)
		var share: float = hidden_share(Rect2(ink_left, top, width, size.y - top))
		if room > 0.0:
			room *= (1.0 - share) * (1.0 - share)
		room -= COVER_COST_PX * share
		if room > best_room:
			best_room = room
			best_x = ink_left
			best_top = top
			best_limit = limit
	if best_room == -INF:
		best_top = size.y - (STAND_ROW - standee.ink.position.y) * s
	standee.position.x = best_x - ink_x
	standee.min_top = best_limit
	standee.up_y = best_top - standee.ink.position.y * s
	standee.down_y = size.y + GRID - standee.ink.position.y * s
	standee.level = 0.0


## The lowest bottom (crowd-local y) of the `avoid` rects over the columns of an ink from
## `ink_left`, `width` wide; -INF for none.
func _limit_under_avoid(ink_left: float, width: float) -> float:
	var limit: float = -INF
	for rect: Rect2 in avoid:
		var left: float = rect.position.x - position.x
		if ink_left < left + rect.size.x and ink_left + width > left:
			limit = maxf(limit, rect.end.y - position.y)
	return limit


## The share (0 to 1) of a crowd-local ink rect hidden behind `cover`.
func hidden_share(rect: Rect2) -> float:
	var area: float = rect.get_area()
	if area <= 0.0:
		return 0.0
	var stage_rect := Rect2(rect.position + position, rect.size)
	var covered: float = 0.0
	for rect_in_front: Rect2 in cover:
		covered += stage_rect.intersection(rect_in_front).get_area()
	return minf(1.0, covered / area)


## The crowd-local y below which an ink from `ink_left`, `width` wide can't show: the belt's top
## over the belt's columns, else the foot line.
func _floor_at(ink_left: float, width: float) -> float:
	var left: float = BELT_RECT.position.x - position.x
	if ink_left < left + BELT_RECT.size.x and ink_left + width > left:
		return minf(size.y, BELT_RECT.position.y - position.y)
	return size.y


## Fits the band to the visible width (centred on the stage, on the art grid); the standees up
## keep their place on the stage.
func _fit_band() -> void:
	var extra: float = maxf(0.0, (float(view_width.call()) - ShiftStage.SIZE.x) / 2.0)
	extra = floorf(extra / GRID) * GRID
	var shift: float = position.x + extra
	for child: Node in get_children():
		if child is CheerStandee:
			(child as CheerStandee).position.x += shift
	position = Vector2(-extra, TOP_Y)
	size = Vector2(ShiftStage.SIZE.x + 2.0 * extra, FOOT_Y - TOP_Y)


## How much room an ink from `ink_left`, `width` wide has: its gap to the nearest standee's ink
## (negative when they overlap), INF in an empty crowd.
func _room(ink_left: float, width: float) -> float:
	var room: float = INF
	var middle: float = ink_left + width / 2.0
	for other: CheerStandee in _standees:
		var other_width: float = other.ink.size.x * other.art_scale
		var other_left: float = other.position.x + other.ink.position.x * other.art_scale
		var other_middle: float = other_left + other_width / 2.0
		room = minf(room, absf(middle - other_middle) - (width + other_width) / 2.0)
	return room


## Appends a hop `height` px high to `tween`, arms up.
func _hop(tween: Tween, standee: CheerStandee, height: float) -> void:
	var half: float = _tuning.cheer_hop_ms / 2000.0
	tween.tween_callback(standee.set_cheering.bind(true))
	tween.tween_property(standee, "level", 1.0, half)
	(
		tween
		. parallel()
		. tween_property(standee, "hop", height, half)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_QUAD)
	)
	tween.tween_property(standee, "hop", 0.0, half).set_ease(Tween.EASE_IN).set_trans(
		Tween.TRANS_QUAD
	)
	tween.tween_interval(maxf(0.0, _hop_s() - 2.0 * half))
	tween.tween_callback(standee.set_cheering.bind(false))


## How long a hop lasts, its arms up to the end (at least cheer_frame_ms), in seconds.
func _hop_s() -> float:
	return maxi(_tuning.cheer_hop_ms, _tuning.cheer_frame_ms) / 1000.0


func _sink(tween: Tween, standee: CheerStandee) -> void:
	(
		tween
		. tween_property(standee, "level", 0.0, _tuning.cheer_sink_ms / 1000.0)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_QUAD)
	)
	tween.tween_callback(_drop.bind(standee))


func _hop_px(tier: int, note: int) -> float:
	var hops: PackedInt32Array = _tuning.cheer_hop_px
	var base: float = 0.0
	if not hops.is_empty():
		base = hops[clampi(tier, 1, hops.size()) - 1]
	return snappedf(base + _tuning.cheer_hop_per_note_px * note, GRID)


func _scale_of(tier: int) -> int:
	var scales: PackedInt32Array = _tuning.cheer_scales
	return scales[clampi(tier, 1, scales.size()) - 1] if not scales.is_empty() else 2


## Kills `standee`'s tween and makes a new one bound to it (it dies with the standee).
func _restart(standee: CheerStandee) -> Tween:
	standee.stop()
	var tween: Tween = make_tween.call() as Tween
	tween.bind_node(standee)
	standee.tween = tween
	return tween


func _drop(standee: CheerStandee) -> void:
	standee.stop()
	_standees.erase(standee)
	if standee.get_parent() == self:
		remove_child(standee)
	standee.queue_free()


func _play(sound: String, pitch: float) -> void:
	var sfx: Sfx = Sfx.find(self)
	if sfx != null:
		sfx.play(sound, pitch, _tuning.cheer_db)
