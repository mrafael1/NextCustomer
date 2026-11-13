extends GdUnitTestSuite
## Polish audit batch 1, pass 3 (2026-11-13, v1.36): the shift, the checkout and the machine. The
## monitor's tag row ("Squashed cake +BREAKFAST") whole; a Spot check's stamp under the slot's
## stickers; the WASTED puff (the stack's label) clear above the pile; the price gun parked on the
## bag's lid, clear of the desk calendar at 1280x720 and 1920x1080; the marquee's title beside
## every head stamp; the upgrade tickets' names in the pixel rows; no lone last word on a start
## card's rule; a tip's trailing amount kept with its word and the Menu key's tip; the medal
## twinkle on the medal; the naming pass (KEEP 1, Your cart (n/m), sentence-case tier names).

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards"
const PRICE_GUN := "res://data/pins/price_gun.tres"
const SIZES: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A tag's monitor row names the item and the family as a chip word: the audit's Breakfast
## sticker on Squashed cake reads on one line; every tag card's family on the longest product
## name shows whole (at most the row's lines, no ellipsis).
func test_the_monitor_tag_row_shows_its_family() -> void:
	var line: String = MonitorText.tag_line("Squashed cake", "Breakfast")
	assert_str(line).is_equal("Squashed cake +BREAKFAST")
	var row: Control = _row(line)
	assert_float(row.size.y).is_equal(MonitorStepRow.ROW_PITCH)
	row.free()
	var longest: String = ""
	var families: PackedStringArray = PackedStringArray()
	for card: CardDefinition in _cards():
		if card.is_product() and card.display_name.length() > longest.length():
			longest = card.display_name
		for rule: Rule in card.rules:
			var grant: GrantTagToNextSlotRule = rule as GrantTagToNextSlotRule
			if grant == null:
				continue
			if not grant.tag.is_empty():
				families.append(grant.tag)
			families.append_array(grant.choices)
	assert_bool(families.is_empty()).is_false()
	for family: String in families:
		var whole: Control = _row(MonitorText.tag_line(longest, family))
		var lines: float = whole.size.y / MonitorStepRow.ROW_PITCH
		assert_float(lines).override_failure_message(family).is_less_equal(
			MonitorItemColumn.ROW_MAX_LINES
		)
		(
			assert_object(whole.get_node_or_null("WholeLine"))
			. override_failure_message(family)
			. is_null()
		)
		whole.free()


## A denied item's stamp (Spot check's 0€) is drawn under the stickers: the stamps' box comes
## before the stacks' in the planning layer.
func test_a_spot_check_stamp_sits_under_the_slot_stickers() -> void:
	var layer: PlanningLayer = auto_free(PlanningLayer.new())
	var stamps: int = layer.get_node("Stamps").get_index()
	assert_int(stamps).is_less(layer.get_node("Stacks").get_index())
	assert_int(stamps).is_greater(layer.get_node("TicketRing").get_index())


## A fizzle's puff is the stack's grey WASTED label, starting PUFF_CLEAR px above the item's
## sticker stack (its foot), never on it; with no stack, 30 px over the item.
func test_the_wasted_puff_starts_above_the_pile() -> void:
	var puff: EffectSticker = auto_free(CountUpBeats.wasted_puff())
	assert_str(puff.text()).is_equal(EffectLink.WASTED_WORD)
	assert_int(puff.spec().kind).is_equal(StickerSpec.Kind.FIZZLE)
	var item: Vector2 = Vector2(400, 420)
	for pile: Rect2 in [Rect2(380, 300, 120, 96), Rect2(380, 410, 92, 32)]:
		var at: Vector2 = CountUpBeats.puff_from(item, pile, puff.size)
		var rect: Rect2 = Rect2(at - puff.size / 2.0, puff.size)
		assert_bool(rect.intersects(pile)).override_failure_message(str(pile)).is_false()
		assert_float(rect.end.y).is_less_equal(pile.position.y - CountUpBeats.PUFF_CLEAR)
		assert_float(at.x).is_equal(item.x)
	var bare: Vector2 = CountUpBeats.puff_from(item, Rect2(), puff.size)
	assert_vector(bare).is_equal(item + Vector2(0, -30))


