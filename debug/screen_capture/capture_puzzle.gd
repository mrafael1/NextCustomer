extends SceneTree
## The puzzle shifts' captures (#183, full build plan section 7.6): the title's puzzle planner
## (at rest and hot), the puzzle board (mid-shine when the first pack is complete) and a puzzle
## shift in planning, with its row placed and after its count (the verdict and its keys). Saves
## and logs go to a temporary folder, deleted on exit. Run as
## `godot --path . --resolution 1280x720 -s res://debug/screen_capture/capture_puzzle.gd --
## --capture=<folder> [--puzzle=<id>] [--solved=<n>] [--miss|--over] [--past]` (`--solved`:
## how many of the first pack's puzzles the profile has solved, 5 by default, 8 for a completed
## pack; `--miss` checks out the solution less its last item: a SHORT verdict; `--over` the
## solution with one item left in the hand added or swapped in, the first move that scores over
## the target: OVER; `--past` also grabs puzzle_past.png PAST_SECONDS after the count's total
## first passes the target).
## Files: puzzle_title.png, puzzle_title_hot.png, puzzle_board_shine.png (a complete first pack
## only), puzzle_board.png, puzzle_plan.png, puzzle_placed.png, puzzle_count.png (mid-count),
## puzzle_celebrate.png, puzzle_gold_turn.png, puzzle_verdict.png.

const TITLE := "res://ui/title_screen.tscn"
const SHIFT := "res://ui/shift_screen.tscn"
const CATALOGUE := "res://data/catalogue/catalogue.tres"
const SETTLE_FRAMES := 8
const COUNT_FRAMES := 4000
## The frame of the count grabbed as puzzle_count.png (the exact gauge filling).
const COUNT_GRAB_FRAME := 200
## Seconds after the verdict before puzzle_verdict.png (the gauge back down, the stamp settled,
## the verdict keys landed: frames run faster than real time here, so the waits are timed).
const VERDICT_SECONDS := 1.6
## Seconds after the verdict before puzzle_celebrate.png (an EXACT stamp just landed: its
## confetti and the notch's flash) and puzzle_gold_turn.png (a pack's completing solve: the
## overlay mid-way to gold; #183 polish 5).
const CELEBRATE_SECONDS := 0.28
const GOLD_SECONDS := 0.75
## Frames after placing the row before puzzle_placed.png (the receipt's roll and the gauge's pour
## settled: ReceiptRoll.MAX_SECONDS and more).
const PLACED_FRAMES := 60
## Seconds after the board opens before puzzle_board_shine.png (the light mid-sweep), then before
## puzzle_board.png (the sweep over).
const SHINE_SECONDS := 0.62
const BOARD_SECONDS := 1.2
## Seconds after the count's total first passes the target before puzzle_past.png (`--past`).
const PAST_SECONDS := 0.6

