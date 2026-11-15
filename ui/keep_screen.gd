class_name KeepScreen
extends Control
## The Golden basket's keep screen (#132; the user's call of 2026-11-02: "golden basket in the
## center, the previous conveyor items listed, drag and drop inside it"). Over the shift screen
## after the count-up, before the machine: the shade, GOLDEN BASKET and its hint on the store's
## teal sign plate, the golden basket drawn as the hand's (its back, its places, the inside's
## darkening, its front) at BASKET_SCALE in the middle, and under it LAST CHECKOUT with the KEPT
## counter ("0/2 KEPT": kept of PinPlay.keep_count) and the steel tray of the items the checkout
## put on the belt, each a mini card with its name and price. An item dragged from the tray into
## the basket is kept for the next shift's first basket (PinPlay.keep, up to keep_count); one
## dragged out of the basket back to the tray lets it go. A click does the same (into the first
## free place, or back out). DONE closes it (`done`).
##
## Polish batch 2 (the polish audit's "keep"): the parts pop in (UiKit.pop_in, its ui_open sound)
## as the shade fades in; Enter or Space presses DONE, and so does Esc when that loses no choice.
##
## The drag feels like the shift screen's (CardDrag; the user's 2026-11-02 review: "not as smooth
## as in the shift scene"): past DRAG_THRESHOLD a ghost of the item (ItemView.Form.GHOST, lifted
## and tilted) follows the mouse centred on it, its source fades, the target it would land on
## lights up with a slot tick (the basket brightens, and over it the ghost grows to the
## basket's size; the tray brightens), and a drop pops the item into its new place. A drop
## elsewhere flies the ghost back to where it came from.

## DONE was pressed.
signal done

enum Target { NONE, BASKET, LIST }

const TITLE := "GOLDEN BASKET"
## The hint in hard pixel caps (no number: pixel words print none; the counter says how many).
const HINT := "Drag cards into the basket. They start the next shift."
const LIST_TITLE := "LAST CHECKOUT"
const COUNTER_TEXT := "%d/%d"
const COUNTER_WORD := "KEPT"
const DONE_TEXT := "DONE"
const SHADE_ALPHA := 0.84
const TITLE_SIZE := 30
const HINT_SCALE := 2
const LIST_TITLE_SIZE := 14
const COUNTER_SIZE := 16
const BUTTON_SIZE := 22
const DONE_WIDTH := 200.0
const BASKET_SCALE := 2.0
## The basket unit as the hand draws one (in its own coordinates, its rim's left at 0): the back,
## the item places, the inside's darkening and the front (HandBaskets, HandRow).
const UNIT_SIZE := Vector2(216, 164)
const BACK_AT := Vector2(0, 60)
const FRONT_AT := Vector2(0, 76)
const PLACE_AT: Array[Vector2] = [Vector2(12, 0), Vector2(108, 0)]
const PLACE_SIZE := Vector2(96, 96)
const INSIDE_STEPS: Array[Rect2] = [Rect2(8, 70, 200, 4), Rect2(8, 74, 200, 4)]
const INSIDE_ALPHAS: Array[float] = [0.14, 0.28]
## Where things sit on the 1280 x 720 screen (polish batch 2): the sign's top and padding (left,
## top, right, bottom), the basket's top, the gap from the basket's foot to the tray's header row
## (LAST CHECKOUT and the counter), that row's height, the gap from it to the tray and the gap
## from the tray to DONE.
const SIGN_Y := 8.0
const SIGN_PADDING := Vector4(22, 6, 22, 10)
const BASKET_Y := 84.0
const ROW_GAP := 2.0
const ROW_HEIGHT := 28.0
const TRAY_GAP := 4.0
const DONE_GAP := 10.0
## The steel tray under the basket (a 9-slice of TRAY_MARGIN art px): its padding, its width when
## it holds few cards, and the widest it gets (cards shrink past TRAY_MAX_WIDTH's nine: a Double
## checkout's 14).
const TRAY_FRAME := preload("res://art/frames/steel_tray.png")
const TRAY_MARGIN := 4
const TRAY_PADDING := Vector2(16, 12)
const TRAY_MIN_WIDTH := 560.0
const TRAY_MAX_WIDTH := 1180.0
## A tray card: the item's art (CELL_SIZE at full size) on paper with an ink edge, its name and its
## price (a coupon: COUPON) under it.
const CELL_SIZE := 96.0
const CELL_GAP := 10
const CARD_PAD := 4.0
const CARD_EDGE := 2
const NAME_HEIGHT := 18.0
const NAME_SIZE := 12
const NAME_MIN_SIZE := 9
const PRICE_HEIGHT := 24.0
const PRICE_SIZE := 16
const COUPON_TEXT := "COUPON"
const COUPON_SIZE := 11
const DRAG_KIND := "keep_item"
## The keys wait this long after the screen opens (like ResultsPanel.ARM_MS), so a Space tap left
## over from skipping the count-up never presses DONE before the choice is seen.
const ARM_MS := 600
## The drag (as CardDrag's): the ghost's alpha, the source's fade, the target's light, the
## ghost's grow time, the way back, and a landing's pop.
const GHOST_ALPHA := 0.92
const SOURCE_ALPHA := 0.3
const TARGET_LIGHT := Color(1.18, 1.14, 1.04)
const GROW_TIME := 0.12
const BACK_TIME := 0.14
const POP_SCALE := 1.25
const POP_TIME := 0.22
## The keys that press DONE (Esc too, when it loses no choice: choice_left).
const DONE_KEYS: Array[Key] = [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]

