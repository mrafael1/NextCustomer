class_name StartBoard
extends Control
## Opening-time v3 store page and v4 B staff room (full build plan 7.2, reworked 2026-11-05).
## Root owns navigation, keys, LOCK IN & DEAL and the regular's swap strip; game choices go
## through StartChoice (StartBoardActions), so this class only displays them and routes input.

signal clocked_in(pack: StarterPackDefinition)
## Esc (or ‹ TITLE) on the store page: the screen owns the scene change and its teardown.
signal back_to_title

## The keys the board answers; any other key goes on (F1's debug panel, global shortcuts).
const KEYS: Array[Key] = [
	KEY_ESCAPE,
	KEY_ENTER,
	KEY_KP_ENTER,
	KEY_1,
	KEY_2,
	KEY_3,
	KEY_4,
	KEY_P,
	KEY_R,
	KEY_N,
	KEY_UP,
	KEY_DOWN,
	KEY_SPACE,
	KEY_BACKSPACE
]
const NUMBER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
## The swap strip's left edge (just right of the aisle board) and its lowest bottom.
const STRIP_LEFT := 456.0
const STRIP_BOTTOM := 600.0

var page: int = 1
var selected: int = -1
var preview: int = -1
var run: RunState
var profile: ProfileState
var store: StorePage
var staff: StaffBuildPage
var busy: bool = false
var strip: RegularSwapStrip
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
## The swap strip (null while closed) and the regular it replaces: its slot, the card proposed,
## whether it is a PUT BACK, and how it was dropped.
var _swap_slot: int = -1
var _swap_card: CardDefinition
var _swap_restore: bool = false
var _swap_via: String = "click"


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
	store.drop_requested.connect(_dropped)
	store.restore_requested.connect(open_restore)
	store.restock_requested.connect(restock)
	store.draft_changed.connect(_refresh_footer)
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
	_save_hint = StartBoardKit.body(
		_stage,
		"Regular replacements and aisle choices are saved to your profile.",
		Rect2(270, 646, 650, 22),
		Palette.CREAM,
		14
	)
	_save_hint.add_theme_font_override("font", ArtStyle.bold_font(700))
	_note = StartBoardKit.body(_stage, "", Rect2(380, 620, 520, 28), Palette.TOMATO_LIGHT, 14)
	_find_selected()
	if run.start_setup.stage == StartSetup.Stage.BUILD:
		page = 2
		staff.visible = true
		store.visible = false
	resized.connect(_resize)
	refresh()


func _ready() -> void:
	_resize()


## The picked pack's place in the offer (-1: none picked).
func _find_selected() -> void:
	selected = -1
	for index: int in run.start_offer.packs.size():
		if run.start_offer.packs[index].id == run.start_setup.picked:
			selected = index


## Whether nothing is dealt yet (LOCK IN & DEAL waits).
func selecting() -> bool:
	return run.start_setup.stage == StartSetup.Stage.SELECT


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
	_save_hint.visible = page == 1
	_note.text = ""
	_refresh_footer()


func _show_build() -> void:
	if not selecting():
		staff.show_build(
			_build_view(),
			selected,
			preview,
			profile.reduced_motion(),
			StartSetupRules.new_packs_block(run, profile)
		)


## The footer on page 1: LOCK IN & DEAL while nothing is dealt (disabled, saying what is
## missing, while the draft isn't 2 STARTER CART and 1 RUN ONLY), else NEXT; and its key hints.
func _refresh_footer() -> void:
	_next.visible = page == 1
	var caption: Label = StartBoardKit.key_caption(_next)
	var lock: bool = selecting()
	var reason: StringName = store.lock_reason() if lock else &""
	var done: int = StartSetupRules.completed(run.balance, profile).size()
	caption.text = "LOCK IN & DEAL ›" if lock else "NEXT ›"
	var pixels: int = 4
	while pixels > 2 and StartBoardKit.text_width(caption.text, pixels) > _next.size.x - 24:
		pixels -= 1
	UiKit.use_pixel_text(caption, pixels)
	var room: Rect2 = Rect2(8, 4, _next.size.x - 16, _next.size.y - 30)
	UiKit.place_pixel_label(caption, room, true)
	StartBoardKit.centre(caption, room)
	_next.disabled = lock and reason != &""
	caption.add_theme_color_override(
		"font_color", Palette.INK_LIGHT if _next.disabled else Palette.PAPER
	)
	_next_line.text = (
		StartReasons.lock(run, done, reason) if lock else "Your build: pack, pins, cart"
	)
	_next_line.add_theme_color_override(
		"font_color", Palette.INK if _next.disabled else Palette.PAPER
	)
	_next.tooltip_text = _next_line.text
	var line_font: Font = _next_line.get_theme_font("font")
	var line_size: int = 14
	while (
		line_size > 11
		and (
			line_font.get_string_size(_next_line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, line_size).x
			> _next_line.size.x
		)
	):
		line_size -= 1
	_next_line.add_theme_font_size_override("font_size", line_size)
	if _key_hint != null:
		_stage.remove_child(_key_hint)
		_key_hint.queue_free()
		_key_hint = null
	if page != 1:
		return
	var parts: PackedStringArray = (
		["ENTER", "lock in & deal"] if lock else ["ENTER", "next", "R", "restock"]
	)
	if store.choosing():
		parts.append_array(["SPACE", "aisle status"])
	parts.append_array(["1-4", "replace a regular", "ESC", "back"])
	_key_hint = StartBoardKit.hints(_stage, parts, Vector2(270, 676), Palette.CREAM)


