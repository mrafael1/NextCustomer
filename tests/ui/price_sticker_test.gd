extends GdUnitTestSuite
## The price ticket (tickets v5, V5a of mock-up shift_scene_polish_v5_tickets.html): every card in
## data/cards (every tier) reads in three fixed zones, inside the ticket and apart: its family
## glyphs in the icon label (ICON_FIRST + 20 px steps), its price in the fixed window (PriceWindow,
## top right; its digits never leave it for any price, 1€ to 9999€ and the "Nk€" form), and its
## short text from core (CardDefinition.sticker_summary) on the cream plate, fitted to 2 lines at
## 14 px, else 3 at 13, else 3 at 12, the same size for each tier of a card, never cut (no card in
## data/ needs the MORE chip). The face is in the colours of the family it works with
## (FamilyPalette, data); a works-with family is written as a chip (FamilyWord). A gained family
## (the Price gun) grows the ticket to TALL_SIZE with a GAINED row. GOLDEN wears a gold ring
## outside the outline (its own TextureRect), never gold in the window, so a boosted pay (green
## or violet digits on the window's one paper fill) reads apart from it. Its colour says what it
## means in a tooltip (ColourSpot); every glyph, word and window tips below the ticket. No ticket
## carries the staple padlock.

const LiveCardCount := preload("res://tests/data/live_card_count.gd")
const CARDS := "res://data/cards"
## A number that isn't an ordinal ("2nd" stays): the data's numbers, which balance passes may
## change.
const NUMBER := "\\d+(?!st|nd|rd|th)"
## The approved readings of style frame v2's cards (spec section 4.1), every number from the data
## as N.
const READINGS: Dictionary[String, String] = {
	"eggs": "×N next Food",
	"tea_bags": "×N last MORNING",
	# The Banana chain (#106) replaced v2's "+N after Banana"; its CHAIN keyword (#128 Produce
	# links) is a chip.
	"banana": "CHAIN +prev",
	"batteries": "×N next Household",
	"two_for_one": "Same both sides: 2nd ×N",
	"crisps": "+N per redraw left",
	"coffee": "+N per MORNING",
	"milk": "+N per earlier Breakfast",
	"cheese": "+N PAIR with Bread",
	# Produce links (#128): Strawberries feed the chain just after them.
	"strawberries": "+N each, next CHAIN",
	# The Bakery batch roles (#128 v3) replaced Croissant's "+N beside Bakery"; its BATCH keyword
	# is a chip since the Bound strip.
	"croissant": "BATCH 1st: +N to the rest",
	"multipack": "×N later of the family before",
}
## The prices the window must hold: every whole euro to 9999€, and a 12k€ total.
const MAX_WHOLE := 9999
const THOUSANDS := 12000
## The least a boost step's ink (on its own, no shadow) contrasts with the paper fill: step 2's
## orange (about 2.7:1) still reads by its hue; the PR #138 review's pale step 1 (1.9:1) did not.
const BOOST_INK_MIN_CONTRAST := 2.5
## A text no plate holds (the fit's -1).
const TOO_LONG := "+12 per earlier Breakfast item, then ×3 for each Dairy before it "


## Every ticket at rest: its glyphs in the icon label, its window top right, its text on the plate,
## all inside the ticket and apart; its text the card's own, fitted with no MORE chip.
func test_every_ticket_lays_out_inside_and_apart() -> void:
	var cards: Array[CardDefinition] = _cards()
	assert_int(cards.size()).is_equal(LiveCardCount.CARDS)
	var palette: FamilyPalette = FamilyPalette.shared()
	var problems: PackedStringArray = PackedStringArray()
	for definition: CardDefinition in cards:
		var sticker: PriceSticker = auto_free(PriceSticker.new(definition))
		add_child(sticker)
		problems.append_array(_layout_problems(sticker, definition, palette))
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## The rule-fit check over every card in data/ (BIG and GOLDEN tiers included): each text fits the
## plate at one of TEXT_FITS (never the MORE safety net), and each tier of a card prints at the
## same size as its plain card. A text no plate could hold gets no fit.
func test_every_rule_fits_its_plate() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var sizes: Dictionary[String, int] = {}
	var problems: PackedStringArray = PackedStringArray()
	for definition: CardDefinition in _cards():
		var redraws: int = -1
		if CardText.live_rule(definition) != null:
			redraws = (load(PriceSticker.BALANCE) as BalanceDefinition).base_redraws
		var line: String = CardText.sticker_summary(definition, redraws)
		if line.is_empty():
			continue
		var id: String = String(definition.id)
		var fit: int = PriceSticker.fit_for(
			line, 0, palette, CardText.live_tips(definition, redraws)
		)
		if fit < 0:
			problems.append("%s: '%s' fits no plate" % [id, line])
			continue
		var sticker: PriceSticker = auto_free(PriceSticker.new(definition))
		if not sticker.summary().fits() or sticker.get_node_or_null(PriceSticker.MORE_NAME) != null:
			problems.append("%s: '%s' needs MORE" % [id, line])
		var stem: CardDefinition = definition
		while stem.variant_of != null:
			stem = stem.variant_of
		var font_size: int = sticker.summary().font_size()
		var key: String = String(stem.id)
		if sizes.has(key) and sizes[key] != font_size:
			problems.append("%s: %d px, its other tiers %d px" % [id, font_size, sizes[key]])
		sizes[key] = font_size
		if not [14, 13, 12].has(font_size):
			problems.append("%s: %d px" % [id, font_size])
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()
	assert_int(PriceSticker.fit_for(TOO_LONG.repeat(3), 0, palette)).is_equal(-1)