var _run: RunState
var _armed_ms: int = 0
## Everything but the shade, at the window's size: it pops in (UiKit.pop_in).
var _content: Control
var _shade: ColorRect
var _sign: PanelContainer
var _basket: Control
var _places: Array[Control] = []
var _row: Control
var _list_title: Label
var _counter: PanelContainer
var _counter_number: Label
var _belt: PanelContainer
var _list: HBoxContainer
var _cards: Array[CardInstance] = []
var _done_button: FramedButton
## The drag: the card pressed (null: none), whether it came from the basket, where the press was,
## whether it became a drag, its ghost, the faded source and the target under the mouse.
var _carried: CardInstance
var _from_basket: bool = false
var _press_at: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _ghost: ItemView
var _source: Control
var _target: Target = Target.NONE
var _swell: Tween
## The card whose new place pops at the next _show.
var _popped: CardInstance


## The screen for `run`'s checked-out items (PinPlay.keepable).
func _init(run: RunState) -> void:
	_run = run
	name = "KeepScreen"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cards = PinPlay.keepable(run)
	_shade = ColorRect.new()
	_shade.name = "Shade"
	_shade.color = Color(Palette.INK, SHADE_ALPHA)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_content = Control.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_build_sign()
	_build_basket()
	_build_row()
	_build_belt()
	_done_button = UiKit.framed_button(
		null, DONE_TEXT, done.emit, BUTTON_SIZE, UiKit.BUTTON_FRAME, Vector2(DONE_WIDTH, 0)
	)
	_done_button.name = "KeepDone"
	_content.add_child(_done_button)
	_show()


## Lays the parts out for the window and pops them in (UiKit.pop_in, with the open sound) as the
## shade fades in.
func _ready() -> void:
	_armed_ms = Time.get_ticks_msec() + ARM_MS
	_place_parts()
	resized.connect(_place_parts)
	UiKit.pop_in(_content)
	_shade.color.a = 0.0
	create_tween().tween_property(_shade, "color:a", SHADE_ALPHA, UiKit.POP_IN_SECONDS)


## Enter or Space presses DONE. Esc presses it too when that loses no choice (choice_left: the
## basket is full, or the tray is empty); else it passes on to the pause, as before, so a stray
## Esc never closes the screen with a keep still to choose. Taken before the pause's layer (the
## shift screen's first child) sees it.
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or _done_button.disabled:
		return
	if Time.get_ticks_msec() < _armed_ms:
		return
	var escape: bool = key.keycode == KEY_ESCAPE
	if not DONE_KEYS.has(key.keycode) and not (escape and not choice_left()):
		return
	get_viewport().set_input_as_handled()
	_cancel_drag()
	_done_button.pressed.emit()


