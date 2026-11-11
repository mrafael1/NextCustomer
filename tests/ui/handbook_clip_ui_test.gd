extends GdUnitTestSuite
## The handbook's example clips show the shift's own effects (the guide polish, 2026-11-11):
## WASTED's grey WASTED stickers and its tomato wrong-job chips (only once the effects slap on, on
## every loop) and CHAIN's chain frames (a Price gun relabel and a quota on test-made pages:
## handbook_example_clip_ui_test). A playing clip stopped at any point of its count shows the
## still clip's state. The clips' tweens are stepped by hand (paused, custom_step), so the timing
## does not hang on the frame rate. The real saves and logs are never touched.

const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## The step the clips' tweens are driven by, and the most steps any wait takes.
const STEP := 0.05
const MAX_STEPS := 400

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## WASTED's clip wears the grey WASTED stickers and the tomato wrong-job chips.
func test_wasted_shows_its_wasted_stickers_and_chips() -> void:
	var clip: HandbookClip = await _clip(&"wasted", true)
	var wasted: int = 0
	for slot: int in range(clip.items().size()):
		for sticker: EffectSticker in clip.planning_layer().stack(slot):
			if sticker.spec().kind == StickerSpec.Kind.FIZZLE:
				wasted += 1
	assert_int(wasted).is_greater(0)
	assert_int(_wrong_jobs(clip)).is_greater(0)


## CHAIN's clip shows the chain frames (not the batch frames).
func test_chain_shows_its_chain_frames() -> void:
	var clip: HandbookClip = await _clip(&"chain", true)
	assert_bool(clip.planning_layer().frames(true).is_empty()).is_false()


## WASTED's tickets ride in plain on the first loop and on the next: the chips turn tomato only
## once the effects slap on.
func test_the_ride_in_is_plain_on_every_loop() -> void:
	var clip: HandbookClip = await _clip(&"wasted", false)
	for loop: int in range(2):
		assert_int(_wrong_jobs(clip)).override_failure_message("loop %d" % loop).is_equal(0)
		await _step_until(clip, func() -> bool: return clip._planned)
		assert_int(_wrong_jobs(clip)).override_failure_message("loop %d" % loop).is_greater(0)
		await _step_until(clip, func() -> bool: return not clip.planning_layer().visible)
		await _frames(2)


## A playing clip stopped as its count starts, a few steps in and late in it shows the still
## clip's state: every ticket's pay, the items' halos and greys, the stickers, the frames, the LED
## and the receipt.
func test_stopping_mid_count_shows_the_still_state() -> void:
	var book: HandbookBook = HandbookBook.shared()
	for entry: HandbookEntry in book.entries:
		if not entry.has_example():
			continue
		var still: HandbookClip = await _clip(entry.id, true)
		var expected: String = _state(still)
		for extra: int in [0, 3, 12]:
			var clip: HandbookClip = await _clip(entry.id, false)
			await _step_until(
				clip, func() -> bool: return not clip._planned and clip.planning_layer().visible
			)
			for _step: int in range(extra):
				_advance(clip)
			await _frames(1)
			clip.stop()
			await _frames(2)
			var what: String = "%s +%d" % [entry.id, extra]
			assert_str(_state(clip)).override_failure_message(what).is_equal(expected)
			_close(clip)
		_close(still)


## The clip of entry `id` (in `book`, the game's by default) on a fresh handbook page, `still` or
## playing (its tween paused, to be stepped by hand).
func _clip(id: StringName, still: bool) -> HandbookClip:
	var page: HandbookPage = auto_free(HandbookPage.new())
	page.still = still
	add_child(page)
	page.size = SCREEN_RECT.size
	await _frames(1)
	page.open_at(id)
	await _frames(3)
	var clip: HandbookClip = page.entry_view().clip()
	_advance(clip, 0.0)
	return clip


## Takes the clip's page off (auto_free frees it after the test).
func _close(clip: HandbookClip) -> void:
	var node: Node = clip
	while node != null and not node is HandbookPage:
		node = node.get_parent()
	if node != null:
		remove_child(node)


## Steps the clip's tween (the current loop's) `seconds` on, holding it paused.
func _advance(clip: HandbookClip, seconds: float = STEP) -> void:
	var tween: Tween = clip._tween
	if tween == null or not tween.is_valid():
		return
	tween.pause()
	if seconds > 0.0:
		tween.custom_step(seconds)
	if clip._tween != null and clip._tween != tween and clip._tween.is_valid():
		clip._tween.pause()


func _step_until(clip: HandbookClip, done: Callable) -> void:
	for _step: int in range(MAX_STEPS):
		if bool(done.call()):
			return
		_advance(clip)
		await _frames(1)
	fail("the clip never got there")


## The tickets whose keyword chips show a wrong job.
static func _wrong_jobs(clip: HandbookClip) -> int:
	var count: int = 0
	for ticket: PriceSticker in clip.tickets():
		if not ticket.summary().keyword_wasted().is_empty():
			count += 1
	return count


## What the clip shows, as text.
static func _state(clip: HandbookClip) -> String:
	var parts: PackedStringArray = []
	var layer: PlanningLayer = clip.planning_layer()
	for slot: int in range(clip.items().size()):
		var item: ItemView = clip.items()[slot]
		var window: PriceWindow = item.sticker().window()
		var stickers: PackedStringArray = []
		for sticker: EffectSticker in layer.stack(slot):
			stickers.append(sticker.text())
		(
			parts
			. append(
				(
					"%d pay=%d:%d rings=%d denied=%s x=%.0f wrong=%s stamp=%s [%s]"
					% [
						slot,
						window.pay_state(),
						window.pay_amount(),
						item.boost_rings,
						item.denied,
						item.position.x,
						item.sticker().summary().keyword_wasted(),
						layer.stamp(slot) != null,
						",".join(stickers),
					]
				)
			)
		)
	parts.append("frames=%d chains=%d" % [layer.frames().size(), layer.frames(true).size()])
	parts.append("total=" + clip.total_text())
	if clip.receipt_target() != null:
		parts.append("met=%s" % clip.receipt_target().is_met())
	return "\n".join(parts)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
