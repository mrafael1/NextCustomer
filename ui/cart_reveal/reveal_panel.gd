class_name RevealPanel
extends Control
## The cart reveal's panel (variant A of mock-up cart_reveal_v1.html, v0.51): YOUR STAPLES (the
## recipe's core cards, already in the cart, each with a padlock) in their tray, TODAY'S PICKS
## (the dealt coupon and products) as empty slots that fill as each pick drops out of the TODAY'S
## STOCK dispenser (StockDispenser) and arcs into its slot, the CART chip counting them, then the
## summary line "CART 13/15 = 4 staples + 1 coupon + 8 from today's stock" and the tap hint.
##
## With starter packs (#107, mock-up starter_choice_107.html layout A, v0.63) it has two modes.
## The choice (`choice`, made with an offer): the staples, the dispenser holding today's shared
## products as pictures (their popups open on hover), and PICK A STARTER PACK with the offer's
## packs (PackChoice) where TODAY'S PICKS will be. After the pick (made with `pack`): the pack's
## cards are the first picks and fly in from where they sat on the pack's face (`pack_from`),
## then the shared products drop out of the dispenser as before; a bracket in the pack's colour
## names it under its cards, and the summary reads "CART 13/15 = 4 staples + 3 from Breakfast run
## + 6 from today's stock".
##
## Its layout is the mock-up's, in stage coordinates (the game's 640x360 at 2x): the panel sits at
## RECT on the 1280x720 stage and its content is placed in stage coordinates. show_at(t) poses
## everything for a time t on the reveal's timeline (CartRevealTuning), so the same t always
## gives the same frame (a skip jumps to the end, a capture freezes a moment).

const RECT := Rect2(96, 66, 1088, 642)
## The panel's frame: a paper rim and an ink line outside it, and a drop shadow.
const RIM := 3.0
const SHADOW_DROP := 10.0
const SHADOW := Color(0, 0, 0, 0.35)
const HEADING_SIZE := 22
const SUB_SIZE := 13
const COUNT_GAP := 14.0
## YOUR STAPLES: the heading's padlock chip, the heading, its sub line, the tray and the tiles.
const STAPLES_LOCK := Rect2(152, 126, 28, 28)
const STAPLES_HEADING := Vector2(186, 128)
const STAPLES_SUB := Vector2(158, 160)
const TRAY_POSITION := Vector2(146, 186)
const TRAY_HEIGHT := 144.0
const TRAY_PAD := 12.0
const TILE_LEFT := 158.0
const TILE_STEP := 108.0
## The most tiles the layout holds: the staples' tray (left of the dispenser) and the picks' row
## (the panel's width). A recipe needing more (DeckDefinition) fails the data test that checks it.
const MAX_STAPLES := 4
const MAX_PICKS := 9
const STAPLE_TOP := 196.0
## TODAY'S PICKS: the heading, its sub line, the CART chip, and the slots (the coupons first, a
## gap, then the products).
const PICKS_HEADING := Vector2(158, 402)
const PICKS_SUB := Vector2(158, 428)
const CHIP_POSITION := Vector2(1010, 398)
const CHIP_SIZE := Vector2(0, 34)
const CHIP_TEXT_SIZE := 22
const PICK_TOP := 464.0
const COUPON_GAP := 12.0
## The summary line, centred on the panel, and the tap hint at its bottom right.
const SUMMARY_RECT := Rect2(96, 600, 1088, 70)
const SUMMARY_SIZE := 19
const SUMMARY_GAP := 18
const SUMMARY_PART_GAP := 7
const SUMMARY_ICON := Vector2(28, 28)
const SUMMARY_CHIP_SIZE := 24
const PLUS_SIZE := 22
const HINT_RECT := Rect2(866, 676, 300, 20)
const HINT_SIZE := 15
## A landing's sparkles.
const BURST_COUNT := 5
const SPARKLE := preload("res://art/effects/sparkle.png")
const STAPLES_TEXT := "YOUR STAPLES"
const STAPLES_SUB_TEXT := "In every run’s cart. Never a surprise."
const PICKS_TEXT := "TODAY’S PICKS"
const SKIP_HINT := "TAP TO SKIP ››"
const START_HINT := "TAP TO START SHIFT %d ›"
## The choice's hint, and the dispenser's LED while it waits for the pick (#107).
const CHOOSE_HINT := "1 · 2 · 3 RAISE  ·  ENTER TAKES IT"
const CHOOSE_LED := "PICK A PACK ↓"
## The bracket under the pack's cards (#107): its bar, under the tiles, and its name.
const BRACKET_TOP := 590.0
const BRACKET_HEIGHT := 4.0
const BRACKET_NAME_TOP := 598.0
const BRACKET_NAME_SIZE := 12

