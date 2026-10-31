class_name CheckoutCrowd
extends Control
## The checkout cheering (#120, mock-up docs/art/mockups/checkout_cheering.html, the user's
## answers of 2026-10-30): cardboard promo standees pop up behind the counter as the items pay
## and grow into a crowd over the checkout. Decor only: it reads the count-up's plan (each payout
## beat's cheer tier and count, CountUpPlan) and never scores.
##
## Where (ShiftStage builds it in the world, over the back wall, the store sections and the
## RECEIPT REWARDS machine, under the monitor and the fore): in the band from the top bar's foot
## down to the counter's top (FOOT_Y, where it clips, so the standees' legs and easel stay hidden
## behind the belt and the counter), across the visible width, the extra wall of a window wider
## than 16:9 included (refitted at every pop, so a resized window keeps it), but never in the
## columns of `blocked` (the register with its printer and receipt, the kraft bag and its shelf:
## since the clean scene of #123 the open wall is right of the bagging shelf, over the belt).
## Never in front of `avoid` (the hung monitor with its rods and under-strip, the hanging aisle
## signs with their cords): a standee there only peeks below it, its head and shoulders
## (MIN_PEEK_ROWS) above the belt's top, and its ink never reaches it, hops included. Each
## standee casts a ground shadow (CheerShadow) forward onto the visible ground under it (the
## stage lays the shadow layer on the belt's guard). Placement is seeded per checkout (from its
## plan, never the global RNG): of CANDIDATES x positions in the open columns the one with the
## most room wins, so new standees fill the gaps before they overlap, and later ones layer over
## the earlier.
##
## When: each bonus line of an item pops one standee as it lands (CountUp.step_landed; up to
## cheer_line_cap per item, 2026-11-01), at its item's tier's scale (bigger as the payout is bigger
## or a combo, CountUpTuning's cheer_*), with card_place pitched up per standee and tier, each
## rising into a hop as high as its tier and the ladder's note
## (a crowd-wide hop leaves a standee alone while its pop runs); a payout of 0 that failed (its
## own condition WASTED, or denied; CountUpBeat.cheer_failed: a coupon paying nothing of its own
## does not) slumps the newest one (card_return); the ding makes everyone hop and pops
## cheer_quota_count more (v0.82), on the crowd's own clock so the ding's hold doesn't freeze
## them; a passed verdict hops them all, then folds them down before the printer feed; a missed
## one topples them. The printer feed and the count's end hard-hide the crowd, a new count clears
## it, and a resumed checkout (CountUp.show_end_state) shows none.
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
## Under `avoid` a standee only peeks; where it would show fewer art rows than this (its head and
## shoulders with the arms' tops, the art's rows 13 to 33) above the ground, it goes elsewhere.
const MIN_PEEK_ROWS := 20
## Over the belt's columns the belt and the row in front hide the crowd below the belt's top
## (stage px): a peek is measured to it.
const BELT_RECT := ShiftStage.BELT_RECT
## Room kept for the pop's back-ease overshoot above a peeking standee.
const OVERSHOOT_PX := 8.0
## Candidate x positions tried per standee.
const CANDIDATES := 16
## A candidate's room loses this share of its sinking under `avoid`: the open wall right of the
## monitor wins while it has room, but since the clean scene (#123) the peek under the monitor is
## half the open columns, so a standee takes it before it overlaps another.
const SINK_COST := 0.5
const GRID := CheerStandee.GRID