var _folder: String = ""
var _saves: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var puzzle_id: StringName = &"op_breakfast_for_one"
	var miss: bool = false
	var over: bool = false
	var past: bool = false
	var solved: int = 5
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_folder = argument.trim_prefix("--capture=")
		elif argument.begins_with("--puzzle="):
			puzzle_id = StringName(argument.trim_prefix("--puzzle="))
		elif argument.begins_with("--solved="):
			solved = int(argument.trim_prefix("--solved="))
		elif argument == "--miss":
			miss = true
		elif argument == "--over":
			over = true
		elif argument == "--past":
			past = true
	DirAccess.make_dir_recursive_absolute(_folder)
	_saves = "user://capture_puzzle_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_saves)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _saves)
	(root.get_node("/root/EventLog") as EventLogService).use_folder(_saves)
	var profile: ProfileState = ProfileState.new()
	profile.run_count = 1
	var list: PuzzleList = PuzzlePlay.list()
	for puzzle: PuzzleDefinition in list.pack(1).slice(0, solved):
		profile.solved_puzzles.append(puzzle.id)
	var catalogue: CatalogueDefinition = load(CATALOGUE)
	for pin: PinDefinition in catalogue.pins:  # A complete pack's pin is earned, as in play.
		if ProfilePuzzles.is_met(pin.unlock_condition, profile, list):
			profile.unlocked_pins.append(pin.id)
	SaveService.new(_saves).save_profile(profile)
	var title: TitleScreen = (load(TITLE) as PackedScene).instantiate()
	title.changes_scene = false
	root.add_child(title)
	title.skip_intro()
	await _settle()
	_grab("puzzle_title")
	title.menu().mark(TitleMenu.Entry.PUZZLES)
	await _settle()
	_grab("puzzle_title_hot")
	title.menu().unmark(TitleMenu.Entry.PUZZLES)
	var complete: bool = list.is_complete(1, profile.solved_puzzles)
	if complete:
		PuzzlePlay.note_completed(1)
	title.open_puzzles()
	await create_timer(SHINE_SECONDS).timeout
	if complete:
		_grab("puzzle_board_shine")
	await create_timer(BOARD_SECONDS).timeout
	_grab("puzzle_board")
	title.queue_free()
	await process_frame
	PuzzlePlay.request(puzzle_id)
	var screen: ShiftScreen = (load(SHIFT) as PackedScene).instantiate()
	screen.changes_scene = false
	root.add_child(screen)
	await _settle()
	_grab("puzzle_plan")
	var puzzle: PuzzleDefinition = list.find(puzzle_id)
	var ids: PackedStringArray = puzzle.solution
	if miss:
		ids = ids.slice(0, ids.size() - 1)
	for card: CardInstance in PuzzleRun.row_of(screen.run, ids):
		screen.run.place(card, screen.run.row.size())
	if over:
		_swap_over(screen.run, puzzle.target)
	screen._refresh()
	for frame: int in PLACED_FRAMES:
		await process_frame
	_grab("puzzle_placed")
	screen._on_checkout_pressed()
	for frame: int in COUNT_FRAMES:
		await process_frame
		if frame == COUNT_GRAB_FRAME:
			_grab("puzzle_count")
		if past and screen._count_up._shown_subtotal > puzzle.target:
			past = false
			await create_timer(PAST_SECONDS).timeout
			_grab("puzzle_past")
		if screen.puzzle_flow.last_verdict >= 0:
			break
	await create_timer(CELEBRATE_SECONDS).timeout  # The stamp just landed: confetti, the notch.
	_grab("puzzle_celebrate")
	await create_timer(GOLD_SECONDS - CELEBRATE_SECONDS).timeout  # A completing solve's gold turn.
	_grab("puzzle_gold_turn")
	await create_timer(VERDICT_SECONDS - GOLD_SECONDS).timeout  # The gauge back down, the keys landed.
	_grab("puzzle_verdict")
	screen.queue_free()
	await process_frame
	for file_name: String in DirAccess.get_files_at(_saves):
		DirAccess.remove_absolute(_saves.path_join(file_name))
	DirAccess.remove_absolute(_saves)
	quit()


## One item left in the hand added at the belt's end, else swapped for a belt item: the first
## move that scores over `target`.
func _swap_over(run: RunState, target: int) -> void:
	for spare: CardInstance in run.deck.hand():
		if not run.row.has(spare) and run.place(spare, run.row.size()):
			if run.preview().total > target:
				return
			run.remove(spare)
	for slot: int in run.row.size():
		for spare: CardInstance in run.deck.hand():
			if run.row.has(spare):
				continue
			var out: CardInstance = run.row[slot]
			run.remove(out)
			run.place(spare, slot)
			if run.preview().total > target:
				return
			run.remove(spare)
			run.place(out, slot)


func _settle() -> void:
	for frame: int in SETTLE_FRAMES:
		await process_frame


func _grab(file_name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(_folder.path_join(file_name + ".png"))
	print("captured ", file_name)