var staples: Array[CardDefinition] = []
var picks: Array[CardDefinition] = []
var staple_tiles: Array[RevealTile] = []
var pick_tiles: Array[RevealTile] = []
var slots: Array[RevealSlot] = []
var dispenser: StockDispenser
var chip: RevealChip
var summary: HBoxContainer
var hint: Label
var staples_heading: Label
var picks_heading: Label
var picks_count: Label
var picks_sub: Label
## The starter pack choice (#107; null outside it) and the pack taken (null without packs).
var choice: PackChoice
var pack: StarterPackDefinition
var _pack_count: int = 0
## Where each of the pack's cards sat on its face (stage coordinates): their flights start there.
var _pack_from: Array[Vector2] = []
## The dispenser's heap: the picks after the pack's, or the offer's shared products (the choice).
var _heap_cards: Array[CardDefinition] = []
var _content: Control
var _fly_layer: Control
var _flyers: Array[TextureRect] = []
var _bursts: Array[Array] = []
var _coupons: int = 0
var _deck_limit: int = 0
var _copy_max: int = 0
var _shift: int = 1


## The panel for a dealt deck: its `core` cards (the staples) and its `dealt` picks (the coupons
## first), at most `copy_max` copies of a card, a cart of `deck_limit`, before shift `shift`.
## With `taken` (#107) the first picks are that pack's cards, flying in from `taken_from`; with
## `offer` the panel is the choice (no picks yet).
func _init(
	core: Array[CardDefinition],
	dealt: Array[CardDefinition],
	copy_max: int,
	deck_limit: int,
	shift: int,
	taken: StarterPackDefinition = null,
	taken_from: Array[Vector2] = [],
	offer: StartOffer = null
) -> void:
	_copy_max = copy_max
	staples = core.duplicate()
	picks = dealt.duplicate()
	if offer != null:
		picks.clear()
	_deck_limit = deck_limit
	_shift = shift
	pack = taken
	if pack != null:
		_pack_count = mini(pack.cards.size(), picks.size())
		_pack_from = taken_from.duplicate()
	_heap_cards = offer.shared.duplicate() if offer != null else picks.slice(_pack_count)
	if pack == null and offer == null:
		for card: CardDefinition in picks:
			_coupons += 1 if card.is_coupon() else 0
	name = "RevealPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = RECT.position
	size = RECT.size
	_content = Control.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.position = -RECT.position
	_content.draw.connect(_draw_tray)
	add_child(_content)
	_build_staples()
	_build_picks()
	_build_summary()
	if offer != null:
		choice = PackChoice.new(offer)
		_content.add_child(choice)
	_fly_layer = Control.new()
	_fly_layer.name = "Flyers"
	_fly_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_fly_layer)
	for card: CardDefinition in picks:
		var flyer: TextureRect = ItemView.item_art(card)
		flyer.pivot_offset = ItemView.SPRITE_SIZE / 2.0
		flyer.visible = false
		_fly_layer.add_child(flyer)
		_flyers.append(flyer)
		var burst: Array[TextureRect] = []
		for _spark: int in BURST_COUNT:
			var sparkle: TextureRect = UiKit.sprite(SPARKLE)
			sparkle.size = SPARKLE.get_size() * ArtStyle.ART_SCALE
			sparkle.visible = false
			_fly_layer.add_child(sparkle)
			burst.append(sparkle)
		_bursts.append(burst)


## Whether the panel's layout holds `recipe`'s deal: at most MAX_STAPLES core cards and
## MAX_PICKS coupons and products.
static func fits(recipe: DeckDefinition) -> bool:
	var dealt: int = recipe.random_count + recipe.random_coupon_count
	return recipe.core_cards.size() <= MAX_STAPLES and dealt <= MAX_PICKS


## Where pick `index`'s slot is, in stage coordinates.
func slot_position(index: int) -> Vector2:
	var gap: float = COUPON_GAP if _coupons > 0 and index >= _coupons else 0.0
	return Vector2(TILE_LEFT + index * TILE_STEP + gap, PICK_TOP)


## The flyer (the pick's art in flight) of pick `index` (for tests).
func flyer_of(index: int) -> TextureRect:
	return _flyers[index]


