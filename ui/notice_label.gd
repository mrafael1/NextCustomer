class_name NoticeLabel
extends Label
## A short red notice on the monitor's paper screen (ShiftStage.NOTICE_RECT; e.g. a product that
## doesn't fit, plan section 3.1). It stays for SHOW_SECONDS, then fades. It only displays: the
## rules come from RowCapacity.
##
## It fades by `modulate` and clears by emptying its text, so `visible` never changes. Nothing on
## the stage hides to make room for it; showing_changed is kept for callers and tests that follow
## whether a notice shows.

## Emitted when a notice starts showing (true) and when it has faded or been cleared (false).
signal showing_changed(showing: bool)

## How long a notice stays before it fades.
const SHOW_SECONDS := 2.2
## How long the fade lasts.
const FADE_SECONDS := 0.4

var _tween: Tween
var _showing: bool = false


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
	_set_showing(true)


## True from show_notice until the notice has faded or been cleared.
func is_showing() -> bool:
	return _showing


## Plan section 3.1: no card fits once the row holds as many cards as the shift allows (a coupon
## past the coupon-only slots uses a product slot, so this can come before the products are
## full), and a product doesn't fit once every product slot is used, even when a coupon slot is
## still free. Shows why and returns true, or returns false when it fits.
func explain_refusal(card: CardDefinition, limits: ShiftLimits, row: Array[CardInstance]) -> bool:
	var row_full: bool = row.size() >= RowCapacity.card_limit(limits)
	if card.is_coupon() or not RowCapacity.products_full(limits, row):
		if not row_full:
			return false
		show_notice(
			"Row full (%d/%d items): take an item out first" % [row.size(), limits.card_limit()]
		)
		return true
	var products: String = "%d/%d products" % [RowCapacity.product_count(row), limits.slot_count]
	if row.size() < RowCapacity.card_limit(limits):
		show_notice("%s: only a coupon fits now" % products)
	else:
		show_notice("%s: take a product out first" % products)
	return true


func clear_notice() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	text = ""
	_set_showing(false)


## The end of the fade: the notice no longer shows.
func _on_faded() -> void:
	_tween = null
	_set_showing(false)


func _set_showing(showing: bool) -> void:
	if showing == _showing:
		return
	_showing = showing
	showing_changed.emit(showing)
