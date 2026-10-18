class_name RewardPanel
extends PanelContainer
## The reward choice after a passed shift (plan section 2): pick 1 of the offered items for
## the deck, or skip. It only shows the offer and reports the choice; RunState applies it. When
## the next shift is inspected, its notice shows in red above the items (plan section 3.9), so
## the pick can take it into account.
##
## The offer shows as items (#75, decision 4A): each card is a tray ItemView, its sprite over its
## price sticker (with its aisle's glyph once show_rack or print_offer gave it the run), and the
## shift screen's hover scanner reads them like the hand's (ScanController.cover_offers) once
## the panel accepts clicks (can_scan).
##
## Two ways in. The impulse rack pops in (show_offer, show_rack) and arms ARM_MS after it
## appeared, once the mouse is up. A passed shift's reward is the dessert's print-out
## (show_printout, #61; full build plan 6.2): it appears at the printer feed beside the receipt,
## on the shift screen's stage (#55: wherever the stage sits in the window), without the repeated
## headline, and its items lift out of the printer over the tuning's printout_lift_ms (under
## reduced motion they fade in in place). It arms as soon as the lift has ended and the mouse is
## up, so the tap that skipped the dessert never picks an item. A tap during the lift (its own
## PressReader) skips it at CountUp.DESSERT_SKIP, like a dessert skipped earlier; either sets the
## timeline's presentation_skipped. Shown again after the deck view or the deck-full chooser, the
## panel never replays its presentation. On the print-out, products are promo products (stocked
## products on special offer, full build plan 7.2): a cosmetic PROMO tag on their price sticker
## says so.

signal picked(card: CardDefinition)
signal skipped
signal deck_requested
## The offer's items were built (show_offer or show_printout): the scanner watches them.
signal items_shown

## How a print-out's cards come in (show_printout): they lift at the player's speed, lift at
## CountUp.DESSERT_SKIP (the dessert was skipped: presentation_skipped), or show in place at
## once (a resumed run: no dessert).
enum Lift { NORMAL, SKIPPED, NONE }

## The pop-in arms this long after the panel appeared, once the mouse is up.
const ARM_MS := 350
## The print-out's cards start this far below their place, at PRINTOUT_START_SCALE, and lift.
const PRINTOUT_DROP_PX := 120.0
const PRINTOUT_START_SCALE := 0.6
## The print-out's gap to the receipt it sits beside, and the top bar it stays below (the shade
## starts there too). The print-out itself stays under the hung monitor (#80): its area starts
## PRINTOUT_GAP under the monitor's foot (MonitorView.DRAWN_RECT), on the stage.
const PRINTOUT_GAP := 24.0
const PRINTOUT_TOP := 64.0
const PRINTOUT_AREA_TOP := MonitorView.DRAWN_RECT.end.y + PRINTOUT_GAP
## The impulse rack's headline (show_rack).
const RACK_HEADLINE := "Impulse rack: grab one before shift 1?"
## The PROMO tag on a print-out product's price sticker (sticker coordinates): over the sticker's
## glyph corner, as a redraw mark is (ItemView.REDRAW_RECT), clear of the base value and the
## summary even tilted by PROMO_TILT_DEG.
const PROMO_TEXT := "PROMO"
const PROMO_RECT := Rect2(52, 4, 52, 20)
const PROMO_TILT_DEG := 8.0
const PROMO_SIZE := 12
## The tag's text inside its face, in canvas pixels.
const PROMO_PADDING := 3
## The gap between the offered items.
const ITEM_GAP := 22

## The offer's presentation timeline (presented_ms, armed_ms, decide_ms, presentation_skipped;
## plan section 8), started by show_offer (the pop-in) or show_printout (the printer feed) and
## kept while the panel is hidden and shown again. A skipped print-out sets presentation_skipped.
var timeline: OfferTimeline = OfferTimeline.new()
var _tuning: CountUpTuning
var _headline: Label
var _note: Label
var _warning: Label
## The offered items, in a row.
var _cards: HBoxContainer
## Holds the items' place in the column while they lift (the items are free inside it).
var _cards_holder: Control
var _deck_button: Button
var _skip_button: Button
## The panel only reacts once the mouse has been released after it appeared, so clicks meant
## to speed up the count-up never pick a card the player didn't see.
var _armed: bool = false
var _shown_ms: int = 0
## Showing a print-out (show_printout) rather than the pop-in.
var _printout: bool = false
## The receipt the print-out sits beside (kept beside it as the screen lays out).
var _beside: Control
## The stage the print-out stays on (its rect is read again every frame, as the window resizes).
var _stage: Control
## The print-out's lift, until it has ended (null for a pop-in or once lifted).
var _lift: Tween
var _reader: PressReader
## The run's balance (show_rack, print_offer): the offered products' aisles, for their glyphs.
var _balance: BalanceDefinition


