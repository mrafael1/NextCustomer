class_name CartDrawer
extends Control
## The CART drawer a NEW ITEMS, COUPONS or UPGRADES pick lands in (#77, look F; build spec 4.2),
## on the machine's stage layer, right edge ShiftStage.CART_DRAWER_RIGHT, top CART_DRAWER_TOP: a
## teal light drawer with "YOUR CART", a note ("+1 card", "full: swap 1 out", "same count") and
## the count chip "n/<deck_limit>" (balance.deck_limit, never a hard-coded 15), a line saying how
## many of the landing product the cart holds, one 100x122 slot per copy of it (its sprite and its
## PLAIN / BIG / GOLDEN band), and for a new card a dashed "NEW" slot it lands in. An upgrade's
## copies are ringed in gold and glint in 6 steps, one after another, then change in place; the
## stamp NEW IN CART ✓ or UPGRADED ✓ lands under the slots. It slides in before the prize's
## flight and out after the punch (no slide under reduced motion).
##
## It shows only view.landing (MachineLanding: the copy added, the copies upgraded, the cart's
## counts) and the run's cart; frame(t) reads view.plan's landing times.

const SIZE := Vector2.ZERO
## Look F's drawer: padding, header and sub line heights, slots, the least width.
const PAD_X := 10.0
const PAD_TOP := 8.0
const PAD_BOTTOM := 10.0
const HEADER_HEIGHT := 24.0
const SUB_HEIGHT := 16.0
const SLOTS_GAP := 6.0
const SLOT_SIZE := Vector2(100, 122)
const SLOT_GAP := 8.0
const SPRITE_SIZE := 96.0
const TAG_HEIGHT := 20.0
const MIN_WIDTH := 320.0
## The most slots shown (an upgrade's copies first): 4 make the drawer 448 wide, its left edge at
## x 300, clear of the stage receipt (x 46..282); a fifth would cover it.
const MAX_SLOTS := 4
const BORDER := 2.0
const INNER_RING := 3.0
const SHADOW := 6.0
const RING := 3.0
## The slide: 16 px over SLIDE seconds, in and out; the count chip glows CHIP_GLOW after the
## landing; the new slot pops from 1.3, a changed copy from 1.25, the stamp from 1.8.
const SLIDE_PX := 16.0
const SLIDE := 0.2
const CHIP_GLOW := 0.6
const NEW_POP := 1.3
const CHANGE_POP := 1.25
const STAMP_POP := 1.8
const POP := 0.25
const STAMP_DROP := 22.0
const STAMP_TILT_DEG := -5.0
## The glint: a paper bar GLINT_WIDTH wide, skewed, in GLINT_STEPS steps across GLINT_TRAVEL.
const GLINT_WIDTH := 14.0
const GLINT_SKEW := 6.0
const GLINT_STEPS := 6
const GLINT_TRAVEL := 82.0
const GLINT_ALPHA := 0.85
const TITLE_TEXT := "YOUR CART"
const NEW_TEXT := "NEW"
const NEW_STAMP := "NEW IN CART ✓"
const UP_STAMP := "UPGRADED ✓"
const TIER_TEXTS: Array[String] = ["PLAIN", "BIG", "GOLDEN"]
const CART_ICON := preload("res://art/icons/cart.png")
const ICON_SCALE := 2.0
const TITLE_SIZE := 12
const STAMP_SIZE := 24
const NOTE_SIZE := 11
const SUB_SIZE := 12
const CHIP_SIZE := 15
const TAG_SIZE := 10
const BOLD := 700
const BOLDER := 800

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
## The landing shown, whether it adds a card (else it upgrades copies), the cart's counts.
var landing: MachineLanding
var adds_card: bool = false
var count_label: Label
var note_label: Label
var sub_label: Label
var stamp_label: Label
## One per slot: {"node": Control, "from": CardDefinition, "to": CardDefinition or null,
## "step": the upgrade's order (-1: not upgraded), "new": bool, "sprite": TextureRect,
## "tag": Label}.
var slots: Array[Dictionary] = []
var _chip: PanelContainer
## The chip's paper and glowing styles, and the tier bands' (PLAIN, BIG, GOLDEN).
var _chip_styles: Array[StyleBoxFlat] = []
var _bands: Array[StyleBoxFlat] = []
var _content: Control
var _width: float = MIN_WIDTH
var _height: float = 0.0
var _t: float = 0.0


