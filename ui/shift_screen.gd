class_name ShiftScreen
extends Control
## The shift screen (plan section 2): draw, redraw, click-to-place into the row, the live
## projected total and receipt, checkout with the count-up, the reward choice, the deck view,
## and the run's results. It only displays RunState and ScoreResult; every rule lives in core/.
##
## Click-to-place: click a hand card to pick it up, then click a slot to put it there (a
## filled slot pushes the cards from there to the right). Click a row card to pick it back up.
##
## The row has slot_count product slots plus coupon-only slots (plan section 3.1). The row is
## compacted, so the coupon slot is a capacity, not a position: no panel is marked as the
## coupon slot (a coupon can go anywhere), and the capacity label counts it instead.

const STARTER_DECK := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const DEBUG_PANEL := "res://debug/debug_panel.tscn"
const CARDS_FOLDER := "res://data/cards"
## How long a notice (e.g. a product that doesn't fit) stays before it fades.
const NOTICE_SECONDS := 2.2

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
## The offer on screen: when it appeared, whether the deck view was opened, and a picked card
## waiting for the player to choose which deck card it replaces.
var _reward_shown_ms: int = 0
var _deck_viewed_for_reward: bool = false
var _pending_reward: CardDefinition

var _shift_label: Label
var _quota_label: Label
var _deck_button: Button
var _seed_label: Label
var _slots: Array[PanelContainer] = []
var _row_views: Array[CardView] = []
var _hand_box: HBoxContainer
var _projected_label: Label
var _capacity_label: Label
var _notice_label: Label
var _notice_tween: Tween
var _subtotal_label: Label
var _receipt: ReceiptView
var _redraw_button: Button
var _cancel_button: Button
var _checkout_button: Button
var _banner: PanelContainer
var _banner_label: Label
var _banner_detail: Label
var _banner_button: Button
var _reward_panel: RewardPanel
## Dims the screen and blocks clicks behind the reward panel, deck view and results.
var _shade: ColorRect
var _banner_armed_ms: int = 0
var _deck_view: DeckView
var _row_box: HBoxContainer
var _overlay: Control
var _count_up: CountUp
var _sfx: Sfx
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
	_clear_notice()
	_picked = null
	_picked_from_row = false
	_redraw_mode = false
	_redraw_pick = []
	_banner.visible = false
	_reward_panel.visible = false
	_deck_view.visible = false
	_pending_reward = null
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
		_explain_if_refused(view.card)
	_refresh()


func _on_row_card_clicked(view: CardView) -> void:
	if _counting or _redraw_mode or run.phase != RunState.Phase.PLANNING:
		return
	var slot: int = run.row.find(view.card)
	# A hand card that fits nowhere (the notice says to take a product out) is let go, so this
	# click takes the row card out instead of repeating the refusal.
	if _picked != null and not _picked_from_row and not run.can_place(_picked):
		_drop_pick()
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
		_sfx.play("click", 1.2)
		_picked = null
		_picked_from_row = false
		_refresh()
	else:
		_explain_if_refused(_picked)


## Plan section 3.1: a product doesn't fit once every product slot is used, even when the
## coupon slot is still free. Says so instead of silently ignoring the click.
func _explain_if_refused(card: CardInstance) -> void:
	if card.definition.is_coupon() or not RowCapacity.products_full(run.balance, run.row):
		return
	var products: String = (
		"%d/%d products" % [RowCapacity.product_count(run.row), run.balance.slot_count]
	)
	if run.row.size() < RowCapacity.card_limit(run.balance):
		_show_notice("%s: only a coupon fits now" % products)
	else:
		_show_notice("%s: take a product out first" % products)


func _show_notice(text: String) -> void:
	_notice_label.text = text
	_notice_label.modulate = Color.WHITE
	_sfx.play("denied", 1.4, -6.0)
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(NOTICE_SECONDS)
	_notice_tween.tween_property(_notice_label, "modulate", Color(1, 1, 1, 0), 0.4)


func _clear_notice() -> void:
	if _notice_tween != null:
		_notice_tween.kill()
		_notice_tween = null
	_notice_label.text = ""


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
	_clear_notice()
	_redraw_mode = false
	_deck_view.visible = false
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
	await _count_up.play(result, _row_views, _names(committed), run.quota())
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
	if run.phase == RunState.Phase.REWARD:
		_show_rewards(result)
	else:
		_show_results(result)


## Results screen: New run.
func _on_banner_pressed() -> void:
	_log.log_event(
		"restart", {"since_run_end_ms": Time.get_ticks_msec() - _run_ended_ms, "screen": "results"}
	)
	start_new_run(_log.new_run_seed())


# --- Rewards and deck view -------------------------------------------------------------------


func _show_rewards(result: ScoreResult) -> void:
	_reward_shown_ms = Time.get_ticks_msec()
	_deck_viewed_for_reward = false
	_pending_reward = null
	_reward_panel.show_offer(
		run.offer,
		"Shift passed!  €%d / €%d" % [result.total, run.quota()],
		run.deck.size(),
		run.balance.deck_limit
	)