func _next_pressed() -> void:
	if selecting():
		lock_in()
	else:
		show_page(2, "click")


## LOCK IN & DEAL with the store page's draft: deals the baskets and the offer (saved), then
## uncovers the baskets. False when refused or not saved.
func lock_in() -> bool:
	if busy or _blocked() or not selecting() or store.lock_reason() != &"":
		return false
	store.cancel_carry()
	if not _choice.lock_in.call(store.draft_green(), store.draft_run_only(), store.status_clicks):
		_note.text = "Could not save the deal. Try again."
		return false
	_find_selected()
	preview = -1
	Sfx.play_at(self, "ui_confirm")
	refresh()
	store.play_deal(profile.reduced_motion())
	return true


## RESTOCK basket `basket` (saved at once), then plays that basket's reveal.
func restock(basket: int) -> bool:
	if busy or _blocked() or page != 1:
		return false
	if StartSetupRules.restock_block(run, profile, basket) != &"":
		store.set_restock_picking(false)
		return false
	store.cancel_carry()
	if not _choice.restock_basket.call(basket):
		_note.text = "Restock could not be saved."
		return false
	Sfx.play_at(self, "ui_click")
	store.restock_picking = false
	refresh()
	store.play_deal(profile.reduced_motion(), basket)
	return true


## R on page 1: the RESTOCK tags wait for 1–3 (only while a basket can be restocked).
func start_restock() -> bool:
	if page != 1 or _blocked():
		return false
	for basket: int in run.start_setup.baskets.size():
		if StartSetupRules.restock_block(run, profile, basket) == &"":
			store.cancel_carry()
			store.set_restock_picking(true)
			return true
	return false


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
		if index == 1 and selecting():
			tab.disabled = true
			tab.tooltip_text = "LOCK IN & DEAL first"
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
	if (
		busy
		or _modal != null
		or (_pins != null and _pins.visible)
		or next_page == page
		or next_page not in [1, 2]
		or (next_page == 2 and selecting())
	):
		return
	store.cancel_carry()
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
		_note.text = "Could not save your pick. Try again."


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


func clock_in() -> bool:
	if page != 2 or selected < 0 or busy or _blocked():
		return false
	busy = true
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
	elif _pins != null and _pins.visible:
		_pins.close()
	elif store.carrying():
		store.cancel_carry()
	elif store.restock_picking:
		store.set_restock_picking(false)
	elif page == 2:
		show_page(1, key)
	else:
		_choice.page_changed.call(0, 1, key)
		back_to_title.emit()


## Whether the swap strip or the pins are open over the page.
func _blocked() -> bool:
	return _modal != null or (_pins != null and _pins.visible)


func open_pins() -> void:
	if busy or _modal != null or page != 2:
		return
	if _pins != null:
		_pins.queue_free()
	_pins = _choice.open_pins.call(_stage, refresh, Vector2(-140, 0)) as BadgeScreen


## The carried regular `slot` was dropped on aisle `aisle_id` (`via` drag, click or key): opens
## the aisle's strip for it, or straight its preview when the aisle offers one item; a row that
## can't take it says why in the tray.
func _dropped(slot: int, aisle_id: StringName, via: String) -> void:
	if busy or _blocked():
		return
	var reason: StringName = StartSetupRules.target_block(run, profile, slot, aisle_id)
	if reason != &"":
		store.say(StartReasons.target(run, reason) + ".")
		return
	var offer: Array[CardDefinition] = _choice.regular_offer.call(slot, aisle_id)
	if offer.is_empty():
		store.say("Could not save the aisle's offer. Try again.")
		return
	_swap_slot = slot
	_swap_via = via
	_swap_restore = false
	if offer.size() == 1:
		open_preview(slot, offer[0], false)
		return
	var reasons: Array[StringName] = []
	for card: CardDefinition in offer:
		reasons.append(StartSetupRules.swap_block(run, profile, slot, card))
	_open_strip(store.board.row_rect(aisle_id))
	strip.show_strip(
		run, run.starter.core_cards[slot], AisleBoard._aisle(run, aisle_id), offer, reasons
	)
	_place_strip()


