class_name StartBoard
extends Control
## Opening-time board (full build plan 7.2): page 1 YOUR STORE "Counter" (v1.07, mock-up
## start_store_v6.html A) and page 2 YOUR BUILD, look B Staff room. Root owns navigation, keys,
## RESTOCK's pick and the store page's two pop-ups (a regular's swap shelf, a starter basket's
## aisle choice); game choices go through StartChoice (StartBoardActions), so this class only
## displays them and routes input.

signal clocked_in(pack: StarterPackDefinition)
## Esc (or ‹ TITLE) on the store page: the screen owns the scene change and its teardown.
signal back_to_title

## The keys the board answers; any other key goes on (F1's debug panel, global shortcuts).
const KEYS: Array[Key] = [
	KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_1, KEY_2, KEY_3, KEY_4, KEY_P, KEY_R, KEY_N
]
const NUMBER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
## The pop-ups keep this far (stage px) from their anchor and from the stage's edges.
const POP_GAP := 14.0
const POP_TOP := 60.0

var page: int = 1
var selected: int = -1
var preview: int = -1
var run: RunState
var profile: ProfileState
var store: StorePage
var staff: StaffBuildPage
var busy: bool = false
## The open pop-up (null while none) and what it is for: a regular's swap shelf (`_swap_slot`)
## or a starter basket's aisle choice (`_aisle_basket`).
var popover: StorePopover
## The page slide's length (s): CartRevealTuning.page_slide_s, set by the reveal before it adds
## the board.
var slide_s: float = 0.3
## A board key pressed during the page slide, acted on when it ends (KEY_NONE: none).
var _queued_key: Key = KEY_NONE
var _choice: StartBoardActions
var _stage: Control
var _pages: Control
var _bar: Control
var _rail: Control
var _back: Button
var _back_caption: Label
var _next: Button
var _next_plaque: Control
var _next_line: Label
var _modal: Control
var _pins: BadgeScreen
var _note: Label
var _save_hint: Label
var _key_hint: Control
var _swap_slot: int = -1
var _aisle_basket: int = -1


func _init(shown_run: RunState, shown_profile: ProfileState, choice: StartBoardActions) -> void:
	run = shown_run
	profile = shown_profile
	_choice = choice
	name = "StartBoard"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stage = Control.new()
	_stage.size = ShiftStage.SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_pages = Control.new()
	_pages.size = ShiftStage.SIZE
	_pages.clip_contents = true
	_pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_pages)
	StartBoardKit.panel(_pages, Rect2(Vector2.ZERO, ShiftStage.SIZE), Palette.BACKGROUND)
	store = StorePage.new()
	_pages.add_child(store)
	store.restock_pressed.connect(toggle_restock)
	store.basket_clicked.connect(restock)
	store.regular_clicked.connect(open_swap)
	store.undo_clicked.connect(undo_swap)
	store.sign_clicked.connect(open_aisles)
	staff = StaffBuildPage.new()
	_pages.add_child(staff)
	staff.pick_requested.connect(pick)
	staff.preview_requested.connect(_preview)
	staff.pins_requested.connect(open_pins)
	staff.open_requested.connect(clock_in)
	staff.new_packs_requested.connect(new_packs)
	staff.visible = false
	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_bar)
	_rail = Control.new()
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_rail)
	StartBoardKit.panel(_stage, Rect2(12, 634, 236, 78), Palette.STEEL_PALE, Palette.STEEL_DARK)
	_next_plaque = StartBoardKit.panel(
		_stage, Rect2(928, 634, 336, 78), Palette.STEEL_PALE, Palette.STEEL_DARK
	)
	_back = StartBoardKit.key(_stage, "‹ TITLE", Rect2(32, 652, 196, 48), _back_pressed)
	_back_caption = StartBoardKit.key_caption(_back)
	_next = StartBoardKit.key(_stage, "NEXT ›", Rect2(944, 640, 304, 66), _next_pressed, true)
	_next.name = "Next"
	_next_line = StartBoardKit.subtitle(_next, "Your build: pack, pins, cart")
	_save_hint = StartBoardKit.body(_stage, "", Rect2(270, 684, 640, 22), Palette.TEAL_PALE, 14)
	_save_hint.name = "SaveHint"
	_save_hint.add_theme_font_override("font", ArtStyle.bold_font(600))
	_note = StartBoardKit.body(_stage, "", Rect2(270, 684, 640, 22), Palette.TOMATO_LIGHT, 14)
	_note.name = "Note"
	_note.add_theme_font_override("font", ArtStyle.bold_font(700))
	_find_selected()
	if run.start_setup.stage == StartSetup.Stage.BUILD:
		page = 2
		staff.visible = true
		store.visible = false
	resized.connect(_resize)
	refresh()


