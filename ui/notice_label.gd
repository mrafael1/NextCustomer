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


## Plan section 3.1: a product doesn't fit once every product slot is used, even when the
## coupon slot is still free. Shows why and returns true, or returns false when it fits.
func explain_refusal(
	card: CardDefinition, balance: BalanceDefinition, row: Array[CardInstance]
) -> bool:
	if card.is_coupon() or not RowCapacity.products_full(balance, row):
		return false
	var products: String = "%d/%d products" % [RowCapacity.product_count(row), balance.slot_count]
	if row.size() < RowCapacity.card_limit(balance):
		show_notice("%s: only a coupon fits now" % products)
	else:
		show_notice("%s: take a product out first" % products)
	return true


func clear_notice() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	text = ""