## A wrong job's wider tomato chip still fits the plate on every card with a keyword: the text
## steps down a size while it lasts (never the MORE chip) and back once it clears.
func test_a_wrong_job_still_fits() -> void:
	var problems: PackedStringArray = PackedStringArray()
	for definition: CardDefinition in _cards():
		var sticker: PriceSticker = auto_free(PriceSticker.new(definition))
		if sticker.summary().keywords().is_empty():
			continue
		var calm: int = sticker.summary().font_size()
		sticker.set_wrong_job("WASTED · a test reason")
		var id: String = String(definition.id)
		if not sticker.summary().fits() or sticker.get_node_or_null(PriceSticker.MORE_NAME) != null:
			problems.append("%s: '%s' does not fit wasted" % [id, sticker.summary().text])
		if not sticker.plate_rect().grow(1).encloses(sticker.summary_text_rect()):
			problems.append("%s: wasted text outside the plate" % id)
		sticker.set_wrong_job("")
		if sticker.summary().font_size() != calm:
			problems.append(
				"%s: %d px after, %d before" % [id, sticker.summary().font_size(), calm]
			)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


func test_the_v2_cards_read_as_approved() -> void:
	var number: RegEx = RegEx.create_from_string(NUMBER)
	for card_id: String in READINGS:
		var sticker: PriceSticker = auto_free(PriceSticker.new(_card(card_id)))
		var text: String = sticker.summary().text
		assert_str(number.sub(text, "N", true)).override_failure_message(card_id).is_equal(
			READINGS[card_id]
		)


## Stale popcorn's ×N is live (#128 v3): off the shift it reads the balance's base redraws (2:
## ×3), and the shift's redraws left change it (1: ×2, 0: ×1; Golden ×6, ×4, ×2). Its ×N is a
## gold chip whose tooltip says how it grows, the way Eggs' and Tea bags' ×N reads.
func test_a_live_factor_follows_the_redraws_left() -> void:
	var sticker: PriceSticker = auto_free(PriceSticker.new(_card("stale_popcorn")))
	add_child(sticker)
	assert_str(sticker.summary().text).is_equal("×3 next Snack")
	for left: int in [1, 0, 2]:
		sticker.redraws_left = left
		var word: String = ["×1", "×2", "×3"][left]
		assert_str(sticker.summary().text).is_equal(word + " next Snack")
		var live: Array[KeywordChip] = []
		for chip: KeywordChip in sticker.summary().keywords():
			if chip.is_live():
				live.append(chip)
		assert_int(live.size()).is_equal(1)
		assert_str(live[0].keyword).is_equal(word)
		assert_object(live[0].face_color()).is_equal(Palette.GOLD)
		assert_str(live[0].tip_text).is_equal(
			"%s now · ×1, plus 1 for each redraw left this shift (%d left)" % [word, left]
		)
	var golden: PriceSticker = auto_free(PriceSticker.new(_card("stale_popcorn_golden")))
	assert_str(golden.summary().text).is_equal("×6 next Snack")
	golden.redraws_left = 0
	assert_str(golden.summary().text).is_equal("×2 next Snack")
	# A card with no live factor ignores the redraws.
	var eggs: PriceSticker = auto_free(PriceSticker.new(_card("eggs")))
	var eggs_text: String = eggs.summary().text
	eggs.redraws_left = 0
	assert_str(eggs.summary().text).is_equal(eggs_text)
	assert_int(eggs.redraws_left).is_equal(-1)


## A keyword chip's pixel word goes through the sharp-pixel material with linear filtering (the
## 1920x1080 legibility fix: at 1.5x the word's strokes stay even); a live chip's smooth bold
## digits don't, so a chip scaled up in a pop keeps their edges soft.
func test_only_a_pixel_word_chip_takes_the_pixel_material() -> void:
	var word: KeywordChip = auto_free(KeywordChip.new("BATCH"))
	assert_object(word.material).is_same(ArtStyle.pixel_material())
	assert_int(word.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_LINEAR)
	var wasted: KeywordChip = auto_free(KeywordChip.new("CHAIN", "wasted"))
	assert_object(wasted.material).is_same(ArtStyle.pixel_material())
	var live: KeywordChip = auto_free(KeywordChip.new("×3", "", "×3 now"))
	assert_bool(live.is_live()).is_true()
	assert_object(live.material).is_null()
	assert_int(live.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_PARENT_NODE)


## A card with no rule (Bread) shows its name centred on the plate and its printed price in the
## window.
func test_a_card_with_no_rule_shows_its_name() -> void:
	var bread: CardDefinition = _card("bread")
	assert_bool(bread.rules.is_empty()).is_true()
	var sticker: PriceSticker = auto_free(PriceSticker.new(bread))
	add_child(sticker)
	assert_str(sticker.summary().text).is_equal(bread.display_name)
	var text: Rect2 = sticker.summary_text_rect()
	assert_bool(sticker.plate_rect().encloses(text)).is_true()
	var off_centre: float = absf(text.get_center().x - sticker.plate_rect().get_center().x)
	assert_float(off_centre).is_less_equal(ArtStyle.ART_SCALE)
	assert_int(sticker.window().pay_state()).is_equal(PriceWindow.State.PRINTED)
	assert_str(sticker.window().digits().text).is_equal("%d€" % bread.base)


