class_name StoreClosed
extends Control
## The store closes behind the run's final receipt (#56, results option 2 "Store closed"): the
## lights go down over the shift screen, a roller shutter rolls down from the window's top over
## the top bar and the store, with a CLOSED sign hanging on it, and a warm lamp lights the
## receipt (`focus`). ResultsPanel owns it, behind itself, over the whole window. Decor only: it
## takes no clicks, so the top bar's Cart and ☰ stay clickable through the shutter (full build
## plan 6.1), and the shift screen's shade, below the top bar, keeps the store unpressable.

## The lights go down over DARK_S; the shutter rolls down over SHUTTER_S, starting together.
const DARK_S := 0.4
const SHUTTER_S := 0.9
const DARK := Color(Palette.CHARCOAL, 0.72)
## The shutter stops this share of the window's height down.
const SHUTTER_STOP := 0.72
## Its slats: the slat, its shadow line and its lit line, in pixels, top to bottom.
const SLAT := 18.0
const SLAT_SHADOW := 3.0
const SLAT_LIGHT := 3.0
const BOTTOM_BAR := 8.0
const HANDLE_SIZE := Vector2(60, 10)
## The lights are down on the shutter too.
const SHUTTER_SHADE := Color(Palette.CHARCOAL, 0.45)
const SIGN_TEXT := "CLOSED"
const SIGN_FONT_SIZE := 34
const SIGN_PADDING := Vector2(20, 6)
const SIGN_TILT := -6.0
## The sign hangs from the shutter at this x, and its top this far above the shutter's foot.
const SIGN_X := 76.0
const SIGN_ABOVE_FOOT := 400.0
const SIGN_STRING := 18.0
const LAMP := Color(Palette.MUSTARD_PALE, 0.24)
## The lamp's pool is this much larger than the receipt.
const LAMP_GROW := 1.6

## The receipt's rect (global), which the lamp lights.
var focus: Rect2 = Rect2()
var _dark: float = 0.0
var _shutter: float = 0.0
var _lamp: GradientTexture2D
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, LAMP)
	gradient.set_color(1, Color(LAMP, 0.0))
	_lamp = GradientTexture2D.new()
	_lamp.gradient = gradient
	_lamp.fill = GradientTexture2D.FILL_RADIAL
	_lamp.fill_from = Vector2(0.5, 0.5)
	_lamp.fill_to = Vector2(1.0, 0.5)
	_lamp.width = 128
	_lamp.height = 128


## The lights go down and the shutter rolls down (at once when `at_once`).
func close_store(at_once: bool = false) -> void:
	if _tween != null:
		_tween.kill()
	if at_once:
		_set_dark(1.0)
		_set_shutter(1.0)
		return
	_set_dark(0.0)
	_set_shutter(0.0)
	_tween = create_tween()
	_tween.tween_method(_set_dark, 0.0, 1.0, DARK_S)
	(
		_tween
		. parallel()
		. tween_method(_set_shutter, 0.0, 1.0, SHUTTER_S)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN_OUT)
	)


## How far the shutter is down, 0 (up) to 1 (closed; for tests).
func shutter() -> float:
	return _shutter


## The shutter's foot, in local coordinates.
func shutter_foot() -> float:
	return size.y * SHUTTER_STOP * _shutter


func _set_dark(value: float) -> void:
	_dark = value
	queue_redraw()


func _set_shutter(value: float) -> void:
	_shutter = value
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(DARK, DARK.a * _dark))
	var foot: float = shutter_foot()
	if foot > 0.0:
		_draw_shutter(foot)
		_draw_sign(foot)
	if focus.has_area():
		var local: Rect2 = get_global_transform().affine_inverse() * focus
		var pool: Vector2 = local.size * LAMP_GROW
		var lamp: Color = Color(1, 1, 1, _dark)
		draw_texture_rect(_lamp, Rect2(local.get_center() - pool / 2.0, pool), false, lamp)


func _draw_shutter(foot: float) -> void:
	var y: float = foot - BOTTOM_BAR
	# The slats are drawn up from the foot, so they ride down with it.
	while y > 0.0:
		var top: float = y - SLAT - SLAT_SHADOW - SLAT_LIGHT
		_band(top, SLAT_LIGHT, Palette.STEEL_PALE)
		_band(top + SLAT_LIGHT, SLAT, Palette.STEEL)
		_band(top + SLAT_LIGHT + SLAT, SLAT_SHADOW, Palette.STEEL_SHADE)
		y = top
	_band(foot - BOTTOM_BAR, BOTTOM_BAR, Palette.STEEL_DARKEST)
	var handle: Rect2 = Rect2(
		Vector2((size.x - HANDLE_SIZE.x) / 2.0, foot - BOTTOM_BAR - HANDLE_SIZE.y), HANDLE_SIZE
	)
	draw_rect(handle, Palette.STEEL_DARK)
	draw_rect(Rect2(0, 0, size.x, foot), SHUTTER_SHADE)


## A full-width band from `top`, `height` high, clipped to the window's top.
func _band(top: float, height: float, color: Color) -> void:
	var from: float = maxf(top, 0.0)
	if top + height > from:
		draw_rect(Rect2(0, from, size.x, top + height - from), color)


func _draw_sign(foot: float) -> void:
	var font: Font = ArtStyle.DISPLAY_FONT
	var text: Vector2 = font.get_string_size(
		SIGN_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT_SIZE
	)
	var board: Vector2 = text + 2.0 * SIGN_PADDING
	var top: float = foot - SIGN_ABOVE_FOOT
	if top + board.y < 0.0:
		return
	var hook: Vector2 = Vector2(SIGN_X + board.x / 2.0, top - SIGN_STRING)
	draw_line(hook, Vector2(SIGN_X + 10.0, top), Palette.INK, 2.0)
	draw_line(hook, Vector2(SIGN_X + board.x - 10.0, top), Palette.INK, 2.0)
	draw_set_transform(Vector2(SIGN_X, top), deg_to_rad(SIGN_TILT))
	draw_rect(Rect2(Vector2.ZERO, board), Palette.TOMATO)
	draw_rect(Rect2(Vector2.ZERO, board), Palette.INK, false, 4.0)
	var baseline: Vector2 = Vector2(
		SIGN_PADDING.x, SIGN_PADDING.y + font.get_ascent(SIGN_FONT_SIZE)
	)
	draw_string(
		font, baseline, SIGN_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT_SIZE, Palette.PAPER
	)
	draw_set_transform(Vector2.ZERO)
