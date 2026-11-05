class_name StorePage
extends Control
## YOUR STORE (full build plan 7.2, mock-up start_screen_v3, reworked 2026-11-05): the aisle board
## on the left (AisleBoard: every aisle, coloured by status, clickable from 6 completed aisles
## while nothing is dealt), three baskets on the counter (covered until LOCK IN & DEAL, then each
## with its RESTOCK tag) linked to their rows by the source rail, and YOUR REGULARS in a shallow
## counter tray: drag one onto an aisle row (or click it, then the row) to replace it. The page
## holds the draft aisle statuses and the carried regular (view state only); StartBoard routes
## the commitments to StartChoice.

signal drop_requested(slot: int, aisle_id: StringName, via: String)
signal restore_requested(slot: int)
signal restock_requested(basket: int)
signal draft_changed

## The counter's panel, the baskets' left, step and top, and the source rail's bar and riser.
const COUNTER := Rect2(466, 114, 798, 270)
const BASKET_LEFT := 480.0
const BASKET_STEP := 262.0
const BASKET_TOP := 168.0
const RAIL_Y := 158.0
const RAIL_X := 452.0
## The regulars' tray panel, a regular's left, step and top, and the tray's tip card.
const TRAY := Rect2(466, 396, 798, 196)
const REGULAR_LEFT := 480.0
const REGULAR_STEP := 126.0
const REGULAR_TOP := 430.0
const TIP := Rect2(990, 430, 260, 150)
## How far (stage px) a pressed regular moves before it is dragged rather than clicked.
const DRAG_START := 8.0
## The baskets' reveal stagger at LOCK IN.
const REVEAL_STAGGER_S := 0.12

var board: AisleBoard
var baskets: Array[StartBasketView] = []
var regulars: Array[Control] = []
## The carried regular's slot (-1: none) and how it was picked up ("drag", "click", "key").
var carry_slot: int = -1
var carry_via: String = ""
## Whether R waits for a basket's 1–3.
var restock_picking: bool = false
## The draft's status clicks before LOCK IN (start_lock_in's status_clicks).
var status_clicks: int = 0
var tray_tip: Label
var counter_line: Label
var ghost: Control
var _run: RunState
var _profile: ProfileState
var _draft: Dictionary[StringName, AisleBoard.Status] = {}
var _draft_setup: StartSetup
var _press_slot: int = -1
var _press_at: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _hovered: StringName = &""
var _message: String = ""
var _tweens: Array[Tween] = []
var _rail: Control
var _counter: Control
var _tray: Control


func show_store(run: RunState, profile: ProfileState) -> void:
	_run = run
	_profile = profile
	skip_deal()
	carry_slot = -1
	_press_slot = -1
	_dragging = false
	_message = ""
	_hovered = &""
	if run.start_setup != _draft_setup or run.start_setup.stage != StartSetup.Stage.SELECT:
		_reset_draft()
	StartBoardKit.clear(self)
	size = ShiftStage.SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background: TextureRect = UiKit.sprite(StoreArt.texture())
	background.position = Vector2(-320, 54)
	background.size = Vector2(StoreArt.art_size().x * 2, 554)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(background)
	board = AisleBoard.new()
	board.name = "AisleBoard"
	add_child(board)
	board.row_clicked.connect(_row_clicked)
	board.row_hovered.connect(_row_hovered)
	_counter = Control.new()
	_counter.name = "Counter"
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_counter)
	_tray = Control.new()
	_tray.name = "Tray"
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tray)
	_rail = Control.new()
	_rail.name = "Rail"
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rail)
	_rail.draw.connect(_draw_rail)
	ghost = Control.new()
	ghost.name = "Ghost"
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.visible = false
	add_child(ghost)
	_render_board()
	_render_counter()
	_render_tray()


## Whether the player sets today's aisles now (6 completed aisles, nothing dealt yet).
func choosing() -> bool:
	return (
		_run.start_setup.stage == StartSetup.Stage.SELECT
		and StartSetupRules.choice_mode(_run.balance, _profile)
	)


## The draft's STARTER CART aisles, data order.
func draft_green() -> Array[StringName]:
	return _draft_ids(AisleBoard.Status.GREEN)


## The draft's RUN ONLY aisles, data order.
func draft_run_only() -> Array[StringName]:
	return _draft_ids(AisleBoard.Status.ORANGE)


## Why the draft can't be locked in (StartSetupRules.lock_block), &"" when it can.
func lock_reason() -> StringName:
	return StartSetupRules.lock_block(_run, _profile, draft_green(), draft_run_only())


