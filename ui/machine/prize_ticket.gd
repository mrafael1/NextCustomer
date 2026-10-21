class_name PrizeTicket
extends Control
## One prize in its cell on the machine's tray (#77, look F; build spec 4.2): cell i holds reveal
## i. It arrives as its box (BoxLane hands it over at the box's gate) and opens at its reveal: the
## tape splits, the flaps go half up, then open, and the card flips from the box to its front.
##
## Its front is a tray item (ItemView, Form.TRAY) for a product or coupon, with a NEW tag when the
## product is one of the stock's new arrivals; a stamp ticket (the stamp ring, "STAMP · <initials>",
## the register's name) for a register; for an item upgrade the item at its new tier with its
## BIG/GOLDEN tag (a SHELF upgrade's "SHELF ×n", as look F), an up arrow, look F's name line
## ("Milk +1 step", "Milk › GOLDEN", "Shelf upgrade") and what the pick does
## (RewardMachine.preview: "1 copy: BIG › GOLDEN", "1 plain copy, 2 steps", "SHELF ×n · every
## Milk +1 step"). Over it its rarity tab
## (RarityTab: COMMON / RARE! / LEGENDARY!!) and, once open, its pips (● / ◆◆ / ★★★, drawn shapes);
## behind it nothing (COMMON), the sticker burst (RARE, with a teal inner ring) or the gold
## sunburst and sparkles (LEGENDARY, with a gold ring and a little hop), so a rarity never shows by
## colour alone; each rarity's reveal also lasts longer (the plan's reveal_length) and has its own
## sounds (MachineSounds.reveal_sounds plays them). Under reduced motion the box opens without
## the flip, shake or hop, the sunburst stands still and the sparkles hold one frame.
## The shapes behind (burst, sunburst, sparkles) sit in the machine's ticket_fx layer, under
## every ticket and clipped to the tray, clear of the RESTOCK hood.
##
## Hovering the revealed ticket shows its hover card (the register's ticket fields,
## UpgradeTicket.field_texts; the item's sticker line and rule, with the fields an upgrade changes,
## CardText.changed_fields, highlighted). A click picks it once the machine has armed. After the
## pick the picked ticket lifts and flies off (the flyer takes it), and a bin drops every ticket.
## frame(t) reads only view.plan, t, view.landing and view.idle_time.

signal clicked(index: int)

