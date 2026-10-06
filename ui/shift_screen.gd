class_name ShiftScreen
extends Control
## The shift screen (plan section 2, day 2): draw, redraw, click-to-place into the row, the
## live projected total and receipt, checkout with the count-up, then the next shift or a new
## run. It only displays RunState and ScoreResult; every rule lives in core/.
##
## Click-to-place: click a hand card to pick it up, then click a slot to put it there (a
## filled slot pushes the cards from there to the right). Click a row card to pick it back up.

const STARTER_DECK := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const DEBUG_PANEL := "res://debug/debug_panel.tscn"
const CARDS_FOLDER := "res://data/cards"

var run: RunState
var tracker: CheckoutTracker = CheckoutTracker.new()
var _picked: CardInstance
## True when the picked card was taken from the row: placing it again is a move (plan 8:
## 1 placement, 0 removals); only leaving it in the hand counts as a removal.
var _picked_from_row: bool = false
var _balance: BalanceDefinition
var _click_ms: int = 0
var _redraw_mode: bool = false
var _redraw_pick: Array[CardInstance] = []
var _counting: bool = false
var _run_started_ms: int = 0
var _run_ended_ms: int = -1

var _shift_label: Label
var _quota_label: Label
var _deck_label: Label
var _seed_label: Label
var _slots: Array[PanelContainer] = []
var _row_views: Array[CardView] = []
var _hand_box: HBoxContainer
var _projected_label: Label
var _subtotal_label: Label
var _receipt: ReceiptView
var _redraw_button: Button
var _cancel_button: Button
var _checkout_button: Button
var _banner: PanelContainer
var _banner_label: Label
var _banner_button: Button
var _overlay: Control
var _count_up: CountUp
var _debug_panel: Control
## Web only: keeps the page-visibility callback alive.
var _visibility_callback: JavaScriptObject
## The EventLog autoload, typed. Fetched from the tree because standalone script checks
## don't know autoload names.
@onready var _log: EventLogService = get_node("/root/EventLog")


func _ready() -> void:
	_balance = load(BALANCE)
	_build()
	_watch_focus()
	_add_debug_panel()
	start_new_run(_log.new_run_seed())
	_maybe_play_demo_row()


## Starts a run with a seed (a new random one, or one set from the debug panel).
func start_new_run(seed_value: int) -> void:
	run = RunState.new(seed_value, load(STARTER_DECK), _balance)
	_run_started_ms = Time.get_ticks_msec()
	_run_ended_ms = -1
	_log.begin_run()
	_log.log_event("run_start", {"seed": seed_value, "starting_deck": _ids(run.deck.cards)})
	run.start_shift()
	_on_shift_started()


func _on_shift_started() -> void:
	_picked = null
	_picked_from_row = false
	_redraw_mode = false
	_redraw_pick = []
	_banner.visible = false
	tracker.begin(Time.get_ticks_msec(), _has_focus())
	_log.log_event(
		"shift_start",
		{"shift": run.shift_index + 1, "quota": run.quota(), "cards_drawn": _ids(run.hand())}
	)
	_refresh()


# --- Input -------------------------------------------------------------------------------


func _on_hand_card_clicked(view: CardView) -> void:
	if _counting or run.phase != RunState.Phase.PLANNING:
		return
	if _redraw_mode:
		if _redraw_pick.has(view.card):
			_redraw_pick.erase(view.card)
		elif _redraw_pick.size() < run.balance.redraw_limit:
			_redraw_pick.append(view.card)
	elif _picked == view.card:
		_drop_pick()
	else:
		_pick(view.card, false)
	_refresh()


func _on_row_card_clicked(view: CardView) -> void:
	if _counting or _redraw_mode or run.phase != RunState.Phase.PLANNING:
		return
	var slot: int = run.row.find(view.card)
	if _picked != null:
		_place_picked(slot)
	elif run.remove(view.card):
		_pick(view.card, true)
		_refresh()


func _on_slot_input(event: InputEvent, slot: int) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if not (press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT):
		return
	if _counting or _redraw_mode or _picked == null:
		return
	_place_picked(slot)


func _place_picked(slot: int) -> void:
	if run.place(_picked, slot):
		tracker.on_place()
		_picked = null
		_picked_from_row = false
		_refresh()


func _pick(card: CardInstance, from_row: bool) -> void:
	_drop_pick()
	_picked = card
	_picked_from_row = from_row


## Lets go of the picked card. A card taken from the row stays in the hand: a removal.
func _drop_pick() -> void:
	if _picked != null and _picked_from_row:
		tracker.on_remove()
	_picked = null
	_picked_from_row = false


func _on_background_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if not (press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT):
		return
	if _picked != null and not _counting:
		_drop_pick()
		_refresh()