## At 1280x720 and 1920x1080 the price gun and its tag lie on the bag's lid: inside the window,
## clear of the desk calendar (its shift number), the receipt, the belt and the register's keys.
func test_the_price_gun_parks_clear_of_the_calendar() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	await _frames(3)
	var worn: Array[PinDefinition] = [load(PRICE_GUN) as PinDefinition]
	RunPins.wear(screen.run, worn)
	screen.run.start_shift()
	screen._week.skip()
	screen._refresh()
	for window: Vector2 in SIZES:
		screen.size = window
		await _frames(3)
		var gun: PriceGunItem = screen._pins.gun()
		assert_bool(gun.is_visible_in_tree()).is_true()
		var keep_clear: Dictionary[String, Rect2] = {
			"calendar": screen._stage.day_calendar.get_global_rect(),
			"receipt": screen._receipt.get_global_rect(),
			"belt": _on_stage(screen, ShiftStage.BELT_RECT),
			"checkout": screen._cabinet.checkout_key.get_global_rect(),
			"monitor": screen._stage.monitor.get_global_rect(),
		}
		for part: Control in [gun, gun.tag()]:
			var rect: Rect2 = part.get_global_rect()
			var info: String = "%s %s at %s" % [part.name, rect, window]
			(
				assert_bool(screen.get_global_rect().encloses(rect))
				. override_failure_message(info)
				. is_true()
			)
			for what: String in keep_clear:
				(
					assert_bool(rect.intersects(keep_clear[what]))
					. override_failure_message("%s on the %s %s" % [info, what, keep_clear[what]])
					. is_false()
				)
		assert_vector(gun.get_global_rect().position).is_equal_approx(
			_on_stage(screen, PriceGunItem.RECT).position, Vector2.ONE
		)


## While a head stamp is set the marquee keeps its title and sub line, on both faces, centred in
## the room left of the stamp (STAMP_CLEAR clear of it), never blank.
func test_the_marquee_keeps_its_title_beside_every_stamp() -> void:
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	var head: MachineHead = view.head
	var stamps: Array[PackedStringArray] = [
		PackedStringArray([MachineHead.BONUS_TEXT, "Spot check passed"]),
		PackedStringArray([OvertimeWords.SILVER_STAMP, ""]),
		PackedStringArray([OvertimeWords.GOLD_STAMP, ""]),
		PackedStringArray([Payday.STAMP, Payday.STAMP_UNDER]),
	]
	for night: bool in [false, true]:
		head._show_face(night)
		for stamp: PackedStringArray in stamps:
			head.set_stamp(stamp[0], stamp[1])
			var rest: Rect2 = head.stamp_rect()
			var room_end: float = rest.position.x - MachineHead.STAMP_CLEAR
			var centre: float = (MachineHead.TITLE_RECT.position.x + room_end) / 2.0
			for line: MachineLine in head.title_lines():
				var info: String = "%s on %s (night %s)" % [line.text(), stamp[0], night]
				assert_bool(line.visible).override_failure_message(info).is_true()
				var rect: Rect2 = Rect2(line.position, line.size)
				assert_float(rect.position.x).is_greater_equal(MachineHead.TITLE_RECT.position.x)
				assert_float(rect.end.x).override_failure_message(info).is_less_equal(room_end)
				assert_float(rect.get_center().x).is_equal_approx(centre, MachineArt.PIXEL)
	head.set_stamp("", "")
	for line: MachineLine in head.title_lines():
		assert_float(line.position.x + line.size.x / 2.0).is_equal_approx(
			MachineHead.TITLE_RECT.get_center().x, MachineArt.PIXEL
		)


