class_name HandbookClip
extends Control
## A handbook entry's example (v1.06; redone 2026-11-11 so every entry shows the game's own
## effects): a window onto a slice of the shift's counter, built from the shift's own parts at
## their stage places (ShiftStage): the painted store behind (StoreArt), the counter, the belt
## (BeltPanel, cut to the row) with the row's cells on it (RowStrip: each card's belt item,
## ItemView, with its ticket on the rail, and the day events' slot marks), and over them the
## planning layer (PlanningLayer) on a PlanningModel of the example's real score
## (HandbookExample): the stickers ("+3", "×2", "=6€", the grey WASTED), the rail strips, the pay
## windows, the halos and sparkles, the deny stamps, and the batch and chain frames with the
## MORNING line and the PAIR clasps; a Price gun relabel wears the gun's tag and the gained glyph
## (PinFlow.show_relabel). Under the window, the register strip's LED reads the total, and an
## example with a quota prints the receipt's header beside it (ReceiptTarget on the receipt paper:
## TODAY'S TARGET over PROJECTED, then the count's TOTAL, BEATEN! as it crosses the quota).
##
## play() loops a short shift: the items ride in from the right one by one (RIDE_EVERY apart, each
## RIDE_S over RIDE_FROM px, in RIDE_STEPS steps), the planning effects slap on (PlanningLayer
## slap_new) and hold PLAN_HOLD_S; then the count, as BeltRide plays it: the strips, halos and
## planned pays go (keep_stickers) and each score step lands in turn, STEP_S apart, its sticker
## firing (EffectSticker.fire: a punch, then its check) and a day event's slot mark with it; each
## payout pops its ticket's paid window (PAY_S apart) and the LED counts up. The total pops, holds
## HOLD_S, the clip fades and starts over. Reduced motion (`still`) shows the planning state and
## the total at once and never loops. Decor only: it takes no clicks (its tickets' glyphs and chips
## still show their tooltips, as on the belt), and every number in it is the score's.

## The stage band the window shows (ShiftStage coordinates): from over the stickers on the items'
## shoulders down to the price rail's shadow; a taller stack raises its top and a slot mark or
## MORNING pin hung under the tickets lowers its foot (_fit_view).
const VIEW_TOP := 272.0
const VIEW_BOTTOM := ShiftStage.BELT_RECT.position.y + 194.0
## The room kept over the highest sticker or stamp and under the lowest hung mark.
const VIEW_HEADROOM := 8.0
## The window's ink frame and the register strip under it, the LED total at its right end.
const BORDER := 2.0
const STRIP_HEIGHT := 48.0
const LED_SIZE := Vector2(196, 40)
const LED_FRAME := preload("res://art/frames/led_panel.png")
const LED_MARGIN := 4
const LED_CAPTION := "TOTAL"
const LED_FONT_SIZE := 26
const LED_CAPTION_SCALE := 2
const LED_INSET := 14.0
## An example's receipt on the strip's left: the receipt's paper (2 art px margins) round its
## header, RECEIPT_PADDING px in, the strip RECEIPT_GAP px taller than it.
const RECEIPT := preload("res://art/frames/receipt_paper.png")
const RECEIPT_MARGIN := 2
const RECEIPT_PADDING := 6.0
const RECEIPT_GAP := 12.0
## The fewest cells the belt shows (BeltPanel's shortest baked belt).
const MIN_CELLS := BeltPanel.MIN_CELLS
const RIDE_EVERY := 0.11
const RIDE_S := 0.2
const RIDE_FROM := 64.0
const RIDE_STEPS := 4.0
const SLAP_AFTER := 0.25
const PLAN_HOLD_S := 1.8
const STEP_S := 0.2
const PAY_S := 0.32
const PAY_POP := 1.25
const POP_SCALE := 1.15
const POP_S := 0.08
const HOLD_S := 1.8
const FADE_S := 0.3

## Shows the planning state and the total at once and never loops (the profile's reduced motion).
var still: bool = false:
	set(value):
		still = value
		if _layer != null:
			_layer.reduced_motion = value
var _example: HandbookExample
var _model: PlanningModel
var _window: Control
var _stage: Control
var _belt: BeltPanel
var _row: RowStrip
var _layer: PlanningLayer
var _views: Array[ItemView] = []
var _led: PanelContainer
var _total: Label
var _caption: Label
var _receipt: PanelContainer
var _target: ReceiptTarget
var _strip_height: float = STRIP_HEIGHT
## The planning state shows as built (not hidden for a ride, nor turned to the count's look).
var _planned: bool = false
var _view_top: float = VIEW_TOP
var _view_bottom: float = VIEW_BOTTOM
var _belt_width: float = 0.0
var _tween: Tween
var _pops: Array[Tween] = []