const SIZE := ItemView.TRAY_SIZE
const RARITY_TEXTS: Array[String] = RarityTab.TEXTS
const PIPS: Array[String] = ["●", "◆◆", "★★★"]
const TIER_WORDS: Array[String] = ["PLAIN", "BIG", "GOLDEN"]
## Each rarity's shape behind the ticket (none, the sticker burst, the sunburst and sparkles).
const SHAPES: Array[String] = ["", "Burst", "Sunburst"]
const NEW_RECT := Rect2(2, 2, 40, 18)
const NOTE_RECT := Rect2(0, 104, 108, 64)
const STICKER_RECT := Rect2(0, 104, 108, 64)
const BAND_HEIGHT := 18.0
const NAME_HEIGHT := 13.0
const TAG_SIZE := 12
const NOTE_SIZE := 10
const BOLD_WEIGHT := 800
## The upgrade's tier tag (look F: Pixelify, tilted, at the sprite's foot) and up arrow.
const TIER_TAG_AT := Vector2(0, 80)
const TIER_TAG_TILT := -6.0
const UP_ARROW := preload("res://art/icons/up_arrow.png")
const UP_ARROW_RECT := Rect2(86, 24, 18, 18)
const STAMP_RING := preload("res://art/icons/stamp_ring.png")
const STAMP_RING_RECT := Rect2(15, 12, 78, 78)
## The box's lid frames (66 x 100 art px, the box at 6,16): tape split, flaps half up, open.
const LIDS: Array[Texture2D] = [
	preload("res://art/machine/box_lid_0.png"),
	preload("res://art/machine/box_lid_1.png"),
	preload("res://art/machine/box_lid_2.png"),
]
const LIDS_STAMP_DAY: Array[Texture2D] = [
	preload("res://art/machine/box_lid_stamp_day_0.png"),
	preload("res://art/machine/box_lid_stamp_day_1.png"),
	preload("res://art/machine/box_lid_stamp_day_2.png"),
]
const LID_RECT := Rect2(-12, -32, 132, 200)
## The RARE burst (31 x 17 art px at 6x) and the LEGENDARY sunburst (Sunburst, scaled so its met
## radius is SUN_RADIUS px), centred on the sprite; the six sparkles (5 x 5 art px at 4x).
const BURST := preload("res://art/effects/sticker_burst.png")
const BURST_SCALE := 6.0
const SPARKLE := preload("res://art/effects/sparkle.png")
const SPARKLE_SIZE := Vector2(20, 20)
const SPARKLE_AT: Array[Vector2] = [
	Vector2(-18, 6),
	Vector2(100, -6),
	Vector2(112, 70),
	Vector2(-22, 92),
	Vector2(40, -30),
	Vector2(84, 120)
]
const FX_CENTRE := Vector2(54, 52)
const SUN_RECT := 288.0
const SUN_RADIUS := 88.0
## The reveal (look F, unchanged from the page): the card opens between OPEN_FROM[r] and
## OPEN_TO[r] of the reveal (reduced motion: at OPEN_RM), shaking before; the lid's tape splits
## until LID_SPLIT x OPEN_FROM, the flaps are half up until LID_HALF x OPEN_FROM (COMMON: half up
## until LID_COMMON_HALF).
const OPEN_FROM: Array[float] = [0.0, 0.2, 0.35]
const OPEN_TO: Array[float] = [0.6, 0.5, 0.55]
const OPEN_RM := 0.3
const LID_SPLIT := 0.45
const LID_HALF := 0.8
const LID_COMMON_HALF := 0.08
const SHAKE_RATE := 30.0
## The landing bump (BUMP px over BUMP_S), the LEGENDARY hop (HOP px between HOP_FROM and HOP_TO
## of its reveal), the RARE burst's pop (BURST_FROM .. BURST_TO, from BURST_START to BURST_OVER),
## the sunburst's growth, the sparkles (from SPARKLE_FROM, blinking SPARKLE_RATE a second).
const BUMP := 8.0
const BUMP_S := 0.25
const HOP := 6.0
const HOP_FROM := 0.55
const HOP_TO := 0.7
const BURST_FROM := 0.45
const BURST_TO := 0.62
const BURST_START := 0.2
const BURST_OVER := 1.15
const SUN_GROW_TO := 0.35
const SUN_FULL := 0.2
const SPARKLE_FROM := 0.6
const SPARKLE_RATE := 4.0
const SPARKLE_PHASE := 1.7
## The pick: the ticket lifts PICK_LIFT px from the press until it flies; a bin drops the tickets
## BIN_DROP px over BIN_S as they fade.
const PICK_LIFT := 10.0
const BIN_DROP := 24.0
const BIN_S := 0.35
## The tray's inner x range in machine px, from its left rail to the RESTOCK hood: a rarity tab
## and the hover card stay inside it, clear of the hood.
const TRAY_LEFT := 12.0
const TRAY_RIGHT := 396.0
const TAB_GAP := 4.0
const TAB_MARGIN := 4.0
## The least gap between two neighbouring tabs' tilted bounds.
const TAB_SPACING := 4.0
## The pips (5 x 5 art px at 2 px each, 2 px apart) at the face's top right, and their grids.
const PIP_GRIDS: Array[String] = [
	".XXX.XXXXXXXXXXXXXXX.XXX.", "..X...XXX.XXXXX.XXX...X..", "..X..XXXXX.XXX..X.X.X...X"
]
const PIP_PIXEL := 2.0
const PIP_GAP := 2.0
const PIP_TOP := 6.0
const PIP_RIGHT := 6.0
const HOVER_WIDTH := 220.0
const HOVER_GAP := 36.0
const HOVER_TITLE_SIZE := 12
const HOVER_TEXT_SIZE := 12

var index: int = 0
var prize: MachinePrize
## The tray item (a product or coupon prize, or an upgrade's item), or null.
var item: ItemView
## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
## The rarity tab over the ticket.
var tab: RarityTab
var _preview: MachinePreview
var _cell: int = 0
var _stamp_day: bool = false
var _card: Control
var _face: Control
var _back: Control
var _fx: Control
var _burst: TextureRect
var _sun: Sunburst
var _sparkles: Array[TextureRect] = []
var _pips: Control
var _note: Label
var _note_name: Label
var _lid: int = -1
var _open: float = 1.0
var _hover_card: PanelContainer
var _hovers: Dictionary[StringName, bool] = {}