func _on_reward_picked(card: CardDefinition) -> void:
	if run.phase != RunState.Phase.REWARD:
		return
	if not run.deck_is_full():
		_finish_reward(card, null)
		return
	# Plan section 2: at the deck limit, taking a card means choosing one to remove.
	# The forced chooser is not the player choosing to look at their deck.
	_pending_reward = card
	_reward_panel.visible = false
	_deck_view.open(
		run.deck.cards,
		(
			"Deck full (%d/%d): choose a card to remove for %s"
			% [run.deck.size(), run.balance.deck_limit, card.display_name]
		),
		true
	)


func _on_reward_skipped() -> void:
	if run.phase == RunState.Phase.REWARD:
		_finish_reward(null, null)


func _on_deck_card_chosen(card: CardInstance) -> void:
	if _pending_reward != null:
		_finish_reward(_pending_reward, card)


func _on_deck_closed() -> void:
	if run.phase == RunState.Phase.REWARD:
		_pending_reward = null
		_reward_panel.visible = true


func _on_reward_deck_requested() -> void:
	_deck_viewed_for_reward = true
	_reward_panel.visible = false
	_deck_view.open(
		run.deck.cards, "Your deck (%d/%d)" % [run.deck.size(), run.balance.deck_limit], false
	)


func _on_deck_button_pressed() -> void:
	if _counting:
		return
	if run.phase == RunState.Phase.REWARD:
		_on_reward_deck_requested()
		return
	_deck_view.open(
		run.deck.cards, "Your deck (%d/%d)" % [run.deck.size(), run.balance.deck_limit], false
	)


## Applies the choice (card null = skip), logs it, and starts the next shift.
func _finish_reward(card: CardDefinition, replaced: CardInstance) -> void:
	var offered: Array = run.offer.map(
		func(offered_card: CardDefinition) -> String: return String(offered_card.id)
	)
	var taken: bool = run.take_reward(card, replaced) if card != null else run.skip_reward()
	if not taken:
		return
	(
		_log
		. log_event(
			"reward",
			{
				"shift": run.shift_index + 1,
				"offered": offered,
				"picked": String(card.id) if card != null else "",
				"skipped": card == null,
				"replaced": String(replaced.definition.id) if replaced != null else "",
				"decide_ms": Time.get_ticks_msec() - _reward_shown_ms,
				"deck_view_opened": _deck_viewed_for_reward,
			}
		)
	)
	_pending_reward = null
	_reward_panel.visible = false
	_deck_view.visible = false
	_sfx.play("click")
	run.next_shift()
	_on_shift_started()


func _on_export_pressed() -> void:
	var screen: String = "shift"
	if _counting:
		screen = "count_up"
	elif _banner.visible:
		screen = "results"
	elif run.phase == RunState.Phase.REWARD:
		screen = "reward"
	_log.export_logs(screen)


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
	_deck_button.text = "Deck %d/%d" % [run.deck.size(), run.balance.deck_limit]
	_seed_label.text = "Seed %d" % run.run_seed
	_capacity_label.text = (
		"Products %d/%d  ·  Coupon slot %d/%d"
		% [
			RowCapacity.product_count(run.row),
			run.balance.slot_count,
			RowCapacity.coupon_slots_used(run.balance, run.row),
			run.balance.coupon_slot_count
		]
	)
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
			panel.add_child(_empty_slot_hint(slot))
		var placeable: bool = _picked != null and run.can_place(_picked) and slot <= run.row.size()
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		style.border_color = Palette.MUSTARD if placeable else Color(1, 1, 1, 0.15)


## An empty panel shows its slot number.
func _empty_slot_hint(slot: int) -> Label:
	var hint: Label = Label.new()
	hint.text = str(slot + 1)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 28)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.18))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hint


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


## The win and lose screens (plan section 2).
func _show_results(result: ScoreResult) -> void:
	var won: bool = run.phase == RunState.Phase.WON
	_banner_label.text = "RUN WON!" if won else "RUN OVER"
	_banner_label.add_theme_color_override("font_color", Palette.GOOD if won else Palette.TOMATO)
	if won:
		_banner_detail.text = (
			"All %d shifts cleared. Last checkout €%d / €%d."
			% [run.shift_count(), result.total, run.quota()]
		)
	else:
		_banner_detail.text = (
			"Shift %d / %d: €%d of €%d, short by €%d."
			% [
				run.shift_index + 1,
				run.shift_count(),
				result.total,
				run.quota(),
				run.quota() - result.total,
			]
		)
	_banner_button.text = "New run"
	# Like the reward panel: New run waits for the mouse to be released after it appears.
	_banner_button.disabled = true
	_banner_armed_ms = Time.get_ticks_msec() + 350
	UiKit.pop_in(_banner)


