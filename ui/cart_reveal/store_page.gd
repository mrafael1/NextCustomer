class_name StorePage
extends Control
## YOUR STORE, page 1 "Counter" (full build plan 7.2, v1.07; mock-up start_store_v6.html,
## direction A, the user: "A counter is really good"). Three hand baskets hang under their aisle
## signs on one rail (Staples, then the two STARTER CART aisles), dealt face up; today's extra
## (RUN-ONLY) aisle is a small sign at the rail's end with no basket; the baskets stand on one
## wooden shelf that ends before it (v1.08), and YOUR REGULARS stand on a matching shelf below,
## each with one price and family sticker on the shelf's edge. Each unlock appears in place only
## once earned: from 1 completed aisle a swap badge on each regular and the SWAPS pips, from
## restock_min_completed one RESTOCK key by the baskets, from pair_choice_min_completed a swap tab
## on the two starter signs. A red NEW tag marks an
## unlocked control until it is first used or the run clocks in (StartBoard marks it seen).
##
## The page only shows and reports clicks (its signals); StartBoard routes them to StartChoice and
## opens the small pop-ups (StorePopover). Motion (the drop-in, a restock's hop-out and drop, a
## swap's flip, a restock pick's hover) is cosmetic; reduced motion shows the end state.
##
## The RESTOCK pick works as the shift's basket redraw (v1.08, the user: "it should work like
## in-run redraw"; BasketTags, RedrawTag, BasketRedraw): the key arms it (PICK A BASKET, with its
## close cross), each basket that can be restocked wears the redraw's teal tag on its front, here
## reading RESTOCK, and becomes a click target; a hovered basket eases up and wobbles (the
## redraw's hover, RedrawTuning) and its tag goes hot (teal light, without the redraw's gold
## ring), naming how many items go ("RESTOCK 2").
## Nothing else on the page changes: no frames, cues, bob or dimming.

signal restock_pressed
signal basket_clicked(basket: int)
signal regular_clicked(slot: int)
signal undo_clicked(slot: int)
signal sign_clicked(basket: int)

## First-seen flags (ProfileState.seen) of the NEW tags.
const NEW_SWAP := &"start_new_swap"
const NEW_RESTOCK := &"start_new_restock"
const NEW_AISLE := &"start_new_aisle"
const SWAP_ICON := preload("res://art/icons/swap_arrows.png")
const RESTOCK_ICON := preload("res://art/icons/redraw_arrow.png")
const BASKET_BACK := preload("res://art/scenery/basket_back_left.png")
const BASKET_FRONT := preload("res://art/scenery/basket_front.png")
const CAPSULE_PATH := "res://art/scenery/toy_capsule_%s.png"
## The rail, a bay's left and step (a bay: strings, sign, basket), its width, and the sign.
const RAIL := Rect2(26, 150, 1228, 8)
const BAY_LEFT := 40.0
const BAY_STEP := 333.0
const BAY_WIDTH := 313.0
const SIGN := Rect2(13, 164, 287, 42)
## The basket's art scale (the mock-up's 1.8 screen px at 1080p), its left in the bay, the items'
## top and size, and the gap between them.
const BASKET_SCALE := 1.2
const BASKET_X := 27.0
const ITEM_TOP := 214.0
const ITEM_SIZE := 96.0
const ITEM_GAP := 12.0
## The RESTOCK key, the extra aisle's sign, the baskets' zone bottom, the regulars' heading, tiles
## and gap, and the footer's top. The baskets' shelf and the regulars' shelf are PLANK px deep, and
## the baskets' shelf reaches SHELF_REACH px past the outer baskets.
const RESTOCK := Rect2(704, 92, 308, 48)
const EXTRA := Rect2(1040, 179, 200, 36)
const WALL_SHELF_Y := 402.0
const PLANK := 20.0
const SHELF_REACH := 20.0
const REGULARS_TOP := 419.0
const TILE_TOP := 473.0
const TILE_GAP := 24.0
## A regular's swap badge (v1.08): BADGE px square, BADGE_GAP px clear of its art's visible box,
## reaching at most BADGE_REACH px past its tile's right edge (into the TILE_GAP lane).
const BADGE := 30.0
const BADGE_GAP := 4.0
const BADGE_REACH := 12.0
## A swapped regular's put-back tag (↺ and the old item): it takes the swap badge's place, its
## top-right corner on the badge's.
const UNDO := Vector2(58, 32)
const FOOTER_Y := 630.0
## Motion (s): the drop-in, the hop-out, the new pair's drop and the flip; the basket dips
## LAND_DIP px over LAND_DIP_S as each new item lands.
const DROP_S := 0.5
const HOP_S := 0.28
const PAIR_DROP_S := 0.55
const FLIP_S := 0.42
const LAND_DIP := 4.0
## The delay between two items' hop-out (and drop-in), s.
const ITEM_STAGGER_S := 0.08
const LAND_DIP_S := 0.18
## The RESTOCK tag's word, and its top above the basket's foot (it sits where RESTOCKED stamps).
const RESTOCK_WORD := "RESTOCK"
const TAG_RISE := 30.0

## The three bays (strings, sign, basket), their signs, each basket's item hosts and pick areas.
var bays: Array[Control] = []
var signs: Array[Panel] = []
var items: Array[Array] = []
var hits: Array[Control] = []
var regulars: Array[Control] = []
var restock_key: Button
var swap_chip: Control
var extra: Control
## Whether the baskets wait for a click (or 1–3) to restock one.
var restock_picking: bool = false
## The regular whose swap shelf is open (-1: none) and the starter basket whose aisle pop-up is.
var open_slot: int = -1
var open_basket: int = -1
## The NEW tags shown (unlocked controls' first-seen flags not yet in the profile).
var fresh: Array[StringName] = []
var _run: RunState
var _profile: ProfileState
var _reduced: bool = true
var _tweens: Array[Tween] = []
var _loops: Array[Tween] = []
## The redraw's hover timings (RedrawTuning), and each basket's hover tween while one plays.
var _hover: RestockHover = RestockHover.new()