## Whether a card could still go into the basket: it has room and the tray holds a card.
func choice_left() -> bool:
	var kept: int = _run.kept.size()
	return kept < PinPlay.keep_count(_run) and kept < _cards.size()


## The basket's two places, left first (for tests: their global rects are the drop targets).
func places() -> Array[Control]:
	return _places.duplicate()


## The golden basket (for layout tests).
func basket() -> Control:
	return _basket


## The sign plate holding the title and the hint (for layout tests).
func sign_plate() -> Control:
	return _sign


## The KEPT counter's plate (for layout tests).
func counter() -> Control:
	return _counter


## The KEPT counter's number ("1/2").
func counter_text() -> String:
	return _counter_number.text


## The steel tray (for layout tests).
func tray() -> Control:
	return _belt


## The parts that pop in (for tests).
func content() -> Control:
	return _content


## The list's cells, one per item not kept (for tests).
func list_cells() -> Array[Control]:
	var cells: Array[Control] = []
	for child: Node in _list.get_children():
		cells.append(child as Control)
	return cells


func done_button() -> FramedButton:
	return _done_button


## Keeps `card` (a drop into the basket, or a click in the list); false when it can't be.
func keep(card: CardInstance) -> bool:
	if PinPlay.is_kept(_run, card) or not PinPlay.keep(_run, card):
		Sfx.play_at(self, "denied")
		return false
	Sfx.play_at(self, "card_place")
	_popped = card
	_show()
	return true


## Lets `card` go (a drag out of the basket, or a click on it there).
func release(card: CardInstance) -> bool:
	if not PinPlay.is_kept(_run, card) or not PinPlay.keep(_run, card):
		return false
	Sfx.play_at(self, "card_return")
	_popped = card
	_show()
	return true


## The title and the hint on the store's teal sign plate (UiKit.SIGN_FRAME), so neither reads over
## the dimmed monitor behind; the hint in hard pixel caps.
func _build_sign() -> void:
	_sign = UiKit.frame_panel(UiKit.SIGN_FRAME, FramedButton.FRAME_MARGIN, SIGN_PADDING)
	_sign.name = "KeepSign"
	_content.add_child(_sign)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	_sign.add_child(column)
	var title: Label = UiKit.display_label(TITLE, TITLE_SIZE, true)
	title.name = "Title"
	title.add_theme_color_override("font_color", Palette.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	# The pixel words are drawn scaled: a holder of their size on screen (measured on the font: the
	# label's own minimum size isn't up to date before it is in the tree) keeps the plate round them.
	var hint: Label = UiKit.pixel_label(HINT.to_upper(), HINT_SCALE, Palette.PAPER)
	hint.name = "Hint"
	var font: Font = ArtStyle.pixel_display_font()
	var words: Vector2 = font.get_string_size(
		hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.PIXEL_TEXT_SIZE
	)
	var holder: Control = Control.new()
	holder.name = "HintHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var high: float = ArtStyle.PIXEL_CAP_HEIGHT + 2.0
	holder.custom_minimum_size = Vector2(ceilf(words.x), high) * HINT_SCALE
	holder.add_child(hint)
	UiKit.place_pixel_label(hint, Rect2(Vector2.ZERO, holder.custom_minimum_size), true)
	column.add_child(holder)


func _build_basket() -> void:
	_basket = Control.new()
	_basket.name = "GoldenBasket"
	_basket.size = UNIT_SIZE
	_basket.scale = Vector2(BASKET_SCALE, BASKET_SCALE)
	_basket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_basket)
	_add_art(HandBaskets.BACK_LEFT_GOLDEN, BACK_AT)
	for index: int in PLACE_AT.size():
		var place: Control = Control.new()
		place.name = "Place%d" % index
		place.position = PLACE_AT[index]
		place.size = PLACE_SIZE
		place.mouse_filter = Control.MOUSE_FILTER_STOP
		place.gui_input.connect(_on_place_input.bind(index))
		_basket.add_child(place)
		_places.append(place)
	for step: int in INSIDE_STEPS.size():
		var inside: ColorRect = ColorRect.new()
		inside.color = Color(Palette.INK, INSIDE_ALPHAS[step])
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.position = INSIDE_STEPS[step].position
		inside.size = INSIDE_STEPS[step].size
		_basket.add_child(inside)
	_add_art(HandBaskets.FRONT_GOLDEN, FRONT_AT)


