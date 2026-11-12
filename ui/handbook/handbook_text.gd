class_name HandbookText
extends RefCounted
## An entry's text on the handbook's sheet (the guide feedback of 2026-11-11: "use more colors for
## a quicker and easier identification"), its HandbookMarkup terms drawn in their own colours, all
## the game's own:
## - a keyword in its chip's colour: its family's shade (KeywordChip.KEYWORD_FAMILIES: CHAIN the
##   Produce green, MORNING the Breakfast mustard, BATCH the Bakery brown, PAIR the Dairy teal),
##   a shade too light to read on the paper taken one palette step darker (DARKER_INK), WASTED
##   in its wasted chip's tomato (KeywordChip.WASTED_FACE);
## - an item after its mini (its giver badge's) in ITEM_INK;
## - a coupon after its mini icon, in paper on the coupon ticket's teal (PriceSticker's plain
##   coupon face), like a little ticket;
## - a family after its glyph, on its ticket's face in its ticket's text colour; the coupon mark
##   (COUPON_FAMILY) reads as a coupon; a family with no ticket colours shows in plain ink.
## A term on a face is padded inside it by FACE_PAD, so the face sits evenly round its words and
## the next word's punctuation stays outside it. Icons are scaled by whole steps to about
## ICON_HEIGHT, so an item's mini and a family's glyph stand as tall in one sentence.
## Terms are in the heavier TERM_WEIGHT; an UNKNOWN token shows plainly. The label wraps, never
## scrolls, sizes to its text and lets the mouse through (the page's wheel still scrolls it).

## The item's ink: art/src/palette.txt's violet dark, a hue no keyword or family uses.
const ITEM_INK := Palette.VIOLET_DARK
const COUPON_FACE := Palette.TEAL_SHADE
const COUPON_INK := Palette.PAPER
## The family the coupon mark is (as cards write tags).
const COUPON_FAMILY := MonitorItemColumn.COUPON_FAMILY
## A keyword shade too light for body text on the paper, and the palette's next darker step.
const DARKER_INK: Dictionary[Color, Color] = {
	Palette.MUSTARD_DARK: Palette.MUSTARD_DARKEST,
	Palette.BROWN: Palette.BROWN_DARK,
}
## The screen px an inline icon is scaled towards (by a whole number, hard pixels).
const ICON_HEIGHT := 18.0
## The room each side of an inline icon.
const ICON_GAP := 4.0
const TERM_WEIGHT := 800
## A faced term's room above and below its words (its sides are FACE_PAD).
const HIGHLIGHT_PADDING := Vector2i(0, 1)
## The narrow no-break space each side of a faced term, inside its face.
const FACE_PAD := " "
## A term's spaces never break: a name ("Sugar cubes") stays on one line.
const NO_BREAK := " "

## The scaled icons by art path, made once a session (a handful of small textures; kept so a
## page turn never rescales them).
static var _icons: Dictionary[String, Texture2D] = {}


## A wrapping label `width` wide of `text` (HandbookMarkup) at `font_size`, its plain words in
## `ink` and the body font at `weight`.
static func label(
	text: String, font_size: int, ink: Color, width: float, weight: int
) -> RichTextLabel:
	var shown: RichTextLabel = RichTextLabel.new()
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shown.bbcode_enabled = false
	shown.fit_content = true
	shown.scroll_active = false
	shown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shown.custom_minimum_size = Vector2(width, 0)
	shown.add_theme_font_override("normal_font", ArtStyle.bold_font(weight))
	shown.add_theme_font_override("bold_font", ArtStyle.bold_font(TERM_WEIGHT))
	shown.add_theme_font_size_override("normal_font_size", font_size)
	shown.add_theme_font_size_override("bold_font_size", font_size)
	shown.add_theme_color_override("default_color", ink)
	shown.add_theme_constant_override("text_highlight_h_padding", HIGHLIGHT_PADDING.x)
	shown.add_theme_constant_override("text_highlight_v_padding", HIGHLIGHT_PADDING.y)
	write(shown, text)
	return shown


