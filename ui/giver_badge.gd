class_name GiverBadge
extends Control
## The giver's badge on a planning sticker (#105 readability v3): 28 px tokens for coupons and
## loyalty perks, and die-cut product plates with a larger 10x10 drawing, a paper rim and an ink
## edge (a GOLDEN giver has a gold rim). The card's existing 7x7 mini reference selects its plate
## in art/giver_badges; that small mini is still used in monitor lines. A missing plate falls
## back to the small mini; missing mini art falls back to initials. Inspection keeps its warning
## icon. A loyalty perk's token holds its perk icon (#108 follow-up: as its loyalty box,
## LoyaltyCard.perk_icon) when one fits inside the stamp, else its initials, and an Aisle run's
## badge wears the box's "×" tag at its top left (LoyaltyCard.make_run_tag), so a family's
## Regulars and Aisle run tell apart on the stickers too. Decor only, with the same drained grey
## as the sticker.

enum Kind { NONE, ITEM, COUPON, LOYALTY, INSPECTION }

## A product's or coupon's badge holds this many letters of its name.
const CARD_INITIALS := 2
## A loyalty badge holds the upgrade's initials (as its loyalty box), at most this many.
const LOYALTY_INITIALS := 3
## The token (14x14 art at 2x) and the inspection's warning icon (13x11 at 2x).
const SIZE := Vector2(28, 28)
const INSPECTION_SIZE := Vector2(26, 22)
## The original 7x7 mini at 2x, retained for fallback and monitor lines.
const MINI_SIZE := Vector2(14, 14)
## Readability v3: a 10x10 drawing inside a 14x14 die-cut plate, shown at 2x.
const PLATE_FOLDER := "res://art/giver_badges/"
## The initials: Pixelify, the largest of these sizes whose width fits INITIALS_WIDTH.
const INITIALS_SIZES: Array[int] = [11, 10, 9]
const INITIALS_WIDTH := 22.0
## The room inside the loyalty stamp token for a perk icon at the art scale (its 10x10 art inside
## the 14x14 token's rim).
const LOYALTY_ICON_ROOM := 20.0

const ITEM_TOKEN := preload("res://art/effects/badge_item_polished.png")
const COUPON_TOKEN := preload("res://art/effects/badge_coupon_polished.png")
const LOYALTY_TOKEN := preload("res://art/effects/badge_stamp_polished.png")
const WARNING := preload("res://art/icons/warning.png")

var kind: Kind = Kind.NONE
var _token: TextureRect
var _initials: Label
var _drained: bool = false
var _mini: bool = false
var _icon: TextureRect
var _run_tag: Control
var _run_colour: Color = Color()


## A `badge_kind` badge holding `badge_initials` (none for an inspection), or for an ITEM with a
## `mini_ref` (a texture path that exists), that mini instead; for a LOYALTY badge, `mini_ref` is
## the perk's icon (UpgradeDefinition.icon_ref), drawn on the stamp token instead of the initials
## when it fits. A missing path falls back to the initials quietly: a stale `mini_art_ref` in the
## data is caught by live_cards_test (every product's mini ref must load), not here. A LOYALTY
## badge with a `run_colour` (LoyaltyCard.run_mark_colour, an Aisle run's) wears the run tag.
func _init(
	badge_kind: Kind, badge_initials: String, mini_ref: String = "", run_colour: Color = Color()
) -> void:
	kind = badge_kind
	name = "GiverBadge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = INSPECTION_SIZE if kind == Kind.INSPECTION else SIZE
	custom_minimum_size = size
	if kind == Kind.ITEM and not mini_ref.is_empty() and ResourceLoader.exists(mini_ref):
		_mini = true
		var plate: String = PLATE_FOLDER.path_join(mini_ref.get_file())
		var framed: bool = ResourceLoader.exists(plate)
		_token = UiKit.sprite(load(plate if framed else mini_ref) as Texture2D)
		_token.name = "Mini"
		_token.size = SIZE if framed else MINI_SIZE
		_token.position = ((size - _token.size) / 2.0).floor()
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
	if kind == Kind.LOYALTY and run_colour != Color():
		_run_colour = run_colour
		_run_tag = LoyaltyCard.make_run_tag(run_colour)
		_run_tag.name = "RunTag"
	if kind == Kind.LOYALTY and _add_icon(mini_ref):
		_add_run_tag()
		return
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
	_add_run_tag()


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


## Greys the token, the perk icon and steps the initials back (`drained`), or puts the look back.
func set_drained(drained: bool) -> void:
	_drained = drained
	var look: ShaderMaterial = ArtStyle.grey_material(ArtStyle.Grey.DRAINED) if drained else null
	ArtStyle.set_look(_token, look)
	if _icon != null:
		ArtStyle.set_look(_icon, look)
	if _run_tag != null:
		# Drawn in code, so it greys by its colour, not the grey material.
		LoyaltyCard.set_run_tag_face(_run_tag, Palette.GREY_LIGHT if drained else _run_colour)
	_colour_initials()


func is_drained() -> bool:
	return _drained


## Whether it shows a product's mini (no token, no initials).
func shows_mini() -> bool:
	return _mini


## The Aisle run tag on a loyalty badge, or null (for tests).
func run_tag() -> Control:
	return _run_tag


## Whether a loyalty badge shows its perk icon on the token (no initials).
func shows_icon() -> bool:
	return _icon != null


## The perk icon on a loyalty badge's token, or null (for tests).
func icon_texture() -> Texture2D:
	return _icon.texture if _icon != null else null


## The drawn texture: the mini, the token or the warning icon (for tests).
func texture() -> Texture2D:
	return _token.texture


## The drawn texture's rectangle in the badge (for tests).
func art_rect() -> Rect2:
	return Rect2(_token.position, _token.size)


## The initials shown, or empty (for tests).
func initials() -> String:
	return _initials.text if _initials != null else ""


## Draws the perk icon at `icon_ref` centred on the loyalty token, when it exists and fits
## LOYALTY_ICON_ROOM at the art scale. Whether it did.
func _add_icon(icon_ref: String) -> bool:
	if icon_ref.is_empty() or not ResourceLoader.exists(icon_ref):
		return false
	var art: Texture2D = load(icon_ref) as Texture2D
	if art == null:
		return false
	var drawn: Vector2 = art.get_size() * ArtStyle.ART_SCALE
	if drawn.x > LOYALTY_ICON_ROOM or drawn.y > LOYALTY_ICON_ROOM:
		return false
	_icon = UiKit.sprite(art)
	_icon.name = "Icon"
	_icon.size = drawn
	# On the art grid, so the icon's texels stay square.
	_icon.position = ((size - drawn) / 2.0 / ArtStyle.ART_SCALE).floor() * ArtStyle.ART_SCALE
	add_child(_icon)
	return true


## Adds the Aisle run tag, if any, over the token and the icon or initials.
func _add_run_tag() -> void:
	if _run_tag != null:
		add_child(_run_tag)


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