## Shows the page for `run` and `profile` (rebuilt from scratch).
func show_store(run: RunState, profile: ProfileState) -> void:
	_run = run
	_profile = profile
	_reduced = profile.reduced_motion()
	skip_deal()
	StartBoardKit.clear(self)
	bays.clear()
	signs.clear()
	items.clear()
	hits.clear()
	regulars.clear()
	_hover.clear()
	restock_key = null
	swap_chip = null
	extra = null
	size = ShiftStage.SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	restock_picking = restock_picking and can_restock()
	fresh = _fresh_tags()
	_draw_wall()
	_add_basket_shelf()
	var heading: Label = StartBoardKit.words(
		self, "TODAY'S BASKETS", Rect2(40, 110, 300, 28), Palette.MUSTARD_LIGHT
	)
	heading.name = "BasketsHeading"
	StartBoardKit.panel(self, RAIL, Palette.STEEL, Palette.INK).name = "Rail"
	for index: int in _run.start_setup.baskets.size():
		_add_bay(index)
	_add_extra()
	_add_restock_key()
	_add_regulars()
	_show_picking()


## The unlocked controls' first-seen flags not yet seen.
func _fresh_tags() -> Array[StringName]:
	var found: Array[StringName] = []
	# A run that already swapped (one resumed from before the NEW tags) knows the control.
	var swapped: bool = StartSetupRules.applied_swaps(_run) > 0
	if StartSetupRules.swap_limit(_run, _profile) > 0 and not swapped:
		found.append(NEW_SWAP)
	if restock_unlocked() and _run.start_setup.restock_basket < 0:
		found.append(NEW_RESTOCK)
	if StartSetupRules.choice_mode(_run.balance, _profile):
		found.append(NEW_AISLE)
	return found.filter(func(id: StringName) -> bool: return not _profile.seen.has(id))


## Whether RESTOCK shows (restock_min_completed completed aisles).
func restock_unlocked() -> bool:
	var done: int = StartSetupRules.completed(_run.balance, _profile).size()
	return done >= _run.balance.restock_min_completed and _run.balance.restocks_per_run > 0


## Whether a basket can still be restocked this run.
func can_restock() -> bool:
	for basket: int in _run.start_setup.baskets.size():
		if StartSetupRules.restock_block(_run, _profile, basket) == &"":
			return true
	return false


## Whether green basket `basket`'s sign can change its aisle.
func can_change(basket: int) -> bool:
	return not StartSetupRules.aisle_options(_run, _profile, basket).is_empty()


## Whether regular `slot` can open its swap shelf (a swap left, or it is swapped).
func can_swap(slot: int) -> bool:
	if slot < 0 or slot >= _run.starter.core_cards.size():
		return false
	if StartSetupRules.swap_limit(_run, _profile) <= 0:
		return false
	var swapped: bool = _run.starter.core_cards[slot] != _run.start_setup.originals[slot]
	return swapped or StartSetupRules.swaps_left(_run, _profile) > 0


## The baskets wait for a pick (`on`), each restockable one tagged RESTOCK, or stop waiting.
func set_restock_picking(on: bool) -> void:
	restock_picking = on
	if _run != null:
		show_store(_run, _profile)


## Marks regular `slot` (-1: none) as the one whose swap shelf is open.
func set_open_slot(slot: int) -> void:
	open_slot = slot
	for index: int in regulars.size():
		_lift(index, 8.0 if index == slot else 0.0)
		(regulars[index].get_node("Selected") as Control).visible = index == slot


## Marks green basket `basket` (-1: none) as the one whose aisle pop-up is open.
func set_open_basket(basket: int) -> void:
	var before: int = open_basket
	open_basket = basket
	for index: int in [before, basket]:
		_sign_hover(index, false)


## Basket `basket`'s pick area (its items and front), in stage px.
func basket_rect(basket: int) -> Rect2:
	var bottom: float = _front_top() + BASKET_FRONT.get_height() * BASKET_SCALE
	return Rect2(
		BAY_LEFT + basket * BAY_STEP + BASKET_X - 10,
		ITEM_TOP - 8,
		BASKET_FRONT.get_width() * BASKET_SCALE + 20,
		bottom - ITEM_TOP + 16
	)


## Basket `basket`'s sign rect (stage px).
func sign_rect(basket: int) -> Rect2:
	return Rect2(SIGN.position + Vector2(BAY_LEFT + basket * BAY_STEP, 0), SIGN.size)


## The baskets' shelf (stage px): one plank under the three baskets, its top at their feet, ending
## before today's extra aisle.
func basket_shelf_rect() -> Rect2:
	var feet: float = _front_top() + BASKET_FRONT.get_height() * BASKET_SCALE
	var left: float = BAY_LEFT + BASKET_X - SHELF_REACH
	var count: int = _run.start_setup.baskets.size() if _run != null else 3
	var right: float = (
		BAY_LEFT + (count - 1) * BAY_STEP + BASKET_X + BASKET_FRONT.get_width() * BASKET_SCALE
	)
	right = 2.0 * ceilf((right + SHELF_REACH) / 2.0)
	return Rect2(left, 2.0 * floorf(feet / 2.0), right - left, PLANK)


