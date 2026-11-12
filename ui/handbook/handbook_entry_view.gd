class_name HandbookEntryView
extends VBoxContainer
## One handbook entry on the binder's sheet (v1.06, mock-up keywords_guide.html's entry layout;
## dressed in the store's pixel art by the guide polish of 2026-11-11): its head (the mark at 2x,
## the title in the display font, the tab's name on a teal store sign, frames/sign) over a dashed
## receipt rule, the rule in one bold sentence (HandbookText: its keywords, items, coupons and
## families in their own colours), then for an entry with an example the example (HandbookClip:
## the shift's own counter on the entry's real score) and the worked equation printed on a receipt
## slip (frames/receipt_paper; the cards' names in the rule's item violet and coupon teal, every
## payout that differs from its printed price in orange). A family's or the coupon intro's entry
## has no example: its page ends at the rule (the guide feedback of 2026-11-11 removed the notes
## under the slip and the USED BY shelf). All text comes from the entry's data; every number from
## the score.

const TITLE_SIZE := 30
const RULE_SIZE := 18
const RULE_WEIGHT := 700
const EQUATION_SIZE := 18
const SEPARATION := 12
const HEAD_SEPARATION := 14
## The tab's name on its store sign, SIGN_HEIGHT tall, SIGN_PADDING px each side of the words.
const SIGN_PADDING := 10.0
const SIGN_HEIGHT := 28.0
## The receipt's dashed rule under the head: DASH px on, DASH px off.
const DASH := 4.0
const RULE_HEIGHT := 2.0
## The equation's receipt slip: its paper (2 art px margins) and the room round the text.
const SLIP := preload("res://art/frames/receipt_paper.png")
const SLIP_MARGIN := 2
const SLIP_PADDING := Vector4(14, 8, 14, 8)
## A payout that differs from its printed price, and the total, on the slip.
const MARKED_INK := Palette.ORANGE_DARK

var _entry: HandbookEntry
var _clip: HandbookClip
var _equation: RichTextLabel
var _rule: RichTextLabel


## The view of `shown`, `width` wide (its tab's title `group_title`); its clip is `still` under
## reduced motion.
func _init(shown: HandbookEntry, width: float, group_title: String, still: bool) -> void:
	name = "HandbookEntryView"
	_entry = shown
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(width, 0)
	add_theme_constant_override("separation", SEPARATION)
	_add_head(group_title)
	add_child(DashedRule.new(width))
	_rule = HandbookText.label(shown.rule, RULE_SIZE, Palette.INK, width, RULE_WEIGHT)
	_rule.name = "Rule"
	add_child(_rule)
	var example: HandbookExample = HandbookExample.of(shown)
	if example.is_scored():
		_clip = HandbookClip.new(example, width)
		_clip.still = still
		add_child(_clip)
		add_child(_slip(example, width))


func _ready() -> void:
	if _clip != null:
		_clip.play()


func entry() -> HandbookEntry:
	return _entry


## The example's clip (null for an entry without one).
func clip() -> HandbookClip:
	return _clip


## The worked equation's text (empty without an example).
func equation_text() -> String:
	return _equation.get_parsed_text() if _equation != null else ""


## The rule, its terms coloured (HandbookText).
func rule_label() -> RichTextLabel:
	return _rule


func _add_head(group_title: String) -> void:
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", HEAD_SEPARATION)
	var mark: Control = HandbookMark.make(_entry, 2)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(mark)
	var title: Label = UiKit.display_label(_entry.title, TITLE_SIZE, false)
	title.name = "Title"
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	head.add_child(_sign(group_title))
	add_child(head)


## The tab's name in paper pixel words on a teal store sign.
static func _sign(text: String) -> Control:
	var words: Label = UiKit.pixel_label(text, 2, Palette.PAPER)
	var wide: float = HandbookButton.words_width(words) + SIGN_PADDING * 2.0
	var board: Vector2 = Vector2(wide, SIGN_HEIGHT).snappedf(ArtStyle.ART_SCALE)
	var holder: Control = Control.new()
	holder.name = "Group"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = board
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var plate: PanelContainer = UiKit.frame_panel(UiKit.SIGN_FRAME, FramedButton.FRAME_MARGIN)
	plate.size = board
	holder.add_child(plate)
	holder.add_child(words)
	HandbookButton.centre_words(words, Rect2(Vector2.ZERO, board - Vector2(0, 2)))
	return holder


## The worked equation printed on a receipt slip.
func _slip(example: HandbookExample, width: float) -> Control:
	var slip: PanelContainer = UiKit.frame_panel(SLIP, SLIP_MARGIN, SLIP_PADDING)
	slip.name = "Slip"
	slip.custom_minimum_size = Vector2(width, 0)
	_equation = _equation_label(example, width - SLIP_PADDING.x - SLIP_PADDING.z)
	slip.add_child(_equation)
	return slip


func _equation_label(example: HandbookExample, width: float) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.name = "Equation"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_font_override("normal_font", ArtStyle.number_font())
	label.add_theme_font_size_override("normal_font_size", EQUATION_SIZE)
	label.add_theme_color_override("default_color", Palette.INK)
	var text: String = ""
	for part: Array in example.equation_parts():
		var shown: String = str(part[0]).replace("[", "[lb]")
		var paint: HandbookExample.Paint = part[1]
		var ink: Color = equation_ink(paint)
		if ink == Palette.INK:
			text += shown
		else:
			text += "[color=#%s]%s[/color]" % [ink.to_html(false), shown]
	label.text = text
	return label


## The ink of an equation part painted `paint`: a marked amount in orange dark, an item's name in
## the rule's item ink, a coupon's in the coupon ticket's teal (HandbookText; no icon, no face, so
## the slip keeps its one line); else ink.
static func equation_ink(paint: HandbookExample.Paint) -> Color:
	match paint:
		HandbookExample.Paint.MARKED:
			return MARKED_INK
		HandbookExample.Paint.ITEM:
			return HandbookText.ITEM_INK
		HandbookExample.Paint.COUPON:
			return HandbookText.COUPON_FACE
	return Palette.INK


## The receipt's dashed rule, `width` wide, in grey light.
class DashedRule:
	extends Control

	func _init(width: float) -> void:
		name = "DashedRule"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(width, RULE_HEIGHT)

	func _draw() -> void:
		var x: float = 0.0
		while x < size.x:
			draw_rect(Rect2(x, 0, minf(DASH, size.x - x), RULE_HEIGHT), Palette.GREY_LIGHT)
			x += DASH * 2.0
