class_name CountUp
extends Node
## Plays a ScoreResult back step by step: the "counting points feels good" moment (plan
## sections 1 and 6, full build plan 6.2). Everything comes from the steps, never from rules.
##
## Scan lift and beep, bonuses flying in from the card that caused them (each one in a chain
## pitched higher), multiplier stamps, copies, Soup's "denied", sticker and Bundle moments,
## a short glow when a card arms an effect for later cards, fizzle puffs, a receipt printer
## that speeds up as the subtotal grows, a register rattle on big payouts, then a pause and the
## total slammed against the quota.
##
## Respecting the player (full build plan 6.2): a press of Space or the mouse (anywhere except on
## a button that can be pressed) released before HOLD_THRESHOLD_MS is a tap. The first tap speeds
## the count to the verdict (the final total shown) at TAP_SKIP; what follows it (the slam, pass
## or fail, the next-shift notice) then plays at normal speed, unless a second tap (or a first one
## after the verdict) skips it at DESSERT_SKIP. A press held past the threshold fast-forwards at
## FAST_FORWARD while held. The fastest of these wins. Skips only speed tweens up, never kill
## them, so every line, sound and shake still happens and the receipt ends up the same. Presses
## are read from the input events, so a press and release within one frame is still a tap. The
## checkout click is ignored (a press still held at the start is ignored up to its release), so is
## the second click of a double-click on it (CHECKOUT fires on the first click's release), and a
## tap after the count-up does nothing.
##
## Steps caused by an upgrade (source_kind UPGRADE) come from that upgrade's loyalty-card box:
## bonuses and multipliers fly in from it, and its fizzles puff out of it. Steps caused by an
## inspection (source_kind INSPECTION, plan section 3.9) come from its tag in the top bar: it is
## punched as its "0" lands. On a passed shift followed by an inspected one, the notice prints in
## red under the total.

signal finished

## A hold's speed, from HOLD_THRESHOLD_MS on.
const FAST_FORWARD := 5.0
## A press released before this (in ms of Time.get_ticks_msec()) is a tap; one held this long is
## a hold.
const HOLD_THRESHOLD_MS := 200
## The speed after the first tap, up to the verdict.
const TAP_SKIP := 12.0
## The speed of everything left after a tap that skips the dessert.
const DESSERT_SKIP := 30.0
## A double-click's second press this soon (in ms) after the count-up started is the end of the
## checkout click's double-click, not a tap. Later ones are real taps (the second of two quick
## taps is a double-click too, and still skips the dessert).
const CHECKOUT_DOUBLE_CLICK_MS := 500
## The sources of a press, as bits of _down and _ignored.
const PRESS_SPACE := 1
const PRESS_MOUSE := 2
const SCAN_LIFT := -22.0
## The armed beat is short and soft: it hints at what is coming, the payoff plays at the target.
const ARMED_BEAT := 0.18
const ARMED_GLOW := Color(1.3, 1.3, 1.15)

## A hold past HOLD_THRESHOLD_MS sped this count-up up (plan 8's fast-forward used).
var fast_forward_used: bool = false
## Time.get_ticks_msec() when the final total was shown (plan 8: count-up time ends there).
var total_shown_ms: int = 0
## Time.get_ticks_msec() of this count-up's first tap, or -1 for none (plan 8's skip_at_ms).
var first_tap_ms: int = -1
## A tap skipped the dessert: a second tap, or a first one after the verdict.
var dessert_skipped: bool = false
var _overlay: Control
var _views: Array[CardView] = []
var _names: PackedStringArray = PackedStringArray()
## The loyalty-card boxes and names of the run's upgrades, indexed like the run's upgrades
## (a step's source_index). Never mixed up with _views, which is indexed by slot.
var _upgrade_boxes: Array[Control] = []
var _upgrade_names: PackedStringArray = PackedStringArray()
## Where the shift's inspections are shown and their names, indexed like the shift's
## inspections (a step's source_index).
var _inspection_sources: Array[Control] = []
var _inspection_names: PackedStringArray = PackedStringArray()
var _receipt: ReceiptView
var _subtotal_label: Label
var _sfx: Sfx
## Shaken on big payouts (the register rattle).
var _rattle_target: Control
var _shown_subtotal: int = 0
## Consecutive bonuses on the current card: each one lands a little harder.
var _chain: int = 0
var _playing: bool = false
## The sources (PRESS_SPACE, PRESS_MOUSE) already held when the count-up started, such as the
## checkout click: ignored up to their release.
var _ignored: int = 0
## The sources down in the press being tracked: it ends when the last one is released.
var _down: int = 0
## When the press being tracked started (Time.get_ticks_msec()), or -1 while nothing is pressed.
var _press_ms: int = -1
## A tap has sped the count up (to the verdict, unless it skipped the dessert).
var _tapped: bool = false
## The final total is shown: what follows is the dessert.
var _verdict_shown: bool = false
## Running tweens: their speed follows fast-forward every frame, not only when they start.
var _live: Array[Tween] = []
var _last_tick_ms: int = 0
## Time.get_ticks_msec() when this count-up started (for CHECKOUT_DOUBLE_CLICK_MS).
var _started_ms: int = 0