func _init() -> void:
	name = "CartDrawer"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_chip_styles = [
		_box(Palette.PAPER, Palette.INK, 2, 6), _box(Palette.MUSTARD_LIGHT, Palette.INK, 2, 6)
	]
	for band: Color in [Palette.CREAM, Palette.MUSTARD_LIGHT, Palette.GOLD]:
		var style: StyleBoxFlat = _box(band, Palette.INK, 0, 0)
		style.border_width_top = int(BORDER)
		_bands.append(style)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The drawer at `t` on view.plan: shown from the plan's drawer_in to its drawer_out (and the
## slide out) for a landing that adds or upgrades a card, its slots as they are at `t`.
func frame(t: float) -> void:
	_t = t
	var plan: MachinePlan = view.plan
	var shown: bool = (
		plan != null
		and plan.has_landing
		and view.landing != null
		and (
			plan.landing == MachinePlan.Landing.NEW_CARD
			or plan.landing == MachinePlan.Landing.UPGRADE
		)
	)
	if not shown:
		visible = false
		return
	if view.landing != landing:
		_build(view.landing)
	var rm: bool = plan.reduced_motion
	var out_end: float = plan.drawer_out + (0.0 if rm else SLIDE)
	visible = t >= plan.drawer_in and t < out_end
	if not visible:
		return
	var slide_in: float = 1.0 if rm else _seg(t, plan.drawer_in, plan.drawer_in + SLIDE)
	var slide_out: float = 0.0 if rm else _seg(t, plan.drawer_out, plan.drawer_out + SLIDE)
	position = Vector2(
		ShiftStage.CART_DRAWER_RIGHT - _width,
		ShiftStage.CART_DRAWER_TOP - roundf(SLIDE_PX * (1.0 - slide_in) + SLIDE_PX * slide_out)
	)
	modulate.a = slide_in * (1.0 - slide_out)
	if adds_card:
		_frame_new(t, plan)
	else:
		_frame_upgrade(t, plan)
	var stamp_at: float = plan.land
	if not adds_card:
		stamp_at = plan.glint_end - (0.0 if rm else MachineTuning.sec(view.tuning.glint_tail_ms))
	stamp_label.visible = t >= stamp_at
	var pop: float = 1.0 if rm else _ease_out(_seg(t, stamp_at, stamp_at + SLIDE))
	stamp_label.scale = Vector2.ONE * lerpf(STAMP_POP, 1.0, pop)
	queue_redraw()


## The flight's target in stage coordinates: the new slot's centre, or the first upgraded copy's.
func dest() -> Vector2:
	var index: int = 0
	for slot_index: int in range(slots.size()):
		var slot: Dictionary = slots[slot_index]
		if bool(slot["new"]) or int(slot["step"]) == 0:
			index = slot_index
			break
	var centre: Vector2 = _slot_position(index) + SLOT_SIZE / 2.0
	return Vector2(ShiftStage.CART_DRAWER_RIGHT - _width, ShiftStage.CART_DRAWER_TOP) + centre


## The drawer's rect in stage coordinates where it rests (no slide).
func rest_rect() -> Rect2:
	return Rect2(
		Vector2(ShiftStage.CART_DRAWER_RIGHT - _width, ShiftStage.CART_DRAWER_TOP),
		Vector2(_width, _height)
	)


func _build(shown: MachineLanding) -> void:
	landing = shown
	slots = []
	if _content != null:
		remove_child(_content)
		_content.queue_free()
	_content = Control.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	adds_card = landing.added != null
	var product: CardDefinition = _product()
	var copies: Array[Dictionary] = _copies(product)
	var count: int = copies.size() + (1 if adds_card else 0)
	_width = maxf(MIN_WIDTH, count * (SLOT_SIZE.x + SLOT_GAP) - SLOT_GAP + 2.0 * (PAD_X + BORDER))
	_height = (
		BORDER
		+ PAD_TOP
		+ HEADER_HEIGHT
		+ SUB_HEIGHT
		+ SLOTS_GAP
		+ SLOT_SIZE.y
		+ PAD_BOTTOM
		+ BORDER
	)
	size = Vector2(_width, _height)
	_build_header(product, copies.size())
	for copy: Dictionary in copies:
		_add_slot(copy)
	if adds_card:
		_add_slot({"from": landing.added.definition, "to": null, "step": -1, "new": true})
	stamp_label = _stamp(NEW_STAMP if adds_card else UP_STAMP)