## The WAS key under a replaced regular: the PUT BACK preview.
func open_restore(slot: int) -> void:
	if busy or _blocked():
		return
	if not StartSetupRules.can_restore(run, slot):
		store.say("Putting it back would break the %d-copy limit." % run.starter.copy_max)
		return
	store.cancel_carry()
	_swap_slot = slot
	_swap_via = "click"
	var regular: Control = store.regulars[slot]
	open_preview(slot, run.start_setup.originals[slot], true, Rect2(regular.position, regular.size))


## The preview of regular `slot` becoming `card` (`restore`: its original), CONFIRM or CANCEL.
func open_preview(slot: int, card: CardDefinition, restore: bool, near: Rect2 = Rect2()) -> void:
	if strip == null:
		_open_strip(near)
	_swap_slot = slot
	_swap_card = card
	_swap_restore = restore
	strip.show_preview(run.starter.core_cards[slot], card, restore)
	_place_strip()


## Confirms the preview: the swap (or PUT BACK) is saved; the baskets are never re-dealt.
func confirm_swap() -> bool:
	if strip == null or not strip.previewing or _swap_card == null:
		return false
	var saved: bool = (
		_choice.restore_regular.call(_swap_slot, _swap_via)
		if _swap_restore
		else _choice.swap_staple.call(_swap_slot, _swap_card, _swap_via)
	)
	_close_modal()
	if not saved:
		_note.text = "The replacement could not be saved."
		return false
	Sfx.play_at(self, "ui_confirm")
	refresh()
	return true


## The modal layer for the strip: a light dim over the stage that cancels on a click.
func _open_strip(near: Rect2) -> void:
	_close_modal()
	_modal = Control.new()
	_modal.name = "SwapLayer"
	_modal.size = ShiftStage.SIZE
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.set_meta("near", near)
	_modal.gui_input.connect(
		func(event: InputEvent) -> void:
			var button: InputEventMouseButton = event as InputEventMouseButton
			if button != null and button.pressed:
				_close_modal()
	)
	_stage.add_child(_modal)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(Palette.TEAL_BLACK, 0.55)
	dim.position = -ShiftStage.SIZE
	dim.size = ShiftStage.SIZE * 3
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(dim)
	strip = RegularSwapStrip.new()
	_modal.add_child(strip)
	strip.chosen.connect(func(card: CardDefinition) -> void: open_preview(_swap_slot, card, false))
	strip.confirmed.connect(confirm_swap)
	strip.cancelled.connect(_close_modal)


## Places the strip beside the row (or regular) it came from, inside the stage.
func _place_strip() -> void:
	var near: Rect2 = _modal.get_meta("near", Rect2())
	var top: float = near.get_center().y - strip.size.y / 2.0
	var left: float = STRIP_LEFT
	if near.position.x > STRIP_LEFT:
		left = near.get_center().x - strip.size.x / 2.0
		top = near.position.y - strip.size.y - 12
	left = clampf(left, 12, ShiftStage.SIZE.x - 12 - strip.size.x)
	top = clampf(top, 60, STRIP_BOTTOM - strip.size.y)
	strip.position = Vector2(left, top).floor()


func _close_modal() -> void:
	if _modal != null:
		_stage.remove_child(_modal)
		_modal.queue_free()
		_modal = null
	strip = null
	_swap_card = null


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not is_visible_in_tree() or key == null or not key.pressed or key.echo:
		return
	if _pins != null and _pins.visible:
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
	elif strip != null:
		if strip.previewing and enter:
			confirm_swap()
		elif not strip.previewing and number >= 0:
			strip.choose(number)
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
		return
	if keycode in [KEY_UP, KEY_DOWN]:
		store.move_focus(-1 if keycode == KEY_UP else 1)
	elif keycode == KEY_SPACE or (enter and store.carrying()):
		store.activate_focus()
	elif enter:
		if selecting():
			lock_in()
		else:
			show_page(2, "enter")
	elif number >= 0:
		if store.carry_slot == number:
			store.cancel_carry()
		else:
			store.carry(number, "key")
	elif keycode == KEY_BACKSPACE and store.carrying():
		open_restore(store.carry_slot)
	elif keycode == KEY_R and not selecting():
		start_restock()


## The card tile under the pointer that may show its scan popup (CartReveal's, with its hold):
## a control carrying a "card" meta on the shown page; null while a sheet, the pins or a slide
## covers the board.
func hovered_card() -> Control:
	if busy or _blocked() or store.carrying() or not is_visible_in_tree():
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
