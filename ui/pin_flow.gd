class_name PinFlow
extends RefCounted
## The #132 badge pins on the shift screen (PinPlay; picked by the user on 2026-11-02). Split out
## of ShiftScreen to keep that file short; like RepackFlow it is a part of the screen and works on
## its run and display.
## - Stock list: in redraw mode a hovered basket's monitor panel shows the items its redraw
##   would bring (RedrawNotice.of_run, PinPlay.peek; the user's call of 2026-11-02).
## - Day off: the day calendar's SKIP tag (DayTags.show_skip; the user's calls of 2026-11-02)
##   puts a pile of gold with the quota's burst on belt slot 1 (DayOffPile): the belt's items go
##   back to the hand and the belt takes none while it is there; the tag reads UNDO. A click on
##   the tag or the pile takes it back. CHECKOUT takes the day off (take_day_off): the shift
##   passes on its quota with no count-up, and the machine opens as after any pass.
## - Price gun: the labeller lies on the counter in front of the printer (PriceGunItem, with the
##   relabels left on its tag); a click picks it up (armed), then a click on a product (hand or
##   belt) opens the family picker (PriceGunPicker); the item wears a price tag with the family's
##   glyph while relabelled.
## - Golden basket: the first basket is gold; after the count-up, before the machine, the keep
##   screen (KeepScreen) shows the golden basket and the checked-out items to drag into it.
## - Every worn pin: on the name badge's lanyard from the monitor (PinLanyard), its card on hover
##   (or kept by a click) in planning only (_pin_card_blocked).
## It also holds the #122 pins' parts the screen refreshes with them: Repack's (RepackFlow,
## `repack`) and Double checkout's (DoubleCheckoutFlow.refresh, count_row_one).

## Sent when the keep screen closes (keep_items awaits it).
signal keep_done

const DAY_OFF_ARMED := "Day off: CHECKOUT takes it (passed on quota), UNDO takes it back"
const DAY_OFF_LOCKED := "Day off: the belt holds the pile. UNDO to play items"
const DAY_OFF_DONE := "Day off: today passes on quota"
const GUN_ARMED := "Price gun: click an item to give it a family"
const GUN_NONE := "Price gun: pick a product"
const GUN_EMPTY := "Price gun: no tag left this shift; click the tagged item to move it"
## The price tag on a relabelled item: its size and offset from the item's sprite's
## bottom left.
const TAG_SIZE := Vector2(26, 26)
const TAG_OFFSET := Vector2(2, -4)
const TAG_NODE := "PriceGunTag"

## Repack's drag between the hand's baskets (#122).
var repack: RepackFlow
## The Family stickers' family tags and picker (v1.29).
var stickers: FamilyStickerFlow
var _screen: ShiftScreen
var _log: EventLogService
var _gun_armed: bool = false
var _picker: PriceGunPicker
## The labeller on the counter, built when first needed.
var _gun: PriceGunItem
var _keep_panel: KeepScreen
## Day off's pile of gold on the belt, from SKIP until it is taken back or the next shift's
## planning (RunState.day_off_pending while it waits for CHECKOUT).
var _pile: DayOffPile


func _init(screen: ShiftScreen, event_log: EventLogService) -> void:
	_screen = screen
	_log = event_log
	repack = RepackFlow.new(screen, event_log)
	stickers = FamilyStickerFlow.new(screen, event_log)
	_screen._calendar.skip_pressed.connect(press_day_off)
	_screen._stage.pin_lanyard.reduced_motion = _reduced
	_screen._stage.pin_lanyard.blocked = _pin_card_blocked


## Shows the pins' parts for the run as it is now (call after the hand and belt are shown):
## Repack's, the #132 pins', then Double checkout's.
func refresh() -> void:
	repack.refresh()
	_show_pins()
	DoubleCheckoutFlow.refresh(_screen)


func _show_pins() -> void:
	var run: RunState = _screen.run
	if run == null:
		return
	var planning: bool = run.phase == RunState.Phase.PLANNING and not _screen._busy()
	var gold: Array[int] = []
	if PinPlay.keep_count(run) > 0:
		gold.append(0)
	_screen._stage.baskets.set_gold(gold)
	_screen._stage.basket_fronts.set_gold(gold)
	_show_gun(planning)
	_show_skip(planning)
	stickers.refresh()
	_show_tags()
	_screen._stage.pin_lanyard.show_run(run)
	if not planning:
		_close_picker()
	if run.phase == RunState.Phase.PLANNING and not run.day_off_pending and _pile != null:
		_pile.queue_free()
		_pile = null


