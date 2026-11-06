class_name HandbookClip
extends Control
## A handbook entry's example row (v1.06, mock-up keywords_guide.html's clip): the example's items
## on a strip of belt, each with its real ticket (PriceSticker) on the rail under it, bound by the
## belt's own marks (BatchFrames, ChainFrames with the MORNING ribbon and PAIR clasps), all from a
## PlanningModel of the example's real score (HandbookExample), and the total at the row's end.
##
## play() loops the mock-up's clip: the items ride in from the right one by one (RIDE_EVERY apart,
## each RIDE_S over RIDE_FROM px), the frames and marks appear, then each slot pays in turn
## (PAY_EVERY apart): its item hops and its ticket's window steps to its pay, the total counting
## up; the total pops, holds HOLD_S and the clip starts over. Reduced motion (`still`) shows the
## final state and never loops. Decor only: it takes no clicks (its tickets' glyphs and chips show
## their tooltips through GlyphTips, as on the belt).

const SLOT_PITCH := 124.0
const ITEM_SIZE := Vector2(96, 96)
const TICKET_TOP := 104.0
const PADDING := Vector2(16, 14)
## The total's box at the row's end.
const TOTAL_WIDTH := 132.0
const TOTAL_FONT_SIZE := 34
const TOTAL_CAPTION := "TOTAL"
const HEIGHT := 228.0
const BORDER := 2.0
## The belt under the items' feet and the rail under the tickets, from the clip's top.
const BELT_BAND := Vector2(70, 100)
const RAIL_BAND := Vector2(100, 184)
const RIDE_EVERY := 0.11
const RIDE_S := 0.18
const RIDE_FROM := 48.0
const MARKS_AFTER := 0.3
const PAY_EVERY := 0.38
const HOP := 8.0
const HOP_S := 0.08
const HOLD_S := 2.0
const FADE_S := 0.3
const POP_SCALE := 1.15

## Shows the final state at once and never loops (the profile's reduced motion).
var still: bool = false
var _example: HandbookExample
var _model: PlanningModel
var _items: Array[TextureRect] = []
var _tickets: Array[PriceSticker] = []
var _batches: BatchFrames
var _chains: ChainFrames
var _total: Label
var _caption: Label
var _row_left: float = 0.0
var _tween: Tween


## The clip of `example` (scored), `width` wide.
func _init(example: HandbookExample, width: float) -> void:
	name = "HandbookClip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(width, HEIGHT)
	size = custom_minimum_size
	_example = example
	var none_upgrades: Array[UpgradeDefinition] = []
	var none_events: Array[InspectionDefinition] = []
	_model = PlanningModel.build(example.result, example.cards, none_upgrades, none_events, null)
	var row_width: float = SLOT_PITCH * example.cards.size() - (SLOT_PITCH - PriceSticker.SIZE.x)
	_row_left = roundf((width - TOTAL_WIDTH - row_width) / 2.0)
	_batches = BatchFrames.new()
	add_child(_batches)
	for slot: int in range(example.cards.size()):
		_add_slot(slot, example.cards[slot])
	_chains = ChainFrames.new()
	add_child(_chains)
	_caption = UiKit.pixel_label(TOTAL_CAPTION, 2, Palette.INK_LIGHT)
	add_child(_caption)
	UiKit.place_pixel_label(_caption, Rect2(width - TOTAL_WIDTH + 16, 80, TOTAL_WIDTH - 24, 20))
	_total = UiKit.number_label("", TOTAL_FONT_SIZE, false)
	_total.name = "Total"
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_total.add_theme_color_override("font_color", Palette.ORANGE_DARK)
	_total.position = Vector2(width - TOTAL_WIDTH + 16, 104)
	_total.size = Vector2(TOTAL_WIDTH - 24, 48)
	add_child(_total)
	_show_marks()
	_show_final()


## Plays the clip from the start (the final state at once when `still`).
func play() -> void:
	_stop()
	if still or not is_inside_tree():
		_show_final()
		return
	_reset()
	_tween = create_tween()
	for slot: int in range(_items.size()):
		_tween.parallel().tween_method(_ride.bind(slot), 0.0, 1.0, RIDE_S).set_delay(
			RIDE_EVERY * slot
		)
	_tween.tween_interval(MARKS_AFTER)
	_tween.tween_callback(_set_marks_shown.bind(true))
	var running: int = 0
	for slot: int in range(_items.size()):
		running += _example.payouts()[slot]
		_tween.tween_interval(PAY_EVERY)
		_tween.tween_callback(_pay.bind(slot, running))
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


## The tickets, in row order.
func tickets() -> Array[PriceSticker]:
	return _tickets.duplicate()


## The items' sprites, in row order.
func items() -> Array[TextureRect]:
	return _items.duplicate()


## The total shown.
func total_text() -> String:
	return _total.text


func total_label() -> Label:
	return _total


func chain_frames() -> ChainFrames:
	return _chains


func batch_frames() -> BatchFrames:
	return _batches


