class_name PriceLabelLayer
extends Control
## The stuck price labels of a row of tickets, drawn over the whole row (price leak, 2026-11-10):
## a label leaks past its ticket's right edge, and the row's next cell is drawn after its own
## (cells draw left to right), so that cell's ticket, gold ring or blank mat would cut it. Mounted
## after the row's cells (RowStrip; on the shift screen the stage moves it into the planning
## layer, over the batch and chain frames, whose band runs along the tickets' top: mount_after),
## this layer draws every shown label of `windows`, digits included, at its
## window's place, scale and tint: the label is then over the next cell and the frames, and still
## under everything drawn after it (the effect stickers, the panels and screens over the belt),
## which a z_index would not be.
##
## A window whose label it draws leaves the drawing to it (PriceWindow.set_label_cover): a label
## shows once, so a fading ticket's label is not blended twice. While the layer itself is hidden,
## and for a window that left the row, the window draws its own again. Each frame it compares
## what the labels show (their place, tint, leak, digits and inks) with what it drew and redraws
## on a change; a window that moves, hides or changes its price after the layer's frame (a
## tween: the belt's slide, a counted pay's pop) calls refresh() itself, so the drawn label never
## trails its ticket. It is each drawn window's `tip_cover` (TipTarget), so the label's tip shows
## where it lies over the next cell too.
##
## A GOLDEN neighbour's corner sparkle is raised over its row (z_index), so over a label lying on
## it: the layer hides a sparkle that a label of another ticket covers, and shows it again when
## the label goes. Decor only: it takes no clicks.

## Every layer is in this group: a window whose price changes calls their refresh().
const GROUP := &"price_label_layer"

## Returns the row's price windows (Array[PriceWindow]), in draw order.
var windows: Callable = Callable()
## What the drawn labels showed (_state), to redraw only on a change.
var _drawn: Array = []
## The windows whose label it draws, and the sparkles it hid under them.
var _covered: Array[PriceWindow] = []
var _hidden: Array[CanvasItem] = []
## What the last _draw drew (drawn_rects).
var _rects: Array[Rect2] = []


func _init() -> void:
	name = "PriceLabels"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(GROUP)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EXIT_TREE:
			_release()
		NOTIFICATION_VISIBILITY_CHANGED:
			if is_inside_tree():
				refresh()


## Moves the layer in the tree to draw right after `part` (its next sibling), over it and under
## everything after it: the planning layer's frames, on the shift screen.
func mount_after(part: Node) -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	part.add_sibling(self)
	position = Vector2.ZERO


func _process(_delta: float) -> void:
	refresh()


## Checks the row's labels now and redraws them if one changed (each frame, and from a window
## that moved or changed after it; a test calls it).
func refresh() -> void:
	if not is_inside_tree():
		return
	var shown: Array[PriceWindow] = []
	if is_visible_in_tree():
		shown = labelled()
	for window: PriceWindow in _covered:
		if is_instance_valid(window) and not shown.has(window):
			window.set_label_cover(null)
	var state: Array = []
	for window: PriceWindow in shown:
		if window.tip_cover != self:
			window.set_label_cover(self)
		state.append(_state_of(window))
	_covered = shown
	_cover_sparkles(shown)
	if state != _drawn:
		_drawn = state
		queue_redraw()


## The windows whose label it draws now: shown on screen, their price on a label.
func labelled() -> Array[PriceWindow]:
	var found: Array[PriceWindow] = []
	for window: PriceWindow in _all():
		if _shows(window):
			found.append(window)
	return found


## The rect of each label it drew at the last draw (global: PriceLabel.art_rect through the
## transform it drew the label in), in `labelled` order.
func drawn_rects() -> Array[Rect2]:
	return _rects.duplicate()


## The tint `window`'s label is drawn in: the modulates from the label up to the ancestor it
## shares with this layer (an item's mix grey, a faded ticket).
func tint_of(window: PriceWindow) -> Color:
	var tint: Color = Color.WHITE
	var node: Node = window.label()
	while node != null and not node.is_ancestor_of(self):
		var item: CanvasItem = node as CanvasItem
		if item != null:
			tint *= item.modulate
		node = node.get_parent()
	return tint


func _draw() -> void:
	var to_global: Transform2D = get_global_transform()
	var to_local: Transform2D = to_global.affine_inverse()
	_rects.clear()
	for window: PriceWindow in _covered:
		if not _shows(window):
			continue
		var at: Transform2D = to_local * window.get_global_transform()
		draw_set_transform_matrix(at)
		var words: Array[PixelWords] = []
		if window.shadow().visible:
			words.append(window.shadow())
		words.append(window.digits())
		var label: PriceLabel = window.label()
		label.draw_on(self, tint_of(window), words, window.digits().modulate.a)
		_rects.append(to_global * at * Rect2(label.position, label.size))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _all() -> Array[PriceWindow]:
	var found: Array[PriceWindow] = []
	if windows.is_valid():
		found.assign(windows.call())
	return found


func _shows(window: PriceWindow) -> bool:
	return (
		is_instance_valid(window)
		and window.is_inside_tree()
		and window.label().leak() > 0
		and window.label().visible
		and window.is_visible_in_tree()
	)


## Hides each GOLDEN sparkle of the row's tickets that a label of another ticket (`shown`'s)
## lies over, and shows the ones it hid that none covers any more.
func _cover_sparkles(shown: Array[PriceWindow]) -> void:
	var under: Array[CanvasItem] = []
	if not shown.is_empty():
		for window: PriceWindow in _all():
			var sticker: PriceSticker = window.get_parent() as PriceSticker
			if sticker == null or not window.is_inside_tree():
				continue
			for sparkle: TextureRect in sticker.sparkles():
				var rect: Rect2 = sparkle.get_global_rect()
				for other: PriceWindow in shown:
					if other != window and other.label().get_global_rect().intersects(rect):
						under.append(sparkle)
						break
	for sparkle: CanvasItem in _hidden:
		if is_instance_valid(sparkle) and not under.has(sparkle):
			sparkle.self_modulate.a = 1.0
	for sparkle: CanvasItem in under:
		sparkle.self_modulate.a = 0.0
	_hidden = under


## Gives every label and sparkle back to its ticket (the layer leaves the tree).
func _release() -> void:
	for window: PriceWindow in _covered:
		if is_instance_valid(window):
			window.set_label_cover(null)
	_covered.clear()
	for sparkle: CanvasItem in _hidden:
		if is_instance_valid(sparkle):
			sparkle.self_modulate.a = 1.0
	_hidden.clear()
	_drawn.clear()


## What `window`'s label shows: everything its drawing depends on.
func _state_of(window: PriceWindow) -> Array:
	var digits: PixelWords = window.digits()
	var shadow: PixelWords = window.shadow()
	return [
		window.get_instance_id(),
		window.get_global_transform(),
		get_global_transform(),
		tint_of(window),
		window.label().leak(),
		window.size.x,
		window.label().paper(),
		digits.text,
		digits.sheet,
		digits.position,
		digits.color,
		digits.modulate.a,
		shadow.visible,
		shadow.color,
	]