## The clip of `example` (scored), `width` wide.
func _init(example: HandbookExample, width: float) -> void:
	name = "HandbookClip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_example = example
	var tuning: PlanningTuning = load(PlanningEffects.TUNING_PATH) as PlanningTuning
	var none_upgrades: Array[UpgradeDefinition] = []
	_model = PlanningModel.build(
		example.result, example.cards, none_upgrades, example.events, tuning
	)
	_window = Control.new()
	_window.name = "Window"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.clip_contents = true
	_window.position = Vector2.ONE * BORDER
	add_child(_window)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = ShiftStage.SIZE
	_window.add_child(_stage)
	_build_stage(tuning)
	_build_strip()
	_size_to(width)
	_show_final()


## Plays the clip from the start (the final state at once when `still`).
func play() -> void:
	_stop()
	if still or not is_inside_tree():
		_show_final()
		return
	_reset()
	_tween = create_tween()
	for slot: int in range(_views.size()):
		_tween.parallel().tween_method(_ride.bind(slot), 0.0, 1.0, RIDE_S).set_delay(
			RIDE_EVERY * slot
		)
	_tween.tween_interval(SLAP_AFTER)
	_tween.tween_callback(_show_planning.bind(true))
	_tween.tween_interval(PLAN_HOLD_S)
	_tween.tween_callback(_start_count)
	var running: int = 0
	var steps: Array[ScoreStep] = _example.result.steps
	for index: int in range(steps.size()):
		var step: ScoreStep = steps[index]
		var paid: bool = step.step_type == ScoreStep.StepType.PAYOUT
		if not paid and not _shows_step(index):
			continue
		if paid:
			running += step.value
		_tween.tween_interval(PAY_S if paid else STEP_S)
		_tween.tween_callback(_land.bind(index, running))
	_tween.tween_callback(_pop_total)
	_tween.tween_interval(HOLD_S)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_S)
	_tween.tween_callback(play)


## Stops the loop on its final state.
func stop() -> void:
	_stop()
	_show_final()


func is_playing() -> bool:
	return _tween != null and _tween.is_running()


## The row's stuck price labels (PriceLabelLayer), over the tickets and the frames.
func price_labels() -> PriceLabelLayer:
	return _row.labels


## The tickets, in row order.
func tickets() -> Array[PriceSticker]:
	var found: Array[PriceSticker] = []
	for view: ItemView in _views:
		found.append(view.sticker())
	return found


## The belt items, in row order.
func items() -> Array[ItemView]:
	return _views.duplicate()


## The planning layer over the row (its stickers, strips, stamps and frames).
func planning_layer() -> PlanningLayer:
	return _layer


## The row's cells (RowStrip: the day events' slot marks hang on them).
func row_strip() -> RowStrip:
	return _row


## The window onto the counter (canvas coordinates).
func window_rect() -> Rect2:
	return _window.get_global_rect()


## The total shown.
func total_text() -> String:
	return _total.text


func total_label() -> Label:
	return _total


## The register strip's LED (its frame round the total).
func led() -> Control:
	return _led


## The receipt's header an example with a quota shows (null without one).
func receipt_target() -> ReceiptTarget:
	return _target


func chain_frames() -> ChainFrames:
	return _layer.get_node(^"ChainFrames") as ChainFrames


func batch_frames() -> BatchFrames:
	for child: Node in _layer.get_children():
		var frames: BatchFrames = child as BatchFrames
		if frames != null and not frames is ChainFrames:
			return frames
	return null


func _ready() -> void:
	_show_final()
	_fit_view.call_deferred()


func _exit_tree() -> void:
	_stop()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.INK)
	var strip: Rect2 = Rect2(
		BORDER, size.y - _strip_height - BORDER, size.x - BORDER * 2.0, _strip_height
	)
	draw_rect(strip, Palette.STEEL_DARKEST)
	draw_rect(Rect2(strip.position, Vector2(strip.size.x, BORDER)), Palette.STEEL_LIGHT)
	var shade: Rect2 = Rect2(strip.position + Vector2(0, BORDER), Vector2(strip.size.x, BORDER))
	draw_rect(shade, Palette.STEEL)


