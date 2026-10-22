class_name UpgradeSwap
extends Control
## An upgraded item swapping in place (#77 machine v2, the approved page's renderUpgrade): the
## shift after an UPGRADES pick, once the camera is back in the store, every upgraded copy that
## has an item on screen (in the hand's baskets or on the belt) shows its old art until its turn,
## then swaps to its new tier's art with a white flash masked to its sprite, a gold sunburst behind
## it, a pop, and a gold tag above it ("BANANA › GOLDEN") that rises in, holds and fades. Copies
## not on screen are skipped (the monitor's brief still says "Banana is GOLDEN now": news_line).
## Several copies start PlanningTuning.swap_stagger_ms apart. Reduced motion: no flash, sunburst
## or pop; the tag shows at once. Every time is PlanningTuning's "Upgrade swap" group
## (data/balance/planning.tres).
##
## It lives on the shift screen's overlay (screen coordinates, unzoomed); the flash and the
## sunburst ride on the item's own view (the flash on its sprite, so it follows the pop; the
## sunburst behind the sprite). Its clock is its own (`time`, seconds; show_at for tests); it
## frees itself after the last tag has faded (`finished`). Display only: the pairs are
## MachineLanding.upgraded's [old, new] CardInstances, the names and tiers their definitions'.

signal finished

const TUNING_PATH := "res://data/balance/planning.tres"
const FLASH_SHADER := preload("res://presentation/flash_mask.gdshader")
const FLASH_NAME := "SwapFlash"
const SHINE_NAME := "SwapShine"
## The sunburst: SHINE_RAYS rays and as many gaps, gold rays over clear gaps.
const SHINE_RAYS := 18
const SHINE_COLOUR := Color(Palette.GOLD, 0.7)
## The tag: Pixelify TAG_SIZE in ink on gold, a 2 px ink border, TAG_PAD inside, TAG_GAP above the
## sprite, kept MARGIN inside the viewport.
const TAG_SIZE := 12
const TAG_PAD := Vector2(8, 2)
const TAG_GAP := 6.0
const MARGIN := 4.0
const SOUND := "ding"

var tuning: PlanningTuning
var reduced_motion: bool = false
## Seconds since play().
var time: float = 0.0
## Each copy shown: {view, old, new, start, tag, flash, shine}.
var _plays: Array[Dictionary] = []
var _sfx: Sfx
var _done: bool = false


func _init() -> void:
	name = "UpgradeSwap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	tuning = load(TUNING_PATH) as PlanningTuning


## The swap's tag line for an upgraded copy's `definition`: "BANANA › GOLDEN".
static func tier_line(definition: CardDefinition) -> String:
	var item: String = definition.product_card().display_name.to_upper()
	return "%s › %s" % [item, CardDefinition.Tier.keys()[definition.tier]]


## The monitor brief's line for an upgraded copy's `definition`: "Banana is GOLDEN now".
static func news_line(definition: CardDefinition) -> String:
	var item: String = definition.product_card().display_name
	return "%s is %s now" % [item, CardDefinition.Tier.keys()[definition.tier]]


## `pairs` (MachineLanding.upgraded's [old, new] CardInstances, several landings in a row) with one
## pair per copy: a copy upgraded twice (PLAIN › BIG, then BIG › GOLDEN) keeps its first old and
## its last new, at its first pair's place.
static func collapse(pairs: Array) -> Array:
	var result: Array = []
	var at: Dictionary[int, int] = {}
	for pair: Array in pairs:
		var copy: CardInstance = pair[1] as CardInstance
		if at.has(copy.instance_id):
			var index: int = at[copy.instance_id]
			var kept: Array = result[index]
			result[index] = [kept[0], copy]
		else:
			at[copy.instance_id] = result.size()
			result.append([pair[0], copy])
	return result


## The [view, old definition, new definition] of every pair in `pairs` (MachineLanding.upgraded's
## [old, new] CardInstances) whose new copy has an item among `views`, in `pairs`' order.
static func matching(pairs: Array, views: Array[ItemView]) -> Array[Array]:
	var found: Array[Array] = []
	for pair: Array in pairs:
		var old: CardInstance = pair[0] as CardInstance
		var copy: CardInstance = pair[1] as CardInstance
		for item: ItemView in views:
			if is_instance_valid(item) and item.card.instance_id == copy.instance_id:
				found.append([item, old.definition, copy.definition])
				break
	return found


## Shows the old art on the items of `pairs`' new copies among `views` until they swap (the glide
## back to the store plays meanwhile).
static func hold_old(pairs: Array, views: Array[ItemView]) -> void:
	for shown: Array in matching(pairs, views):
		var item: ItemView = shown[0] as ItemView
		item.sprite().texture = ArtStyle.item_sprite(shown[1] as CardDefinition)