## Once the stamp lifts (and on a BONUS visit before it lands) the title and sub line centre on
## the whole sign again, not in the room left of where the stamp was.
func test_the_marquee_recentres_once_the_stamp_lifts() -> void:
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	var head: MachineHead = view.head
	head.set_stamp(MachineHead.BONUS_TEXT, "Spot check passed")
	view.plan = MachinePlan.new(view.tuning, MachineVisit.Kind.BONUS, false)
	view.plan.set_draw([0, 0, 1] as Array[int])
	view.plan.set_landing(MachinePlan.Landing.NEW_CARD, 1, MachinePlan.NO_VISIT)
	head.frame(view.plan.fly_end + MachineTuning.sec(view.tuning.bonus_stamp_land_ms) + 0.01)
	assert_bool(head.stamp_shown()).is_true()
	var room_end: float = head.stamp_rect().position.x - MachineHead.STAMP_CLEAR
	for line: MachineLine in head.title_lines():
		assert_float(line.position.x + line.size.x).is_less_equal(room_end)
	head.frame(MachineHead.lift_time(view.plan) + 0.1)
	assert_bool(head.stamp_shown()).is_false()
	_assert_lines_centred(head)
	# A BONUS visit whose ticket is still flying: no stamp yet, so a centred sign.
	view.plan = MachinePlan.new(view.tuning, MachineVisit.Kind.BONUS, false)
	view.plan.fly_end = 1.0
	head.set_stamp(MachineHead.BONUS_TEXT, "")
	head.frame(0.5)
	assert_bool(head.stamp_shown()).is_false()
	_assert_lines_centred(head)


func _assert_lines_centred(head: MachineHead) -> void:
	var boxes: Array[Rect2] = [MachineHead.TITLE_RECT, MachineHead.SUB_RECT]
	var lines: Array[MachineLine] = head.title_lines()
	for k: int in lines.size():
		assert_bool(lines[k].visible).is_true()
		assert_float(lines[k].position.x + lines[k].size.x / 2.0).is_equal_approx(
			boxes[k].get_center().x, MachineArt.PIXEL
		)


## An upgrade ticket's name is the item (the tier it reaches is the art's chip) in the hard pixel
## rows, for every item with tiers; its rule says what it does without repeating the name.
func test_upgrade_tickets_name_the_item_in_the_pixel_rows() -> void:
	var tiered: int = 0
	for card: CardDefinition in _cards():
		if not card.is_product() or card.tier != 0 or not ResourceLoader.exists(_big_path(card)):
			continue
		tiered += 1
		var prize: MachinePrize = MachinePrize.new(MachinePrize.Kind.UPGRADE, 1, card)
		var title: String = PrizeTicket.upgrade_name(prize)
		assert_str(title).is_equal(card.display_name)
		# A one-word name wider than the band ("Strawberries") takes the bold fallback, as on
		# its NEW ITEMS ticket; every other name is in the pixel rows.
		if title.contains(" ") or MachineLine.width_of(title) <= PrizeTicket.NAME_WIDTH:
			(
				assert_bool(PrizeTicket.name_rows(title).is_empty())
				. override_failure_message(title)
				. is_false()
			)
	assert_int(tiered).is_greater(10)
	assert_bool(PrizeTicket.name_rows(PrizeTicket.SHELF_NAME).is_empty()).is_false()
	assert_str(PrizeTicket.UPGRADE_ONE % ["PLAIN", "GOLDEN"]).is_equal("Turns 1 PLAIN copy GOLDEN")


## A start card's rule ends on two words at least when the line before can give one (the audit's
## "beside / it"), for every card at its booster window; the copy pass's wordings are in.
func test_start_card_rules_have_no_lone_last_word() -> void:
	var lone: PackedStringArray = PackedStringArray()
	for card: CardDefinition in _cards():
		for rare: bool in [false, true]:
			var text: Dictionary = BoosterArt.face_text(card, rare)
			var win: Rect2i = text.window
			var room: float = float(text.rule_bottom) - float(text.rule_top)
			var fit: Array = BoosterCardDraw.rule_fit(card, win.size.x - 4, room)
			if fit.is_empty():
				continue
			var lines: PackedStringArray = fit[1]
			if lines.size() < 2 or lines[-1].contains(" "):
				continue
			if lines[-2].split(" ", false).size() >= 3:
				var moved: String = lines[-2].get_slice(" ", lines[-2].count(" ")) + " " + lines[-1]
				var wrapped: PackedStringArray = BoosterCardDraw.wrap_words(
					moved, float(fit[0]), win.size.x - 4
				)
				if wrapped.size() == 1:
					lone.append("%s: %s" % [card.id, " / ".join(lines)])
	assert_array(Array(lone)).is_empty()
	var cereal: CardDefinition = load(CARDS.path_join("cereal.tres"))
	assert_str(cereal.rule_text).is_equal("PAIR: +4€ per Milk beside it")
	var bread: CardDefinition = load(CARDS.path_join("bread.tres"))
	assert_str(bread.rule_text).is_equal("Plain item: pays its price")
	var banana: CardDefinition = load(CARDS.path_join("banana.tres"))
	assert_str(banana.rule_text).contains(". CHAIN:")
	var two_for_one: CardDefinition = load(CARDS.path_join("two_for_one.tres"))
	assert_str(two_for_one.rule_text).contains("side by side")