func _init(tuning: CountUpTuning = null) -> void:
	_tuning = tuning if tuning != null else load(CountUp.TUNING_PATH) as CountUpTuning
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.INK
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	_headline = UiKit.label("", 28, Palette.INK)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_headline)
	_note = UiKit.label("Pick an item for your cart, or skip.", 16, Palette.MUTED_INK)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_note)
	_warning = UiKit.label("", 18, Palette.TOMATO)
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.visible = false
	column.add_child(_warning)
	_cards_holder = Control.new()
	_cards_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_cards_holder)
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", ITEM_GAP)
	_cards.custom_minimum_size = Vector2(0, ItemView.TRAY_SIZE.y)
	_cards_holder.add_child(_cards)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_skip_button = UiKit.button(buttons, "Skip", func() -> void: skipped.emit(), 18, "ui_back")
	# The deck view makes its own sound as it opens.
	_deck_button = UiKit.button(buttons, "", func() -> void: deck_requested.emit(), 18, "")
	_reader = PressReader.new()
	add_child(_reader)
	_reader.tapped.connect(func(_now_ms: int) -> void: skip_printout())
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	if _printout:
		_place_beside()
	if _armed:
		return
	var waited: bool = not is_lifting()
	if not _printout:
		waited = Time.get_ticks_msec() - _shown_ms >= ARM_MS
	if waited and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_set_armed(true)
		_reader.end()
		timeline.mark_armed(Time.get_ticks_msec())


func _set_armed(armed: bool) -> void:
	_armed = armed
	_skip_button.disabled = not armed
	_deck_button.disabled = not armed


## The impulse rack: the panel pops in at the centre with `headline`. `warning` is the next
## shift's inspection notice, or "" for none.
func show_offer(
	offer: Array[CardDefinition],
	headline: String,
	deck_size: int,
	deck_limit: int,
	warning: String = ""
) -> void:
	_fill(offer, headline, deck_size, deck_limit, warning)
	_printout = false
	_place_cards()
	_shown_ms = Time.get_ticks_msec()
	timeline = OfferTimeline.new(_shown_ms)
	_set_armed(false)
	timeline.presented_when(UiKit.pop_in(self))


## `run`'s impulse rack (full build plan section 3), before shift 1.
func show_rack(run: RunState) -> void:
	_balance = run.balance
	show_offer(run.impulse_offer, RACK_HEADLINE, run.deck.size(), run.balance.deck_limit)


## A passed shift's reward, printed at the printer feed (`feed_ms`, Time.get_ticks_msec(): the
## timeline starts there) and centred in the room on `stage` left of `beside` (the receipt). Its
## items come in as `lift` says: over printout_lift_ms at `speed` (the player's speed setting),
## at CountUp.DESSERT_SKIP (then presentation_skipped), or in place at once; under
## `reduced_motion` they fade in in place.
func show_printout(
	offer: Array[CardDefinition],
	deck_size: int,
	deck_limit: int,
	warning: String,
	beside: Control,
	stage: Control,
	feed_ms: int,
	speed: float = 1.0,
	lift: Lift = Lift.NORMAL,
	reduced_motion: bool = false
) -> void:
	_fill(offer, "", deck_size, deck_limit, warning)
	_printout = true
	_beside = beside
	_stage = stage
	visible = true
	scale = Vector2.ONE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	reset_size()
	_place_beside()
	_shown_ms = feed_ms
	timeline = OfferTimeline.new(feed_ms)
	timeline.presentation_skipped = lift == Lift.SKIPPED
	_set_armed(false)
	for view: ItemView in items():
		if view.card.definition.is_product():
			_add_promo_sticker(view)
	_place_cards()
	if lift == Lift.NONE:
		timeline.mark_presented(Time.get_ticks_msec())
		return
	Sfx.play_at(self, "print")
	_lift = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lift.set_speed_scale(CountUp.DESSERT_SKIP if lift == Lift.SKIPPED else maxf(speed, 0.01))
	var seconds: float = _tuning.printout_lift_ms / 1000.0
	_cards.modulate.a = 0.0
	_lift.tween_property(_cards, "modulate:a", 1.0, seconds)
	if not reduced_motion:
		_cards.position.y += PRINTOUT_DROP_PX
		_cards.scale = Vector2(PRINTOUT_START_SCALE, PRINTOUT_START_SCALE)
		_lift.tween_property(_cards, "position:y", _cards.position.y - PRINTOUT_DROP_PX, seconds)
		_lift.tween_property(_cards, "scale", Vector2.ONE, seconds)
	_lift.finished.connect(_on_lifted)
	_reader.begin()


## The reward of `run`'s passed shift as the dessert's print-out, beside `receipt` on `stage`:
## from `count_up`'s printer feed, at the player's speed setting and reduced motion, skipped
## with its dessert. `resumed` (no dessert) shows it lifted at once.
func print_offer(
	run: RunState, receipt: Control, stage: Control, count_up: CountUp, resumed: bool
) -> void:
	var plan: CountUpPlan = count_up.plan
	var feed_ms: int = count_up.printer_feed_ms
	var lift: Lift = Lift.SKIPPED if count_up.dessert_skipped else Lift.NORMAL
	_balance = run.balance
	show_printout(
		run.offer,
		run.deck.size(),
		run.balance.deck_limit,
		InspectionTag.next_notice(run.next_inspection),
		receipt,
		stage,
		feed_ms if feed_ms >= 0 and not resumed else Time.get_ticks_msec(),
		plan.speed_setting if plan != null else 1.0,
		Lift.NONE if resumed else lift,
		plan != null and plan.reduced_motion
	)


