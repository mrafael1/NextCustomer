class_name ReceiptGold
extends Node
## The receipt's gold paper (2026-11-05): on a payday shift (the PAYDAY NEXT announce's check,
## ReceiptGoldFlow) the whole paper turns warm gold as the shift opens, and on a shift whose paid
## total reaches the overtime PREMIUM laps (MachineDefinition.overtime_premium_laps) it turns gold
## as they are reached, with a small "3× QUOTA" stamp on its TODAY'S TARGET (a payday's paper,
## gold already, only gets the stamp). Its gold is the PREMIUM / PAYDAY NEXT announce's gold slip
## (GoldPaperArt, the user's "it should feel golden like the previous text box"): the slip's gold
## face with a darker brass edge and trim, its highlight and dithered shading, a pixel star in each
## top corner, the announce's glint sweeping across every SHINE_PERIOD and a few sparkles as it
## turns gold, all drawn on the paper's own canvas, under its ink. It fades in place over
## FADE_SECONDS; under reduced motion (`instant`) it switches at once, with no glint and no
## sparkles. On the gold the ink stays dark and the lighter inks step darker (INKS: a short margin's
## tomato, a waiting amount's grey, a pass's green, a link's teal), so the warnings keep reading;
## the dashed rules turn amber. Display only: ReceiptGoldFlow says when.
##
## The SILVER paper (2026-11-05 review: "x2 bonus ticket should transform receipt to silver"): a
## shift whose paid total reaches the overtime ticket's laps
## (MachineDefinition.overtime_ticket_laps) turns silver the same way (GoldPaperArt's material in
## Palette's steels, its glint and sparkles, its "2× QUOTA" stamp in steel: show_silver,
## show_stamp's `silver`), under the gold: gold (the ×3, or a payday) wins over silver, drawn over
## it. The inks step darker on silver as on gold.
##
## The week medals (2026-11-06): the paper is silver or gold only when its checkout spends the
## medal (ReceiptGoldFlow), so a metal receipt always pays. While planning's projection would spend
## one, only its edges glow faintly in that metal, a glint running round them (show_pending,
## GoldPaperArt.draw_glow), fading in and out over FADE_SECONDS; the full metal waits for the
## checkout.

const FADE_SECONDS := 0.3
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
## The stamp: "3× QUOTA" (the laps from the data), the display font at STAMP_SIZE, brass's darkest
## on mustard pale (lighter than the gold paper) in a STAMP_BORDER px border, tilted, at the right
## of the target's number.
const STAMP_NAME := "QuotaStamp"
const STAMP_TEXT := "%d%s QUOTA"
const STAMP_SIZE := 12
const STAMP_BORDER := 2
const STAMP_PAD := Vector2(4, 1)
const STAMP_TILT_DEG := -8.0
const STAMP_INSET := 2.0
const STAMP_FACE := Palette.MUSTARD_PALE
const STAMP_INK := Palette.BRASS_DARKEST
## The silver stamp ("2× QUOTA"): light steel (darker than the silver paper), the darkest steel.
const SILVER_STAMP_FACE := Palette.STEEL_LIGHT
const SILVER_STAMP_INK := Palette.STEEL_DARKEST
## The stamp lands from STAMP_SLAM times its size over STAMP_SLAM_SECONDS (not under reduced
## motion).
const STAMP_SLAM := 1.6
const STAMP_SLAM_SECONDS := 0.2

var _paper: Control
var _target: ReceiptTarget
var _gold: bool = false
var _silver: bool = false
var _laps: int = 0
var _stamp_silver: bool = false
var _stamp: PanelContainer
var _tween: Tween
var _silver_tween: Tween
## The pending glow: its metal (PENDING_*), how far it is in (0 .. 1), its tween and its clock.
var _pending: int = PENDING_NONE
var _pending_k: float = 0.0
var _pending_tween: Tween
var _glow_time: float = 0.0
## How far the gold is in (0: cream .. 1: gold), and the silver under it.
var _k: float = 0.0
var _ks: float = 0.0
## Reduced motion: the gold switches at once, with no glint and no sparkles.
var _still: bool = false
## Seconds since the paper turned gold (the glint's clock), and the sparkles' (below 0: none).
var _time: float = 0.0
var _sparkle: float = -1.0
## The paper's labels and rules the retint walks (found again only when a node joins the paper).
var _inked: Array[Node] = []
var _inked_stale: bool = true


## The gold of `paper` (a ReceiptView: drawn on its canvas, its labels retint), its stamp on
## `target`'s number row.
func _init(paper: Control, target: ReceiptTarget = null) -> void:
	name = "Gold"
	_paper = paper
	_target = target
	_paper.draw.connect(_draw_gold)
	set_process(false)


## Turns the paper gold (`on`) or back to cream, fading in place with its sparkles unless `instant`
## (reduced motion: no glint either).
func show_gold(on: bool, instant: bool = false) -> void:
	_still = instant
	if on == _gold and (_tween == null or not _tween.is_running()):
		return
	_gold = on
	if _tween != null:
		_tween.kill()
		_tween = null
	_time = 0.0
	_sparkle = 0.0 if on and not instant else -1.0
	if instant or not _paper.is_inside_tree():
		_set_amount(1.0 if on else 0.0)
	else:
		_tween = _paper.create_tween()
		_tween.tween_method(_set_amount, _k, 1.0 if on else 0.0, FADE_SECONDS)
	_retint()
	set_process(true)


func is_gold() -> bool:
	return _gold