func setup(
	overlay: Control, receipt: ReceiptView, subtotal_label: Label, sfx: Sfx, rattle_target: Control
) -> void:
	_overlay = overlay
	_receipt = receipt
	_subtotal_label = subtotal_label
	_sfx = sfx
	_rattle_target = rattle_target


func play(
	result: ScoreResult,
	views: Array[CardView],
	names: PackedStringArray,
	quota: int,
	upgrade_boxes: Array[Control] = [],
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_sources: Array[Control] = [],
	inspection_names: PackedStringArray = PackedStringArray(),
	notice: String = ""
) -> void:
	_views = views
	_names = names
	_upgrade_boxes = upgrade_boxes
	_upgrade_names = upgrade_names
	_inspection_sources = inspection_sources
	_inspection_names = inspection_names
	_shown_subtotal = 0
	_chain = 0
	fast_forward_used = false
	first_tap_ms = -1
	dessert_skipped = false
	_tapped = false
	_verdict_shown = false
	_press_ms = -1
	_down = 0
	_ignored = 0
	_started_ms = Time.get_ticks_msec()
	if Input.is_key_pressed(KEY_SPACE):
		_ignored |= PRESS_SPACE
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_ignored |= PRESS_MOUSE
	_playing = true
	_receipt.clear()
	_set_subtotal(0.0)
	for view: CardView in _views:
		view.reset_motion()
		view.hide_badge()
	await _wait(0.25)
	for step: ScoreStep in result.steps:
		await _play_step(step)
	# A held breath, then the total lands against the quota.
	await _wait(0.45)
	_receipt.add_total(result.total)
	total_shown_ms = Time.get_ticks_msec()
	_verdict_shown = true
	await _total_slam(result.total, quota)
	if not notice.is_empty():
		await _print_notice(notice)
	_playing = false
	finished.emit()


func _process(_delta: float) -> void:
	_drop_lost_presses()
	var speed: float = _speed()
	var live: Array[Tween] = []
	for tween: Tween in _live:
		if tween.is_valid() and tween.is_running():
			tween.set_speed_scale(speed)
			live.append(tween)
	_live = live
	if _playing and _is_holding() and FAST_FORWARD > _skip_speed() and not _live.is_empty():
		fast_forward_used = true


## Follows the presses of Space and the mouse during the count-up from their events, so a press
## and release within one frame, or around a long frame, are timed as they came: a release before
## HOLD_THRESHOLD_MS is a tap. Events are never marked handled, so the buttons still get them.
func _input(event: InputEvent) -> void:
	var source: int = _press_source(event)
	if not _playing or source == 0:
		return
	var now: int = Time.get_ticks_msec()
	if event.is_pressed():
		# A new press of an ignored source means its release was missed: it is tracked again.
		_ignored &= ~source
		if source == PRESS_MOUSE and not _is_tap_target():
			return
		if source == PRESS_MOUSE and _ends_checkout_double_click(event, now):
			_ignored |= PRESS_MOUSE  # Its release is dropped too.
			return
		if _down == 0:
			_press_ms = now
		_down |= source
		return
	if (_ignored & source) != 0:
		_ignored &= ~source
		return
	if (_down & source) == 0:
		return
	_down &= ~source
	if _down == 0:
		if now - _press_ms < HOLD_THRESHOLD_MS:
			_tap(now)
		_press_ms = -1