## Regular `slot`'s tile rect at rest (stage px).
func tile_rect(slot: int) -> Rect2:
	return Rect2(Vector2(_tile_left(slot), TILE_TOP), StartItemTile.SIZE)


func _tile_left(slot: int) -> float:
	var count: int = _run.starter.core_cards.size()
	var width: float = count * StartItemTile.SIZE.x + (count - 1) * TILE_GAP
	return floorf((ShiftStage.SIZE.x - width) / 4.0) * 2 + slot * (StartItemTile.SIZE.x + TILE_GAP)


func _front_top() -> float:
	return ITEM_TOP + floorf(ITEM_SIZE * 0.78)


func _draw_wall() -> void:
	var wall: Control = Control.new()
	wall.name = "Wall"
	wall.size = ShiftStage.SIZE
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.draw.connect(
		func() -> void:
			wall.draw_rect(Rect2(0, 54, 1280, FOOTER_Y - 54), Palette.BACKGROUND)
			for x: int in range(158, 1280, 166):
				wall.draw_rect(Rect2(x, 54, 8, FOOTER_Y - 54), Color(Palette.TEAL_BLACK, 0.55))
			wall.draw_rect(Rect2(0, FOOTER_Y, 1280, 720 - FOOTER_Y), Palette.RUBBER)
			wall.draw_rect(Rect2(0, FOOTER_Y, 1280, 2), Palette.INK)
			wall.draw_rect(Rect2(0, FOOTER_Y + 2, 1280, 2), Palette.STEEL_DARK)
	)
	add_child(wall)


## The baskets' wooden shelf (basket_shelf_rect), drawn under the bays so their feet stand on it.
func _add_basket_shelf() -> void:
	StartBoardKit.plank(self, basket_shelf_rect()).name = "BasketShelf"


## A sign in its aisle's colour (the Staples shelf's cream) with its glyph and name; a starter
## basket's sign that can change its aisle carries a swap tab at its right end.
func _sign(parent: Control, source: StringName, rect: Rect2, tab: bool) -> Panel:
	var aisle: AisleDefinition = aisle_of(_run, source)
	var face: Color = aisle.sign_color if aisle != null else Palette.CREAM
	var ink: Color = Palette.INK if face.get_luminance() > 0.55 else Palette.PAPER
	var board: Panel = StartBoardKit.panel(parent, rect, face, Palette.INK)
	(board.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(3)
	var shine: Panel = StartBoardKit.panel(
		board, Rect2(3, 3, rect.size.x - 6, 4), Color(Palette.PAPER, 0.35), Color(0, 0, 0, 0)
	)
	shine.name = "Shine"
	var title: String = aisle.display_name if aisle != null else "Staples"
	var room: float = rect.size.x - (42.0 if tab else 0.0)
	var width: float = StartBoardKit.text_width(title) + 26
	var left: float = floorf((room - width) / 4.0) * 2
	var glyph: TextureRect = StartBoardKit.icon(
		board, StartBoardKit.glyph(aisle), Vector2(left, floorf(rect.size.y / 4.0) * 2 - 9)
	)
	glyph.name = "Glyph"
	var name_label: Label = StartBoardKit.tag(
		board, title, Rect2(left + 26, 0, room - left - 26, rect.size.y), ink, 2, false
	)
	name_label.name = "Name"
	UiKit.place_pixel_label(name_label, Rect2(left + 26, 0, room - left - 26, rect.size.y), true)
	if tab:
		var swap: Panel = StartBoardKit.panel(
			board, Rect2(rect.size.x - 42, 0, 42, rect.size.y), Palette.TEAL_SHADE
		)
		swap.name = "SwapTab"
		(swap.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(3)
		var arrows: TextureRect = StartBoardKit.icon(
			swap, SWAP_ICON, Vector2(12, floorf(rect.size.y / 4.0) * 2 - 10)
		)
		arrows.name = "Arrows"
	return board


func _add_bay(index: int) -> void:
	var setup: StartSetup = _run.start_setup
	var bay: Control = Control.new()
	bay.name = "Basket%d" % index
	bay.position = Vector2(BAY_LEFT + index * BAY_STEP, 0)
	bay.size = Vector2(BAY_WIDTH, WALL_SHELF_Y)
	bay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bay)
	bays.append(bay)
	for x: float in [SIGN.position.x + 44, SIGN.end.x - 48]:
		StartBoardKit.panel(bay, Rect2(x, RAIL.end.y, 4, SIGN.position.y - RAIL.end.y), Palette.INK)
	var tab: bool = can_change(index)
	var board: Panel = _sign(bay, setup.baskets[index].source, SIGN, tab)
	board.name = "Sign"
	signs.append(board)
	if tab:
		board.mouse_filter = Control.MOUSE_FILTER_STOP
		board.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		board.tooltip_text = "Change this basket's aisle"
		board.pivot_offset = (board.size / 2).floor()
		board.gui_input.connect(_sign_input.bind(index))
		board.mouse_entered.connect(_sign_hover.bind(index, true))
		board.mouse_exited.connect(_sign_hover.bind(index, false))
		if fresh.has(NEW_AISLE):
			_new_tag(board, Vector2(board.size.x - 20, -18))
	var bob: Control = Control.new()
	bob.name = "Bob"
	bob.size = bay.size
	bob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The redraw's hover pivot: the basket's centre-bottom.
	bob.pivot_offset = Vector2(
		BASKET_X + floorf(BASKET_FRONT.get_width() * BASKET_SCALE / 2.0), _basket_bottom()
	)
	bay.add_child(bob)
	_fill_basket(bob, index)
	_sign_hover(index, false)


## The basket's back, its two items, its front and their price tags, its stamp, and its pick
## area (in `bob`, the part that moves with a restock pick's hover and a restock's dip).
func _fill_basket(bob: Control, index: int) -> void:
	var setup: StartSetup = _run.start_setup
	var basket_width: float = BASKET_FRONT.get_width() * BASKET_SCALE
	var front_top: float = _front_top()
	_art(bob, BASKET_BACK, Vector2(BASKET_X, front_top - 16)).name = "Back"
	var cards: Array[CardDefinition] = setup.baskets[index].cards
	var pair: float = cards.size() * ITEM_SIZE + maxf(cards.size() - 1, 0) * ITEM_GAP
	var left: float = BASKET_X + floorf((basket_width - pair) / 4.0) * 2
	var hosts: Array[Control] = []
	for at: int in cards.size():
		var host: Control = StartBoardKit.item(
			bob, cards[at], Vector2(left + at * (ITEM_SIZE + ITEM_GAP), ITEM_TOP), ITEM_SIZE
		)
		host.name = "Item%d" % at
		host.pivot_offset = Vector2(ITEM_SIZE / 2, ITEM_SIZE)
		hosts.append(host)
	items.append(hosts)
	_art(bob, BASKET_FRONT, Vector2(BASKET_X, front_top)).name = "Front"
	var tag_y: float = front_top + floorf(BASKET_FRONT.get_height() * BASKET_SCALE * 0.21) * 2
	for at: int in cards.size():
		var x: float = left + at * (ITEM_SIZE + ITEM_GAP) + ITEM_SIZE / 2 - 24
		var tag: Panel = StartBoardKit.panel(bob, Rect2(x, tag_y, 48, 30), Palette.CREAM)
		tag.name = "Price%d" % at
		var price: Label = StartBoardKit.number(
			tag, "%d€" % cards[at].base, Rect2(0, 0, 48, 28), Palette.INK, 24
		)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bottom: float = front_top + BASKET_FRONT.get_height() * BASKET_SCALE
	if setup.restocked(index):
		var stamp: Panel = StartBoardKit.panel(
			bob, Rect2(BASKET_X + basket_width / 2 - 66, bottom - 30, 132, 26), Palette.PAPER
		)
		stamp.name = "Stamp"
		var style: StyleBoxFlat = stamp.get_theme_stylebox("panel") as StyleBoxFlat
		style.border_color = Palette.TOMATO_DARK
		style.set_border_width_all(3)
		stamp.pivot_offset = stamp.size / 2
		stamp.rotation = deg_to_rad(-8)
		StartBoardKit.tag(stamp, "RESTOCKED", Rect2(0, 0, 132, 24), Palette.TOMATO_DARK, 2, true)
	var hit: Control = Control.new()
	hit.name = "Hit"
	var rect: Rect2 = basket_rect(index)
	hit.position = rect.position - Vector2(BAY_LEFT + index * BAY_STEP, 0)
	hit.size = rect.size
	hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit.gui_input.connect(_basket_input.bind(index))
	bob.add_child(hit)
	hits.append(hit)


func _art(parent: Control, texture: Texture2D, at: Vector2) -> TextureRect:
	var sprite: TextureRect = UiKit.sprite(texture)
	sprite.position = at
	sprite.size = texture.get_size() * BASKET_SCALE
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sprite)
	return sprite