func _ready() -> void:
	_resize()
	if page == 1:
		store.play_intro()


## The picked pack's place in the offer (-1: none picked).
func _find_selected() -> void:
	selected = -1
	for index: int in run.start_offer.packs.size():
		if run.start_offer.packs[index].id == run.start_setup.picked:
			selected = index


func _resize() -> void:
	var factor: float = minf(size.x / ShiftStage.SIZE.x, size.y / ShiftStage.SIZE.y)
	_stage.scale = Vector2.ONE * factor
	_stage.position = ((size - ShiftStage.SIZE * factor) / 2.0).floor()


func refresh() -> void:
	store.show_store(run, profile)
	_show_build()
	_refresh_header()
	_back_caption.text = "‹ TITLE" if page == 1 else "‹ STORE"
	StartBoardKit.centre(_back_caption, Rect2(8, 2, _back.size.x - 16, _back.size.y - 8))
	_next_plaque.visible = page == 1
	_note.text = ""
	_refresh_footer()


func _show_build() -> void:
	staff.show_build(
		_build_view(),
		selected,
		preview,
		profile.reduced_motion(),
		StartSetupRules.new_packs_block(run, profile)
	)


## The footer on page 1: NEXT and its key hints (R only while a RESTOCK waits), and the line
## saying the swaps (and aisle picks) stay for the next runs once they are unlocked.
func _refresh_footer() -> void:
	_next.visible = page == 1
	if _key_hint != null:
		_stage.remove_child(_key_hint)
		_key_hint.queue_free()
		_key_hint = null
	var swaps: bool = StartSetupRules.swap_limit(run, profile) > 0
	var aisles: bool = StartSetupRules.choice_mode(run.balance, profile)
	_save_hint.text = (
		"Swaps and aisle picks stay for your next runs."
		if aisles
		else "Swaps stay for your next runs." if swaps else ""
	)
	_save_hint.visible = page == 1 and _note.text == ""
	if page != 1:
		return
	var parts: PackedStringArray = ["ENTER", "next"]
	if store.restock_unlocked() and store.can_restock():
		parts.append_array(["R", "restock"])
	if store.restock_picking:
		parts = PackedStringArray(["1-3", "restock that basket", "ESC", "cancel"])
	else:
		parts.append_array(["ESC", "back"])
	_key_hint = StartBoardKit.hints(_stage, parts, Vector2(270, 652), Palette.CREAM)


## A short message in the footer (a refused or unsaved action), in place of the saves line.
func say(text: String) -> void:
	_note.text = text
	_save_hint.visible = text == "" and page == 1


func _next_pressed() -> void:
	show_page(2, "click")


## The RESTOCK key: the baskets wait for a pick, or stop waiting.
func toggle_restock() -> bool:
	if store.restock_picking:
		cancel_restock()
		return true
	return start_restock()


## R on page 1: the baskets wait for a click or 1–3 (only while a basket can be restocked).
func start_restock() -> bool:
	if page != 1 or busy or _blocked() or not store.can_restock():
		return false
	store.set_restock_picking(true)
	Sfx.play_at(self, "ui_click")
	_refresh_footer()
	return true


