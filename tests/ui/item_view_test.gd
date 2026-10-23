extends GdUnitTestSuite
## The item view (#75, step 3): every card in data/cards laid out as a belt item, a basket item
## (#80, step 8: sunk a third under the rim, outlined when selected, flagged when redraw-marked) and
## a tray item, placed where the shift screen puts them, with the real fonts. The paid chip never
## runs under the art (at rest, selected or scanned, either face) nor, settled, over the corner
## mark; the sticker covers neither the sprite nor the mark; center() is on the sprite; the paid
## chip has its two faces, mutes at €0 and pops with an echo; the looks (selected, redraw) show; one
## mark per item sits on the art's corner (#80, step 7); every sprite's opaque pixels keep clear of
## its sticker (#57); and every undrawn item's name fits its art-pending box or its slip.

const CARDS := "res://data/cards"
const BALANCE := "res://data/balance/balance.tres"
const SCREEN := Rect2(0, 0, 1280, 720)
## Where the first belt cell and the first tray cell stand on the stage (style frame v2).
const BELT_ORIGIN := Vector2(32, 76)
const TRAY_ORIGIN := Vector2(20, 418)
## The art-pending box's dashed line (canvas, sprite coordinates) and the slip's paper.
const PENDING_BOX := Rect2(10, 20, 76, 76)
const SLIP_PAPER := Rect2(26, 30, 60, 48)
const DRAWN_MILK := "res://art/items_v2/milk.png"
const COUPON_ICON := "res://art/icons/coupon_multipack_v2.png"
## The live data's tests, for the products a new profile stocks (#57).
const LIVE_CARDS := preload("res://tests/data/live_cards_test.gd")
## The longest names (#75, decision 3A), each checked as if undrawn (Flickering bulb is drawn
## since #57).
const LONG_NAMES: Array[String] = [
	"Birthday candles", "Flickering bulb", "Breakfast sticker", "Final markdown"
]

var _holder: Control


func before_test() -> void:
	_holder = auto_free(Control.new())
	_holder.size = SCREEN.size
	add_child(_holder)


## Every belt item: the sprite stands inside its cell above the sticker; the mark sits inside the
## cell on the art's visible top-right corner, clear of the sticker; the paid chip, current or
## settled, stays in the cell's column, over the art's visible top and under the cell's top less
## PAID_SETTLED_MIN_Y, never running under the art (at rest or with both scan-lifted, a four-digit
## payout too; planning, where items are selected, shows no paid chip), and a settled one or a
## current one of up to two digits never covers the mark. All of it stays on screen.
func test_belt_items_keep_sprite_paid_chip_sticker_and_mark_apart() -> void:
	var views: Array[ItemView] = await _all_laid_out(ItemView.Form.BELT, BELT_ORIGIN)
	for view: ItemView in views:
		var message: String = view.card.definition.id
		var mark: EffectMark = view.show_mark(true)
		var cell: Rect2 = view.get_global_rect()
		assert_vector(cell.size).is_equal(ItemView.BELT_SIZE)
		var sticker: Rect2 = view.sticker().get_global_rect()
		assert_bool(cell.encloses(sticker)).override_failure_message(message).is_true()
		var mark_rect: Rect2 = mark.get_global_rect()
		assert_bool(cell.encloses(mark_rect)).override_failure_message(message).is_true()
		assert_bool(mark_rect.intersects(sticker)).override_failure_message(message).is_false()
		assert_bool(SCREEN.encloses(mark_rect)).override_failure_message(message).is_true()
		assert_vector(mark.position).is_equal(
			EffectMark.corner(
				view.sprite().texture, Rect2(view._stand.position, ItemView.SPRITE_SIZE)
			)
		)
		for current: bool in [true, false]:
			view.set_badge_current(current)
			for value: int in [0, 7, 999, 9999]:
				var label: String = "%s, %s €%d" % [message, current, value]
				view.show_badge(value, false)
				_assert_sprite_clear(view, label)
				if value < 100:
					var face: Rect2 = _face_with_shadow(view)
					(
						assert_bool(face.intersects(mark_rect))
						. override_failure_message(label)
						. is_false()
					)
				view.body.position.y = view.scan_lift()
				view.badge.position.y = view.badge_rest_y() + view.scan_lift()
				_assert_sprite_clear(view, label)
				view.reset_motion()


## Every tray item: the sprite and sticker inside the cell, apart, lifted or not; the selected
## look's brackets stay clear of the sticker.
func test_tray_items_keep_the_sticker_off_the_sprite() -> void:
	var views: Array[ItemView] = await _all_laid_out(ItemView.Form.TRAY, TRAY_ORIGIN)
	for view: ItemView in views:
		var message: String = view.card.definition.id
		var cell: Rect2 = view.get_global_rect()
		assert_vector(cell.size).is_equal(ItemView.TRAY_SIZE)
		var sticker: Rect2 = view.sticker().get_global_rect()
		assert_bool(cell.encloses(sticker)).override_failure_message(message).is_true()
		assert_bool(SCREEN.encloses(sticker)).override_failure_message(message).is_true()
		for highlight: CardView.Highlight in [CardView.Highlight.NONE, CardView.Highlight.SELECTED]:
			view.set_highlight(highlight)
			var sprite: Rect2 = view.body.get_global_rect()
			assert_bool(cell.encloses(sprite)).override_failure_message(message).is_true()
			assert_bool(sprite.intersects(sticker)).override_failure_message(message).is_false()
			if highlight == CardView.Highlight.SELECTED:
				var brackets: Rect2 = Rect2(
					view.global_position + view.brackets().position, view.brackets().size
				)
				(
					assert_bool(brackets.intersects(sticker))
					. override_failure_message(message)
					. is_false()
				)
				assert_bool(SCREEN.encloses(brackets)).is_true()


