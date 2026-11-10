extends RefCounted
## The anchored receipt's dessert lines (2026-11-07, ReceiptView.anchored: the user's "no weird half
## receipt next to the receipt"): INSPECTION PASSED, the tear and the next shift's notice print on
## the paper under its foot (main scene v2: the last row the count printed), nothing on it covered
## and nothing ever prints beside it. Since H2 (v1.18 review) the count's paper reaches its room's
## top (planning's is its header alone since the 2026-11-08 feedback), so its header (the hero,
## the target, BEATEN!) never rises off the screen: lines past its room scroll the oldest rows up
## under the header, the newest line in view. Load it with
## preload("res://tests/ui/receipt_fed_lines.gd") (no class_name: tests/ is not exported).

## How far (px) a rect may stray for rounding.
const SLACK := 1.0
## The removed beside-the-receipt nodes' names (the dessert's "+1 BONUS TICKET" banner, the BONUS
## stub): none is left anywhere on the screen.
const GONE_NODES: Array[String] = ["BonusBanner", "BonusStub"]


## The lines under `receipt`'s foot (the margin's line, then the dessert's), top to bottom; none
## before the count prints its rows.
static func lines(receipt: ReceiptView) -> Array[Control]:
	var found: Array[Control] = []
	var foot: Control = foot_of(receipt)
	if foot == null:
		return found
	for index: int in range(foot.get_index() + 1, receipt._lines.get_child_count()):
		found.append(receipt._lines.get_child(index) as Control)
	return found


## The count's paper's room on `screen` (global): the stage's receipt from the overhead printer's
## slot (RECEIPT_TOP) down to RECEIPT_BOTTOM (ShiftStage, left column v2).
static func planned_rect(screen: ShiftScreen) -> Rect2:
	var stage: Rect2 = Rect2(
		ShiftStage.RECEIPT_X,
		ShiftStage.RECEIPT_TOP,
		ShiftStage.RECEIPT_WIDTH,
		ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
	)
	return screen._stage.fore.get_global_transform() * stage


## The foot: the last row the count printed (main scene v2), or null.
static func foot_of(receipt: ReceiptView) -> Control:
	var rows: Array[Control] = receipt.printed_rows()
	return rows[-1] if not rows.is_empty() else null


## What `receipt`'s fed lines get wrong, or none: each shows on the paper, under the foot and
## inside the paper's frame and the scroll area's view, one under the other; the paper is
## in `planned`, its room (its left edge, width and top, its foot no lower); nothing in the receipt
## reaches right of the paper, nothing in the screen's count-up overlay stands beside it and no
## removed beside node (GONE_NODES) is left; the header shows whole inside `screen_rect` and the
## paper.
static func failures(receipt: ReceiptView, planned: Rect2, screen_rect: Rect2) -> Array[String]:
	var found: Array[String] = []
	var paper: Rect2 = receipt.get_global_rect()
	if absf(paper.position.x - planned.position.x) > SLACK:
		found.append("paper moved sideways: %s, planned %s" % [paper, planned])
	if absf(paper.size.x - planned.size.x) > SLACK:
		found.append("paper changed width: %s, planned %s" % [paper, planned])
	# Left column v2: the paper hangs from the overhead printer's slot, down to its room's foot.
	if absf(paper.position.y - planned.position.y) > SLACK:
		found.append("paper left the printer: %s, planned %s" % [paper, planned])
	if paper.end.y > planned.end.y + SLACK:
		found.append("paper %.1f tall, its room %.1f" % [paper.size.y, planned.size.y])
	var foot: Control = foot_of(receipt)
	var above: float = foot.get_global_rect().end.y if foot != null else -INF
	var inner: Rect2 = paper.intersection(receipt._scroll.get_global_rect()).grow(SLACK)
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
	# The header (the hero, the target, BEATEN!) stays whole on the screen and the paper.
	var header: Rect2 = receipt.target.get_global_rect()
	if receipt.target.visible and not screen_rect.grow(SLACK).encloses(header):
		found.append("header left the screen: %s" % header)
	if receipt.target.visible and not paper.grow(SLACK).encloses(header):
		found.append("header off the paper: %s, paper %s" % [header, paper])
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