func _build_header(product: CardDefinition, owned: int) -> void:
	var icon: TextureRect = UiKit.sprite(CART_ICON)
	icon.size = Vector2(CART_ICON.get_size()) * ICON_SCALE
	icon.position = Vector2(BORDER + PAD_X, BORDER + PAD_TOP + (HEADER_HEIGHT - icon.size.y) / 2.0)
	_content.add_child(icon)
	var title: Label = UiKit.display_label(TITLE_TEXT, TITLE_SIZE, false)
	title.name = "Title"
	title.position = Vector2(icon.position.x + icon.size.x + 8.0, BORDER + PAD_TOP + 4.0)
	_content.add_child(title)
	note_label = _body("", NOTE_SIZE, Palette.TEAL_SHADE, BOLD)
	note_label.name = "Note"
	note_label.position = Vector2(title.position.x + 84.0, BORDER + PAD_TOP + 5.0)
	_content.add_child(note_label)
	_chip = PanelContainer.new()
	_chip.name = "Count"
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_theme_stylebox_override("panel", _chip_styles[0])
	count_label = _body(_count_text(landing.cart_before), CHIP_SIZE, Palette.INK, BOLDER)
	_chip.add_child(count_label)
	_content.add_child(_chip)
	_chip.size = _chip.get_combined_minimum_size()
	_chip.position = Vector2(_width - BORDER - PAD_X - _chip.size.x, BORDER + PAD_TOP)
	var sub_text: String = "No %s in your cart yet" % product.display_name
	if owned > 0:
		sub_text = "%s: you own %d" % [product.display_name, owned]
	sub_label = _body(sub_text, SUB_SIZE, Palette.TEAL_SHADE, BOLD)
	sub_label.name = "Sub"
	sub_label.position = Vector2(BORDER + PAD_X, BORDER + PAD_TOP + HEADER_HEIGHT - 2.0)
	_content.add_child(sub_label)


## The product the landing is about: the copy added, or the first upgraded copy's.
func _product() -> CardDefinition:
	if landing.added != null:
		return landing.added.definition.product_card()
	var pair: Array = landing.upgraded[0] if not landing.upgraded.is_empty() else []
	if pair.size() == 2:
		return (pair[1] as CardInstance).definition.product_card()
	return landing.prize.card.product_card()


## The cart's copies of `product` before the landing (the copy added left out), each with what
## it becomes when the pick upgrades it; an upgrade's copies first when they don't all fit.
func _copies(product: CardDefinition) -> Array[Dictionary]:
	var steps: Dictionary[int, int] = {}
	var befores: Dictionary[int, CardDefinition] = {}
	for index: int in range(landing.upgraded.size()):
		var pair: Array = landing.upgraded[index]
		steps[(pair[1] as CardInstance).instance_id] = index
		befores[(pair[1] as CardInstance).instance_id] = (pair[0] as CardInstance).definition
	var found: Array[Dictionary] = []
	for card: CardInstance in view.run.deck.cards:
		if card == landing.added or not card.definition.is_same_product(product):
			continue
		var step: int = steps.get(card.instance_id, -1)
		var from: CardDefinition = befores.get(card.instance_id, card.definition)
		var to: CardDefinition = card.definition if step >= 0 else null
		found.append({"from": from, "to": to, "step": step, "new": false})
	var room: int = MAX_SLOTS - (1 if landing.added != null else 0)
	while found.size() > room:
		found.remove_at(_trimmed(found))
	return found


## The copy to leave out when they don't all fit: the last one not upgraded, else the one
## upgraded last (the first upgraded copy, step 0, always stays: the flight lands on it).
static func _trimmed(found: Array[Dictionary]) -> int:
	var drop: int = -1
	for index: int in range(found.size() - 1, -1, -1):
		var step: int = int(found[index]["step"])
		if step < 0:
			return index
		if drop < 0 or step > int(found[drop]["step"]):
			drop = index
	return drop