## The ticket stays clear of the art for every card (#57, the user's answer). The sticker sits
## below the sprite box, so no drawing can reach it whatever its pixels; this pins that layout
## per card: each card's opaque art box (at 2x where the view draws it) misses its sticker and
## stays inside its cell and the screen, on the belt and in the tray, at rest and lifted, and
## the 20 products a new profile stocks show their own sprite. The pixels only matter here if
## the sticker ever moves under the sprite box.
func test_no_sprite_reaches_its_price_sticker() -> void:
	var stocked: Array[CardDefinition] = LIVE_CARDS.stocked_products()
	var origins: Dictionary[ItemView.Form, Vector2] = {
		ItemView.Form.BELT: BELT_ORIGIN, ItemView.Form.TRAY: TRAY_ORIGIN
	}
	for form: ItemView.Form in origins:
		var checked: int = 0
		for view: ItemView in await _all_laid_out(form, origins[form]):
			var definition: CardDefinition = view.card.definition
			if stocked.has(definition):
				checked += 1
				assert_object(view.sprite().texture).is_not_same(ArtStyle.ITEM_PENDING)
			for lifted: bool in [false, true]:
				view.lifted = lifted
				var message: String = "%s, form %d, lifted %s" % [definition.id, form, lifted]
				var art: Rect2 = _art_rect(view)
				var sticker: Rect2 = view.sticker().get_global_rect()
				assert_bool(art.intersects(sticker)).override_failure_message(message).is_false()
				var cell: Rect2 = view.get_global_rect()
				assert_bool(cell.encloses(art)).override_failure_message(message).is_true()
				assert_bool(SCREEN.encloses(art)).override_failure_message(message).is_true()
			view.lifted = false
		assert_int(checked).is_equal(stocked.size())


## center() is the sprite's middle at rest, in both forms and in a scaled row (RowStrip's 8 and
## 9 slots), not the cell's: the count-up's flights land on the sprite.
func test_center_is_on_the_sprite() -> void:
	var milk: CardDefinition = load("%s/milk.tres" % CARDS)
	for form: ItemView.Form in [ItemView.Form.BELT, ItemView.Form.TRAY]:
		var view: ItemView = await _laid_out(milk, form, BELT_ORIGIN)
		var sprite: Rect2 = view.body.get_global_rect()
		assert_vector(view.center()).is_equal_approx(sprite.get_center(), Vector2(0.01, 0.01))
		assert_bool(sprite.has_point(view.center())).is_true()
		assert_bool(view.sticker().get_global_rect().has_point(view.center())).is_false()
		view.body.position.y = view.scan_lift()
		assert_vector(view.center()).is_equal_approx(sprite.get_center(), Vector2(0.01, 0.01))
	_holder.scale = Vector2(0.8, 0.8)
	var scaled: ItemView = await _laid_out(milk, ItemView.Form.BELT, BELT_ORIGIN)
	var drawn: Rect2 = scaled.sprite().get_global_rect()
	assert_vector(scaled.center()).is_equal_approx(drawn.get_center(), Vector2(0.01, 0.01))


## An item's scan lift is LIFT; a plain card keeps its own (CardView.SCAN_LIFT). Lifted by it,
## reset_motion puts the sprite and plaque back at rest.
func test_an_item_lifts_by_its_own_height_and_resets_to_rest() -> void:
	var milk: CardDefinition = load("%s/milk.tres" % CARDS)
	var view: ItemView = await _laid_out(milk, ItemView.Form.BELT, BELT_ORIGIN)
	assert_float(view.scan_lift()).is_equal(-ItemView.LIFT)
	var card: CardView = auto_free(CardView.new(CardInstance.new(milk, 1)))
	assert_float(card.scan_lift()).is_equal(CardView.SCAN_LIFT)
	view.show_badge(3, true)
	view.body.position.y = view.scan_lift()
	view.badge.position.y = view.badge_rest_y() + view.scan_lift()
	view.reset_motion()
	assert_float(view.body.position.y).is_equal_approx(0.0, 0.01)
	assert_float(view.badge.position.y).is_equal_approx(view.badge_rest_y(), 0.01)


## A chip that pops again while its last echo still fades keeps the new echo for a whole
## ECHO_TIME: the old fade is killed and cannot hide it early.
func test_a_new_pop_keeps_its_echo() -> void:
	var view: ItemView = await _laid_out(
		load("%s/milk.tres" % CARDS), ItemView.Form.BELT, BELT_ORIGIN
	)
	var plaque: PayoutPlaque = view.badge as PayoutPlaque
	view.set_badge_current(true, true)
	view.show_badge(3, false)
	assert_bool(plaque.echo_frame().visible).is_true()
	var wait_ms: int = int(PayoutPlaque.ECHO_TIME * 1000.0 * 0.6)
	await await_millis(wait_ms)
	view.set_badge_current(false)
	view.set_badge_current(true, true)
	view.show_badge(3, false)
	await await_millis(wait_ms)
	assert_bool(plaque.echo_frame().visible).is_true()