## Cycles aisle `id`'s draft status (not today › STARTER CART › RUN ONLY), skipping a full one.
## False when it can't change (not choosing, not listable, or both other statuses full).
func cycle(id: StringName) -> bool:
	if not choosing() or not StartSetupRules.listable_ids(_run.balance, _profile).has(id):
		return false
	var current: AisleBoard.Status = _draft.get(id, AisleBoard.Status.OFF)
	var next: AisleBoard.Status = _next_status(id)
	if next == current:
		return false
	if next == AisleBoard.Status.OFF:
		_draft.erase(id)
	else:
		_draft[id] = next
	status_clicks += 1
	Sfx.play_at(self, "ui_click")
	_render_board()
	_render_counter()
	draft_changed.emit()
	return true


## Picks up regular `slot` (`via` "drag", "click" or "key"). False before an aisle is completed.
func carry(slot: int, via: String) -> bool:
	if slot < 0 or slot >= _run.starter.core_cards.size():
		return false
	if StartSetupRules.completed(_run.balance, _profile).is_empty():
		say("Complete an aisle to replace a regular.")
		return false
	carry_slot = slot
	carry_via = via
	restock_picking = false
	_message = ""
	_render_board()
	_render_counter()
	_mark_carried()
	if via == "key":
		for index: int in board.ids.size():
			var id: StringName = board.ids[index]
			if id != StartSetup.STAPLES and _target(id) == &"":
				board.set_focus(index)
				break
	else:
		_show_ghost()
	return true


func cancel_carry() -> void:
	if carry_slot < 0 and not _dragging:
		return
	carry_slot = -1
	_dragging = false
	_press_slot = -1
	ghost.visible = false
	_render_board()
	_mark_carried()


func carrying() -> bool:
	return carry_slot >= 0


## Drops the carried regular on row `id` (StorePage.drop_requested), or puts it down when `id`
## is not an aisle.
func drop_on(id: StringName, via: String) -> void:
	var slot: int = carry_slot
	cancel_carry()
	if id == &"" or id == StartSetup.STAPLES or slot < 0:
		return
	drop_requested.emit(slot, id, via)


## R: the baskets' RESTOCK tags wait for 1–3 (`on`), or stop waiting.
func set_restock_picking(on: bool) -> void:
	restock_picking = on
	_render_counter()


## Moves the keyboard's row by `step` (wrapping).
func move_focus(step: int) -> void:
	var count: int = board.ids.size()
	var at: int = board.focus
	board.set_focus(0 if at < 0 else posmod(at + step, count))
	_row_hovered(board.ids[board.focus])


## Space or Enter on the keyboard's row: drops the carried regular there, else cycles its status.
func activate_focus() -> bool:
	if board.focus < 0:
		return false
	var id: StringName = board.ids[board.focus]
	if carrying():
		drop_on(id, "key")
		return true
	return cycle(id)


## A short message in the tray's tip card (until the next carry).
func say(text: String) -> void:
	_message = text
	if tray_tip != null:
		tray_tip.text = text


## The reveal at LOCK IN & DEAL (`basket` -1: every basket, staggered) or of the one restocked
## basket. Cosmetic only. Reduced motion shows the end at once.
func play_deal(reduced: bool, basket: int = -1) -> void:
	skip_deal()
	if reduced or not is_inside_tree():
		return
	for index: int in baskets.size():
		if basket < 0 or basket == index:
			var delay: float = index * REVEAL_STAGGER_S if basket < 0 else 0.0
			_tweens.append(baskets[index].play_reveal(delay))


## Ends a playing reveal at its last frame.
func skip_deal() -> void:
	for tween: Tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	for view: StartBasketView in baskets:
		if is_instance_valid(view):
			view.settle()


## Whether the reveal is playing.
func is_dealing() -> bool:
	for tween: Tween in _tweens:
		if tween.is_valid() and tween.is_running():
			return true
	return false


func _reset_draft() -> void:
	_draft.clear()
	_draft_setup = _run.start_setup
	status_clicks = 0
	for id: StringName in _run.start_setup.green_ids(_run.balance):
		_draft[id] = AisleBoard.Status.GREEN
	for id: StringName in _run.start_setup.run_only_ids(_run.balance):
		_draft[id] = AisleBoard.Status.ORANGE


