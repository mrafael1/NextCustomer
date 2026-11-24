class_name GradeMoves
extends RefCounted
## The grade twists' stamps as a shift opens (v1.49 play test: "small animation when a new item is
## selected / deleted"), played once planning takes input, with the shift's notice (MachineFlow):
## a product Shrinkflation just picked gets its "-1€" sticker slapped on (it drops from STAMP_FROM
## times its size with an overshoot, then shakes), a card Expiry dates just dated gets its BEST
## BEFORE tag stamped on the same way, on every item of theirs on screen; on a run with the Picky
## regular each item on today's promo gets its red "-25%" promo tag (PromoTag) stamped on too
## (the user's play test of 2026-11-24); each card that just
## expired drops out of the Cart button as a ghost of its art, an EXPIRED stamp slaps on under
## it, the ghost holds GHOST_HOLD_SECONDS so the player sees which item it was (the user's play
## test of 2026-11-24: "could last a bit longer so you see the item better"), then it greys, tips
## and falls away (about 1.9 s in all; several ghosts stagger). Tween-based; nothing takes clicks,
## so planning is never held. What to play is GradeState's fresh changes, which a save
## never keeps: a resumed shift plays nothing. Reduced motion shows the end state at once.

const STAMP_FROM := 2.2
const STAMP_SECONDS := 0.18
const FADE_IN_SECONDS := 0.08
## The shake after the stamp lands: SHAKE_STEPS moves of SHAKE_PX, SHAKE_STEP_SECONDS each.
const SHAKE_PX := 3.0
const SHAKE_STEPS := 4
const SHAKE_STEP_SECONDS := 0.04
## The pause between two stamps, and between two expired ghosts.
const STAGGER_SECONDS := 0.08
const GHOST_STAGGER_SECONDS := 0.3
## An expired ghost: its art's scale, where it starts (under the Cart button's centre, px), the
## room between two, its pop, how long it holds with its EXPIRED stamp, then its fall (greying,
## tipping, fading).
const GHOST_SCALE := 0.75
const GHOST_DROP := Vector2(0, 24)
const GHOST_SPACING := 168.0
const GHOST_POP_SECONDS := 0.12
const GHOST_HOLD_SECONDS := 1.1
const GHOST_FALL_SECONDS := 0.45
const GHOST_FALL_PX := 48.0
const GHOST_TILT := 0.35
const GHOST_GREY := Color(0.55, 0.55, 0.55, 0.0)
## The EXPIRED stamp: the chunky pixel capitals (PixelWords CHUNKY_CAPS, 6x8) at EXPIRED_CELL px a
## font px (24 px tall), paper with an ink shadow on a tomato plate in an ink border, straight so
## it stays pixel-crisp, its top EXPIRED_RISE px over the art's foot.
const EXPIRED_TEXT := "EXPIRED"
const EXPIRED_CELL := 3.0
const EXPIRED_PAD := Vector2(8, 6)
const EXPIRED_BORDER := 2
const EXPIRED_RISE := 18.0
const STAMP_SOUND := "stamp"
const EXPIRED_SOUND := "rip"
const GHOST_NAME := "ExpiredGhost"


## Plays `run`'s fresh twist changes on the screen's items (`views`) and out of `cart` (the Cart
## button), the ghosts on `layer`; then forgets them. Returns the tweens playing (none under
## `reduced` motion or with nothing fresh).
static func play(
	layer: Control, run: RunState, views: Array[ItemView], cart: Control, reduced: bool
) -> Array[Tween]:
	var tweens: Array[Tween] = []
	if run == null or not run.twists.has_fresh():
		return tweens
	var shrunk: Array[StringName] = run.twists.fresh_shrunk.duplicate()
	var dated: Array[int] = run.twists.fresh_dated.duplicate()
	var expired: Array[CardDefinition] = run.twists.fresh_expired.duplicate()
	var promo: bool = run.twists.fresh_promo
	run.twists.clear_fresh()
	if reduced:
		return tweens
	var delay: float = 0.0
	for view: ItemView in views:
		var promo_tag: PromoTag = PromoTag.of(view)
		if promo and promo_tag != null:
			tweens.append(stamp(promo_tag, delay))
			delay += STAGGER_SECONDS
		var tags: GradeTags = view.get_node_or_null(NodePath(GradeTags.NODE_NAME)) as GradeTags
		if tags == null or view.card == null:
			continue
		var product: StringName = (
			view.card.definition.product_card().id if view.card.definition.is_product() else &""
		)
		if tags.shrink_face() != null and shrunk.has(product):
			tweens.append(stamp(tags.shrink_face(), delay))
			delay += STAGGER_SECONDS
		if tags.date_face() != null and dated.has(view.card.instance_id):
			tweens.append(stamp(tags.date_face(), delay))
			delay += STAGGER_SECONDS
	if cart != null and layer != null:
		for index: int in range(expired.size()):
			var place: Callable = _ghost_at.bind(layer, cart, index)
			var delay_s: float = index * GHOST_STAGGER_SECONDS
			tweens.append(ghost(layer, expired[index], place.call(), delay_s, place))
	return tweens


