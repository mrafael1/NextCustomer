class_name ReceiptInk
extends RefCounted
## The receipt's Checkout Rhythm v3.1 inks (approved mock-up checkout_rhythm_v3_1.html): each
## item line's mini in a two-character slot before its name (its giver-badge plate, else its item
## sprite), still once printed; × amounts in dark amber and + amounts in ink; each item's final
## payout in bold; and an armed effect's sub line ("arms ×3 later with prior's tag", worded from
## its card's sticker summary, the × amount amber inside the words, nothing in the amount column).
## Display only: ReceiptView decides which line gets which ink.

## The item mini: ICON_SIZE, centred on the name's first row, in a slot as wide as ICON_SLOT at
## the line's size. A name that would wrap onto more rows past the slot than it does without it
## steps its font down to NAME_MIN_FONT_SIZE, so the receipt never grows taller.
const ICON_NAME := "ItemMini"
const ICON_SIZE := Vector2(14, 14)
const ICON_SLOT := "  "
const NAME_MIN_FONT_SIZE := 11
## The armed effect's line: ARM_WORD, then the card's sticker summary, on one row at
## ReceiptView.FOOTER_FONT_SIZE, stepping down to ARM_MIN_FONT_SIZE to fit (else wrapping). Its
## "×N" (AMBER_PATTERN) is the AMBER_NAME label over a blank of the same width.
const ARM_WORD := "arms "
const ARM_MIN_FONT_SIZE := 10
const ARM_MIN_ROOM := 60.0
const ARM_META := "arm"
const WORDS_META := "words"
const AMBER_NAME := "Amber"
const AMBER_PATTERN := "×\\d+"
## How much the bold payout is emboldened (a FontVariation over the receipt's mono font).
const BOLD_EMBOLDEN := 0.9
## A loyalty perk's line: a pale teal band (TEAL_PALE at PERK_BAND_ALPHA) in place of the gold.
const PERK_BAND_ALPHA := 0.6

static var _bold: FontVariation
static var _amber: RegEx


## Each card's definition, in row order (the receipt's `cards`).
static func cards_of(row: Array[CardInstance]) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for card: CardInstance in row:
		found.append(card.definition)
	return found


## The mini an item line shows for `definition`: its giver-badge plate (GiverBadge.PLATE_FOLDER,
## by its badge mini's file), else its item sprite, else its small mini; null when none loads.
static func item_art(definition: CardDefinition) -> Texture2D:
	if definition == null:
		return null
	var small: String = definition.badge_mini_ref()
	var refs: PackedStringArray = PackedStringArray()
	if not small.is_empty():
		refs.append(GiverBadge.PLATE_FOLDER.path_join(small.get_file()))
	refs.append_array([definition.art_ref, definition.product_card().art_ref, small])
	for ref: String in refs:
		if not ref.is_empty() and ResourceLoader.exists(ref):
			return load(ref) as Texture2D
	return null


## Gives an item line's `label` (its name) the mini slot, holding `texture` (none for null) as an
## "ItemMini" inside it, so the line keeps its height.
static func add_item_mini(label: Label, texture: Texture2D) -> void:
	var slot: float = _width(label, ICON_SLOT, label.get_theme_font_size("font_size"))
	var indent: StyleBoxEmpty = StyleBoxEmpty.new()
	indent.content_margin_left = slot
	label.add_theme_stylebox_override("normal", indent)
	if texture != null:
		var icon: TextureRect = TextureRect.new()
		icon.name = ICON_NAME
		icon.texture = texture
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = ICON_SIZE
		ArtStyle.use_pixel_material(icon)
		label.add_child(icon)
	label.resized.connect(_fit_name.bind(label, slot))
	_fit_name(label, slot)


## The item line's mini, or null (for tests).
static func item_mini(line: HBoxContainer) -> TextureRect:
	return line.get_child(0).get_node_or_null(ICON_NAME) as TextureRect


## A × amount's dark amber.
static func amber(label: Label) -> void:
	label.add_theme_color_override("font_color", Palette.MUSTARD_DARKEST)


## A final payout's bold.
static func embolden(label: Label) -> void:
	label.add_theme_font_override("font", bold_font())


## The receipt's mono font, emboldened.
static func bold_font() -> FontVariation:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ReceiptView.MONO_FONT
		_bold.variation_embolden = BOLD_EMBOLDEN
	return _bold


## Whether `label` prints in bold (bold_font).
static func is_bold(label: Label) -> bool:
	return label.get_theme_font("font") == bold_font()


## The armed effect's words for `step` (an EFFECT_ARMED step), from its card `definition`'s
## sticker summary (its rule's text when the card has none, or no card is known), after ARM_WORD.
static func arm_words(step: ScoreStep, definition: CardDefinition) -> String:
	var summary: String = "" if definition == null else CardText.sticker_summary(definition)
	if summary.is_empty():
		summary = step.text
	return ARM_WORD + summary


