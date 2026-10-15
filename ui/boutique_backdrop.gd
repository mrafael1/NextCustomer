class_name BoutiqueBackdrop
extends RefCounted
## The shift screen's boutique backdrop (#55, from style frame v2; full build plan section 6.1).
## Decor only, with no game information and no clicks except the wall's.
##
## Two parts, so nothing drifts when the window isn't 1280x720: screen_parts() fills the window
## behind the centred stage (the velvet wall, which takes the background clicks, the marble
## counter from the stage's counter line, its brass edge, the picture rail and the kickplate at
## the window's bottom); the stage puts its own decor in the layers v2 has it in, each light over
## what it lights and under the cards, the receipt and the texts: the valance (valance()) and the
## light canvases (light_canvas() and pool(), drawn with draw_spots() and draw_pool()). plaque()
## is the top bar's FINE GROCERIES plaque.

## The window's middle is the stage's (the stage is centred), so the bands are placed from it.
const STAGE_MIDDLE := ShiftStage.SIZE.y / 2.0
## The brass picture rail across the wall, and the counter's brass edge on the counter line
## (stage rows).
const PICTURE_RAIL := Rect2(0, 62, 1280, 4)
const COUNTER_EDGE := Rect2(0, ShiftStage.COUNTER_TOP, 1280, 6)
## The kickplate along the window's bottom.
const KICKPLATE_HEIGHT := 12.0
const KICKPLATE_COLOR := Palette.VELVET_DARK
## The velvet valance hangs on its brass rod over the picture rail and the belt's top rail
## (stage coordinates).
const VALANCE_RECT := Rect2(16, 54, ShiftStage.BELT_RECT.size.x, 34)
## The ceiling spotlights: each a cone of warm light from the stage's top, SPOT_TOP half-wide,
## down to the counter line (SPOT_BOTTOM half-wide), in two hard bands. SPOT_XS are style frame
## v2's, in the gaps between the top bar's parts; spot_xs() moves a cone a part would cover.
const SPOT_XS: Array[float] = [289.0, 516.0, 811.0]
const SPOT_TOP := 6.0
const SPOT_BOTTOM := 100.0
const SPOT_BANDS: Array[float] = [1.0, 0.55]
const SPOT_ALPHAS: Array[float] = [0.10, 0.18]
## A moved cone stays at least this far right of the one before it, so their feet never overlap.
const SPOT_SPACING := 2.0 * SPOT_BOTTOM
## Pools of light (centre, radii; stage coordinates), each in three hard bands, outermost first.
const BELT_LIGHT := Rect2(464, 195, 440, 127)
const REGISTER_LIGHT := Rect2(1104, 150, 180, 120)
const TRAY_LIGHT := Rect2(
	470, ShiftStage.TRAY_RECT.position.y + ShiftStage.TRAY_RECT.size.y / 2.0, 450, 92
)
const PURSE_LIGHT := Rect2(808, 650, 120, 56)
const LIGHTS: Array[Rect2] = [BELT_LIGHT, REGISTER_LIGHT, TRAY_LIGHT, PURSE_LIGHT]
const LIGHT_BANDS: Array[float] = [1.0, 0.72, 0.44]
const LIGHT_ALPHAS: Array[float] = [0.04, 0.07, 0.10]
const LIGHT_POINTS := 48
const LIGHT_COLOR := Palette.MUSTARD_PALE
const SPOT_COLOR := Palette.MUSTARD_LIGHT
## The plaque in the top bar: a small velvet-darkest plate in a brass rim with gold lettering
## (the register plate's look), so it reads as decor and not as a button.
const PLAQUE_SIZE := Vector2(156, 24)
const PLAQUE_TEXT := "FINE GROCERIES"
const PLAQUE_FONT_SIZE := 12
const PLAQUE_RIM := 2
const PLAQUE_FACE := Palette.VELVET_DARKEST
const PLAQUE_RIM_COLOR := Palette.BRASS
const PLAQUE_TEXT_COLOR := Palette.GOLD
const VALANCE_NAME := &"Valance"
## The belt's light canvas (the spotlights and the belt's pool), and the other pools' canvases.
const LIGHTS_NAME := &"Lights"
const REGISTER_LIGHT_NAME := &"RegisterLight"
const TRAY_LIGHT_NAME := &"TrayLight"
const PURSE_LIGHT_NAME := &"PurseLight"

