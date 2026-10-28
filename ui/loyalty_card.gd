class_name LoyaltyCard
extends PanelContainer
## The loyalty card (full build plan 5.2), in the pixel-art style (#55): the loyalty_card frame with
## one box per register the RECEIPT REWARDS machine can stamp (its register cap, #77; plus one for a
## starting deck's upgrade, 7.3), each an empty stamp ring until an upgrade is taken. A taken
## upgrade stamps the next box with its perk icon (`face_icon`), or its initials when it has none
## that fits.
## Hovering a stamped box shows the upgrade's name, type, effect and condition, so nothing about an
## upgrade is shown only inside an animation.
##
## The count-up flies upgrade steps in from these boxes: box(i) belongs to the run's upgrade i.
##
## The top bar's face (#80 step 10, mock-up B2; `chip`): the teal LOYALTY chip with B2's 13x13
## stamp rings at 2x, upright: a mustard ring around the teal panel for a stamp, a dashed ring
## for an empty box. A perk's icon sits in its ring; a perk with none that fits keeps its
## initials, in mustard pale, as large as fits inside the ring. The final receipt keeps the card
## face.
##
## Perk icons (#108 follow-up, decided with the user on 2026-10-26): every perk whose icon fits
## its box shows it at the art scale instead of its initials (a family perk its family glyph, a
## jackpot its product's mini, the rest the icon their LOYALTY ticket shows). A family perk's
## ring takes its family's colour (`family_ring`, as its tickets do since #105) between a thin ink
## edge and a teal dark inside, so every family colour reads on the teal chip and the cream card
## alike (none does on teal alone: Dairy's face is 1.0:1 against it); an Aisle run
## also wears a small family-coloured "×" tag at the box's top left (`run_mark`), so a family's
## Regulars and Aisle run tell apart.
##
## Planning effects (#71): hovering a stamped box reports box_hovered / box_unhovered (its
## tooltip stays); set_relation rings a box in gold (the hovered item's cause, or the hovered box
## itself). A rebuild (the upgrades changed) clears it. An upgrade's fizzles show as "WASTED"
## stickers with its badge on the belt (PlanningLayer), not on its box.
##
## Perk levels (#108, v0.61): a perk levelled up by the machine (LV 2, LV 3) keeps its box, which
## shows its level as a small mustard badge with the level's numeral in Pixelify at the box's
## bottom right, inside the box (level_mark), on both faces; its tooltip names the level
## ("Coupon engine LV 2").

## The pointer entered or left the stamped box of the run's upgrade `index`.
signal box_hovered(index: int)
signal box_unhovered(index: int)

const BOX_SIZE := Vector2(34, 34)
## The resting tilt of every stamped box.
const STAMP_TILT := -6.0
## The card's 9-slice margin in art pixels, and its padding: left, top, right, bottom.
const FRAME_MARGIN := 3
const PADDING := Vector4(10, 6, 8, 4)
const TITLE_SIZE := 11
## The initials' size: the widest (four letters, e.g. "ExCS") just fits inside the border.
const INITIALS_SIZE := 12
## A stamped box's ink ring, in canvas pixels.
const STAMP_BORDER := 2
## The initials' ink outline: thinner than UiKit.LIGHT_OUTLINE, which would fill the letters'
## counters at this size.
const INITIALS_OUTLINE := 3