## Plays the swap of every pair whose new copy is among `views` (see the class comment); returns
## how many play. With none, it finishes at once.
func play(pairs: Array, views: Array[ItemView], reduced: bool, sfx: Sfx = null) -> int:
	reduced_motion = reduced
	_sfx = sfx
	time = 0.0
	var index: int = 0
	for shown: Array in matching(pairs, views):
		var start: float = index * _sec(tuning.swap_stagger_ms)
		(
			_plays
			. append(
				{
					"view": shown[0],
					"old": shown[1],
					"new": shown[2],
					"start": start,
					"begun": false,
					"tag": _make_tag(tier_line(shown[2] as CardDefinition)),
				}
			)
		)
		index += 1
	show_at(0.0)
	return _plays.size()


## How many copies play.
func count() -> int:
	return _plays.size()


## Copy `index`'s tag, flash (null before its start or under reduced motion) and sunburst.
func tag(index: int) -> Label:
	return _plays[index]["tag"] as Label


func flash(index: int) -> TextureRect:
	return _plays[index].get("flash") as TextureRect


func shine(index: int) -> Sunburst:
	return _plays[index].get("shine") as Sunburst


func view(index: int) -> ItemView:
	return _plays[index]["view"] as ItemView


## The whole swap's length (s): the last copy's tag gone.
func length() -> float:
	var last: float = 0.0
	for shown: Dictionary in _plays:
		last = maxf(last, float(shown["start"]))
	return last + _tag_end()


## Renders every copy at `t` seconds (tests, and each frame); past length() it finishes.
func show_at(t: float) -> void:
	time = t
	for shown: Dictionary in _plays:
		_frame(shown, t - float(shown["start"]))
	if t >= length() and not _done:
		_finish()


func _process(delta: float) -> void:
	if _done:
		return
	show_at(time + delta)


## One copy `local` seconds into its own swap.
func _frame(shown: Dictionary, local: float) -> void:
	var item: ItemView = shown["view"] as ItemView
	var label: Label = shown["tag"] as Label
	if not is_instance_valid(item):
		label.visible = false
		return
	if local < 0.0:
		label.visible = false
		return
	if not bool(shown["begun"]):
		_begin(shown, item)
	var sprite: TextureRect = item.sprite()
	var pop: float = 1.0
	if not reduced_motion:
		var pop_p: float = _seg(local, 0.0, _sec(tuning.swap_pop_ms))
		pop = 1.0 + (tuning.swap_pop_scale - 1.0) * sin(pop_p * PI)
	sprite.pivot_offset = Vector2(sprite.size.x / 2.0, sprite.size.y)
	sprite.scale = Vector2.ONE * pop
	var flash_rect: TextureRect = shown.get("flash") as TextureRect
	if flash_rect != null:
		var fade: float = 1.0 - _seg(local, 0.0, _sec(tuning.swap_flash_ms))
		flash_rect.modulate.a = tuning.swap_flash_alpha * fade
		flash_rect.visible = fade > 0.0
	var burst: Sunburst = shown.get("shine") as Sunburst
	if burst != null:
		var p: float = _seg(local, 0.0, _sec(tuning.swap_shine_ms))
		var grow: float = _ease_out(_seg(local, 0.0, _sec(tuning.swap_shine_grow_ms)))
		burst.visible = p < 1.0
		burst.modulate.a = sin(clampf(p * 1.3, 0.0, 1.0) * PI) * tuning.swap_shine_alpha
		burst.scale = Vector2.ONE * lerpf(tuning.swap_shine_from, tuning.swap_shine_to, grow)
		burst.rotation = deg_to_rad(tuning.swap_shine_turn_deg_s * local)
	_place_tag(label, sprite, local)