## The tray's header row: LAST CHECKOUT on its left, the KEPT counter (kept of keep_count in the
## number font, on a paper tag that turns green once the basket is full) on its right.
func _build_row() -> void:
	_row = Control.new()
	_row.name = "TrayRow"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_row)
	_list_title = UiKit.display_label(LIST_TITLE, LIST_TITLE_SIZE, true)
	_list_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row.add_child(_list_title)
	_counter = PanelContainer.new()
	_counter.name = "KeptCounter"
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_counter)
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 6)
	_counter.add_child(line)
	_counter_number = UiKit.number_label("", COUNTER_SIZE, false)
	_counter_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(_counter_number)
	var word: Label = UiKit.display_label(COUNTER_WORD, LIST_TITLE_SIZE, false)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(word)


## The steel tray the list's cards lie in (a drop anywhere on it lets a kept item go).
func _build_belt() -> void:
	var padding: Vector4 = Vector4(TRAY_PADDING.x, TRAY_PADDING.y, TRAY_PADDING.x, TRAY_PADDING.y)
	_belt = UiKit.frame_panel(TRAY_FRAME, TRAY_MARGIN, padding)
	_belt.name = "LastCheckout"
	_belt.mouse_filter = Control.MOUSE_FILTER_STOP
	var height: float = _card_size(CELL_SIZE).y + 2.0 * TRAY_PADDING.y
	_belt.custom_minimum_size = Vector2(TRAY_MIN_WIDTH, height)
	_content.add_child(_belt)
	_list = HBoxContainer.new()
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_theme_constant_override("separation", CELL_GAP)
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_belt.add_child(_list)


func _add_art(texture: Texture2D, at: Vector2) -> void:
	var art: TextureRect = UiKit.sprite(texture)
	art.position = at
	art.size = texture.get_size()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_basket.add_child(art)


## Top to bottom, centred: the sign, the basket, the tray's header row, the tray and DONE. The
## content keeps the window's size, so the pop-in scales it round the window's centre.
func _place_parts() -> void:
	var window: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
	_content.custom_minimum_size = window
	_content.size = window
	_content.pivot_offset = window / 2.0
	var width: float = window.x
	_sign.reset_size()
	_sign.position = Vector2(roundf((width - _sign.size.x) / 2.0), SIGN_Y)
	_basket.position = Vector2((width - UNIT_SIZE.x * BASKET_SCALE) / 2.0, BASKET_Y)
	_belt.reset_size()
	var row_y: float = BASKET_Y + UNIT_SIZE.y * BASKET_SCALE + ROW_GAP
	var tray_left: float = roundf((width - _belt.size.x) / 2.0)
	_row.position = Vector2(tray_left, row_y)
	_row.size = Vector2(_belt.size.x, ROW_HEIGHT)
	_list_title.position = Vector2(4, 0)
	_list_title.size = Vector2(_belt.size.x / 2.0, ROW_HEIGHT)
	_counter.reset_size()
	var counter_y: float = roundf((ROW_HEIGHT - _counter.size.y) / 2.0)
	_counter.position = Vector2(_belt.size.x - _counter.size.x, counter_y)
	_belt.position = Vector2(tray_left, row_y + ROW_HEIGHT + TRAY_GAP)
	_done_button.reset_size()
	var done_y: float = _belt.position.y + _belt.size.y + DONE_GAP
	_done_button.position = Vector2(roundf((width - _done_button.size.x) / 2.0), done_y)


