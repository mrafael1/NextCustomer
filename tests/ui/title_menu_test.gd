extends GdUnitTestSuite
## The title's menu and popups (#56, direction C+): the plates stand on the brick at the
## mock-up's places and step in (at once when still); one marker lights an entry, shared by the
## mouse, the keys and the storefront, and Enter presses it (the primary entry when none is
## marked); REWARDS shows the coins and opens TOY MACHINES, while the locked LOYALTY only says
## no; BACK and Esc close it; the New run question never abandons on a bare Enter.

const BALANCE := "res://data/balance/balance.tres"


func _menu(saved: bool) -> TitleMenu:
	var menu: TitleMenu = auto_free(TitleMenu.new(saved, "SHIFT 5/12", 59))
	add_child(menu)
	return menu


func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


func test_the_plates_stand_on_the_brick() -> void:
	var menu: TitleMenu = _menu(true)
	assert_vector(menu.position).is_equal(Vector2(72, 320))
	assert_array(menu.entries()).is_equal(
		[TitleMenu.Entry.PRIMARY, TitleMenu.Entry.NEW_RUN, TitleMenu.Entry.REWARDS]
	)
	var primary: MenuPlate = menu.plate(TitleMenu.Entry.PRIMARY)
	assert_str(primary.caption).is_equal("CONTINUE")
	assert_str(primary.sub_line).is_equal("SHIFT 5/12")
	assert_float(menu.plate(TitleMenu.Entry.NEW_RUN).position.y).is_equal(96.0)
	var rewards: MenuPlate = menu.plate(TitleMenu.Entry.REWARDS)
	assert_float(rewards.position.y).is_equal(152.0)
	assert_str(rewards.count_label().text).is_equal("59")
	# Each plate clears the one above it.
	var plates: Array[MenuPlate] = [primary, menu.plate(TitleMenu.Entry.NEW_RUN), rewards]
	for i: int in plates.size() - 1:
		assert_float(plates[i + 1].position.y).is_greater_equal(plates[i].get_rect().end.y)
	var fresh: TitleMenu = auto_free(TitleMenu.new(false, "12 SHIFTS", 0))
	assert_array(fresh.entries()).is_equal([TitleMenu.Entry.PRIMARY, TitleMenu.Entry.REWARDS])
	assert_str(fresh.plate(TitleMenu.Entry.PRIMARY).caption).is_equal("START RUN")
	assert_object(fresh.plate(TitleMenu.Entry.NEW_RUN)).is_null()


func test_the_length_line_comes_from_balance_data() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var shifts: int = balance.quotas.size()
	var weeks: int = ceili(float(shifts) / balance.week_length)
	assert_str(TitleMenu.length_line(balance)).is_equal("%d SHIFTS · %d WEEKS" % [shifts, weeks])
	var short: BalanceDefinition = balance.duplicate()
	short.week_length = 0
	assert_str(TitleMenu.length_line(short)).is_equal("%d SHIFTS" % shifts)


func test_the_plates_step_in_or_show_at_once_when_still() -> void:
	var menu: TitleMenu = _menu(true)
	var plates: Array[MenuPlate] = []
	for entry: TitleMenu.Entry in menu.entries():
		plates.append(menu.plate(entry))
		assert_bool(menu.plate(entry).visible).is_false()
	var stepping: Tween = menu.step_in()
	assert_object(stepping).is_not_null()
	stepping.custom_step(TitleMenu.SLIDE_TIME / 2.0)
	assert_bool(plates[0].visible).is_true()
	assert_float(plates[0].position.x).is_less(0.0)
	assert_float(fmod(plates[0].position.x, TitleMenu.SLIDE_STEP)).is_equal(0.0)
	stepping.custom_step(1.0)
	for each: MenuPlate in plates:
		assert_bool(each.visible).is_true()
		assert_float(each.position.x).is_equal(0.0)
	var still: TitleMenu = _menu(false)
	still.still = true
	assert_object(still.step_in()).is_null()
	assert_bool(still.plate(TitleMenu.Entry.REWARDS).visible).is_true()


