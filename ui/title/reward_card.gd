class_name RewardCard
extends Button
## A card on the REWARDS menu (#56, mock-up title_premium_directions.html, rewardCard): a cream
## card with a teal header band holding its name in paper (frames/reward_card), or, LOCKED (a
## reward still to come, LOYALTY), a grey band over a cream shade face (reward_card_locked).
## The menu lays its picture and lines on content(), in canvas px from the card's top left.
##
## The mouse or the keyboard marker on it (`marked`, set by the menu) lifts it LIFT px and rings
## it in gold (the _hot frames). It never takes focus (Space must not press it behind the menu's
## back). A locked card lifts too, so a player can see it is there, but keeps the arrow cursor:
## the menu answers its press with a denied sound and nothing else. Nothing here moves on its
## own: every change is one step, on input.

const FRAME := preload("res://art/frames/reward_card.png")
const HOT_FRAME := preload("res://art/frames/reward_card_hot.png")
const LOCKED_FRAME := preload("res://art/frames/reward_card_locked.png")
const LOCKED_HOT_FRAME := preload("res://art/frames/reward_card_locked_hot.png")
## The frames' 9-slice margins (left and right, top, bottom), in art px: the header band is in
## the top margin, so it keeps its height at any card size. A hot frame adds its gold ring.
const MARGINS := Vector3i(2, 17, 3)
const RING := 1
## The card's size: 154x140 art.
const SIZE := Vector2(308, 280)
## How far a marked card lifts, in canvas px (2 art px).
const LIFT := 4.0
## The name: hard pixel words at 2x (UiKit.pixel_label), in paper, in the header band (canvas
## px).
const TITLE_TEXT_SCALE := 2
const TITLE_RECT := Rect2(16, 2, 276, 32)

## The mouse or the keyboard marker is on the card (the menu sets it): it lifts and rings.
var marked: bool = false:
	set(value):
		marked = value
		_show_card()

var _locked: bool
var _frame: PanelContainer
var _styles: Array[StyleBoxTexture] = []
var _content: Control
var _title: Label


## A card named `title_text`; `locked` for a reward still to come.
func _init(title_text: String, locked: bool = false) -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	_locked = locked
	size = SIZE
	custom_minimum_size = SIZE
	accessibility_name = title_text
	mouse_default_cursor_shape = CURSOR_ARROW if locked else CURSOR_POINTING_HAND
	_styles = [
		_style(LOCKED_FRAME if locked else FRAME, 0),
		_style(LOCKED_HOT_FRAME if locked else HOT_FRAME, RING),
	]
	_frame = PanelContainer.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(_frame)
	add_child(_frame, false, Node.INTERNAL_MODE_FRONT)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size = SIZE
	add_child(_content, false, Node.INTERNAL_MODE_FRONT)
	_title = UiKit.pixel_label(title_text, TITLE_TEXT_SCALE, Palette.PAPER)
	UiKit.place_pixel_label(_title, TITLE_RECT, true)
	_content.add_child(_title)
	_show_card()


func is_locked() -> bool:
	return _locked


## The layer the card's picture and lines go on (it lifts with the card).
func content() -> Control:
	return _content


func title_label() -> Label:
	return _title


## The card's frame (its look: normal or hot).
func frame() -> PanelContainer:
	return _frame


## A frame's style: MARGINS (and `ring` art px more on every side), in canvas px.
func _style(texture: Texture2D, ring: int) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	var art_scale: int = ArtStyle.ART_SCALE
	style.texture_margin_left = (MARGINS.x + ring) * art_scale
	style.texture_margin_right = (MARGINS.x + ring) * art_scale
	style.texture_margin_top = (MARGINS.y + ring) * art_scale
	style.texture_margin_bottom = (MARGINS.z + ring) * art_scale
	return style


## The look of `marked`: lifted LIFT px in its gold ring, or at rest.
func _show_card() -> void:
	var lift: float = LIFT if marked else 0.0
	var ring: float = float(RING * ArtStyle.ART_SCALE) if marked else 0.0
	_frame.add_theme_stylebox_override("panel", _styles[1 if marked else 0])
	_frame.position = Vector2(-ring, -lift - ring)
	_frame.size = SIZE + Vector2(ring, ring) * 2.0
	_content.position = Vector2(0.0, -lift)
