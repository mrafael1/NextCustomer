class_name TipTarget
extends TextureRect
## Something a hover tip explains when the pointer rests on it (#105; the hover tips revamp of
## 2026-11-13, GlyphTips and TipCard): a family glyph (FamilyGlyph), a ticket's colour
## (PriceSticker.ColourSpot), a keyword (KeywordChip), a price window, a monitor line, or any
## control a cover_control() lies over (a loyalty stamp, a medal, the week glass, a menu key). Its
## tip is a TipSpec (tip_spec()): an explicit `spec`, else its plain `tip_text` read by
## TipSpec.from_text, with the tip_* fields (kind, title, tag, icon, fine print, click action,
## band, side) on top; `tip_more` is its live line. The tip opens below `tip_anchor` (a rail or
## shelf ticket) when `tip_below`, else on `tip_side`, else on the side its screen zone says
## (GlyphTips). It takes no clicks: the thing under it keeps its hover, its drag and its clicks.

## Every target is in this group, for GlyphTips.
const GROUP := &"tip_target"
## A cover's node name (cover_control()).
const COVER_NAME := &"Tip"
## No side asked for: GlyphTips picks one by the target's place on the screen.
const SIDE_AUTO := -1
const KIND_FROM_TEXT := -1
const COUPON_TITLE := "COUPON"

## Its tooltip's text (plain words; its first part the title, TipSpec.from_text).
var tip_text: String = ""
## What the tip adds while it shows on the belt (tickets v5: a family's items there, or what a
## written family's rule counts; PlanningEffects sets it when the tip opens): its live line, or "".
var tip_more: String = ""
## The tooltip opens below `tip_anchor` (a rail or shelf ticket), else above the target.
var tip_below: bool = false
var tip_anchor: Control
## Its tip still shows while GlyphTips is `blocked` (the count-up): a monitor count row's bag glyph
## (v1.11), which only shows during the count.
var shows_while_blocked: bool = false
## A control that draws part of the target over later ones (a price label's layer over its row,
## PriceLabelLayer): what covers the target is then what covers that control (drawn_from). Null:
## the target draws itself.
var tip_cover: Control
## The whole tip, when set (cover_control()'s): tip_text and the tip_* fields are then not read.
var spec: TipSpec
## The tip's parts over the ones tip_text gives (a TipSpec.Kind, or KIND_FROM_TEXT; "": the text's).
var tip_kind: int = KIND_FROM_TEXT
var tip_title: String = ""
var tip_tag: String = ""
var tip_icon: Texture2D
var tip_cond: String = ""
var tip_click: String = ""
var tip_live_kind: TipSpec.Live = TipSpec.Live.INFO
## A family tip's band and title colours (clear: its kind's).
var tip_band: Color = Color(0, 0, 0, 0)
var tip_band_ink: Color = Color(0, 0, 0, 0)
## The side its tip opens on (a TipCard.Opens), or SIDE_AUTO.
var tip_side: int = SIDE_AUTO
## The boxes its tip shows beside it (TipWords keys); empty: the ones its rule names.
var tip_subs: PackedStringArray = PackedStringArray()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(GROUP)


## A target lying over the whole of `control` (an IGNORE overlay that follows its size) whose tip is
## `tip`; `control`'s own native tooltip goes. A second call updates the same cover.
static func cover_control(control: Control, tip: TipSpec) -> TipTarget:
	var target: TipTarget = control.get_node_or_null(NodePath(COVER_NAME)) as TipTarget
	if target == null:
		target = TipTarget.new()
		target.name = COVER_NAME
		target.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Internal: the control's own children (get_child, get_child_count) stay as they were.
		control.add_child(target, false, Node.INTERNAL_MODE_BACK)
	target.spec = tip
	target.tip_text = tip.source if not tip.source.is_empty() else tip.plain()
	control.tooltip_text = ""
	return target


## A cover over `control` (cover_control) whose tip is read from `text` (TipSpec.from_text; its
## title `title` when not empty), of `kind`, tagged `tag`, with a footer CLICK `click`. An empty
## text and title remove the cover.
static func cover_text(
	control: Control,
	text: String,
	kind: TipSpec.Kind = TipSpec.Kind.ITEM,
	tag: String = "",
	click: String = "",
	title: String = ""
) -> TipTarget:
	if text.is_empty() and title.is_empty():
		var old: Node = control.get_node_or_null(NodePath(COVER_NAME))
		if old != null:
			control.remove_child(old)
			old.queue_free()
		control.tooltip_text = ""
		return null
	var made: TipSpec = TipSpec.from_text(text)
	if not title.is_empty():
		made.title = title
		made.body = TipSpec.sentences(text) if not text.is_empty() else ""
	made.body = TipMarkup.auto(made.body)
	made.kind = kind
	made.tag = tag
	made.click = click
	made.source = text if not text.is_empty() else title
	return cover_control(control, made)