## Makes `line` (an indented line of an armed effect's words) the arm line: one row (smaller to
## fit, else wrapped), its words in the "words" meta, its "×N" in amber. Its "arm" meta is set.
## Returns it.
static func arm_line(line: Control) -> Control:
	line.set_meta(ARM_META, true)
	var label: Label = line.get_child(0) as Label
	var words: String = label.text
	label.set_meta(WORDS_META, words)
	label.custom_minimum_size.x = 1.0
	label.add_theme_font_size_override("font_size", ReceiptView.FOOTER_FONT_SIZE)
	var found: RegExMatch = _amber_pattern().search(words)
	if found != null:
		var overlay: Label = Label.new()
		overlay.name = AMBER_NAME
		overlay.text = found.get_string()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_theme_font_override("font", label.get_theme_font("font"))
		amber(overlay)
		label.add_child(overlay)
	label.resized.connect(_fit_arm.bind(label))
	_fit_arm(label)
	return line


## Whether `line` is an armed effect's line (arm_line).
static func is_arm(line: Node) -> bool:
	return line.get_meta(ARM_META, false)


## The arm line's font: FOOTER_FONT_SIZE, or the largest down to ARM_MIN_FONT_SIZE at which its
## words fit on one row; words that don't fit even then wrap at FOOTER_FONT_SIZE, hung as a
## fizzle's reason is. The amber "×N" sits over its blank on the first row (it comes first).
static func _fit_arm(label: Label) -> void:
	var words: String = label.get_meta(WORDS_META, label.text)
	var indent: float = label.get_theme_stylebox("normal").content_margin_left
	var font_size: int = ReceiptView.FOOTER_FONT_SIZE
	var room: float = label.size.x - indent
	while font_size > ARM_MIN_FONT_SIZE and room > 0.0 and _width(label, words, font_size) > room:
		font_size -= 1
	# Narrower than ARM_MIN_ROOM, the line is not laid out yet: it stays on one row.
	var wraps: bool = room >= ARM_MIN_ROOM and _width(label, words, font_size) > room
	if wraps:
		font_size = ReceiptView.FOOTER_FONT_SIZE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wraps else TextServer.AUTOWRAP_OFF
	# One row never widens the receipt: cut at its edge (the font has already stepped down).
	label.clip_text = not wraps
	label.text_overrun_behavior = (
		TextServer.OVERRUN_NO_TRIMMING if wraps else TextServer.OVERRUN_TRIM_ELLIPSIS
	)
	if label.get_theme_font_size("font_size") != font_size:
		label.add_theme_font_size_override("font_size", font_size)
	var overlay: Label = label.get_node_or_null(AMBER_NAME) as Label
	if overlay == null:
		return
	overlay.add_theme_font_size_override("font_size", font_size)
	var at: int = words.find(overlay.text)
	var lead: float = _width(label, words.left(at), font_size)
	var blank: String = " ".repeat(overlay.text.length())
	label.text = words.left(at) + blank + words.substr(at + blank.length())
	overlay.position = Vector2(indent + lead, 0.0)
	overlay.size = Vector2.ZERO


## The item name's font: the line's size, or smaller (to NAME_MIN_FONT_SIZE) while the name
## would wrap onto more rows past the mini's `slot` than across the whole label; the mini centred
## on its first row.
static func _fit_name(label: Label, slot: float) -> void:
	var font_size: int = ReceiptView.LINE_FONT_SIZE
	if label.size.x > slot:
		var font: Font = label.get_theme_font("font")
		var rows: int = _rows(label.text, label.size.x, font, font_size)
		while (
			font_size > NAME_MIN_FONT_SIZE
			and _rows(label.text, label.size.x - slot, font, font_size) > rows
		):
			font_size -= 1
	if label.get_theme_font_size("font_size") != font_size:
		label.add_theme_font_size_override("font_size", font_size)
	var icon: Control = label.get_node_or_null(ICON_NAME) as Control
	if icon != null:
		var row: float = label.get_theme_font("font").get_height(font_size)
		icon.position = Vector2(0.0, roundf((row - ICON_SIZE.y) / 2.0))


## The largest font size from `largest` down to `smallest` at which `text` fits `room` pixels in
## the receipt's mono font (the verdict on the TOTAL line).
static func fit_font_size(text: String, room: float, largest: int, smallest: int) -> int:
	var font_size: int = largest
	while (
		font_size > smallest
		and ReceiptView.text_width(text, ReceiptView.MONO_FONT, font_size) > room
	):
		font_size -= 1
	return font_size


## How many rows `text` takes at `width` (word-wrapped as a receipt label is).
static func _rows(text: String, width: float, font: Font, font_size: int) -> int:
	var paragraph: TextParagraph = TextParagraph.new()
	paragraph.add_string(text, font, font_size)
	paragraph.width = width
	paragraph.break_flags = (
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	)
	return paragraph.get_line_count()


static func _width(label: Label, text: String, font_size: int) -> float:
	return ReceiptView.text_width(text, label.get_theme_font("font"), font_size)


static func _amber_pattern() -> RegEx:
	if _amber == null:
		_amber = RegEx.create_from_string(AMBER_PATTERN)
	return _amber