## Today's extra aisle: a small sign at the rail's end, RUN-ONLY under it, its capsules and one
## line.
func _add_extra() -> void:
	var run_only: Array[StringName] = _run.start_setup.run_only_ids(_run.balance)
	if run_only.is_empty():
		return
	extra = Control.new()
	extra.name = "Extra"
	extra.size = ShiftStage.SIZE
	extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(extra)
	for x: float in [EXTRA.position.x + 38, EXTRA.end.x - 42]:
		StartBoardKit.panel(
			extra, Rect2(x, RAIL.end.y, 4, EXTRA.position.y - RAIL.end.y), Palette.INK
		)
	var board: Panel = _sign(extra, run_only[0], EXTRA, false)
	board.name = "Sign"
	board.mouse_filter = Control.MOUSE_FILTER_PASS
	board.tooltip_text = "Today's extra aisle: in stock for machine prizes, drawn each run"
	_run_only_caption(Vector2(EXTRA.get_center().x, EXTRA.end.y + 8))
	var capsule: Texture2D = load(CAPSULE_PATH % run_only[0]) as Texture2D
	var row: float = 3 * 39 + 2 * 6
	for at: int in 3:
		var left: float = floorf((EXTRA.get_center().x - row / 2) / 2.0) * 2 + at * 45
		StartBoardKit.icon(extra, capsule, Vector2(left, 252), 3).name = "Capsule%d" % at
	var line: Label = StartBoardKit.body(
		extra,
		"Available as machine prizes.",
		Rect2(EXTRA.position.x - 10, 300, EXTRA.size.x + 20, 22),
		Palette.TEAL_PALE,
		14
	)
	line.name = "Line"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_override("font", ArtStyle.bold_font(700))


## RUN-ONLY centred on `centre` (its top): the pixel font's hyphen has no left side bearing (it
## touched the N), so the hyphen is set on its own, 4 px after RUN.
func _run_only_caption(centre: Vector2) -> void:
	var caption: Control = Control.new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extra.add_child(caption)
	var parts: PackedStringArray = ["RUN", "-ONLY"]
	var width: float = 4.0 + StartBoardKit.text_width(parts[0]) + StartBoardKit.text_width(parts[1])
	caption.position = Vector2(2.0 * floorf((centre.x - width / 2.0) / 2.0), centre.y)
	caption.size = Vector2(width, 20)
	var x: float = 0
	for part: String in parts:
		var part_width: float = StartBoardKit.text_width(part)
		StartBoardKit.tag(caption, part, Rect2(x, 0, part_width + 2, 20), Palette.MUSTARD_LIGHT)
		x += part_width + 4