func cancel_restock() -> void:
	store.set_restock_picking(false)
	_refresh_footer()


## RESTOCK basket `basket` (saved at once): its two items hop out and a new pair drops in.
func restock(basket: int) -> bool:
	if busy or _blocked() or page != 1:
		return false
	if StartSetupRules.restock_block(run, profile, basket) != &"":
		return false
	var before: Array[CardDefinition] = run.start_setup.baskets[basket].cards.duplicate()
	store.restock_picking = false
	if not _choice.restock_basket.call(basket):
		refresh()
		say("Restock could not be saved. Try again.")
		return false
	_choice.mark_seen.call(StorePage.NEW_RESTOCK)
	Sfx.play_at(self, "ui_confirm")
	refresh()
	store.play_redeal(basket, before)
	return true


## Regular `slot`'s swap shelf: one tab per completed aisle, the open tab's offer (saved the first
## time it is shown); `aisle_id` opens that tab (&"": the slot's own aisle when swapped, else the
## first open one).
func open_swap(slot: int, aisle_id: StringName = &"") -> bool:
	if busy or page != 1 or _pins_open() or store.restock_picking or not store.can_swap(slot):
		return false
	var aisles: Array[AisleDefinition] = StartSetupRules.completed(run.balance, profile)
	var blocks: Array[StringName] = []
	var open: StringName = aisle_id
	var card: CardDefinition = run.starter.core_cards[slot]
	var swapped_from: AisleDefinition = (
		run.balance.aisle_of(card) if card != run.start_setup.originals[slot] else null
	)
	for aisle: AisleDefinition in aisles:
		var reason: StringName = StartSetupRules.target_block(run, profile, slot, aisle.id)
		blocks.append(reason)
		if open == &"" and swapped_from == aisle:
			open = aisle.id
	if open == &"":
		for index: int in aisles.size():
			if open == &"" and blocks[index] == &"":
				open = aisles[index].id
	var cards: Array[CardDefinition] = []
	var reasons: Array[StringName] = []
	if open != &"":
		cards = _choice.regular_offer.call(slot, open)
		for offered: CardDefinition in cards:
			reasons.append(StartSetupRules.swap_block(run, profile, slot, offered))
	if _swap_slot != slot:
		_open_modal()
	_swap_slot = slot
	store.set_open_slot(slot)
	popover.show_swap(
		run,
		run.starter.core_cards[slot],
		run.start_setup.originals[slot],
		aisles,
		blocks,
		open,
		cards,
		reasons
	)
	var tile: Rect2 = store.tile_rect(slot)
	_place(tile, true)
	return true


## Swaps the open shelf's regular for `card` at once (no confirm; its put-back tag undoes it).
func swap_to(card: CardDefinition, via: String = "click") -> bool:
	var slot: int = _swap_slot
	if slot < 0 or not StartSetupRules.can_swap(run, profile, slot, card):
		return false
	_close_modal()
	if not _choice.swap_staple.call(slot, card, via):
		refresh()
		say("The swap could not be saved. Try again.")
		return false
	_choice.mark_seen.call(StorePage.NEW_SWAP)
	Sfx.play_at(self, "ui_confirm")
	refresh()
	store.play_flip(slot)
	return true


## The put-back tag on swapped regular `slot` (or the shelf's BACK TO tab): its original returns.
func undo_swap(slot: int) -> bool:
	if busy or page != 1 or _pins_open():
		return false
	if not StartSetupRules.can_restore(run, slot):
		say("Putting it back would break the %d-copy limit." % run.starter.copy_max)
		return false
	_close_modal()
	if not _choice.restore_regular.call(slot, "click"):
		refresh()
		say("The swap could not be saved. Try again.")
		return false
	Sfx.play_at(self, "ui_click")
	refresh()
	store.play_flip(slot)
	return true


