class_name StartBoardKit
extends RefCounted
## Small drawing and layout helpers for the opening-time boards, all on the 2 px art grid.

const STAPLES_GLYPH := preload("res://art/icons/aisle_staples.png")
const CLOCK_ICON := preload("res://art/icons/clock.png")
const PADLOCK := preload("res://art/icons/padlock.png")
const CHECK := preload("res://art/icons/mark_check.png")


static func panel(parent: Control, rect: Rect2, face: Color, edge: Color = Palette.INK) -> Panel:
	var node: Panel = Panel.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = face
	style.border_color = edge
	style.set_border_width_all(2 if minf(rect.size.x, rect.size.y) >= 4 else 0)
	style.shadow_color = Color(Palette.INK, 0.4)
	style.shadow_size = 4 if rect.size.y > 70 else 0
	style.shadow_offset = Vector2(2, 2)
	node.add_theme_stylebox_override("panel", style)
	parent.add_child(node)
	return node


static func words(
	parent: Control, text: String, rect: Rect2, color: Color = Palette.INK, pixels: int = 2
) -> Label:
	var label: Label = UiKit.pixel_label(text.replace(" ", "  "), pixels, color)
	parent.add_child(label)
	UiKit.place_pixel_label(label, rect, true)
	return label


static func body(
	parent: Control, text: String, rect: Rect2, color: Color = Palette.INK, font_size: int = 14
) -> Label:
	var label: Label = UiKit.body_label(text, font_size, color)
	label.clip_text = true
	label.position = rect.position
	label.size = rect.size
	parent.add_child(label)
	return label


static func number(
	parent: Control, text: String, rect: Rect2, color: Color = Palette.INK, font_size: int = 22
) -> Label:
	var label: Label = UiKit.number_label(text, font_size, false)
	label.add_theme_font_override("font", ArtStyle.pixel_number_font())
	label.add_theme_color_override("font_color", color)
	label.position = rect.position
	label.size = rect.size
	parent.add_child(label)
	return label


static func key(
	parent: Control, text: String, rect: Rect2, action: Callable, primary: bool = false
) -> Button:
	var button: Button = UiKit.button(parent, "", action, 18)
	button.position = rect.position
	button.size = rect.size
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Palette.TOMATO if primary else Palette.TEAL
		if state == "hover":
			style.bg_color = Palette.TOMATO_LIGHT if primary else Palette.TEAL_LIGHT
		elif state == "pressed":
			style.bg_color = Palette.TOMATO_DARK if primary else Palette.TEAL_SHADE
		elif state == "disabled":
			style.bg_color = Palette.STEEL_PALE
		style.border_color = Palette.INK
		style.set_border_width_all(2)
		style.border_width_bottom = 6
		button.add_theme_stylebox_override(state, style)
	var face: Rect2 = Rect2(8, 2, rect.size.x - 16, rect.size.y - 8)
	var label: Label = words(button, text, face, Palette.PAPER, 4 if primary else 2)
	centre(label, face)
	return button


## The caption label a key() made (its first child), to change its text or colour.
static func key_caption(button: Button) -> Label:
	return button.get_child(0) as Label


static func item(parent: Control, card: CardDefinition, at: Vector2, extent: float) -> Control:
	var host: Control = Control.new()
	host.position = at
	host.size = Vector2.ONE * extent
	host.mouse_filter = Control.MOUSE_FILTER_PASS
	host.set_meta("card", card)
	parent.add_child(host)
	var art: TextureRect = ItemView.item_art(card)
	art.scale = Vector2.ONE * extent / ItemView.SPRITE_SIZE.x
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(art)
	return host


## Pixel words with single spaces (words doubles them), for tight pills and keys; `centred`
## puts them in the middle of `rect` on the 2 px grid.
static func tag(
	parent: Control,
	text: String,
	rect: Rect2,
	color: Color = Palette.INK,
	pixels: int = 2,
	centred: bool = false
) -> Label:
	var label: Label = UiKit.pixel_label(text, pixels, color)
	parent.add_child(label)
	UiKit.place_pixel_label(label, rect, true)
	if centred:
		centre(label, rect)
	return label