## The tip words of `control`'s cover (cover_control), or its native tooltip: for checks.
static func tip_of(control: Control) -> String:
	var target: TipTarget = control.get_node_or_null(NodePath(COVER_NAME)) as TipTarget
	return target.full_tip() if target != null else control.tooltip_text


## The tip spec of `control`'s cover, or null.
static func spec_of(control: Control) -> TipSpec:
	var target: TipTarget = control.get_node_or_null(NodePath(COVER_NAME)) as TipTarget
	return target.tip_spec() if target != null else null


## Dresses its tip as `style`'s family: the FAMILY kind in the family's own colours, its glyph and
## the FAMILY tag.
func dress_family(style: FamilyStyle) -> void:
	if style == null:
		return
	tip_kind = TipSpec.Kind.FAMILY
	tip_band = style.face if style.has_ticket_colours() else Palette.CREAM_SHADE
	tip_band_ink = Palette.PAPER if style.paper_text else Palette.INK
	tip_icon = style.glyph
	tip_tag = TipSpec.FAMILY_TAG
	tip_subs = PackedStringArray(["FAMILY"])


## Dresses its tip as `definition`'s ticket colour (PriceSticker.ColourSpot, the scanner bay's
## FamilyChip): titled with the colour's family (both of a split ticket's; COUPON for the plain
## coupon ticket), tagged with the item, its rule the card's own (CardText.monitor_text).
func dress_colour(definition: CardDefinition) -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var ids: PackedStringArray = palette.ticket_families(definition)
	if ids.is_empty():
		tip_kind = TipSpec.Kind.COUPON
		tip_title = COUPON_TITLE
		tip_icon = ArtStyle.coupon_icon(definition)
	else:
		dress_family(palette.style(ids[0]))
		tip_title = palette.display_name(ids[0])
		if ids.size() > 1:
			tip_title = "%s + %s" % [tip_title, palette.display_name(ids[1])]
	tip_tag = definition.display_name
	tip_subs = PackedStringArray()
	# The card's own words; a plain item's (none) says what its colour means.
	tip_text = CardText.monitor_text(definition)
	if tip_text.is_empty():
		tip_text = palette.colour_tip(definition)


## Its tooltip showed (`shown`) or went (GlyphTips calls it once per change): a keyword chip
## lights while its tip shows (KeywordChip). Nothing by default.
func tip_shown(_shown: bool) -> void:
	pass


## The tooltip's whole text: tip_text, then tip_more after a " · ".
func full_tip() -> String:
	return tip_text if tip_more.is_empty() else "%s · %s" % [tip_text, tip_more]


## The tip it shows now (see the class comment). Its words are marked up (TipMarkup.auto).
func tip_spec() -> TipSpec:
	var made: TipSpec
	if spec != null:
		made = spec.copy()
	else:
		made = TipSpec.from_text(tip_text)
		if not tip_title.is_empty():
			made.title = tip_title
			made.body = TipSpec.sentences(tip_text) if tip_text != tip_title else ""
		if tip_kind != KIND_FROM_TEXT:
			made.kind = tip_kind as TipSpec.Kind
		if not tip_tag.is_empty():
			made.tag = tip_tag
		if tip_icon != null:
			made.icon = tip_icon
		if not tip_cond.is_empty():
			made.cond = tip_cond
		if not tip_click.is_empty():
			made.click = tip_click
		made.band = tip_band
		made.band_ink = tip_band_ink
		made.live_kind = tip_live_kind
		made.subs = tip_subs.duplicate()
	if made.live.is_empty() and not tip_more.is_empty():
		made.live = TipSpec.sentences(tip_more)
	made.body = TipMarkup.auto(made.body)
	made.cond = TipMarkup.auto(made.cond)
	made.live = TipMarkup.auto(made.live)
	made.source = full_tip()
	return made


## Where the pointer finds the target (global): its rect; a price window adds its stuck label's
## (PriceWindow).
func hover_rect() -> Rect2:
	return get_global_rect()


## The control whose place in the tree says what covers the target: `tip_cover` while it is in
## the tree, else the target.
func drawn_from() -> Control:
	if is_instance_valid(tip_cover) and tip_cover.is_inside_tree():
		return tip_cover
	return self


## Whether it has a tip to show (some words, or a spec).
func has_tip() -> bool:
	return spec != null or not tip_text.is_empty() or not tip_title.is_empty()


## Whether the target shows on screen now (GlyphTips only shows a tooltip for one that does).
func is_shown() -> bool:
	return is_visible_in_tree() and modulate.a > 0.0