func _exit_tree() -> void:
	_stop()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Palette.INK)
	draw_rect(rect.grow(-BORDER), Palette.CREAM)
	draw_rect(
		Rect2(size.x - TOTAL_WIDTH, BORDER, BORDER, size.y - BORDER * 2.0), Palette.CREAM_SHADE
	)
	var inner: float = size.x - BORDER - TOTAL_WIDTH
	draw_rect(Rect2(BORDER, BELT_BAND.x, inner, BELT_BAND.y - BELT_BAND.x), Palette.RUBBER)
	draw_rect(Rect2(BORDER, RAIL_BAND.x, inner, RAIL_BAND.y - RAIL_BAND.x), Palette.RUBBER_DARK)
	draw_rect(Rect2(BORDER, BELT_BAND.x - BORDER, inner, BORDER), Palette.INK)
	draw_rect(Rect2(BORDER, RAIL_BAND.y, inner, BORDER), Palette.INK)


func _add_slot(slot: int, card: CardDefinition) -> void:
	var item: TextureRect = UiKit.sprite(ArtStyle.item_sprite(card))
	item.name = "Item%d" % slot
	item.size = ITEM_SIZE
	add_child(item)
	var icon: Texture2D = ArtStyle.coupon_icon(card)
	if icon != null:
		var overlay: TextureRect = UiKit.sprite(icon)
		overlay.position = ItemView.COUPON_ICON_RECT.position
		overlay.size = ItemView.COUPON_ICON_RECT.size
		item.add_child(overlay)
	_items.append(item)
	var ticket: PriceSticker = PriceSticker.new(card)
	ticket.name = "Ticket%d" % slot
	add_child(ticket)
	_tickets.append(ticket)
	var wrong: String = _model.slots[slot].wrong_job if slot < _model.slots.size() else ""
	if not wrong.is_empty():
		ticket.set_wrong_job(wrong)
	_place(slot, 0.0)


## Puts slot `slot`'s item and ticket in place, `away` px right of it.
func _place(slot: int, away: float) -> void:
	var x: float = _row_left + SLOT_PITCH * slot + away
	var item_x: float = x + roundf((PriceSticker.SIZE.x - ITEM_SIZE.x) / 2.0)
	_items[slot].position = Vector2(item_x, PADDING.y)
	_tickets[slot].position = Vector2(x, TICKET_TOP)


func _show_marks() -> void:
	var run_batches: Array[PackedInt32Array] = []
	for index: int in _model.run_batch:
		run_batches.append(_model.batches[index])
	_batches.show_batches(_model.runs, run_batches)
	_chains.show_chains(_model)
	var rects: Dictionary[int, Rect2] = {}
	for slot: int in range(_tickets.size()):
		rects[slot] = Rect2(Vector2(_row_left + SLOT_PITCH * slot, TICKET_TOP), PriceSticker.SIZE)
	_batches.lay_out(rects)
	_chains.lay_out(rects)


func _set_marks_shown(shown: bool) -> void:
	_batches.visible = shown
	_chains.visible = shown


## The start: every item off to the right and clear, the tickets' printed prices, no marks.
func _reset() -> void:
	modulate.a = 1.0
	_set_marks_shown(false)
	for slot: int in range(_items.size()):
		_ride(0.0, slot)
		_tickets[slot].clear_pay()
	_total.text = MonitorText.euros(0)
	_total.scale = Vector2.ONE


## Slot `slot` `share` (0 to 1) of its ride in, in 4 steps.
func _ride(share: float, slot: int) -> void:
	var stepped: float = floorf(share * 4.0) / 4.0
	_place(slot, roundf(RIDE_FROM * (1.0 - stepped)))
	_items[slot].modulate.a = 1.0 if share > 0.0 else 0.0
	_tickets[slot].modulate.a = _items[slot].modulate.a


func _pay(slot: int, running: int) -> void:
	_show_pay(slot)
	_total.text = MonitorText.euros(running)
	var item: TextureRect = _items[slot]
	var hop: Tween = create_tween()
	hop.tween_property(item, "position:y", PADDING.y - HOP, HOP_S / 2.0)
	hop.tween_property(item, "position:y", PADDING.y, HOP_S / 2.0)


func _show_pay(slot: int) -> void:
	if slot >= _model.slots.size():
		return
	var planning: PlanningSlot = _model.slots[slot]
	_tickets[slot].set_pay(planning.pay, planning.payout, planning.stamp_caption)


func _pop_total() -> void:
	_total.pivot_offset = Vector2(0.0, _total.size.y / 2.0)
	var pop: Tween = create_tween()
	pop.tween_property(_total, "scale", Vector2.ONE * POP_SCALE, HOP_S)
	pop.tween_property(_total, "scale", Vector2.ONE, HOP_S)


func _show_final() -> void:
	modulate.a = 1.0
	_set_marks_shown(true)
	for slot: int in range(_items.size()):
		_ride(1.0, slot)
		_show_pay(slot)
	_total.text = MonitorText.euros(_example.total())
	_total.scale = Vector2.ONE


func _stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