## The one RESTOCK key by the baskets (from restock_min_completed): RESTOCK, then PICK A BASKET
## while a pick waits, then RESTOCK USED (grey) once spent.
func _add_restock_key() -> void:
	if not restock_unlocked():
		return
	var used: bool = _run.start_setup.restock_basket >= 0
	restock_key = StartBoardKit.key(self, "", RESTOCK, func() -> void: restock_pressed.emit())
	restock_key.name = "Restock"
	var face: Color = Palette.MUSTARD
	var edge: Color = Palette.INK
	var ink: Color = Palette.INK
	var title: String = "RESTOCK"
	var line: String = "one basket, once a run"
	if used:
		face = Palette.TEAL_DARK
		edge = Palette.TEAL_SHADE
		ink = Palette.TEAL_LIGHT
		title = "RESTOCK USED"
		line = ""
		restock_key.disabled = true
		restock_key.tooltip_text = "RESTOCK used this run"
	elif restock_picking:
		face = Palette.PAPER
		title = "PICK A BASKET"
		line = "Esc cancels"
		restock_key.tooltip_text = "Click a basket, or press 1, 2 or 3"
	elif not can_restock():
		restock_key.disabled = true
		restock_key.tooltip_text = "No other pair of products fits these baskets"
	else:
		restock_key.tooltip_text = "Replace both items of one basket (R), once a run"
	StartBoardKit.restyle(restock_key, face, edge, 3)
	var caption: Label = StartBoardKit.key_caption(restock_key)
	caption.text = title.replace(" ", "  ")
	caption.add_theme_color_override("font_color", ink)
	var icon: TextureRect = StartBoardKit.icon(restock_key, RESTOCK_ICON, Vector2(14, 14), 2)
	icon.name = "Icon"
	icon.modulate = ink
	icon.visible = not restock_picking
	if restock_picking:
		_add_cross(restock_key, ink)
	var left: float = 42.0
	UiKit.place_pixel_label(caption, Rect2(left, 0, 200, 42), true)
	if line != "":
		var small: Label = StartBoardKit.body(
			restock_key,
			line,
			Rect2(left + StartBoardKit.text_width(caption.text) + 10, 11, 150, 20),
			Palette.WOOD_DARK if not restock_picking else Palette.INK_LIGHT,
			13
		)
		small.name = "Line"
		small.add_theme_font_override("font", ArtStyle.bold_font(700))
	if fresh.has(NEW_RESTOCK) and not used:
		_new_tag(restock_key, Vector2(RESTOCK.size.x - 22, -16))


## The armed key's close cross (the mock-up's "✕ Pick a basket"): pressing the key again cancels.
func _add_cross(key: Button, ink: Color) -> void:
	var cross: Control = Control.new()
	cross.name = "Cross"
	cross.position = Vector2(16, 15)
	cross.size = Vector2(14, 14)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(
		func() -> void:
			for step: int in 7:
				cross.draw_rect(Rect2(step * 2, step * 2, 3, 3), ink)
				cross.draw_rect(Rect2(12 - step * 2, step * 2, 3, 3), ink)
	)
	key.add_child(cross)


## YOUR REGULARS: the heading (and the SWAPS pips once swaps are unlocked), the four tiles on
## their shelf, each with its swap badge or its put-back tag.
func _add_regulars() -> void:
	var shelf: Control = Control.new()
	shelf.name = "Regulars"
	shelf.size = ShiftStage.SIZE
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shelf)
	var left: float = _tile_left(0)
	var heading: Label = StartBoardKit.words(
		shelf, "YOUR REGULARS", Rect2(left - 2, REGULARS_TOP, 220, 28), Palette.MUSTARD_LIGHT
	)
	heading.name = "Heading"
	var sub_left: float = left + StartBoardKit.text_width(heading.text) + 12
	var sub: Label = StartBoardKit.body(
		shelf, "in every run", Rect2(sub_left, REGULARS_TOP + 4, 96, 22), Palette.TEAL_LIGHT, 15
	)
	sub.name = "Subtitle"
	sub.add_theme_font_override("font", ArtStyle.bold_font(700))
	var limit: int = StartSetupRules.swap_limit(_run, _profile)
	if limit > 0:
		_add_swap_chip(shelf, Vector2(sub_left + 104, REGULARS_TOP + 1), limit)
	var count: int = _run.starter.core_cards.size()
	var width: float = count * StartItemTile.SIZE.x + (count - 1) * TILE_GAP
	var plank: Panel = StartBoardKit.plank(
		shelf, Rect2(left - 40, TILE_TOP + StartItemTile.SHELF_Y, width + 80, PLANK)
	)
	plank.name = "Shelf"
	for slot: int in count:
		_add_tile(shelf, slot)


func _add_swap_chip(parent: Control, at: Vector2, limit: int) -> void:
	var used: int = StartSetupRules.applied_swaps(_run)
	var pips_left: float = 18 + StartBoardKit.text_width("SWAPS")
	var width: float = pips_left + limit * 14 + 6
	swap_chip = StartBoardKit.panel(parent, Rect2(at, Vector2(width, 28)), Palette.TEAL_SHADE)
	swap_chip.name = "Swaps"
	swap_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	swap_chip.tooltip_text = (
		"One swap per completed aisle, up to %d: %d left"
		% [_run.starter.core_cards.size(), limit - used]
	)
	var words: Label = StartBoardKit.tag(swap_chip, "SWAPS", Rect2(8, 0, 60, 28), Palette.PAPER)
	UiKit.place_pixel_label(words, Rect2(8, 0, 60, 28), true)
	for pip: int in limit:
		var dot: Panel = StartBoardKit.panel(
			swap_chip,
			Rect2(pips_left + pip * 14, 8, 12, 12),
			Palette.TEAL_DARK if pip < used else Palette.GOLD
		)
		dot.name = "Pip%d" % pip
	if fresh.has(NEW_SWAP):
		# Beside the chip, not above it: above, it reaches into basket 3's RESTOCK THIS cue.
		_new_tag(swap_chip, Vector2(width + 8, 2))


