extends Control
## The polish audit's capture (2026-11-13): the screens ScreenCapture doesn't reach, on a
## temporary save folder (deleted on exit). `--audit=<mode>[,<option>...]` and
## `--out=<file.png>`; the capture is saved at the window's size, then the game quits.
## Modes:
## - title: the title screen; `t=<seconds>` waits that long into its intro (real time), else the
##   intro is skipped (the sign lit, the plates in); `saved` writes a run save first (CONTINUE);
##   `open=<options|quit|guide|newrun|toys|book>` opens that over the lit title (`entry=<id>`
##   picks the guide's entry, `turn=<n>` turns the figurine book's pages n times);
## - pause: the fixed shift (ScreenCapture's) with the pause open; `open=<options|guide>` opens
##   that from the pause.
## `wait=<seconds>` waits that much more before the capture; `--release-ui` (its own argument)
## shows the screens as a release build does, without the playtest UI (PlaytestUi).

const TITLE := preload("res://ui/title_screen.tscn")
const SHIFT := preload("res://ui/shift_screen.tscn")
const CAPTURE := preload("res://debug/screen_capture/screen_capture.tscn")
const SEED := 20261014
const SETTLE_FRAMES := 12

var _folder: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if OS.get_cmdline_user_args().has("--release-ui"):
		PlaytestUi.forced = 0
	get_viewport().gui_disable_input = true
	_folder = OS.get_temp_dir().path_join("next_customer_audit_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	var log_service: EventLogService = get_tree().root.get_node("/root/EventLog")
	log_service.use_folder(_folder)
	var spec: PackedStringArray = _argument("--audit=").split(",", false)
	var out: String = _argument("--out=")
	if spec.is_empty() or out == "":
		push_error("capture_audit: --audit= and --out= are needed")
		get_tree().quit()
		return
	var mode: String = spec[0]
	var options: PackedStringArray = spec.slice(1)
	if mode == "title":
		await _title(options)
	elif mode == "pause":
		await _pause(options)
	var extra: float = _option(options, "wait=").to_float()
	if extra > 0.0:
		await get_tree().create_timer(extra, true).timeout
	await _capture(out)
	get_tree().paused = false
	get_tree().quit()


func _exit_tree() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	_remove_folder(_folder)


func _title(options: PackedStringArray) -> void:
	if options.has("saved"):
		var shift: ShiftScreen = SHIFT.instantiate()
		add_child(shift)
		shift.start_new_run(SEED)
		shift.run.debug_skip_to_shift(2)
		shift.debug_show_shift()
		shift._save_run()
		remove_child(shift)
		shift.free()
	var title: TitleScreen = TITLE.instantiate()
	title.changes_scene = false
	add_child(title)
	var at: String = _option(options, "t=")
	if at != "":
		await get_tree().create_timer(at.to_float()).timeout
		return
	title.skip_intro()
	await get_tree().create_timer(0.6).timeout
	var opened: String = _option(options, "open=")
	if opened == "options":
		title._on_options_pressed()
	elif opened == "quit":
		title._on_quit_pressed()
	elif opened == "newrun":
		title._on_new_run_pressed()
	elif opened == "guide":
		title._on_guide_pressed()
		var entry: String = _option(options, "entry=")
		if entry != "":
			title.guide().show_entry(StringName(entry))
	elif opened == "toys" or opened == "book":
		title._on_rewards_pressed()
		await get_tree().create_timer(2.0).timeout
		if opened == "book":
			title.toy_machines()._open_shelf()
			await get_tree().create_timer(1.2).timeout
			var turns: int = _option(options, "turn=").to_int()
			for _turn: int in range(turns):
				title.toy_machines().book().turn(1)
				await get_tree().create_timer(1.2).timeout
	await get_tree().create_timer(1.0).timeout


func _pause(options: PackedStringArray) -> void:
	var capture: Control = CAPTURE.instantiate()
	capture.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(capture)
	await get_tree().create_timer(1.0).timeout
	var screen: ShiftScreen = capture.call("screen")
	screen._pause.open()
	await get_tree().create_timer(1.0).timeout
	var opened: String = _option(options, "open=")
	if opened == "options":
		screen._pause._open_options()
	elif opened == "guide":
		screen._pause._open_guide()
	await get_tree().create_timer(1.0).timeout


func _capture(out: String) -> void:
	for _frame: int in range(SETTLE_FRAMES):
		await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var error: Error = image.save_png(out)
	if error != OK:
		push_error("capture_audit: can't save %s (%d)" % [out, error])


static func _option(options: PackedStringArray, prefix: String) -> String:
	for option: String in options:
		if option.begins_with(prefix):
			return option.trim_prefix(prefix)
	return ""


static func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


static func _remove_folder(folder: String) -> void:
	if folder == "" or not DirAccess.dir_exists_absolute(folder):
		return
	for sub: String in DirAccess.get_directories_at(folder):
		_remove_folder(folder.path_join(sub))
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder)
