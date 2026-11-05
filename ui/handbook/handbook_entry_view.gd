class_name HandbookEntryView
extends VBoxContainer
## One handbook entry on the binder's right page (v1.06, mock-up keywords_guide.html's entry
## layout): its head (the mark at 2x, the title in the display font, the tab's name), the rule in
## one bold sentence, the example (HandbookClip on the entry's real score, then the worked
## equation with every payout that differs from its printed price in orange, and the note), the
## longer details, and the cards that use it (their sprites, each with its name as a tooltip). All
## text comes from the entry's data; every number from the score.

const TITLE_SIZE := 30
const RULE_SIZE := 18
const RULE_WEIGHT := 700
const EQUATION_SIZE := 18
const BODY_SIZE := 15
const SEPARATION := 12
const HEAD_SEPARATION := 14
const USED_BY := "USED BY"
const CARD_SIZE := Vector2(48, 48)
const CAPTION_GAP := 10.0

var _entry: HandbookEntry
var _clip: HandbookClip
var _equation: RichTextLabel
var _rule: Label


## The view of `shown`, `width` wide (its tab's title `group_title`); its clip is `still` under
## reduced motion.
func _init(shown: HandbookEntry, width: float, group_title: String, still: bool) -> void:
	name = "HandbookEntryView"
	_entry = shown
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(width, 0)
	add_theme_constant_override("separation", SEPARATION)
	_add_head(group_title)
	_rule = _wrapped(shown.rule, RULE_SIZE, Palette.INK, width)
	_rule.name = "Rule"
	_rule.add_theme_font_override("font", ArtStyle.bold_font(RULE_WEIGHT))
	add_child(_rule)
	var example: HandbookExample = HandbookExample.of(shown)
	if example.is_scored():
		_clip = HandbookClip.new(example, width)
		_clip.still = still
		add_child(_clip)
		_equation = _equation_label(example, width)
		add_child(_equation)
	if not shown.example_note.is_empty():
		add_child(_wrapped(shown.example_note, BODY_SIZE, Palette.INK_LIGHT, width))
	if not shown.details.is_empty():
		add_child(_wrapped(shown.details, BODY_SIZE, Palette.INK, width))
	_add_cards()


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


func rule_label() -> Label:
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
	var group: Label = UiKit.pixel_label(group_title, 2, Palette.TEAL_SHADE)
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = UiKit.pixel_text_size(group)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(group)
	head.add_child(holder)
	add_child(head)


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
		if bool(part[1]):
			text += "[color=#%s]%s[/color]" % [Palette.ORANGE_DARK.to_html(false), shown]
		else:
			text += shown
	label.text = text
	return label


func _add_cards() -> void:
	var cards: Array[CardDefinition] = []
	for card_id: String in _entry.cards:
		var card: CardDefinition = FamilyPalette.data_card(card_id)
		if card != null:
			cards.append(card)
	if cards.is_empty():
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "UsedBy"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var caption: Label = UiKit.pixel_label(USED_BY, 2, Palette.TEAL_SHADE)
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The caption's drawn words (its font at PIXEL_TEXT_SIZE, scaled), CAPTION_GAP before the cards.
	var words: Vector2 = ArtStyle.pixel_display_font().get_string_size(
		USED_BY, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.PIXEL_TEXT_SIZE
	)
	holder.custom_minimum_size = Vector2(
		ceilf(words.x * caption.scale.x) + CAPTION_GAP, UiKit.pixel_text_size(caption).y
	)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(caption)
	row.add_child(holder)
	for card: CardDefinition in cards:
		var sprite: TextureRect = UiKit.sprite(ArtStyle.item_sprite(card))
		sprite.custom_minimum_size = CARD_SIZE
		sprite.mouse_filter = Control.MOUSE_FILTER_PASS
		sprite.tooltip_text = card.display_name
		row.add_child(sprite)
	add_child(row)


## A body-font label `width` wide that wraps.
static func _wrapped(text: String, font_size: int, color: Color, width: float) -> Label:
	var label: Label = UiKit.body_label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label