func _init(
	cell_index: int, ticket_prize: MachinePrize, preview: MachinePreview, run: RunState
) -> void:
	index = cell_index
	prize = ticket_prize
	_preview = preview
	name = "PrizeTicket%d" % cell_index
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hover.bind(&"ticket", true))
	mouse_exited.connect(_set_hover.bind(&"ticket", false))
	_fx = _layer("Fx", self)
	_card = _layer("Card", self)
	_card.pivot_offset = SIZE / 2.0
	_face = _layer("Face", _card)
	_back = _layer("Back", _card)
	ArtStyle.use_pixel_material(_back)
	_back.draw.connect(_draw_back)
	match prize.kind:
		MachinePrize.Kind.PRODUCT, MachinePrize.Kind.COUPON:
			_add_item(prize.card, run)
			if run.stock.new_arrivals.has(prize.card):
				_add_new_tag()
		MachinePrize.Kind.REGISTER:
			_add_stamp_face()
		MachinePrize.Kind.UPGRADE:
			var shown: CardDefinition = _upgraded_card()
			_add_item(shown, run)
			item.sticker().visible = false
			_add_tier_tag(shown, _shelf_text())
			var arrow: TextureRect = UiKit.sprite(UP_ARROW)
			arrow.name = "UpArrow"
			arrow.position = UP_ARROW_RECT.position
			arrow.size = UP_ARROW_RECT.size
			_face.add_child(arrow)
			_add_note("UPGRADE", upgrade_text(prize, preview), Palette.GOLD, upgrade_name(prize))
	tooltip_text = ""
	var ring: Control = _layer("Ring", _face)
	ring.draw.connect(_draw_ring.bind(ring))
	_pips = _layer("Pips", _face)
	_pips.draw.connect(_draw_pips)
	_add_shapes()
	tab = RarityTab.new(prize.rarity, index)
	add_child(tab)


## What an UPGRADES pick does, from the machine's preview: one copy one step ("1 copy: BIG ›
## GOLDEN"), a plain copy straight to GOLDEN, or every copy (SHELF).
static func upgrade_text(upgrade_prize: MachinePrize, preview: MachinePreview) -> String:
	if preview == null or preview.targets.is_empty():
		return ""
	var from_tier: int = preview.targets[0].definition.tier
	var to_tier: int = preview.to_cards[0].tier
	match upgrade_prize.rarity:
		MachinePrize.Rarity.RARE:
			return "1 plain copy, 2 steps"
		MachinePrize.Rarity.LEGENDARY:
			return (
				"SHELF ×%d · every %s +1 step" % [preview.copies, upgrade_prize.card.display_name]
			)
	return "1 copy: %s › %s" % [TIER_WORDS[from_tier], TIER_WORDS[to_tier]]


## Look F's name line of an UPGRADES ticket: which item it improves and how ("Milk +1 step",
## "Milk › GOLDEN", "Shelf upgrade").
static func upgrade_name(upgrade_prize: MachinePrize) -> String:
	var item_name: String = upgrade_prize.card.display_name
	match upgrade_prize.rarity:
		MachinePrize.Rarity.RARE:
			return "%s › GOLDEN" % item_name
		MachinePrize.Rarity.LEGENDARY:
			return "Shelf upgrade"
	return "%s +1 step" % item_name


## Hooks this part to the machine: RewardMachineView calls it once, after placing it in its cell
## and before adding it (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine
	tab.setup(machine)
	var found: int = MachinePlan.CELL_X.find(position.x)
	_cell = found if found >= 0 else clampi(index, 0, MachinePlan.MAX_PRIZES - 1)
	_stamp_day = view.plan != null and view.plan.kind == MachineVisit.Kind.STAMP_DAY
	if view.ticket_fx != null and _fx.get_parent() == self:
		# Behind every ticket and clipped to the tray, clear of the hood (build spec 4.2).
		remove_child(_fx)
		view.ticket_fx.add_child(_fx)
		_fx.name = "Fx%d" % index
	if _sun != null:
		_sun.reduced_motion = func() -> bool: return view.plan != null and view.plan.reduced_motion
	var rarities: Array[int] = [prize.rarity]
	var at: int = 0
	if view.plan != null and view.plan.has_draw and index < view.plan.n_prizes:
		rarities = view.plan.rarities
		at = index
	var compact: bool = tabs_compact(rarities)
	tab.set_compact(compact)
	var row: Array[float] = tab_row(rarities, compact, position.x - MachinePlan.CELL_X[_cell])
	# The row holds the tilted bounds; the tab's rest rect is centred in its bounds.
	var bounds: Vector2 = tab.tilted_size()
	var x: float = row[at] + (bounds.x - tab.size.x) / 2.0 - position.x
	var y: float = -TAB_GAP - (bounds.y + tab.size.y) / 2.0
	tab.place(Vector2(StockroomWindow.snap(x), StockroomWindow.snap(y)))