func _add_tile(parent: Control, slot: int) -> void:
	var holder: Control = Control.new()
	holder.name = "Regular%d" % slot
	holder.position = Vector2(_tile_left(slot), TILE_TOP)
	holder.size = StartItemTile.SIZE
	parent.add_child(holder)
	regulars.append(holder)
	var card: CardDefinition = _run.starter.core_cards[slot]
	var tile: StartItemTile = StartItemTile.new(card)
	tile.name = "Tile"
	tile.pivot_offset = StartItemTile.SIZE / 2
	holder.add_child(tile)
	var selected: Panel = StartBoardKit.panel(
		holder, Rect2(Vector2(-6, -6), StartItemTile.SIZE + Vector2(12, 12)), Color(0, 0, 0, 0)
	)
	selected.name = "Selected"
	var style: StyleBoxFlat = selected.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Palette.GOLD
	style.set_border_width_all(4)
	# A ring only: no face and no shadow, or Godot fills the centre and greys the tile out.
	style.draw_center = false
	style.shadow_size = 0
	selected.visible = slot == open_slot
	var open: bool = can_swap(slot)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_PASS
	if open:
		holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		holder.tooltip_text = "Swap %s" % card.display_name
		holder.gui_input.connect(_tile_input.bind(slot))
		holder.mouse_entered.connect(_tile_hover.bind(slot, true))
		holder.mouse_exited.connect(_tile_hover.bind(slot, false))
	var original: CardDefinition = _run.start_setup.originals[slot]
	if card != original:
		var undo: Button = StartBoardKit.key(
			holder, "", Rect2(_undo_at(tile), UNDO), func() -> void: undo_clicked.emit(slot)
		)
		undo.name = "Undo"
		undo.tooltip_text = "Back to %s" % original.display_name
		StartBoardKit.restyle(undo, Palette.PAPER, Palette.INK, 3)
		StartBoardKit.icon(undo, RESTOCK_ICON, Vector2(6, 7), 2).modulate = Palette.INK
		var small: Control = StartBoardKit.item(undo, original, Vector2(28, 2), 22)
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		small.remove_meta("card")
	elif open:
		var badge: Panel = StartBoardKit.panel(
			holder, Rect2(_badge_at(tile), BADGE * Vector2.ONE), Palette.TEAL_SHADE
		)
		badge.name = "Badge"
		(badge.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(3)
		StartBoardKit.icon(badge, SWAP_ICON, Vector2(6, 5), 2).name = "Arrows"
	_lift(slot, 8.0 if slot == open_slot else 0.0)


func _tile_input(event: InputEvent, slot: int) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not restock_picking:
			regular_clicked.emit(slot)


func _tile_hover(slot: int, inside: bool) -> void:
	if slot >= regulars.size() or slot == open_slot or restock_picking:
		return
	var holder: Control = regulars[slot]
	_lift(slot, 6.0 if inside else 0.0)
	var badge: Panel = holder.get_node_or_null("Badge") as Panel
	if badge != null:
		var style: StyleBoxFlat = badge.get_theme_stylebox("panel") as StyleBoxFlat
		style.bg_color = Palette.MUSTARD if inside else Palette.TEAL_SHADE
		(badge.get_node("Arrows") as CanvasItem).modulate = Palette.INK if inside else Color.WHITE


## Lifts regular `slot`'s item art `by` px off its shelf, its swap badge or put-back tag with it
## (its sticker stays on the shelf's edge).
func _lift(slot: int, by: float) -> void:
	var tile: StartItemTile = regulars[slot].get_node("Tile") as StartItemTile
	tile.art.position.y = StartItemTile.SHELF_Y - StartItemTile.ART - by
	var badge: Control = regulars[slot].get_node_or_null("Badge") as Control
	if badge != null:
		badge.position = _badge_at(tile)
	var undo: Control = regulars[slot].get_node_or_null("Undo") as Control
	if undo != null:
		undo.position = _undo_at(tile)


## Where a swapped regular's put-back tag sits (holder px): in the swap badge's place, its
## top-right corner on the badge's (so it reaches left over the art, never into the next lane).
static func _undo_at(tile: StartItemTile) -> Vector2:
	return _badge_at(tile) + Vector2(BADGE - UNDO.x, 0)


## Where a regular's swap badge sits (holder px): at its art's visible top-right corner, BADGE_GAP
## px clear of the art's opaque pixels (beside the art when it fits inside the tile's lane, else
## just over the art's pixels under it, e.g. a carton's shoulder).
static func _badge_at(tile: StartItemTile) -> Vector2:
	var art: Rect2 = tile.art_bounds()
	var x: float = minf(
		2.0 * ceilf((art.end.x + BADGE_GAP) / 2.0), StartItemTile.SIZE.x + BADGE_REACH - BADGE
	)
	var under: float = tile.art_top_over(x - BADGE_GAP, x + BADGE + BADGE_GAP)
	var y: float = minf(art.position.y - BADGE / 2.0, under - BADGE_GAP - BADGE)
	return Vector2(x, 2.0 * floorf(y / 2.0))


func _sign_input(event: InputEvent, basket: int) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not restock_picking:
			sign_clicked.emit(basket)


## Lights sign `basket`'s swap tab (mustard, a slight tilt) while hovered or while its pop-up is
## open.
func _sign_hover(basket: int, inside: bool) -> void:
	if basket < 0 or basket >= signs.size():
		return
	var board: Panel = signs[basket]
	var tab: Panel = board.get_node_or_null("SwapTab") as Panel
	if tab == null:
		return
	var lit: bool = inside or basket == open_basket
	var style: StyleBoxFlat = tab.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = Palette.MUSTARD if lit else Palette.TEAL_SHADE
	(tab.get_node("Arrows") as CanvasItem).modulate = Palette.INK if lit else Color.WHITE
	board.rotation = deg_to_rad(-1.2) if lit and not _reduced else 0.0


func _basket_input(event: InputEvent, basket: int) -> void:
	if not restock_picking:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		basket_clicked.emit(basket)


## While a pick waits (the shift's redraw mode): each basket that can be restocked becomes a click
## target with the redraw's teal tag on its front, reading RESTOCK; the rest of the page stays
## as it is.
func _show_picking() -> void:
	if not restock_picking:
		return
	for index: int in hits.size():
		if StartSetupRules.restock_block(_run, _profile, index) != &"":
			continue
		var hit: Control = hits[index]
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var bob: Control = bays[index].get_node("Bob") as Control
		var tag: RedrawTag = RedrawTag.new(RESTOCK_WORD)
		tag.name = "Tag"
		tag.ring = false
		bob.add_child(tag)
		_place_tag(tag)
		tag.resized.connect(_place_tag.bind(tag))
		hit.mouse_entered.connect(_pick_hover.bind(index, true))
		hit.mouse_exited.connect(_pick_hover.bind(index, false))


## Basket `basket`'s RESTOCK tag (null: not waiting for a pick, or it can't be restocked).
func restock_tag(basket: int) -> RedrawTag:
	if basket < 0 or basket >= bays.size():
		return null
	return bays[basket].get_node_or_null("Bob/Tag") as RedrawTag


## The tag centred on its basket's front, its top TAG_RISE px above the basket's foot.
func _place_tag(tag: RedrawTag) -> void:
	var centre: float = BASKET_X + BASKET_FRONT.get_width() * BASKET_SCALE / 2.0
	var top: float = 2.0 * roundf((_basket_bottom() - TAG_RISE) / 2.0)
	tag.position = Vector2(2.0 * roundf((centre - tag.tag_width() / 2.0) / 2.0), top)


## A restock pick's hover, as the redraw's (BasketRedraw.hover): the tag goes hot and names how
## many items go; with motion the basket eases up hover_lift px and wobbles about its centre-bottom,
## and eases back on leaving.
func _pick_hover(basket: int, inside: bool) -> void:
	var tag: RedrawTag = restock_tag(basket)
	if tag == null:
		return
	tag.set_hot(inside, _run.start_setup.baskets[basket].cards.size())
	_place_tag(tag)
	if _reduced:
		return
	_loops.append(_hover.play(basket, bays[basket].get_node("Bob") as Control, inside))


## The baskets' foot (stage y): the bottom of their front.
func _basket_bottom() -> float:
	return _front_top() + BASKET_FRONT.get_height() * BASKET_SCALE


## A red NEW tag at `at` on `parent`, tilted and (with motion) pulsing.
func _new_tag(parent: Control, at: Vector2) -> Panel:
	var tag: Panel = StartBoardKit.panel(parent, Rect2(at, Vector2(44, 24)), Palette.TOMATO)
	tag.name = "New"
	(tag.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(3)
	tag.pivot_offset = tag.size / 2
	tag.rotation = deg_to_rad(8)
	StartBoardKit.tag(tag, "NEW", Rect2(0, 0, 44, 22), Palette.PAPER, 2, true)
	if not _reduced:
		var tween: Tween = tag.create_tween().set_loops()
		tween.tween_property(tag, "scale", Vector2.ONE * 1.12, 0.5).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(tag, "rotation", deg_to_rad(4), 0.5)
		tween.tween_property(tag, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(tag, "rotation", deg_to_rad(8), 0.5)
		_loops.append(tween)
	return tag


## The page's drop-in: the bays, the extra aisle and the regulars drop and settle, staggered.
func play_intro() -> void:
	if _reduced or not is_inside_tree():
		return
	var parts: Array[Control] = []
	parts.append_array(bays)
	if extra != null:
		parts.append(extra)
	parts.append_array(regulars)
	for at: int in parts.size():
		var part: Control = parts[at]
		var rest: Vector2 = part.position
		part.position = rest - Vector2(0, 40)
		part.modulate.a = 0.0
		var tween: Tween = part.create_tween()
		tween.tween_interval(at * 0.06)
		tween.tween_property(part, "position", rest, DROP_S).set_trans(Tween.TRANS_BACK).set_ease(
			Tween.EASE_OUT
		)
		tween.parallel().tween_property(part, "modulate:a", 1.0, DROP_S * 0.5)
		_tweens.append(tween)


## Basket `basket` dealt again (RESTOCK or an aisle change): `before`'s items hop out of it, then
## its new pair drops in with a bounce and a few gold sparks.
func play_redeal(basket: int, before: Array[CardDefinition]) -> void:
	if _reduced or not is_inside_tree() or basket < 0 or basket >= bays.size():
		return
	var bob: Control = bays[basket].get_node("Bob") as Control
	var hosts: Array = items[basket]
	var front: Control = bob.get_node("Front") as Control
	for at: int in before.size():
		var x: float = BASKET_X + 26 + at * (ITEM_SIZE + ITEM_GAP)
		if at < hosts.size():
			x = (hosts[at] as Control).position.x
		var ghost: Control = StartBoardKit.item(bob, before[at], Vector2(x, ITEM_TOP), ITEM_SIZE)
		ghost.name = "Ghost%d" % at
		ghost.remove_meta("card")
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.pivot_offset = Vector2(ITEM_SIZE / 2, ITEM_SIZE)
		bob.move_child(ghost, front.get_index())
		var out: Tween = ghost.create_tween()
		out.tween_interval(at * ITEM_STAGGER_S)
		out.tween_property(ghost, "position:y", ITEM_TOP - 100, HOP_S).set_ease(Tween.EASE_IN)
		out.parallel().tween_property(ghost, "rotation", deg_to_rad(-14), HOP_S)
		out.parallel().tween_property(ghost, "modulate:a", 0.0, HOP_S)
		out.tween_callback(ghost.queue_free)
		_tweens.append(out)
	for at: int in hosts.size():
		var host: Control = hosts[at]
		host.position.y = ITEM_TOP - 146
		host.modulate.a = 0.0
		var drop: Tween = host.create_tween()
		drop.tween_interval(HOP_S + at * ITEM_STAGGER_S)
		drop.tween_property(host, "modulate:a", 1.0, 0.05)
		(
			drop
			. tween_property(host, "position:y", ITEM_TOP, PAIR_DROP_S)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
		_tweens.append(drop)
		# The basket dips as each item lands (the redraw's landing).
		var dip: Tween = bob.create_tween()
		dip.tween_interval(landing_s(at))
		dip.tween_property(bob, "position:y", LAND_DIP, LAND_DIP_S * 0.4).set_ease(Tween.EASE_OUT)
		dip.tween_property(bob, "position:y", 0.0, LAND_DIP_S * 0.6).set_ease(Tween.EASE_IN_OUT)
		_tweens.append(dip)
	_sparks(bays[basket].position + Vector2(BAY_WIDTH / 2, ITEM_TOP + 48), HOP_S + 0.3)


## When new item `at` of a restock lands (s after the click): the moment its drop first reaches
## the basket (its back ease overshoots, then settles).
static func landing_s(at: int) -> float:
	return HOP_S + at * ITEM_STAGGER_S + PAIR_DROP_S * 0.45


## Regular `slot` flips to its new card, with a few gold sparks.
func play_flip(slot: int) -> void:
	if _reduced or not is_inside_tree() or slot < 0 or slot >= regulars.size():
		return
	var tile: Control = regulars[slot].get_node("Tile") as Control
	tile.scale = Vector2(0, 1)
	var tween: Tween = tile.create_tween()
	tween.tween_property(tile, "scale", Vector2(1.12, 1), FLIP_S * 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "scale", Vector2.ONE, FLIP_S * 0.4)
	_tweens.append(tween)
	_sparks(regulars[slot].position + StartItemTile.SIZE / 2, 0.1)


## Sign `basket` wiggles (its aisle changed).
func play_wiggle(basket: int) -> void:
	if _reduced or basket < 0 or basket >= signs.size():
		return
	var board: Panel = signs[basket]
	var tween: Tween = board.create_tween()
	for angle: float in [-3.0, 3.0, 0.0]:
		tween.tween_property(board, "rotation", deg_to_rad(angle), 0.1)
	_tweens.append(tween)


func _sparks(centre: Vector2, delay: float) -> void:
	for at: int in 10:
		var spark: Panel = StartBoardKit.panel(self, Rect2(centre, Vector2(8, 8)), Palette.GOLD)
		spark.name = "Spark%d" % at
		spark.modulate.a = 0.0
		var tween: Tween = spark.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(spark, "modulate:a", 1.0, 0.01)
		tween.tween_property(
			spark, "position", centre + Vector2.from_angle(TAU * at / 10.0) * 70, 0.6
		)
		tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.6)
		tween.tween_callback(spark.queue_free)
		_tweens.append(tween)


## Ends the one-shot motion at its last frame and stops the loops.
func skip_deal() -> void:
	for tween: Tween in _tweens + _loops:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	_loops.clear()
	for child: Node in get_children():
		if String(child.name).begins_with("Spark"):
			child.queue_free()
	for index: int in bays.size():
		var bay: Control = bays[index]
		bay.position = Vector2(BAY_LEFT + index * BAY_STEP, 0)
		bay.modulate.a = 1.0
		(bay.get_node("Bob") as Control).position = Vector2.ZERO
		(bay.get_node("Bob") as Control).rotation = 0.0
		for child: Node in bay.get_node("Bob").get_children():
			if String(child.name).begins_with("Ghost"):
				child.queue_free()
		for host: Control in items[index]:
			host.position.y = ITEM_TOP
			host.modulate.a = 1.0
	if extra != null:
		extra.position = Vector2.ZERO
		extra.modulate.a = 1.0
	for slot: int in regulars.size():
		var holder: Control = regulars[slot]
		holder.position = Vector2(_tile_left(slot), TILE_TOP)
		holder.modulate.a = 1.0
		_lift(slot, 8.0 if slot == open_slot else 0.0)
		(holder.get_node("Tile") as Control).scale = Vector2.ONE


## Whether one-shot motion is playing.
func is_dealing() -> bool:
	for tween: Tween in _tweens:
		if tween.is_valid() and tween.is_running():
			return true
	return false


## Aisle `id`'s definition in `run`'s balance (null: the Staples shelf or unknown).
static func aisle_of(run: RunState, id: StringName) -> AisleDefinition:
	for aisle: AisleDefinition in run.balance.aisles:
		if aisle.id == id:
			return aisle
	return null
