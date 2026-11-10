class_name ReceiptGold
extends Node
## The receipt's silver and gold paper (2026-11-05; since left column v2, the user's pick of
## 2026-11-09, mock-up docs/art/mockups/left_column_v2.html): the gauge hides at CHECKOUT and the
## paper carries the week medals the checkout wins. When the count earns the overtime ticket's
## medal (twice the target, MachineDefinition.overtime_ticket_laps) the paper turns SILVER; when it
## earns the PREMIUM medal (three times) it turns GOLD (ReceiptGoldFlow says when). Each metal
## wipes on from the paper's top down in whole art px over WIPE_SECONDS (GoldPaperArt's `wipe`),
## then a stepped shine band crosses it once (SHINE_SECONDS) and its sparkles twinkle round it;
## gold wipes over the silver, so a total jumping past both shows two beats in one count, silver
## then gold. The material
## is the PREMIUM / PAYDAY NEXT announce's gold slip (GoldPaperArt: its face, a darker edge and
## trim, its highlight and dithered shading, a pixel star in each top corner), in Palette's steels
## for the silver, drawn on the paper's own canvas under its ink: the ink stays ink, and the lighter
## inks step darker (INKS: a short margin's tomato, a waiting amount's grey, a pass's green, a
## link's teal), so the warnings keep reading; the dashed rules turn amber (steel on silver). Under
## reduced motion (`instant`) it switches at once, with no shine and no sparkles. No stamp: the
## medal is the paper's metal alone. A payday is the paycheck design (ReceiptPayday), not a metal.
##
## While planning's projection would spend a week medal (2026-11-06) only the paper's edges glow
## faintly in that metal, a glint running round them (show_pending, GoldPaperArt.draw_glow),
## fading in and out over FADE_SECONDS. Display only.

const FADE_SECONDS := 0.3
## The metal's wipe from the top, then its one shine across.
const WIPE_SECONDS := 0.36
const SHINE_SECONDS := 0.42
## The inks that step darker on the gold paper.
const INKS: Dictionary[Color, Color] = {
	Palette.TOMATO: Palette.TOMATO_DARK,
	Palette.MUTED_INK: Palette.GREY_DARK,
	Palette.GOOD: Palette.GREEN_DARK,
	Palette.TEAL: Palette.TEAL_SHADE,
}
## A dashed rule's dashes on the gold paper, and on the silver (ReceiptDecor's rules read RULE_META:
## on a metal paper, and SILVER_RULE_META: silver, not gold; rule_ink).
const RULE_INK := Palette.MUSTARD_DARK
const SILVER_RULE_INK := Palette.STEEL_SHADE
const RULE_META := &"gold_paper"
const SILVER_RULE_META := &"silver_paper"
## The pending glow's metal (show_pending): none, silver, gold.
const PENDING_NONE := 0
const PENDING_SILVER := 1
const PENDING_GOLD := 2
## A retinted label keeps its cream ink here.
const CREAM_META := &"cream_ink"
var _paper: Control
var _target: ReceiptTarget
var _gold: bool = false
var _silver: bool = false
var _tween: Tween
var _silver_tween: Tween
## The pending glow: its metal (PENDING_*), how far it is in (0 .. 1), its tween and its clock.
var _pending: int = PENDING_NONE
var _pending_k: float = 0.0
var _pending_tween: Tween
var _glow_time: float = 0.0
## How far the gold's wipe is down the paper (0 .. 1), and the silver's under it.
var _k: float = 0.0
var _ks: float = 0.0
## Reduced motion: the metal switches at once, with no shine and no sparkles.
var _still: bool = false
## Seconds since the gold's wipe ended, and the silver's (below 0: no shine or sparkles).
var _time: float = -1.0
var _silver_time: float = -1.0
## The paper's labels and rules the retint walks (found again only when a node joins the paper).
var _inked: Array[Node] = []
var _inked_stale: bool = true


## The metal of `paper` (a ReceiptView: drawn on its canvas, its labels retint); `target` is its
## header.
func _init(paper: Control, target: ReceiptTarget = null) -> void:
	name = "Gold"
	_paper = paper
	_target = target
	_paper.draw.connect(_draw_gold)
	set_process(false)