## Forgets presses whose release never came (the window lost focus) and, once the count-up has
## ended, every press: neither is a tap or a hold.
func _drop_lost_presses() -> void:
	if not _playing:
		_down = 0
		_ignored = 0
	if not Input.is_key_pressed(KEY_SPACE):
		_down &= ~PRESS_SPACE
		_ignored &= ~PRESS_SPACE
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_down &= ~PRESS_MOUSE
		_ignored &= ~PRESS_MOUSE
	if _down == 0:
		_press_ms = -1


## PRESS_SPACE or PRESS_MOUSE for a Space key (not an echo) or left mouse button event, else 0.
static func _press_source(event: InputEvent) -> int:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		return PRESS_SPACE if key.keycode == KEY_SPACE and not key.echo else 0
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
		return PRESS_MOUSE
	return 0


## The first tap speeds the count to the verdict; a second one, or one after the verdict, skips
## the dessert too.
func _tap(now: int) -> void:
	if first_tap_ms < 0:
		first_tap_ms = now
	if _tapped or _verdict_shown:
		dessert_skipped = true
	_tapped = true


func _play_step(step: ScoreStep) -> void:
	match step.step_type:
		ScoreStep.StepType.TAG_ADDED:
			await _tag_added(step)
		ScoreStep.StepType.LINKED:
			await _linked(step)
		ScoreStep.StepType.WASTED:
			await _fizzle(step)
		ScoreStep.StepType.BASE:
			await _base(step)
		ScoreStep.StepType.FLAT, ScoreStep.StepType.COPY:
			await _bonus(step)
		ScoreStep.StepType.MULTIPLIER:
			await _stamp(step)
		ScoreStep.StepType.PAYOUT_OVERRIDE:
			await _denied(step)
		ScoreStep.StepType.PAYOUT:
			await _payout(step)
		ScoreStep.StepType.EFFECT_ARMED:
			await _armed(step)


func _tag_added(step: ScoreStep) -> void:
	_receipt.add_step(step, _names, _upgrade_names, _inspection_names)
	var target: CardView = _views[step.slot]
	var source: CardView = _source_view(step)
	if source == null:
		source = target
	_punch(source.body, 1.1)
	await _fly_text("+" + step.tag, source.center(), target.center(), Palette.LIGHT_TEXT, 24, 0.35)
	_sfx.play("tag")
	target.add_tag(step.tag)
	_punch(target.body, 1.15)
	await _wait(0.15)


func _linked(step: ScoreStep) -> void:
	_receipt.add_step(step, _names, _upgrade_names, _inspection_names)
	var left: CardView = _views[step.slot]
	var right: CardView = _views[step.linked_slot]
	var line: Line2D = Line2D.new()
	line.width = 10.0
	line.default_color = Palette.TEAL
	line.add_point(left.center() - _overlay.global_position)
	line.add_point(right.center() - _overlay.global_position)
	_overlay.add_child(line)
	_sfx.play("link")
	# A coupon's link punches the coupon. An upgrade's (Rule bender) comes out of its
	# loyalty-card box: its name flies to the link, so the player sees what joined the cards.
	var source: Control = _source_control(step)
	if source != null:
		_punch(_moving_part(source), 1.15)
	var box: Control = _upgrade_box(step)
	if box != null:
		var middle: Vector2 = (left.center() + right.center()) / 2.0
		_fly_text(step.text, _center(box), middle, Palette.TEAL, 20, 0.35, true)
	_punch(left.body, 1.12)
	_punch(right.body, 1.12)
	var tween: Tween = _tween()
	tween.tween_property(line, "width", 3.0, 0.45)
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	await tween.finished
	line.queue_free()


