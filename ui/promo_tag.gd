class_name PromoTag
extends TextureRect
## The Picky regular's promo tag (#182 grade 5; the user's play tests of 2026-11-24: "promo tag on
## item -25%", then "the tag should be on the item, it just flies over it in the air"): on a promo
## day each item the score cuts wears a red supermarket promo label (art/icons/promo_tag, pixel art
## at SCALE) printed with the day's cut in paper ("-15%" to "-30%", GradeRules.promo_text: the
## day's drawn cut, never typed here) in the number font.
##
## It is stuck on the item itself: a child of the item's sprite, so it rides every lift, punch,
## shake and scan of the count-up with the art, and greys with it. The item places it as it is
## stuck on (ItemView.PROMO_OVERHANG): on a belt item on its art's visible lower-left corner,
## gripping the art's foot and hanging over the mat (under the sticker stacks, its own and its
## neighbours', clear of the effect mark on the art's top-right corner, the paid chip above it and
## the grade marks under it, GradeTags.BELT_AT); in a basket over its art's visible right side,
## its foot on the basket's rim, under the grade marks' row.
##
## Which items wear it is the score's own answer (GradeRules.promo_slot: the FamilyPayCutRule's
## test on the score's tags, so an item the Price gun labels into today's family wears it too); a
## basket item, outside any score, by its printed families and its Price gun label
## (GradeRules.on_promo). Its hover tip is the day's: "Promo day" over "Dairy price reduced by 25%
## today" (PickySign's). It stamps on as the shift opens (GradeMoves). It only displays: the cut is
## the score's; it takes no clicks, so the item still drags.

const NODE_NAME := "PromoTag"
const ART := preload("res://art/icons/promo_tag.png")
## The small promo tag (14x14 at 2x): the monitor's promo line icon (MonitorView.source_icon).
const MINI := preload("res://art/icons/promo_tag_mini.png")
const SCALE := 2.0
## The cut's room on the tag (art px from its left: right of the hole; and from its right: the
## outline and its shade), its font size and ink.
const TEXT_LEFT := 7.0
const TEXT_RIGHT := 2.0
const FONT_SIZE := 14
const INK := Palette.PAPER

## The cut it shows ("-25%").
var text: String = ""
var _label: Label


## Puts the promo tag printed `cut` ("-25%") on `view`'s item, or removes it when `cut` is "". A
## tag already there with the same cut stays (only placed again), so a refresh never cuts its
## stamp short. Returns the tag, or null.
static func mark(view: CardView, run: RunState, cut: String) -> PromoTag:
	var item: ItemView = view as ItemView
	var old: PromoTag = of(view)
	if old != null and (cut.is_empty() or old.text != cut):
		old.get_parent().remove_child(old)
		old.queue_free()
		old = null
	if cut.is_empty() or item == null:
		return null
	var tag: PromoTag = old if old != null else PromoTag.new(cut)
	if old == null:
		item.sprite().add_child(tag)  # The item places it.
	var event: InspectionDefinition = GradeRules.picky_event(run)
	if event != null:
		TipTarget.cover_text(
			tag, PickySign.TODAY % event.notice_text, TipSpec.Kind.WORD, "", "", event.display_name
		)
	return tag


## Tags the hand's basket items (`hand`) of `run` that are on today's promo, and the belt's items
## (`belt`) the score `result` cuts; with no `result` (the belt's score is not known yet) the belt
## keeps its tags until mark_belt.
static func mark_items(
	run: RunState, belt: Array[CardView], hand: Array[Control], result: ScoreResult = null
) -> void:
	if result != null:
		mark_belt(run, belt, result)
	var cut: String = GradeRules.promo_text(run) if run != null else ""
	for item: Control in hand:
		var view: CardView = item as CardView
		if view != null:
			var on: bool = not cut.is_empty() and GradeRules.on_promo(run, view.card)
			mark(view, run, cut if on else "")


## Tags the belt's items (`belt`, in slot order) that the score `result` cuts.
static func mark_belt(run: RunState, belt: Array[CardView], result: ScoreResult) -> void:
	var cut: String = GradeRules.promo_text(run) if run != null else ""
	for slot: int in range(belt.size()):
		var view: CardView = belt[slot]
		var on: bool = not cut.is_empty() and GradeRules.promo_slot(run, result, slot, view.card)
		mark(view, run, cut if on else "")


## `view`'s promo tag (on its item's sprite), or null.
static func of(view: CardView) -> PromoTag:
	var item: ItemView = view as ItemView
	if item == null:
		return null
	return item.sprite().get_node_or_null(NodePath(NODE_NAME)) as PromoTag


func _init(cut: String) -> void:
	name = NODE_NAME
	text = cut
	texture = ART
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	size = ART.get_size() * SCALE
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(self)
	_label = UiKit.number_label(cut, FONT_SIZE, false)
	_label.name = "Cut"
	_label.add_theme_color_override("font_color", INK)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = Vector2(TEXT_LEFT * SCALE, 0)
	_label.size = Vector2(size.x - (TEXT_LEFT + TEXT_RIGHT) * SCALE, size.y)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## The cut's label (tests read its words and room).
func label() -> Label:
	return _label
