class_name CountUpDessert
extends RefCounted
## The shift's dessert (#61): what CountUp plays after the verdict (the TOTAL line), kept out of
## CountUp so it stays under gdlint's file length. Timed by the CountUpTuning's Dessert group,
## on the count-up's tweens (`make_tween`), so taps and holds speed it up like the count and
## never kill it: every line, sound and shake still happens.
##
## "€total / €quota" slams onto the receipt's TOTAL line (green on a pass, red on a miss) with
## `total` or `miss` and a shake, a step bigger for a large total and another for a huge one; the
## margin line under it counts "+€N OVER QUOTA", "SHORT €N" or a green "ON QUOTA" (ShiftMargin)
## while `pass` or `fail` sounds; a pass gets the PAID stamp (`stamp_paid`) once the margin has
## counted; the receipt tears (`rip`), on a miss after `fail` has rung out; the next shift's
## notice prints in red with the printer's feed, then the clerk's stamp (`stamp_notice`). A pass
## ends at the printer feed, where the reward print-out takes over; a miss a little after the
## tear. Under reduced motion the slam fades in at full size and nothing shakes (CountUpMotion);
## the small punches stay.

## The slam starts this big (D11) and lands at 1 on the TOTAL line.
const SLAM_SCALE := 3.2
## The slam's outline, thinner than CountUpMotion's big labels: it lands at the receipt's size.
const SLAM_OUTLINE := 4
## The verdict on the TOTAL line punches as it lands; the PAID stamp lands from PAID_SLAM_SCALE
## over PAID_SLAM seconds.
const VERDICT_PUNCH := 1.3
const PAID_SLAM_SCALE := 2.0
const PAID_SLAM := 0.1
## The next-shift notice: the clerk's stamp lands this long after the printer feeds the line.
const NOTICE_STAMP_GAP := 0.08

## The shift's margin against its quota, set when the dessert starts; null before that.
var margin: ShiftMargin
## The sounds: the count-up's own Sfx (CountUp sets it before each dessert).
var sfx: Sfx
## The player's speed setting, the speed the dessert's waits run at without taps or holds
## (CountUp sets it before each dessert).
var speed_setting: float = 1.0
var _overlay: Control
var _receipt: ReceiptView
var _fx: CountUpMotion
## Shaken as the slam lands (the register rattle's target).
var _rattle_target: Control
## Returns a new Tween that follows the count-up's speed.
var _make_tween: Callable
var _tuning: CountUpTuning


func _init(
	overlay: Control,
	receipt: ReceiptView,
	sounds: Sfx,
	fx: CountUpMotion,
	rattle_target: Control,
	make_tween: Callable
) -> void:
	_overlay = overlay
	_receipt = receipt
	sfx = sounds
	_fx = fx
	_rattle_target = rattle_target
	_make_tween = make_tween


## Plays the dessert of a shift that ended on `total` against `quota`, with the next shift's
## `notice` (none when empty). `intensity` scales the shake; `print_pitch` is the printer's.
## Returns at the printer feed on a pass, after the tear on a miss.
func play(
	total: int,
	quota: int,
	notice: String,
	tuning: CountUpTuning,
	intensity: CountUpIntensity,
	reduced_motion: bool,
	print_pitch: float
) -> void:
	_tuning = tuning
	margin = ShiftMargin.of(total, quota)
	var passed: bool = margin.passed()
	await _wait_ms(_tuning.dessert_slam_delay_ms)
	var verdict: Label = await _slam(total, quota, reduced_motion)
	sfx.play("total" if passed else "miss")
	_fx.shake(_rattle_target, shake_px(passed, intensity, _tuning))
	if verdict != null:
		_fx.punch(verdict, VERDICT_PUNCH)
	var line: Control = _count_margin()
	var sound_ms: int = mini(_tuning.dessert_verdict_sound_ms, _tuning.dessert_margin_ms)
	await _wait_ms(sound_ms)
	sfx.play("pass" if passed else "fail")
	await _wait_ms(_tuning.dessert_margin_ms - sound_ms)
	ReceiptView.show_margin(line, margin.kind(), margin.amount())
	if passed:
		await _wait_ms(_tuning.dessert_paid_ms)
		_stamp_paid(line)
	else:
		# The music stays ducked through the whole fail sound (#62, Q6), then the receipt tears.
		# The sound plays in real time but the waits run at the speed setting, so its length is
		# scaled up to the waits' time (only a tap or a hold cuts it short).
		var heard: float = (_tuning.dessert_margin_ms - sound_ms) / 1000.0
		await _wait(maxf(sfx.sound_length("fail") * speed_setting - heard, 0.0))
	await _wait_ms(_tuning.dessert_tear_ms)
	_tear()
	if not passed:
		await _wait_ms(_tuning.dessert_miss_end_ms)
		return
	var feed_ms: float = _tuning.dessert_feed_ms
	if not notice.is_empty():
		await _wait_ms(_tuning.dessert_notice_ms)
		await _print_notice(notice, print_pitch)
		feed_ms -= _tuning.dessert_notice_ms + NOTICE_STAMP_GAP * 1000.0
	await _wait(maxf(feed_ms, 0.0) / 1000.0)