func _on_redraw_pressed() -> void:
	if not _redraw_mode:
		_redraw_mode = true
		_drop_pick()
		_redraw_pick = []
	elif _redraw_pick.is_empty():
		_redraw_mode = false
	else:
		var replaced: Array[CardInstance] = _redraw_pick.duplicate()
		var received: Array[CardInstance] = run.redraw(replaced)
		_log.log_event(
			"redraw", {"cards_replaced": _ids(replaced), "cards_received": _ids(received)}
		)
		_redraw_mode = false
		_redraw_pick = []
	_refresh()


func _on_cancel_pressed() -> void:
	_redraw_mode = false
	_redraw_pick = []
	_refresh()


func _on_checkout_pressed() -> void:
	if _counting or run.phase != RunState.Phase.PLANNING:
		return
	_counting = true
	_drop_pick()
	_redraw_mode = false
	_click_ms = Time.get_ticks_msec()
	tracker.on_checkout(_click_ms)
	var committed: Array[CardInstance] = run.row.duplicate()
	var result: ScoreResult = run.checkout()
	# Logged at the click, so closing the game during the count-up loses nothing.
	var checkout_data: Dictionary = {
		"shift": run.shift_index + 1,
		"final_order": _ids(committed),
		"score": result.total,
		"quota": run.quota(),
		"passed": run.passed(),
	}
	checkout_data.merge(tracker.measures(committed.size()))
	_log.log_event("checkout", checkout_data)
	if run.phase == RunState.Phase.WON or run.phase == RunState.Phase.LOST:
		_run_ended_ms = Time.get_ticks_msec()
		(
			_log
			. log_event(
				"run_end",
				{
					"result": "win" if run.phase == RunState.Phase.WON else "loss",
					"shift_reached": run.shift_index + 1,
					"last_score": result.total,
					"run_ms": _run_ended_ms - _run_started_ms,
				}
			)
		)
	_refresh()
	await _count_up.play(result, _row_views, _names(committed))
	(
		_log
		. log_event(
			"count_up",
			{
				"shift": run.shift_index + 1,
				"count_up_ms": _count_up.total_shown_ms - _click_ms,
				"fast_forward_used": _count_up.fast_forward_used,
			}
		)
	)
	_counting = false
	_show_banner(result)


func _on_banner_pressed() -> void:
	if run.can_advance():
		run.next_shift()
		_on_shift_started()
	else:
		_log.log_event(
			"restart",
			{"since_run_end_ms": Time.get_ticks_msec() - _run_ended_ms, "screen": "results"}
		)
		start_new_run(_log.new_run_seed())


## Planning time pauses while the player is away. On the web that means the page is hidden
## (another tab, minimised): canvas focus also drops on any click outside the game, e.g. on
## the itch.io page, while the player can still see the hand and think. On desktop it is
## window focus.
func _watch_focus() -> void:
	if OS.has_feature("web"):
		var document: JavaScriptObject = JavaScriptBridge.get_interface("document")
		_visibility_callback = JavaScriptBridge.create_callback(_on_page_visibility_changed)
		document.call("addEventListener", "visibilitychange", _visibility_callback)
	else:
		get_window().focus_exited.connect(_on_focus_exited)
		get_window().focus_entered.connect(_on_focus_entered)


func _has_focus() -> bool:
	if OS.has_feature("web"):
		return not bool(JavaScriptBridge.eval("document.hidden", true))
	return get_window().has_focus()


func _on_page_visibility_changed(_arguments: Array) -> void:
	if _has_focus():
		_on_focus_entered()
	else:
		_on_focus_exited()


func _on_focus_exited() -> void:
	tracker.on_focus_lost(Time.get_ticks_msec())


func _on_focus_entered() -> void:
	tracker.on_focus_gained(Time.get_ticks_msec())


# --- Debug panel (development builds only) -------------------------------------------------


## Plan section 2: the panel is excluded from playtest exports, so it is only loaded by path
## here and never named by class outside debug/.
func _add_debug_panel() -> void:
	if OS.has_feature("playtest") or not ResourceLoader.exists(DEBUG_PANEL):
		return
	var scene: PackedScene = load(DEBUG_PANEL)
	_debug_panel = scene.instantiate()
	add_child(_debug_panel)
	_debug_panel.call("set_shift_count", _balance.quotas.size())
	_debug_panel.connect(&"seed_requested", _on_debug_seed)
	_debug_panel.connect(&"card_requested", _on_debug_card)
	_debug_panel.connect(&"shift_requested", _on_debug_shift)