## The chip face's boxes (the 13x13 rings at 2x), their gap, and the initials' sizes: the largest
## that fits inside both rings (CHIP_RING px: the mustard light and mustard texels at 2x, which
## leaves the teal panel's 18 px), down to the smallest.
const CHIP_BOX_SIZE := Vector2(26, 26)
const CHIP_BOX_GAP := 8
const CHIP_RING := 4
const CHIP_INITIALS_SIZES: Array[int] = [12, 11, 10, 9, 8, 7]
## A related box's gold ring (#71): its line, outside the box by RING_OUTSET.
const RING_WIDTH := 2
const RING_OUTSET := 2
const RING_NAME := "RelationRing"
## A levelled perk's badge (#108): Pixelify LEVEL_SIZE ink on mustard light with an ink border,
## LEVEL_PAD px each side of its numeral, in the box's bottom right corner (the round box leaves
## that corner free, so the badge sits on the ring's edge).
const LEVEL_MARK_NAME := "LevelMark"
const LEVEL_SIZE := 12
const LEVEL_PAD := 3.0
const LEVEL_BORDER := 2
## The chip face's smaller level badge (polish pass): the 26 px ring's full-size badge hid most of
## the perk icon, so the chip's numeral is CHIP_LEVEL_SIZE with CHIP_LEVEL_PAD each side.
const CHIP_LEVEL_SIZE := 9
const CHIP_LEVEL_PAD := 1.0
## The card face's upright level badge sits this far in from the box's corner (polish pass).
const LEVEL_INSET := 2.0
## The ring laid over a perk icon (polish pass), so the icon's corners tuck under the ring.
const ICON_RIM_NAME := "Rim"
## A perk icon's node in its box.
const ICON_NAME := "Icon"
## A family perk's ring (#108 follow-up), this wide on both faces (the chip's ring art is CHIP_RING
## wide too): its outer FAMILY_EDGE px ink, the rest its family's colour, teal dark inside.
const FAMILY_RING := 4
const FAMILY_EDGE := 2
const FAMILY_EDGE_NAME := "FamilyEdge"
## An Aisle run's tag (#108 follow-up): 5x5 art pixels at 2x at the box's top left, an ink edge
## around its family's face colour with an ink "×" (RUN_MARK_CROSS, art cells) in the middle;
## small enough to stay clear of the level badge in the bottom right, even on the chip.
const RUN_MARK_NAME := "RunMark"
const RUN_MARK_SIZE := Vector2(10, 10)
const RUN_MARK_FACE := &"run_mark_face"
const RUN_MARK_CROSS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(3, 1), Vector2i(2, 2), Vector2i(1, 3), Vector2i(3, 3)
]

const CARD_FRAME := preload("res://art/frames/loyalty_card.png")
const STAMP_EMPTY := preload("res://art/icons/stamp_empty.png")
const RING := preload("res://art/icons/stamp_ring.png")
const RING_EMPTY := preload("res://art/icons/stamp_ring_empty.png")
## The chip ring's rim alone, laid over a perk icon so its square corners tuck under the ring.
const RING_RIM := preload("res://art/icons/stamp_ring_rim.png")

var _boxes: HBoxContainer
var _box_count: int = 0
## What the boxes show now, so a refresh only rebuilds them when the upgrades change.
var _shown: Array[UpgradeDefinition] = []
## The top bar's chip face (else the card face).
var _chip: bool = false
var _box_size: Vector2 = BOX_SIZE


## `chip`: the top bar's face; else the card (the final receipt's).
func _init(chip: bool = false) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip = chip
	_box_size = CHIP_BOX_SIZE if chip else BOX_SIZE
	var style: StyleBoxTexture = ArtStyle.frame_style(
		TopBar.CHIP_FRAME if chip else CARD_FRAME, FRAME_MARGIN
	)
	style.content_margin_left = float(TopBar.CHIP_PADDING) if chip else PADDING.x
	style.content_margin_top = 0.0 if chip else PADDING.y
	style.content_margin_right = float(TopBar.CHIP_PADDING) if chip else PADDING.z
	style.content_margin_bottom = 0.0 if chip else PADDING.w
	add_theme_stylebox_override("panel", style)
	ArtStyle.use_pixel_material(self)
	if chip:
		custom_minimum_size.y = TopBar.ROW_SIZE.y
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", TopBar.CHIP_SEPARATION if chip else 6)
	add_child(row)
	var title: Label = (
		TopBar.key_label("LOYALTY")
		if chip
		else UiKit.display_label("LOYALTY\nCARD", TITLE_SIZE, false)
	)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	_boxes = HBoxContainer.new()
	_boxes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boxes.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_boxes.add_theme_constant_override("separation", CHIP_BOX_GAP if chip else 4)
	# A container resets its children's rotation whenever it sorts them, so the tilt is put
	# back after every sort.
	_boxes.sort_children.connect(_tilt_stamped_boxes)
	row.add_child(_boxes)