## The face (V5a): an ink outline with cut corners, the family's light left column, its face down
## the sides, its shade on the right column and the bottom row; the icon label paper, the window's
## place paper, the plate cream with dark text on every family.
func test_the_face_is_in_its_familys_colours() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var cases: Dictionary[String, String] = {
		"milk": "Breakfast",
		"cereal": "Dairy",
		"banana": "Produce",
		"eggs": "Food",
		"batteries": "Household",
		"final_markdown": "Clearance",
	}
	for card_id: String in cases:
		var sticker: PriceSticker = auto_free(PriceSticker.new(_card(card_id)))
		var family: FamilyStyle = palette.style(cases[card_id])
		assert_array(Array(sticker.face_families())).contains_exactly([family.id])
		var art: Image = (sticker.face() as TextureRect).texture.get_image()
		assert_vector(Vector2(art.get_size())).is_equal(Vector2(TicketFace.ART_SIZE))
		assert_vector(sticker.size).is_equal(PriceSticker.SIZE)
		assert_str(_hex(art.get_pixel(2, 20))).override_failure_message(card_id).is_equal(
			_hex(family.face)
		)
		assert_str(_hex(art.get_pixel(1, 20))).is_equal(_hex(family.light))
		assert_str(_hex(art.get_pixel(52, 20))).is_equal(_hex(family.shade))
		assert_str(_hex(art.get_pixel(20, 36))).is_equal(_hex(family.shade))
		assert_str(_hex(art.get_pixel(10, 37))).is_equal(_hex(ArtStyle.INK))
		assert_str(_hex(art.get_pixel(5, 5))).is_equal(_hex(Palette.PAPER))
		assert_str(_hex(art.get_pixel(30, 5))).is_equal(_hex(Palette.PAPER))
		_assert_zone_frames(art, family, family)
		assert_str(_hex(art.get_pixel(20, 25))).is_equal(_hex(Palette.CREAM))
		assert_float(art.get_pixel(0, 0).a).is_equal(0.0)
		assert_float(art.get_pixel(53, 37).a).is_equal(0.0)
		assert_object(sticker.summary().color()).is_equal(Palette.INK)


## A plain coupon wears the coupon teal, a family coupon (the Breakfast sticker) its family's
## colours, both perforated along the foot; the window shows the scissors (a coupon pays nothing
## itself), WASTED when it gives nothing; a coupon is never ringed as a target.
func test_a_coupon_shows_its_scissors() -> void:
	var plain: PriceSticker = auto_free(PriceSticker.new(_card("multipack")))
	var art: Image = (plain.face() as TextureRect).texture.get_image()
	assert_str(_hex(art.get_pixel(2, 20))).is_equal(_hex(Palette.TEAL_SHADE))
	assert_str(_hex(art.get_pixel(3, 36))).is_equal(_hex(Palette.PAPER))
	assert_str(_hex(art.get_pixel(5, 36))).is_equal(_hex(Palette.TEAL_DARK))
	var family: PriceSticker = auto_free(PriceSticker.new(_card("breakfast_sticker")))
	var breakfast: FamilyStyle = FamilyPalette.shared().style("Breakfast")
	var family_art: Image = (family.face() as TextureRect).texture.get_image()
	assert_str(_hex(family_art.get_pixel(2, 20))).is_equal(_hex(breakfast.face))
	assert_str(_hex(family_art.get_pixel(4, 36))).is_equal(_hex(Palette.PAPER))
	for coupon: PriceSticker in [plain, family]:
		assert_int(coupon.window().pay_state()).is_equal(PriceWindow.State.COUPON)
		assert_bool(coupon.window().digits().visible).is_false()
		assert_str(coupon.window().tip_text).contains("a coupon pays nothing itself")
		coupon.set_pay(PlanningModel.Pay.DENIED, 0, "nothing beside it")
		assert_int(coupon.window().pay_state()).is_equal(PriceWindow.State.WASTED)
		assert_str(coupon.window().tip_text).contains("nothing beside it")
		# The slash stays tomato dark over the grey scissors (only lowered and 0€ digits went grey,
		# PR #138 round 2): "gave nothing" still reads.
		assert_str(_hex(PriceWindow.WASTED_SLASH_INK)).is_equal(_hex(Palette.TOMATO_DARK))
		assert_str(_hex(PriceWindow.WASTED_SLASH_INK)).is_not_equal(
			_hex(PriceWindow.WASTED_SCISSORS_INK)
		)
		coupon.clear_pay()
		assert_int(coupon.window().pay_state()).is_equal(PriceWindow.State.COUPON)
		coupon.set_got(true)
		assert_bool(coupon.got_ring().visible).is_false()
	assert_str(plain.glyphs()[0].family).is_equal("Coupon")


## A split ticket (two families): a 45° stair, the second family past it, the seam in its light.
func test_a_split_face_is_a_stair_with_a_seam() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var first: FamilyStyle = palette.style("Produce")
	var second: FamilyStyle = palette.style("Dairy")
	var styles: Array[FamilyStyle] = [first, second]
	var art: Image = TicketFace.image(styles, false)
	assert_str(_hex(art.get_pixel(2, 20))).is_equal(_hex(first.face))
	assert_str(_hex(art.get_pixel(51, 20))).is_equal(_hex(second.face))
	assert_str(_hex(art.get_pixel(29, 13))).is_equal(_hex(second.light))
	assert_str(_hex(art.get_pixel(28, 13))).is_equal(_hex(first.face))
	assert_str(_hex(art.get_pixel(30, 13))).is_equal(_hex(second.face))
	# The zones' frame follows the stair: the window's is the second family's from it on.
	_assert_zone_frames(art, first, second)
	assert_str(_hex(art.get_pixel(30, 1))).is_equal(_hex(first.light))