func _draft_ids(status: AisleBoard.Status) -> Array[StringName]:
	var found: Array[StringName] = []
	for aisle: AisleDefinition in _run.balance.aisles:
		if _draft.get(aisle.id, AisleBoard.Status.OFF) == status:
			found.append(aisle.id)
	return found


## Aisle `id`'s next draft status: the cycle's next one that isn't full; its own when none is.
func _next_status(id: StringName) -> AisleBoard.Status:
	var current: AisleBoard.Status = _draft.get(id, AisleBoard.Status.OFF)
	var green_max: int = _run.balance.dealt_aisle_count
	var orange_max: int = _run.balance.stock_aisle_count - green_max
	var next: AisleBoard.Status = current
	for step: int in [1, 2]:
		var candidate: AisleBoard.Status = ((int(current) + step) % 3) as AisleBoard.Status
		var full: bool = (
			(candidate == AisleBoard.Status.GREEN and draft_green().size() >= green_max)
			or (candidate == AisleBoard.Status.ORANGE and draft_run_only().size() >= orange_max)
		)
		if not full:
			next = candidate
			break
	return next


## The statuses shown: the draft in SELECT, else the locked aisles.
func _statuses() -> Dictionary[StringName, AisleBoard.Status]:
	if _run.start_setup.stage == StartSetup.Stage.SELECT:
		return _draft
	var shown: Dictionary[StringName, AisleBoard.Status] = {}
	for id: StringName in _run.start_setup.green_ids(_run.balance):
		shown[id] = AisleBoard.Status.GREEN
	for id: StringName in _run.start_setup.run_only_ids(_run.balance):
		shown[id] = AisleBoard.Status.ORANGE
	return shown


func _target(id: StringName) -> StringName:
	return StartSetupRules.target_block(_run, _profile, carry_slot, id)


func _render_board() -> void:
	var statuses: Dictionary[StringName, AisleBoard.Status] = _statuses()
	var listable: Array[StringName] = StartSetupRules.listable_ids(_run.balance, _profile)
	var done: int = StartSetupRules.completed(_run.balance, _profile).size()
	var selecting: bool = _run.start_setup.stage == StartSetup.Stage.SELECT
	var picking: bool = choosing()
	var tips: Dictionary[StringName, String] = {}
	var pills: Dictionary[StringName, String] = {}
	var clickable: Array[StringName] = []
	var targets: Dictionary[StringName, StringName] = {}
	tips[StartSetup.STAPLES] = "The Staples shelf always fills the Staples basket"
	pills[StartSetup.STAPLES] = "ALWAYS"
	for aisle: AisleDefinition in _run.balance.aisles:
		var id: StringName = aisle.id
		var status: AisleBoard.Status = statuses.get(id, AisleBoard.Status.OFF)
		pills[id] = ["", "STARTER", "RUN ONLY"][status]
		if not listable.has(id):
			pills[id] = "OPENS AT %d" % _run.balance.aisle_listable_min
		if carrying():
			var reason: StringName = _target(id)
			targets[id] = reason
			pills[id] = StartReasons.target_word(reason)
			if reason == &"":
				tips[id] = (
					"Drop %s here to pick its replacement"
					% _run.starter.core_cards[carry_slot].display_name
				)
				clickable.append(id)
			else:
				tips[id] = StartReasons.target(_run, reason)
		elif not listable.has(id):
			tips[id] = "Opens at %d items" % _run.balance.aisle_listable_min
		elif picking:
			var next: AisleBoard.Status = _next_status(id)
			if next == status:
				tips[id] = (
					"STARTER CART is full (%d) and RUN ONLY is full (%d): click a coloured aisle to free a place"
					% [
						_run.balance.dealt_aisle_count,
						_run.balance.stock_aisle_count - _run.balance.dealt_aisle_count
					]
				)
			else:
				tips[id] = "Click: %s" % ["not today", "STARTER CART", "RUN ONLY"][next]
				clickable.append(id)
		elif selecting:
			tips[id] = StartReasons.choose_line(_run, done)
		else:
			tips[id] = "Locked in for this run"
	if carrying():
		targets[StartSetup.STAPLES] = &"slot"
		pills[StartSetup.STAPLES] = ""
		tips[StartSetup.STAPLES] = "Regulars are replaced from completed aisles"
	var focus: int = board.focus
	board.show_board(_run, _profile, statuses, tips, pills, clickable, targets)
	if picking:
		for id: StringName in board.ids:
			if not clickable.has(id) and id != StartSetup.STAPLES and listable.has(id):
				board.rows[id].modulate = AisleBoard.MUTED
	board.set_focus(focus)
	if carrying():
		(
			board
			. set_note(
				"REPLACE %s" % _run.starter.core_cards[carry_slot].display_name.to_upper(),
				(
					"Drop it on a gold aisle row, or click one. %d of %d replacements left · Esc puts it down."
					% [
						StartSetupRules.swaps_left(_run, _profile),
						StartSetupRules.swap_limit(_run, _profile)
					]
				)
			)
		)
	elif picking:
		(
			board
			. set_note(
				"SET TODAY'S AISLES",
				(
					"Click an aisle: not today › STARTER CART › RUN ONLY. STARTER CART %d/%d · RUN ONLY %d/%d."
					% [
						draft_green().size(),
						_run.balance.dealt_aisle_count,
						draft_run_only().size(),
						_run.balance.stock_aisle_count - _run.balance.dealt_aisle_count
					]
				)
			)
		)
	elif selecting:
		board.set_note(
			"TODAY'S AISLES", "Picked for you today. %s." % StartReasons.choose_line(_run, done)
		)
	else:
		board.set_note(
			"LOCKED IN FOR THIS RUN",
			"STARTER CART aisles dealt your baskets; RUN ONLY stays in stock for machine prizes."
		)
	if _rail != null:
		_rail.queue_redraw()