## Whether a draw of `rarities` needs compact tabs: its full-size tabs' tilted bounds don't fit
## side by side between the tray's left rail and the RESTOCK hood.
static func tabs_compact(rarities: Array[int]) -> bool:
	var width: float = TAB_SPACING * maxf(0.0, rarities.size() - 1.0)
	for rarity: int in rarities:
		width += RarityTab.bounds_of(rarity, false).x
	return width > TRAY_RIGHT - TRAY_LEFT - 2.0 * TAB_MARGIN


## The left x (machine px) of each prize's tab's tilted bounds in a draw of `rarities`: each
## centred over its ticket (look F), then pushed left of its right neighbour and the hood, then
## right of its left neighbour and the tray's left rail, so no two tabs overlap. `shift` moves
## the cells (a ticket placed off its cell).
static func tab_row(rarities: Array[int], compact: bool, shift: float = 0.0) -> Array[float]:
	var count: int = rarities.size()
	var widths: Array[float] = []
	var xs: Array[float] = []
	for slot: int in range(count):
		var width: float = RarityTab.bounds_of(rarities[slot], compact).x
		var cell: float = MachinePlan.CELL_X[MachinePlan.cell_of(slot, count)] + shift
		widths.append(width)
		xs.append(cell + (SIZE.x - width) / 2.0)
	var limit: float = TRAY_RIGHT - TAB_MARGIN
	for slot: int in range(count - 1, -1, -1):
		xs[slot] = minf(xs[slot], limit - widths[slot])
		limit = xs[slot] - TAB_SPACING
	limit = TRAY_LEFT + TAB_MARGIN
	for slot: int in range(count):
		xs[slot] = maxf(xs[slot], limit)
		limit = xs[slot] + widths[slot] + TAB_SPACING
	return xs


## Shows the ticket at time `t` (seconds) of view.plan: hidden until its box meets its gate, then
## the box, its reveal, the open front; after the pick, the lift or the bin's drop.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	if plan == null or not plan.has_draw or index >= plan.n_prizes:
		_show_open()
		return
	var rm: bool = plan.reduced_motion
	var tier: int = clampi(prize.rarity, 0, OPEN_FROM.size() - 1)
	var arrived: float = plan.run_to[index]
	visible = t >= arrived
	var offset: Vector2 = Vector2.ZERO
	if not rm:
		var bump: float = StockroomWindow.seg(t, arrived, arrived + BUMP_S)
		if bump > 0.0 and bump < 1.0:
			offset.y = -roundf(sin(bump * PI) * BUMP)
	var p: float = plan.reveal_progress(index, t)
	_open = _open_at(p, tier, rm)
	var squeeze: float = 1.0
	if not rm:
		if p > 0.0 and p < OPEN_FROM[tier]:
			var a: float = p / OPEN_FROM[tier]
			var side: float = 1.0 if int(floorf(t * SHAKE_RATE)) % 2 == 1 else -1.0
			offset.x = side * (ceilf(a * 3.0) if tier == MachinePrize.Rarity.LEGENDARY else 1.0)
		squeeze = 1.0 - _open * 2.0 if _open < 0.5 else _open * 2.0 - 1.0
		if _open >= 1.0:
			squeeze = 1.0
		if tier == MachinePrize.Rarity.LEGENDARY and p > HOP_FROM and p < HOP_TO:
			offset.y -= roundf(sin((p - HOP_FROM) / (HOP_TO - HOP_FROM) * PI) * HOP)
	_back.visible = _open < 0.5
	_face.visible = not _back.visible
	var lid: int = _lid_at(p, tier, rm)
	if lid != _lid:
		_lid = lid
		_back.queue_redraw()
	_pips.visible = _open >= 1.0
	_frame_shapes(p, rm)
	var alpha: float = 1.0
	if plan.has_landing and t >= plan.press:
		if _picked():
			offset.y -= PICK_LIFT
			if t >= plan.fly_out:
				alpha = 0.0
		elif plan.landing == MachinePlan.Landing.BIN:
			var drop: float = StockroomWindow.seg(t, plan.press, plan.press + BIN_S)
			alpha = 0.0 if rm else 1.0 - drop
			offset.y += roundf(drop * BIN_DROP)
	_card.position = offset.snapped(Vector2(1, 1))
	_card.scale = Vector2(maxf(0.02, squeeze), 1.0)
	# The bump, hop, lift and drop move the whole ticket (look F moves its .tk): the tab, the
	# shape behind and the sparkles too; the shake and the squeeze stay on the card.
	var rise: Vector2 = Vector2(0, _card.position.y)
	_place_fx(rise, alpha)
	tab.frame(t)
	tab.position += rise
	modulate.a = alpha
	_place_hover()