## The count-up's gold brackets (ScanOverlay.scan_frame, mock-up B2) on every belt item: the
## lifted sprite's sides and foot, the top brought down to SCAN_ART_GAP over the art's visible top
## and never above the sprite's own brackets. A current chip over a low item (not held by
## PAID_CURRENT_MIN_Y) pops above them, its echo frame 8 px clear of the top arms (B2), so the chip
## and its shadow stay off the arms (a tall item's, held under the monitor, shares their rows).
func test_the_count_up_brackets_hug_the_art_under_the_current_chip() -> void:
	var lows: int = 0
	for view: ItemView in await _all_laid_out(ItemView.Form.BELT, BELT_ORIGIN):
		var message: String = view.card.definition.id
		var sprite: Rect2 = ScanOverlay.lifted_sprite(view)
		var frame: Rect2 = ScanOverlay.scan_frame(view)
		assert_float(frame.position.x).is_equal(sprite.position.x)
		assert_float(frame.size.x).is_equal(sprite.size.x)
		assert_float(frame.end.y).is_equal(sprite.end.y)
		assert_float(frame.position.y).override_failure_message(message).is_greater_equal(
			sprite.position.y
		)
		var art: float = view.global_position.y + view._art_top() + view.scan_lift()
		var brackets: Rect2 = frame.grow(ScanOverlay.BRACKET_OUTSET)
		if frame.position.y > sprite.position.y:
			assert_float(brackets.position.y).is_equal_approx(art - ScanOverlay.SCAN_ART_GAP, 0.01)
		view.set_badge_current(true)
		view.show_badge(3, false)
		var plaque: PayoutPlaque = view.badge as PayoutPlaque
		var lifted_y: float = view.global_position.y + view.badge_rest_y() + view.scan_lift()
		var face: Rect2 = Rect2(
			Vector2(view.global_position.x + plaque.position.x, lifted_y),
			plaque.size + Vector2.ONE * plaque.shadow()
		)
		var outside: float = PayoutPlaque.ECHO_GAP + PayoutPlaque.ECHO_WIDTH
		var echo_foot: float = face.end.y + outside
		if view._art_top() - ItemView.PAID_CURRENT_ABOVE < ItemView.PAID_CURRENT_MIN_Y:
			continue
		assert_float(echo_foot + 8.0).override_failure_message(message).is_less_equal(
			brackets.position.y + 0.01
		)
		for arm: Rect2 in _top_arms(brackets):
			var clash: String = "%s: chip %s over the arm %s" % [message, face, arm]
			assert_bool(face.intersects(arm)).override_failure_message(clash).is_false()
		lows += 1
	assert_int(lows).is_greater(0)


## The top corner brackets' arms (ScanOverlay.draw_brackets) of the brackets' outer rect.
static func _top_arms(brackets: Rect2) -> Array[Rect2]:
	var arm: float = ScanOverlay.BRACKET_ARM
	var width: float = ScanOverlay.BRACKET_WIDTH
	var right: float = brackets.end.x
	var top: float = brackets.position.y
	return [
		Rect2(brackets.position.x, top, arm, width),
		Rect2(brackets.position.x, top, width, arm),
		Rect2(right - arm, top, arm, width),
		Rect2(right - width, top, width, arm),
	]