func _render_counter() -> void:
	StartBoardKit.clear(_counter)
	baskets.clear()
	var setup: StartSetup = _run.start_setup
	var selecting: bool = setup.stage == StartSetup.Stage.SELECT
	var done: int = StartSetupRules.completed(_run.balance, _profile).size()
	StartBoardKit.panel(_counter, COUNTER, Palette.TEAL_DARK, Palette.TEAL_LIGHT)
	StartBoardKit.words(
		_counter, "TODAY'S BASKETS", Rect2(480, 122, 260, 28), Palette.MUSTARD_LIGHT
	)
	var line: String = "Covered until you LOCK IN & DEAL"
	if not selecting:
		var reason: StringName = StartSetupRules.restock_block(_run, _profile, 0)
		if setup.restock_basket >= 0:
			line = "RESTOCK used this run"
		elif reason == &"locked":
			line = StartReasons.restock(_run, done, reason, "")
		elif restock_picking:
			line = "RESTOCK which basket? Press 1, 2 or 3 · Esc cancels"
		else:
			line = "RESTOCK one basket's items, once a run (R)"
	counter_line = StartBoardKit.body(
		_counter, line, Rect2(760, 126, 490, 22), Palette.TEAL_LIGHT, 14
	)
	counter_line.name = "CounterLine"
	counter_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter_line.add_theme_font_override("font", ArtStyle.bold_font(700))
	var sources: Array[StringName] = (
		StartSetupRules.basket_sources(_run.balance, draft_green())
		if selecting
		else setup.basket_sources()
	)
	while sources.size() < 1 + _run.balance.dealt_aisle_count:
		sources.append(&"")
	for index: int in sources.size():
		var source: StringName = sources[index]
		var view: StartBasketView = StartBasketView.new(index)
		view.position = Vector2(BASKET_LEFT + index * BASKET_STEP, BASKET_TOP)
		_counter.add_child(view)
		baskets.append(view)
		view.restock_pressed.connect(func(at: int) -> void: restock_requested.emit(at))
		var aisle: AisleDefinition = AisleBoard._aisle(_run, source)
		var title: String = (
			"Staples"
			if source == StartSetup.STAPLES
			else aisle.display_name if aisle != null else "STARTER CART ?"
		)
		var cards: Array[CardDefinition] = []
		if not selecting and index < setup.baskets.size():
			cards = setup.baskets[index].cards
		var state: StringName = &""
		var tip: String = ""
		if not selecting:
			var reason: StringName = StartSetupRules.restock_block(_run, _profile, index)
			tip = StartReasons.restock(_run, done, reason, title)
			match reason:
				&"":
					state = &"pick" if restock_picking else &"open"
				&"locked", &"none":
					state = reason
		view.show_basket(
			source,
			title,
			StartBoardKit.glyph(aisle) if source != &"" else null,
			cards,
			selecting,
			state,
			tip,
			setup.restock_basket == index
		)
	if _rail != null:
		_rail.queue_redraw()