const WALL := preload("res://art/scenery/wall_velvet.png")
const MARBLE := preload("res://art/scenery/marble_tile.png")
const BRASS_RAIL := preload("res://art/frames/brass_rail.png")
const VALANCE := preload("res://art/scenery/valance.png")


## Adds the window-sized parts to `parent`, behind the stage: the wall (its first child), the
## counter (its second), the rails and the kickplate. Returns the wall, which takes the
## background clicks.
static func screen_parts(parent: Control) -> TextureRect:
	var wall: TextureRect = UiKit.tiled(WALL)
	wall.name = "Wall"
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(wall)
	var counter: TextureRect = UiKit.tiled(MARBLE)
	counter.name = "Counter"
	counter.set_anchors_preset(Control.PRESET_FULL_RECT)
	counter.anchor_top = 0.5
	counter.offset_top = ShiftStage.COUNTER_TOP - STAGE_MIDDLE
	parent.add_child(counter)
	var picture_rail: Control = _band(rail(PICTURE_RAIL.size.y), PICTURE_RAIL)
	picture_rail.name = "PictureRail"
	parent.add_child(picture_rail)
	var counter_edge: Control = _band(rail(COUNTER_EDGE.size.y), COUNTER_EDGE)
	counter_edge.name = "CounterEdge"
	parent.add_child(counter_edge)
	var kickplate: ColorRect = ColorRect.new()
	kickplate.name = "Kickplate"
	kickplate.color = KICKPLATE_COLOR
	kickplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kickplate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	kickplate.offset_top = -KICKPLATE_HEIGHT
	kickplate.offset_bottom = 0
	parent.add_child(kickplate)
	return wall


## The valance at VALANCE_RECT, for a parent standing at `origin` on the stage. It takes no
## click.
static func valance(origin: Vector2) -> TextureRect:
	var result: TextureRect = UiKit.tiled(VALANCE)
	result.name = VALANCE_NAME
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.position = VALANCE_RECT.position - origin
	result.size = VALANCE_RECT.size
	return result


## An empty canvas for lights, the stage's size, taking no click. In a parent standing at
## `origin` on the stage its coordinates are the stage's; nothing clips it.
static func light_canvas(canvas_name: StringName, origin: Vector2) -> Control:
	var canvas: Control = Control.new()
	canvas.name = canvas_name
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.position = -origin
	canvas.size = ShiftStage.SIZE
	return canvas


## A light canvas for the stage itself, drawing the pool of light `light`.
static func pool(canvas_name: StringName, light: Rect2) -> Control:
	var canvas: Control = light_canvas(canvas_name, Vector2.ZERO)
	canvas.draw.connect(draw_pool.bind(canvas, light))
	return canvas


## Where the spotlights start for a top bar whose visible parts stand at `parts` (stage
## coordinates), so each cone starts on velvet: each of SPOT_XS stays if its top clears every
## part, or else moves to the nearest place over the belt where it does, at least SPOT_SPACING
## right of the cone before it. One with no such place stays where it was.
static func spot_xs(parts: Array[Rect2]) -> Array[float]:
	var velvet: Array[Vector2] = _velvet(parts)
	var xs: Array[float] = []
	for x: float in SPOT_XS:
		var least: float = -INF
		if not xs.is_empty():
			least = xs[-1] + SPOT_SPACING
		var best: float = x
		var distance: float = INF
		for gap: Vector2 in velvet:
			var from: float = maxf(gap.x, least)
			if from > gap.y:
				continue
			var at: float = clampf(x, from, gap.y)
			if absf(at - x) < distance:
				best = at
				distance = absf(at - x)
		xs.append(best)
	return xs


## The top bar's FINE GROCERIES plaque.
static func plaque() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Plaque"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = PLAQUE_SIZE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PLAQUE_FACE
	style.border_color = PLAQUE_RIM_COLOR
	style.set_border_width_all(PLAQUE_RIM)
	panel.add_theme_stylebox_override("panel", style)
	var engraved: Label = UiKit.display_label(PLAQUE_TEXT, PLAQUE_FONT_SIZE, false)
	engraved.add_theme_color_override("font_color", PLAQUE_TEXT_COLOR)
	engraved.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	engraved.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	engraved.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(engraved)
	return panel