## Poses the panel for time `t` on the reveal's timeline (`timing`): the staples' padlocks, the
## picks in flight or landed, their sparkles, the counts, the summary and the hint, and the
## dispenser.
func show_at(t: float, timing: CartRevealTuning) -> void:
	_show_locks(t, timing)
	if choice != null:
		_show_choice(t, timing)
		return
	_show_picks(t, timing)


## The staples' padlocks clunk on, one after another.
func _show_locks(t: float, timing: CartRevealTuning) -> void:
	for index: int in staple_tiles.size():
		var start: float = timing.lock_start_s + timing.lock_gap_s * index
		var q: float = clampf((t - start) / timing.lock_s, 0.0, 1.0)
		var lock: RevealChip = staple_tiles[index].lock_badge
		lock.visible = t >= start
		var grow: float = (timing.lock_scale - 1.0) * (1.0 - CartReveal.ease_out(q))
		lock.scale = Vector2.ONE * (1.0 + grow)
		lock.rotation_degrees = (1.0 - q) * timing.lock_turn_deg


## The choice (#107): the packs drop in and wait; the dispenser shows today's products, full.
func _show_choice(t: float, timing: CartRevealTuning) -> void:
	choice.show_at(t, timing)
	var chase: int = int(floorf(t * timing.chase_hz))
	var lit: Array[bool] = []
	for bulb: int in StockDispenser.BULB_COUNT:
		lit.append((bulb + chase) % 3 == 0)
	dispenser.show_state(0, 0.0, 0.0, 0.0, 0.0, lit, CHOOSE_LED, false)
	hint.text = CHOOSE_HINT
	hint.modulate.a = 0.7


## The picks in flight or landed, the counts, the summary, the hint and the dispenser.
func _show_picks(t: float, timing: CartRevealTuning) -> void:
	var landed: int = 0
	var pulse: bool = false
	for index: int in picks.size():
		landed += 1 if _show_pick(index, t, timing) else 0
		var land: float = timing.pick_land(index)
		pulse = pulse or (t >= land and t < land + timing.chip_pop_s)
	var total: int = picks.size()
	picks_count.text = "%d/%d" % [landed, total]
	chip.set_text("CART %d/%d" % [staples.size() + landed, _deck_limit])
	chip.scale = Vector2.ONE * (1.0 + (timing.chip_pop if pulse else 0.0))
	var sq: float = clampf((t - timing.summary_start(total)) / timing.summary_s, 0.0, 1.0)
	summary.modulate.a = sq
	summary.position.y = (
		SUMMARY_RECT.position.y
		+ CartReveal.snap((1.0 - CartReveal.ease_out(sq)) * timing.summary_rise)
	)
	chip.modulate.a = 1.0 - sq
	var end: float = timing.end_time(total)
	if t < end:
		hint.text = SKIP_HINT
		hint.modulate.a = 0.7
	else:
		hint.text = START_HINT % _shift
		hint.modulate.a = 1.0 if int(floorf(t * timing.hint_hz)) % 2 == 1 else 0.55
	_show_dispenser(t, timing)


## Shows pick `index` at `t`: in flight (its flyer), or landed (its tile popping in over its
## slot, its sparkles flying out). Returns whether it has landed.
func _show_pick(index: int, t: float, timing: CartRevealTuning) -> bool:
	var land: float = timing.pick_land(index)
	var start: float = timing.pick_start(index)
	var tile: RevealTile = pick_tiles[index]
	var flyer_art: TextureRect = _flyers[index]
	var done: bool = t >= land
	tile.visible = done
	slots[index].visible = not done
	flyer_art.visible = not done and t >= start
	if done:
		var q: float = clampf((t - land) / timing.land_s, 0.0, 1.0)
		tile.set_landing(timing.land_pop * (1.0 - q) * (1.0 - q), timing.land_flash * (1.0 - q))
	elif flyer_art.visible:
		var pose: Transform2D = _flight(index, t - start, timing)
		flyer_art.position = Vector2(CartReveal.snap(pose.origin.x), CartReveal.snap(pose.origin.y))
		flyer_art.scale = pose.get_scale()
		flyer_art.rotation = pose.get_rotation()
	var since: float = t - land
	for spark: int in BURST_COUNT:
		var sparkle: TextureRect = _bursts[index][spark]
		sparkle.visible = since >= 0.0 and since < timing.burst_s
		if sparkle.visible:
			var angle: float = float(spark) / BURST_COUNT * TAU - PI / 2.0
			var radius: float = timing.burst_radius + since * timing.burst_speed
			var centre: Vector2 = slot_position(index) + RevealTile.SIZE / 2.0 - Vector2(0, 10)
			var at: Vector2 = centre + Vector2(cos(angle), sin(angle) * 0.8) * radius
			sparkle.position = Vector2(CartReveal.snap(at.x - 5.0), CartReveal.snap(at.y - 5.0))
			sparkle.modulate.a = 1.0 - since / timing.burst_s
	return done