## The stage's parts at their shift places: the store's art, the counter, the belt with the row on
## it, the day events' slot marks, the planning layer over them.
func _build_stage(tuning: PlanningTuning) -> void:
	var store: TextureRect = UiKit.sprite(StoreArt.texture())
	store.name = "Store"
	store.position = StoreShelves.WALL_RECT.position
	store.size = StoreShelves.WALL_RECT.size
	_stage.add_child(store)
	var counter: ColorRect = ColorRect.new()
	counter.name = "Counter"
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.color = StoreBackdrop.COUNTER_COLOR
	counter.position = Vector2(0, ShiftStage.COUNTER_TOP)
	counter.size = Vector2(ShiftStage.SIZE.x, ShiftStage.SIZE.y - ShiftStage.COUNTER_TOP)
	_stage.add_child(counter)
	_belt = BeltPanel.new()
	_belt.position = ShiftStage.BELT_RECT.position
	_belt.size = ShiftStage.BELT_RECT.size
	_stage.add_child(_belt)
	_row = RowStrip.new()
	_belt.add_child(_row)
	var count: int = _example.cards.size()
	_row.set_slot_count(count)
	_belt.set_cells(maxi(count, MIN_CELLS))
	_belt_width = ShiftStage.BELT_RECT.size.x - _belt.cut()
	var height: float = _row.get_combined_minimum_size().y
	var left: float = ShiftStage.ROW_POSITION.x - RowStrip.overhang(count) / 2.0
	_row.position = Vector2(left, ShiftStage.ROW_BOTTOM - height) - ShiftStage.BELT_RECT.position
	_belt.place_scanner(_row.position.x + RowStrip.CELL_SIZE.x * _row.box.scale.x / 2.0)
	var instances: Array[CardInstance] = []
	for index: int in range(count):
		instances.append(CardInstance.new(_example.cards[index], index + 1))
	for view: CardView in _row.show_cards(instances, -1, _ignore_click):
		_views.append(view as ItemView)
	for slot: int in _example.relabels:
		PinFlow.show_relabel(_views[slot], _example.relabels[slot])
	var none_upgrades: Array[UpgradeDefinition] = []
	_row.show_slot_marks(SlotMark.marks_for(none_upgrades, _example.events, count, count))
	_layer = PlanningLayer.new()
	_layer.tuning = tuning
	_layer.reduced_motion = still
	_stage.add_child(_layer)
	# As on the stage: a stuck price label lies over its ticket's frame, and the MORNING's line
	# keeps clear of the slot marks.
	_row.labels.mount_after(_layer.get_node(^"ChainFrames"))
	KeywordMarks.of(_layer).obstacles = _row.mark_rects
	_pass_mouse(_stage)


## The register strip's LED: TOTAL in hard pixel words, the amount in the number font.
func _build_strip() -> void:
	_led = UiKit.frame_panel(LED_FRAME, LED_MARGIN)
	_led.name = "Led"
	_led.size = LED_SIZE
	add_child(_led)
	_caption = UiKit.pixel_label(LED_CAPTION, LED_CAPTION_SCALE, Palette.MUSTARD_LIGHT)
	_caption.name = "Caption"
	add_child(_caption)
	_total = UiKit.number_label("", LED_FONT_SIZE, true)
	_total.name = "Total"
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_total.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_total.add_theme_color_override("font_color", Palette.GOLD)
	add_child(_total)
	if _example.quota <= 0:
		return
	var padding: Vector4 = Vector4.ONE * RECEIPT_PADDING
	_receipt = UiKit.frame_panel(RECEIPT, RECEIPT_MARGIN, padding)
	_receipt.name = "Receipt"
	add_child(_receipt)
	_target = ReceiptTarget.new()
	_target.custom_minimum_size.x = ReceiptTarget.DEFAULT_WIDTH
	_receipt.add_child(_target)
	_target.show_quota(_example.quota)
	_target.show_planned(_example.total(), _example.quota)
	_receipt.size = _receipt.get_combined_minimum_size()
	_strip_height = maxf(STRIP_HEIGHT, _receipt.size.y + RECEIPT_GAP * 2.0)


