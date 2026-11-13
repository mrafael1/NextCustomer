extends Control
## The title's and the boot loader's captures (2026-11-13: the title opening, variant C, and the
## loading screen, look A; captures in docs/art/mockups/title_loading_game/), and the two boot
## images the loader is drawn from (tools/boot_frame.sh). Saves and logs go to a temporary
## folder, deleted on exit; the real pointer drives nothing. Run as
## `godot --path . [--resolution WxH] res://debug/screen_capture/capture_title.tscn -- <mode>`
## (`-- --window=WxH` sets the window's size in pixels on a high-DPI screen):
## - `--base-frame`: the title's first frame (the sign dark, the plates hidden) without its
##   corner icons, on the 1280x720 stage, saved at art size (640x360) to
##   art/boot/title_first_frame.png; a 2x2 block that isn't one colour is reported.
## - `--boot-frame`: the loader at 0% (the boot splash), saved to art/boot/boot_frame.png.
## - `--web-shell`: export/web_shell.html from its template and the loader's pixels
##   (CaptureWebShell).
## - `--capture=<folder> --title=<seconds>`: the title's opening frozen at that time,
##   title_opening_<tenths>_<w>x<h>.png; `--title=lit` the opening skipped (the menu in place),
##   title_lit_<w>x<h>.png.
## - `--capture=<folder> --loader=<percent>[,roll=<seconds>]`: the loader at that share printed
##   (100: TOTAL and THANK YOU!) and that far into the shutters' roll, the title's first frame
##   made under them when rolling, boot_loader_<percent>[_roll<tenths>]_<w>x<h>.png.

const TITLE := preload("res://ui/title_screen.tscn")
const LOADER_PATH := "res://ui/boot/boot_loader.tscn"
const BASE_PATH := "res://art/boot/title_first_frame.png"
const BOOT_PATH := "res://art/boot/boot_frame.png"
const STEP := 1.0 / 60.0
## Frames to wait before grabbing, so the layout and the draw calls have settled.
const SETTLE_FRAMES := 4

var _folder: String = ""
## Where the captured scenes go: this control, or a SubViewport's control (--window=).
var _host: Control = self


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_folder = OS.get_temp_dir().path_join("next_customer_title_capture_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)
	get_viewport().gui_disable_input = true
	# `--window=WxH`: the captures render at WxH in a SubViewport whatever the screen's scale
	# (--resolution is scaled up on a high-DPI screen), its 2D stretched from 1280 px wide as the
	# window's canvas_items stretch does.
	var window_spec: String = _argument("--window=")
	if window_spec != "":
		var parts: PackedStringArray = window_spec.split("x")
		var pixels := Vector2i(parts[0].to_int(), parts[1].to_int())
		var viewport: SubViewport = SubViewport.new()
		viewport.size = pixels
		viewport.size_2d_override = Vector2i(1280, roundi(1280.0 * pixels.y / pixels.x))
		viewport.size_2d_override_stretch = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		_host = Control.new()
		_host.size = viewport.size_2d_override
		viewport.add_child(_host)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--base-frame"):
		await _base_frame()
	elif args.has("--web-shell"):
		await CaptureWebShell.build(self, _loader(1.0, 0.0))
	elif args.has("--boot-frame"):
		_loader(0.0, 0.0)
		await _save(ProjectSettings.globalize_path(BOOT_PATH))
	else:
		var folder: String = _argument("--capture=")
		var title_spec: String = _argument("--title=")
		var loader_spec: String = _argument("--loader=")
		var window: Vector2i = _host.get_viewport().get_texture().get_size()
		var size_part: String = "%dx%d" % [window.x, window.y]
		if title_spec != "":
			var file: String = _title(title_spec)
			await _save(folder.path_join("%s_%s.png" % [file, size_part]))
		elif loader_spec != "":
			var parts: PackedStringArray = loader_spec.split(",")
			var rolled: float = 0.0
			var file: String = "boot_loader_%s" % parts[0]
			if parts.size() > 1 and parts[1].begins_with("roll="):
				rolled = parts[1].trim_prefix("roll=").to_float()
				file += "_roll%d" % roundi(rolled * 10.0)
			_loader(parts[0].to_float() / 100.0, rolled)
			await _save(folder.path_join("%s_%s.png" % [file, size_part]))
	get_tree().quit()


func _exit_tree() -> void:
	get_viewport().gui_disable_input = false
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	_remove_folder(_folder)


## The title, held still, its opening driven by hand to `spec` seconds (or "lit": skipped).
func _title(spec: String) -> String:
	var title: TitleScreen = _held_title()
	if spec == "lit":
		title.skip_intro()
		return "title_lit"
	var seconds: float = spec.to_float()
	var front: Storefront = title.storefront()
	var steps: int = roundi(seconds / STEP)
	for _step: int in steps:
		title._process(STEP)
		front._process(STEP)
		front.neon_sign()._process(STEP)
	return "title_opening_%02d" % roundi(seconds * 10.0)


## The title made and held still (its own clock stopped) on a fresh profile.
func _held_title() -> TitleScreen:
	var title: TitleScreen = TITLE.instantiate()
	title.changes_scene = false
	title.process_mode = Node.PROCESS_MODE_DISABLED
	_host.add_child(title)
	return title


## The title's first frame without its corner icons, saved at art size.
func _base_frame() -> void:
	var title: TitleScreen = _held_title()
	title.export_button().hide()
	title.build_label().hide()
	for _frame: int in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _host.get_viewport().get_texture().get_image()
	if image.get_size() != Vector2i(1280, 720):
		push_error("--base-frame needs a 1280x720 window, not %s" % image.get_size())
		return
	var art: Image = Image.create(640, 360, false, Image.FORMAT_RGB8)
	var mixed: int = 0
	for y: int in 360:
		for x: int in 640:
			var colour: Color = image.get_pixel(x * 2, y * 2)
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				if not image.get_pixel(x * 2 + offset.x, y * 2 + offset.y).is_equal_approx(colour):
					mixed += 1
					break
			art.set_pixel(x, y, colour)
	if mixed > 0:
		push_warning("%d 2x2 blocks of the title's first frame are not one colour" % mixed)
	var error: Error = art.save_png(ProjectSettings.globalize_path(BASE_PATH))
	if error != OK:
		push_error("Can't save %s (error %d)" % [BASE_PATH, error])


## The loader, not loading, drawn at `share` printed and `rolled` seconds into the roll (the
## title's first frame made under the shutters when rolling).
func _loader(share: float, rolled: float) -> Control:
	var loader: Control = (load(LOADER_PATH) as PackedScene).instantiate()
	loader.set("auto_load", false)
	loader.set("changes_scene", false)
	_host.add_child(loader)
	loader.set_process(false)
	if rolled > 0.0:
		var title: TitleScreen = TITLE.instantiate()
		title.changes_scene = false
		title.process_mode = Node.PROCESS_MODE_DISABLED
		loader.add_child(title)
		loader.move_child(title, 0)
	loader.call("show_state", share, rolled)
	return loader


func _save(path: String) -> void:
	for _frame: int in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _host.get_viewport().get_texture().get_image()
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Can't save %s (error %d)" % [path, error])
	else:
		print("Saved %s" % path)


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


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