## Day off's pile (for tests), or null.
func pile() -> DayOffPile:
	return _pile


## Puts the day's pile of gold for `quota` on belt slot 1 (DayOffPile), dropping.
func _drop_pile(quota: int) -> void:
	if _pile != null:
		_pile.queue_free()
	_pile = DayOffPile.new(quota)
	_pile.pressed.connect(press_day_off)
	var belt: Control = _screen._stage.belt
	belt.add_child(_pile)
	var first: Rect2 = RowStrip.footprint(_screen._slots[0]).get_global_rect()
	var foot: Vector2 = belt.get_global_transform().affine_inverse() * first.get_center()
	_pile.stand_at(foot + Vector2(0.0, first.size.y / 2.0))
	_pile.drop(_reduced(), _screen._sfx)


## Whether a Day off's pile waits on the belt for CHECKOUT.
func day_off_pending() -> bool:
	return _screen.run != null and _screen.run.day_off_pending


## After a checkout that left the run planning, a Double checkout's row 1 (#122): counts it
## alone (DoubleCheckoutFlow.count_row_one, the belt's `committed` cards); whether it did.
func count_row_one(committed: Array[CardInstance]) -> bool:
	if _screen.run.phase != RunState.Phase.PLANNING:
		return false
	await DoubleCheckoutFlow.count_row_one(_screen, committed)
	return true


## Whether the price gun shows now (for tests): Price gun worn, in planning.
func gun_shown() -> bool:
	return _gun != null and _gun.visible


## The labeller on the counter (for tests), or null before it was needed.
func gun() -> PriceGunItem:
	return _gun


## Takes a click on an item while the Price gun is armed: a product opens the family picker. True
## when the click was the gun's (the screen does nothing else with it).
func take_click(card: CardInstance) -> bool:
	if day_off_pending():
		_screen._notice_label.show_notice(DAY_OFF_LOCKED)
		_screen._sfx.play("denied")
		return true
	if not _gun_armed:
		return false
	var tags: PackedStringArray = _picker_tags(card)
	if tags.is_empty() and PinPlay.relabel_of(_screen.run, card).is_empty():
		var none_left: bool = card.definition.is_product() and _left() <= 0
		_screen._notice_label.show_notice(GUN_EMPTY if none_left else GUN_NONE)
		return true
	_open_picker(card, tags)
	return true


## The keep panel after a checkout (Golden basket): waits until the player closes it; at once
## when there is nothing to keep.
func keep_items() -> void:
	var cards: Array[CardInstance] = PinPlay.keepable(_screen.run)
	if cards.is_empty():
		return
	_open_keep()
	await keep_done


## The keep panel, while open (for tests).
func keep_panel() -> KeepScreen:
	return _keep_panel


## The family picker, while open (for tests).
func picker() -> PriceGunPicker:
	return _picker


## Day off: SKIP puts the pile on belt slot 1 (the belt's items back to the hand); UNDO, or a
## click on the pile, takes it back. CHECKOUT takes the day off (take_day_off).
func press_day_off() -> void:
	var run: RunState = _screen.run
	if not PinPlay.can_take_day_off(run) or _screen._busy() or _screen._redraw_busy:
		return
	_screen._drop_pick()
	_screen._drag.cancel()
	PinPlay.set_day_off(run, not run.day_off_pending)
	if run.day_off_pending:
		_screen._sfx.play("card_return")
		_screen._refresh()
		_screen._save_run()
		_drop_pile(run.quota())
		_screen._notice_label.show_notice(DAY_OFF_ARMED)
	else:
		if _pile != null:
			_pile.lift(_reduced(), _screen._sfx)
			_pile = null
		_screen._notice_label.end_notice()
		_screen._refresh()


## A click on the labeller: picks it up (armed) or puts it down.
func press_gun() -> void:
	if PinPlay.relabels_per_shift(_screen.run) <= 0 or not gun_shown():
		return
	_gun_armed = not _gun_armed
	_close_picker()
	if _gun_armed:
		_screen._notice_label.show_notice(GUN_ARMED if _left() > 0 else GUN_EMPTY)
	else:
		_screen._notice_label.end_notice()
	_show_gun(true)