func _add_slot(slot: Dictionary) -> void:
	var node: Control = Control.new()
	node.name = "Slot%d" % slots.size()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size = SLOT_SIZE
	node.position = _slot_position(slots.size())
	node.pivot_offset = SLOT_SIZE / 2.0
	_content.add_child(node)
	var sprite: TextureRect = UiKit.sprite(ArtStyle.item_sprite(slot["from"] as CardDefinition))
	sprite.size = Vector2(SPRITE_SIZE, SPRITE_SIZE)
	sprite.position = Vector2(BORDER, BORDER)
	node.add_child(sprite)
	var tag: Label = _body("", TAG_SIZE, Palette.INK, BOLDER)
	tag.name = "Tag"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	RewardMachineView.fit(tag, Rect2(0.0, SLOT_SIZE.y - TAG_HEIGHT, SLOT_SIZE.x, TAG_HEIGHT))
	node.add_child(tag)
	slot["node"] = node
	slot["sprite"] = sprite
	slot["tag"] = tag
	_show_tier(slot, slot["from"] as CardDefinition)
	if bool(slot["new"]):
		var label: Label = UiKit.display_label(NEW_TEXT, TITLE_SIZE, false)
		label.name = "Placeholder"
		label.add_theme_color_override("font_color", Palette.TEAL_SHADE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		RewardMachineView.fit(label, Rect2(0.0, 40.0, SLOT_SIZE.x, 20.0))
		node.add_child(label)
	node.draw.connect(_draw_slot.bind(slots.size()))
	slots.append(slot)


func _show_tier(slot: Dictionary, definition: CardDefinition) -> void:
	(slot["sprite"] as TextureRect).texture = ArtStyle.item_sprite(definition)
	var tag: Label = slot["tag"] as Label
	tag.text = TIER_TEXTS[definition.tier]
	tag.add_theme_stylebox_override("normal", _bands[definition.tier])


func _frame_new(t: float, plan: MachinePlan) -> void:
	var landed: bool = t >= plan.land
	var slot: Dictionary = slots[-1]
	var node: Control = slot["node"] as Control
	(slot["sprite"] as Control).visible = landed
	(slot["tag"] as Control).visible = landed
	(node.get_node("Placeholder") as Control).visible = not landed
	var pop: float = 1.0 if plan.reduced_motion else _ease_out(_seg(t, plan.land, plan.land + POP))
	node.scale = Vector2.ONE * (lerpf(NEW_POP, 1.0, pop) if landed else 1.0)
	node.queue_redraw()
	count_label.text = _count_text(landing.cart_after if landed else landing.cart_before)
	note_label.text = ""
	if landed:
		note_label.text = "full: swap 1 out" if landing.replaced != null else "+1 card"
	var glow: bool = landed and t < plan.land + CHIP_GLOW
	_chip.add_theme_stylebox_override("panel", _chip_styles[1 if glow else 0])


func _frame_upgrade(t: float, plan: MachinePlan) -> void:
	var step: float = 0.0 if plan.reduced_motion else MachineTuning.sec(view.tuning.glint_copy_ms)
	for slot: Dictionary in slots:
		var order: int = int(slot["step"])
		var node: Control = slot["node"] as Control
		node.queue_redraw()
		if order < 0:
			continue
		var change: float = plan.glint + order * step
		var done: bool = t >= change
		_show_tier(slot, (slot["to"] if done else slot["from"]) as CardDefinition)
		var pop: float = 1.0 if plan.reduced_motion else _ease_out(_seg(t, change, change + SLIDE))
		node.scale = Vector2.ONE * (lerpf(CHANGE_POP, 1.0, pop) if done else 1.0)
	count_label.text = _count_text(landing.cart_before)
	note_label.text = "same count" if t >= plan.land else ""


## Where the glint of the copy upgraded `order`-th is at `t`: 0..1 while it runs, else -1.
func glint_progress(order: int, t: float) -> float:
	var plan: MachinePlan = view.plan
	if plan == null or plan.reduced_motion or order < 0:
		return -1.0
	var step: float = MachineTuning.sec(view.tuning.glint_copy_ms)
	var start: float = plan.land + order * step
	var end: float = plan.glint + order * step
	var progress: float = _seg(t, start, end)
	return progress if progress > 0.0 and progress < 1.0 else -1.0


func _draw() -> void:
	if landing == null:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(Vector2(SHADOW, SHADOW), size), Palette.TEAL_BLACK)
	draw_rect(rect, Palette.TEAL_LIGHT)
	draw_rect(rect.grow(-BORDER - INNER_RING / 2.0), Palette.TEAL_PALE, false, INNER_RING)
	draw_rect(rect.grow(-BORDER / 2.0), Palette.INK, false, BORDER)


