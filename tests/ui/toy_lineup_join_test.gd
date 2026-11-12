extends GdUnitTestSuite
## A new figurine joins its lineup card (v1.05, mock-up toy_shelf_unlock.html option B,
## ToyLineupJoin): once the reveal's hold is over the drawn machine's lineup card is the stage
## (kept up when hovered, dropped in otherwise), the icon flies from the reveal into its mini, which
## flips into colour, and only then do the FIGURINES LED, the plate and the window count it (held
## from the draw); a tap ends the look. A capsule that completes its aisle turns the band gold
## (ALL COLLECTED) and shows the COMPLETED! card, which waits for OK, then SOLD OUT; the last
## capsule of all opens COLLECTION COMPLETE at the end. The card (v1.26) is the aisle's band with
## the COMPLETED stamp slammed onto it and OK, no rules, pips or footer. Every piece stays on
## screen, clear of the others. Saves and logs go to a temporary
## folder.

const Kit := preload("res://tests/ui/toy_test_kit.gd")

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_toys_join_%d" % Time.get_ticks_usec()
	Kit.event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(Kit.SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	Kit.remove(_folder)


## Hovered, the lineup stays up behind the reveal; the flight lands on the drawn mini, which
## turns to colour; the counts tick after; NEW! sits under the mini; a tap ends the look.
func test_the_figurine_joins_the_hovered_lineup_card() -> void:
	var profile: ProfileState = Kit.profile(2, 2, {&"bakery": 2})
	var screen: ToyMachinesScreen = await _open(profile)
	var bakery: ToyMachineView = _machine(screen, &"bakery")
	bakery._on_hover(true)
	var lineup: ToyLineup = screen.lineup()
	assert_bool(lineup.visible).is_true()
	bakery._gui_input(Kit.left_click())
	await _frames(2)
	var join: ToyLineupJoin = screen.lineup_join()
	assert_bool(lineup.visible).is_true()  # Kept, behind the reveal's shade.
	assert_int(lineup.z_index).is_equal(0)
	assert_bool(screen.board().visible).is_false()
	var drawn: CardDefinition = _drawn(profile, &"bakery", 2)
	var index: int = Kit.aisle(Kit.balance(), &"bakery").capsule_cards.find(drawn)
	assert_bool(lineup.is_owned(index)).is_false()
	await _dismiss(screen)
	assert_bool(join.is_active()).is_true()
	assert_int(lineup.z_index).is_greater(join.shade().z_index)
	assert_float(lineup.position.y).is_equal(lineup.rest_position().y)  # Not dropped again.
	join.seek(ToyLineupJoin.TO_S * 0.5)
	assert_bool(join.flyer().visible).is_true()
	assert_bool(Kit.SCREEN_RECT.encloses(Kit.rect(join.flyer()))).is_true()
	assert_bool(lineup.is_owned(index)).is_false()
	assert_str(screen.figurines_text()).is_equal("2/30")
	join.seek(ToyLineupJoin.TO_S + ToyLineupJoin.TICK_S)
	assert_bool(join.flyer().visible).is_false()
	assert_bool(lineup.is_owned(index)).is_true()
	assert_str(screen.figurines_text()).is_equal("3/30")
	assert_str(bakery.floor_text()).is_equal("5 OF 8 LEFT")
	assert_int(bakery.capsule_count()).is_equal(5)
	assert_str(str(join.current())).is_equal("look")
	var burst: Rect2 = Kit.rect(join.new_burst())
	assert_bool(join.new_burst().visible).is_true()
	assert_bool(Kit.SCREEN_RECT.encloses(burst)).is_true()
	assert_float(burst.get_center().y).is_greater(Kit.rect(lineup.minis()[index]).get_center().y)
	assert_bool(Kit.SCREEN_RECT.encloses(lineup.strip_rect())).is_true()
	join.tap()  # Ends the look.
	assert_str(str(join.current())).is_equal("away")
	join.seek(10.0)
	assert_bool(join.is_active()).is_false()
	assert_bool(lineup.visible).is_false()
	assert_bool(screen.board().visible).is_true()
	assert_int(lineup.z_index).is_equal(0)
	assert_bool(screen.reveal().visible).is_false()


## Not hovered: the card drops in from above its place.
func test_the_lineup_card_drops_in_when_not_hovered() -> void:
	var profile: ProfileState = Kit.profile(2, 2)
	var screen: ToyMachinesScreen = await _open(profile)
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	await _frames(2)
	var lineup: ToyLineup = screen.lineup()
	assert_bool(lineup.visible).is_false()
	await _dismiss(screen)
	assert_bool(lineup.visible).is_true()
	assert_float(lineup.position.y).is_less(lineup.rest_position().y)
	screen.lineup_join().seek(ToyLineupJoin.TO_S)
	assert_float(lineup.position.y).is_equal(lineup.rest_position().y)
	assert_str(lineup.title_line().text()).is_equal("PANTRY LINEUP")


## The capsule that completes Cold cases: the gold band, the COMPLETED! card waiting for OK (not
## before it arms), the plate held at 0 OF 2 LEFT until SOLD OUT.
func test_a_completing_capsule_shows_the_completed_card() -> void:
	var profile: ProfileState = Kit.profile(2, 2, {&"cold_cases": 1})
	var screen: ToyMachinesScreen = await _open(profile)
	var machine: ToyMachineView = _machine(screen, &"cold_cases")
	machine._gui_input(Kit.left_click())
	await _frames(2)
	await _dismiss(screen)
	var join: ToyLineupJoin = screen.lineup_join()
	join.seek(30.0)  # Held at the card.
	assert_bool(join.is_waiting()).is_true()
	assert_bool(screen.lineup().is_collected()).is_true()
	assert_str(screen.lineup().title_line().text()).is_equal("ALL COLLECTED")
	_assert_words_inside(screen.lineup())  # Its two minis make a narrow card.
	assert_str(machine.floor_text()).is_equal("0 OF 2 LEFT")
	assert_bool(machine.part("sold_out").visible).is_false()
	assert_bool(screen.lineup().visible).is_true()
	assert_bool(screen.board().visible).is_false()
	var card: ToyCompletedCard = join.completed_card()
	assert_bool(card.visible).is_true()
	join.tap()  # Not armed yet: nothing.
	assert_bool(join.is_waiting()).is_true()
	await _assert_card_on_screen(card)
	await await_millis(ResultsPanel.ARM_MS + 100)
	await _frames(2)
	assert_bool(card.is_armed()).is_true()
	join.tap()
	assert_bool(join.is_waiting()).is_false()
	join.seek(join.time() + ToyLineupJoin.CARD_OUT_S + 0.01)
	assert_str(str(join.current())).is_equal("sold")
	assert_int(machine.state()).is_equal(CapsuleCounter.State.EMPTY)
	assert_str(machine.floor_text()).is_equal("SOLD OUT")
	assert_bool(screen.board().visible).is_true()  # The card has left: the board is back.
	assert_bool(screen.lineup().visible).is_false()
	join.seek(30.0)
	assert_bool(join.is_active()).is_false()
	assert_bool(machine.part("sold_out").visible).is_true()
	assert_float(machine.part("sold_out").rotation).is_equal(0.0)


## Every aisle's lineup card is wide enough for its LINEUP title and for ALL COLLECTED (a two-mini
## aisle's title can be narrower than ALL COLLECTED: round 3's DAIRY LINEUP was).
func test_every_lineup_card_fits_all_collected() -> void:
	var stage: Control = auto_free(Control.new())
	stage.size = Kit.SCREEN_RECT.size
	add_child(stage)
	for aisle: AisleDefinition in Kit.balance().aisles:
		var lineup: ToyLineup = ToyLineup.new()
		stage.add_child(lineup)
		lineup.show_aisle(aisle, {}, 200)
		_assert_words_inside(lineup)
		lineup.set_collected(true)
		assert_str(lineup.title_line().text()).is_equal("ALL COLLECTED")
		_assert_words_inside(lineup)
		lineup.free()


## The last capsule of all: COLLECTION COMPLETE waits for the end.
func test_the_last_capsule_opens_collection_complete_at_the_end() -> void:
	var counts: Dictionary = Kit.full_counts()
	counts[&"pantry"] = int(counts[&"pantry"]) - 1
	var profile: ProfileState = Kit.profile(2, 2, counts)
	var screen: ToyMachinesScreen = await _open(profile)
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	await _frames(2)
	assert_int(screen.strip_kind()).is_not_equal(ToyMachinesScreen.Strip.COMPLETE)
	await _dismiss(screen)
	var join: ToyLineupJoin = screen.lineup_join()
	join.seek(30.0)
	assert_int(screen.strip_kind()).is_not_equal(ToyMachinesScreen.Strip.COMPLETE)
	await _assert_card_on_screen(join.completed_card())
	join.finish()
	assert_int(screen.strip_kind()).is_equal(ToyMachinesScreen.Strip.COMPLETE)
	assert_str(screen.figurines_text()).is_equal("30/30")


## Reduced motion: no flight, no drop; the mini is in colour from the start.
func test_reduced_motion_fades_in_place() -> void:
	var profile: ProfileState = Kit.profile(2, 2)
	profile.set_reduced_motion(true)
	var screen: ToyMachinesScreen = await _open(profile)
	_machine(screen, &"snacks")._gui_input(Kit.left_click())
	await _frames(2)
	await _dismiss(screen)
	var join: ToyLineupJoin = screen.lineup_join()
	var lineup: ToyLineup = screen.lineup()
	assert_bool(join.flyer().visible).is_false()
	assert_float(lineup.position.y).is_equal(lineup.rest_position().y)
	var drawn: CardDefinition = _drawn(profile, &"snacks", 0)
	var index: int = Kit.aisle(Kit.balance(), &"snacks").capsule_cards.find(drawn)
	assert_bool(lineup.is_owned(index)).is_true()
	assert_bool(screen.reveal().visible).is_false()
	join.finish()
	assert_bool(join.is_active()).is_false()


## The stamp slams in during the card's pop: absent and large before STAMP_FROM; at its size
## at the impact, the card jolted JOLT art px down for JOLT_S, then back at rest. Only the stamp,
## the aisle's name and OK are on the card (no rules, pips or stock footer).
func test_the_completed_stamp_slams_onto_the_band() -> void:
	var profile: ProfileState = Kit.profile(2, 2, {&"cold_cases": 1})
	var screen: ToyMachinesScreen = await _open(profile)
	_machine(screen, &"cold_cases")._gui_input(Kit.left_click())
	await _frames(2)
	await _dismiss(screen)
	var join: ToyLineupJoin = screen.lineup_join()
	var card: ToyCompletedCard = join.completed_card()
	var rest: Vector2 = card.position
	var start: float = ToyLineupJoin.TO_S + ToyLineupJoin.TICK_S + ToyLineupJoin.SLAP_S
	var length: float = ToyLineupJoin.CARD_IN_S
	join.seek(start + length * (ToyLineupJoin.STAMP_FROM - 0.05))
	assert_float(card.stamp().modulate.a).is_equal(0.0)
	assert_float(card.stamp().scale.x).is_equal(ToyLineupJoin.STAMP_SIZE)
	# The slam: opaque at once, and only at whole canvas px per art px (2x, 1.5x, 1x: 4, 3, 2 px).
	var scales: Array[float] = []
	var slam_from: float = start + length * ToyLineupJoin.STAMP_FROM
	for step: int in 12:
		join.seek(slam_from + length * ToyLineupJoin.STAMP_SHARE * (step + 0.5) / 12.0)
		var shown: float = card.stamp().scale.x
		(
			assert_bool(ToyLineupJoin.STAMP_STEPS.has(shown))
			. override_failure_message(str(shown))
			. is_true()
		)
		assert_float(card.stamp().modulate.a).is_equal(1.0)
		if not scales.has(shown):
			scales.append(shown)
	assert_array(scales).contains([2.0, 1.5])
	assert_float(join.shade().color.a).is_equal_approx(ToyLineupJoin.CARD_SHADE_ALPHA, 0.01)
	var impact: float = start + length * (ToyLineupJoin.STAMP_FROM + ToyLineupJoin.STAMP_SHARE)
	join.seek(impact + ToyLineupJoin.JOLT_S / 2.0)
	assert_float(card.stamp().scale.x).is_equal(1.0)
	assert_float(card.stamp().modulate.a).is_equal(1.0)
	var jolt: float = ToyLineupJoin.JOLT * ArtStyle.ART_SCALE
	assert_vector(card.position).is_equal(rest + Vector2(0, jolt))
	join.seek(start + length)
	assert_bool(join.is_waiting()).is_true()
	assert_vector(card.position).is_equal(rest)
	var words: Array[String] = []
	for line: Node in card.find_children("*", "PixelLine", true, false):
		words.append((line as PixelLine).text())
	words.sort()
	var expected: Array[String] = ["COLD CASES", ToyCompletedCard.STAMP_TEXT]
	expected.sort()
	assert_array(words).is_equal(expected)
	var labels: Array[String] = []
	for label: Label in Kit.labels(card):
		if label.get_parent() is PixelLine:
			continue
		labels.append(label.text)
	assert_array(labels).is_equal([ToyCompletedCard.OK_TEXT])
	join.finish()


## The card inside the screen: its band, stamp and OK inside the frame; the stamp centred on the
## band and stamped on the name: it crosses the name's lower part (its top below the name's
## middle, above the name's foot), the name's top half clear; OK under the stamp, clear of it;
## the card centred on the stage, the stage dimmed behind it.
func _assert_card_on_screen(card: ToyCompletedCard) -> void:
	await _frames(2)
	var frame: Rect2 = Kit.rect(card.frame())
	assert_bool(Kit.SCREEN_RECT.encloses(frame)).override_failure_message(str(frame)).is_true()
	assert_float(frame.get_center().x).is_equal_approx(Kit.SCREEN_RECT.get_center().x, 1.0)
	var band: Rect2 = Kit.rect(card.band())
	var stamp: Rect2 = Kit.rect(card.stamp())
	var ok: Rect2 = Kit.rect(card.ok_button())
	for rect: Rect2 in [band, stamp, ok]:
		assert_bool(frame.encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_bool(stamp.intersects(band)).is_true()
	assert_float(stamp.position.y).is_greater(band.position.y + band.size.y / 2.0)
	assert_float(stamp.end.y).is_greater(band.end.y)
	assert_float(stamp.get_center().x).is_equal_approx(band.get_center().x, 2.0)
	assert_bool(stamp.intersects(ok)).is_false()
	assert_float(ok.position.y).is_greater(stamp.end.y)
	var row: Control = card.band().get_child(0) as Control
	for piece: Node in row.get_children():
		var piece_rect: Rect2 = Kit.rect(piece as Control)
		assert_bool(band.encloses(piece_rect)).override_failure_message(str(piece_rect)).is_true()
	var name_line: PixelLine = row.get_child(1).get_child(0) as PixelLine
	var name_rect: Rect2 = Rect2(
		name_line.global_position, Vector2(name_line.width(), name_line.size.y)
	)
	assert_bool(stamp.intersects(name_rect)).override_failure_message(str(name_rect)).is_true()
	assert_float(stamp.position.y).is_greater(name_rect.get_center().y)
	assert_float(stamp.position.y).is_less(name_rect.end.y)
	assert_vector(stamp.position.posmodv(Vector2(2, 2))).is_equal(Vector2.ZERO)


## Ends the reveal's hold (ToyReveal.HOLD_S) at once: the join starts.
## The lineup's words lie inside its card's face, TEXT_AT's margin clear of its right edge.
func _assert_words_inside(lineup: ToyLineup) -> void:
	var face: Rect2 = Rect2(lineup.global_position, lineup.size)
	var words: PixelLine = lineup.title_line()
	var right: float = words.global_position.x + words.width()
	var margin: float = ToyLineup.TEXT_AT.x * ArtStyle.ART_SCALE
	(
		assert_float(right)
		. override_failure_message(
			(
				"%s: %s ends at %s, the card at %s"
				% [lineup.shown_aisle().id, words.text(), right, face.end.x]
			)
		)
		. is_less_equal(face.end.x - margin)
	)
	assert_bool(face.has_point(words.global_position)).is_true()


func _dismiss(screen: ToyMachinesScreen) -> void:
	await _frames(1)
	screen.reveal().finish_hold()


## The capsule item of `aisle_id` drawn after its first `owned` items.
func _drawn(profile: ProfileState, aisle_id: StringName, owned: int) -> CardDefinition:
	var cards: Array[CardDefinition] = Kit.aisle(Kit.balance(), aisle_id).capsule_cards
	for card: CardDefinition in cards.slice(owned):
		if profile.unlocked_items.has(card.id):
			return card
	return null


func _machine(screen: ToyMachinesScreen, id: StringName) -> ToyMachineView:
	for machine: ToyMachineView in screen.machines():
		if machine.aisle().id == id:
			return machine
	return null


func _open(profile: ProfileState) -> ToyMachinesScreen:
	var counter: CapsuleCounter = CapsuleCounter.new(
		profile, SaveService.new(_folder), Kit.balance(), Kit.event_log(), false, true
	)
	var screen: ToyMachinesScreen = ToyMachinesScreen.new()
	add_child(screen)
	auto_free(screen)
	screen.open(counter, Kit.balance())
	await _frames(3)
	return screen


func _frames(count: int) -> void:
	for frame: int in range(count):
		await await_idle_frame()