## The flyer's pose `since` seconds after pick `index` left: popping out of the chute, then its
## arc into its slot (a coupon flutters, a product rights itself).
func _flight(index: int, since: float, timing: CartRevealTuning) -> Transform2D:
	var coupon: bool = picks[index].is_coupon()
	if index < _pack_count and index < _pack_from.size():
		# A pack's card (#107) arcs from its place on the pack's face, with no chute to leave.
		var lift: float = clampf(since / (timing.exit_s + timing.fly_s), 0.0, 1.0)
		var into: Vector2 = slot_position(index) + RevealTile.SPRITE_POSITION
		var arc: float = timing.coupon_arc_height if coupon else timing.arc_height
		var pose_at: Vector2 = (
			_pack_from[index].lerp(into, lift) - Vector2(0, arc * 4.0 * lift * (1.0 - lift))
		)
		return Transform2D(0.0, Vector2.ONE, 0.0, pose_at)
	var exit: Vector2 = StockDispenser.EXIT_POINT
	if since < timing.exit_s:
		var e: float = CartReveal.ease_out(clampf(since / timing.exit_s, 0.0, 1.0))
		var grow: float = timing.exit_scale + (1.0 - timing.exit_scale) * e
		return Transform2D(0.0, Vector2.ONE * grow, 0.0, exit + Vector2(0, timing.exit_drop * e))
	var u: float = clampf((since - timing.exit_s) / timing.fly_s, 0.0, 1.0)
	var from: Vector2 = exit + Vector2(0, timing.exit_drop)
	var to: Vector2 = slot_position(index) + RevealTile.SPRITE_POSITION
	var height: float = timing.coupon_arc_height if coupon else timing.arc_height
	var at: Vector2 = from.lerp(to, u) - Vector2(0, height * 4.0 * u * (1.0 - u))
	var turn: float
	if coupon:
		turn = sin(u * PI * 3.0) * timing.coupon_flutter_deg
	else:
		turn = (1.0 - u) * timing.product_tilt_deg * (1.0 if index % 2 == 1 else -1.0)
	return Transform2D(deg_to_rad(turn), Vector2.ONE, 0.0, at)


func _show_dispenser(t: float, timing: CartRevealTuning) -> void:
	var total: int = _heap_cards.size()
	var dispensed: int = 0
	var jolt: float = 0.0
	var open: float = 0.0
	for index: int in total:
		var since: float = t - timing.pick_start(index + _pack_count)
		if since >= 0.0:
			dispensed = index + 1
		if since >= 0.0 and since < timing.jolt_s:
			jolt = sin(since / timing.jolt_s * PI * 3.0) * timing.jolt_px
		if since >= 0.0 and since < timing.flap_s:
			open = maxf(open, sin(since / timing.flap_s * PI))
	var last_land: float = timing.pick_land(total - 1 + _pack_count) if total > 0 else 0.0
	var done: bool = t >= last_land
	var chase: int = int(floorf(t * timing.chase_hz))
	var blink: bool = done and int(floorf(t * timing.blink_hz)) % 2 == 1
	var lit: Array[bool] = []
	for bulb: int in StockDispenser.BULB_COUNT:
		lit.append((bulb + chase) % 3 == 0 or blink)
	var message: String
	if dispensed == 0 and pack != null:
		message = "%d FROM TODAY’S STOCK" % total
	elif dispensed == 0:
		message = "%d PICKS + %d %s" % [total - _coupons, _coupons, _plural("COUPON", _coupons)]
	elif done:
		message = "CART READY ✓"
	else:
		message = "DISPENSING %d/%d" % [dispensed, total]
	var moving: bool = t > timing.pick_start_s and not done
	var wobble: float = t * 40.0 if moving else 0.0
	dispenser.show_state(
		dispensed, dispensed * timing.heap_sink, wobble, jolt, open, lit, message, done
	)


