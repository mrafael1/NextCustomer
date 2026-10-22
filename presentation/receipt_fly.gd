class_name ReceiptFly
extends RefCounted
## A payout's paper "+€N" chip (#86 v6): it flies from the item at the scanner to the payout's
## receipt line (the control ReceiptView.add_step returned, followed live as the receipt scrolls)
## and the line, printed hidden at the beat's start, fades in as the chip lands. The receipt's
## text and framing never change. On the count-up's tweens (`make_tween`), so taps, holds and
## hit-stops apply to it. Under reduced motion nothing flies: the line shows at once.

## The chip's flight at speed 1, in seconds: the payout's roll kept between these.
const FLIGHT_MIN := 0.12
const FLIGHT_MAX := 0.22
const FONT_SIZE := 16
const BORDER := 2
const PADDING := Vector2i(6, 1)
## The line fades in over this as the chip lands.
const LINE_FADE := CountUp.LINE_FADE
## Marks the chips among the overlay's children (is_chip).
const CHIP_META := &"receipt_chip"

## No flights: each line shows at once (the player's reduced motion setting).
var reduced_motion: bool = false
var _overlay: Control
## Returns a new Tween that follows the count-up's speed.
var _make_tween: Callable


func _init(overlay: Control, make_tween: Callable) -> void:
	_overlay = overlay
	_make_tween = make_tween


## Flies `text` from `from` (a global rect: from its centre) to `line` over `seconds`, then fades
## `line` in (`reveal`; else the line, already shown, is left as it is). No line: nothing flies.
## Under reduced motion the line shows at once.
func fly(text: String, from: Rect2, line: Control, seconds: float, reveal: bool = true) -> void:
	if line == null:
		return
	if reduced_motion or seconds <= 0.0:
		line.modulate.a = 1.0
		return
	var chip: PanelContainer = make_chip(text)
	_overlay.add_child(chip)
	chip.size = chip.get_minimum_size()
	var start: Vector2 = from.get_center()
	_place(0.0, chip, start, line)
	var tween: Tween = _make_tween.call() as Tween
	(
		tween
		. tween_method(_place.bind(chip, start, line), 0.0, 1.0, seconds)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN_OUT)
	)
	tween.tween_callback(_land.bind(chip, line, reveal))


## "+€N" for a payout, "€0" for none.
static func amount_text(payout: int) -> String:
	return "+€%d" % payout if payout > 0 else "€0"


## A flying chip of this class (among the overlay's children).
static func is_chip(node: Node) -> bool:
	return node != null and node.has_meta(CHIP_META)


## Where a chip of `chip_size` lands on `line` (global centre): at the line's right end, where
## its amount stands, inside the line's rect.
static func landing_point(line: Control, chip_size: Vector2) -> Vector2:
	var rect: Rect2 = line.get_global_rect()
	return Vector2(rect.end.x - minf(chip_size.x, rect.size.x) / 2.0, rect.get_center().y)


## The paper chip: ink text in the number font on paper, in an ink border.
static func make_chip(text: String) -> PanelContainer:
	var chip: PanelContainer = PanelContainer.new()
	chip.set_meta(CHIP_META, true)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.INK
	style.set_border_width_all(BORDER)
	style.content_margin_left = BORDER + PADDING.x
	style.content_margin_right = BORDER + PADDING.x
	style.content_margin_top = BORDER + PADDING.y
	style.content_margin_bottom = BORDER + PADDING.y
	chip.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", ArtStyle.number_font())
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Palette.INK)
	chip.add_child(label)
	return chip


## Puts the chip `progress` (eased, 0 to 1) of the way from `start` to its landing point on
## `line` as the line is now, on whole pixels and inside the overlay. Untyped: either may have
## been freed (the receipt starting over).
func _place(progress: float, chip: Variant, start: Vector2, line: Variant) -> void:
	if not is_instance_valid(chip) or not is_instance_valid(line):
		return
	var flying: Control = chip as Control
	var centre: Vector2 = start.lerp(landing_point(line as Control, flying.size), progress)
	var area: Rect2 = _overlay.get_global_rect()
	var corner: Vector2 = (centre - flying.size / 2.0).round()
	corner = corner.clamp(area.position, (area.end - flying.size).max(area.position))
	flying.global_position = corner


## The chip lands: it goes and its line fades in (`reveal`).
func _land(chip: Variant, line: Variant, reveal: bool) -> void:
	if is_instance_valid(chip):
		(chip as Node).queue_free()
	if reveal and is_instance_valid(line):
		var tween: Tween = _make_tween.call() as Tween
		tween.tween_property(line as Control, "modulate:a", 1.0, LINE_FADE)