## A fizzle: the card shudders, greys out for a moment, and lets out a little puff. An
## upgrade's fizzle comes out of its loyalty-card box instead (the card it had nothing to work
## on gives a small nudge).
func _fizzle(step: ScoreStep) -> void:
	_receipt.add_step(step, _names, _upgrade_names, _inspection_names)
	var view: CardView = _views[step.slot]
	var shaken: Control = view.body
	var puff_at: Vector2 = view.center() + Vector2(0, -30)
	var puff_to: Vector2 = puff_at + Vector2(0, -50)
	var upgrade_box: Control = _upgrade_box(step)
	var resetter: CardView = _source_view(step)
	if upgrade_box != null:
		shaken = upgrade_box
		# The box sits in the top bar: the puff drifts down from it, onto the screen.
		puff_at = _center(upgrade_box) + Vector2(0, 26)
		puff_to = puff_at + Vector2(0, 50)
		_punch(view.body, 1.06)
	elif resetter != null and step.source_slot != step.slot:
		# A reset: show the card that wiped this one's effect.
		_punch(resetter.body, 1.15)
		await _fly_text("reset", resetter.center(), view.center(), Palette.LIGHT_TEXT, 20, 0.3)
	_sfx.play("fizzle")
	shaken.pivot_offset = shaken.size / 2.0
	# An upgrade's box keeps its stamp tilt: the shake ends where it started.
	var rest: float = shaken.rotation if upgrade_box != null else 0.0
	var tween: Tween = _tween()
	tween.tween_property(shaken, "modulate", Color(0.6, 0.6, 0.6), 0.08)
	tween.tween_property(shaken, "rotation", rest + deg_to_rad(-5.0), 0.06)
	tween.tween_property(shaken, "rotation", rest + deg_to_rad(5.0), 0.08)
	tween.tween_property(shaken, "rotation", rest, 0.06)
	tween.tween_property(shaken, "modulate", Color.WHITE, 0.2)
	_fly_text("pfff…", puff_at, puff_to, Palette.LIGHT_TEXT, 20, 0.55, true)
	await tween.finished
	await _wait(0.1)


## The scanner: the card lifts and its base value pops up.
func _base(step: ScoreStep) -> void:
	_chain = 0
	_receipt.add_step(step, _names, _upgrade_names, _inspection_names)
	var view: CardView = _views[step.slot]
	var tween: Tween = _tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(view.body, "position:y", SCAN_LIFT, 0.18)
	tween.tween_property(view.badge, "position:y", CardView.BADGE_Y + SCAN_LIFT, 0.18)
	_sfx.play("scan")
	view.show_badge(step.value_after, true)
	_punch(view.badge, 1.3)
	await tween.finished
	await _wait(0.08)


## A bonus flies in from the card that caused it, or from the upgrade's loyalty-card box (or
## pops on the card for its own rules).
func _bonus(step: ScoreStep) -> void:
	_chain += 1
	_receipt.add_step(step, _names, _upgrade_names, _inspection_names)
	var target: CardView = _views[step.slot]
	# A copy flies in from the copied card; any other bonus from the card or upgrade that
	# caused it, unless it is the target's own rule.
	var source: Control = null
	if step.step_type == ScoreStep.StepType.COPY:
		source = _views[step.linked_slot]
	elif step.source_kind == ScoreStep.SourceKind.UPGRADE or step.source_slot != step.slot:
		source = _source_control(step)
	var text: String = "+%d" % step.value
	if source != null:
		_punch(_moving_part(source), 1.1)
		if step.step_type == ScoreStep.StepType.COPY:
			_sfx.play("copy")
		await _fly_text(text, _center(source), target.center(), Palette.MUSTARD, 30, 0.32)
	else:
		var above: Vector2 = target.center() + Vector2(0, -20)
		await _fly_text(text, above, above + Vector2(0, -40), Palette.MUSTARD, 30, 0.3)
	_sfx.play("bonus", 1.0 + 0.12 * (_chain - 1))
	target.show_badge(step.value_after, true)
	_punch(target.badge, 1.25 + 0.08 * _chain)
	await _wait(0.12)


