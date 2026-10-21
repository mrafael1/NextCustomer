class_name LedBeat
extends Control
## The line under the count's digits (#86 v6 scan count-up, mock-up count_up_86_v6_scan.html;
## LedDisplay.Layout.COUNT, on the monitor's paper at LedDisplay.COUNT_TO_GO_RECT): how far the
## quota is, "€N to go" in dark tomato, in ink once the amount is near the quota
## (QuotaMeter.NEAR_SHARE). Its text follows to_go_text (core's ShiftMargin of the shown amount:
## "Spot on" or "+€N" past it), but it shows only while the amount is short of the quota, as in the
## mock-up: past it the line is the SPEND MET stamp's place (stamp(), MetStamp), and the "+€N" is
## the tab beside the stamp (OverTab). So a last payout crossing the quota (met with the TOTAL, D5)
## leaves the line empty through the held breath instead of saying "+€N" before the stamp. It also
## hides once the count is met (set_met), before the stamp lands. The LED owns it and shows it in
## its count layout only. Display only: the margin is the LED's.

## The line's text, centred on its row: TO_GO_FONT_SIZE px at TO_GO_WEIGHT.
const TO_GO_FONT_SIZE := 18
const TO_GO_WEIGHT := 800
## The line's text: short of the quota, on it and past it (ShiftMargin's kinds).
const TO_GO_TEXT := "€%d to go"
const ON_QUOTA_TEXT := "Spot on"
const OVER_TEXT := "+€%d"
## Dark tomato while short of the quota (tomato is only for fizzles, CHECKOUT and CLOSED, and
## #86's "€N to go"; the top bar's tag shares it), ink from NEAR_SHARE of it on.
const FIZZLE_COLOR := Palette.TOMATO_DARK
const NEAR_COLOR := Palette.INK
## The stamp's top left in the line's coordinates (stage (640,184) over the line at (615,183): 36 px
## left of the line's centre, so the stamp and the "+€N" tab beside it sit centred under the number
## and its €; monitor bay follow-up, mock-up monitor_bay_v1.html).
const STAMP_POSITION := Vector2(25, 1)

## Returns a new tween on the count-up's clock: CountUp sets its own (tween_maker()), so motion on
## it follows the count's speed (taps, holds) and freezes in its hit-stops. The monitor's scanner
## bay takes its per-beat motion from it (new_tween). None means the line's own tween.
var make_tween: Callable = Callable()

var _to_go: Label
var _stamp: MetStamp
## The amount is near the quota, short of it.
var _near: bool = false
## The amount is short of the quota (the line has something to go).
var _short: bool = true
## The count has met the quota (set_met): the line stays hidden.
var _met: bool = false


func _init() -> void:
	name = "Beat"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_to_go = UiKit.body_label("", TO_GO_FONT_SIZE, FIZZLE_COLOR)
	_to_go.add_theme_font_override("font", ArtStyle.bold_font(TO_GO_WEIGHT))
	_to_go.add_theme_constant_override("outline_size", 0)
	_to_go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_to_go.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_to_go)
	_stamp = MetStamp.new()
	_stamp.position = STAMP_POSITION
	_stamp.showing_changed.connect(_on_stamp_showing)
	add_child(_stamp)
	_lay_out()


func _ready() -> void:
	_lay_out()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_lay_out()


## The line for `margin`, the shown amount's against `quota` (to_go_text): dark tomato short of the
## quota, ink once near it; hidden on or past it (the stamp's place).
func show_to_go(margin: ShiftMargin, quota: int) -> void:
	_to_go.text = to_go_text(margin)
	var short: bool = margin.kind() == ShiftMargin.Kind.SHORT
	_short = short
	_near = short and quota > 0 and quota - margin.amount() >= quota * QuotaMeter.NEAR_SHARE
	var ink: bool = _near or not short
	_to_go.add_theme_color_override("font_color", NEAR_COLOR if ink else FIZZLE_COLOR)
	_lay_out()


## Whether the count has met the quota: from then on the line hides (the stamp replaces it).
func set_met(met: bool) -> void:
	_met = met
	_lay_out()


## A new count (or the LED blank): the stamp goes and the line comes back.
func clear_beat() -> void:
	_met = false
	_short = true
	_stamp.hide_stamp()
	_lay_out()


## Whether the amount is near the quota, short of it (the line in ink).
func is_near() -> bool:
	return _near


func to_go_label() -> Label:
	return _to_go


## The SPEND MET stamp over the line (MetStamp: slam, show_static).
func stamp() -> MetStamp:
	return _stamp


## A new tween from make_tween (the count-up's), or the line's own.
func new_tween() -> Tween:
	return make_tween.call() as Tween if make_tween.is_valid() else create_tween()


## The to-go text for `margin`, core's ShiftMargin of the shown amount against the quota: "€N to
## go" short of it, "Spot on" on it, "+€N" past it.
static func to_go_text(margin: ShiftMargin) -> String:
	match margin.kind():
		ShiftMargin.Kind.SHORT:
			return TO_GO_TEXT % margin.amount()
		ShiftMargin.Kind.ON:
			return ON_QUOTA_TEXT
	return OVER_TEXT % margin.amount()


func _on_stamp_showing(_showing: bool) -> void:
	_lay_out()


## The line over the whole row, shown while it says something, the amount is short of the quota,
## the count is not met and the stamp is off.
func _lay_out() -> void:
	_to_go.position = Vector2.ZERO
	_to_go.size = size
	var stamped: bool = _stamp != null and _stamp.is_showing()
	_to_go.visible = not _to_go.text.is_empty() and _short and not stamped and not _met