## Where the print-out goes beside a receipt at `receipt` on a stage at `stage` (both global
## rects): the room on the stage right of the receipt, under the hung monitor.
static func printout_area(receipt: Rect2, stage: Rect2) -> Rect2:
	var left: float = minf(receipt.end.x + PRINTOUT_GAP, stage.end.x)
	return Rect2(
		left,
		stage.position.y + PRINTOUT_AREA_TOP,
		stage.end.x - left,
		maxf(stage.size.y - PRINTOUT_AREA_TOP, 0.0)
	)


## The PROMO tag on `view`'s price sticker, at PROMO_RECT (for tests: promo_sticker()).
static func _add_promo_sticker(view: ItemView) -> void:
	var sticker: Label = UiKit.label(PROMO_TEXT, PROMO_SIZE, Palette.PAPER)
	sticker.name = PROMO_TEXT
	sticker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sticker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.TOMATO
	style.set_corner_radius_all(3)
	style.set_content_margin_all(0)
	style.content_margin_left = PROMO_PADDING
	style.content_margin_right = PROMO_PADDING
	sticker.add_theme_stylebox_override("normal", style)
	view.add_child(sticker)
	sticker.position = view.sticker().position + PROMO_RECT.position
	sticker.size = PROMO_RECT.size
	sticker.pivot_offset = PROMO_RECT.size / 2.0
	sticker.rotation = deg_to_rad(PROMO_TILT_DEG)


## An offered item's PROMO tag, or null.
static func promo_sticker(view: CardView) -> Label:
	return view.get_node_or_null(PROMO_TEXT) as Label


## Centred in the room on the stage right of the receipt (the items lift inside the panel, which
## stays put).
func _place_beside() -> void:
	if not is_instance_valid(_beside) or not is_instance_valid(_stage):
		return
	var area: Rect2 = printout_area(_beside.get_global_rect(), _stage.get_global_rect())
	# Centred in its area; a print-out taller than the area starts at its top.
	var place: Vector2 = (area.get_center() - size / 2.0).round()
	place.y = maxf(place.y, area.position.y)
	global_position = place


## The print-out's items are still lifting.
func is_lifting() -> bool:
	return _lift != null


## Showing the dessert's print-out (not the impulse rack's pop-in).
func is_printout() -> bool:
	return visible and _printout


## A tap during the lift skips it: the items finish lifting at CountUp.DESSERT_SKIP.
func skip_printout() -> void:
	if not is_lifting():
		return
	timeline.presentation_skipped = true
	_lift.set_speed_scale(CountUp.DESSERT_SKIP)


func _on_lifted() -> void:
	_lift = null
	timeline.mark_presented(Time.get_ticks_msec())
	_place_cards()


## The items fill their holder (centred in the column, as wide as they are), at rest.
func _place_cards() -> void:
	_cards.size = _cards.get_combined_minimum_size()
	_cards_holder.custom_minimum_size = _cards.size
	_cards.position = Vector2.ZERO
	_cards.pivot_offset = Vector2(_cards.size.x / 2.0, _cards.size.y)
	_cards.scale = Vector2.ONE
	_cards.modulate.a = 1.0


func _fill(
	offer: Array[CardDefinition], headline: String, deck_size: int, deck_limit: int, warning: String
) -> void:
	if _lift != null:
		_lift.kill()
		_lift = null
	_reader.end()
	_headline.text = headline
	_headline.visible = not headline.is_empty()
	_warning.text = warning
	_warning.visible = not warning.is_empty()
	var full: bool = deck_size >= deck_limit
	_note.text = (
		"Your cart is full: picking an item means removing one."
		if full
		else "Pick an item for your cart, or skip."
	)
	_deck_button.text = "View cart (%d/%d)" % [deck_size, deck_limit]
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for card: CardDefinition in offer:
		var aisle: AisleDefinition = _balance.aisle_of(card) if _balance != null else null
		var view: ItemView = ItemView.new(CardInstance.new(card, 0), aisle, ItemView.Form.TRAY)
		view.clicked.connect(_on_card_clicked)
		_cards.add_child(view)
	items_shown.emit()


## The offered items, in order.
func items() -> Array[ItemView]:
	var views: Array[ItemView] = []
	for child: Node in _cards.get_children():
		views.append(child as ItemView)
	return views


## Whether the scanner may read the offered items: the panel is shown and accepts clicks (not
## while it pops in or its items lift).
func can_scan() -> bool:
	return is_visible_in_tree() and _armed and not is_lifting()


## Shown but not yet accepting clicks (the top bar's Cart waits for it too).
func is_arming() -> bool:
	return visible and not _armed


## The inspection notice shown, or "" (for tests).
func warning_text() -> String:
	return _warning.text if _warning.visible else ""


func _on_card_clicked(view: CardView) -> void:
	if _armed:
		picked.emit(view.card.definition)