## Shows the owned upgrades in pick order, one per box. `boxes` comes from the caller (usually
## box_count). More upgrades than boxes (debug) add boxes.
func show_upgrades(boxes: int, upgrades: Array[UpgradeDefinition]) -> void:
	if boxes == _box_count and upgrades == _shown:
		return
	_box_count = boxes
	_shown = upgrades.duplicate()
	for child: Node in _boxes.get_children():
		_boxes.remove_child(child)
		child.queue_free()
	for index: int in range(maxi(boxes, upgrades.size())):
		var upgrade: UpgradeDefinition = upgrades[index] if index < upgrades.size() else null
		var made: PanelContainer = _make_box(upgrade)
		_boxes.add_child(made)
		if upgrade != null:
			_add_relation_parts(made)
			made.mouse_entered.connect(box_hovered.emit.bind(index))
			made.mouse_exited.connect(box_unhovered.emit.bind(index))


## Rings the box of upgrade `index` in gold (#71), or takes the ring off.
func set_relation(index: int, related: bool) -> void:
	var ring: Control = _part(index, RING_NAME)
	if ring != null:
		ring.visible = related


## Whether the box of upgrade `index` is ringed.
func has_relation(index: int) -> bool:
	var ring: Control = _part(index, RING_NAME)
	return ring != null and ring.visible


## Takes every ring off.
func clear_relations() -> void:
	for index: int in range(_shown.size()):
		set_relation(index, false)


## The ring (`part_name`) of upgrade `index`'s box, or null.
func _part(index: int, part_name: String) -> Control:
	var stamped: Control = box(index)
	return stamped.get_node_or_null(part_name) as Control if stamped != null else null


## A stamped box's hidden gold ring (round, just outside the box). It takes no clicks; the box's
## first child stays its label (box_texts).
func _add_relation_parts(stamped: PanelContainer) -> void:
	var ring: Panel = Panel.new()
	ring.name = RING_NAME
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: StyleBoxFlat = StyleBoxFlat.new()
	line.draw_center = false
	line.border_color = Palette.GOLD
	line.set_border_width_all(RING_WIDTH)
	line.set_corner_radius_all(int(_box_size.x / 2.0) + RING_OUTSET)
	line.set_expand_margin_all(RING_OUTSET)
	ring.add_theme_stylebox_override("panel", line)
	ring.visible = false
	stamped.add_child(ring)


## The run's boxes: one per register the machine can stamp (its register cap, #77), plus one when
## its deck has a starting upgrade (full build plan 7.3).
static func box_count(run: RunState) -> int:
	var cap: int = run.balance.machine.register_cap if run.balance.machine != null else 0
	return cap + (0 if run.starter.starting_upgrade == null else 1)


## The box of the run's upgrade `index` (pick order), or null.
func box(index: int) -> Control:
	if index < 0 or index >= _shown.size() or index >= _boxes.get_child_count():
		return null
	return _boxes.get_child(index) as Control


## The box `index` whether stamped or still empty (the machine's register flies to the next empty
## one before the card shows its stamp), or null past the card's boxes.
func any_box(index: int) -> Control:
	if index < 0 or index >= _boxes.get_child_count():
		return null
	return _boxes.get_child(index) as Control


## The stamped boxes, indexed like the run's upgrades (for the count-up's fly-ins).
func stamped_boxes() -> Array[Control]:
	var stamped: Array[Control] = []
	for index: int in range(_shown.size()):
		stamped.append(box(index))
	return stamped