## Turns the paper gold (`on`: wiping on from its top, then its shine and sparkles) or back to
## cream at once; `instant` (reduced motion): at once, with no shine or sparkles.
func show_gold(on: bool, instant: bool = false) -> void:
	_still = instant
	if on == _gold and (_tween == null or not _tween.is_running()):
		return
	_gold = on
	if _tween != null:
		_tween.kill()
		_tween = null
	_time = -1.0
	if not on or instant or not _paper.is_inside_tree():
		_set_amount(1.0 if on else 0.0)
	else:
		_tween = _paper.create_tween()
		_tween.tween_method(_set_amount, 0.0, 1.0, WIPE_SECONDS)
		_tween.finished.connect(func() -> void: _time = 0.0)
	_retint()
	set_process(true)


func is_gold() -> bool:
	return _gold


## Turns the paper silver (`on`) or back, as show_gold does (under the gold: gold wipes over it).
func show_silver(on: bool, instant: bool = false) -> void:
	_still = instant
	if on == _silver and (_silver_tween == null or not _silver_tween.is_running()):
		return
	_silver = on
	if _silver_tween != null:
		_silver_tween.kill()
		_silver_tween = null
	_silver_time = -1.0
	if not on or instant or not _paper.is_inside_tree():
		_set_silver(1.0 if on else 0.0)
	else:
		_silver_tween = _paper.create_tween()
		_silver_tween.tween_method(_set_silver, 0.0, 1.0, WIPE_SECONDS)
		_silver_tween.finished.connect(func() -> void: _silver_time = 0.0)
	_retint()
	set_process(true)


func is_silver() -> bool:
	return _silver


## The edges glow faintly in `metal` (PENDING_SILVER, PENDING_GOLD) while planning's projection
## would spend that medal, or go quiet (PENDING_NONE), fading unless `instant` (reduced motion: no
## glint either); the target's PROJECTED number takes the same metal (ReceiptTarget).
func show_pending(metal: int, instant: bool = false) -> void:
	_still = instant
	if _target != null:
		_target.show_pending_metal(metal)
	if metal == _pending and (_pending_tween == null or not _pending_tween.is_running()):
		return
	var was: int = _pending
	_pending = metal
	if _pending_tween != null:
		_pending_tween.kill()
		_pending_tween = null
	var target: float = 0.0 if metal == PENDING_NONE else 1.0
	if was != PENDING_NONE and metal != PENDING_NONE:
		target = 1.0  # Silver to gold: the metal switches, the glow stays.
	if instant or not _paper.is_inside_tree():
		_set_pending(target)
	else:
		_pending_tween = _paper.create_tween()
		_pending_tween.tween_method(_set_pending, _pending_k, target, FADE_SECONDS)
	set_process(true)


## The pending glow's metal (PENDING_*) and how far it is in (0 .. 1), as drawn now.
func pending() -> int:
	return _pending


func pending_amount() -> float:
	return _pending_k


## How far the silver's wipe is down the paper (0 .. 1), as drawn now (under the gold).
func silver_amount() -> float:
	return _ks


## How far the gold's wipe is down the paper (0: cream .. 1: gold), as drawn now.
func amount() -> float:
	return _k


## The wipe's front for `k` (0 .. 1) on the paper (its px, whole art px): the metal is drawn above.
func wipe_y(k: float) -> float:
	var cell: float = ArtStyle.ART_SCALE
	return roundf(_paper.size.y * clampf(k, 0.0, 1.0) / cell) * cell


## Whether the shine and the sparkles play (not under reduced motion).
func shines() -> bool:
	return _metal() and not _still


## Whether a metal's shine band crosses the paper now.
func is_shining() -> bool:
	return _shine_of(_time) >= 0.0 or _shine_of(_silver_time) >= 0.0


## The paper's face colour at its foot now (cream, silver once its wipe is down, gold once its
## is), for what paints under it (the torn tail).
func face_colour() -> Color:
	if _k >= 1.0:
		return GoldPaperArt.FACE
	if _ks >= 1.0:
		return GoldPaperArt.SILVER[0]
	return Palette.PAPER


## Shows `other`'s metal at once (a copy of its receipt).
func copy_from(other: ReceiptGold) -> void:
	show_gold(other.is_gold(), true)
	show_silver(other.is_silver(), true)
	_still = other._still


## `color` as a label on the gold paper shows it (itself unless INKS steps it darker).
static func ink_on_gold(color: Color) -> Color:
	return INKS.get(color, color)


## A dashed rule's dashes as its paper is now (RULE_META, SILVER_RULE_META): amber on gold, steel
## on silver, else `cream`.
static func rule_ink(rule: Node, cream: Color) -> Color:
	if not bool(rule.get_meta(RULE_META, false)):
		return cream
	return SILVER_RULE_INK if bool(rule.get_meta(SILVER_RULE_META, false)) else RULE_INK