## The icon label and the window are paper boxes framed by the face (the user's play test of
## 2026-11-03: "badge and price sections should still have a border ... with family color"): one
## art px of the family's light over them and left of them, its shade right of them, its face
## between them and under them; no ink inside the outline round them. `left` frames the label,
## `right` the window's right side and top-right corner.
func _assert_zone_frames(art: Image, left: FamilyStyle, right: FamilyStyle) -> void:
	var label: Rect2i = TicketFace.LABEL
	var window: Rect2i = TicketFace.WINDOW
	for x: int in range(label.position.x, label.end.x):
		assert_str(_hex(art.get_pixel(x, 1))).override_failure_message("top %d" % x).is_equal(
			_hex(left.light)
		)
		assert_str(_hex(art.get_pixel(x, label.end.y))).is_equal(_hex(left.face))
	for y: int in range(label.position.y, label.end.y):
		assert_str(_hex(art.get_pixel(1, y))).is_equal(_hex(left.light))
		assert_str(_hex(art.get_pixel(label.end.x, y))).is_equal(_hex(left.face))
		assert_str(_hex(art.get_pixel(window.end.x, y))).is_equal(_hex(right.shade))
	assert_str(_hex(art.get_pixel(window.end.x - 1, 1))).is_equal(_hex(right.light))
	for y: int in range(1, window.end.y + 1):
		# The outline's cut corner steps in one px on row 1.
		var inset: int = 2 if y == 1 else 1
		for x: int in range(inset, art.get_width() - inset):
			var colour: String = _hex(art.get_pixel(x, y))
			var message: String = "ink at (%d, %d)" % [x, y]
			assert_str(colour).override_failure_message(message).is_not_equal(_hex(ArtStyle.INK))
	assert_int(window.position.x).is_equal(label.end.x + 1)
	assert_int(window.end.x).is_equal(TicketFace.ART_SIZE.x - 2)
	assert_int(window.position.y).is_equal(2)
	assert_vector(PriceWindow.SIZE).is_equal(Vector2(window.size * ArtStyle.ART_SCALE))
	assert_vector(PriceSticker.WINDOW_AT).is_equal(Vector2(window.position * ArtStyle.ART_SCALE))


## The window holds every price in its fixed box by V5a's ladder: the 6x8 digits to 999€, the 4x7
## ones from 1000€ to 9999€, then "12k€" (6x8) and "123k€" (4x7); the digits sit centred in the
## window (within 1 px both ways, on the art's grid: the PR #138 review), the 4x7 ones included,
## and never reach the icons or the plate.
func test_the_window_holds_every_price() -> void:
	var room: int = PriceWindow.DIGITS_RIGHT - PriceWindow.DIGITS_LEFT + 1
	var problems: PackedStringArray = PackedStringArray()
	for amount: int in range(1, MAX_WHOLE + 1):
		var form: Array = PriceWindow.form_for(amount)
		var sheet: PixelWords.Sheet = form[1]
		var whole: String = "%d€" % amount
		var expected: PixelWords.Sheet = (
			PixelWords.Sheet.DIGITS if amount <= 999 else PixelWords.Sheet.SMALL_DIGITS
		)
		if form[0] != whole or sheet != expected:
			problems.append("%d€: %s" % [amount, form])
		if PixelWords.font_size_of(form[0], sheet).x > room:
			problems.append("%d€ too wide" % amount)
	for amount: int in [10000, 12345, 99999, 100000, 999999]:
		var form: Array = PriceWindow.form_for(amount)
		if PixelWords.font_size_of(form[0], form[1]).x > room:
			problems.append("%d€ too wide" % amount)
	assert_array(PriceWindow.form_for(123456)).is_equal(["123k€", PixelWords.Sheet.SMALL_DIGITS])
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()
	assert_array(PriceWindow.form_for(THOUSANDS)).is_equal(["12k€", PixelWords.Sheet.DIGITS])
	# On a ticket with two glyphs and a long text (Golden Milk), at each width of price.
	var milk: PriceSticker = auto_free(PriceSticker.new(_card("milk_golden")))
	add_child(milk)
	var window: PriceWindow = milk.window()
	var box: Rect2 = Rect2(window.position, window.size)
	assert_that(box).is_equal(Rect2(PriceSticker.WINDOW_AT, PriceWindow.SIZE))
	var middle: Vector2 = window.size / 2.0
	for amount: int in [1, 9, 99, 999, 1000, 9999, THOUSANDS, 123456]:
		milk.set_pay(PlanningModel.Pay.BOOSTED, amount)
		var digits: Rect2 = window.digits_rect()
		var message: String = "%d€: %s" % [amount, digits]
		var inside: bool = Rect2(Vector2.ZERO, window.size).encloses(digits)
		assert_bool(inside).override_failure_message(message).is_true()
		var off: Vector2 = (digits.get_center() - middle).abs()
		assert_float(off.x).override_failure_message(message).is_less_equal(1.0)
		assert_float(off.y).override_failure_message(message).is_less_equal(1.0)
		assert_float(fmod(digits.position.x, ArtStyle.ART_SCALE)).is_equal(0.0)
		assert_float(fmod(digits.position.y, ArtStyle.ART_SCALE)).is_equal(0.0)
		var shadow: Rect2 = Rect2(window.shadow().position, window.shadow().size)
		assert_bool(Rect2(Vector2.ZERO, window.size).encloses(shadow)).is_true()
		var shown: Rect2 = Rect2(window.position + digits.position, digits.size)
		for glyph: FamilyGlyph in milk.glyphs():
			var over: bool = glyph.rim_rect().intersects(shown)
			assert_bool(over).override_failure_message(message).is_false()
		var on_plate: bool = shown.intersects(milk.plate_rect())
		assert_bool(on_plate).override_failure_message(message).is_false()
		assert_that(Rect2(window.position, window.size)).is_equal(box)
		assert_str(window.tip_text).contains("%d€" % amount)