## A multiplier lands like a stamp: big, rotated, slammed down, with a shake. An upgrade's
## factor first flies in from its loyalty-card box.
func _stamp(step: ScoreStep) -> void:
	_chain += 1
	_receipt.add_step(step, _names, _upgrade_names, _inspection_names)
	var target: CardView = _views[step.slot]
	var upgrade_box: Control = _upgrade_box(step)
	var source: CardView = _source_view(step)
	if upgrade_box != null:
		_punch(upgrade_box, 1.3)
		var factor: String = "×%d" % step.value
		await _fly_text(factor, _center(upgrade_box), target.center(), Palette.TOMATO, 26, 0.3)
	elif source != null and step.source_slot != step.slot:
		_punch(source.body, 1.12)
	var stamp: Label = _text_label("×%d" % step.value, Palette.TOMATO, 54)
	_overlay.add_child(stamp)
	stamp.global_position = target.center() - stamp.size / 2.0
	stamp.pivot_offset = stamp.size / 2.0
	stamp.scale = Vector2(2.6, 2.6)
	stamp.rotation = deg_to_rad(-18.0)
	stamp.modulate.a = 0.0
	var slam: Tween = _tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam.tween_property(stamp, "scale", Vector2.ONE, 0.16)
	slam.tween_property(stamp, "rotation", deg_to_rad(-8.0), 0.16)
	slam.tween_property(stamp, "modulate:a", 1.0, 0.1)
	await slam.finished
	_sfx.play("stamp", 1.0 + 0.06 * (_chain - 1))
	_shake(target.body, 7.0)
	target.show_badge(step.value_after, true)
	_punch(target.badge, 1.35 + 0.08 * _chain)
	var fade: Tween = _tween()
	fade.tween_interval(0.2)
	fade.tween_property(stamp, "modulate:a", 0.0, 0.2)
	fade.tween_callback(stamp.queue_free)
	await _wait(0.22)


## Soup beside Frozen, or an inspection: a hard "denied" as its value is wiped to 0. An
## inspection's tag is punched first, so the 0 visibly comes from it.
func _denied(step: ScoreStep) -> void:
	_receipt.add_step(step, _names, _upgrade_names, _inspection_names)
	var view: CardView = _views[step.slot]
	var inspection: Control = _inspection_source(step)
	if inspection != null:
		_punch(inspection, 1.25)
	var cross: Label = _text_label("0", Palette.TOMATO, 64)
	_overlay.add_child(cross)
	cross.global_position = view.center() - cross.size / 2.0
	cross.pivot_offset = cross.size / 2.0
	cross.scale = Vector2(3, 3)
	var tween: Tween = _tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(cross, "scale", Vector2.ONE, 0.2)
	await tween.finished
	_sfx.play("denied")
	_shake(view.body, 10.0)
	view.show_badge(step.value_after, true)
	view.badge.add_theme_color_override("font_color", Palette.TOMATO)
	var fade: Tween = _tween()
	fade.tween_interval(0.25)
	fade.tween_property(cross, "modulate:a", 0.0, 0.2)
	fade.tween_callback(cross.queue_free)
	await _wait(0.3)


## The payout drops onto the receipt and the subtotal ticks up, harder for bigger payouts.
func _payout(step: ScoreStep) -> void:
	var view: CardView = _views[step.slot]
	var line: Control = _receipt.add_step(step, _names, _upgrade_names, _inspection_names)
	if line:
		line.modulate.a = 0.0
		_tween().tween_property(line, "modulate:a", 1.0, 0.15)
	var drop: Tween = _tween().set_parallel().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop.tween_property(view.body, "position:y", 0.0, 0.22)
	drop.tween_property(view.badge, "position:y", CardView.BADGE_Y, 0.22)
	var from: int = _shown_subtotal
	# The printer runs faster and higher as the subtotal grows.
	_sfx.play("print", 1.0 + minf(step.subtotal / 60.0, 0.7))
	var tick: Tween = _tween()
	var speed_up: float = 1.0 + step.subtotal / 40.0
	var duration: float = clampf((0.12 + 0.02 * step.value) / speed_up, 0.08, 0.5)
	tick.tween_method(_set_subtotal, float(from), float(step.subtotal), duration)
	_punch(_subtotal_label, 1.1 + minf(step.value / 25.0, 0.5))
	if step.value >= 10:
		# A big payout rattles the register.
		_shake(_rattle_target, minf(3.0 + step.value / 4.0, 12.0))
	await tick.finished
	await _wait(0.12)


