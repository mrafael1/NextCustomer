class_name BoutiqueDecor
extends RefCounted
## The boutique beyond the wall band in style frame v2 (#75, round 3: the velvet wall barely
## showed, so the mood rested on brass and the purse). Decor only, with no game information: a
## pleated velvet valance with a gold braid and a brass fringe along the belt's top edge, warm
## ceiling spotlights fanning down across the wall onto the belt, and a brass-rimmed plaque on
## the wall in the top bar's gap. The items and the belt keep their size.

## The valance hangs on its brass rod over the picture rail along the belt's top edge, under the
## top bar's parts: 16 scalloped swags, each dipping 8 px at its middle, with a hanging brass
## fringe. The plaques hang over its braid; the mats and the sprites start below its fringe.
const VALANCE_RECT := Rect2(16, 54, 896, 34)
## The ceiling spotlights: each a cone of warm light from the stage's top at SPOT_XS (the wall's
## gaps between the top bar's parts, so the light shows on the velvet), SPOT_TOP half-wide, down
## across the valance to the counter line (SPOT_BOTTOM half-wide), in two hard bands of mustard
## light, under the top bar and the items.
const SPOT_XS: Array[float] = [289.0, 516.0, 811.0]
const SPOT_TOP := 6.0
const SPOT_BOTTOM := 100.0
const SPOT_BANDS: Array[float] = [1.0, 0.55]
const SPOT_ALPHAS: Array[float] = [0.10, 0.18]
## The plaque, between the inspection tag and Deck: a small velvet-darkest plate in a brass rim
## with gold lettering (the register's name plate's look), so it reads as decor and not as a
## button.
const PLAQUE_RECT := Rect2(836, 20, 156, 24)
const PLAQUE_TEXT := "FINE GROCERIES"
const PLAQUE_SIZE := 12
const PLAQUE_RIM := 2

const VALANCE := preload("res://art/scenery/valance.png")


## The valance, tiled across its rect.
static func valance() -> TextureRect:
	return UiKit.tiled(VALANCE)


## The plaque at PLAQUE_RECT, its text in gold.
static func plaque() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = StyleFrameV2.VELVET_DARKEST
	style.border_color = StyleFrameV2.BRASS
	style.set_border_width_all(PLAQUE_RIM)
	panel.add_theme_stylebox_override("panel", style)
	panel.name = "BoutiquePlaque"
	panel.position = PLAQUE_RECT.position
	panel.size = PLAQUE_RECT.size
	var engraved: Label = UiKit.display_label(PLAQUE_TEXT, PLAQUE_SIZE, false)
	engraved.add_theme_color_override("font_color", StyleFrameV2.GOLD)
	engraved.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	engraved.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(engraved)
	return panel


## Draws the spotlights' cones on `canvas` (stage coordinates), on the 2 px art grid.
static func draw_spots(canvas: CanvasItem) -> void:
	for x: float in SPOT_XS:
		var shown: float = 0.0
		for band: int in range(SPOT_BANDS.size()):
			# Each band over the ones under it adds up to SPOT_ALPHAS[band].
			var alpha: float = (SPOT_ALPHAS[band] - shown) / (1.0 - shown)
			shown = SPOT_ALPHAS[band]
			var top: float = SPOT_TOP * SPOT_BANDS[band]
			var bottom: float = SPOT_BOTTOM * SPOT_BANDS[band]
			var foot: float = StyleFrameV2.COUNTER_TOP
			var cone: PackedVector2Array = PackedVector2Array(
				[
					Vector2(x - top, 0).snappedf(ArtStyle.ART_SCALE),
					Vector2(x + top, 0).snappedf(ArtStyle.ART_SCALE),
					Vector2(x + bottom, foot).snappedf(ArtStyle.ART_SCALE),
					Vector2(x - bottom, foot).snappedf(ArtStyle.ART_SCALE),
				]
			)
			canvas.draw_colored_polygon(cone, Color(StyleFrameV2.MUSTARD_LIGHT, alpha))