## The slam's shake in pixels: a pass's or a miss's, a step bigger for a large total and another
## for a huge one. CountUpMotion drops it under reduced motion.
static func shake_px(passed: bool, intensity: CountUpIntensity, tuning: CountUpTuning) -> float:
	var px: float = tuning.dessert_shake_pass_px if passed else tuning.dessert_shake_miss_px
	var steps: int = 0
	if intensity != null:
		steps = int(intensity.is_large) + int(intensity.is_huge)
	return px * (1.0 + tuning.dessert_shake_step * steps)


## "€total / €quota" slams from SLAM_SCALE onto the TOTAL line's right side (under reduced
## motion it fades in there at full size), which then shows it. Returns that label, or null
## when the receipt has no TOTAL line.
func _slam(total: int, quota: int, reduced_motion: bool) -> Label:
	var target: Label = _receipt.show_verdict(total, quota)
	if target == null:
		await _wait_ms(_tuning.dessert_slam_ms)
		return null
	target.modulate.a = 0.0
	var slam: Label = CountUpMotion.text_label(
		ReceiptView.verdict_text(total, quota),
		target.get_theme_color("font_color"),
		ReceiptView.TOTAL_FONT_SIZE
	)
	slam.add_theme_font_override("font", ReceiptView.MONO_FONT)
	slam.add_theme_constant_override("outline_size", SLAM_OUTLINE)
	slam.modulate.a = 0.0
	_overlay.add_child(slam)
	# Sized in the tree, where its font override is in effect (_place_slam keeps the pivot).
	slam.size = slam.get_minimum_size()
	if not reduced_motion:
		slam.scale = Vector2(SLAM_SCALE, SLAM_SCALE)
	_place_slam(0.0, slam, target)
	var seconds: float = _tuning.dessert_slam_ms / 1000.0
	var tween: Tween = _tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The landing spot follows the TOTAL line as the receipt lays out its new text.
	tween.tween_method(_place_slam.bind(slam, target), 0.0, 1.0, seconds)
	if reduced_motion:
		tween.tween_property(slam, "modulate:a", 1.0, seconds)
	else:
		tween.tween_property(slam, "scale", Vector2.ONE, seconds)
		tween.tween_property(slam, "modulate:a", 1.0, seconds * 0.6)
	await tween.finished
	slam.queue_free()
	target.modulate.a = 1.0
	return target


## The slam over the TOTAL line's right side, scaled around its centre and kept inside the
## overlay while it is big: it lands on the line as it reaches full size.
func _place_slam(_progress: float, slam: Label, target: Label) -> void:
	slam.pivot_offset = slam.size / 2.0
	var half: Vector2 = slam.size * slam.scale / 2.0
	var area: Rect2 = _overlay.get_global_rect()
	var center: Vector2 = target.get_global_rect().get_center()
	center = center.clamp(area.position + half, (area.end - half).max(area.position + half))
	# Its position, not its global_position: drawn around the pivot, its centre is position plus
	# half its size at any scale.
	slam.position = center - area.position - slam.size / 2.0


## The margin line prints under the total and counts up to the margin over dessert_margin_ms.
## Returns the line.
func _count_margin() -> Control:
	var line: Control = _receipt.add_margin(margin)
	ReceiptView.show_margin(line, margin.kind(), 0)
	_fade_in(line)
	if margin.amount() > 0:
		var seconds: float = _tuning.dessert_margin_ms / 1000.0
		_tween().tween_method(_show_margin.bind(line), 0.0, float(margin.amount()), seconds)
	return line


func _show_margin(euros: float, line: Control) -> void:
	ReceiptView.show_margin(line, margin.kind(), roundi(euros))


## PAID lands on the margin line with its stamp.
func _stamp_paid(line: Control) -> void:
	var stamp: Label = ReceiptView.stamp_paid(line)
	sfx.play("stamp_paid")
	stamp.scale = Vector2(PAID_SLAM_SCALE, PAID_SLAM_SCALE)
	var slam: Tween = _fx.scale_tween(stamp).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.tween_property(stamp, "scale", Vector2.ONE, PAID_SLAM)


## The receipt tears off under the shift's lines, with `rip`.
func _tear() -> void:
	sfx.play("rip")
	_fade_in(_receipt.add_tear())


## The next shift's inspection prints in red under the tear: the printer feeds it, then the
## clerk's stamp lands (#62, Q5).
func _print_notice(notice: String, print_pitch: float) -> void:
	_fade_in(_receipt.add_notice(notice))
	sfx.play("print", print_pitch)
	await _wait(NOTICE_STAMP_GAP)
	sfx.play("stamp_notice")


func _fade_in(line: Control) -> void:
	line.modulate.a = 0.0
	_tween().tween_property(line, "modulate:a", 1.0, CountUp.LINE_FADE)


func _wait(seconds: float) -> void:
	var tween: Tween = _tween()
	tween.tween_interval(seconds)
	await tween.finished


func _wait_ms(ms: int) -> void:
	await _wait(ms / 1000.0)


func _tween() -> Tween:
	return _make_tween.call() as Tween