func _build_staples() -> void:
	var lock: RevealChip = RevealChip.new(Palette.MUSTARD, STAPLES_LOCK.size, RevealTile.LOCK_ICON)
	lock.position = STAPLES_LOCK.position
	_content.add_child(lock)
	staples_heading = _heading(STAPLES_TEXT, STAPLES_HEADING, str(staples.size()))
	_sub(STAPLES_SUB_TEXT, STAPLES_SUB)
	for index: int in staples.size():
		var tile: RevealTile = RevealTile.new(staples[index], RevealTile.Kind.STAPLE)
		tile.position = Vector2(TILE_LEFT + index * TILE_STEP, STAPLE_TOP)
		_content.add_child(tile)
		staple_tiles.append(tile)


func _build_picks() -> void:
	picks_heading = _heading(PICKS_TEXT, PICKS_HEADING, "0/%d" % picks.size())
	picks_count = picks_heading.get_parent().get_child(1) as Label
	var products: int = picks.size() - _coupons
	var sub_text: String = (
		"%d %s + %d %s, random from today’s stock. A pick can repeat a staple (×2), never a %s copy."
		% [
			_coupons,
			_plural("coupon", _coupons),
			products,
			_plural("product", products),
			CartReveal.ordinal(_copy_max + 1),
		]
	)
	if pack != null:
		sub_text = (
			"%d from your %s pack + %d from today’s stock."
			% [_pack_count, pack.display_name, picks.size() - _pack_count]
		)
	picks_sub = _sub(sub_text, PICKS_SUB)
	chip = RevealChip.new(Palette.MUSTARD, CHIP_SIZE, null, "CART 0/0", CHIP_TEXT_SIZE, Palette.INK)
	chip.pad = 12.0
	chip.ledge = Palette.MUSTARD_DARKEST
	chip.position = CHIP_POSITION
	_content.add_child(chip)
	dispenser = StockDispenser.new(_heap_cards)
	_content.add_child(dispenser)
	if picks.is_empty():
		# The choice (#107): TODAY'S PICKS waits for the pack.
		picks_heading.get_parent().visible = false
		picks_sub.visible = false
		chip.visible = false
	for index: int in picks.size():
		var card: CardDefinition = picks[index]
		var slot: RevealSlot = RevealSlot.new(card.is_coupon())
		slot.position = slot_position(index)
		_content.add_child(slot)
		slots.append(slot)
		var second: bool = (
			index >= _pack_count and card.is_product() and staples.any(card.is_same_product)
		)
		var kind: RevealTile.Kind = (
			RevealTile.Kind.COUPON if card.is_coupon() else RevealTile.Kind.PICK
		)
		var tile: RevealTile = RevealTile.new(card, kind, second)
		tile.position = slot.position
		tile.visible = false
		_content.add_child(tile)
		pick_tiles.append(tile)
	if pack != null and _pack_count > 0:
		_build_bracket()


## The summary line: CART n/limit = <padlock> 4 staples + <token> 1 coupon + <+> 8 from today's
## stock, centred on the panel.
func _build_summary() -> void:
	summary = HBoxContainer.new()
	summary.name = "Summary"
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_theme_constant_override("separation", SUMMARY_GAP)
	summary.position = SUMMARY_RECT.position
	summary.size = SUMMARY_RECT.size
	_content.add_child(summary)
	var total: RevealChip = RevealChip.new(
		Palette.MUSTARD,
		CHIP_SIZE,
		null,
		"CART %d/%d" % [staples.size() + picks.size(), _deck_limit],
		SUMMARY_CHIP_SIZE,
		Palette.INK
	)
	total.pad = 12.0
	total.ledge = Palette.MUSTARD_DARKEST
	total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	summary.add_child(total)
	summary.add_child(_summary_text("=", Palette.PAPER, SUMMARY_SIZE))
	var products: int = picks.size() - _coupons
	summary.add_child(
		_summary_part(
			Palette.MUSTARD,
			RevealTile.LOCK_ICON,
			"%d %s" % [staples.size(), _plural("staple", staples.size())]
		)
	)
	if _coupons > 0:
		summary.add_child(_summary_text("+", Palette.TEAL_LIGHT, PLUS_SIZE))
		summary.add_child(
			_summary_part(
				Palette.TOMATO,
				RevealTile.COUPON_ICON,
				"%d %s" % [_coupons, _plural("coupon", _coupons)]
			)
		)
	if pack != null:
		var look: Array = PackFace.pack_look(pack)
		var glyph: Texture2D = look[2] if look[2] != null else RevealTile.PICK_ICON
		summary.add_child(_summary_text("+", Palette.TEAL_LIGHT, PLUS_SIZE))
		summary.add_child(
			_summary_part(look[0], glyph, "%d from %s" % [_pack_count, pack.display_name])
		)
		products = picks.size() - _pack_count
	summary.add_child(_summary_text("+", Palette.TEAL_LIGHT, PLUS_SIZE))
	summary.add_child(
		_summary_part(Palette.TEAL_BRIGHT, RevealTile.PICK_ICON, "%d from today’s stock" % products)
	)
	summary.modulate.a = 0.0
	hint = UiKit.body_label(SKIP_HINT, HINT_SIZE, Palette.TEAL_LIGHT)
	hint.add_theme_font_override("font", CartReveal.spaced_font(800, 1))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.position = HINT_RECT.position
	hint.size = HINT_RECT.size
	_content.add_child(hint)