## A card arms an effect for later cards (Eggs charges, Coffee, Multipack): it glows and
## pulses, the effect's name floats up from it, and a soft, high "bonus" plays. The beat is
## short; the label keeps fading while the next step starts. No receipt line.
func _armed(step: ScoreStep) -> void:
	var view: CardView = _views[step.slot]
	_punch(view.body, 1.08)
	var glow: Tween = _tween()
	glow.tween_property(view.body, "modulate", ARMED_GLOW, 0.05)
	glow.tween_property(view.body, "modulate", Color.WHITE, 0.13)
	_sfx.play("bonus", 1.6, -8.0)
	var start: Vector2 = view.center() + Vector2(0, -40)
	_fly_text(step.text, start, start + Vector2(0, -36), Palette.MUSTARD, 18, 0.45, true)
	await _wait(ARMED_BEAT)


## The card that caused a step, or null when its source is not a card (an upgrade or an
## inspection, full build): source_slot is only read for CARD sources (plan section 4).
func _source_view(step: ScoreStep) -> CardView:
	if step.source_kind != ScoreStep.SourceKind.CARD:
		return null
	return _views[step.source_slot]


## The loyalty-card box of the upgrade that caused a step, or null when the step's source is
## not an upgrade (or its box is missing): source_index is only read for UPGRADE sources.
func _upgrade_box(step: ScoreStep) -> Control:
	if step.source_kind != ScoreStep.SourceKind.UPGRADE:
		return null
	if step.source_index < 0 or step.source_index >= _upgrade_boxes.size():
		return null
	return _upgrade_boxes[step.source_index]


## Where the inspection that caused a step is shown, or null when the step's source is not an
## inspection (or nothing shows it): source_index is only read for INSPECTION sources.
func _inspection_source(step: ScoreStep) -> Control:
	if step.source_kind != ScoreStep.SourceKind.INSPECTION:
		return null
	if step.source_index < 0 or step.source_index >= _inspection_sources.size():
		return null
	return _inspection_sources[step.source_index]


## Where a step comes from on screen: its card, its upgrade's loyalty-card box, or its
## inspection's tag.
func _source_control(step: ScoreStep) -> Control:
	var upgrade_box: Control = _upgrade_box(step)
	if upgrade_box != null:
		return upgrade_box
	var inspection: Control = _inspection_source(step)
	return inspection if inspection != null else _source_view(step)


## The next shift's inspection prints in red under the total, with a stamp.
func _print_notice(notice: String) -> void:
	await _wait(0.2)
	var line: Control = _receipt.add_notice(notice)
	_sfx.play("stamp")
	line.modulate.a = 0.0
	_tween().tween_property(line, "modulate:a", 1.0, 0.15)
	await _wait(0.35)


## The part of a source that is punched: a card's body (its layout box stays still), or the
## whole loyalty-card box.
static func _moving_part(source: Control) -> Control:
	var view: CardView = source as CardView
	return view.body if view != null else source


static func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


## The final moment: the total slams down beside the quota, green and cheerful if it is
## enough, red and deflated if not.
func _total_slam(total: int, quota: int) -> void:
	var enough: bool = total >= quota
	var verdict: Label = _text_label(
		"€%d / €%d" % [total, quota], Palette.GOOD if enough else Palette.TOMATO, 72
	)
	_overlay.add_child(verdict)
	var center: Vector2 = _overlay.get_global_rect().get_center() + Vector2(0, -40)
	verdict.global_position = center - verdict.size / 2.0
	verdict.pivot_offset = verdict.size / 2.0
	verdict.scale = Vector2(3.2, 3.2)
	verdict.modulate.a = 0.0
	var slam: Tween = _tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam.tween_property(verdict, "scale", Vector2.ONE, 0.2)
	slam.tween_property(verdict, "modulate:a", 1.0, 0.12)
	await slam.finished
	# A bright chord only for a pass; a miss lands with a dull thud.
	_sfx.play("total" if enough else "miss")
	_shake(_rattle_target, 10.0 if enough else 4.0)
	_punch(_subtotal_label, 1.5)
	await _wait(0.25)
	_sfx.play("pass" if enough else "fail")
	await _wait(0.6)
	var fade: Tween = _tween()
	fade.tween_property(verdict, "modulate:a", 0.0, 0.25)
	fade.tween_callback(verdict.queue_free)