## The rects no standee's ink may reach (stage px): the hung monitor, its rods and under-strip
## (set in _init; a redrawn scene may change them).
var avoid: Array[Rect2] = []
## The fore's parts whose columns no standee's ink may share (stage px): the register with its
## printer and the receipt at its full height, the kraft bag with its shelf (set in _init).
var blocked: Array[Rect2] = []
## The visible width (stage px), read at every pop: the viewport's by default.
var view_width: Callable
## Makes the standees' tweens (CountUp.tween_maker once it follows a count-up).
var make_tween: Callable
var reduced_motion: bool = false
## The confetti the final yay throws (ShiftStage sets it: over the crowd, unclipped), or null.
var confetti: CheerConfetti
## The standees' ground shadows (CheerShadow): the crowd's own child until the stage lays it on
## the ground in front of the crowd (lay_shadows: the belt's guard, under the row).
var shadow_layer: Control
var _tuning: CountUpTuning
var _count_up: CountUp
## The standees up, oldest first.
var _standees: Array[CheerStandee] = []
## The ladder's note of the latest gain beat.
var _note: int = 0
## Standees popped this checkout (they take the designs in turn).
var _popped: int = 0
var _design_offset: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The crowd's origin in the shadow layer.
var _shadow_origin: Vector2 = Vector2.ZERO


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
	for board: Rect2 in StoreShelves.SIGN_RECTS.values():
		# The sign with its cords, from the top bar's foot.
		avoid.append(Rect2(board.position.x, TOP_Y, board.size.x, board.end.y - TOP_Y))
	var receipt := Rect2(
		ShiftStage.RECEIPT_X,
		ShiftStage.RECEIPT_TOP,
		ShiftStage.RECEIPT_WIDTH,
		ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
	)
	blocked = [
		receipt.merge(ShiftStage.PRINTER_RECT).merge(ShiftStage.REGISTER_RECT),
		ShiftStage.BAG_RECT.merge(ShiftStage.BAGGING_SHELF_RECT),
	]
	shadow_layer = Control.new()
	shadow_layer.name = "Shadows"
	shadow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shadow_layer)
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
	count_up.step_landed.connect(_on_step_landed)
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
	shadow_layer.visible = true
	_fit_band()


## Lays the shadow layer in `ground` (in front of the crowd, e.g. the belt) at `area` there,
## clipped to it, as its child at `index`: the shadows show only on that ground.
func lay_shadows(ground: Control, area: Rect2, index: int) -> void:
	if shadow_layer.get_parent() != null:
		shadow_layer.get_parent().remove_child(shadow_layer)
	ground.add_child(shadow_layer)
	ground.move_child(shadow_layer, index)
	shadow_layer.clip_contents = true
	shadow_layer.position = area.position
	shadow_layer.size = area.size


## Pops `count` standees for a payout of `tier` (the first at its tier's scale), each hopping
## for the ladder's `note` (-1: the latest gain beat's); `own_clock`: on the crowd's own tweens
## (the quota's pop, during the ding's hold), not the count's.
func pop(tier: int, count: int, note: int = -1, own_clock: bool = false) -> void:
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
		standee.shadow_lift_px = _tuning.cheer_shadow_lift_px
		standee.shadow_lift_share = _tuning.cheer_shadow_lift_share
		standee.shadow.origin = _shadow_origin
		shadow_layer.add_child(standee.shadow)
		add_child(standee)
		_place(standee)
		_standees.append(standee)
		var pitch: float = _tuning.cheer_pitch_base + _tuning.cheer_pitch_step * (index + tier - 1)
		if reduced_motion:
			standee.level = 1.0
			_play("card_place", pitch)
			continue
		var tween: Tween = _restart(standee, own_clock)
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


## A failed payout of 0: the newest standee sags, then sinks out of sight (an "aww").
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


## A missed verdict, the yay's sad mirror (v0.82): arms down, the whole crowd sags with an "aww"
## (card_return) and wilts, each leaning up to cheer_lean_deg; then, in a wave from the register
## side, each keels over flat onto its foot (cheer_topple_ms, cheer_topple_stagger_ms apart, the
## wave at most cheer_topple_spread_ms long) with a thud pitched lower down the wave and a puff of
## dust (`confetti`), and goes. Reduced motion: they go at once, with the "aww" alone.
func topple_all() -> void:
	if _standees.is_empty():
		return
	_play("card_return", _tuning.cheer_sad_pitch_from)
	var wave: Array[CheerStandee] = _standees.duplicate()
	wave.sort_custom(
		func(a: CheerStandee, b: CheerStandee) -> bool: return a.position.x < b.position.x
	)
	_standees.clear()
	var count: int = wave.size()
	var step_ms: float = _tuning.cheer_topple_stagger_ms
	if count > 1:
		step_ms = minf(step_ms, _tuning.cheer_topple_spread_ms / float(count - 1))
	for index: int in range(count):
		var standee: CheerStandee = wave[index]
		if reduced_motion:
			_drop(standee)
			continue
		var share: float = 0.0 if count < 2 else float(index) / (count - 1)
		var pitch: float = lerpf(_tuning.cheer_sad_pitch_from, _tuning.cheer_sad_pitch_to, share)
		var lean: float = _tuning.cheer_lean_deg * (1.0 if _rng.randf() < 0.5 else -1.0)
		_topple(_restart(standee), standee, index * step_ms / 1000.0, pitch, lean)