## The upgrades' names, indexed like the run's upgrades, for the receipt.
static func names(upgrades: Array[UpgradeDefinition]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for upgrade: UpgradeDefinition in upgrades:
		result.append(upgrade.display_name)
	return result


## Every box's text: a stamped box's initials (empty when it shows its perk icon, box_icon), empty
## for an empty box.
func box_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for child: Node in _boxes.get_children():
		texts.append((child.get_child(0) as Label).text)
	return texts


## The stamp landing on the box of upgrade `index`: big and tilted, slammed down.
func play_stamp(index: int) -> void:
	var target: Control = box(index)
	if target == null:
		return
	target.pivot_offset = _box_size / 2.0
	target.scale = Vector2(2.4, 2.4)
	target.rotation = deg_to_rad(-20.0)
	target.modulate.a = 0.0
	var slam: Tween = target.create_tween().set_parallel()
	slam.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam.tween_property(target, "scale", Vector2.ONE, 0.16)
	slam.tween_property(target, "rotation", stamp_tilt(), 0.16)
	slam.tween_property(target, "modulate:a", 1.0, 0.1)
	slam.chain().tween_property(target, "scale", Vector2(1.15, 1.15), 0.06)
	slam.chain().tween_property(target, "scale", Vector2.ONE, 0.12)


## The perk's name with its level past LV 1 ("Coupon engine", "Coupon engine LV 2").
static func perk_name(upgrade: UpgradeDefinition) -> String:
	if upgrade.level_number() > 1:
		return "%s LV %d" % [upgrade.display_name, upgrade.level_number()]
	return upgrade.display_name


## The level badge on the box of upgrade `index` (null: none, a LV 1 perk or no such box).
func level_mark(index: int) -> Control:
	var holder: Control = _part(index, LEVEL_MARK_NAME)
	return holder.get_child(0) as Control if holder != null else null


## The level badge of upgrade `index` in its box's own frame (the box's stamp tilt undone), and
## the box's rect in that frame: [badge, box], or [] when there is no badge.
func level_mark_in_box(index: int) -> Array[Rect2]:
	var badge: Control = level_mark(index)
	var stamped: Control = box(index)
	if badge == null or stamped == null:
		return []
	var to_box: Transform2D = (
		stamped.get_global_transform().affine_inverse() * badge.get_global_transform()
	)
	return [to_box * Rect2(Vector2.ZERO, badge.size), Rect2(Vector2.ZERO, stamped.size)]


## The stamp of a perk with no icon that fits: the first two letters of the first word, then the
## second word's initial ("Coupon engine" CoE, "Category engine" CaE, #108's "Dairy aisle run"
## DaA), so similar names stay apart and three letters fit the ring.
static func initials(display_name: String) -> String:
	var words: PackedStringArray = display_name.split(" ", false)
	if words.is_empty():
		return "?"
	var text: String = words[0].substr(0, 2).capitalize()
	for word: String in words.slice(1, 2):
		text += word.substr(0, 1).to_upper()
	return text


## A stamped box's hover text: the ticket's fields, so nothing is only in the animation.
static func tooltip_for(upgrade: UpgradeDefinition) -> String:
	var lines: PackedStringArray = PackedStringArray(
		["%s (%s)" % [perk_name(upgrade), upgrade.type_label()], upgrade.effect_text]
	)
	if not upgrade.condition_text.is_empty():
		lines.append(upgrade.condition_text)
	return "\n".join(lines)


## A stamped box's resting tilt in radians: STAMP_TILT on the card, upright on the chip (B2).
func stamp_tilt() -> float:
	return 0.0 if _chip else deg_to_rad(STAMP_TILT)


func _tilt_stamped_boxes() -> void:
	for stamped: Control in stamped_boxes():
		if stamped == null:
			continue
		stamped.pivot_offset = _box_size / 2.0
		stamped.rotation = stamp_tilt()


func _make_box(upgrade: UpgradeDefinition) -> PanelContainer:
	if _chip:
		return make_ring(upgrade)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = BOX_SIZE
	if upgrade == null:
		# The empty stamp ring, drawn at the box's size.
		var ring: StyleBoxTexture = StyleBoxTexture.new()
		ring.texture = STAMP_EMPTY
		ring.set_content_margin_all(0)
		panel.add_theme_stylebox_override("panel", ring)
		ArtStyle.use_pixel_material(panel)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif family_ring(upgrade) != Color():
		panel.add_theme_stylebox_override("panel", _family_face(upgrade, BOX_SIZE))
	else:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.set_corner_radius_all(17)
		style.set_border_width_all(STAMP_BORDER)
		style.set_content_margin_all(0)
		# The darker tomato keeps the paper initials readable (5.9:1 against 3.7:1); an icon
		# sits on teal dark, as the mock-up's boxes (#108).
		var icon: Texture2D = face_icon(upgrade, false)
		style.bg_color = Palette.TEAL_DARK if icon != null else Palette.TOMATO_DARK
		style.border_color = Palette.INK
		panel.add_theme_stylebox_override("panel", style)
	if upgrade != null:
		# PASS, not IGNORE: a tooltip needs the mouse.
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.tooltip_text = tooltip_for(upgrade)
	# The number font (MSDF Atkinson) stays crisp at the tilt and tells l from I and C from D:
	# paper with a thin ink outline.
	var label: Label = UiKit.number_label(stamp_text(upgrade, false), INITIALS_SIZE, true)
	label.add_theme_constant_override("outline_size", INITIALS_OUTLINE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	add_perk_icon(panel, upgrade, false)
	add_family_edge(panel, upgrade, BOX_SIZE)
	add_run_mark(panel, upgrade, false)
	add_level_mark(panel, upgrade, BOX_SIZE)
	return panel


## The chip face's box: B2's ring (dashed when empty) at 2x, or a family perk's ring in its
## family's colour, holding the perk's icon, else its initials in mustard pale at the largest
## CHIP_INITIALS_SIZES size that fits inside the rings. The deck view's Run info shows it beside
## each upgrade (#56).
static func make_ring(upgrade: UpgradeDefinition) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = CHIP_BOX_SIZE
	if family_ring(upgrade) != Color():
		panel.add_theme_stylebox_override("panel", _family_face(upgrade, CHIP_BOX_SIZE))
	else:
		var ring: StyleBoxTexture = StyleBoxTexture.new()
		ring.texture = RING if upgrade != null else RING_EMPTY
		ring.set_content_margin_all(0)
		panel.add_theme_stylebox_override("panel", ring)
	ArtStyle.use_pixel_material(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = UiKit.number_label("", CHIP_INITIALS_SIZES[0], false)
	label.add_theme_color_override("font_color", Palette.MUSTARD_PALE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	if upgrade == null:
		return panel
	# PASS, not IGNORE: a tooltip needs the mouse.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.tooltip_text = tooltip_for(upgrade)
	label.text = stamp_text(upgrade, true)
	label.add_theme_font_size_override("font_size", chip_initials_size(label.text))
	add_perk_icon(panel, upgrade, true)
	add_family_edge(panel, upgrade, CHIP_BOX_SIZE)
	add_run_mark(panel, upgrade, true)
	add_level_mark(panel, upgrade, CHIP_BOX_SIZE)
	return panel


## The perk icon of `upgrade` (UpgradeDefinition.icon_ref) when it loads and fits `inside` px
## square at the art scale, else null (the box shows its initials).
static func perk_icon(upgrade: UpgradeDefinition, inside: float) -> Texture2D:
	if (
		upgrade == null
		or upgrade.icon_ref.is_empty()
		or not ResourceLoader.exists(upgrade.icon_ref)
	):
		return null
	var texture: Texture2D = load(upgrade.icon_ref) as Texture2D
	if texture == null:
		return null
	var drawn: Vector2 = texture.get_size() * ArtStyle.ART_SCALE
	return texture if drawn.x <= inside and drawn.y <= inside else null


## The ring colour of a family perk (#108 follow-up): the face colour of the family it works with
## (UpgradeDefinition.boosts_tag, FamilyPalette), or Color() for a perk with no family colour.
static func family_ring(upgrade: UpgradeDefinition) -> Color:
	var style: FamilyStyle = _family(upgrade)
	return style.face if style != null else Color()


## A family perk's round face in a `box_size` box: teal dark inside a FAMILY_RING ring in its
## family's colour (add_family_edge inks the ring's outer edge).
static func _family_face(upgrade: UpgradeDefinition, box_size: Vector2) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.anti_aliasing = false
	style.bg_color = Palette.TEAL_DARK
	style.border_color = family_ring(upgrade)
	style.set_border_width_all(FAMILY_RING)
	style.set_corner_radius_all(int(box_size.x / 2.0))
	style.set_content_margin_all(0)
	return style


## Inks the outer FAMILY_EDGE px of a family perk's ring in its box `stamped` (`box_size`): a
## round ink line over the whole box. Other perks get none. The box's first child stays its label
## (box_texts).
static func add_family_edge(
	stamped: PanelContainer, upgrade: UpgradeDefinition, box_size: Vector2
) -> void:
	if family_ring(upgrade) == Color():
		return
	var edge: Panel = Panel.new()
	edge.name = FAMILY_EDGE_NAME
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: StyleBoxFlat = StyleBoxFlat.new()
	line.anti_aliasing = false
	line.draw_center = false
	line.border_color = Palette.INK
	line.set_border_width_all(FAMILY_EDGE)
	line.set_corner_radius_all(int(box_size.x / 2.0))
	edge.add_theme_stylebox_override("panel", line)
	stamped.add_child(edge)


## The family look of `upgrade`'s boosts_tag, when it has ticket colours, else null.
static func _family(upgrade: UpgradeDefinition) -> FamilyStyle:
	if upgrade == null or upgrade.boosts_tag.is_empty():
		return null
	var style: FamilyStyle = FamilyPalette.shared().style(upgrade.boosts_tag)
	return style if style != null and style.has_ticket_colours() else null


## The icon `upgrade`'s box shows on the chip face (`chip`) or the card face: its perk icon when
## it fits inside the box's ring (FAMILY_RING for a family perk, else the face's own ring), else
## null. Every perk's icon fits both (#108 follow-up: Big basket's is a 9x9 "+1" ticket since).
static func face_icon(upgrade: UpgradeDefinition, chip: bool) -> Texture2D:
	var box_size: Vector2 = CHIP_BOX_SIZE if chip else BOX_SIZE
	var ring: int = CHIP_RING if chip else STAMP_BORDER
	if family_ring(upgrade) != Color():
		ring = FAMILY_RING
	return perk_icon(upgrade, box_size.x - 2.0 * ring)


## A stamped box's text on the chip face (`chip`) or the card face: its initials when no icon
## fits, else empty (empty for an empty box too).
static func stamp_text(upgrade: UpgradeDefinition, chip: bool) -> String:
	if upgrade == null or face_icon(upgrade, chip) != null:
		return ""
	return initials(upgrade.display_name)


## Adds `upgrade`'s perk icon (face_icon) to its box `stamped` on the chip face (`chip`) or the
## card face, centred at the art scale. The box's first child stays its label (box_texts).
static func add_perk_icon(stamped: PanelContainer, upgrade: UpgradeDefinition, chip: bool) -> void:
	var texture: Texture2D = face_icon(upgrade, chip)
	if texture == null:
		return
	var box_size: Vector2 = CHIP_BOX_SIZE if chip else BOX_SIZE
	var holder: Control = Control.new()
	holder.name = ICON_NAME
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamped.add_child(holder)
	var sprite: TextureRect = UiKit.sprite(texture)
	sprite.name = "Sprite"
	sprite.size = texture.get_size() * ArtStyle.ART_SCALE
	# On the art grid, so the icon's texels stay square.
	sprite.position = (
		((box_size - sprite.size) / 2.0 / ArtStyle.ART_SCALE).floor() * ArtStyle.ART_SCALE
	)
	if not chip:
		# Upright inside the card's tilted stamp (polish pass): a round ring looks the same at any
		# tilt, and pixel art turned 6 degrees goes soft and jagged.
		sprite.pivot_offset = box_size / 2.0 - sprite.position
		sprite.rotation = -deg_to_rad(STAMP_TILT)
	holder.add_child(sprite)
	holder.add_child(_icon_rim(upgrade, chip))


## The ring laid over `upgrade`'s icon (polish pass), the same as the box's own ring under it: a
## family perk's ring in its family's colour, else the chip's rim art or the card's ink ring.
static func _icon_rim(upgrade: UpgradeDefinition, chip: bool) -> Control:
	var box_size: Vector2 = CHIP_BOX_SIZE if chip else BOX_SIZE
	if chip and family_ring(upgrade) == Color():
		var rim: TextureRect = UiKit.sprite(RING_RIM)
		rim.name = ICON_RIM_NAME
		rim.size = box_size
		return rim
	var panel: Panel = Panel.new()
	panel.name = ICON_RIM_NAME
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = box_size
	var line: StyleBoxFlat = StyleBoxFlat.new()
	line.anti_aliasing = false
	line.draw_center = false
	var family: Color = family_ring(upgrade)
	line.border_color = family if family != Color() else Palette.INK
	line.set_border_width_all(FAMILY_RING if family != Color() else STAMP_BORDER)
	line.set_corner_radius_all(int(box_size.x / 2.0))
	panel.add_theme_stylebox_override("panel", line)
	return panel


## The perk icon shown in the box of upgrade `index`, or null (its initials, or no such box).
func box_icon(index: int) -> Texture2D:
	var holder: Control = _part(index, ICON_NAME)
	return (holder.get_child(0) as TextureRect).texture if holder != null else null


## Adds an Aisle run's tag (#108 follow-up) to its box `stamped` on the chip face (`chip`) or the
## card face: the RUN_MARK_SIZE "×" badge on its family's face colour at the box's top left,
## upright on the card's tilted stamp (polish pass: drawn turned, its texels went jagged). Other
## perks get none.
static func add_run_mark(stamped: PanelContainer, upgrade: UpgradeDefinition, chip: bool) -> void:
	var face: Color = run_mark_colour(upgrade)
	if face == Color():
		return
	var holder: Control = Control.new()
	holder.name = RUN_MARK_NAME
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamped.add_child(holder)
	var tag: Control = make_run_tag(face)
	if not chip:
		tag.pivot_offset = RUN_MARK_SIZE / 2.0
		tag.rotation = -deg_to_rad(STAMP_TILT)
	holder.add_child(tag)


## The colour of `upgrade`'s Aisle run tag: its family's face for an Aisle run with a family
## colour, else Color() (no tag).
static func run_mark_colour(upgrade: UpgradeDefinition) -> Color:
	var family: FamilyStyle = _family(upgrade)
	if family == null or upgrade.type != UpgradeDefinition.Type.AISLE_RUN:
		return Color()
	return family.face


## A RUN_MARK_SIZE Aisle run tag in `face`, at (0, 0): the loyalty box's and the planning
## sticker's loyalty badge's (GiverBadge). Its colour is its RUN_MARK_FACE meta, so a drained
## badge can repaint it grey (set_run_tag_face).
static func make_run_tag(face: Color) -> Control:
	var tag: Control = Control.new()
	tag.name = "Tag"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size = RUN_MARK_SIZE
	tag.position = Vector2.ZERO
	tag.set_meta(RUN_MARK_FACE, face)
	tag.draw.connect(func() -> void: _draw_run_mark(tag, tag.get_meta(RUN_MARK_FACE) as Color))
	return tag


## Repaints the run tag `tag` (make_run_tag) in `face`.
static func set_run_tag_face(tag: Control, face: Color) -> void:
	tag.set_meta(RUN_MARK_FACE, face)
	tag.queue_redraw()


## Draws the Aisle run tag on `tag`: ink, the family's `face` inside a one-texel edge, the ink
## cross over it.
static func _draw_run_mark(tag: Control, face: Color) -> void:
	var texel: Vector2 = Vector2.ONE * ArtStyle.ART_SCALE
	tag.draw_rect(Rect2(Vector2.ZERO, RUN_MARK_SIZE), Palette.INK)
	tag.draw_rect(Rect2(texel, RUN_MARK_SIZE - texel * 2.0), face)
	for cell: Vector2i in RUN_MARK_CROSS:
		tag.draw_rect(Rect2(Vector2(cell) * texel, texel), Palette.INK)


## The Aisle run tag on the box of upgrade `index` (null: none, another perk or no such box).
func run_mark(index: int) -> Control:
	var holder: Control = _part(index, RUN_MARK_NAME)
	return holder.get_child(0) as Control if holder != null else null


## Adds `upgrade`'s level badge to its box `stamped` (`box_size`), past LV 1 only: a holder over
## the whole box (the container fits it), the badge at the holder's bottom right. The box's first
## child stays its label (box_texts).
static func add_level_mark(
	stamped: PanelContainer, upgrade: UpgradeDefinition, box_size: Vector2
) -> void:
	if upgrade == null or upgrade.level_number() <= 1:
		return
	var holder: Control = Control.new()
	holder.name = LEVEL_MARK_NAME
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamped.add_child(holder)
	var text: String = str(upgrade.level_number())
	var chip: bool = box_size == CHIP_BOX_SIZE
	var font_size: int = CHIP_LEVEL_SIZE if chip else LEVEL_SIZE
	var pad: float = CHIP_LEVEL_PAD if chip else LEVEL_PAD
	var badge: Label = UiKit.display_label(text, font_size, false)
	badge.name = "Badge"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.MUSTARD_LIGHT
	style.border_color = Palette.INK
	style.set_border_width_all(LEVEL_BORDER)
	style.set_content_margin_all(0)
	badge.add_theme_stylebox_override("normal", style)
	var font: Font = ArtStyle.DISPLAY_FONT
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var side: Vector2 = Vector2(width + 2.0 * (pad + LEVEL_BORDER), font.get_height(font_size))
	side = (side / 2.0).ceil() * 2.0  # On the 2 px grid.
	badge.notification(Control.NOTIFICATION_THEME_CHANGED)
	badge.size = side
	badge.position = box_size - side
	if not chip:
		# Upright on the card's tilted stamp (polish pass: turned, its numeral went soft), moved in
		# by LEVEL_INSET so its turned corners stay inside the box.
		badge.position -= Vector2.ONE * LEVEL_INSET
		badge.pivot_offset = side / 2.0
		badge.rotation = -deg_to_rad(STAMP_TILT)
	holder.add_child(badge)


## The largest CHIP_INITIALS_SIZES size at which `text` fits inside the chip's rings (else the
## smallest). Measured with the number font itself: the new box is not in the tree yet, so its
## label ignores theme overrides and would report the default font's width at every size.
static func chip_initials_size(text: String) -> int:
	var inside: float = CHIP_BOX_SIZE.x - 2.0 * CHIP_RING
	var font: Font = ArtStyle.number_font()
	for font_size: int in CHIP_INITIALS_SIZES:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= inside:
			return font_size
	return CHIP_INITIALS_SIZES[-1]