## The rarity tab's text and the pips, for tests.
func rarity_texts() -> PackedStringArray:
	return PackedStringArray([tab.text(), PIPS[prize.rarity]])


## The rarity's shape behind the ticket ("" none, "Burst", "Sunburst"), for tests.
func shape_name() -> String:
	return SHAPES[prize.rarity]


## The shape behind the ticket (the burst, the sunburst), or null for a COMMON.
func shape() -> Control:
	if _burst != null:
		return _burst
	return _sun


## The LEGENDARY sparkles (empty otherwise).
func sparkles() -> Array[TextureRect]:
	return _sparkles.duplicate()


## How far the ticket is open (0 the box .. 1 its front), and the lid frame shown (-1 none).
func open_amount() -> float:
	return _open


func lid_frame() -> int:
	return _lid if _back.visible else -1


## Whether the box (the back) or the front shows.
func shows_box() -> bool:
	return _back.visible


## The pips' text (● / ◆◆ / ★★★) when they show, else "".
func pips_text() -> String:
	return PIPS[prize.rarity] if _pips.visible and _face.visible else ""


## The upgrade's or register's note ("" for a tray item), for tests.
func note_text() -> String:
	return _note.text if _note != null else ""


## An upgrade note's name line ("Milk +1 step"; "" otherwise), and its tier tag's text, for tests.
func note_name() -> String:
	return _note_name.text if _note_name != null else ""


func tier_tag_text() -> String:
	var tag: Label = _face.get_node_or_null("TierTag") as Label
	return tag.text if tag != null else ""


## The fields an UPGRADES pick changes on its item (CardText.changed_fields from the copy now
## to its new tier), highlighted on the hover card; empty for other prizes.
func highlighted_fields() -> PackedStringArray:
	if prize.kind != MachinePrize.Kind.UPGRADE or _preview == null or _preview.targets.is_empty():
		return PackedStringArray()
	return CardText.changed_fields(_preview.targets[0].definition, _upgraded_card())


## The hover card (built on first use): shown while the revealed ticket is hovered.
func hover_card() -> PanelContainer:
	if _hover_card == null:
		_build_hover_card()
	return _hover_card


## Shows or hides the hover card as a hover would (it shows only once the ticket is open).
func show_hover(shown: bool) -> void:
	_set_hover(&"ticket", shown)


## The hover card's lines, for tests.
func hover_texts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for child: Node in hover_card().get_child(0).get_children():
		var label: Label = child as Label
		var rich: RichTextLabel = child as RichTextLabel
		if label != null:
			found.append(label.text)
		elif rich != null:
			found.append(rich.get_parsed_text())
	return found


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(index)


static func _open_at(p: float, tier: int, rm: bool) -> float:
	if p == MachinePlan.NOT_SET or p < 0.0:
		return 0.0
	if rm:
		return 1.0 if p >= OPEN_RM else 0.0
	return clampf((p - OPEN_FROM[tier]) / (OPEN_TO[tier] - OPEN_FROM[tier]), 0.0, 1.0)


static func _lid_at(p: float, tier: int, rm: bool) -> int:
	if p == MachinePlan.NOT_SET or p < 0.0:
		return -1
	if rm:
		return 2
	if tier == MachinePrize.Rarity.COMMON:
		return 1 if p < LID_COMMON_HALF else 2
	var opens: float = OPEN_FROM[tier]
	if p < opens * LID_SPLIT:
		return 0
	return 1 if p < opens * LID_HALF else 2


func _show_open() -> void:
	visible = true
	_open = 1.0
	_back.visible = false
	_face.visible = true
	_pips.visible = true
	_place_fx(Vector2.ZERO, 1.0)


## The shapes behind the ticket (in the machine's clipped ticket_fx layer once set up) follow
## the ticket: its cell, `rise`, its visibility and `alpha`.
func _place_fx(rise: Vector2, alpha: float) -> void:
	var origin: Vector2 = Vector2.ZERO
	if _fx.get_parent() != self and view != null:
		origin = position - view.ticket_fx.position
	_fx.position = origin + rise
	_fx.visible = visible
	_fx.modulate.a = alpha


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_fx) and _fx.get_parent() != self:
		_fx.queue_free()


func _picked() -> bool:
	var landing: MachineLanding = view.landing
	if landing == null or landing.prize == null:
		return false
	return landing.prize == prize or landing.prize.key() == prize.key()