## Sizes the clip `width` wide round the window (from _view_top), the belt in the window's middle
## and the LED at the strip's right end.
func _size_to(width: float) -> void:
	var view: Vector2 = Vector2(width - BORDER * 2.0, _view_bottom - _view_top)
	_window.size = view
	var belt_left: float = _snap((view.x - _belt_width) / 2.0)
	_stage.position = Vector2(belt_left - ShiftStage.BELT_RECT.position.x, -_view_top)
	custom_minimum_size = Vector2(width, view.y + _strip_height + BORDER * 3.0)
	size = custom_minimum_size
	var strip_top: float = size.y - _strip_height - BORDER
	_led.position = Vector2(
		width - BORDER - LED_SIZE.x - 6.0,
		_snap(strip_top + (_strip_height - LED_SIZE.y) / 2.0) + 2.0
	)
	if _receipt != null:
		_receipt.position = Vector2(BORDER + RECEIPT_GAP, strip_top + RECEIPT_GAP)
	var inner: Rect2 = Rect2(
		_led.position + Vector2(LED_INSET, 0), LED_SIZE - Vector2(LED_INSET * 2.0, 0)
	)
	UiKit.place_pixel_label(_caption, Rect2(inner.position, Vector2(80, LED_SIZE.y)), true)
	_total.position = inner.position
	_total.size = inner.size
	queue_redraw()


