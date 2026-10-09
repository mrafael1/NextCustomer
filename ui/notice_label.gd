class_name NoticeLabel
extends Label
## A short red notice beside the totals (e.g. a product that doesn't fit, plan section 3.1). It
## stays for SHOW_SECONDS, then fades. It only displays: the rules come from RowCapacity.

## How long a notice stays before it fades.
const SHOW_SECONDS := 2.2

var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", Palette.TOMATO)


func show_notice(notice: String) -> void:
	text = notice
	modulate = Color.WHITE
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(SHOW_SECONDS)
	_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.4)


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
			"Row full (%d/%d cards): take a card out first" % [row.size(), limits.card_limit()]
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