## Shows the kept items in the basket's places (kept order) and the others in the tray.
func _show() -> void:
	var kept: Array[CardInstance] = _kept_cards()
	for index: int in _places.size():
		var place: Control = _places[index]
		for child: Node in place.get_children():
			place.remove_child(child)
			child.queue_free()
		TipTarget.cover_text(place, "")
		if index < kept.size():
			var art: TextureRect = ItemView.item_art(kept[index].definition)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			place.add_child(art)
			TipTarget.cover_text(
				place, "", TipSpec.Kind.ITEM, "", "", kept[index].definition.display_name
			)
			if kept[index] == _popped:
				_pop(art)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var side: float = _cell_side(_cards.size() - kept.size())
	for card: CardInstance in _cards:
		if not kept.has(card):
			var cell: Control = _list_cell(card, side)
			_list.add_child(cell)
			if card == _popped:
				_pop(cell.get_node("Card") as Control)
	_popped = null
	_show_counter(kept.size())
	if is_inside_tree():
		_place_parts()


## The KEPT counter: kept of keep_count, on paper, green once the basket is full.
func _show_counter(kept: int) -> void:
	var room: int = PinPlay.keep_count(_run)
	_counter_number.text = COUNTER_TEXT % [kept, room]
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.GREEN_LIGHT if kept >= room else Palette.PAPER
	box.border_color = Palette.INK
	box.set_border_width_all(CARD_EDGE)
	box.set_corner_radius_all(2)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	_counter.add_theme_stylebox_override("panel", box)


## A tray card's art side: CELL_SIZE, or less when `count` cards would make the tray wider than
## TRAY_MAX_WIDTH.
static func _cell_side(count: int) -> float:
	if count <= 0:
		return CELL_SIZE
	var room: float = TRAY_MAX_WIDTH - 2.0 * TRAY_PADDING.x - CELL_GAP * (count - 1)
	return minf(CELL_SIZE, floorf(room / count - 2.0 * CARD_PAD))


## A tray card's size for art `side` px wide: the art with its name and price under it, on paper.
static func _card_size(side: float) -> Vector2:
	return Vector2(side + 2.0 * CARD_PAD, side + 2.0 * CARD_PAD + NAME_HEIGHT + PRICE_HEIGHT)


func _kept_cards() -> Array[CardInstance]:
	var kept: Array[CardInstance] = []
	for id: int in _run.kept:
		for card: CardInstance in _cards:
			if card.instance_id == id:
				kept.append(card)
	return kept


## A tray cell: the item as a mini card, its art (scaled down to `side` in a full tray) on paper
## with its name and price (a coupon: COUPON) under it; dragged into the basket (or clicked) it's
## kept.
func _list_cell(card: CardInstance, side: float) -> Control:
	var cell: Control = Control.new()
	cell.name = "Keep%d" % card.instance_id
	TipTarget.cover_text(cell, "", TipSpec.Kind.ITEM, "", "", card.definition.display_name)
	var card_size: Vector2 = _card_size(side)
	cell.custom_minimum_size = card_size
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.mouse_default_cursor_shape = Control.CURSOR_DRAG
	var face: Panel = Panel.new()
	face.name = "Card"
	face.size = card_size
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.PAPER
	box.border_color = Palette.INK
	box.set_border_width_all(CARD_EDGE)
	box.set_corner_radius_all(4)
	face.add_theme_stylebox_override("panel", box)
	cell.add_child(face)
	var art: TextureRect = ItemView.item_art(card.definition)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(CARD_PAD, CARD_PAD)
	art.scale = Vector2.ONE * (side / CELL_SIZE)
	face.add_child(art)
	var text_width: float = card_size.x - 2.0 * CARD_PAD
	var title: Label = UiKit.body_label(card.definition.display_name, NAME_SIZE, Palette.INK)
	title.name = "Name"
	title.add_theme_font_override("font", ArtStyle.bold_font(700))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.position = Vector2(CARD_PAD, CARD_PAD + side + 2.0)
	title.size = Vector2(text_width, NAME_HEIGHT)
	_fit_name(title, text_width)
	face.add_child(title)
	var price: Label
	if card.definition.is_coupon():
		price = UiKit.display_label(COUPON_TEXT, COUPON_SIZE, false)
		price.add_theme_color_override("font_color", Palette.TEAL_DARK)
	else:
		price = UiKit.number_label(PriceSticker.price_text(card.definition.base), PRICE_SIZE, false)
	price.name = "Price"
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.position = Vector2(CARD_PAD, title.position.y + NAME_HEIGHT)
	price.size = Vector2(text_width, PRICE_HEIGHT)
	face.add_child(price)
	cell.gui_input.connect(_on_cell_input.bind(card))
	return cell