## The monitor's payout prints a lowered or 0€ pay in the ticket's grey too (the PR #138 round 2),
## a plain one in ink: the same state colours as the price window.
func test_the_monitor_payout_shares_the_window_inks() -> void:
	var payout: MonitorPayout = auto_free(MonitorPayout.new())
	payout.show_pay(PriceWindow.State.LOWERED, 1, 3)
	assert_that(payout.digit_words().color).is_equal(Palette.MUTED_INK)
	assert_bool(payout.shadow().visible).is_false()
	payout.show_pay(PriceWindow.State.ZERO, 0, 4, PlanningModel.Glyph.WARNING)
	assert_that(payout.digit_words().color).is_equal(Palette.MUTED_INK)
	payout.show_pay(PriceWindow.State.PRINTED, 4, 4)
	assert_that(payout.digit_words().color).is_equal(Palette.INK)


## Each pay has its window state; the window's fill is paper in every state (the user's play test
## of 2026-11-03) and the digits' ink says the pay: ink printed, a boost on BOOST_INKS' ramp,
## lowered and 0€ (its reason in the tip) grey (muted ink; the PR #138 round 2: tomato dark until
## then), still readable on the paper.
func test_the_window_says_the_pay() -> void:
	var milk: PriceSticker = auto_free(PriceSticker.new(_card("milk")))
	var window: PriceWindow = milk.window()
	var cases: Dictionary[PlanningModel.Pay, PriceWindow.State] = {
		PlanningModel.Pay.PLAIN: PriceWindow.State.PRINTED,
		PlanningModel.Pay.BOOSTED: PriceWindow.State.BOOSTED,
		PlanningModel.Pay.LOWERED: PriceWindow.State.LOWERED,
		PlanningModel.Pay.DENIED: PriceWindow.State.ZERO,
		PlanningModel.Pay.ZERO: PriceWindow.State.ZERO,
	}
	for pay: PlanningModel.Pay in cases:
		milk.set_pay(pay, 12, "SPOT CHECK")
		assert_int(window.pay_state()).is_equal(cases[pay])
	# One fill for every state: no per-state fill or band is left.
	assert_that(PriceWindow.FILL).is_equal(Palette.PAPER)
	for gone: String in ["fill_color", "band_color"]:
		assert_bool(window.has_method(gone)).override_failure_message(gone).is_false()
	milk.set_pay(PlanningModel.Pay.LOWERED, 1)
	assert_that(window.digits().color).is_equal(Palette.MUTED_INK)
	assert_float(_contrast(Palette.MUTED_INK, PriceWindow.FILL)).is_greater_equal(3.5)
	assert_bool(window.shadow().visible).is_false()
	milk.set_pay(PlanningModel.Pay.PLAIN, 0)
	assert_that(window.digits().color).is_equal(Palette.INK)
	milk.set_pay(PlanningModel.Pay.DENIED, 0, "SPOT CHECK")
	assert_that(window.digits().color).is_equal(Palette.MUTED_INK)
	assert_str(window.digits().text).is_equal("0€")
	assert_str(window.tip_text).contains("SPOT CHECK")
	milk.set_pay(PlanningModel.Pay.ZERO, 0)
	assert_str(window.tip_text).contains(PriceSticker.ZERO_REASON)
	milk.set_pay(PlanningModel.Pay.BOOSTED, 18)
	assert_str(window.digits().text).is_equal("18€")
	var printed: String = "%d€" % _card("milk").base
	assert_str(window.tip_text).is_equal(PriceSticker.PAY_TIP % ["Milk", "18€", printed, "boosted"])
	milk.clear_pay()
	assert_int(window.pay_state()).is_equal(PriceWindow.State.PRINTED)
	assert_str(window.digits().text).is_equal(printed)


## GOLDEN and boosted take different draw paths, so they never read alike: GOLDEN is a gold ring
## outside the outline (its own TextureRect, dark rim outermost) with two sparkles, the window
## inside still paper; a boosted pay is the digits' amber, orange or red ink, and no window ink is
## ever gold, brass or mustard.
func test_golden_and_boosted_read_apart() -> void:
	var golden: PriceSticker = auto_free(PriceSticker.new(_card("milk_golden")))
	var plain: PriceSticker = auto_free(PriceSticker.new(_card("milk")))
	assert_object(plain.gold_ring()).is_null()
	var ring: TextureRect = golden.gold_ring()
	assert_object(ring).is_not_null()
	var grow: float = PriceSticker.GOLD_RING_ART * ArtStyle.ART_SCALE
	assert_that(Rect2(ring.position, ring.size)).is_equal(
		Rect2(Vector2.ZERO, PriceSticker.SIZE).grow(grow)
	)
	var art: Image = ring.texture.get_image()
	var middle: int = floori(art.get_width() / 2.0)
	assert_str(_hex(art.get_pixel(middle, 0))).is_equal(_hex(Palette.BRASS_DARKEST))
	assert_str(_hex(art.get_pixel(middle, 1))).is_equal(_hex(Palette.GOLD))
	assert_str(_hex(art.get_pixel(middle, 2))).is_equal(_hex(Palette.GOLD))
	assert_str(_hex(art.get_pixel(middle, art.get_height() - 2))).is_equal(_hex(Palette.BRASS))
	assert_float(art.get_pixel(middle, 10).a).is_equal(0.0)
	for index: int in 2:
		assert_object(golden.get_node_or_null(PriceSticker.SPARKLE_NAME % index)).is_not_null()
	assert_int(golden.window().pay_state()).is_equal(PriceWindow.State.PRINTED)
	plain.set_pay(PlanningModel.Pay.BOOSTED, 30)
	assert_object(plain.gold_ring()).is_null()
	var inks: Array[Color] = [
		PriceWindow.FILL,
		PriceWindow.NEGATIVE_INK,
		PriceWindow.SCISSORS_INK,
		PriceWindow.WASTED_SCISSORS_INK,
		PriceWindow.WASTED_SLASH_INK,
	]
	for state: PriceWindow.State in PriceWindow.State.values():
		for step: int in range(1, PriceWindow.BOOST_INKS.size() + 1):
			inks.append(PriceWindow.digit_color(state, step))
			inks.append(PriceWindow.shadow_color(state, step))
	for colour: Color in inks:
		for gold: Color in [Palette.GOLD, Palette.BRASS, Palette.MUSTARD, Palette.BRASS_DARKEST]:
			assert_bool(colour.is_equal_approx(gold)).is_false()