## Pixel words' width on screen in canvas px (from the font, so it holds out of the tree).
static func text_width(text: String, pixels: int = 2) -> float:
	var font: Font = ArtStyle.pixel_display_font()
	return (
		ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.PIXEL_TEXT_SIZE).x)
		* pixels
	)


## Centres pixel words across `rect` (in their parent's px) on the 2 px grid, left aligned so the
## label's own width never shifts them.
static func centre(label: Label, rect: Rect2) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var spare: float = rect.size.x - text_width(label.text, roundi(label.scale.x))
	label.position.x = rect.position.x + 2.0 * floorf(maxf(spare, 0.0) / 4.0)


## A pixel-art icon at `factor` times its art size (2: the 2 px grid).
static func icon(
	parent: Control, texture: Texture2D, at: Vector2, factor: float = 2
) -> TextureRect:
	var sprite: TextureRect = UiKit.sprite(texture)
	sprite.position = at
	sprite.size = texture.get_size() * factor
	parent.add_child(sprite)
	return sprite


## A glyph for a stock source: the aisle's, or the Staples shelf's (aisle null).
static func glyph(aisle: AisleDefinition) -> Texture2D:
	return STAPLES_GLYPH if aisle == null else load(ArtStyle.glyph_path(aisle)) as Texture2D


## A cream keycap (ENTER, ESC, 1, P) at `at`, its height `height`. Returns it.
static func keycap(parent: Control, text: String, at: Vector2, height: float = 24) -> Panel:
	var width: float = maxf(height, text_width(text) + 12)
	var cap: Panel = panel(parent, Rect2(at, Vector2(width, height)), Palette.CREAM)
	var style: StyleBoxFlat = cap.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_width_bottom = 4
	tag(cap, text, Rect2(0, 0, width, height - 2), Palette.INK, 2, true)
	return cap


## A footer line of keycaps and their meaning: `parts` alternates key captions (a key may hold
## several captions split by "|", drawn side by side) and body text. Returns its row.
static func hints(parent: Control, parts: PackedStringArray, at: Vector2, color: Color) -> Control:
	var row: Control = Control.new()
	row.name = "Hints"
	row.position = at
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var x: float = 0
	for index: int in parts.size():
		if index % 2 == 0:
			for caption: String in parts[index].split("|"):
				x += keycap(row, caption, Vector2(x, 0)).size.x + 4
			x += 2
		else:
			var label: Label = UiKit.body_label(parts[index], 14, color)
			label.add_theme_font_override("font", ArtStyle.bold_font(600))
			label.position = Vector2(x, 1)
			row.add_child(label)
			# Measured from the font: a label's own size is stale until its theme settles.
			var font: Font = ArtStyle.bold_font(600)
			var width: float = ceilf(
				font.get_string_size(parts[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			)
			label.size = Vector2(width, 24)
			x += width + 10
	row.size = Vector2(x - 10, 26)
	return row


## A key's caption on two lines: the pixel caption above a body subtitle.
static func subtitle(button: Button, text: String, color: Color = Palette.PAPER) -> Label:
	var caption: Label = key_caption(button)
	var top: float = button.size.y - 6
	var room: Rect2 = Rect2(8, 4, button.size.x - 16, top - 24)
	UiKit.place_pixel_label(caption, room, true)
	centre(caption, room)
	var line: Label = body(button, text, Rect2(8, top - 21, button.size.x - 16, 20), color, 14)
	line.add_theme_font_override("font", ArtStyle.bold_font(700))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return line


## Restyles `button` (a key) with one face and edge for every state.
static func restyle(button: Button, face: Color, edge: Color, width: int = 2) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = (button.get_theme_stylebox(state) as StyleBoxFlat).duplicate()
		style.bg_color = face if state != "hover" else face.lightened(0.08)
		style.border_color = edge
		style.set_border_width_all(width)
		style.border_width_bottom = maxi(width, 4)
		button.add_theme_stylebox_override(state, style)


static func clear(parent: Control) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