## Steps the name's font down from NAME_SIZE to NAME_MIN_SIZE until it fits `width` (past that it
## ends in an ellipsis; the hover tip names it in full).
static func _fit_name(label: Label, width: float) -> void:
	var font: Font = label.get_theme_font("font")
	var fitted: int = NAME_SIZE
	while (
		fitted > NAME_MIN_SIZE
		and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width
	):
		fitted -= 1
	label.add_theme_font_size_override("font_size", fitted)


## Keeps the card a test drag `data` carries ({kind, card}; for tests, as a drop on the basket):
## whether it could be dropped there.
func can_drop_in(data: Variant) -> bool:
	var card: CardInstance = _card_of(data)
	if card == null or PinPlay.is_kept(_run, card):
		return false
	return _run.kept.size() < PinPlay.keep_count(_run)


## The ghost of the drag under way (for tests), or null.
func ghost() -> ItemView:
	return _ghost


static func _card_of(data: Variant) -> CardInstance:
	if data is Dictionary and (data as Dictionary).get("kind") == DRAG_KIND:
		return (data as Dictionary).get("card") as CardInstance
	return null


func _on_cell_input(event: InputEvent, card: CardInstance) -> void:
	if _is_press(event):
		var cell: Control = _list.get_node_or_null(NodePath("Keep%d" % card.instance_id))
		_arm(card, false, (event as InputEventMouseButton).global_position, cell)
		accept_event()


func _on_place_input(event: InputEvent, index: int) -> void:
	var kept: Array[CardInstance] = _kept_cards()
	if _is_press(event) and index < kept.size():
		_arm(kept[index], true, (event as InputEventMouseButton).global_position, _places[index])
		accept_event()


## A left button press.
static func _is_press(event: InputEvent) -> bool:
	var press: InputEventMouseButton = event as InputEventMouseButton
	return press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT


## A press on `card` (from the basket when `from_basket`) at `at`, its art in `source`: a click
## or the start of a drag, whichever the mouse does next (_input).
func _arm(card: CardInstance, from_basket: bool, at: Vector2, source: Control) -> void:
	_cancel_drag()
	_carried = card
	_from_basket = from_basket
	_press_at = at
	_source = source


func _input(event: InputEvent) -> void:
	if _carried == null:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if not motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_cancel_drag()  # The release was missed (outside the window).
		elif _dragging:
			_follow(motion.position)
		elif motion.position.distance_to(_press_at) >= CardDrag.DRAG_THRESHOLD:
			_start_drag(motion.position)
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		get_viewport().set_input_as_handled()
		_finish(button.position)


## The button is up at `at`: a click keeps or lets go of the card; a drag drops it on its target
## or flies back.
func _finish(at: Vector2) -> void:
	var card: CardInstance = _carried
	var from_basket: bool = _from_basket
	if not _dragging:
		_cancel_drag()
		if from_basket:
			release(card)
		else:
			keep(card)
		return
	var target: Target = _target_at(at)
	if target == Target.NONE:
		_fly_back()
		return
	_cancel_drag()
	if target == Target.BASKET:
		keep(card)
	else:
		release(card)