## The copy's turn: its new art, the flash on its sprite and the sunburst behind it, its sound.
func _begin(shown: Dictionary, item: ItemView) -> void:
	shown["begun"] = true
	var sprite: TextureRect = item.sprite()
	sprite.texture = ArtStyle.item_sprite(shown["new"] as CardDefinition)
	if _sfx != null:
		_sfx.play(SOUND)
	if reduced_motion:
		return
	var flash_rect: TextureRect = UiKit.sprite(sprite.texture)
	flash_rect.name = FLASH_NAME
	flash_rect.size = sprite.size
	var mask: ShaderMaterial = ShaderMaterial.new()
	mask.shader = FLASH_SHADER
	flash_rect.material = mask
	sprite.add_child(flash_rect)
	shown["flash"] = flash_rect
	var side: float = tuning.swap_shine_px
	var burst: Sunburst = Sunburst.new(Vector2(side, side), Vector2(side, side) / 2.0)
	burst.name = SHINE_NAME
	burst.reduced_motion = func() -> bool: return true  # It turns here, not by itself.
	var shader: ShaderMaterial = burst.material as ShaderMaterial
	shader.set_shader_parameter(&"ray_colour", SHINE_COLOUR)
	shader.set_shader_parameter(&"gap_colour", Color(SHINE_COLOUR, 0.0))
	shader.set_shader_parameter(&"radius", side / 2.0)
	shader.set_shader_parameter(&"squash", 1.0)
	shader.set_shader_parameter(&"rays", float(SHINE_RAYS))
	burst.pivot_offset = Vector2(side, side) / 2.0
	var centre: Vector2 = (
		item.get_global_transform().affine_inverse() * (sprite.get_global_rect().get_center())
	)
	burst.position = centre - burst.pivot_offset
	item.add_child(burst)
	item.move_child(burst, 0)
	shown["shine"] = burst


## The tag above the sprite, centred on it and kept inside the viewport: fading in from
## swap_tag_delay_ms over swap_tag_in_ms and rising swap_tag_rise_px over swap_tag_rise_ms (at
## once under reduced motion), held, then fading out.
func _place_tag(label: Label, sprite: TextureRect, local: float) -> void:
	var alpha: float = 1.0
	var rise: float = 0.0
	var delay: float = _sec(tuning.swap_tag_delay_ms)
	if not reduced_motion:
		alpha = _seg(local, delay, delay + _sec(tuning.swap_tag_in_ms))
		var up: float = _ease_out(_seg(local, delay, delay + _sec(tuning.swap_tag_rise_ms)))
		rise = tuning.swap_tag_rise_px * (1.0 - up)
	var out_at: float = _tag_end() - _sec(tuning.swap_tag_out_ms)
	alpha *= 1.0 - _seg(local, out_at, _tag_end())
	label.visible = alpha > 0.0
	label.modulate.a = alpha
	label.size = label.get_combined_minimum_size()
	var art: Rect2 = get_global_transform().affine_inverse() * sprite.get_global_rect()
	var x: float = art.get_center().x - label.size.x / 2.0
	var view_size: Vector2 = get_viewport_rect().size if is_inside_tree() else size
	x = clampf(x, MARGIN, maxf(MARGIN, view_size.x - MARGIN - label.size.x))
	var y: float = maxf(MARGIN, art.position.y - TAG_GAP - label.size.y + rise)
	label.position = Vector2(roundf(x), roundf(y))


## When a copy's tag has faded out, from its start (s).
func _tag_end() -> float:
	var shown_from: float = 0.0 if reduced_motion else _sec(tuning.swap_tag_delay_ms)
	if not reduced_motion:
		shown_from += _sec(tuning.swap_tag_in_ms)
	return shown_from + _sec(tuning.swap_tag_hold_ms) + _sec(tuning.swap_tag_out_ms)


func _make_tag(text: String) -> Label:
	var label: Label = UiKit.display_label(text, TAG_SIZE, false)
	label.name = "SwapTag"
	label.add_theme_color_override("font_color", Palette.INK)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.GOLD
	style.border_color = Palette.INK
	style.set_border_width_all(2)
	style.content_margin_left = TAG_PAD.x
	style.content_margin_right = TAG_PAD.x
	style.content_margin_top = TAG_PAD.y
	style.content_margin_bottom = TAG_PAD.y
	label.add_theme_stylebox_override("normal", style)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	add_child(label)
	return label


## Takes the flashes and sunbursts off the items, puts their sprites back at rest and frees.
func _finish() -> void:
	_done = true
	for shown: Dictionary in _plays:
		var item: ItemView = shown["view"] as ItemView
		if not is_instance_valid(item):
			continue
		item.sprite().scale = Vector2.ONE
		for key: String in ["flash", "shine"]:
			var part: Node = shown.get(key) as Node
			if is_instance_valid(part):
				part.get_parent().remove_child(part)
				part.queue_free()
	finished.emit()
	if is_inside_tree():
		queue_free()


static func _sec(ms: int) -> float:
	return ms / 1000.0


static func _seg(t: float, from: float, to: float) -> float:
	if to <= from:
		return 1.0 if t >= from else 0.0
	return clampf((t - from) / (to - from), 0.0, 1.0)


static func _ease_out(p: float) -> float:
	return 1.0 - (1.0 - p) * (1.0 - p)