func _process(_delta: float) -> void:
	_shade.visible = _reward_panel.visible or _deck_view.visible or _banner.visible
	var waited: bool = Time.get_ticks_msec() >= _banner_armed_ms
	if _banner.visible and _banner_button.disabled and waited:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_banner_button.disabled = false


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
	_deck_button = UiKit.button(top, "", _on_deck_button_pressed, 16)
	_seed_label = _info_label(top, 16)
	var build: Label = _info_label(top, 14)
	build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build.text = str(ProjectSettings.get_setting("next_customer/build_label", ""))
	UiKit.button(top, "Export log", _on_export_pressed, 14)

	var middle: HBoxContainer = HBoxContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 24)
	page.add_child(middle)
	var row_column: VBoxContainer = VBoxContainer.new()
	row_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_column.add_theme_constant_override("separation", 10)
	middle.add_child(row_column)
	var row_header: HBoxContainer = HBoxContainer.new()
	row_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Room above the row for the value badges over each card.
	row_header.custom_minimum_size = Vector2(0, 72)
	row_column.add_child(row_header)
	var row_title: Label = _info_label(row_header, 16)
	row_title.text = "CHECKOUT  (scanned left to right)"
	row_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_capacity_label = _info_label(row_header, 16)
	_capacity_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_capacity_label.modulate = Color(1, 1, 1, 0.75)
	_row_box = HBoxContainer.new()
	_row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Narrow enough that 7 slots and the receipt fit the 1280 px window (plan section 3.1).
	_row_box.add_theme_constant_override("separation", 10)
	row_column.add_child(_row_box)
	for slot: int in range(RowCapacity.card_limit(_balance)):
		_row_box.add_child(_slot_panel(slot))
	var totals: HBoxContainer = HBoxContainer.new()
	totals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	totals.add_theme_constant_override("separation", 30)
	row_column.add_child(totals)
	_projected_label = _info_label(totals, 30)
	_subtotal_label = _info_label(totals, 44)
	_subtotal_label.add_theme_color_override("font_color", Palette.MUSTARD)
	_subtotal_label.add_theme_constant_override("outline_size", 8)
	_subtotal_label.add_theme_color_override("font_outline_color", Palette.INK)
	_notice_label = _info_label(totals, 16)
	_notice_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_notice_label.add_theme_color_override("font_color", Palette.TOMATO)
	_receipt = ReceiptView.new()
	_receipt.custom_minimum_size = Vector2(300, 0)
	_receipt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(_receipt)

	var hint: Label = _info_label(page, 14)
	hint.text = (
		"Click a card, then a slot to place it  ·  click a placed card to take it back"
		+ "  ·  hold Space or the mouse to fast-forward the count"
	)
	hint.modulate = Color(1, 1, 1, 0.6)
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
	_sfx = Sfx.new()
	add_child(_sfx)
	_count_up = CountUp.new()
	add_child(_count_up)
	_count_up.setup(_overlay, _receipt, _subtotal_label, _sfx, _row_box)

	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.5)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Below the top bar, so Export log and Deck stay reachable on every screen.
	_shade.offset_top = 64
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.visible = false
	add_child(_shade)
	_reward_panel = RewardPanel.new()
	add_child(_reward_panel)
	_reward_panel.picked.connect(_on_reward_picked)
	_reward_panel.skipped.connect(_on_reward_skipped)
	_reward_panel.deck_requested.connect(_on_reward_deck_requested)
	_banner = UiKit.paper_panel()
	add_child(_banner)
	var banner_column: VBoxContainer = VBoxContainer.new()
	banner_column.add_theme_constant_override("separation", 16)
	_banner.add_child(banner_column)
	_banner_label = UiKit.label("", 48, Palette.INK)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_column.add_child(_banner_label)
	_banner_detail = UiKit.label("", 20, Palette.INK)
	_banner_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_column.add_child(_banner_detail)
	var banner_buttons: HBoxContainer = HBoxContainer.new()
	banner_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_buttons.add_theme_constant_override("separation", 16)
	banner_column.add_child(banner_buttons)
	_banner_button = _button(banner_buttons, "", _on_banner_pressed, 22)
	_button(banner_buttons, "Export log", _on_export_pressed, 18)
	_banner.visible = false
	# Added last, so the deck view sits above the reward panel and the results.
	_deck_view = DeckView.new()
	add_child(_deck_view)
	_deck_view.card_chosen.connect(_on_deck_card_chosen)
	_deck_view.closed.connect(_on_deck_closed)


func _slot_panel(slot: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = CardView.CARD_SIZE
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Color(1, 1, 1, 0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	# No content margin: a filled slot stays exactly card-sized, so the row never shifts.
	style.set_content_margin_all(0)
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
	# Mouse-only buttons: keyboard focus would let Space (the fast-forward key) press CHECKOUT.
	button.focus_mode = Control.FOCUS_NONE
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
