class_name ScanFooter
extends Control
## A scan's step lines (#75; the monitor's since #80, the scan popup's footer went in step 12): each
## line as the caller words it (ReceiptView.step_line), a fizzle's in dark tomato after the fizzle
## icon, its amount (or "WASTED", after ReceiptView.joined_line's two spaces) right-aligned on the
## line's last row, the text wrapped clear of it, as on the receipt. Lines that don't fit the height
## fill() is given fold into a last "+N more" line. The first `gives_lines` lines are a belt item's
## "gives" lines (#71): their amount in mustard darkest. Display only: the lines are the caller's.

## The last line when the rest don't fit: how many were folded.
const MORE_TEXT := "+%d more"
## What separates a line's text from its amount (ReceiptView.joined_line).
const AMOUNT_SEPARATOR := "  "
## The room between a line's text and its amount, on each side.
const AMOUNT_GAP := 4.0
const ICON_SIZE := Vector2(14, 14)
## The fizzle icon's drop from the line's top, and the gap after it.
const ICON_DROP := 2.0
const ICON_GAP := 4.0

const FIZZLE_ICON := preload("res://art/icons/fizzle.png")

## How many of the first lines are "gives" lines (their amount in mustard darkest).
var gives_lines: int = 0
var _width: float = 0.0
var _font_size: int = 12
## Each line shown, as the caller gave it (its amount included), then "+N more" when some were
## folded.
var _texts: PackedStringArray = PackedStringArray()


## A footer `width` wide whose text is body text at `font_size`.
func _init(width: float, font_size: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_width = width
	_font_size = font_size
	size = Vector2(width, 0.0)


## Lays out `lines` (each with whether it is a fizzle, `fizzles`) from the footer's top: each one
## that ends within `max_height`, keeping room for a "+N more" row while more are to come; that
## line folds the first one that doesn't fit and the rest. Call it once the footer is in the
## tree: the text is measured with the real font. Takes the lines' height and returns whether
## every line shows (none folded).
func fill(lines: PackedStringArray, fizzles: Array[bool], max_height: float) -> bool:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_texts.clear()
	var top: float = 0.0
	var more_height: float = _row_height()
	for index: int in range(lines.size()):
		var kept: int = get_child_count()
		var next: float = _add_line(lines[index], fizzles[index], top, index < gives_lines)
		var reserve: float = more_height if index < lines.size() - 1 else 0.0
		if next + reserve <= max_height:
			top = next
			continue
		# It doesn't fit: take it out again and fold it with the rest.
		for child: Node in get_children().slice(kept):
			remove_child(child)
			child.queue_free()
		_texts.remove_at(_texts.size() - 1)
		var more: Label = UiKit.body_label(
			MORE_TEXT % (lines.size() - index), _font_size, Palette.INK
		)
		_texts.append(more.text)
		size.y = _add_label(more, top)
		return false
	size.y = top
	return true


## The lines shown ("+N more" last when some were folded).
func texts() -> PackedStringArray:
	return _texts.duplicate()


## Adds one line from `top`: a fizzle's icon, then its text, wrapped clear of its amount, which
## sits right-aligned on the text's last row (in mustard darkest on a `gives` line). Returns the
## next line's top.
func _add_line(text: String, fizzle: bool, top: float, gives: bool = false) -> float:
	var colour: Color = Palette.TOMATO_DARK if fizzle else Palette.INK
	var at: int = text.rfind(AMOUNT_SEPARATOR)
	var left: String = text if at < 0 else text.left(at)
	var label: Label = UiKit.body_label(left, _font_size, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texts.append(text)
	var indent: float = 0.0
	if fizzle:
		var icon: TextureRect = UiKit.sprite(FIZZLE_ICON)
		icon.position = Vector2(0.0, top + ICON_DROP)
		icon.size = ICON_SIZE
		add_child(icon)
		indent = ICON_SIZE.x + ICON_GAP
	var amount: Label = null
	var amount_width: float = 0.0
	if at >= 0:
		amount = UiKit.body_label(
			text.substr(at + AMOUNT_SEPARATOR.length()),
			_font_size,
			Palette.MUSTARD_DARKEST if gives else colour
		)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(amount)
		amount_width = amount.get_minimum_size().x + AMOUNT_GAP * 2.0
	# In the tree first: out of it a label measures with the default font size.
	add_child(label)
	label.position = Vector2(indent, top)
	label.size = Vector2(_width - indent - amount_width, 1.0)
	label.size.y = label.get_minimum_size().y
	if amount != null:
		var row: float = amount.get_minimum_size().y
		amount.position = Vector2(0.0, top + label.size.y - row)
		amount.size = Vector2(_width, row)
	return top + label.size.y


## Adds `label` at `top` across the footer, at its measured height. Returns the next line's top.
func _add_label(label: Label, top: float) -> float:
	add_child(label)
	label.position = Vector2(0.0, top)
	label.size = Vector2(_width, 1.0)
	label.size.y = label.get_minimum_size().y
	return top + label.size.y


## One row of the footer's text, measured with the real font.
func _row_height() -> float:
	var probe: Label = UiKit.body_label("+0", _font_size, Palette.INK)
	add_child(probe)
	var height: float = probe.get_minimum_size().y
	remove_child(probe)
	probe.free()
	return height