## A passed verdict: everyone hops, throwing cheer_confetti_count pieces of confetti from its head
## (`confetti`, when set), then folds down cheer_fold_delay_ms later.
func cheer_and_fold() -> void:
	if reduced_motion:
		return
	for standee: CheerStandee in _standees:
		if confetti != null:
			var rect: Rect2 = standee.visible_rect()
			var head: Vector2 = position + Vector2(rect.get_center().x, rect.position.y)
			var local: Vector2 = (
				confetti.get_global_transform().affine_inverse()
				* (get_global_transform() * (head - position))
			)
			confetti.burst(local, _tuning.cheer_confetti_count, _rng.randi())
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
	for shadow: Node in shadow_layer.get_children():
		shadow_layer.remove_child(shadow)
		shadow.queue_free()
	shadow_layer.visible = false
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
		pop(_tuning.cheer_quota_tier, _tuning.cheer_quota_count, -1, true)
		hop_all()


func _on_beat_started(
	beat: CountUpBeat, _step: ScoreStep, _line: String, _view: CardView, _items: int
) -> void:
	if beat.note >= 0:
		_note = beat.note
	if not CountUpPlan.is_payout_beat(beat):
		return
	if beat.cheer_failed:
		slump()


## A step lands on its item (its sticker fires): a bonus line's beat pops its standee.
func _on_step_landed(index: int) -> void:
	for beat: CountUpBeat in _count_up.plan.beats:
		if beat.steps[0] == index and beat.cheer_count > 0:
			pop(beat.cheer_tier, beat.cheer_count, beat.note if beat.note >= 0 else _note)
			return


func _on_total_landed() -> void:
	if _count_up.plan.quota_reached:
		cheer_and_fold()
	else:
		topple_all()


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
	var spans: Array[Vector2] = _open_lefts(ink_x, width)
	var open_px: float = 0.0
	for span: Vector2 in spans:
		open_px += span.y - span.x
	for _try: int in range(CANDIDATES if not spans.is_empty() else 0):
		var ink_left: float = _pick_left(spans, open_px) + ink_x
		var jitter: int = _rng.randi_range(0, STAND_JITTER_ROWS)
		var standing: float = size.y - (STAND_ROW - standee.ink.position.y - jitter) * s
		var top: float = standing
		var limit: float = _limit_under_avoid(ink_left, width)
		if limit > -INF:
			top = maxf(top, ceilf((limit + hop_room) / GRID) * GRID)
			if _floor_at(ink_left, width) - top < MIN_PEEK_ROWS * s:
				continue
		var room: float = minf(_room(ink_left, width), size.x) - SINK_COST * (top - standing)
		if room > best_room:
			best_room = room
			best_x = ink_left
			best_top = top
			best_limit = limit
	if best_room == -INF:
		best_top = size.y - (STAND_ROW - standee.ink.position.y) * s
		if not spans.is_empty():
			best_x = spans[-1].y + ink_x
	standee.position.x = best_x - ink_x
	standee.min_top = best_limit
	standee.ground_y = _floor_at(best_x, width)
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


