class_name CountUp
extends Node
## Plays a ScoreResult back step by step: the "counting points feels good" moment (plan
## sections 1 and 6, full build plan 6.2). Everything comes from the steps, never from rules.
##
## Scan lift and beep, bonuses flying in from the card that caused them (each one in a chain
## pitched higher), multiplier stamps, copies, Soup's "denied", sticker and Bundle moments,
## a short glow when a card arms an effect for later cards, fizzle puffs, a receipt printer
## that speeds up as the subtotal grows, a register rattle on big payouts, then a pause and the
## total slammed against the quota. Hold the mouse button or Space to fast-forward.

signal finished

const FAST_FORWARD := 5.0
const SCAN_LIFT := -22.0
## The armed beat is short and soft: it hints at what is coming, the payoff plays at the target.
const ARMED_BEAT := 0.18
const ARMED_GLOW := Color(1.3, 1.3, 1.15)

var fast_forward_used: bool = false
## Time.get_ticks_msec() when the final total was shown (plan 8: count-up time ends there).
var total_shown_ms: int = 0
var _overlay: Control
var _views: Array[CardView] = []
var _names: PackedStringArray = PackedStringArray()
var _receipt: ReceiptView
var _subtotal_label: Label
var _sfx: Sfx
## Shaken on big payouts (the register rattle).
var _rattle_target: Control
var _shown_subtotal: int = 0
## Consecutive bonuses on the current card: each one lands a little harder.
var _chain: int = 0
var _playing: bool = false
## The click that started checkout may still be held: it only counts once released.
var _ignore_held: bool = false
## Running tweens: their speed follows fast-forward every frame, not only when they start.
var _live: Array[Tween] = []
var _last_tick_ms: int = 0


func setup(
	overlay: Control, receipt: ReceiptView, subtotal_label: Label, sfx: Sfx, rattle_target: Control
) -> void:
	_overlay = overlay
	_receipt = receipt
	_subtotal_label = subtotal_label
	_sfx = sfx
	_rattle_target = rattle_target


func play(
	result: ScoreResult, views: Array[CardView], names: PackedStringArray, quota: int
) -> void:
	_views = views
	_names = names
	_shown_subtotal = 0
	_chain = 0
	fast_forward_used = false
	_playing = true
	_ignore_held = _is_held()
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
	await _total_slam(result.total, quota)
	_playing = false
	finished.emit()


func _process(_delta: float) -> void:
	var speed: float = _speed()
	var live: Array[Tween] = []
	for tween: Tween in _live:
		if tween.is_valid() and tween.is_running():
			tween.set_speed_scale(speed)
			live.append(tween)
	_live = live
	if _playing and speed > 1.0 and not _live.is_empty():
		fast_forward_used = true


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
	_receipt.add_step(step, _names)
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
	_receipt.add_step(step, _names)
	var left: CardView = _views[step.slot]
	var right: CardView = _views[step.linked_slot]
	var line: Line2D = Line2D.new()
	line.width = 10.0
	line.default_color = Palette.TEAL
	line.add_point(left.center() - _overlay.global_position)
	line.add_point(right.center() - _overlay.global_position)
	_overlay.add_child(line)
	_sfx.play("link")
	var source: CardView = _source_view(step)
	if source != null:
		_punch(source.body, 1.15)
	_punch(left.body, 1.12)
	_punch(right.body, 1.12)
	var tween: Tween = _tween()
	tween.tween_property(line, "width", 3.0, 0.45)
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	await tween.finished
	line.queue_free()


## A fizzle: the card shudders, greys out for a moment, and lets out a little puff.
func _fizzle(step: ScoreStep) -> void:
	_receipt.add_step(step, _names)
	var view: CardView = _views[step.slot]
	var resetter: CardView = _source_view(step)
	if resetter != null and step.source_slot != step.slot:
		# A reset: show the card that wiped this one's effect.
		_punch(resetter.body, 1.15)
		await _fly_text("reset", resetter.center(), view.center(), Palette.LIGHT_TEXT, 20, 0.3)
	_sfx.play("fizzle")
	var tween: Tween = _tween()
	tween.tween_property(view.body, "modulate", Color(0.6, 0.6, 0.6), 0.08)
	tween.tween_property(view.body, "rotation", deg_to_rad(-5.0), 0.06)
	tween.tween_property(view.body, "rotation", deg_to_rad(5.0), 0.08)
	tween.tween_property(view.body, "rotation", 0.0, 0.06)
	tween.tween_property(view.body, "modulate", Color.WHITE, 0.2)
	var start: Vector2 = view.center() + Vector2(0, -30)
	_fly_text("pfff…", start, start + Vector2(0, -50), Palette.LIGHT_TEXT, 20, 0.55, true)
	await tween.finished
	await _wait(0.1)


## The scanner: the card lifts and its base value pops up.
func _base(step: ScoreStep) -> void:
	_chain = 0
	_receipt.add_step(step, _names)
	var view: CardView = _views[step.slot]
	var tween: Tween = _tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(view.body, "position:y", SCAN_LIFT, 0.18)
	tween.tween_property(view.badge, "position:y", CardView.BADGE_Y + SCAN_LIFT, 0.18)
	_sfx.play("scan")
	view.show_badge(step.value_after, true)
	_punch(view.badge, 1.3)
	await tween.finished
	await _wait(0.08)


## A bonus flies in from the card that caused it (or pops on the card for its own rules).
func _bonus(step: ScoreStep) -> void:
	_chain += 1
	_receipt.add_step(step, _names)
	var target: CardView = _views[step.slot]
	# A copy flies in from the copied card; any other bonus from the card that caused it,
	# unless it is the target's own rule or has no card source.
	var source: CardView = null
	if step.step_type == ScoreStep.StepType.COPY:
		source = _views[step.linked_slot]
	elif step.source_slot != step.slot:
		source = _source_view(step)
	var text: String = "+%d" % step.value
	if source != null:
		_punch(source.body, 1.1)
		if step.step_type == ScoreStep.StepType.COPY:
			_sfx.play("copy")
		await _fly_text(text, source.center(), target.center(), Palette.MUSTARD, 30, 0.32)
	else:
		var above: Vector2 = target.center() + Vector2(0, -20)
		await _fly_text(text, above, above + Vector2(0, -40), Palette.MUSTARD, 30, 0.3)
	_sfx.play("bonus", 1.0 + 0.12 * (_chain - 1))
	target.show_badge(step.value_after, true)
	_punch(target.badge, 1.25 + 0.08 * _chain)
	await _wait(0.12)


## A multiplier lands like a stamp: big, rotated, slammed down, with a shake.
func _stamp(step: ScoreStep) -> void:
	_chain += 1
	_receipt.add_step(step, _names)
	var target: CardView = _views[step.slot]
	var source: CardView = _source_view(step)
	if source != null and step.source_slot != step.slot:
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


## Soup beside Frozen: a hard "denied" as its value is wiped to 0.
func _denied(step: ScoreStep) -> void:
	_receipt.add_step(step, _names)
	var view: CardView = _views[step.slot]
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
	var line: Control = _receipt.add_step(step, _names)
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


func _speed() -> float:
	var held: bool = _is_held()
	if _ignore_held and not held:
		_ignore_held = false
	return FAST_FORWARD if held and not _ignore_held else 1.0


## Space, or the mouse held anywhere except on a button (clicking Export log or Deck during
## the count is not a fast-forward).
func _is_held() -> bool:
	if Input.is_key_pressed(KEY_SPACE):
		return true
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return false
	var hovered: Control = get_viewport().gui_get_hovered_control()
	return not hovered is BaseButton