## Development builds only: `godot --path . -- --demo-row=eggs,coffee,banana` fills the row with
## those cards and checks out, to watch (or record) the count-up for a chosen row.
func _maybe_play_demo_row() -> void:
	if OS.has_feature("playtest"):
		return
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--demo-row="):
			continue
		var card_ids: PackedStringArray = argument.trim_prefix("--demo-row=").split(",", false)
		_log.log_event("debug", {"action": "demo_row", "cards": Array(card_ids)})
		for card_id: String in card_ids:
			var path: String = "%s/%s.tres" % [CARDS_FOLDER, card_id]
			if ResourceLoader.exists(path):
				_pick(run.debug_add_to_hand(load(path)), false)
				_place_picked(run.row.size())
		_refresh()
		await get_tree().create_timer(0.8).timeout
		_on_checkout_pressed()


func _on_debug_seed(seed_value: int) -> void:
	if _counting:
		return
	_log.log_event("debug", {"action": "set_seed", "seed": seed_value})
	start_new_run(seed_value)


func _on_debug_card(card_id: String) -> void:
	if _counting or run.phase != RunState.Phase.PLANNING:
		return
	var path: String = "%s/%s.tres" % [CARDS_FOLDER, card_id]
	if not ResourceLoader.exists(path):
		return
	_log.log_event("debug", {"action": "add_card", "card": card_id})
	run.debug_add_to_hand(load(path))
	_refresh()


func _on_debug_shift(shift_number: int) -> void:
	if _counting:
		return
	_log.log_event("debug", {"action": "skip_to_shift", "shift": shift_number})
	if run.phase == RunState.Phase.WON or run.phase == RunState.Phase.LOST:
		# An ended run stays ended: replay its seed as a new run instead.
		start_new_run(run.run_seed)
	run.debug_skip_to_shift(shift_number - 1)
	_on_shift_started()


# --- Display -------------------------------------------------------------------------------


func _refresh() -> void:
	_shift_label.text = "Shift %d / %d" % [run.shift_index + 1, run.shift_count()]
	_quota_label.text = "Quota €%d" % run.quota()
	_deck_label.text = "Deck %d" % run.deck.size()
	_seed_label.text = "Seed %d" % run.run_seed
	_refresh_row()
	_refresh_hand()
	_refresh_buttons()
	if not _counting and run.phase == RunState.Phase.PLANNING:
		_refresh_preview()


func _refresh_row() -> void:
	_row_views = []
	for slot: int in range(_slots.size()):
		var panel: PanelContainer = _slots[slot]
		for child: Node in panel.get_children():
			panel.remove_child(child)
			child.queue_free()
		if slot < run.row.size():
			var view: CardView = CardView.new(run.row[slot])
			view.clicked.connect(_on_row_card_clicked)
			panel.add_child(view)
			_row_views.append(view)
		else:
			var hint: Label = Label.new()
			hint.text = str(slot + 1)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hint.add_theme_font_size_override("font_size", 28)
			hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.18))
			hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(hint)
		var placeable: bool = _picked != null and run.can_place(_picked) and slot <= run.row.size()
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		style.border_color = Palette.MUSTARD if placeable else Color(1, 1, 1, 0.15)


func _refresh_hand() -> void:
	for child: Node in _hand_box.get_children():
		_hand_box.remove_child(child)
		child.queue_free()
	for card: CardInstance in run.hand():
		var view: CardView = CardView.new(card)
		view.clicked.connect(_on_hand_card_clicked)
		if _redraw_mode and _redraw_pick.has(card):
			view.set_highlight(CardView.Highlight.REDRAW)
		elif card == _picked:
			view.set_highlight(CardView.Highlight.SELECTED)
		_hand_box.add_child(view)


func _refresh_buttons() -> void:
	var planning: bool = run.phase == RunState.Phase.PLANNING and not _counting
	_checkout_button.disabled = not planning
	_redraw_button.disabled = not planning or run.redraw_used
	_cancel_button.visible = _redraw_mode
	if _redraw_mode:
		_redraw_button.text = (
			"Confirm redraw (%d/%d)" % [_redraw_pick.size(), run.balance.redraw_limit]
		)
	else:
		_redraw_button.text = (
			"Redraw used" if run.redraw_used else "Redraw up to %d" % [run.balance.redraw_limit]
		)


func _refresh_preview() -> void:
	var result: ScoreResult = run.preview()
	tracker.on_preview(run.row.size(), result.total)
	_receipt.show_result(result, _names(run.row))
	for slot: int in range(_row_views.size()):
		_row_views[slot].show_badge(result.payouts[slot], false)
		_row_views[slot].set_tags(result.tags[slot])
	_projected_label.text = "Projected €%d" % result.total
	var enough: bool = result.total >= run.quota()
	_projected_label.add_theme_color_override(
		"font_color", Palette.GOOD if enough else Palette.TOMATO
	)
	# The big subtotal belongs to the count-up; while planning, the projected total is enough.
	_subtotal_label.text = ""