## CHECKOUT with the pile on the belt (false, doing nothing, without one): the skipped shift,
## logged, saved (the machine is a save point), the day's pip lit on the calendar, then the
## machine opens as after a checkout (or, with no visit, the next shift starts).
func take_day_off() -> bool:
	var run: RunState = _screen.run
	if not run.day_off_pending:
		return false
	run.day_off_pending = false
	if _pile != null:
		_pile.cash(_reduced())
	_screen._drop_pick()
	_screen._drag.cancel()
	_screen._scan.clear()
	_screen._effects.clear()  # The belt's items go: their stickers and tags with them.
	var result: ScoreResult = run.checkout(true)
	if result == null:
		return true
	_log.log_event("day_off", {"shift": run.shift_index + 1, "quota": run.quota()})
	_screen._stage.bell.ding()  # CHECKOUT's sound: the service bell (play test 2026-11-09).
	_screen._save_run()
	_screen._refresh()
	_screen._notice_label.show_notice(DAY_OFF_DONE)
	await _screen._week.light_day()
	if run.phase == RunState.Phase.MACHINE_CHOOSE:
		_screen._machine.open(false)
	elif run.phase == RunState.Phase.SCORED:
		ShiftMusic.next_shift_started(_screen._music)
		run.next_shift()
		_screen._on_shift_started()
	return true


## The labeller: Price gun's, in planning only and never in redraw mode.
func _show_gun(planning: bool) -> void:
	var shown: bool = planning and not _screen._redraw_mode
	shown = shown and PinPlay.relabels_per_shift(_screen.run) > 0
	if not shown:
		_gun_armed = false
	if _gun == null:
		if not shown:
			return
		_build_gun()
	_gun.visible = shown
	_gun.show_gun(_left(), _gun_armed)


## The relabels left this shift.
func _left() -> int:
	return PinPlay.relabels_left(_screen.run)


## The labeller on the counter, in the stage's fore (it drops with the counter) under the belt: it
## lies left of the belt, over the bagging shelf's side.
func _build_gun() -> void:
	_gun = PriceGunItem.new()
	_gun.reduced_motion = _reduced
	_gun.pressed.connect(press_gun)
	var fore: Control = _screen._stage.fore
	fore.add_child(_gun)
	fore.move_child(_gun, _screen._stage.belt.get_index())


func _reduced() -> bool:
	return _screen.profile != null and _screen.profile.reduced_motion()


## No pin card outside planning: during the count and the dessert (the receipt prints under where
## the card opens), the machine, the results, and while the deck view is open.
func _pin_card_blocked() -> bool:
	var run: RunState = _screen.run
	if run == null or run.phase != RunState.Phase.PLANNING:
		return true
	return _screen._busy() or _screen._deck_view.visible


## The day calendar's SKIP tag: while today can be taken off, in planning, outside redraw mode.
## While the run wears a Day off, the calendar's tags (DayTags.show_skip's `reserved`) keep the
## tag's room on every day (v1.16: the bar stands still).
func _show_skip(planning: bool) -> void:
	var tags: DayTags = _screen._calendar.tags
	var pending: bool = day_off_pending()
	var shown: bool = planning and (not _screen._redraw_mode or pending)
	shown = shown and PinPlay.can_take_day_off(_screen.run)
	var before: bool = tags.skip_tag().visible
	var worn: bool = PinPlay.days_off_per_week(_screen.run) > 0
	if tags.show_skip(shown, pending, worn) or before != shown:
		(_screen._top_bar as TopBar).fit_day()


## Puts a price tag with the family's glyph on every relabelled item (hand and belt), and gives
## the item the family for its scan. The tag is stuck on the item's art (ItemView.sprite), so it
## lifts and greys with the item. An item a Family sticker gives a family (v1.29) shows it as a
## gained glyph too, with no price tag (a relabel's comes first).
func _show_tags() -> void:
	var run: RunState = _screen.run
	for view: ItemView in _screen.item_views():
		var tag: String = PinPlay.relabel_of(run, view.card)
		show_relabel(view, tag)
		if tag.is_empty():
			# No relabel: the ticket shows a Family sticker's gained family instead.
			view.sticker().show_gained(stickers.gained_of(view.card), PriceSticker.STICKER_SOURCE)


