class_name ReceiptPile
extends Control
## Style frame v2's paper pile (#75; round 2, delta section 8): once the receipt reaches the
## counter, its paper runs on into fan folds on the counter. The top fold continues the receipt
## itself (the same x and width, no top ink edge, a crease where it joins the receipt's foot);
## each later fold sits FOLD_SHIFT left or right of it, alternately, down to the counter line.
## Every strip has an ink cap at both ends and a crease at each fold, on the 2 px art grid, in
## PaperPile's colours and fold spacing; its height is PaperPile's (count_up.tres, through the
## fixture). Hidden (and 0 px tall) while the receipt hangs short of the counter. Nothing
## animates.

## The later folds' sideways shift from the receipt's span.
const FOLD_SHIFT := 4.0
const EDGE_PX := PaperPile.EDGE_PX
const CREASE_PX := 2.0

## The paper's height in pixels (0 while hidden).
var height_px: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows the pile joined to a receipt spanning `span_x` (x and width, in the parent's
## coordinates): its top fold starts at `top` (over the receipt's foot) and the pile stands on
## `bottom`.
func show_joined(span_x: Vector2, top: float, bottom: float) -> void:
	height_px = maxf(bottom - top, 0.0)
	position = Vector2(span_x.x - FOLD_SHIFT, top)
	size = Vector2(span_x.y + 2.0 * FOLD_SHIFT, height_px)
	visible = height_px > 0.0
	queue_redraw()


## Hides the pile (the receipt hangs short of the counter).
func hide_pile() -> void:
	height_px = 0.0
	visible = false
	queue_redraw()


## Fold `index`'s strip of paper, in the parent's coordinates (fold 0 is the receipt's span).
func fold_rect(index: int) -> Rect2:
	var top: float = index * PaperPile.FOLD_EVERY
	var height: float = minf(PaperPile.FOLD_EVERY, height_px - top)
	return Rect2(
		position + Vector2(_fold_x(index), top), Vector2(size.x - 2.0 * FOLD_SHIFT, height)
	)


## The number of folds shown.
func fold_count() -> int:
	return ceili(height_px / PaperPile.FOLD_EVERY)


## Where the paper is drawn, in global coordinates.
func paper_rect() -> Rect2:
	return get_global_rect()


func _fold_x(index: int) -> float:
	if index == 0:
		return FOLD_SHIFT
	return 0.0 if index % 2 == 1 else 2.0 * FOLD_SHIFT


func _draw() -> void:
	if height_px <= 0.0:
		return
	var width: float = size.x - 2.0 * FOLD_SHIFT
	for index: int in range(fold_count()):
		var strip: Rect2 = Rect2(fold_rect(index).position - position, fold_rect(index).size)
		draw_rect(strip, PaperPile.PAPER)
		# The crease along the fold's top: the join with the receipt's foot, or the fold above.
		draw_rect(Rect2(strip.position, Vector2(width, CREASE_PX)), PaperPile.FOLD)
		draw_rect(Rect2(strip.position, Vector2(EDGE_PX, strip.size.y)), PaperPile.EDGE)
		draw_rect(
			Rect2(strip.end.x - EDGE_PX, strip.position.y, EDGE_PX, strip.size.y), PaperPile.EDGE
		)
	# The bottom fold rests on the counter.
	var last: Rect2 = fold_rect(fold_count() - 1)
	draw_rect(Rect2(last.position.x - position.x, size.y - EDGE_PX, width, EDGE_PX), PaperPile.EDGE)