func _frame_shapes(p: float, rm: bool) -> void:
	if _burst != null:
		var grow: float = 1.0 if p >= OPEN_RM else 0.0
		if not rm:
			grow = StockroomWindow.seg(p, BURST_FROM, BURST_TO)
		_burst.visible = grow > 0.0
		var burst_scale: float = 1.0
		if not rm and grow < 1.0:
			burst_scale = snappedf(lerpf(BURST_START, BURST_OVER, grow), 0.1)
		_burst.scale = Vector2(burst_scale, burst_scale)
	if _sun != null:
		var sun: float = 0.0
		if rm:
			sun = 1.0 if p >= OPEN_RM else 0.0
		elif p > 0.0 and p < SUN_GROW_TO:
			sun = 0.25 + SUN_FULL * p / SUN_GROW_TO
		elif p >= SUN_GROW_TO:
			sun = minf(1.0, 0.45 + (p - SUN_GROW_TO) / SUN_FULL * 0.55)
		_sun.visible = sun > 0.0
		var factor: float = SUN_RADIUS / Sunburst.MET_RADIUS * sun
		_sun.scale = Vector2(factor, factor)
	for spark: int in range(_sparkles.size()):
		var blink: int = int(floorf(view.idle_time * SPARKLE_RATE + spark * SPARKLE_PHASE)) % 3
		_sparkles[spark].visible = p > SPARKLE_FROM and (rm or blink != 0)


func _layer(layer_name: String, parent: Control) -> Control:
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.size = SIZE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	return layer


func _add_shapes() -> void:
	match prize.rarity:
		MachinePrize.Rarity.RARE:
			_burst = UiKit.sprite(BURST)
			_burst.name = "Burst"
			_burst.size = Vector2(BURST.get_size()) * BURST_SCALE
			_burst.position = FX_CENTRE - _burst.size / 2.0
			_burst.pivot_offset = _burst.size / 2.0
			_burst.visible = false
			_fx.add_child(_burst)
		MachinePrize.Rarity.LEGENDARY:
			var half: float = SUN_RECT / 2.0
			_sun = Sunburst.new(Vector2(SUN_RECT, SUN_RECT), Vector2(half, half))
			_sun.set_met(true)
			_sun.position = FX_CENTRE - Vector2(half, half)
			_sun.pivot_offset = Vector2(half, half)
			_sun.visible = false
			_fx.add_child(_sun)
			for at: Vector2 in SPARKLE_AT:  # In the shapes' layer: they follow its rise.
				var spark: TextureRect = UiKit.sprite(SPARKLE)
				spark.name = "Sparkle"
				spark.position = at
				spark.size = SPARKLE_SIZE
				spark.visible = false
				_fx.add_child(spark)
				_sparkles.append(spark)


func _upgraded_card() -> CardDefinition:
	if _preview != null and not _preview.to_cards.is_empty():
		return _preview.to_cards[0]
	return prize.card


func _add_item(card: CardDefinition, run: RunState) -> void:
	item = ItemView.new(CardInstance.new(card, 0), run.balance.aisle_of(card), ItemView.Form.TRAY)
	item.name = "Item"
	item.clicked.connect(func(_view: CardView) -> void: clicked.emit(index))
	item.hovered.connect(func(_view: ItemView) -> void: _set_hover(&"item", true))
	item.unhovered.connect(func(_view: ItemView) -> void: _set_hover(&"item", false))
	_face.add_child(item)


func _add_new_tag() -> void:
	var tag: Label = _label("NEW", NEW_RECT, TAG_SIZE, Palette.PAPER)
	tag.name = "NewTag"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.TOMATO
	style.border_color = Palette.INK
	style.set_border_width_all(2)
	tag.add_theme_stylebox_override("normal", style)


## A SHELF upgrade's tag text ("SHELF ×n", look F), else "".
func _shelf_text() -> String:
	if prize.rarity != MachinePrize.Rarity.LEGENDARY or _preview == null:
		return ""
	return "SHELF ×%d" % _preview.copies


## An upgrade's BIG / GOLDEN tag at the sprite's foot (cream BIG, gold GOLDEN), or `shelf`
## ("SHELF ×n") for a SHELF upgrade.
func _add_tier_tag(card: CardDefinition, shelf: String) -> void:
	var text: String = shelf if not shelf.is_empty() else PriceSticker.tier_text(card)
	if text.is_empty():
		return
	var tag: Label = UiKit.display_label(text, TAG_SIZE, false)
	tag.name = "TierTag"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.GOLD if card.tier == CardDefinition.Tier.GOLDEN else Palette.PAPER
	style.border_color = Palette.INK
	style.set_border_width_all(2)
	style.content_margin_left = 4
	style.content_margin_right = 4
	tag.add_theme_stylebox_override("normal", style)
	tag.position = TIER_TAG_AT
	tag.rotation = deg_to_rad(TIER_TAG_TILT)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(tag)