## Starter basket `basket`'s aisle choice: the other completed aisles as signs.
func open_aisles(basket: int) -> bool:
	if busy or page != 1 or _pins_open() or store.restock_picking or not store.can_change(basket):
		return false
	var current: AisleDefinition = StorePage.aisle_of(run, run.start_setup.baskets[basket].source)
	var choices: Array[AisleDefinition] = []
	for id: StringName in StartSetupRules.aisle_options(run, profile, basket):
		choices.append(StorePage.aisle_of(run, id))
	var extra: Array[StringName] = run.start_setup.run_only_ids(run.balance)
	var extra_aisle: AisleDefinition = (
		StorePage.aisle_of(run, extra[0]) if not extra.is_empty() else null
	)
	_open_modal()
	_aisle_basket = basket
	store.set_open_basket(basket)
	popover.show_aisles(
		basket, current, choices, extra_aisle.display_name if extra_aisle != null else "none"
	)
	_place(store.sign_rect(basket), false)
	return true


## Deals the open pop-up's basket again from aisle `aisle_id` (saved at once).
func change_aisle(aisle_id: StringName) -> bool:
	var basket: int = _aisle_basket
	if basket < 0 or StartSetupRules.aisle_block(run, profile, basket, aisle_id) != &"":
		return false
	var before: Array[CardDefinition] = run.start_setup.baskets[basket].cards.duplicate()
	_close_modal()
	if not _choice.change_aisle.call(basket, aisle_id):
		refresh()
		say("The aisle change could not be saved. Try again.")
		return false
	_choice.mark_seen.call(StorePage.NEW_AISLE)
	Sfx.play_at(self, "ui_confirm")
	refresh()
	store.play_redeal(basket, before)
	store.play_wiggle(basket)
	return true