func _show_banner(result: ScoreResult) -> void:
	match run.phase:
		RunState.Phase.SCORED:
			_banner_label.text = "Shift passed!  €%d / €%d" % [result.total, run.quota()]
			_banner_button.text = "Next shift"
		RunState.Phase.WON:
			_banner_label.text = "Run won!  €%d / €%d" % [result.total, run.quota()]
			_banner_button.text = "New run"
		RunState.Phase.LOST:
			_banner_label.text = (
				"Short by €%d.  €%d / €%d" % [run.quota() - result.total, result.total, run.quota()]
			)
			_banner_button.text = "New run"
	_banner.visible = true
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2(0.6, 0.6)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.25)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = Palette.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.gui_input.connect(_on_background_input)
	add_child(background)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var page: VBoxContainer = VBoxContainer.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 28)
	page.add_child(top)
	_shift_label = _info_label(top, 22)
	_quota_label = _info_label(top, 22)
	_deck_label = _info_label(top, 16)
	_seed_label = _info_label(top, 16)
	var build: Label = _info_label(top, 14)
	build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build.text = str(ProjectSettings.get_setting("next_customer/build_label", ""))

	var middle: HBoxContainer = HBoxContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 24)
	page.add_child(middle)
	var row_column: VBoxContainer = VBoxContainer.new()
	row_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_column.add_theme_constant_override("separation", 10)
	middle.add_child(row_column)
	var row_title: Label = _info_label(row_column, 16)
	row_title.text = "CHECKOUT  (scanned left to right)"
	# Room above the row for the value badges over each card.
	row_title.custom_minimum_size = Vector2(0, 72)
	row_title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	row_column.add_child(row)
	for slot: int in range(_balance.slot_count):
		row.add_child(_slot_panel(slot))
	var totals: HBoxContainer = HBoxContainer.new()
	totals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	totals.add_theme_constant_override("separation", 30)
	row_column.add_child(totals)
	_projected_label = _info_label(totals, 30)
	_subtotal_label = _info_label(totals, 44)
	_subtotal_label.add_theme_color_override("font_color", Palette.MUSTARD)
	_subtotal_label.add_theme_constant_override("outline_size", 8)
	_subtotal_label.add_theme_color_override("font_outline_color", Palette.INK)
	_receipt = ReceiptView.new()
	_receipt.custom_minimum_size = Vector2(330, 0)
	_receipt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(_receipt)

	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 16)
	page.add_child(bottom)
	_hand_box = HBoxContainer.new()
	_hand_box.custom_minimum_size = Vector2(0, CardView.CARD_SIZE.y + 12)
	_hand_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_hand_box.add_theme_constant_override("separation", 8)
	_hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_hand_box)
	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(170, 0)
	buttons.add_theme_constant_override("separation", 10)
	bottom.add_child(buttons)
	_checkout_button = _button(buttons, "CHECKOUT", _on_checkout_pressed, 22)
	_checkout_button.custom_minimum_size = Vector2(0, 70)
	_redraw_button = _button(buttons, "", _on_redraw_pressed, 15)
	_cancel_button = _button(buttons, "Cancel", _on_cancel_pressed, 14)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_count_up = CountUp.new()
	add_child(_count_up)
	_count_up.setup(_overlay, _receipt, _subtotal_label)

	_banner = PanelContainer.new()
	var banner_style: StyleBoxFlat = StyleBoxFlat.new()
	banner_style.bg_color = Palette.PAPER
	banner_style.border_color = Palette.INK
	banner_style.set_border_width_all(4)
	banner_style.set_corner_radius_all(12)
	banner_style.set_content_margin_all(24)
	_banner.add_theme_stylebox_override("panel", banner_style)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_banner)
	var banner_column: VBoxContainer = VBoxContainer.new()
	banner_column.add_theme_constant_override("separation", 16)
	_banner.add_child(banner_column)
	_banner_label = Label.new()
	_banner_label.add_theme_font_size_override("font_size", 32)
	_banner_label.add_theme_color_override("font_color", Palette.INK)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_column.add_child(_banner_label)
	_banner_button = _button(banner_column, "", _on_banner_pressed, 22)
	_banner.visible = false


func _slot_panel(slot: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = CardView.CARD_SIZE
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Color(1, 1, 1, 0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.gui_input.connect(_on_slot_input.bind(slot))
	_slots.append(panel)
	return panel


func _info_label(parent: Control, font_size: int) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.LIGHT_TEXT)
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, action: Callable, font_size: int) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


static func _ids(cards: Array[CardInstance]) -> Array:
	var ids: Array = []
	for card: CardInstance in cards:
		ids.append(String(card.definition.id))
	return ids


static func _names(cards: Array[CardInstance]) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for card: CardInstance in cards:
		names.append(card.definition.display_name)
	return names