func test_one_marker_lights_an_entry_and_enter_presses_it() -> void:
	var menu: TitleMenu = _menu(true)
	var hot: Array[TitleMenu.Entry] = []
	var pressed: Array[String] = []
	menu.hot_changed.connect(func(entry: TitleMenu.Entry) -> void: hot.append(entry))
	menu.start_pressed.connect(func() -> void: pressed.append("start"))
	menu.new_run_pressed.connect(func() -> void: pressed.append("new_run"))
	menu.rewards_pressed.connect(func() -> void: pressed.append("rewards"))
	# Enter with no marker presses the primary entry.
	assert_bool(menu.handle_key(_key(KEY_ENTER))).is_true()
	assert_array(pressed).is_equal(["start"])
	assert_bool(menu.handle_key(_key(KEY_UP))).is_true()
	assert_int(menu.marked_entry()).is_equal(TitleMenu.Entry.REWARDS)
	assert_bool(menu.plate(TitleMenu.Entry.REWARDS).is_lit()).is_true()
	menu.handle_key(_key(KEY_DOWN))
	assert_int(menu.marked_entry()).is_equal(TitleMenu.Entry.PRIMARY)
	menu.handle_key(_key(KEY_DOWN))
	assert_bool(menu.plate(TitleMenu.Entry.REWARDS).is_lit()).is_false()
	assert_bool(menu.plate(TitleMenu.Entry.NEW_RUN).is_lit()).is_true()
	menu.handle_key(_key(KEY_SPACE))
	assert_array(pressed).is_equal(["start", "new_run"])
	# The storefront marks an entry while its object is under the mouse.
	menu.mark(TitleMenu.Entry.REWARDS)
	menu.unmark(TitleMenu.Entry.PRIMARY)
	assert_int(menu.marked_entry()).is_equal(TitleMenu.Entry.REWARDS)
	menu.unmark(TitleMenu.Entry.REWARDS)
	assert_int(menu.marked_entry()).is_equal(TitleMenu.Entry.NONE)
	(
		assert_array(hot)
		. is_equal(
			[
				TitleMenu.Entry.REWARDS,
				TitleMenu.Entry.PRIMARY,
				TitleMenu.Entry.NEW_RUN,
				TitleMenu.Entry.REWARDS,
				TitleMenu.Entry.NONE,
			]
		)
	)
	assert_bool(menu.handle_key(_key(KEY_A))).is_false()
	# A plate's own press is its entry's.
	menu.plate(TitleMenu.Entry.REWARDS).pressed.emit()
	assert_array(pressed).is_equal(["start", "new_run", "rewards"])


func test_rewards_shows_the_coins_and_its_two_cards_on_the_sheet() -> void:
	var rewards: RewardsMenu = auto_free(RewardsMenu.new(load(BALANCE)))
	rewards.still = true
	add_child(rewards)
	rewards.size = Vector2(1280, 720)
	assert_bool(rewards.is_open()).is_false()
	assert_object(rewards.open(59)).is_null()
	assert_bool(rewards.is_open()).is_true()
	assert_str(rewards.coin_label().text).is_equal("59")
	var sheet: Rect2 = rewards.sheet().get_global_rect()
	assert_vector(sheet.size).is_equal(Vector2(RewardsMenu.SHEET_ART) * ArtStyle.ART_SCALE)
	assert_vector(sheet.get_center()).is_equal(Vector2(640, 360))
	var machines: Rect2 = rewards.toy_machines_card().get_global_rect()
	var loyalty: Rect2 = rewards.loyalty_card().get_global_rect()
	var back: Rect2 = rewards.back_plate().get_global_rect()
	for rect: Rect2 in [machines, loyalty, back, rewards.coin_led().get_global_rect()]:
		assert_bool(sheet.encloses(rect)).is_true()
	assert_bool(machines.intersects(loyalty)).is_false()
	assert_float(back.position.y).is_greater_equal(machines.end.y)
	assert_bool(rewards.loyalty_card().is_locked()).is_true()
	rewards.set_coins(7)
	assert_str(rewards.coin_label().text).is_equal("7")