## The boost ramp (the user's play test of 2026-11-03: "stronger the price, the stronger the
## color"; the PR #138 review's classic ramp: "black for base, yellow/orange for semi strong and red
## for strong"): step 1 for any boost, step 2 from pay_ink_ratios[0] times the base, step 3 from
## pay_ink_ratios[1] times (data/balance/planning.tres); the printed price ink, steps 1 and 2 (semi
## strong) amber then orange, step 3 (strong, PriceWindow.STRONG_STEP) red, each on a darker
## shadow. Every step reads on the paper fill (its shadow at 3:1 or more, and its ink itself at
## BOOST_INK_MIN_CONTRAST or more, so no step is a pale ink held up by its shadow alone: the PR #138
## review's washed-out step 1), each is apart from the last, and none is a negative pay's tomato
## dark.
func test_the_boost_ink_steps_up_with_the_pay() -> void:
	var ratios: PackedInt32Array = PriceWindow.ink_ratios()
	var tuning: PlanningTuning = load(PriceWindow.TUNING_PATH) as PlanningTuning
	assert_array(Array(ratios)).is_equal(Array(tuning.pay_ink_ratios))
	assert_int(ratios.size()).is_equal(PriceWindow.BOOST_INKS.size() - 1)
	assert_int(ratios[0]).is_greater(1)
	assert_int(ratios[1]).is_greater(ratios[0])
	var base: int = 4
	var cases: Dictionary[int, int] = {
		base + 1: 1,
		base * ratios[0] - 1: 1,
		base * ratios[0]: 2,
		base * ratios[1] - 1: 2,
		base * ratios[1]: 3,
		base * ratios[1] * 10: 3,
	}
	for amount: int in cases:
		var message: String = "%d€ on %d€" % [amount, base]
		assert_int(PriceWindow.boost_step(amount, base)).override_failure_message(message).is_equal(
			cases[amount]
		)
	# A base of 0 counts as 1.
	assert_int(PriceWindow.boost_step(ratios[1], 0)).is_equal(3)
	var expected: Array[Array] = [
		[Palette.MUSTARD_DARK, Palette.MUSTARD_DARKEST],
		[Palette.ORANGE, Palette.ORANGE_DARK],
		[Palette.TOMATO, Palette.TOMATO_DARKEST],
	]
	assert_array(PriceWindow.BOOST_INKS).is_equal(expected)
	assert_int(PriceWindow.STRONG_STEP).is_equal(PriceWindow.BOOST_INKS.size())
	var last: Color = Palette.INK
	for step: int in range(1, PriceWindow.BOOST_INKS.size() + 1):
		var ink: Color = PriceWindow.digit_color(PriceWindow.State.BOOSTED, step)
		var shadow: Color = PriceWindow.shadow_color(PriceWindow.State.BOOSTED, step)
		var step_text: String = "step %d" % step
		(
			assert_float(_contrast(shadow, Palette.PAPER))
			. override_failure_message(step_text)
			. is_greater_equal(3.0)
		)
		(
			assert_float(_contrast(ink, Palette.PAPER))
			. override_failure_message(step_text)
			. is_greater_equal(BOOST_INK_MIN_CONTRAST)
		)
		assert_that(ink).is_not_equal(last)
		assert_that(ink).is_not_equal(PriceWindow.NEGATIVE_INK)
		last = ink
	# On a ticket: Milk's pay against its printed price picks its step; every step wears the
	# shadow one art px down and right, inside the window.
	var definition: CardDefinition = _card("milk")
	var milk: PriceSticker = auto_free(PriceSticker.new(definition))
	add_child(milk)
	var window: PriceWindow = milk.window()
	var printed: int = maxi(definition.base, 1)
	for step: int in range(1, PriceWindow.BOOST_INKS.size() + 1):
		var amount: int = printed + 1 if step == 1 else printed * ratios[step - 2]
		milk.set_pay(PlanningModel.Pay.BOOSTED, amount)
		assert_int(window.boost_level()).is_equal(step)
		assert_that(window.digits().color).is_equal(PriceWindow.BOOST_INKS[step - 1][0])
		var shadow: PixelWords = window.shadow()
		assert_bool(shadow.visible).is_true()
		assert_that(shadow.color).is_equal(PriceWindow.BOOST_INKS[step - 1][1])
		assert_str(shadow.text).is_equal(window.digits().text)
		var offset: Vector2 = Vector2(PriceWindow.SHADOW_OFFSET) * ArtStyle.ART_SCALE
		assert_vector(shadow.position).is_equal(window.digits().position + offset)
		var shown: Rect2 = Rect2(shadow.position, shadow.size)
		assert_bool(Rect2(Vector2.ZERO, window.size).encloses(shown)).is_true()
	milk.clear_pay()
	assert_int(window.boost_level()).is_equal(0)
	assert_bool(window.shadow().visible).is_false()


