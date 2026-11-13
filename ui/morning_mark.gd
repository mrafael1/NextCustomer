class_name MorningMark
extends TipTarget
## A part of the MORNING's line on the belt (v1.24, KeywordMarks): a pin or the anchor post
## (MorningPin) or a stretch of chain (MorningLink), in the Breakfast family's colours
## (data/families, as the MORNING chip's dot). Each is the MORNING keyword's tip target on the
## belt, as the chip on a ticket is: resting the pointer on it shows MORNING's tooltip
## (GlyphText.keyword_tip), and a right-click then opens the staff handbook at MORNING; its
## hover_rect is HOVER_HEIGHT tall at least, so the slim chain is easy to hit. Lit (set_lit: a
## MORNING tooltip shows) its face turns gold and its light rows paper, as a lit frame's do; its own
## tooltip showing calls `on_tip` (KeywordMarks lights the whole line, in a handbook clip too). It
## takes no clicks.

## The least height of the place the pointer finds it, and the extra room round it.
const HOVER_HEIGHT := 20.0
const HOVER_GROW := 2.0
const SHADOW_ALPHA := 0.38
const CALM_LIGHT := Palette.MUSTARD_PALE
const LIT_FACE := Palette.GOLD
const LIT_LIGHT := Palette.PAPER
## The face when the families' palette can't be read (the Breakfast mustard).
const FALLBACK_FACE := Palette.MUSTARD

## Called with whether its tooltip shows (KeywordMarks.light_morning). None: nothing.
var on_tip: Callable = Callable()
var _lit: bool = false
var _face: Color = FALLBACK_FACE


func _init() -> void:
	super()
	tip_text = GlyphText.keyword_tip(CardText.MORNING_WORD)
	tip_kind = TipSpec.Kind.KEYWORD
	tip_title = CardText.MORNING_WORD
	tip_tag = TipSpec.KEYWORD_TAG
	var family: Resource = KeywordChip.dot_family(CardText.MORNING_WORD)
	if family != null:
		_face = family.get("face")


## Lights it (a MORNING tooltip shows) or puts it back.
func set_lit(lit: bool) -> void:
	if _lit == lit:
		return
	_lit = lit
	queue_redraw()


func is_lit() -> bool:
	return _lit


## Its face's colour now: the Breakfast family's, gold when lit.
func face_color() -> Color:
	return LIT_FACE if _lit else _face


## Its light rows' colour now: mustard pale, paper when lit.
func light_color() -> Color:
	return LIT_LIGHT if _lit else CALM_LIGHT


func tip_shown(shown: bool) -> void:
	if on_tip.is_valid():
		on_tip.call(shown)


func hover_rect() -> Rect2:
	var rect: Rect2 = get_global_rect()
	var tall: float = HOVER_HEIGHT * get_global_transform().get_scale().y
	var extra: float = maxf(tall - rect.size.y, 0.0) / 2.0
	return rect.grow_individual(0.0, extra, 0.0, extra).grow(HOVER_GROW)