func _process(delta: float) -> void:
	_retint()
	if _pending_k > 0.0 and not _still:
		_glow_time += delta
		_paper.queue_redraw()
	if (_k > 0.0 or _ks > 0.0) and not _still:
		if _time >= 0.0:
			_time += delta
		if _silver_time >= 0.0:
			_silver_time += delta
		_paper.queue_redraw()
	if not _fading() and _pending_k <= 0.0 and not _lively():
		set_process(false)


## Whether a metal's shine or sparkles still play.
func _lively() -> bool:
	if _still:
		return false
	var span: float = maxf(SHINE_SECONDS, GoldPaperArt.SPARKLE_SECONDS)
	return (_time >= 0.0 and _time < span) or (_silver_time >= 0.0 and _silver_time < span)


## The shine's progress `time` seconds after a wipe ended (below 0 when none crosses).
func _shine_of(time: float) -> float:
	if _still or time < 0.0 or time >= SHINE_SECONDS:
		return -1.0
	return time / SHINE_SECONDS


## Whether the paper is silver or gold (its inks stepped darker).
func _metal() -> bool:
	return _gold or _silver


func _fading() -> bool:
	return (
		(_tween != null and _tween.is_running())
		or (_silver_tween != null and _silver_tween.is_running())
		or (_pending_tween != null and _pending_tween.is_running())
	)


func _set_amount(k: float) -> void:
	_k = k
	_paper.queue_redraw()


func _set_silver(k: float) -> void:
	_ks = k
	_paper.queue_redraw()


func _set_pending(k: float) -> void:
	_pending_k = k
	_paper.queue_redraw()


## The silver, then the gold wiping over it, under the paper's lines (its own canvas, over its
## panel), each with its shine and sparkles once its wipe is down.
func _draw_gold() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _paper.size)
	if _ks > 0.0:
		var sparkle: float = -1.0 if _still else _silver_time
		var wipe: float = wipe_y(_ks)
		GoldPaperArt.draw(_paper, rect, 1.0, _shine_of(_silver_time), sparkle, true, wipe)
	if _k > 0.0:
		var sparkle: float = -1.0 if _still else _time
		GoldPaperArt.draw(_paper, rect, 1.0, _shine_of(_time), sparkle, false, wipe_y(_k))
	if _pending_k > 0.0:
		var run: float = -1.0
		if not _still:
			run = fmod(_glow_time, GoldPaperArt.GLOW_RUN_PERIOD) / GoldPaperArt.GLOW_RUN_PERIOD
		var silver: bool = _pending == PENDING_SILVER
		GoldPaperArt.draw_glow(_paper, rect, _pending_k, run, silver)


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)
	_inked_stale = true


func _exit_tree() -> void:
	get_tree().node_added.disconnect(_on_node_added)


## A label or a rule joined the paper: the retint finds the paper's again.
func _on_node_added(node: Node) -> void:
	if not _inked_stale and (node is Label or node is HSeparator) and _paper.is_ancestor_of(node):
		_inked_stale = true
		set_process(true)  # The next frame retints it.


## Every label's ink and every dashed rule as the paper is now: stepped darker on gold or silver,
## back to its own ink on cream (one it was given since keeps that).
func _retint() -> void:
	if _inked_stale or not _paper.is_inside_tree():
		_inked = _paper.find_children("*", "Label", true, false)
		_inked.append_array(_paper.find_children("*", "HSeparator", true, false))
		_inked_stale = not _paper.is_inside_tree()
	else:
		_inked = _inked.filter(is_instance_valid)  # A line freed since (a cleared receipt's).
	for node: Node in _inked:
		if not node is Label:
			continue
		var label: Label = node as Label
		if not label.has_theme_color_override("font_color"):
			continue
		var ink: Color = label.get_theme_color("font_color")
		if _metal() and INKS.has(ink):
			label.set_meta(CREAM_META, ink)
			label.add_theme_color_override("font_color", INKS[ink])
		elif not _metal() and label.has_meta(CREAM_META):
			var cream: Color = label.get_meta(CREAM_META) as Color
			if ink == INKS[cream]:
				label.add_theme_color_override("font_color", cream)
			label.remove_meta(CREAM_META)
	for node: Node in _inked:
		if not node is HSeparator:
			continue
		var silver: bool = _silver and not _gold
		var was: bool = bool(node.get_meta(RULE_META, false))
		if was != _metal() or bool(node.get_meta(SILVER_RULE_META, false)) != silver:
			node.set_meta(RULE_META, _metal())
			node.set_meta(SILVER_RULE_META, silver)
			(node as CanvasItem).queue_redraw()
