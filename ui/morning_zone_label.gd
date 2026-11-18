class_name MorningZoneLabel
extends TipTarget
## The MORNING ZONE's label on the belt (2026-11-18, MorningBand): a small rising sun
## (art/icons/morning_sun.png at 2x) and "MORNING" in hard pixel words, ink on the zone's painted
## strip, centred on the zone's middle patch (MorningZoneTile). It is the MORNING keyword's tip
## target on the belt, as the chip on a ticket is: resting the pointer on it shows MORNING's
## tooltip (GlyphText.keyword_tip), and a right-click then opens the staff handbook at MORNING; its
## tooltip showing calls `on_tip` (the zone's print lights). It takes no clicks.

const SUN := preload("res://art/icons/morning_sun.png")
const SUN_SIZE := Vector2(22, 14)
const GAP := 4.0
const TEXT_SCALE := 2
const INK := Palette.INK
## The room the pointer finds it in, past its rect.
const HOVER_GROW := 2.0
const SUN_NAME := &"Sun"
const TEXT_NAME := &"Text"

## Called with whether its tooltip shows. None: nothing.
var on_tip: Callable = Callable()


func _init() -> void:
	super()
	name = "MorningZoneLabel"
	tip_text = GlyphText.keyword_tip(CardText.MORNING_WORD)
	tip_kind = TipSpec.Kind.KEYWORD
	tip_title = CardText.MORNING_WORD
	tip_tag = TipSpec.KEYWORD_TAG
	var sun_icon: TextureRect = UiKit.sprite(SUN)
	sun_icon.name = SUN_NAME
	sun_icon.size = SUN_SIZE
	add_child(sun_icon)
	var text: Label = UiKit.pixel_label(CardText.MORNING_WORD, TEXT_SCALE, INK)
	text.name = TEXT_NAME
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text)
	var font: Font = ArtStyle.pixel_display_font()
	var font_size: int = ArtStyle.PIXEL_TEXT_SIZE
	var words: Vector2 = (
		font.get_string_size(text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) * TEXT_SCALE
	)
	size = Vector2(SUN_SIZE.x + GAP + words.x, MorningZoneTile.STRIP)
	sun_icon.position = Vector2(0, (size.y - SUN_SIZE.y) / 2.0)
	var room: Rect2 = Rect2(SUN_SIZE.x + GAP, 0, words.x, size.y)
	UiKit.place_pixel_label(text, room, true)


## The sun and the words (for tests).
func sun() -> TextureRect:
	return get_node(NodePath(SUN_NAME)) as TextureRect


func text_label() -> Label:
	return get_node(NodePath(TEXT_NAME)) as Label


func tip_shown(shown: bool) -> void:
	if on_tip.is_valid():
		on_tip.call(shown)


func hover_rect() -> Rect2:
	return get_global_rect().grow(HOVER_GROW)
