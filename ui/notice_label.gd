class_name NoticeLabel
extends Label
## A short notice on the monitor's paper screen (MonitorView.NOTICE_RECT; e.g. a product that
## doesn't fit, plan section 3.1). It stays for SHOW_SECONDS, then fades. It only displays: the
## rules come from RowCapacity.
##
## It fades by `modulate` and clears by emptying its text, so `visible` never changes. Nothing on
## the stage hides to make room for it; showing_changed is kept for callers and tests that follow
## whether a notice shows.
##
## A notice that should not cut in (the shift's opening notice, which plays a moment after the
## shift starts) waits with show_next for one the player's own action raised (an armed Price
## gun's, #132) to fade or be ended (end_notice); clear_notice drops it.

## Emitted when a notice starts showing (true) and when it has faded or been cleared (false).
signal showing_changed(showing: bool)
## Emitted on every show_notice, also when it replaces a notice still showing (MonitorView fits
## the text's size to its strip on it).
signal notice_shown(notice: String)

## How long a notice stays before it fades.
const SHOW_SECONDS := 2.2
## How long the fade lasts.
const FADE_SECONDS := 0.4

var _tween: Tween
var _showing: bool = false
## The notice waiting for the shown one to go (show_next), or "".
var _next: String = ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.style_notice(self)


func show_notice(notice: String) -> void:
	text = notice
	modulate = Color.WHITE
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(SHOW_SECONDS)
	_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), FADE_SECONDS)
	_tween.tween_callback(_on_faded)
	notice_shown.emit(notice)
	_set_showing(true)


## Shows `notice` now, or, while another notice shows, once that one has faded or been ended.
func show_next(notice: String) -> void:
	if _showing:
		_next = notice
	else:
		show_notice(notice)


## Ends the shown notice; the one waiting (show_next) shows instead.
func end_notice() -> void:
	var waiting: String = _next
	clear_notice()
	if not waiting.is_empty():
		show_notice(waiting)


## True from show_notice until the notice has faded or been cleared.
func is_showing() -> bool:
	return _showing


## Plan section 3.1: no card fits once the row holds as many cards as the shift has slots (any
## card fits any free slot). Shows why and returns true, or returns false when it fits.
func explain_refusal(limits: ShiftLimits, row: Array[CardInstance]) -> bool:
	if RowCapacity.fits(limits, row):
		return false
	show_notice(
		(
			"Row full (%d/%d items): take an item out first"
			% [row.size(), RowCapacity.card_limit(limits)]
		)
	)
	return true


## Clears the shown notice and drops the one waiting.
func clear_notice() -> void:
	_next = ""
	if _tween != null:
		_tween.kill()
		_tween = null
	text = ""
	_set_showing(false)


## The end of the fade: the notice no longer shows.
func _on_faded() -> void:
	_tween = null
	_set_showing(false)
	if not _next.is_empty():
		var waiting: String = _next
		_next = ""
		show_notice(waiting)


func _set_showing(showing: bool) -> void:
	if showing == _showing:
		return
	_showing = showing
	showing_changed.emit(showing)