func test_rewards_opens_toy_machines_and_loyalty_only_says_no() -> void:
	var rewards: RewardsMenu = auto_free(RewardsMenu.new(load(BALANCE)))
	add_child(rewards)
	var heard: Array[String] = []
	rewards.toy_machines_requested.connect(func() -> void: heard.append("machines"))
	rewards.loyalty_denied.connect(func() -> void: heard.append("denied"))
	rewards.closed.connect(func() -> void: heard.append("closed"))
	var opening: Tween = rewards.open(3)
	assert_object(opening).is_not_null()
	assert_float(rewards.sheet().modulate.a).is_equal(0.0)
	opening.custom_step(RewardsMenu.OPEN_TIME)
	assert_float(rewards.sheet().modulate.a).is_equal(1.0)
	# Enter with nothing marked presses nothing.
	rewards.handle_key(_key(KEY_ENTER))
	assert_array(heard).is_empty()
	rewards.handle_key(_key(KEY_DOWN))
	assert_bool(rewards.toy_machines_card().marked).is_true()
	assert_bool(rewards.open_hint().visible).is_true()
	rewards.handle_key(_key(KEY_ENTER))
	assert_array(heard).is_equal(["machines"])
	assert_bool(rewards.is_open()).is_true()
	rewards.handle_key(_key(KEY_RIGHT))
	assert_bool(rewards.loyalty_card().marked).is_true()
	assert_bool(rewards.toy_machines_card().marked).is_false()
	rewards.handle_key(_key(KEY_SPACE))
	assert_array(heard).is_equal(["machines", "denied"])
	assert_bool(rewards.is_open()).is_true()
	rewards.handle_key(_key(KEY_ESCAPE))
	assert_bool(rewards.is_open()).is_false()
	assert_array(heard).is_equal(["machines", "denied", "closed"])
	assert_bool(rewards.handle_key(_key(KEY_DOWN))).is_false()
	rewards.open(3)
	rewards.back_plate().pressed.emit()
	assert_bool(rewards.is_open()).is_false()


func test_the_new_run_question_never_abandons_on_a_bare_enter() -> void:
	var confirm: AbandonConfirm = auto_free(AbandonConfirm.new())
	confirm.still = true
	add_child(confirm)
	confirm.size = Vector2(1280, 720)
	var heard: Array[String] = []
	confirm.abandon_confirmed.connect(func() -> void: heard.append("abandon"))
	confirm.kept.connect(func() -> void: heard.append("kept"))
	confirm.open("SHIFT 3/12 WILL BE LOST")
	assert_str(confirm.lost_label().text).is_equal("SHIFT 3/12 WILL BE LOST")
	var sheet: Rect2 = confirm.sheet().get_global_rect()
	for plate: MenuPlate in [confirm.abandon_plate(), confirm.keep_plate()]:
		assert_bool(sheet.encloses(plate.get_global_rect())).is_true()
	confirm.handle_key(_key(KEY_ENTER))
	assert_array(heard).is_empty()
	confirm.handle_key(_key(KEY_ESCAPE))
	assert_array(heard).is_equal(["kept"])
	assert_bool(confirm.is_open()).is_false()
	confirm.open("SHIFT 3/12 WILL BE LOST")
	confirm.handle_key(_key(KEY_RIGHT))
	assert_bool(confirm.abandon_plate().is_lit()).is_true()
	confirm.handle_key(_key(KEY_RIGHT))
	assert_bool(confirm.keep_plate().is_lit()).is_true()
	confirm.handle_key(_key(KEY_LEFT))
	confirm.handle_key(_key(KEY_ENTER))
	assert_array(heard).is_equal(["kept", "abandon"])
	assert_bool(confirm.is_open()).is_false()


