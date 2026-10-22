class_name GiverBadge
extends Control
## The giver's mini badge on a planning sticker (#71, mock-up h1, H1_BUILD_SPEC.md section 2.5):
## a token by the giver's kind (a product, a coupon or a loyalty upgrade) holding its initials,
## or the inspection's warning icon. A product with a mini (CardDefinition.badge_mini_ref, sticker
## minis) shows instead its hand-drawn 7x7 mini alone, die-cut, with only its own outline (ink,
## gold for a GOLDEN giver): no token, no initials. The rail strip names the exact item or
## coupon, and the hover rings the upgrade's box. Decor only: it takes no clicks. Drained
## (another item hovered, or on a denied item) its token or mini greys (ArtStyle.Grey.DRAINED)
## and its initials step back.

enum Kind { NONE, ITEM, COUPON, LOYALTY, INSPECTION }

## A product's or coupon's badge holds this many letters of its name.
const CARD_INITIALS := 2
## A loyalty badge holds the upgrade's initials (as its loyalty box), at most this many.
const LOYALTY_INITIALS := 3
## The token (9x9 art at 2x) and the inspection's warning icon (13x11 at 2x).
const SIZE := Vector2(18, 18)
const INSPECTION_SIZE := Vector2(26, 22)
## A mini (7x7 art at 2x), centred in the badge's SIZE so the stack's layout stays as with a token.
const MINI_SIZE := Vector2(14, 14)
## The initials: Pixelify, the largest of these sizes whose width fits INITIALS_WIDTH.
const INITIALS_SIZES: Array[int] = [9, 8, 7]
const INITIALS_WIDTH := 12.0

const ITEM_TOKEN := preload("res://art/effects/badge_item.png")
const COUPON_TOKEN := preload("res://art/effects/badge_coupon.png")
const LOYALTY_TOKEN := preload("res://art/effects/badge_stamp.png")
const WARNING := preload("res://art/icons/warning.png")

var kind: Kind = Kind.NONE
var _token: TextureRect
var _initials: Label
var _drained: bool = false
var _mini: bool = false


## A `badge_kind` badge holding `badge_initials` (none for an inspection), or for an ITEM with a
## `mini_ref` (a texture path that exists), that mini instead. A missing path falls back to the
## initials quietly: a stale `mini_art_ref` in the data is caught by live_cards_test (every
## product's mini ref must load), not here.
func _init(badge_kind: Kind, badge_initials: String, mini_ref: String = "") -> void:
	kind = badge_kind
	name = "GiverBadge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = INSPECTION_SIZE if kind == Kind.INSPECTION else SIZE
	custom_minimum_size = size
	if kind == Kind.ITEM and not mini_ref.is_empty() and ResourceLoader.exists(mini_ref):
		_mini = true
		_token = UiKit.sprite(load(mini_ref) as Texture2D)
		_token.name = "Mini"
		_token.size = MINI_SIZE
		_token.position = ((size - MINI_SIZE) / 2.0).floor()
		add_child(_token)
		return
	var tokens: Dictionary[Kind, Texture2D] = {
		Kind.ITEM: ITEM_TOKEN,
		Kind.COUPON: COUPON_TOKEN,
		Kind.LOYALTY: LOYALTY_TOKEN,
		Kind.INSPECTION: WARNING,
	}
	_token = UiKit.sprite(tokens.get(kind, ITEM_TOKEN))
	_token.name = "Token"
	_token.size = size
	add_child(_token)
	if kind == Kind.INSPECTION or badge_initials.is_empty():
		return
	_initials = UiKit.display_label(badge_initials, INITIALS_SIZES[-1], false)
	_initials.name = "Initials"
	_initials.add_theme_font_size_override("font_size", _initials_size(badge_initials))
	_initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_initials.size = size
	add_child(_initials)
	_colour_initials()


## The initials a `badge_kind` badge shows for a giver named `display_name`: a card's first two
## letters ("Eggs" → "Eg", spaces skipped), an upgrade's LoyaltyCard.initials capped at
## LOYALTY_INITIALS, and none for an inspection (its icon) or no badge.
static func initials_for(badge_kind: Kind, display_name: String) -> String:
	match badge_kind:
		Kind.ITEM, Kind.COUPON:
			var letters: String = display_name.replace(" ", "").substr(0, CARD_INITIALS)
			return letters.substr(0, 1).to_upper() + letters.substr(1).to_lower()
		Kind.LOYALTY:
			return LoyaltyCard.initials(display_name).substr(0, LOYALTY_INITIALS)
	return ""


## Greys the token and steps the initials back (`drained`), or puts the look back.
func set_drained(drained: bool) -> void:
	_drained = drained
	ArtStyle.set_look(_token, ArtStyle.grey_material(ArtStyle.Grey.DRAINED) if drained else null)
	_colour_initials()


func is_drained() -> bool:
	return _drained


## Whether it shows a product's mini (no token, no initials).
func shows_mini() -> bool:
	return _mini


## The drawn texture: the mini, the token or the warning icon (for tests).
func texture() -> Texture2D:
	return _token.texture


## The drawn texture's rectangle in the badge (for tests).
func art_rect() -> Rect2:
	return Rect2(_token.position, _token.size)


## The initials shown, or empty (for tests).
func initials() -> String:
	return _initials.text if _initials != null else ""


## The initials' colour: ink on the cream item token, mustard pale on the stamp, paper on the
## teal coupon; drained, grey on the greyed token.
func _colour_initials() -> void:
	if _initials == null:
		return
	var colour: Color = Palette.INK
	match kind:
		Kind.COUPON:
			colour = Palette.PAPER
		Kind.LOYALTY:
			colour = Palette.MUSTARD_PALE
	if _drained:
		colour = Palette.GREY_DARK if kind == Kind.ITEM else Palette.GREY_LIGHT
	_initials.add_theme_color_override("font_color", colour)


## The largest INITIALS_SIZES size at which `text` fits INITIALS_WIDTH.
static func _initials_size(text: String) -> int:
	for font_size: int in INITIALS_SIZES:
		var width: float = (
			ArtStyle.DISPLAY_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
		if width <= INITIALS_WIDTH:
			return font_size
	return INITIALS_SIZES[-1]