## Shows `view`'s relabel to family `tag` (none: takes it off): the gained glyph on its ticket
## (PriceSticker.show_gained), the family among its tags, and the gun's price tag stuck on its
## art's foot. The handbook's GAINED example shows it the same way.
static func show_relabel(view: ItemView, tag: String) -> void:
	var art: TextureRect = view.sprite()
	var old: Node = price_tag(view)
	if old != null:
		art.remove_child(old)
		old.queue_free()
	view.sticker().show_gained(tag)
	if tag.is_empty():
		return
	view.add_tag(tag)
	var plate: Control = _price_tag(tag)
	# On the sprite's bottom left, like a sticker on the item's foot.
	plate.position = Vector2(0, ItemView.SPRITE_SIZE.y - TAG_SIZE.y) + TAG_OFFSET
	art.add_child(plate)


## The price tag the gun stuck on `view`'s item, or null.
static func price_tag(view: ItemView) -> Control:
	var plate: Control = view.sprite().get_node_or_null(TAG_NODE) as Control
	return plate if plate != null and not plate.is_queued_for_deletion() else null


static func _price_tag(tag: String) -> Control:
	var style: FamilyStyle = FamilyPalette.shared().style(tag)
	var plate: PanelContainer = PanelContainer.new()
	plate.name = TAG_NODE
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.MUSTARD_LIGHT
	box.border_color = Palette.INK
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	plate.add_theme_stylebox_override("panel", box)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.custom_minimum_size = TAG_SIZE
	plate.tooltip_text = "Price gun: %s" % tag
	if style != null and style.glyph != null:
		var glyph: TextureRect = UiKit.sprite(style.glyph)
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		plate.add_child(glyph)
	return plate


## The families the gun can give `card` now (none for a coupon or with no relabel left), less
## the one it wears already.
func _picker_tags(card: CardInstance) -> PackedStringArray:
	var tags: PackedStringArray = PackedStringArray()
	var worn: String = PinPlay.relabel_of(_screen.run, card)
	for tag: String in PinPlay.relabel_tags(_screen.run):
		if tag != worn and PinPlay.can_relabel(_screen.run, card, tag):
			tags.append(tag)
	return tags


## The family picker by `card`'s view, clear of the receipt, the register column and the monitor.
func _open_picker(card: CardInstance, tags: PackedStringArray) -> void:
	_close_picker()
	var removable: bool = not PinPlay.relabel_of(_screen.run, card).is_empty()
	var families: Array[FamilyStyle] = FamilyPalette.shared().styles(tags)
	_picker = PriceGunPicker.new(card.definition.display_name, families, removable)
	_picker.chosen.connect(func(tag: String) -> void: _relabel(card, tag))
	_picker.dismissed.connect(_close_picker)
	_screen._overlay.add_child(_picker)
	var stage: Rect2 = _screen._stage.get_global_rect()
	var area: Rect2 = stage.grow_individual(
		-ShiftStage.COLUMN_RECT.end.x, -ShiftStage.PANEL_TOP, 0.0, 0.0
	)
	var window: Rect2 = _screen.get_viewport_rect()
	var monitor: Rect2 = _screen._stage.monitor.get_global_rect()
	_picker.open_at(_view_rect(card), area.intersection(window), window, monitor, _reduced())


func _view_rect(card: CardInstance) -> Rect2:
	for view: ItemView in _screen.item_views():
		if view.card == card:
			return view.get_global_rect()
	return Rect2(_screen.get_viewport_rect().get_center(), Vector2.ZERO)


func _relabel(card: CardInstance, tag: String) -> void:
	var run: RunState = _screen.run
	if not PinPlay.relabel(run, card, tag):
		return
	_log.log_event(
		"price_gun",
		{"shift": run.shift_index + 1, "card": String(card.definition.id), "family": tag}
	)
	_gun_armed = false
	_close_picker()
	_screen._notice_label.end_notice()
	_screen._save_run()
	_screen._refresh()


func _close_picker() -> void:
	if _picker != null:
		_picker.queue_free()
		_picker = null


func _open_keep() -> void:
	_keep_panel = KeepScreen.new(_screen.run)
	_keep_panel.done.connect(_close_keep)
	_screen._overlay.add_child(_keep_panel)
	_keep_panel.position = Vector2.ZERO
	_keep_panel.size = _screen.get_viewport_rect().size


func _close_keep() -> void:
	var run: RunState = _screen.run
	if _keep_panel != null:
		_keep_panel.queue_free()
		_keep_panel = null
	var kept: Array[int] = []
	kept.assign(Array(run.kept))
	_log.log_event("golden_basket", {"shift": run.shift_index + 1, "kept": kept})
	_screen._save_run()
	keep_done.emit()