func _set_subtotal(value: float) -> void:
	var shown: int = roundi(value)
	if shown != _shown_subtotal and _playing:
		# The printer ticks as the subtotal rolls, a little higher as it grows.
		var now: int = Time.get_ticks_msec()
		if now - _last_tick_ms >= 35:
			_last_tick_ms = now
			_sfx.play("tick", 1.0 + minf(shown / 80.0, 0.8))
	_shown_subtotal = shown
	_subtotal_label.text = "€%d" % _shown_subtotal


func _fly_text(
	text: String,
	from: Vector2,
	to: Vector2,
	color: Color,
	font_size: int,
	duration: float,
	fade_out: bool = false
) -> void:
	var label: Label = _text_label(text, color, font_size)
	_overlay.add_child(label)
	label.global_position = from - label.size / 2.0
	label.pivot_offset = label.size / 2.0
	var tween: Tween = _tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)
	tween.tween_property(label, "global_position", to - label.size / 2.0, duration)
	if fade_out:
		tween.tween_property(label, "modulate:a", 0.0, duration)
	else:
		tween.tween_property(label, "scale", Vector2(1.25, 1.25), duration)
	await tween.finished
	label.queue_free()


func _text_label(text: String, color: Color, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	label.size = label.get_minimum_size()
	return label


func _punch(node: Control, strength: float) -> void:
	node.pivot_offset = node.size / 2.0
	var tween: Tween = _tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(strength, strength), 0.07)
	tween.tween_property(node, "scale", Vector2.ONE, 0.18)


func _shake(node: Control, amount: float) -> void:
	var origin: Vector2 = node.position
	var tween: Tween = _tween()
	for i: int in range(4):
		var offset: Vector2 = Vector2(amount if i % 2 == 0 else -amount, 0) * (1.0 - i * 0.2)
		tween.tween_property(node, "position", origin + offset, 0.03)
	tween.tween_property(node, "position", origin, 0.04)


func _tween() -> Tween:
	var tween: Tween = create_tween().set_speed_scale(_speed())
	_live.append(tween)
	return tween


func _wait(seconds: float) -> void:
	var tween: Tween = _tween()
	tween.tween_interval(seconds)
	await tween.finished


## The fastest of the taps' skip and a hold's fast-forward.
func _speed() -> float:
	return maxf(_skip_speed(), FAST_FORWARD if _is_holding() else 1.0)


func _skip_speed() -> float:
	if dessert_skipped:
		return DESSERT_SKIP
	return TAP_SKIP if _tapped and not _verdict_shown else 1.0


## A press held past HOLD_THRESHOLD_MS (the checkout click never is: it is ignored, not tracked).
func _is_holding() -> bool:
	return _press_ms >= 0 and Time.get_ticks_msec() - _press_ms >= HOLD_THRESHOLD_MS


## A mouse press counts anywhere except on a button that can be pressed (clicking Export log or
## Deck during the count is neither a tap nor a hold). A disabled button, such as CHECKOUT under
## the cursor during its own count, does nothing, so a press on it counts, except for the second
## click of a double-click on CHECKOUT (see _ends_checkout_double_click).
func _is_tap_target() -> bool:
	var button: BaseButton = get_viewport().gui_get_hovered_control() as BaseButton
	return button == null or button.disabled


## A double-click's second press within CHECKOUT_DOUBLE_CLICK_MS of the start: the player
## double-clicked CHECKOUT, which is one intent to check out, not a tap.
func _ends_checkout_double_click(event: InputEvent, now: int) -> bool:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	return mouse.double_click and now - _started_ms < CHECKOUT_DOUBLE_CLICK_MS