## The open ranges (x: from, y: to; crowd-local, on the art grid) of a standee's left edge whose
## ink (`ink_x` in from it, `width` wide) stays in the band, GRID in from its ends, and out of the
## columns of `blocked`.
func _open_lefts(ink_x: float, width: float) -> Array[Vector2]:
	var spans: Array[Vector2] = [Vector2(GRID - ink_x, size.x - GRID - width - ink_x)]
	for rect: Rect2 in blocked:
		# A left edge clears the rect's columns when it is up to `from` or from `to` on.
		var from: float = rect.position.x - position.x - width - ink_x
		var to: float = rect.end.x - position.x - ink_x
		var cut: Array[Vector2] = []
		for span: Vector2 in spans:
			if span.x < from:
				cut.append(Vector2(span.x, minf(span.y, from)))
			if span.y > to:
				cut.append(Vector2(maxf(span.x, to), span.y))
		spans = cut
	var grid_spans: Array[Vector2] = []
	for span: Vector2 in spans:
		var low: float = ceilf(span.x / GRID) * GRID
		var high: float = floorf(span.y / GRID) * GRID
		if low <= high:
			grid_spans.append(Vector2(low, high))
	return grid_spans


## A seeded left edge in `spans` (`open_px` long in all), on the art grid.
func _pick_left(spans: Array[Vector2], open_px: float) -> float:
	var at: float = _rng.randf_range(0.0, open_px)
	for span: Vector2 in spans:
		var length: float = span.y - span.x
		if at <= length:
			return clampf(snappedf(span.x + at, GRID), span.x, span.y)
		at -= length
	return spans[-1].y


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
	# The crowd's origin in the shadow layer (laid elsewhere: through the global transforms).
	var origin: Vector2 = Vector2.ZERO
	if shadow_layer.get_parent() == self:
		shadow_layer.size = size
	elif is_inside_tree() and shadow_layer.is_inside_tree():
		origin = shadow_layer.get_global_transform().affine_inverse() * global_position
	_shadow_origin = origin
	for child: Node in get_children():
		if child is CheerStandee:
			(child as CheerStandee).shadow.origin = origin
			(child as CheerStandee).refresh()


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


## One standee's miss: sag and wilt, wait `delay` s, then keel over with a thud at `pitch` and a
## puff of dust, and go.
func _topple(tween: Tween, standee: CheerStandee, delay: float, pitch: float, lean: float) -> void:
	standee.set_cheering(false)
	var sag_s: float = _tuning.cheer_slump_ms / 1000.0
	tween.set_parallel(true)
	tween.tween_property(standee, "hop", -_tuning.cheer_slump_px, sag_s).set_ease(Tween.EASE_OUT)
	tween.tween_property(standee, "lean", lean, sag_s * 2.0).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	# After the wilt (the parallel steps, the lean's the longest), the wave's delay.
	tween.tween_interval(maxf(delay, 0.001))
	(
		tween
		. tween_property(standee, "fold", 0.0, _tuning.cheer_topple_ms / 1000.0)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_QUAD)
	)
	tween.tween_callback(_play.bind("card_place", pitch))
	tween.tween_callback(_puff.bind(standee))
	tween.tween_callback(_drop.bind(standee))


## A puff of dust where `standee` hit the counter top.
func _puff(standee: CheerStandee) -> void:
	if confetti == null:
		return
	var rect: Rect2 = standee.visible_rect()
	var foot: Vector2 = Vector2(rect.get_center().x, standee.ground_y - CheerConfetti.PIECE_HEIGHT)
	var at: Vector2 = (
		confetti.get_global_transform().affine_inverse() * (get_global_transform() * foot)
	)
	confetti.dust(at, _tuning.cheer_dust_count, _rng.randi())


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
func _restart(standee: CheerStandee, own_clock: bool = false) -> Tween:
	standee.stop()
	var tween: Tween = create_tween() if own_clock else make_tween.call() as Tween
	tween.bind_node(standee)
	standee.tween = tween
	return tween


func _drop(standee: CheerStandee) -> void:
	standee.stop()
	_standees.erase(standee)
	if standee.get_parent() == self:
		remove_child(standee)
	if standee.shadow.get_parent() == shadow_layer:
		shadow_layer.remove_child(standee.shadow)
	standee.shadow.queue_free()
	standee.queue_free()


func _play(sound: String, pitch: float) -> void:
	var sfx: Sfx = Sfx.find(self)
	if sfx != null:
		sfx.play(sound, pitch, _tuning.cheer_db)