## The drag starts at `at`: the ghost (lifted, tilted, at its source's size) and the faded source.
func _start_drag(at: Vector2) -> void:
	_dragging = true
	var aisle: AisleDefinition = _run.balance.aisle_of(_carried.definition)
	_ghost = ItemView.new(_carried, aisle, ItemView.Form.GHOST)
	_ghost.name = "KeepGhost"
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.z_index = 10
	add_child(_ghost)
	_ghost.body.scale = Vector2.ONE * _ghost_scale(_home_target())
	_ghost.body.rotation = deg_to_rad(CardDrag.GHOST_TILT)
	_ghost.body.modulate = Color(1, 1, 1, GHOST_ALPHA)
	if _source != null:
		_source.modulate.a = SOURCE_ALPHA
	Sfx.play_at(self, "card_pickup")
	_follow(at)


## The ghost follows the mouse, centred on it, and the target under it lights up.
func _follow(at: Vector2) -> void:
	_ghost.position = at - get_global_rect().position - ItemView.SPRITE_SIZE / 2.0
	_set_target(_target_at(at))


## The target a drop at `at` would land on: the basket for a listed card while it has room, the
## belt for a kept one; NONE elsewhere.
func _target_at(at: Vector2) -> Target:
	if _from_basket:
		return Target.LIST if _belt.get_global_rect().has_point(at) else Target.NONE
	var room: bool = _run.kept.size() < PinPlay.keep_count(_run)
	return Target.BASKET if room and _basket.get_global_rect().has_point(at) else Target.NONE


## Where the carried card came from, as a target.
func _home_target() -> Target:
	return Target.BASKET if _from_basket else Target.LIST


## Lights `target` (the other goes dark) with a tick, and grows or shrinks the ghost to its
## size there (back to its source's size off any target).
func _set_target(target: Target) -> void:
	if target == _target:
		return
	_target = target
	_basket.modulate = TARGET_LIGHT if target == Target.BASKET else Color.WHITE
	_belt.modulate = TARGET_LIGHT if target == Target.LIST else Color.WHITE
	if _swell != null:
		_swell.kill()
	if not is_inside_tree():
		return
	if _ghost != null:
		_swell = create_tween()
		var size_at: Target = _home_target() if target == Target.NONE else target
		var grown: Vector2 = Vector2.ONE * _ghost_scale(size_at)
		_swell.tween_property(_ghost.body, "scale", grown, GROW_TIME)
	if target != Target.NONE:
		Sfx.play_at(self, "slot_tick")


## The ghost's scale over `target`: the basket's items are drawn at BASKET_SCALE.
static func _ghost_scale(target: Target) -> float:
	return CardDrag.GHOST_SCALE * (BASKET_SCALE if target == Target.BASKET else 1.0)


## A drop off any target: the ghost flies back to its source and the drag ends there.
func _fly_back() -> void:
	var ghost_view: ItemView = _ghost
	_ghost = null
	var home: Vector2 = ghost_view.position
	if _source != null and is_instance_valid(_source):
		home = _source.get_global_rect().get_center() - get_global_rect().position
		home -= ItemView.SPRITE_SIZE / 2.0
	_cancel_drag()
	var back: Tween = ghost_view.create_tween()
	(
		back
		. tween_property(ghost_view, "position", home, BACK_TIME)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	back.tween_callback(ghost_view.queue_free)


## Ends any drag: no ghost (unless _fly_back took it), the source and targets as they were.
func _cancel_drag() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if _source != null and is_instance_valid(_source):
		_source.modulate.a = 1.0
	_source = null
	_carried = null
	_dragging = false
	_set_target(Target.NONE)


## A new place's item pops in.
func _pop(art: Control) -> void:
	if art == null or not is_inside_tree():
		return
	var rest: Vector2 = art.scale
	art.pivot_offset = art.size / 2.0
	art.scale = rest * POP_SCALE
	var pop: Tween = art.create_tween()
	pop.tween_property(art, "scale", rest, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