func _add_stamp_face() -> void:
	var face: Panel = Panel.new()
	face.name = "StampFace"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = SIZE
	face.add_theme_stylebox_override("panel", RewardMachineView.plate_style(Palette.CREAM))
	_face.add_child(face)
	var ring: TextureRect = UiKit.sprite(STAMP_RING)
	ring.name = "StampRing"
	ring.position = STAMP_RING_RECT.position
	ring.size = STAMP_RING_RECT.size
	_face.add_child(ring)
	var initials: String = LoyaltyCard.initials(prize.upgrade.display_name)
	var letters: Label = UiKit.display_label(initials, 24, false)
	letters.name = "Initials"
	letters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letters.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	RewardMachineView.fit(letters, STAMP_RING_RECT)
	_face.add_child(letters)
	_add_note("STAMP · %s" % initials, prize.upgrade.display_name, Palette.MUSTARD)


## The sticker-sized note: a coloured band (`band`) over the text, with `name_line` (look F's
## upgrade name line) between them unless empty.
func _add_note(band: String, text: String, colour: Color, name_line: String = "") -> void:
	var panel: Panel = Panel.new()
	panel.name = "NotePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = NOTE_RECT.position
	panel.size = NOTE_RECT.size
	panel.add_theme_stylebox_override("panel", RewardMachineView.plate_style(Palette.PAPER))
	_face.add_child(panel)
	var head: Label = _label(
		band,
		Rect2(NOTE_RECT.position, Vector2(NOTE_RECT.size.x, BAND_HEIGHT)),
		NOTE_SIZE,
		Palette.INK
	)
	head.name = "Band"
	var style: StyleBoxFlat = RewardMachineView.plate_style(colour)
	head.add_theme_stylebox_override("normal", style)
	var top: float = BAND_HEIGHT
	if not name_line.is_empty():
		var name_rect: Rect2 = Rect2(
			NOTE_RECT.position + Vector2(4, BAND_HEIGHT), Vector2(NOTE_RECT.size.x - 8, NAME_HEIGHT)
		)
		_note_name = _label(name_line, name_rect, NOTE_SIZE, Palette.INK)
		_note_name.name = "NoteName"
		top += NAME_HEIGHT
	var below: Rect2 = Rect2(
		NOTE_RECT.position + Vector2(4, top), NOTE_RECT.size - Vector2(8, top + 2)
	)
	_note = _label(text, below, NOTE_SIZE, Palette.INK)
	_note.name = "Note"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _label(text: String, rect: Rect2, font_size: int, colour: Color) -> Label:
	var label: Label = UiKit.body_label(text, font_size, colour)
	label.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	RewardMachineView.fit(label, rect)
	_face.add_child(label)
	return label


func _set_hover(source: StringName, hovered: bool) -> void:
	_hovers[source] = hovered
	_place_hover()


func _place_hover() -> void:
	var shown: bool = _hovers.values().has(true) and _open >= 1.0 and visible
	if not shown:
		if _hover_card != null:
			_hover_card.visible = false
		return
	var card: PanelContainer = hover_card()
	card.visible = true
	var left: float = TRAY_LEFT - position.x
	var right: float = TRAY_RIGHT - position.x - HOVER_WIDTH
	card.reset_size()
	var x: float = clampf((SIZE.x - HOVER_WIDTH) / 2.0, left, right)
	card.position = Vector2(StockroomWindow.snap(x), -HOVER_GAP - card.size.y)


func _build_hover_card() -> void:
	_hover_card = PanelContainer.new()
	_hover_card.name = "HoverCard"
	_hover_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_card.z_index = 20
	_hover_card.custom_minimum_size = Vector2(HOVER_WIDTH, 0)
	var style: StyleBoxFlat = RewardMachineView.plate_style(Palette.PAPER)
	style.set_content_margin_all(8)
	_hover_card.add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	_hover_card.add_child(column)
	match prize.kind:
		MachinePrize.Kind.REGISTER:
			var fields: UpgradeTicket = UpgradeTicket.new(prize.upgrade)
			for text: String in fields.field_texts():
				column.add_child(_hover_line(text))
			fields.free()
		MachinePrize.Kind.UPGRADE:
			var card: CardDefinition = _upgraded_card()
			column.add_child(_hover_title(card))
			column.add_child(_highlighted_summary(card, highlighted_fields()))
			column.add_child(_hover_line(card.rule_text))
			column.add_child(_hover_line(upgrade_text(prize, _preview)))
		_:
			column.add_child(_hover_title(prize.card))
			var summary: String = CardText.sticker_summary(prize.card)
			if not summary.is_empty():
				column.add_child(_hover_line(summary))
			column.add_child(_hover_line(prize.card.rule_text))
	_hover_card.visible = false
	add_child(_hover_card)