## The bracket under the pack's cards (#107): a bar in its family's colour and its name.
func _build_bracket() -> void:
	var look: Array = PackFace.pack_look(pack)
	var colour: Color = look[0]
	var left: float = slot_position(0).x
	var right: float = slot_position(_pack_count - 1).x + RevealTile.SIZE.x
	var bar: ColorRect = ColorRect.new()
	bar.name = "PackBracket"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.color = colour
	bar.position = Vector2(left, BRACKET_TOP)
	bar.size = Vector2(right - left, BRACKET_HEIGHT)
	_content.add_child(bar)
	var label: Label = UiKit.body_label(pack.display_name.to_upper(), BRACKET_NAME_SIZE, look[1])
	label.add_theme_font_override("font", CartReveal.spaced_font(800, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(left, BRACKET_NAME_TOP)
	label.size = Vector2(right - left, 16)
	_content.add_child(label)


func _summary_part(color: Color, icon: Texture2D, text: String) -> HBoxContainer:
	var part: HBoxContainer = HBoxContainer.new()
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	part.add_theme_constant_override("separation", SUMMARY_PART_GAP)
	var chip_icon: RevealChip = RevealChip.new(color, SUMMARY_ICON, icon)
	chip_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	part.add_child(chip_icon)
	part.add_child(_summary_text(text, Palette.PAPER, SUMMARY_SIZE))
	return part


func _summary_text(text: String, color: Color, font_size: int) -> Label:
	var label: Label = UiKit.body_label(text, font_size, color)
	label.add_theme_font_override("font", CartReveal.font(700))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	return label


## A heading row at `at`: the mustard heading, then its teal `count` COUNT_GAP px after it.
## Returns the heading (the count is the row's second child).
func _heading(text: String, at: Vector2, count: String) -> Label:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(COUNT_GAP))
	row.position = at
	_content.add_child(row)
	var label: Label = null
	for part: Array in [[text, Palette.MUSTARD_LIGHT], [count, Palette.TEAL_LIGHT]]:
		var piece: Label = UiKit.body_label(part[0], HEADING_SIZE, part[1])
		piece.add_theme_font_override("font", CartReveal.spaced_font(800, 1))
		row.add_child(piece)
		if label == null:
			label = piece
	return label


func _sub(text: String, at: Vector2) -> Label:
	var label: Label = UiKit.body_label(text, SUB_SIZE, Palette.TEAL_PALE)
	label.position = at
	_content.add_child(label)
	return label


static func _plural(word: String, count: int) -> String:
	if count == 1:
		return word
	return word + ("S" if word == word.to_upper() else "s")


## The panel's frame (drop shadow, ink line, paper rim, the panel) and the staples' tray.
func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var outer: Rect2 = rect.grow(RIM + 2.0)
	draw_rect(Rect2(outer.position + Vector2(0, SHADOW_DROP), outer.size), SHADOW)
	draw_rect(outer, Palette.INK)
	draw_rect(rect.grow(RIM), Palette.PAPER)
	draw_rect(rect, Palette.PANEL)


func _draw_tray() -> void:
	var width: float = staples.size() * TILE_STEP - (TILE_STEP - RevealTile.SIZE.x) + TRAY_PAD * 2.0
	var tray: Rect2 = Rect2(TRAY_POSITION, Vector2(width, TRAY_HEIGHT))
	_content.draw_rect(tray, Palette.BACKGROUND)
	_content.draw_rect(Rect2(tray.position, Vector2(tray.size.x, 6)), Color(0, 0, 0, 0.25))
	_content.draw_rect(tray.grow(-1), Palette.TEAL_BLACK, false, 2.0)