func _draw_slot(index: int) -> void:
	var slot: Dictionary = slots[index]
	var node: Control = slot["node"] as Control
	var rect: Rect2 = Rect2(Vector2.ZERO, SLOT_SIZE)
	if bool(slot["new"]) and not (slot["sprite"] as Control).visible:
		_dashed_rect(node, rect.grow(-BORDER / 2.0), Palette.TEAL_SHADE)
		return
	node.draw_rect(rect, Palette.PAPER)
	var target: bool = int(slot["step"]) >= 0
	if target:
		node.draw_rect(rect.grow(RING / 2.0 + BORDER / 2.0), Palette.GOLD, false, RING)
	var border: Color = Palette.MUSTARD_DARKEST if target else Palette.INK
	node.draw_rect(rect.grow(-BORDER / 2.0), border, false, BORDER)
	var glint: float = glint_progress(int(slot["step"]), _t)
	if glint >= 0.0:
		var x: float = roundf(floorf(glint * GLINT_STEPS) / GLINT_STEPS * GLINT_TRAVEL)
		var colour: Color = Palette.PAPER
		colour.a = GLINT_ALPHA
		var points: PackedVector2Array = PackedVector2Array(
			[
				Vector2(x + GLINT_SKEW, 0.0),
				Vector2(x + GLINT_SKEW + GLINT_WIDTH, 0.0),
				Vector2(x + GLINT_WIDTH, SPRITE_SIZE),
				Vector2(x, SPRITE_SIZE),
			]
		)
		node.draw_colored_polygon(points, colour)


func _stamp(text: String) -> Label:
	var label: Label = UiKit.display_label(text, STAMP_SIZE, false)
	label.name = "Stamp"
	# Pixelify has no ✓: the display's marked font draws it from the mono font behind it.
	label.add_theme_font_override("font", MachineDisplay.marked_font(0))
	var colour: Color = Palette.TEAL_SHADE if adds_card else Palette.MUSTARD_DARKEST
	label.add_theme_color_override("font_color", colour)
	label.add_theme_stylebox_override("normal", _box(Palette.PAPER, colour, 3, 10))
	_content.add_child(label)
	label.size = label.get_combined_minimum_size()
	label.position = Vector2((_width - label.size.x) / 2.0, _height - label.size.y + STAMP_DROP)
	label.pivot_offset = label.size / 2.0
	label.rotation = deg_to_rad(STAMP_TILT_DEG)
	label.visible = false
	return label


func _slot_position(index: int) -> Vector2:
	return Vector2(
		BORDER + PAD_X + index * (SLOT_SIZE.x + SLOT_GAP),
		BORDER + PAD_TOP + HEADER_HEIGHT + SUB_HEIGHT + SLOTS_GAP
	)


func _count_text(count: int) -> String:
	return "%d/%d" % [count, view.run.balance.deck_limit]


static func _dashed_rect(node: Control, rect: Rect2, colour: Color) -> void:
	var corners: PackedVector2Array = PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
	for index: int in range(4):
		node.draw_dashed_line(corners[index], corners[(index + 1) % 4], colour, BORDER, 6.0)


static func _body(text: String, font_size: int, colour: Color, weight: int) -> Label:
	var label: Label = UiKit.body_label(text, font_size, colour)
	label.add_theme_font_override("font", ArtStyle.bold_font(weight))
	return label


static func _box(fill: Color, border: Color, width: int, pad: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = pad
	style.content_margin_right = pad
	return style


static func _seg(t: float, from: float, to: float) -> float:
	if to <= from:
		return 1.0 if t >= from else 0.0
	return clampf((t - from) / (to - from), 0.0, 1.0)


static func _ease_out(p: float) -> float:
	return 1.0 - (1.0 - p) * (1.0 - p)