## A tip's amount that ends its text never stands alone on the last line ("quota" then "+10%"),
## at any width; the Menu key's tip has its body.
func test_tips_keep_the_amount_and_the_menu_says_what_it_does() -> void:
	var markup: String = TipMarkup.auto("Bakery items +2€, quota +10%")
	for width: int in range(120, 320, 2):
		var text: TipText = auto_free(
			TipText.new(markup, TipCard.BODY_SIZE, TipCard.BODY_WEIGHT, Palette.INK, width)
		)
		var last: Array = text._lines[-1]
		var words: PackedStringArray = PackedStringArray()
		for item: Dictionary in last:
			words.append(str(item["text"]))
		assert_int(last.size()).override_failure_message("%d: %s" % [width, words]).is_greater(1)
	var bar: TopBar = auto_free(TopBar.new())
	var tip: String = TipTarget.tip_of(bar.menu_button)
	assert_str(TopBar.MENU_TITLE).is_equal("Menu")
	assert_str(tip).contains("Pause, options and the handbook")


## The medal twinkle stays on its medal's sprite at every hop and arm (the "+" read "+GOLD"):
## inside the medal's square, clear of its words.
func test_the_medal_twinkle_stays_on_the_medal() -> void:
	var medal_size: float = MedalArt.SIZE * MedalCase.CELL
	for index: int in range(2):
		var medal: Rect2 = Rect2(MedalCase.MEDAL_AT[index], Vector2.ONE * medal_size)
		for hop: int in range(MedalCase.TWINKLE_SPOTS.size()):
			var at: Vector2 = MedalCase.twinkle_at(index, hop)
			var arm: float = MedalCase.TWINKLE_ARM * MedalCase.CELL
			var reach: Rect2 = Rect2(at - Vector2.ONE * arm, Vector2.ONE * (2.0 * arm + 2.0))
			var info: String = "medal %d hop %d: %s in %s" % [index, hop, reach, medal]
			assert_bool(medal.encloses(reach)).override_failure_message(info).is_true()
			assert_float(reach.end.x).is_less_equal(MedalCase.WORDS_X[index])


## The naming pass: KEEP 1 on the display, the bay and the tray; the cart's placing title in the
## cart's own header pattern; a tier's name is its word and the base name in sentence case.
func test_the_naming_pass() -> void:
	assert_str(PrizeBay.HEADER_DRAWN).contains("KEEP 1")
	assert_str(PrizeRow.KEEP_TEXT).is_equal("KEEP 1")
	assert_str(MachineHead.SUB_LINE).starts_with("KEEP 1")
	var tiers: int = 0
	for card: CardDefinition in _cards():
		if card.tier == 0 or not card.is_product():
			continue
		tiers += 1
		var base: String = card.product_card().display_name
		var word: String = "Big" if card.tier == 1 else "Golden"
		var expected: String = "%s %s%s" % [word, base.left(1).to_lower(), base.substr(1)]
		assert_str(card.display_name).is_equal(expected)
	assert_int(tiers).is_greater(20)
	var short_belt: InspectionDefinition = load("res://data/inspections/short_belt.tres")
	assert_str(short_belt.chip_text).is_equal(short_belt.notice_text)


func _row(line: String) -> Control:
	return MonitorStepRow.make(
		line,
		MonitorStepRow.Tone.PLAIN,
		true,
		null,
		MonitorItemColumn.ROW_MAX_LINES,
		MonitorItemColumn.ROWS_WIDTH
	)


static func _cards() -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for file_name: String in DirAccess.get_files_at(CARDS):
		if file_name.ends_with(".tres"):
			found.append(load(CARDS.path_join(file_name)) as CardDefinition)
	return found


static func _big_path(card: CardDefinition) -> String:
	return CARDS.path_join("%s_big.tres" % card.id)


static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	var stage: Transform2D = screen._stage.get_global_transform()
	return Rect2(stage * rect.position, rect.size * stage.get_scale())


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