## Writes `text`'s runs into `shown` (cleared first).
static func write(shown: RichTextLabel, text: String) -> void:
	shown.clear()
	for run: HandbookMarkup.Run in HandbookMarkup.runs(text):
		if run.kind == HandbookMarkup.Kind.TEXT or run.kind == HandbookMarkup.Kind.UNKNOWN:
			shown.add_text(run.text)
			continue
		var icon: Texture2D = icon_for(run)
		if icon != null:
			# Padded ICON_GAP px each side, so no space joins it to its words.
			var room: Vector2 = icon.get_size() + Vector2(ICON_GAP * 2.0, 0)
			shown.add_image(
				icon,
				int(room.x),
				int(room.y),
				Color.WHITE,
				INLINE_ALIGNMENT_CENTER,
				Rect2(),
				null,
				true
			)
		var face: Color = face_for(run)
		if face.a > 0.0:
			shown.push_bgcolor(face)
		shown.push_color(ink_for(run))
		shown.push_bold()
		var words: String = run.text.replace(" ", NO_BREAK)
		shown.add_text(FACE_PAD + words + FACE_PAD if face.a > 0.0 else words)
		shown.pop()
		shown.pop()
		if face.a > 0.0:
			shown.pop()


## The ink a term's words show in.
static func ink_for(run: HandbookMarkup.Run) -> Color:
	match run.kind:
		HandbookMarkup.Kind.KEYWORD:
			if run.id == CardText.WASTED_WORD:
				return KeywordChip.WASTED_FACE
			var family: FamilyStyle = FamilyPalette.shared().style(
				KeywordChip.KEYWORD_FAMILIES.get(run.id, "")
			)
			if family == null:
				return Palette.INK
			for light: Color in DARKER_INK:
				if light.is_equal_approx(family.shade):
					return DARKER_INK[light]
			return family.shade
		HandbookMarkup.Kind.ITEM:
			return ITEM_INK
		HandbookMarkup.Kind.COUPON:
			return COUPON_INK
		HandbookMarkup.Kind.FAMILY:
			if run.id == COUPON_FAMILY:
				return COUPON_INK
			var family: FamilyStyle = FamilyPalette.shared().style(run.id)
			if family == null or not family.has_ticket_colours():
				return Palette.INK
			return FamilyPalette.shared().text_color(PackedStringArray([run.id]))
	return Palette.INK


## The colour behind a term's words: a coupon's (and the coupon mark's) teal, a family's ticket
## face; else clear.
static func face_for(run: HandbookMarkup.Run) -> Color:
	if run.kind == HandbookMarkup.Kind.COUPON:
		return COUPON_FACE
	if run.kind == HandbookMarkup.Kind.FAMILY:
		if run.id == COUPON_FAMILY:
			return COUPON_FACE
		var family: FamilyStyle = FamilyPalette.shared().style(run.id)
		if family != null and family.has_ticket_colours():
			return family.face
	return Color.TRANSPARENT


## The small icon before a term (an item's mini, a coupon's mini icon, a family's glyph) scaled
## towards ICON_HEIGHT, or null (a keyword; a card with no mini).
static func icon_for(run: HandbookMarkup.Run) -> Texture2D:
	var path: String = ""
	match run.kind:
		HandbookMarkup.Kind.ITEM, HandbookMarkup.Kind.COUPON:
			var card: CardDefinition = FamilyPalette.data_card(run.id)
			if card != null:
				path = card.badge_mini_ref()
		HandbookMarkup.Kind.FAMILY:
			var family: FamilyStyle = FamilyPalette.shared().style(run.id)
			if family != null and family.glyph != null:
				path = family.glyph.resource_path
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if not _icons.has(path):
		_icons[path] = _scaled(load(path) as Texture2D)
	return _icons[path]


## `texture` scaled by the whole number that brings it nearest ICON_HEIGHT, with hard pixels (the
## art stays crisp inline).
static func _scaled(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null:
		return texture
	image = image.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	var scale: int = maxi(1, roundi(ICON_HEIGHT / float(image.get_height())))
	image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)