## A brass rail `height` canvas pixels tall: the full rail (glint, gold, brass), or for a thin
## one its brass rows only.
static func rail(height: float) -> TextureRect:
	var region: AtlasTexture = AtlasTexture.new()
	region.atlas = BRASS_RAIL
	var top: float = 2.0 * ArtStyle.ART_SCALE if height <= 2.0 * ArtStyle.ART_SCALE else 0.0
	region.region = Rect2(0, top, BRASS_RAIL.get_width(), height)
	return UiKit.sprite(region)


## Draws the spotlights' cones at `xs` on `canvas` (stage coordinates), on the 2 px art grid.
static func draw_spots(canvas: CanvasItem, xs: Array[float]) -> void:
	for x: float in xs:
		var shown: float = 0.0
		for band: int in range(SPOT_BANDS.size()):
			# Each band over the ones under it adds up to SPOT_ALPHAS[band].
			var alpha: float = (SPOT_ALPHAS[band] - shown) / (1.0 - shown)
			shown = SPOT_ALPHAS[band]
			var top: float = SPOT_TOP * SPOT_BANDS[band]
			var bottom: float = SPOT_BOTTOM * SPOT_BANDS[band]
			var foot: float = ShiftStage.COUNTER_TOP
			var cone: PackedVector2Array = PackedVector2Array(
				[
					Vector2(x - top, 0).snappedf(ArtStyle.ART_SCALE),
					Vector2(x + top, 0).snappedf(ArtStyle.ART_SCALE),
					Vector2(x + bottom, foot).snappedf(ArtStyle.ART_SCALE),
					Vector2(x - bottom, foot).snappedf(ArtStyle.ART_SCALE),
				]
			)
			canvas.draw_colored_polygon(cone, Color(SPOT_COLOR, alpha))


## Draws the pool of light `light` (centre, radii) on `canvas` (stage coordinates), on the 2 px
## art grid.
static func draw_pool(canvas: CanvasItem, light: Rect2) -> void:
	var shown: float = 0.0
	for band: int in range(LIGHT_BANDS.size()):
		# Each band over the ones under it adds up to LIGHT_ALPHAS[band].
		var alpha: float = (LIGHT_ALPHAS[band] - shown) / (1.0 - shown)
		shown = LIGHT_ALPHAS[band]
		var points: PackedVector2Array = PackedVector2Array()
		for index: int in range(LIGHT_POINTS):
			var angle: float = TAU * index / LIGHT_POINTS
			var radius: Vector2 = light.size * LIGHT_BANDS[band]
			var point: Vector2 = light.position + Vector2(cos(angle), sin(angle)) * radius
			points.append(point.snappedf(ArtStyle.ART_SCALE))
		canvas.draw_colored_polygon(points, Color(LIGHT_COLOR, alpha))


## The x ranges, left to right, where a cone's top (SPOT_TOP either side) clears every part of
## `parts`, over the belt and with the cone's foot on the stage.
static func _velvet(parts: Array[Rect2]) -> Array[Vector2]:
	var sorted: Array[Rect2] = []
	sorted.assign(parts)
	sorted.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var last: float = minf(ShiftStage.BELT_RECT.end.x, ShiftStage.SIZE.x - SPOT_BOTTOM)
	var gaps: Array[Vector2] = []
	var from: float = maxf(ShiftStage.BELT_RECT.position.x, SPOT_BOTTOM)
	for part: Rect2 in sorted:
		var to: float = minf(part.position.x - SPOT_TOP, last)
		if to >= from:
			gaps.append(Vector2(from, to))
		from = maxf(from, part.end.x + SPOT_TOP)
	if from <= last:
		gaps.append(Vector2(from, last))
	return gaps


## Spans `item` across the window at the stage's `rect` rows.
static func _band(item: Control, rect: Rect2) -> Control:
	item.anchor_left = 0.0
	item.anchor_right = 1.0
	item.anchor_top = 0.5
	item.anchor_bottom = 0.5
	item.offset_top = rect.position.y - STAGE_MIDDLE
	item.offset_bottom = rect.end.y - STAGE_MIDDLE
	return item