## Stamps `face` on after `delay` s (see the class comment); returns its tween.
static func stamp(face: Control, delay: float = 0.0) -> Tween:
	var rest: Vector2 = face.position
	face.pivot_offset = face.size / 2.0
	face.scale = Vector2.ONE * STAMP_FROM
	face.modulate.a = 0.0
	var tween: Tween = face.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: Sfx.play_at(face, STAMP_SOUND))
	tween.tween_property(face, "modulate:a", 1.0, FADE_IN_SECONDS)
	(
		tween
		. parallel()
		. tween_property(face, "scale", Vector2.ONE, STAMP_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	for step: int in range(SHAKE_STEPS):
		var side: float = SHAKE_PX if step % 2 == 0 else -SHAKE_PX
		var x: float = rest.x + side * (SHAKE_STEPS - step) / SHAKE_STEPS
		tween.tween_property(face, "position:x", x, SHAKE_STEP_SECONDS)
	tween.tween_property(face, "position", rest, SHAKE_STEP_SECONDS)
	return tween


## An expired `card`'s ghost on `layer` at `at` (its centre, `layer`'s px) after `delay` s: it
## pops, takes its EXPIRED stamp, then falls away and frees itself. `place`, when given, gives its
## centre again as it pops (the Cart button laid out by then). Returns its tween.
static func ghost(
	layer: Control, card: CardDefinition, at: Vector2, delay: float = 0.0, place := Callable()
) -> Tween:
	var holder: Control = Control.new()
	holder.name = GHOST_NAME
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art: TextureRect = ItemView.item_art(card)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_size: Vector2 = art.size * GHOST_SCALE
	art.scale = Vector2.ONE * GHOST_SCALE
	holder.add_child(art)
	holder.size = art_size
	holder.pivot_offset = art_size / 2.0
	holder.position = (at - art_size / 2.0).round()
	holder.scale = Vector2.ZERO
	var label: Control = expired_stamp()
	holder.add_child(label)
	label.position = Vector2(
		roundf((art_size.x - label.size.x) / 2.0), roundf(art_size.y - EXPIRED_RISE)
	)
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * STAMP_FROM
	label.modulate.a = 0.0
	ArtStyle.use_pixel_material(holder)
	layer.add_child(holder)
	var tween: Tween = holder.create_tween()
	tween.tween_interval(delay)
	if place.is_valid():
		tween.tween_callback(
			func() -> void: holder.position = ((place.call() as Vector2) - art_size / 2.0).round()
		)
	(
		tween
		. tween_property(holder, "scale", Vector2.ONE, GHOST_POP_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_callback(func() -> void: Sfx.play_at(holder, EXPIRED_SOUND))
	tween.tween_property(label, "modulate:a", 1.0, FADE_IN_SECONDS)
	(
		tween
		. parallel()
		. tween_property(label, "scale", Vector2.ONE, STAMP_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_interval(GHOST_HOLD_SECONDS)
	tween.tween_property(art, "modulate", GHOST_GREY, GHOST_FALL_SECONDS)
	tween.parallel().tween_property(label, "modulate:a", 0.0, GHOST_FALL_SECONDS)
	tween.parallel().tween_property(holder, "rotation", GHOST_TILT, GHOST_FALL_SECONDS)
	(
		tween
		. parallel()
		. tween_property(
			holder, "position:y", holder.position.y + GHOST_FALL_PX, GHOST_FALL_SECONDS
		)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_callback(holder.queue_free)
	return tween


## The EXPIRED stamp (see EXPIRED_CELL): a tomato plate sized to its words, named "Expired".
static func expired_stamp() -> Panel:
	var plate: Panel = Panel.new()
	plate.name = "Expired"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.TOMATO
	box.border_color = Palette.INK
	box.set_border_width_all(EXPIRED_BORDER)
	plate.add_theme_stylebox_override("panel", box)
	var sheet: PixelWords.Sheet = PixelWords.Sheet.CHUNKY_CAPS
	var words: PixelWords = PixelWords.new(EXPIRED_TEXT, sheet, EXPIRED_CELL, Palette.PAPER)
	words.name = "Words"
	words.shadow = Palette.INK
	words.size = PixelWords.text_size(EXPIRED_TEXT, sheet, EXPIRED_CELL)
	words.position = EXPIRED_PAD
	plate.add_child(words)
	plate.size = words.size + Vector2.ONE * EXPIRED_CELL + EXPIRED_PAD * 2.0
	return plate


## Where ghost `index` starts: under the Cart button's centre, each next one further left.
static func _ghost_at(layer: Control, cart: Control, index: int) -> Vector2:
	var to_layer: Transform2D = layer.get_global_transform().affine_inverse()
	var rect: Rect2 = cart.get_global_rect()
	var under: Vector2 = Vector2(rect.get_center().x, rect.end.y) + GHOST_DROP
	return to_layer * under + Vector2(-GHOST_SPACING * index, ItemView.SPRITE_SIZE.y * 0.5)