## The WCAG contrast of two colours.
static func _contrast(a: Color, b: Color) -> float:
	var la: float = a.srgb_to_linear().get_luminance()
	var lb: float = b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## A gained family (the Price gun) grows only that ticket, downward, to TALL_SIZE: the glyph on the
## label's second row, GAINED beside it, the plate moved down; the window stays put. Taking it off
## puts the short ticket back.
func test_a_gained_family_makes_the_tall_ticket() -> void:
	var definition: CardDefinition = _card("milk_golden")
	var milk: PriceSticker = auto_free(PriceSticker.new(definition))
	add_child(milk)
	var printed: int = milk.glyphs().size()
	milk.show_gained("Household")
	assert_bool(milk.is_tall()).is_true()
	assert_vector(milk.size).is_equal(PriceSticker.TALL_SIZE)
	assert_vector(milk.face().texture.get_size()).is_equal(Vector2(TicketFace.TALL_ART_SIZE))
	assert_int(milk.glyphs().size()).is_equal(printed + 1)
	var gained: FamilyGlyph = milk.glyphs()[-1]
	assert_str(String(gained.name)).is_equal(PriceSticker.GAINED_NAME % "Household")
	assert_vector(gained.position).is_equal(
		PriceSticker.ICON_FIRST + Vector2(0, PriceSticker.ICON_ROW_2)
	)
	assert_str(gained.tip_text).contains("gained from the Price gun")
	var words: PixelWords = milk.get_node(PriceSticker.GAINED_WORDS_NAME) as PixelWords
	assert_bool(words.visible).is_true()
	assert_str(words.text).is_equal(PriceSticker.GAINED_TEXT)
	assert_vector(milk.window().position).is_equal(PriceSticker.WINDOW_AT)
	_assert_layout(milk, definition)
	var grow: float = 2.0 * PriceSticker.GOLD_RING_ART * ArtStyle.ART_SCALE
	assert_float(milk.gold_ring().size.y).is_equal(PriceSticker.TALL_SIZE.y + grow)
	milk.show_gained("")
	assert_bool(milk.is_tall()).is_false()
	assert_vector(milk.size).is_equal(PriceSticker.SIZE)
	assert_bool(words.visible).is_false()
	assert_int(milk.glyphs().size()).is_equal(printed)
	_assert_layout(milk, definition)


## A hovered giver's target (#71) gets a gold ring inside its outline, its face unchanged.
func test_got_rings_a_products_ticket() -> void:
	var milk: PriceSticker = auto_free(PriceSticker.new(_card("milk")))
	var face: Texture2D = (milk.face() as TextureRect).texture
	milk.set_got(true)
	assert_bool(milk.got_ring().visible).is_true()
	assert_object((milk.face() as TextureRect).texture).is_same(face)
	milk.set_got(false)
	assert_bool(milk.got_ring().visible).is_false()


## The ticket's colour has a tooltip below the ticket (ColourSpot over the whole face, under its
## glyphs): what the colour means (FamilyPalette.colour_tip).
func test_the_colour_says_what_it_means() -> void:
	var expected: Dictionary[String, String] = {
		"milk": "Breakfast colour · works with Breakfast",
		"cereal": "Dairy colour · works with Milk",
		"banana": "Produce colour · works with another Banana",
		"breakfast_sticker": "Breakfast colour · gives Breakfast",
		"batteries": "Household colour · works with Household",
		"scissors": "Household colour · its own family",
		"multipack": "Plain coupon: works with whatever is beside it",
	}
	for id: String in expected:
		var sticker: PriceSticker = auto_free(PriceSticker.new(_card(id)))
		add_child(sticker)
		var spot: PriceSticker.ColourSpot = _spot(sticker)
		assert_object(spot).override_failure_message(id).is_not_null()
		assert_str(spot.tip_text).override_failure_message(id).is_equal(expected[id])
		assert_bool(spot.tip_below).is_true()
		assert_object(spot.tip_anchor).is_same(sticker)
		assert_that(Rect2(spot.position, spot.size)).is_equal(
			Rect2(Vector2.ZERO, PriceSticker.SIZE)
		)
		# Under every glyph, word and the window, so their own tips win where they overlap.
		for part: Control in _tip_targets(sticker):
			assert_bool(part.is_greater_than(spot)).override_failure_message(id).is_true()