## Raises the window's top over a stack taller than VIEW_TOP allows and lowers its foot under
## the slot marks and MORNING pins hung under the tickets (on the art grid).
func _fit_view() -> void:
	if not is_inside_tree():
		return
	var to_stage: Transform2D = _stage.get_global_transform().affine_inverse()
	var top: float = VIEW_TOP
	for slot: int in range(_views.size()):
		var parts: Array[Control] = []
		parts.assign(_layer.stack(slot))
		if _layer.stamp(slot) != null:
			parts.append(_layer.stamp(slot))
		for part: Control in parts:
			top = minf(top, (to_stage * part.get_global_rect()).position.y - VIEW_HEADROOM)
	var bottom: float = VIEW_BOTTOM
	var hung: Array[Rect2] = _row.mark_rects()
	var marks: KeywordMarks = KeywordMarks.of(_layer)
	for pin: MorningPin in marks.pins():
		if pin.is_visible_in_tree():
			hung.append(pin.get_global_rect())
	for rect: Rect2 in hung:
		bottom = maxf(bottom, (to_stage * rect).end.y + VIEW_HEADROOM)
	top = floorf(top / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE
	bottom = ceilf(bottom / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE
	if top != _view_top or bottom != _view_bottom:
		_view_top = top
		_view_bottom = bottom
		_size_to(size.x)


static func _snap(value: float) -> float:
	return roundf(value / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE


## Whether step `index` shows: it has a sticker on its slot, or fires a day event's mark.
func _shows_step(index: int) -> bool:
	var step: ScoreStep = _example.result.steps[index]
	return _sticker_of(step.slot, index) != null or _event_mark(step) != null


## Shows the planning effects on the row; `slap`: the stickers slap on.
func _show_planning(slap: bool) -> void:
	_layer.visible = true
	_layer.show_model(_model, _views)
	_planned = true
	if slap:
		_layer.slap_new({})
	if _target != null:
		_target.show_planned(_example.total(), _example.quota, slap and not still)


## The count starts: the strips, halos and planned pays go, the stickers stay.
func _start_count() -> void:
	_layer.keep_stickers()
	_planned = false
	for ticket: PriceSticker in tickets():
		ticket.clear_pay()
	if _target != null:
		_target.begin_count(0)


## Step `index` lands (BeltRide's step_landed): its sticker fires, a day event's mark fires, a
## payout pops its ticket's paid window and the LED reads `running`.
func _land(index: int, running: int) -> void:
	var step: ScoreStep = _example.result.steps[index]
	var sticker: EffectSticker = _sticker_of(step.slot, index)
	if sticker != null:
		sticker.fire(still)
	var mark: SlotMark = _event_mark(step)
	if mark != null:
		mark.fire(still)
	if step.step_type != ScoreStep.StepType.PAYOUT:
		return
	if step.slot >= 0 and step.slot < _views.size():
		_show_paid(step)
	_total.text = MonitorText.euros(running)
	if _target != null:
		_target.show_running(running)
		if running >= _example.quota and not _target.is_met():
			_target.show_met(true, still)


## The paid ticket (BeltRide's): its window shows the payout, boosted, lowered or zero, popping.
func _show_paid(step: ScoreStep) -> void:
	var view: ItemView = _views[step.slot]
	var base: int = view.card.definition.base
	var pay: PlanningModel.Pay = PlanningModel.Pay.PLAIN
	if step.value == 0 and base > 0:
		pay = PlanningModel.Pay.ZERO
	elif step.value != base:
		pay = PlanningModel.Pay.BOOSTED if step.value > base else PlanningModel.Pay.LOWERED
	view.sticker().set_pay(pay, step.value)
	var window: PriceWindow = view.sticker().window()
	window.pivot_offset = window.size / 2.0
	window.scale = Vector2.ONE * PAY_POP
	var pop: Tween = create_tween()
	pop.tween_property(window, "scale", Vector2.ONE, POP_S * 2.0)
	_pops.append(pop)


## The sticker of step `index` on `slot`'s stack (the fold chip when it is folded), or null.
func _sticker_of(slot: int, index: int) -> EffectSticker:
	var stack: Array[EffectSticker] = _layer.stack(slot)
	for sticker: EffectSticker in stack:
		if sticker.spec().step_index == index:
			return sticker
	if stack.is_empty() or stack[0].spec().kind != StickerSpec.Kind.MORE:
		return null
	if slot < 0 or slot >= _model.slots.size():
		return null
	var specs: Array[StickerSpec] = _model.slots[slot].stickers
	for spec: StickerSpec in specs.slice(0, specs.size() - (stack.size() - 1)):
		if spec.step_index == index:
			return stack[0]
	return null


## The day event's slot mark that a step of that event on its marked slot fires (BeltRide's), or
## null.
func _event_mark(step: ScoreStep) -> SlotMark:
	if step.source_kind != ScoreStep.SourceKind.INSPECTION:
		return null
	var kinds: Array[ScoreStep.StepType] = [
		ScoreStep.StepType.PAYOUT_OVERRIDE,
		ScoreStep.StepType.FLAT,
		ScoreStep.StepType.MULTIPLIER,
	]
	if not kinds.has(step.step_type):
		return null
	return _row.inspection_mark(step.slot, step.source_index)


## The start: every item off to the right and plain (no halo, grey or wrong job), the planning
## layer hidden until the effects slap on (show_model rebuilds it then: clearing it here would
## leave its parts waiting to be freed), the printed prices. The layer takes the count's look first
## (keep_stickers), as at the end of a loop: it lays the belt out every frame, and in the planning
## look it would put the wrong-job chips back on the riding tickets before the effects slap on.
func _reset() -> void:
	modulate.a = 1.0
	_layer.keep_stickers()
	_layer.visible = false
	_planned = false
	for slot: int in range(_views.size()):
		_ride(0.0, slot)
		var view: ItemView = _views[slot]
		view.boost_rings = 0
		view.denied = false
		view.sticker().clear_pay()
		view.sticker().set_wrong_job("")
	_total.text = MonitorText.euros(0)
	_total.scale = Vector2.ONE
	if _target != null:
		_target.show_planned(0, _example.quota)


## Slot `slot` `share` (0 to 1) of its ride in, in RIDE_STEPS steps.
func _ride(share: float, slot: int) -> void:
	var stepped: float = floorf(share * RIDE_STEPS) / RIDE_STEPS
	var view: ItemView = _views[slot]
	view.position.x = _snap(RIDE_FROM * (1.0 - stepped))
	view.modulate.a = 1.0 if share > 0.0 else 0.0


func _pop_total() -> void:
	_total.pivot_offset = Vector2(_total.size.x, _total.size.y / 2.0)
	var pop: Tween = create_tween()
	pop.tween_property(_total, "scale", Vector2.ONE * POP_SCALE, POP_S)
	pop.tween_property(_total, "scale", Vector2.ONE, POP_S)
	_pops.append(pop)


## The planning state: every item in place under its effects, the total on the LED.
func _show_final() -> void:
	modulate.a = 1.0
	for slot: int in range(_views.size()):
		_ride(1.0, slot)
	if is_inside_tree() and not _planned:
		_show_planning(false)
	_layer.visible = true
	_total.text = MonitorText.euros(_example.total())
	_total.scale = Vector2.ONE
	if _target != null:
		_target.show_planned(_example.total(), _example.quota)


func _stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	for pop: Tween in _pops:
		if pop != null and pop.is_valid():
			pop.kill()
	_pops.clear()
	for ticket: PriceSticker in tickets():
		ticket.window().scale = Vector2.ONE


## Every control under `root` that would stop the mouse lets it pass: the clip is decor, and the
## handbook's page scrolls under it.
static func _pass_mouse(root: Node) -> void:
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			control.mouse_filter = Control.MOUSE_FILTER_PASS


static func _ignore_click(_view: CardView) -> void:
	pass