## Turns the paper silver (`on`) or back, as show_gold does (under the gold: gold wins).
func show_silver(on: bool, instant: bool = false) -> void:
	_still = instant
	if on == _silver and (_silver_tween == null or not _silver_tween.is_running()):
		return
	_silver = on
	if _silver_tween != null:
		_silver_tween.kill()
		_silver_tween = null
	if on and not _gold:
		_time = 0.0
		_sparkle = -1.0 if instant else 0.0
	if instant or not _paper.is_inside_tree():
		_set_silver(1.0 if on else 0.0)
	else:
		_silver_tween = _paper.create_tween()
		_silver_tween.tween_method(_set_silver, _ks, 1.0 if on else 0.0, FADE_SECONDS)
	_retint()
	set_process(true)


func is_silver() -> bool:
	return _silver


## The edges glow faintly in `metal` (PENDING_SILVER, PENDING_GOLD) while planning's projection
## would spend that medal, or go quiet (PENDING_NONE), fading unless `instant` (reduced motion: no
## glint either).
func show_pending(metal: int, instant: bool = false) -> void:
	_still = instant
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


## How far the silver is in (0 .. 1), as drawn now (under the gold).
func silver_amount() -> float:
	return _ks


## How far the gold is in (0: cream .. 1: gold), as drawn now.
func amount() -> float:
	return _k


## Whether the glint and the sparkles play (not under reduced motion).
func shines() -> bool:
	return _metal() and not _still


## The paper's face colour now (cream, silver, gold, or between while they fade), for what paints
## over it.
func face_colour() -> Color:
	if _k >= 1.0:
		return GoldPaperArt.FACE
	return Palette.PAPER.lerp(GoldPaperArt.SILVER[0], _ks).lerp(GoldPaperArt.FACE, _k)


## Stamps "N× QUOTA" (`laps`, the data's) on the target, slamming in unless `instant`, in steel
## when `silver` (the ×2's); 0 takes it off.
func show_stamp(laps: int, instant: bool = false, silver: bool = false) -> void:
	if laps == _laps and silver == _stamp_silver:
		return
	_laps = laps
	_stamp_silver = silver
	if is_instance_valid(_stamp):
		_stamp.queue_free()
	_stamp = null
	if laps <= 0 or _target == null:
		return
	_stamp = quota_stamp(laps, silver)
	var row: Control = _target.get_node("AmountRow") as Control
	row.add_child(_stamp)
	_place_stamp()
	if not row.resized.is_connected(_place_stamp):
		row.resized.connect(_place_stamp)
	if not instant and _stamp.is_inside_tree():
		_stamp.scale = Vector2.ONE * STAMP_SLAM
		var slam: Tween = _stamp.create_tween()
		slam.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slam.tween_property(_stamp, "scale", Vector2.ONE, STAMP_SLAM_SECONDS)


## The stamp shown, or null.
func stamp() -> PanelContainer:
	return _stamp if is_instance_valid(_stamp) else null


## Shows `other`'s gold and stamp at once (a copy of its receipt), glinting as it does.
func copy_from(other: ReceiptGold) -> void:
	show_gold(other.is_gold(), true)
	show_silver(other.is_silver(), true)
	show_stamp(other._laps, true, other._stamp_silver)
	_still = other._still


## The stamp alone: "N× QUOTA", tilted (`silver`: in steel).
static func quota_stamp(laps: int, silver: bool = false) -> PanelContainer:
	var ink: Color = SILVER_STAMP_INK if silver else STAMP_INK
	var made: PanelContainer = PanelContainer.new()
	made.name = STAMP_NAME
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = SILVER_STAMP_FACE if silver else STAMP_FACE
	style.border_color = ink
	style.set_border_width_all(STAMP_BORDER)
	style.content_margin_left = STAMP_PAD.x
	style.content_margin_right = STAMP_PAD.x
	style.content_margin_top = STAMP_PAD.y
	style.content_margin_bottom = STAMP_PAD.y
	made.add_theme_stylebox_override("panel", style)
	var words: Label = UiKit.display_label(
		STAMP_TEXT % [laps, OvertimeWords.TIMES], STAMP_SIZE, false
	)
	words.add_theme_color_override("font_color", ink)
	made.add_child(words)
	made.size = made.get_combined_minimum_size()
	return made


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
		_time += delta
		if _sparkle >= 0.0:
			_sparkle += delta
		_paper.queue_redraw()
	elif not _metal() and not _fading() and _pending_k <= 0.0:
		set_process(false)


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


## The silver, then the gold over it, under the paper's lines (its own canvas, over its panel); the
## glint and the sparkles on the top metal only.
func _draw_gold() -> void:
	var shine: float = -1.0 if _still else GoldPaperArt.shine_at(_time)
	var sparkle: float = -1.0 if _still else _sparkle
	var rect: Rect2 = Rect2(Vector2.ZERO, _paper.size)
	if _k > 0.0:
		GoldPaperArt.draw(_paper, rect, _ks, -1.0, -1.0, true)
		GoldPaperArt.draw(_paper, rect, _k, shine, sparkle)
	else:
		GoldPaperArt.draw(_paper, rect, _ks, shine, sparkle, true)
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


## The stamp at the right of the target's number row, its middle on the row's.
func _place_stamp() -> void:
	if not is_instance_valid(_stamp):
		return
	var row: Control = _stamp.get_parent() as Control
	_stamp.size = _stamp.get_combined_minimum_size()
	_stamp.position = Vector2(
		row.size.x - _stamp.size.x - STAMP_INSET, roundf((row.size.y - _stamp.size.y) / 2.0)
	)
	ReceiptStamps.tilt(_stamp, STAMP_TILT_DEG, true)
