extends RefCounted
## The anchored receipt's dessert lines (2026-11-07, ReceiptView.anchored: the user's "no weird half
## receipt next to the receipt"): INSPECTION PASSED, the tear and the next shift's notice print on
## the paper under its foot, the printer feeding that much more paper, so the paper grows at its
## foot and rises, nothing on it moving or covered, and nothing ever prints beside it. Load it
## with preload("res://tests/ui/receipt_fed_lines.gd") (no class_name: tests/ is not exported).

## How far (px) a rect may stray for rounding.
const SLACK := 1.0
## The removed beside-the-receipt nodes' names (the dessert's "+1 BONUS TICKET" banner, the BONUS
## stub): none is left anywhere on the screen.
const GONE_NODES: Array[String] = ["BonusBanner", "BonusStub"]


## The dessert's lines under `receipt`'s foot (planning's line against the quota, else its
## PROJECTED line, now the TOTAL), top to bottom; none before the dessert prints any.
static func lines(receipt: ReceiptView) -> Array[Control]:
	var found: Array[Control] = []
	var foot: Control = foot_of(receipt)
	if foot == null:
		return found
	for index: int in range(foot.get_index() + 1, receipt._lines.get_child_count()):
		found.append(receipt._lines.get_child(index) as Control)
	return found


## Planning's paper on `screen` (global): the stage's receipt from RECEIPT_TOP to the printer's
## slot (ShiftStage).
static func planned_rect(screen: ShiftScreen) -> Rect2:
	var stage: Rect2 = Rect2(
		ShiftStage.RECEIPT_X,
		ShiftStage.RECEIPT_TOP,
		ShiftStage.RECEIPT_WIDTH,
		ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
	)
	return screen._stage.fore.get_global_transform() * stage


## The foot's last line (planning's line against the quota, else its PROJECTED line), or null.
static func foot_of(receipt: ReceiptView) -> Control:
	if is_instance_valid(receipt._against):
		return receipt._against
	return receipt._projected if is_instance_valid(receipt._projected) else null


## What `receipt`'s fed lines get wrong, or none: each shows on the paper, under the foot and
## inside the paper's frame, one under the other; the paper grew by them alone (its left edge,
## width and foot are `planned`'s, planning's paper, and it is exactly their height taller); nothing
## in the receipt reaches right of the paper, nothing in the screen's count-up overlay stands beside
## it and no removed beside node (GONE_NODES) is left; the paid rows, the TOTAL and the margin
## show inside `screen_rect`.
static func failures(receipt: ReceiptView, planned: Rect2, screen_rect: Rect2) -> Array[String]:
	var found: Array[String] = []
	var paper: Rect2 = receipt.get_global_rect()
	if absf(paper.position.x - planned.position.x) > SLACK:
		found.append("paper moved sideways: %s, planned %s" % [paper, planned])
	if absf(paper.size.x - planned.size.x) > SLACK:
		found.append("paper changed width: %s, planned %s" % [paper, planned])
	if absf(paper.end.y - planned.end.y) > SLACK:
		found.append("paper left the printer: %s, planned %s" % [paper, planned])
	var scale: float = receipt.get_global_transform().get_scale().y
	var grown: float = paper.size.y - planned.size.y
	if absf(grown - receipt._fed_height() * scale) > SLACK:
		found.append("paper grew %.1f, its fed lines %.1f" % [grown, receipt._fed_height() * scale])
	var foot: Control = foot_of(receipt)
	var above: float = foot.get_global_rect().end.y if foot != null else -INF
	var inner: Rect2 = paper.grow(SLACK)
	for line: Control in lines(receipt):
		if not line.is_visible_in_tree():
			continue
		var rect: Rect2 = line.get_global_rect()
		if rect.position.y < above - SLACK:
			found.append("line %s over the one above it (%.1f)" % [rect, above])
		if not inner.encloses(rect):
			found.append("line %s off the paper %s" % [rect, paper])
		above = rect.end.y
	found.append_array(_right_of(receipt, paper))
	var screen: ShiftScreen = _screen_of(receipt)
	if screen != null:
		found.append_array(beside(screen, paper))
	var kept: Array[Control] = []
	if receipt._paid != null:
		kept.append_array(receipt._paid.rows())
	kept.append_array([receipt._projected, receipt._against])
	for kept_line: Control in kept:
		if is_instance_valid(kept_line) and not screen_rect.encloses(kept_line.get_global_rect()):
			found.append("%s left the screen: %s" % [kept_line.name, kept_line.get_global_rect()])
	return found


## Whatever `receipt` shows right of `paper` (its global rect): nothing ever prints beside it.
static func _right_of(receipt: ReceiptView, paper: Rect2) -> Array[String]:
	var found: Array[String] = []
	for node: Node in receipt.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or not control.get_global_rect().has_area():
			continue
		if control.get_global_rect().end.x > paper.end.x + SLACK:
			found.append("%s right of the paper: %s" % [control.name, control.get_global_rect()])
	return found


## Whatever `screen`'s count-up overlay shows just right of `paper` (its global rect) and level
## with it once the verdict is shown (the dessert's time: before it, the count's popups rise from
## the belt's items there), and any removed beside-the-receipt node anywhere on the screen
## (GONE_NODES).
static func beside(screen: ShiftScreen, paper: Rect2) -> Array[String]:
	var found: Array[String] = []
	var overlay: Array[Node] = []
	if screen._count_up != null and screen._count_up._verdict_shown:
		overlay = screen._overlay.find_children("*", "Control", true, false)
	for node: Node in overlay:
		var control: Control = node as Control
		var rect: Rect2 = control.get_global_rect()
		if not control.is_visible_in_tree() or not rect.has_area() or control.modulate.a <= 0.0:
			continue
		var level: bool = rect.end.y > paper.position.y and rect.position.y < paper.end.y
		# Starting in the band a slip beside the paper would take (half the paper's width): the
		# monitor's own effects (its sunburst) stand further right.
		var near: float = rect.position.x - paper.end.x
		if level and near >= -SLACK and near <= paper.size.x / 2.0:
			found.append("%s beside the paper: %s" % [control.name, rect])
	var stack: Array[Node] = [screen]
	while not stack.is_empty():
		var at: Node = stack.pop_back()
		if String(at.name) in GONE_NODES:
			found.append("removed node %s" % at.get_path())
		stack.append_array(at.get_children())
	return found


## The ShiftScreen `receipt` stands in, or null.
static func _screen_of(receipt: ReceiptView) -> ShiftScreen:
	var at: Node = receipt.get_parent()
	while at != null and not at is ShiftScreen:
		at = at.get_parent()
	return at as ShiftScreen