## The marker alone lights a plate: the mouse resting on one plate while a key moves the marker
## away leaves one lit plate (one tick), and Enter presses the lit one; the same in a popup.
func test_a_key_moves_the_light_off_a_hovered_plate() -> void:
	var menu: TitleMenu = _menu(true)
	menu.finish_step_in()
	var primary: MenuPlate = menu.plate(TitleMenu.Entry.PRIMARY)
	_hover(primary)
	assert_int(primary.get_draw_mode()).is_equal(BaseButton.DRAW_HOVER)
	assert_bool(primary.is_lit()).is_true()
	menu.handle_key(_key(KEY_DOWN))
	await get_tree().process_frame
	var lit: Array[TitleMenu.Entry] = []
	for entry: TitleMenu.Entry in menu.entries():
		if menu.plate(entry).is_lit():
			lit.append(entry)
		assert_bool(menu.plate(entry).tick().visible).is_equal(menu.plate(entry).is_lit())
	assert_array(lit).is_equal([TitleMenu.Entry.NEW_RUN])
	var confirm: AbandonConfirm = auto_free(AbandonConfirm.new())
	confirm.still = true
	add_child(confirm)
	confirm.open("SHIFT 3/12 WILL BE LOST")
	_hover(confirm.abandon_plate())
	confirm.handle_key(_key(KEY_RIGHT))
	assert_bool(confirm.abandon_plate().is_lit()).is_false()
	assert_bool(confirm.keep_plate().is_lit()).is_true()


## A frozen menu (a run starting) keeps its marker: neither the mouse nor the keys move it.
func test_a_frozen_menu_keeps_its_marker() -> void:
	var menu: TitleMenu = _menu(true)
	var hot: Array[TitleMenu.Entry] = []
	menu.hot_changed.connect(func(entry: TitleMenu.Entry) -> void: hot.append(entry))
	menu.mark(TitleMenu.Entry.PRIMARY)
	menu.frozen = true
	menu.plate(TitleMenu.Entry.PRIMARY).mouse_exited.emit()
	menu.plate(TitleMenu.Entry.REWARDS).mouse_entered.emit()
	menu.handle_key(_key(KEY_DOWN))
	assert_int(menu.marked_entry()).is_equal(TitleMenu.Entry.PRIMARY)
	assert_array(hot).is_equal([TitleMenu.Entry.PRIMARY])


## Every word on the menu and the popups is hard pixel text (#56): Pixelify's whole-pixel raster
## at 2x or 4x with nearest filtering, on even canvas coordinates, so it sits on the art grid.
func test_the_words_are_hard_pixel_text() -> void:
	var menu: TitleMenu = _menu(true)
	menu.finish_step_in()
	var rewards: RewardsMenu = auto_free(RewardsMenu.new(load(BALANCE)))
	rewards.still = true
	add_child(rewards)
	rewards.size = Vector2(1280, 720)
	rewards.open(59)
	var confirm: AbandonConfirm = auto_free(AbandonConfirm.new())
	confirm.still = true
	add_child(confirm)
	confirm.size = Vector2(1280, 720)
	confirm.open("SHIFT 3/12 WILL BE LOST")
	await get_tree().process_frame
	var words: Array[Label] = []
	for root: Node in [menu, rewards, confirm] as Array[Node]:
		for node: Node in root.find_children("*", "Label", true, false):
			var label: Label = node as Label
			if label.get_theme_font("font") == ArtStyle.pixel_display_font():
				words.append(label)
			else:
				# Anything else is in the number font, and only where a number is.
				assert_object(label.get_theme_font("font")).is_same(ArtStyle.number_font())
	var texts: Array[String] = []
	for label: Label in words:
		texts.append(label.text)
		assert_int(label.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_int(label.get_theme_font_size("font_size")).is_equal(ArtStyle.PIXEL_TEXT_SIZE)
		assert_bool(label.scale.x in [2.0, 4.0]).is_true()
		var at: Vector2 = label.get_global_transform().origin
		(
			assert_vector(at.posmodv(Vector2(2, 2)))
			. override_failure_message("%s at %s" % [label.text, at])
			. is_equal(Vector2.ZERO)
		)
	for caption: String in ["CONTINUE", "NEW RUN", "REWARDS", "TOY MACHINES", "LOYALTY", "BACK"]:
		assert_array(texts).contains([caption])
	for caption: String in ["ESC", "COINS", "ABANDON THIS RUN?", "ABANDON", "KEEP"]:
		assert_array(texts).contains([caption])


## The mouse enters `plate` as it would (the button's hover and its mouse_entered).
func _hover(plate: MenuPlate) -> void:
	plate.notification(Control.NOTIFICATION_MOUSE_ENTER)
	plate.mouse_entered.emit()