## The paid chip (#80, step 7; mock-up B2's count-up): "€N", hidden until shown. The current face
## is big mustard, CURRENT_HEIGHT tall; set_badge_current(false) settles it in place into the small
## paper face, SETTLED_HEIGHT tall, at its own rest y. €0 and a denied value show the muted face
## at either size, and show_badge brings the plain one back. A current chip asked to pop with its
## echo shows the frame around it (shadow included) on its next show, then fades it; without the
## echo, or settled, none shows. The face is drawn in code, behind the text, with no pixel material.
func test_the_paid_chip_faces_mute_and_echo() -> void:
	var view: ItemView = await _laid_out(
		load("%s/milk.tres" % CARDS), ItemView.Form.BELT, BELT_ORIGIN
	)
	var plaque: PayoutPlaque = view.badge as PayoutPlaque
	assert_object(plaque).is_not_null()
	assert_bool(plaque.visible).is_false()
	assert_bool(plaque.is_current()).is_true()
	view.show_badge(5, false)
	assert_str(plaque.text).is_equal("€5")
	assert_str(PayoutPlaque.text_for(17)).is_equal("€17")
	assert_bool(plaque.is_muted()).is_false()
	assert_object(plaque.get_theme_color("font_color")).is_equal(Palette.INK)
	assert_int(plaque.get_theme_font_size("font_size")).is_equal(PayoutPlaque.CURRENT_FONT_SIZE)
	assert_float(plaque.face().size.y).is_equal(PayoutPlaque.CURRENT_HEIGHT)
	assert_float(plaque.get_minimum_size().y).is_less_equal(PayoutPlaque.CURRENT_HEIGHT)
	assert_float(plaque.position.y).is_equal(view.badge_rest_y())
	view.show_badge(0, true)
	assert_bool(plaque.is_muted()).is_true()
	assert_object(plaque.get_theme_color("font_color")).is_equal(Palette.GREY_DARK)
	view.show_fizzle_badge(4)
	assert_bool(plaque.is_muted()).is_true()
	assert_str(plaque.text).is_equal("€4")
	view.show_badge(4, true)
	assert_bool(plaque.is_muted()).is_false()
	# Settled in place: the small face at its own rest y.
	var current_y: float = view.badge_rest_y()
	view.set_badge_current(false)
	assert_bool(plaque.is_current()).is_false()
	assert_bool(plaque.visible).is_true()
	assert_str(plaque.text).is_equal("€4")
	assert_int(plaque.get_theme_font_size("font_size")).is_equal(PayoutPlaque.SETTLED_FONT_SIZE)
	assert_float(plaque.face().size.y).is_equal(PayoutPlaque.SETTLED_HEIGHT)
	assert_float(plaque.get_minimum_size().y).is_less_equal(PayoutPlaque.SETTLED_HEIGHT)
	assert_float(plaque.position.y).is_equal(view.badge_rest_y())
	assert_float(view.badge_rest_y()).is_equal(
		maxf(view._art_top() - ItemView.PAID_SETTLED_ABOVE, ItemView.PAID_SETTLED_MIN_Y)
	)
	# Its foot and shadow end over the mark's top.
	var foot: float = view.badge_rest_y() + PayoutPlaque.SETTLED_HEIGHT + plaque.shadow()
	assert_float(foot).is_less_equal(view._mark_rest().y)
	assert_float(current_y).is_equal(
		maxf(view._art_top() - ItemView.PAID_CURRENT_ABOVE, ItemView.PAID_CURRENT_MIN_Y)
	)
	view.show_badge(0, false)
	assert_bool(plaque.is_muted()).is_true()
	# The echo: only on a current chip's pop that asks for it.
	view.show_badge(3, false)
	assert_bool(plaque.echo_frame().visible).is_false()
	view.set_badge_current(true, true)
	assert_bool(plaque.echo_frame().visible).is_false()
	view.show_badge(3, false)
	var echo: Control = plaque.echo_frame()
	assert_bool(echo.visible).is_true()
	await get_tree().process_frame
	var face: Rect2 = plaque.face().get_global_rect()
	var outside: float = PayoutPlaque.ECHO_GAP + PayoutPlaque.ECHO_WIDTH
	assert_that(echo.get_global_rect()).is_equal(
		Rect2(
			face.position - Vector2.ONE * outside,
			face.size + Vector2.ONE * (PayoutPlaque.CURRENT_SHADOW + 2.0 * outside)
		)
	)
	view.show_badge(3, false)
	await await_millis(int(PayoutPlaque.ECHO_TIME * 1000.0) + 150)
	assert_bool(echo.visible).is_false()
	view.set_badge_current(true, false)
	view.show_badge(3, false)
	assert_bool(echo.visible).is_false()
	assert_object(plaque.material).is_null()
	assert_object(plaque.face().material).is_null()
	assert_bool(plaque.face().show_behind_parent).is_true()
	assert_int(plaque.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	plaque.position.y = 40.0
	view.reset_motion()
	assert_float(plaque.position.y).is_equal(view.badge_rest_y())


## Selected: the sprite lifts by LIFT inside gold brackets. NONE puts it back, fully opaque (the
## basket redraw marks baskets, not items: no REDRAW look on an item since v0.4x).
func test_the_selected_look() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	for definition: CardDefinition in _cards():
		var view: ItemView = await _laid_out(
			definition, ItemView.Form.TRAY, TRAY_ORIGIN, balance.aisle_of(definition)
		)
		var message: String = definition.id
		var rest: Rect2 = view.body.get_global_rect()
		view.set_highlight(CardView.Highlight.SELECTED)
		var lifted: Rect2 = view.body.get_global_rect()
		assert_float(lifted.position.y).is_equal(rest.position.y - ItemView.LIFT)
		var brackets: Rect2 = view.brackets()
		assert_bool(brackets.size != Vector2.ZERO).is_true()
		assert_float(brackets.position.y + view.global_position.y).is_equal(
			lifted.position.y - ScanOverlay.BRACKET_OUTSET
		)
		view.set_highlight(CardView.Highlight.NONE)
		assert_float(view.body.position.y).override_failure_message(message).is_equal(0.0)
		assert_bool(view.brackets().size == Vector2.ZERO).is_true()
		assert_float(view.body.modulate.a).is_equal(1.0)
		assert_float(view.sticker().modulate.a).is_equal(1.0)


## Every card as a basket item (#80, step 8): a BASKET_SIZE cell with its sprite at the cell's
## left, no sticker and no shadow; its art's visible foot is under BASKET_RIM_Y by a third of its
## visible height on the 2 px grid (a coupon's slip BASKET_COUPON_RISE higher). Only the sprite's
## columns from the art's visible top (lifted) take the pointer, inside the cell. Selected, it
## lifts with the outline (ArtOutline) one art pixel round it and no brackets; an undrawn item's
## name keeps to its box's top.
func test_basket_items_sink_a_third_under_the_rim() -> void:
	var cell: Rect2 = Rect2(Vector2.ZERO, ItemView.BASKET_SIZE)
	# The rim's line in the cell is the baskets' front rim on the stage.
	assert_float(ItemView.BASKET_RIM_Y).is_equal(
		HandBaskets.RIM_FRONT_Y - ShiftStage.HAND_RECT.position.y
	)
	for definition: CardDefinition in _cards():
		var view: ItemView = await _laid_out(definition, ItemView.Form.BASKET, TRAY_ORIGIN)
		var message: String = definition.id
		assert_vector(view.size).is_equal(ItemView.BASKET_SIZE)
		assert_bool(view.sticker().visible).is_false()
		assert_that(view._belt_shadow()).is_equal(Rect2())
		var texture: Texture2D = view.sprite().texture
		var box: Rect2i = ContactShadow.opaque_rect(texture)
		var texel: float = ItemView.SPRITE_SIZE.y / texture.get_height()
		var sprite: Rect2 = Rect2(
			view.sprite().get_global_rect().position - TRAY_ORIGIN, Vector2.ZERO
		)
		sprite.size = ItemView.SPRITE_SIZE
		assert_float(sprite.position.x).is_equal(0.0)
		var foot: float = sprite.position.y + box.end.y * texel
		var sink: float = snappedf(box.size.y * texel / 3.0, ArtStyle.ART_SCALE)
		var rise: float = ItemView.BASKET_COUPON_RISE if definition.is_coupon() else 0.0
		assert_float(foot).override_failure_message(message).is_equal(
			ItemView.BASKET_RIM_Y + sink - rise
		)
		# The hit area: the sprite's columns from the art's visible top, lifted, down to its foot.
		var art_top: float = sprite.position.y + box.position.y * texel - ItemView.LIFT
		var hit: Rect2 = Rect2(0, art_top, sprite.size.x, sprite.end.y - art_top)
		assert_that(view.hit_rect()).is_equal(hit)
		assert_bool(cell.encloses(hit)).override_failure_message(message).is_true()
		if view.name_label() != null:
			assert_int(view.name_label().vertical_alignment).is_equal(VERTICAL_ALIGNMENT_TOP)
		view.set_highlight(CardView.Highlight.SELECTED)
		assert_that(view.brackets()).is_equal(Rect2())
		var outline: TextureRect = view._outline
		assert_bool(outline.visible).is_true()
		assert_object(outline.texture).is_same(ArtOutline.texture_for(texture))
		assert_that(outline.get_global_rect()).is_equal(
			view.sprite().get_global_rect().grow(ArtStyle.ART_SCALE)
		)
		view.set_highlight(CardView.Highlight.NONE)
		assert_bool(outline.visible).override_failure_message(message).is_false()


## A selected item's outline (ArtOutline): one pixel larger than the art on each side, mustard
## exactly on the transparent pixels that touch the art (4-neighbours), clear everywhere else.
func test_the_outline_rings_the_art() -> void:
	for path: String in [DRAWN_MILK, "res://art/items_v2/coupon_slip.png"]:
		var art: Texture2D = load(path)
		var outline: ImageTexture = ArtOutline.texture_for(art)
		assert_object(ArtOutline.texture_for(art)).is_same(outline)
		var source: Image = art.get_image()
		var ring: Image = outline.get_image()
		assert_vector(Vector2(ring.get_size())).is_equal(
			Vector2(source.get_size() + Vector2i(2, 2))
		)
		var opaque: Callable = func(x: int, y: int) -> bool:
			var inside: bool = (
				x >= 0 and y >= 0 and x < source.get_width() and y < source.get_height()
			)
			return inside and source.get_pixel(x, y).a >= ArtOutline.OPAQUE_ALPHA
		var count: int = 0
		for y: int in range(ring.get_height()):
			for x: int in range(ring.get_width()):
				var touches: bool = false
				for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					touches = touches or opaque.call(x - 1 + side.x, y - 1 + side.y)
				var expected: bool = touches and not opaque.call(x - 1, y - 1)
				var pixel: Color = ring.get_pixel(x, y)
				assert_bool(pixel.a > 0.5).override_failure_message("%d,%d" % [x, y]).is_equal(
					expected
				)
				if expected:
					assert_that(pixel).is_equal(ArtOutline.COLOUR)
					count += 1
		assert_int(count).is_greater(40)


## A belt item stands on its contact shadow (#80, mock-up B2): its sprite drops by its art's
## transparent rows (the coupon slip's 8), so every item's opaque foot is on the ground line, and
## the shadow is a stepped ellipse across that line, a little right of the sprite's middle, inside
## the cell and above the ticket; lifted (selected or scanned) it shrinks and fades, and it
## follows the sprite back down. Tray and ghost items have none.
func test_belt_items_stand_on_a_contact_shadow() -> void:
	var milk: CardDefinition = load("%s/milk.tres" % CARDS)
	var slip: CardDefinition = load("%s/repeat.tres" % CARDS)
	var feet: Array[float] = []
	for definition: CardDefinition in [milk, slip]:
		var view: ItemView = await _laid_out(definition, ItemView.Form.BELT, BELT_ORIGIN)
		var texture: Texture2D = view.sprite().texture
		var bottom: int = ContactShadow.opaque_bottom(texture)
		assert_int(bottom).is_equal(texture.get_image().get_used_rect().end.y)
		var stand: Vector2 = view.sprite().get_global_rect().position - BELT_ORIGIN
		assert_float(stand.x).is_equal(ItemView.BELT_SPRITE.x)
		var foot: float = stand.y + bottom * ItemView.SPRITE_SIZE.y / texture.get_height()
		assert_float(foot).is_equal_approx(ItemView.BELT_GROUND_Y, 0.01)
		feet.append(float(bottom))
		var shadow: Rect2 = view._belt_shadow()
		assert_vector(shadow.size).is_equal(ItemView.BELT_SHADOW.size)
		assert_bool(shadow.position.y < foot and shadow.end.y > foot).is_true()
		var sprite_middle: float = ItemView.BELT_SPRITE.x + ItemView.SPRITE_SIZE.x / 2.0
		assert_float(shadow.get_center().x).is_greater(sprite_middle)
		assert_bool(Rect2(Vector2.ZERO, ItemView.BELT_SIZE).encloses(shadow)).is_true()
		assert_float(shadow.end.y).is_less_equal(ItemView.BELT_STICKER.y)
		# On the 2 px art grid.
		for value: float in [shadow.position.x, shadow.position.y, shadow.size.x, shadow.size.y]:
			assert_float(fmod(value, ArtStyle.ART_SCALE)).is_equal(0.0)
		view.set_highlight(CardView.Highlight.SELECTED)
		var lifted: Rect2 = view._belt_shadow()
		assert_vector(lifted.size).is_equal(ItemView.BELT_LIFTED_SHADOW.size)
		assert_float(lifted.size.x).is_less(shadow.size.x)
		assert_bool(shadow.encloses(lifted)).is_true()
		view.set_highlight(CardView.Highlight.NONE)
		assert_that(view._belt_shadow()).is_equal(shadow)
		view.lifted = true
		assert_that(view._belt_shadow()).is_equal(lifted)
	# The slip's art ends above its canvas's bottom, so it is the one that drops.
	assert_float(feet[1]).is_less(feet[0])
	assert_float(ItemView.BELT_LIFTED_SHADOW_ALPHA).is_less(ItemView.BELT_SHADOW_ALPHA)
	for form: ItemView.Form in [ItemView.Form.TRAY, ItemView.Form.GHOST]:
		var other: ItemView = await _laid_out(milk, form, TRAY_ORIGIN)
		assert_that(other._belt_shadow()).is_equal(Rect2())


## A product keeps its tags for the scan popup (its own, then the context pass's); a coupon has
## none.
func test_tags_are_kept_for_the_popup() -> void:
	var coffee: CardDefinition = load("%s/coffee.tres" % CARDS)
	var view: ItemView = await _laid_out(coffee, ItemView.Form.BELT, BELT_ORIGIN)
	assert_array(Array(view.tags())).is_equal(Array(coffee.tags))
	view.add_tag("Clearance")
	view.add_tag("Clearance")
	assert_int(view.tags().count("Clearance")).is_equal(1)
	view.set_tags(PackedStringArray(["Food"]))
	assert_array(Array(view.tags())).is_equal(["Food"])
	var coupon: ItemView = await _laid_out(
		load("%s/repeat.tres" % CARDS), ItemView.Form.BELT, BELT_ORIGIN
	)
	coupon.add_tag("Breakfast")
	assert_int(coupon.tags().size()).is_equal(0)


## The item answers the pointer on its sprite (lifted or not) and sticker only, not on the cell's
## empty corners (the mark and the paid chip are decor), and says when the pointer enters and
## leaves.
func test_hover_signals_and_the_hit_area() -> void:
	var view: ItemView = await _laid_out(
		load("%s/milk.tres" % CARDS), ItemView.Form.BELT, BELT_ORIGIN
	)
	var local_sprite: Rect2 = Rect2(
		view.body.global_position - view.global_position, view.body.size
	)
	var local_sticker: Rect2 = Rect2(view.sticker().position, view.sticker().size)
	assert_bool(view._has_point(local_sprite.get_center())).is_true()
	assert_bool(view._has_point(local_sprite.position + Vector2(1, -ItemView.LIFT + 1))).is_true()
	assert_bool(view._has_point(local_sticker.get_center())).is_true()
	assert_bool(view._has_point(Vector2(1, 1))).is_false()
	assert_bool(view._has_point(Vector2(2, ItemView.BELT_SIZE.y - 10))).is_false()
	assert_int(view.show_mark(false).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var seen: Array[String] = []
	view.hovered.connect(
		func(item: ItemView) -> void: seen.append("in:%s" % item.card.definition.id)
	)
	view.unhovered.connect(
		func(item: ItemView) -> void: seen.append("out:%s" % item.card.definition.id)
	)
	view.notification(Control.NOTIFICATION_MOUSE_ENTER)
	view.notification(Control.NOTIFICATION_MOUSE_EXIT)
	assert_array(seen).is_equal(["in:milk", "out:milk"])
	# The sticker's rect, which a side popup keeps clear of.
	assert_that(view.below_rect()).is_equal(view.sticker().get_global_rect())


## One mark per item (#80, step 7): show_mark again keeps the same node and changes its kind in
## place (check, fizzle); the disc is the mark art 13x13 at 2x with its shadow texel inside SIZE;
## the mark stands on the art's visible top-right corner (on the 2 px grid, an art's opaque box
## from ContactShadow.opaque_rect), moves with a hovered or selected sprite (LIFT up,
## MARK_LIFTED_NUDGE sideways) and back, and clear_mark frees it.
func test_one_mark_per_item_on_the_arts_corner() -> void:
	var view: ItemView = await _laid_out(
		load("%s/milk.tres" % CARDS), ItemView.Form.BELT, BELT_ORIGIN
	)
	assert_object(view._mark).is_null()
	var mark: EffectMark = view.show_mark(false)
	assert_bool(mark.is_fizzle()).is_false()
	assert_object(mark.disc().texture).is_same(EffectMark.CHECK_DISC)
	assert_object(view.show_mark(true)).is_same(mark)
	assert_bool(mark.is_fizzle()).is_true()
	assert_object(mark.disc().texture).is_same(EffectMark.FIZZLE_DISC)
	assert_vector(mark.disc().texture.get_size()).is_equal(Vector2(13, 13))
	assert_vector(mark.disc().size).is_equal(Vector2(26, 26))
	assert_vector(mark.size).is_equal(EffectMark.SIZE)
	assert_object(mark.disc().material).is_same(ArtStyle.pixel_material())
	# The corner from the art's opaque box (its used rect).
	var texture: Texture2D = view.sprite().texture
	var box: Rect2i = ContactShadow.opaque_rect(texture)
	assert_that(box).is_equal(texture.get_image().get_used_rect())
	var sprite: Rect2 = view.sprite().get_global_rect()
	var top_right: Vector2 = sprite.position + Vector2(box.end.x, box.position.y) * 2.0
	var rest: Vector2 = mark.global_position
	assert_vector(rest).is_equal(top_right + EffectMark.CORNER_OFFSET)
	for value: float in [rest.x - BELT_ORIGIN.x, rest.y - BELT_ORIGIN.y]:
		assert_float(fmod(value, ArtStyle.ART_SCALE)).is_equal(0.0)
	view.set_highlight(CardView.Highlight.SELECTED)
	assert_vector(mark.global_position).is_equal(
		rest + Vector2(ItemView.MARK_LIFTED_NUDGE, -ItemView.LIFT)
	)
	view.set_highlight(CardView.Highlight.NONE)
	view.lifted = true
	assert_vector(mark.global_position).is_equal(
		rest + Vector2(ItemView.MARK_LIFTED_NUDGE, -ItemView.LIFT)
	)
	view.lifted = false
	assert_vector(mark.global_position).is_equal(rest)
	# Drawn over the sprite and under the paid chip.
	assert_int(mark.get_index()).is_greater(view._stand.get_index())
	assert_int(mark.get_index()).is_less(view.badge.get_index())
	view.clear_mark()
	assert_object(view._mark).is_null()
	await get_tree().process_frame
	(
		assert_int(
			view.get_children().filter(func(node: Node) -> bool: return node is EffectMark).size()
		)
		. is_equal(0)
	)
	# The disc's shadow: one texel down and right, never under the disc.
	for row: int in range(EffectMark.DISC_TEXELS):
		for column: int in range(EffectMark.DISC_TEXELS):
			var opaque: bool = texture_alpha(EffectMark.FIZZLE_DISC, column, row) > 0.0
			assert_bool(opaque).is_equal(EffectMark.in_disc(column, row))


## The sprite comes from art_ref (48x48 at 2x): a drawn product shows its sprite and no name; an
## undrawn one the art-pending box with its name; every coupon the shared slip, with its icon from
## art_ref or, without one, its name.
func test_sprites_come_from_art_ref() -> void:
	var milk: CardDefinition = (load("%s/milk.tres" % CARDS) as CardDefinition).duplicate()
	milk.art_ref = DRAWN_MILK
	var drawn: ItemView = await _laid_out(milk, ItemView.Form.BELT, BELT_ORIGIN)
	assert_str(drawn.sprite().texture.resource_path).is_equal(DRAWN_MILK)
	assert_object(drawn.name_label()).is_null()
	assert_vector(drawn.sprite().texture.get_size() * ArtStyle.ART_SCALE).is_equal(
		ItemView.SPRITE_SIZE
	)
	# An undrawn product: Bread with no art_ref (every stocked product is drawn since #57).
	var undrawn: CardDefinition = (load("%s/bread.tres" % CARDS) as CardDefinition).duplicate()
	undrawn.art_ref = ""
	var bread: ItemView = await _laid_out(undrawn, ItemView.Form.TRAY, TRAY_ORIGIN)
	assert_object(bread.sprite().texture).is_same(ArtStyle.ITEM_PENDING)
	assert_vector(ArtStyle.ITEM_PENDING.get_size() * ArtStyle.ART_SCALE).is_equal(
		ItemView.SPRITE_SIZE
	)
	assert_str(bread.name_label().text).is_equal("Bread")
	# A coupon with no icon (every pool coupon has one since v0.52).
	var plain_repeat: CardDefinition = (
		(load("%s/repeat.tres" % CARDS) as CardDefinition).duplicate()
	)
	plain_repeat.art_ref = ""
	var repeat: ItemView = await _laid_out(plain_repeat, ItemView.Form.BELT, BELT_ORIGIN)
	assert_object(repeat.sprite().texture).is_same(ArtStyle.COUPON_SLIP)
	assert_str(repeat.name_label().text).is_equal("Repeat")
	var multipack: CardDefinition = (
		(load("%s/multipack.tres" % CARDS) as CardDefinition).duplicate()
	)
	multipack.art_ref = COUPON_ICON
	var iconed: ItemView = await _laid_out(multipack, ItemView.Form.BELT, BELT_ORIGIN)
	assert_object(iconed.sprite().texture).is_same(ArtStyle.COUPON_SLIP)
	assert_object(iconed.name_label()).is_null()
	var icons: Array[Node] = iconed.sprite().get_children()
	assert_int(icons.size()).is_equal(1)
	var icon: TextureRect = icons[0] as TextureRect
	assert_str(icon.texture.resource_path).is_equal(COUPON_ICON)
	assert_vector(icon.size).is_equal(icon.texture.get_size() * ArtStyle.ART_SCALE)


## Every card's name fits its art-pending box (a product) or its slip's paper (a coupon) in at
## most NAME_LINES lines, measured with the real font, no word broken, the longest names
## included.
func test_every_name_fits_its_pending_box_or_slip() -> void:
	var names: Array[String] = []
	var too_long: Array[String] = []
	for source: CardDefinition in _cards():
		var definition: CardDefinition = source.duplicate()
		definition.art_ref = ""
		names.append(definition.display_name)
		var view: ItemView = await _laid_out(definition, ItemView.Form.BELT, BELT_ORIGIN)
		var label: Label = view.name_label()
		var message: String = '%s: "%s"' % [definition.id, definition.display_name]
		assert_object(label).override_failure_message(message).is_not_null()
		var room: Rect2 = SLIP_PAPER if definition.is_coupon() else PENDING_BOX.grow(-2.0)
		var rect: Rect2 = Rect2(label.position, label.size)
		assert_bool(room.encloses(rect)).override_failure_message(message).is_true()
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		var widest: float = 0.0
		for word: String in definition.display_name.split(" "):
			widest = maxf(
				widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			)
		var clipped: bool = label.get_visible_line_count() < label.get_line_count()
		if (
			label.get_line_count() > ItemView.NAME_LINES
			or clipped
			or widest > rect.size.x
			or label.get_minimum_size().y > rect.size.y
		):
			too_long.append(message)
	assert_array(too_long).is_empty()
	for long_name: String in LONG_NAMES:
		assert_bool(names.has(long_name)).override_failure_message(long_name).is_true()


## The paid chip's face (its shadow included) stays off the art's visible box, in the cell's
## column and no higher than PAID_SETTLED_MIN_Y over the cell's top; the sprite stays in its cell
## and off the sticker.
func _assert_sprite_clear(view: ItemView, message: String) -> void:
	var sprite: Rect2 = view.body.get_global_rect()
	var art: Rect2 = _art_rect(view)
	var face: Rect2 = _face_with_shadow(view)
	var cell: Rect2 = view.get_global_rect()
	assert_bool(art.intersects(face)).override_failure_message(message).is_false()
	(
		assert_bool(sprite.intersects(view.sticker().get_global_rect()))
		. override_failure_message(message)
		. is_false()
	)
	assert_bool(cell.encloses(sprite)).override_failure_message(message).is_true()
	assert_float(face.position.x).is_greater_equal(cell.position.x)
	assert_float(face.end.x).is_less_equal(cell.end.x)
	assert_float(face.position.y).override_failure_message(message).is_greater_equal(
		cell.position.y + ItemView.PAID_SETTLED_MIN_Y - ItemView.LIFT
	)
	assert_bool(SCREEN.encloses(face)).override_failure_message(message).is_true()
	assert_bool(SCREEN.encloses(sprite)).override_failure_message(message).is_true()


## The paid chip's face and its hard shadow, global.
static func _face_with_shadow(view: ItemView) -> Rect2:
	var plaque: PayoutPlaque = view.badge as PayoutPlaque
	var face: Rect2 = plaque.face().get_global_rect()
	return Rect2(face.position, face.size + Vector2.ONE * plaque.shadow())


## The sprite's visible (opaque) box where it is drawn now, global.
static func _art_rect(view: ItemView) -> Rect2:
	var box: Rect2i = ContactShadow.opaque_rect(view.sprite().texture)
	var sprite: Rect2 = view.sprite().get_global_rect()
	var texel: float = sprite.size.x / view.sprite().texture.get_width()
	return Rect2(sprite.position + Vector2(box.position) * texel, Vector2(box.size) * texel)


## The alpha of `texture`'s texel (`column`, `row`).
static func texture_alpha(texture: Texture2D, column: int, row: int) -> float:
	return texture.get_image().get_pixel(column, row).a


## Every card as an item of `form`, side by side from `origin` (wrapping inside the screen), each
## with its aisle.
func _all_laid_out(form: ItemView.Form, origin: Vector2) -> Array[ItemView]:
	var balance: BalanceDefinition = load(BALANCE)
	var views: Array[ItemView] = []
	var index: int = 0
	for definition: CardDefinition in _cards():
		var view: ItemView = auto_free(
			ItemView.new(CardInstance.new(definition, 1), balance.aisle_of(definition), form)
		)
		view.position = origin + Vector2((index % 8) * 124, 0)
		_holder.add_child(view)
		views.append(view)
		index += 1
	await get_tree().process_frame
	await get_tree().process_frame
	return views


func _laid_out(
	definition: CardDefinition, form: ItemView.Form, at: Vector2, aisle: AisleDefinition = null
) -> ItemView:
	var view: ItemView = auto_free(ItemView.new(CardInstance.new(definition, 1), aisle, form))
	view.position = at
	_holder.add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	return view


func _cards() -> Array[CardDefinition]:
	var result: Array[CardDefinition] = []
	for file: String in DirAccess.get_files_at(CARDS):
		if file.ends_with(".tres"):
			result.append(load("%s/%s" % [CARDS, file]) as CardDefinition)
	return result