func _hover_title(card: CardDefinition) -> Label:
	var tier: String = PriceSticker.tier_text(card)
	var title: String = (
		card.display_name if tier.is_empty() else "%s · %s" % [card.display_name, tier]
	)
	var label: Label = UiKit.display_label(title, HOVER_TITLE_SIZE, false)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _hover_line(text: String) -> Label:
	var label: Label = UiKit.body_label(text, HOVER_TEXT_SIZE, Palette.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(HOVER_WIDTH - 16.0, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The card's sticker line with the `changed` values on a mustard-light ground (the UI never
## compares rules: CardText says which values changed).
func _highlighted_summary(card: CardDefinition, changed: PackedStringArray) -> RichTextLabel:
	var values: Dictionary = CardText.sticker_values(card)
	var marked: Dictionary = {}
	for key: Variant in values:
		var value: String = str(values[key])
		if changed.has(str(key)):
			value = "[bgcolor=#%s]%s[/bgcolor]" % [Palette.MUSTARD_LIGHT.to_html(false), value]
		marked[key] = value
	var template: String = CardText.sticker_template(card)
	var text: String = template.format(marked) if not template.is_empty() else ""
	if changed.has("base"):
		text = "%s €%s" % [text, marked["base"]] if not text.is_empty() else "€%s" % marked["base"]
	var rich: RichTextLabel = RichTextLabel.new()
	rich.name = "Changed"
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.custom_minimum_size = Vector2(HOVER_WIDTH - 16.0, 0)
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.add_theme_font_override("normal_font", ArtStyle.bold_font(BOLD_WEIGHT))
	rich.add_theme_font_size_override("normal_font_size", HOVER_TEXT_SIZE)
	rich.add_theme_color_override("default_color", Palette.INK)
	rich.text = text
	return rich


## The box (BoxLane's art) and, while it opens, its lid frame.
func _draw_back() -> void:
	BoxLane.draw_box(_back, Vector2.ZERO, _cell, _stamp_day)
	if _lid >= 0:
		var lids: Array[Texture2D] = LIDS_STAMP_DAY if _stamp_day else LIDS
		_back.draw_texture_rect(lids[_lid], LID_RECT, false)


## A RARE ticket's teal inner ring and a LEGENDARY's gold one, on its sticker.
func _draw_ring(ring: Control) -> void:
	match prize.rarity:
		MachinePrize.Rarity.RARE:
			_frame_rect(ring, STICKER_RECT.grow(-2.0), 2.0, Palette.TEAL_LIGHT)
		MachinePrize.Rarity.LEGENDARY:
			_frame_rect(ring, STICKER_RECT.grow(-2.0), 3.0, Palette.GOLD)


static func _frame_rect(canvas: CanvasItem, rect: Rect2, width: float, colour: Color) -> void:
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), colour)
	canvas.draw_rect(Rect2(rect.position.x, rect.end.y - width, rect.size.x, width), colour)
	canvas.draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), colour)
	canvas.draw_rect(Rect2(rect.end.x - width, rect.position.y, width, rect.size.y), colour)


## The pips: one circle (COMMON), two diamonds (RARE) or three stars (LEGENDARY), right-aligned.
func _draw_pips() -> void:
	var count: int = prize.rarity + 1
	var grid: String = PIP_GRIDS[prize.rarity]
	var width: float = 5.0 * PIP_PIXEL
	var x: float = SIZE.x - PIP_RIGHT - count * width - (count - 1) * PIP_GAP
	for pip: int in range(count):
		var origin: Vector2 = Vector2(x + pip * (width + PIP_GAP), PIP_TOP)
		for cell: int in range(grid.length()):
			if grid[cell] == "X":
				var at: Vector2 = origin + Vector2(cell % 5, floori(cell / 5.0)) * PIP_PIXEL
				_pips.draw_rect(Rect2(at, Vector2(PIP_PIXEL, PIP_PIXEL)), Palette.INK)