## The modal layer for a pop-up: a click outside it closes it.
func _open_modal() -> void:
	_close_modal()
	_modal = Control.new()
	_modal.name = "PopLayer"
	_modal.size = ShiftStage.SIZE
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.gui_input.connect(
		func(event: InputEvent) -> void:
			var button: InputEventMouseButton = event as InputEventMouseButton
			if button != null and button.pressed:
				_close_modal()
	)
	_stage.add_child(_modal)
	popover = StorePopover.new()
	_modal.add_child(popover)
	popover.tab_chosen.connect(func(aisle_id: StringName) -> void: open_swap(_swap_slot, aisle_id))
	popover.chosen.connect(swap_to)
	popover.restore_chosen.connect(func() -> void: undo_swap(_swap_slot))
	popover.aisle_chosen.connect(change_aisle)
	popover.closed.connect(_close_modal)
	if not profile.reduced_motion():
		popover.scale = Vector2.ONE * 0.85
		popover.modulate.a = 0.0
		var tween: Tween = popover.create_tween().set_parallel()
		tween.tween_property(popover, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
		tween.tween_property(popover, "modulate:a", 1.0, 0.12)


## Places the pop-up over `anchor` (`above`: above it when it fits, else below; otherwise below),
## inside the stage.
func _place(anchor: Rect2, above: bool) -> void:
	var pop_size: Vector2 = popover.size
	var left: float = anchor.get_center().x - pop_size.x / 2.0
	left = clampf(left, 12, ShiftStage.SIZE.x - 12 - pop_size.x)
	var top: float = anchor.end.y + POP_GAP
	if above and anchor.position.y - pop_size.y - POP_GAP >= POP_TOP:
		top = anchor.position.y - pop_size.y - POP_GAP
	top = clampf(top, POP_TOP, ShiftStage.SIZE.y - 12 - pop_size.y)
	popover.position = Vector2(left, top).floor()
	popover.pivot_offset = Vector2(pop_size.x / 2.0, pop_size.y if above else 0.0)


func _close_modal() -> void:
	if _modal != null:
		_stage.remove_child(_modal)
		_modal.queue_free()
		_modal = null
	popover = null
	if _swap_slot >= 0 or _aisle_basket >= 0:
		_swap_slot = -1
		_aisle_basket = -1
		store.set_open_slot(-1)
		store.set_open_basket(-1)


## NEW PACKS (saved at once): three other crates, the pick cleared.
func new_packs() -> bool:
	if busy or _blocked() or page != 2:
		return false
	if not _choice.new_packs.call():
		return false
	_find_selected()
	preview = -1
	Sfx.play_at(self, "ui_click")
	refresh()
	return true


func _refresh_header() -> void:
	StartBoardKit.clear(_bar)
	StartBoardKit.panel(_bar, Rect2(0, 0, 1280, 54), Palette.BACKGROUND, Palette.TEAL_BLACK)
	var shift: Control = _chip(Rect2(16, 8, 312, 38), "ShiftChip")
	StartBoardKit.icon(shift, StartBoardKit.CLOCK_ICON, Vector2(10, 10))
	StartBoardKit.tag(shift, "OPENING TIME", Rect2(36, 2, 150, 34), Palette.MUSTARD_PALE)
	StartBoardKit.tag(shift, "SHIFT", Rect2(196, 2, 56, 34), Palette.TEAL_LIGHT)
	StartBoardKit.number(
		shift, "1/%d" % run.shift_count(), Rect2(258, 2, 52, 34), Palette.PAPER, 24
	)
	var completed: Array[AisleDefinition] = StartSetupRules.completed(run.balance, profile)
	var aisles: Control = _chip(Rect2(342, 8, 300, 38), "AisleChip")
	for index: int in run.balance.aisles.size():
		var aisle: AisleDefinition = run.balance.aisles[index]
		var glyph: TextureRect = StartBoardKit.icon(
			aisles, StartBoardKit.glyph(aisle), Vector2(10 + index * 22, 10)
		)
		glyph.name = "Glyph_%s" % aisle.id
		glyph.tooltip_text = aisle.display_name
		if not completed.has(aisle):
			glyph.modulate = Color(0.32, 0.4, 0.4)
	StartBoardKit.number(
		aisles,
		"%d/%d★" % [completed.size(), run.balance.aisles.size()],
		Rect2(146, 2, 64, 34),
		Palette.PAPER,
		24
	)
	StartBoardKit.tag(aisles, "AISLES", Rect2(214, 2, 80, 34), Palette.TEAL_LIGHT)
	var seed_label: Label = StartBoardKit.body(
		_bar,
		"Seed %d · run %d" % [run.run_seed, profile.run_count + 1],
		Rect2(840, 16, 240, 24),
		Palette.CREAM_DARKEST,
		14
	)
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	seed_label.add_theme_font_override("font", ArtStyle.bold_font(700))
	var pack: StarterPackDefinition = (
		run.start_offer.packs[selected] if page == 2 and selected >= 0 else null
	)
	var count: int = (
		StartSetupRules
		. cart_cards(
			StartSetupRules.cart_lines(run.starter, run.start_offer, run.balance, run.pins, pack)
		)
		. size()
	)
	var cart: Panel = StartBoardKit.panel(
		_bar, Rect2(1094, 8, 170, 38), Palette.TEAL, Palette.TEAL_LIGHT
	)
	cart.name = "CartChip"
	StartBoardKit.icon(cart, TopBar.CART_ICON, Vector2(10, 10))
	StartBoardKit.tag(cart, "Cart", Rect2(40, 2, 56, 34), Palette.PAPER)
	var cart_count: Label = StartBoardKit.number(
		cart, "%d/%d" % [count, run.balance.deck_limit], Rect2(96, 2, 66, 34), Palette.PAPER, 24
	)
	cart_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	StartBoardKit.clear(_rail)
	for index: int in 2:
		var active: bool = page == index + 1
		var tab: Button = StartBoardKit.key(
			_rail,
			"YOUR STORE" if index == 0 else "YOUR BUILD",
			Rect2(12 + index * 264, 60, 236, 46),
			show_page.bind(index + 1, "tab")
		)
		tab.name = "Tab%d" % (index + 1)
		if active:
			StartBoardKit.restyle(tab, Palette.PAPER, Palette.MUSTARD, 4)
		else:
			StartBoardKit.restyle(tab, Palette.TEAL_DARK, Palette.TEAL_LIGHT)
		var caption: Label = StartBoardKit.key_caption(tab)
		caption.add_theme_color_override(
			"font_color", Palette.INK if active else Palette.TEAL_LIGHT
		)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiKit.place_pixel_label(caption, Rect2(46, 0, 150, 40), true)
		var box: Panel = StartBoardKit.panel(
			tab,
			Rect2(10, 8, 26, 26),
			Palette.MUSTARD if active else Palette.TEAL,
			Palette.INK if active else Palette.TEAL_LIGHT
		)
		box.name = "Step"
		var step: Label = StartBoardKit.number(
			box, str(index + 1), Rect2(0, 0, 26, 24), Palette.INK if active else Palette.PAPER, 22
		)
		step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if index == 0 and page == 2:
			StartBoardKit.icon(tab, StartBoardKit.CHECK, Vector2(200, 7)).name = "Done"
	StartBoardKit.tag(_rail, "›", Rect2(250, 62, 24, 40), Palette.TEAL_LIGHT)


## A framed top-bar chip (TopBar's frame) holding its own children at absolute positions.
func _chip(rect: Rect2, chip_name: String) -> Control:
	var frame: PanelContainer = TopBar.chip(TopBar.CHIP_FRAME)
	frame.position = rect.position
	frame.size = rect.size
	frame.custom_minimum_size = rect.size
	_bar.add_child(frame)
	var holder: Control = Control.new()
	holder.name = chip_name
	holder.position = rect.position
	holder.size = rect.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(holder)
	return holder


func show_page(next_page: int, key: String = "click") -> void:
	if busy or _modal != null or _pins_open() or next_page == page or next_page not in [1, 2]:
		return
	store.restock_picking = false
	if next_page == 2 and run.start_setup.stage == StartSetup.Stage.REVEALED:
		_choice.mark_build.call()
	var before: int = page
	_choice.page_changed.call(next_page, before, key)
	page = next_page
	preview = -1
	refresh()
	if profile.reduced_motion():
		store.visible = page == 1
		staff.visible = page == 2
		return
	busy = true
	store.visible = true
	staff.visible = true
	var direction: float = 1.0 if page == 2 else -1.0
	var old: Control = (store as Control) if before == 1 else (staff as Control)
	var fresh: Control = (store as Control) if page == 1 else (staff as Control)
	var tween: Tween = create_tween()
	tween.tween_method(
		func(fraction: float) -> void:
			var step: float = floorf(fraction * 6) / 6.0
			old.position.x = floorf(-direction * step * 1280 / 2.0) * 2
			fresh.position.x = floorf(direction * (1 - step) * 1280 / 2.0) * 2,
		0.0,
		1.0,
		slide_s
	)
	tween.tween_callback(
		func() -> void:
			store.position = Vector2.ZERO
			staff.position = Vector2.ZERO
			store.visible = page == 1
			staff.visible = page == 2
			busy = false
			if _queued_key != KEY_NONE:
				var queued: Key = _queued_key
				_queued_key = KEY_NONE
				_act(queued)
	)


func pick(index: int) -> void:
	if busy or page != 2 or _blocked() or index < 0 or index >= run.start_offer.packs.size():
		return
	if _choice.save_pick.call(run.start_offer.packs[index]):
		selected = index
		preview = -1
		Sfx.play_at(self, "ui_click")
		refresh()
	else:
		say("Could not save your pick. Try again.")


func _preview(index: int) -> void:
	if busy or _blocked():
		return
	preview = index
	_show_build()


func _build_view() -> StartBuildView:
	var view: StartBuildView = StartBuildView.new()
	view.starter = run.starter
	view.start_offer = run.start_offer
	view.balance = run.balance
	view.pins = run.pins
	return view


## Clocks in with the picked pack; the NEW tags shown this run are marked seen (first time only).
func clock_in() -> bool:
	if page != 2 or selected < 0 or busy or _blocked():
		return false
	busy = true
	for id: StringName in store.fresh:
		_choice.mark_seen.call(id)
	if profile.reduced_motion():
		clocked_in.emit(run.start_offer.packs[selected])
	else:
		staff.punch().finished.connect(
			func() -> void: clocked_in.emit(run.start_offer.packs[selected])
		)
	return true


func _back_pressed() -> void:
	back("click")


func back(key: String = "esc") -> void:
	if busy:
		return
	if _modal != null:
		_close_modal()
	elif _pins_open():
		_pins.close()
	elif store.restock_picking:
		cancel_restock()
	elif page == 2:
		show_page(1, key)
	else:
		_choice.page_changed.call(0, 1, key)
		back_to_title.emit()


## Whether a pop-up or the pins are open over the page.
func _blocked() -> bool:
	return _modal != null or _pins_open()


func _pins_open() -> bool:
	return _pins != null and _pins.visible


func open_pins() -> void:
	if busy or _modal != null or page != 2:
		return
	if _pins != null:
		_pins.queue_free()
	_pins = _choice.open_pins.call(_stage, refresh, Vector2(-140, 0)) as BadgeScreen


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not is_visible_in_tree() or key == null or not key.pressed or key.echo:
		return
	if _pins_open():
		if _pins.handle_key(key):
			get_viewport().set_input_as_handled()
		return
	if not KEYS.has(key.keycode):
		return
	get_viewport().set_input_as_handled()
	if busy:
		# Held for the end of the page slide (the last key wins), so Esc Esc still reaches the
		# title; nothing is held once the clock-in punch has started.
		_queued_key = key.keycode if page_sliding() else KEY_NONE
		return
	_act(key.keycode)


## Whether the page slide is running (busy for the slide, not for the clock-in punch).
func page_sliding() -> bool:
	return busy and store.visible and staff.visible


func _act(keycode: Key) -> void:
	var enter: bool = keycode in [KEY_ENTER, KEY_KP_ENTER]
	var number: int = NUMBER_KEYS.find(keycode)
	if keycode == KEY_ESCAPE:
		back()
	elif busy:
		return
	elif popover != null:
		var card: CardDefinition = popover.card_at(number) if _swap_slot >= 0 else null
		if card != null:
			swap_to(card, "key")
	elif _modal != null:
		return
	elif page == 2:
		_act_build(keycode, enter, number)
	else:
		_act_store(keycode, enter, number)


func _act_build(keycode: Key, enter: bool, number: int) -> void:
	if enter:
		clock_in()
	elif number >= 0 and number < 3:
		pick(number)
	elif keycode == KEY_P:
		open_pins()
	elif keycode == KEY_N:
		new_packs()


func _act_store(keycode: Key, enter: bool, number: int) -> void:
	if store.restock_picking:
		if number >= 0 and number < run.start_setup.baskets.size():
			restock(number)
		elif keycode == KEY_R:
			cancel_restock()
		return
	if enter:
		show_page(2, "enter")
	elif keycode == KEY_R:
		start_restock()
	elif number >= 0:
		open_swap(number)


## The card tile under the pointer that may show its scan popup (CartReveal's, with its hold):
## a control carrying a "card" meta on the shown page; null while a pop-up, the pins or a slide
## covers the board.
func hovered_card() -> Control:
	if busy or _blocked() or not is_visible_in_tree():
		return null
	var hovered: Control = get_viewport().gui_get_hovered_control()
	while hovered != null and not hovered.has_meta("card"):
		hovered = hovered.get_parent() as Control
	if hovered == null or not hovered.is_visible_in_tree():
		return null
	return hovered


## The scaled stage's global rect (the popup stays on it).
func stage_rect() -> Rect2:
	return _stage.get_global_rect()