func _render_tray() -> void:
	StartBoardKit.clear(_tray)
	regulars.clear()
	var done: int = StartSetupRules.completed(_run.balance, _profile).size()
	StartBoardKit.panel(_tray, TRAY, Palette.TEAL_DARK, Palette.TEAL_LIGHT)
	StartBoardKit.words(_tray, "YOUR REGULARS", Rect2(480, 404, 220, 28), Palette.MUSTARD_LIGHT)
	var subtitle: Label = StartBoardKit.body(
		_tray,
		"in every run · replacements never re-deal" if done > 0 else "in every run",
		Rect2(700, 408, 540, 22),
		Palette.TEAL_LIGHT,
		14
	)
	subtitle.add_theme_font_override("font", ArtStyle.bold_font(700))
	var slots: int = _run.starter.core_cards.size()
	var wood: Panel = StartBoardKit.panel(
		_tray,
		Rect2(REGULAR_LEFT - 8, 498, (slots - 1) * REGULAR_STEP + 108 + 16, 76),
		Palette.WOOD,
		Palette.WOOD_DARKEST
	)
	wood.name = "Wood"
	StartBoardKit.panel(
		wood, Rect2(0, 66, wood.size.x, 10), Palette.WOOD_LIGHT, Palette.WOOD_DARKEST
	)
	for slot: int in slots:
		var holder: Control = Control.new()
		holder.name = "Regular%d" % slot
		holder.position = Vector2(REGULAR_LEFT + slot * REGULAR_STEP, REGULAR_TOP)
		holder.size = StartItemTile.SIZE
		holder.mouse_filter = Control.MOUSE_FILTER_STOP
		holder.mouse_default_cursor_shape = (
			Control.CURSOR_DRAG if done > 0 else Control.CURSOR_ARROW
		)
		holder.gui_input.connect(_regular_input.bind(slot))
		_tray.add_child(holder)
		regulars.append(holder)
		var tile: StartItemTile = StartItemTile.new(_run.starter.core_cards[slot])
		holder.add_child(tile)
		var frame: Panel = StartBoardKit.panel(
			holder, Rect2(-4, -4, 116, 140), Color(0, 0, 0, 0), Palette.GOLD
		)
		frame.name = "Carried"
		(frame.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(4)
		frame.visible = slot == carry_slot
		var original: CardDefinition = _run.start_setup.originals[slot]
		if _run.starter.core_cards[slot] != original:
			var was: Button = StartBoardKit.key(
				holder, "WAS", Rect2(0, 136, 108, 26), func() -> void: restore_requested.emit(slot)
			)
			was.name = "Was"
			was.tooltip_text = "Put %s back" % original.display_name
			StartBoardKit.restyle(was, Palette.PAPER, Palette.INK, 2)
			var caption: Label = StartBoardKit.key_caption(was)
			caption.add_theme_color_override("font_color", Palette.INK)
			UiKit.place_pixel_label(caption, Rect2(18, 0, 50, 20), true)
			StartBoardKit.item(was, original, Vector2(68, 1), 20)
	var tip: Panel = StartBoardKit.panel(_tray, TIP, Palette.TEAL_BLACK, Palette.INK)
	tip.name = "Tip"
	if done == 0:
		StartBoardKit.icon(tip, StartBoardKit.PADLOCK, Vector2(12, 12))
	tray_tip = StartBoardKit.body(
		tip, _tray_text(done), Rect2(12, 36 if done == 0 else 12, 236, 126), Palette.PAPER, 14
	)
	tray_tip.name = "Words"
	tray_tip.add_theme_font_override("font", ArtStyle.bold_font(700))
	tray_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Shows which regular is carried (dimmed, gold frame) and the tip, without rebuilding the tray.
func _mark_carried() -> void:
	for slot: int in regulars.size():
		var holder: Control = regulars[slot]
		(holder.get_child(0) as Control).modulate = (
			Color(1, 1, 1, 0.45) if slot == carry_slot else Color.WHITE
		)
		(holder.get_node("Carried") as Control).visible = slot == carry_slot
	if tray_tip != null:
		tray_tip.text = _tray_text(StartSetupRules.completed(_run.balance, _profile).size())


func _tray_text(done: int) -> String:
	if _message != "":
		return _message
	if done == 0:
		return "Complete an aisle to replace a regular with one of its items."
	if carrying():
		if _hovered != &"" and _hovered != StartSetup.STAPLES:
			var reason: StringName = _target(_hovered)
			if reason != &"":
				return StartReasons.target(_run, reason) + "."
			return "Drop it on this gold aisle to see its items."
		return "Now drop it on a gold aisle row. Esc puts it down."
	return "Drag a regular onto a completed aisle to replace it, or click it, then the aisle."


func _row_clicked(id: StringName) -> void:
	if carrying():
		drop_on(id, "click")
	else:
		cycle(id)


func _row_hovered(id: StringName) -> void:
	_hovered = id
	if carrying() and tray_tip != null:
		tray_tip.text = _tray_text(1)
	if _rail != null:
		_rail.queue_redraw()


## A regular's mouse input (its holder's `gui_input`): a press then a move past DRAG_START drags
## it (released over an aisle row: dropped there); a press and release in place picks it up for
## click then click, or puts it down again. Positions come from the events (holder px).
func _regular_input(event: InputEvent, slot: int) -> void:
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse == null:
		return
	var point: Vector2 = regulars[slot].get_global_transform() * mouse.position
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if button.pressed:
			_press_slot = slot
			_press_at = point
			_dragging = false
		elif _press_slot == slot:
			_press_slot = -1
			if _dragging:
				_dragging = false
				drop_on(board.row_at(point), "drag")
			elif carry_slot == slot:
				cancel_carry()
			else:
				carry(slot, "click")
		return
	if not event is InputEventMouseMotion or _press_slot != slot:
		return
	var moved: float = (
		(point - _press_at).length() / maxf(get_global_transform().get_scale().x, 0.01)
	)
	if not _dragging and moved > DRAG_START:
		if carry(slot, "drag"):
			_dragging = true
		else:
			_press_slot = -1
	if _dragging:
		_move_ghost(point)
		var over: StringName = board.row_at(point)
		if over != _hovered:
			_row_hovered(over)


func _input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if carry_slot >= 0 and motion != null and not _dragging and is_visible_in_tree():
		_move_ghost(motion.global_position)


func _show_ghost() -> void:
	StartBoardKit.clear(ghost)
	var frame: Panel = StartBoardKit.panel(ghost, Rect2(0, 0, 72, 72), Palette.PAPER, Palette.GOLD)
	(frame.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(4)
	var art: Control = StartBoardKit.item(
		ghost, _run.starter.core_cards[carry_slot], Vector2(4, 4), 64
	)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.remove_meta("card")
	ghost.size = Vector2(72, 72)
	ghost.visible = true
	move_child(ghost, -1)
	_move_ghost(get_global_mouse_position())


## Puts the ghost under global point `point`.
func _move_ghost(point: Vector2) -> void:
	if ghost.visible:
		ghost.position = (get_global_transform().affine_inverse() * point - Vector2(36, 36)).floor()


func _draw_rail() -> void:
	if _run == null or board == null or baskets.is_empty():
		return
	var sources: Array[StringName] = []
	for view: StartBasketView in baskets:
		sources.append(view.source)
	var bottom: float = RAIL_Y + 2
	for id: StringName in board.ids:
		var basket: int = sources.find(id)
		if basket < 0 or id == &"":
			continue
		var y: float = board.row_rect(id).get_center().y
		_rail.draw_rect(Rect2(438, y - 2, RAIL_X - 438 + 2, 4), _rail_colour(id))
		bottom = maxf(bottom, y + 2)
	_rail.draw_rect(Rect2(RAIL_X - 2, RAIL_Y, 4, bottom - RAIL_Y), Palette.GREEN_LIGHT)
	_rail.draw_rect(Rect2(RAIL_X, RAIL_Y, BASKET_LEFT - RAIL_X, 4), Palette.GREEN_LIGHT)
	for index: int in baskets.size():
		var x: float = BASKET_LEFT + index * BASKET_STEP
		var colour: Color = _rail_colour(sources[index])
		_rail.draw_rect(Rect2(x - 16, RAIL_Y, StartBasketView.SIZE.x + 16, 4), colour)
		_rail.draw_rect(Rect2(x + 120, RAIL_Y, 4, BASKET_TOP - RAIL_Y), colour)
	_rail.draw_rect(Rect2(0, 608, 1280, 112), Palette.RUBBER_DARK)
	_rail.draw_rect(Rect2(0, 606, 1280, 6), Palette.STEEL_LIGHT)
	for x: int in range(0, 1280, 8):
		_rail.draw_rect(Rect2(x, 618, 4, 12), Palette.STEEL_DARK)


func _rail_colour(id: StringName) -> Color:
	if id == &"":
		return Palette.TEAL_SHADE
	return Palette.GREEN_LIGHT if _hovered == &"" or _hovered == id else Palette.TEAL_SHADE
