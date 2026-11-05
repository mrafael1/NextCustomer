class_name RailLight
extends RefCounted
## The price rail's apron band (BeltPanel.APRON, inside the rail's ends) as the lights on it share
## it: its place (RAIL_Y, RAIL_HEIGHT, RAIL_LEFT), its top SHADE rows (a darker shade under the
## lip, as the steel band has) and its HIGHLIGHT row, and the belt's bolts and chevrons drawn back
## over a light on it (draw_hardware). QuotaLight and BonusLights light it. It was #86's rail light
## (kept by #105 piece 2): the gold run from a giver's ticket to its target's in the count, gone in
## PR #138 round 7 (the user's "remove yellow line filling when an item is scanned under first
## item"); only the band's shared look stays.

const RAIL_Y := ShiftStage.BELT_RECT.position.y + BeltPanel.APRON.position.y
const RAIL_HEIGHT := BeltPanel.APRON.size.y
const RAIL_LEFT := ShiftStage.BELT_RECT.position.x + BeltPanel.APRON.position.x
const SHADE := 2.0
const HIGHLIGHT := 2.0


## The belt's bolts and chevrons that fall between `left` and `right` (stage x), drawn on
## `canvas` at `alpha_now`, back over a light on the apron band (this one, or BonusLights).
static func draw_hardware(canvas: CanvasItem, left: float, right: float, alpha_now: float) -> void:
	var tint: Color = Color(Color.WHITE, alpha_now)
	for index: int in range(BeltPanel.BOLT_COUNT):
		var step: Vector2 = ShiftStage.BELT_RECT.position + Vector2(index * BeltPanel.BOLT_PITCH, 0)
		for part: Array in [
			[BeltPanel.BELT_BOLT, BeltPanel.BOLT_FIRST],
			[BeltPanel.BELT_CHEVRONS, BeltPanel.CHEVRONS_FIRST]
		]:
			var texture: Texture2D = part[0]
			var at: Vector2 = step + (part[1] as Vector2)
			if at.x + texture.get_width() > left and at.x < right:
				canvas.draw_texture(texture, at, tint)