## The hover tips, each below the ticket: a membership glyph names the family and the item (and
## lights the family's items, PlanningEffects: mix_highlight_ui_test), a written family says what
## the item works with, the window its price.
func test_every_tip_opens_below_its_ticket() -> void:
	var milk: PriceSticker = auto_free(PriceSticker.new(_card("milk")))
	add_child(milk)
	var member: FamilyGlyph = milk.glyphs()[0]
	var style: FamilyStyle = FamilyPalette.shared().style(member.family)
	assert_str(member.tip_text).is_equal(
		PriceSticker.MEMBER_TIP % [style.display_name, "Milk", style.display_name]
	)
	var words: Array[FamilyWord] = milk.summary().words()
	assert_int(words.size()).is_equal(1)
	assert_str(words[0].family).is_equal("Breakfast")
	assert_str(words[0].tip_text).is_equal(FamilyWord.WORKS_WITH % "Breakfast")
	assert_str(milk.window().tip_text).is_equal(
		PriceSticker.PRINTED_TIP % ["Milk", "%d€" % _card("milk").base]
	)
	var scissors: PriceSticker = auto_free(PriceSticker.new(_card("scissors")))
	for sticker: PriceSticker in [milk, scissors]:
		for target: TipTarget in _tip_targets(sticker):
			assert_bool(target.tip_below).is_true()
			assert_object(target.tip_anchor).is_same(sticker)
		for glyph: FamilyGlyph in sticker.glyphs():
			assert_object(glyph.rim()).is_not_null()


## `sticker` lays out as test_every_ticket_lays_out_inside_and_apart holds.
func _assert_layout(sticker: PriceSticker, definition: CardDefinition) -> void:
	var problems: PackedStringArray = _layout_problems(sticker, definition, FamilyPalette.shared())
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## `sticker`'s window, glyphs and written families: the parts with tips of their own.
static func _tip_targets(sticker: PriceSticker) -> Array[TipTarget]:
	var targets: Array[TipTarget] = [sticker.window()]
	for glyph: FamilyGlyph in sticker.glyphs() + sticker.summary().glyphs():
		targets.append(glyph)
	for word: FamilyWord in sticker.summary().words():
		targets.append(word)
	return targets


static func _layout_problems(
	sticker: PriceSticker, definition: CardDefinition, palette: FamilyPalette
) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var id: String = String(definition.id)
	var face: Rect2 = Rect2(Vector2.ZERO, sticker.size)
	var summary: GlyphLabel = sticker.summary()
	var line: String = CardText.sticker_summary(definition, sticker.redraws_left)
	if summary.text != (line if not line.is_empty() else definition.display_name):
		problems.append("%s: summary '%s'" % [id, summary.text])
	if not summary.fits() or sticker.get_node_or_null(PriceSticker.MORE_NAME) != null:
		problems.append("%s: summary does not fit" % id)
	var text: Rect2 = sticker.summary_text_rect()
	var plate: Rect2 = sticker.plate_rect()
	if not plate.grow(1).encloses(text):
		problems.append("%s: summary %s outside %s" % [id, text, plate])
	var chips: Array[Control] = []
	for chip: KeywordChip in summary.keywords():
		chips.append(chip)
	for word: FamilyWord in summary.words():
		chips.append(word)
	for chip: Control in chips:
		var rect: Rect2 = Rect2(summary.position + chip.position, chip.size)
		if not plate.grow(1).encloses(rect):
			problems.append("%s: chip %s outside %s" % [id, rect, plate])
	if sticker.face_families() != palette.ticket_families(definition):
		problems.append("%s: face %s" % [id, sticker.face_families()])
	if sticker.find_children("*Lock*", "", true, false).size() > 0:
		problems.append("%s: a padlock" % id)
	var window: Rect2 = Rect2(sticker.window().position, sticker.window().size)
	if window != Rect2(PriceSticker.WINDOW_AT, PriceWindow.SIZE) or not face.encloses(window):
		problems.append("%s: window at %s" % [id, window])
	if window.intersects(text) or window.intersects(plate):
		problems.append("%s: window over the plate" % id)
	problems.append_array(_glyph_problems(sticker, definition, palette, window, text))
	return problems


static func _glyph_problems(
	sticker: PriceSticker,
	definition: CardDefinition,
	palette: FamilyPalette,
	window: Rect2,
	text: Rect2
) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var id: String = String(definition.id)
	var label: Rect2i = TicketFace.label_rect(sticker.is_tall())
	var label_rect: Rect2 = Rect2(label.position * 2, label.size * 2)
	var expected: PackedStringArray = PackedStringArray(["Coupon"])
	if definition.is_product():
		expected = palette.shelf_families(definition.tags)
	var shown: PackedStringArray = PackedStringArray()
	for glyph: FamilyGlyph in sticker.glyphs():
		var rim: Rect2 = glyph.rim_rect()
		if not String(glyph.name).begins_with("Gained"):
			var at: Vector2 = (
				PriceSticker.ICON_FIRST + Vector2(PriceSticker.ICON_STEP * shown.size(), 0)
			)
			if glyph.position != at:
				problems.append("%s: glyph %d at %s" % [id, shown.size(), glyph.position])
			shown.append(glyph.family)
		if not label_rect.grow(1).encloses(rim):
			problems.append("%s: glyph %s outside the label" % [id, glyph.family])
		if rim.intersects(window) or rim.intersects(text):
			problems.append("%s: glyph %s over the window or text" % [id, glyph.family])
	if shown != expected:
		problems.append("%s: glyphs %s, not %s" % [id, shown, expected])
	return problems


static func _spot(sticker: PriceSticker) -> PriceSticker.ColourSpot:
	return sticker.get_node(PriceSticker.COLOUR_SPOT_NAME) as PriceSticker.ColourSpot


static func _hex(colour: Color) -> String:
	return colour.to_html()


static func _card(card_id: String) -> CardDefinition:
	return load("%s/%s.tres" % [CARDS, card_id]) as CardDefinition


static func _cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file: String in DirAccess.get_files_at(CARDS):
		if file.ends_with(".tres"):
			cards.append(load("%s/%s" % [CARDS, file]) as CardDefinition)
	return cards
