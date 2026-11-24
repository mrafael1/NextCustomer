class_name PickySign
extends Control
## The Picky regular's promo sign (#182 grade 5; the user's play tests of 2026-11-24: "under badge
## icon there could be a sign with family icon for picky regular", then "sign under grade should be
## like a promo sign: icon with promo on it (-25%)"): a supermarket promo card (art/icons/
## promo_sign, pixel art at ART_SCALE) hanging on two ink strings through its punched holes under
## the top bar's grade badge on a Picky regular day. Its mustard face shows today's family glyph
## (the family palette's 9x9 art at GLYPH_SCALE, DayCalendar.twist_glyph) and its tomato band the
## day's cut in paper ("-25%", GradeRules.promo_text: the day's drawn cut, in the number font), so
## the player sees at a glance which family is on promo and by how much. Its hover tip names the
## day: "Promo day" over its event's notice ("Dairy price reduced by 25%", the cut in tomato:
## TipMarkup) and "today". Hidden on a day without one (show_day). Display only, apart from its tip.

const ART := preload("res://art/icons/promo_sign.png")
const ART_SCALE := 2.0
## The strings' length above the card and their centres (art px from the card's left: its holes),
## their width and how far they run down into the holes (px).
const STRING_PX := 6.0
const STRING_HOLES: Array[float] = [4.0, 24.0]
const LINE_PX := 2.0
const STRING_INTO := 6.0
## The glyph on the face (art px from the card's top-left, and its scale) and the cut's band (art
## px: its rect on the card), its font size and ink.
const GLYPH_AT := Vector2(5, 4)
const GLYPH_SCALE := 4.0
const GLYPH_ART := Vector2(9, 9)
const BAND := Rect2(2, 24, 24, 10)
const CUT_SIZE := 16
const CUT_INK := Palette.PAPER
## The tip: the day's notice, then this word.
const TODAY := "%s today"

## The family shown ("" while hidden), and the cut ("-25%").
var family: String = ""
var cut_text: String = ""

var _card: TextureRect
var _glyph: TextureRect
var _cut: Label


func _init() -> void:
	name = "PickySign"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_card = UiKit.sprite(ART)
	_card.name = "Card"
	_card.size = ART.get_size() * ART_SCALE
	_card.position = Vector2(0, STRING_PX)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_glyph = TextureRect.new()
	_glyph.name = "Glyph"
	_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph.stretch_mode = TextureRect.STRETCH_SCALE
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.size = GLYPH_ART * GLYPH_SCALE
	_glyph.position = GLYPH_AT * ART_SCALE
	ArtStyle.use_pixel_material(_glyph)
	_card.add_child(_glyph)
	_cut = UiKit.number_label("", CUT_SIZE, false)
	_cut.name = "Cut"
	_cut.add_theme_color_override("font_color", CUT_INK)
	_cut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cut.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cut.position = BAND.position * ART_SCALE
	_cut.size = BAND.size * ART_SCALE
	_cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_cut)
	size = Vector2(_card.size.x, STRING_PX + _card.size.y)
	custom_minimum_size = size


## Shows `run`'s Picky regular for today (GradeRules.picky_event) with its cut, or hides the sign.
func show_day(run: RunState) -> void:
	var event: InspectionDefinition = GradeRules.picky_event(run) if run != null else null
	var image: Image = DayCalendar.twist_glyph(event)
	family = GradeRules.picky_family(run) if image != null else ""
	cut_text = GradeRules.promo_text(run) if image != null else ""
	visible = image != null
	if image == null:
		_glyph.texture = null
		_cut.text = ""
		TipTarget.cover_text(self, "")
		return
	_glyph.texture = ImageTexture.create_from_image(image)
	_cut.text = cut_text
	TipTarget.cover_text(
		self, TODAY % event.notice_text, TipSpec.Kind.WORD, "", "", event.display_name
	)
	queue_redraw()


## The card under the strings (tests check it clears its neighbours).
func board_rect() -> Rect2:
	return Rect2(_card.position, _card.size)


## The glyph's texture, or null (tests).
func glyph_texture() -> Texture2D:
	return _glyph.texture


## The glyph's rect and the cut's label (tests check they sit on the card).
func glyph_rect() -> Rect2:
	return Rect2(_card.position + _glyph.position, _glyph.size)


func cut_label() -> Label:
	return _cut


func _draw() -> void:
	for hole: float in STRING_HOLES:
		var x: float = hole * ART_SCALE - LINE_PX / 2.0
		draw_rect(Rect2(x, 0, LINE_PX, STRING_PX + STRING_INTO), Palette.INK)
