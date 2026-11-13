extends GdUnitTestSuite
## The boot loader (2026-11-13, mock-up loading_screen.html, look A): the game's main scene,
## shown first by the engine's boot splash (its frame at 0%, on the title's sky, crisp, with the
## clear colour the same sky); it loads the title on a thread while its receipt prints, makes the
## title held still under the shutters (the title's first frame), rolls them up, then hands over
## to that same title as the current scene. Reduced motion hands over at once. It names no
## class_name type, so loading it compiles nothing of the game. The web build's shell keeps
## Godot's placeholders and is the Web preset's.

const LOADER := "res://ui/boot/boot_loader.tscn"
const LOADER_SCRIPT := "res://ui/boot/boot_loader.gd"
const SKY := Color("172c2b")
const SHELL := "res://export/web_shell.html"
## Every placeholder of Godot 4.7's default web shell.
const PLACEHOLDERS: Array[String] = [
	"$GODOT_PROJECT_NAME",
	"$GODOT_HEAD_INCLUDE",
	"$GODOT_SPLASH_CLASSES",
	"$GODOT_SPLASH",
	"$GODOT_URL",
	"$GODOT_CONFIG",
	"$GODOT_THREADS_ENABLED",
]
## Seconds a load and hand-off may take before a test gives up.
const PATIENCE := 20.0

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_boot_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_folder)
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The boot splash is the loader's first frame on the title's sky, and nothing grey shows.
func test_the_boot_splash_and_the_clear_colour_are_the_title_sky() -> void:
	assert_str(ProjectSettings.get_setting("application/run/main_scene")).is_equal(LOADER)
	assert_str(ProjectSettings.get_setting("application/boot_splash/image")).is_equal(
		"res://art/boot/boot_frame.png"
	)
	assert_bool(ProjectSettings.get_setting("application/boot_splash/show_image")).is_true()
	assert_bool(ProjectSettings.get_setting("application/boot_splash/use_filter")).is_false()
	(
		assert_int(ProjectSettings.get_setting("application/boot_splash/minimum_display_time"))
		. is_equal(0)
	)
	var splash: Color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	var clear: Color = ProjectSettings.get_setting(
		"rendering/environment/defaults/default_clear_color"
	)
	assert_str(splash.to_html(false)).is_equal(SKY.to_html(false))
	assert_str(clear.to_html(false)).is_equal(SKY.to_html(false))
	var frame: Texture2D = load("res://art/boot/boot_frame.png")
	assert_vector(frame.get_size()).is_equal(Vector2(1280, 720))


## The loader names no class_name type: each one would compile part of the game before its
## first frame, behind the boot splash.
func test_the_loader_names_no_class() -> void:
	var words: Dictionary[String, bool] = {}
	var regex: RegEx = RegEx.create_from_string("[A-Za-z_][A-Za-z0-9_]*")
	for line: String in FileAccess.get_file_as_string(LOADER_SCRIPT).split(String.chr(10)):
		# The code only: the comments may name the classes it stands in for.
		for found: RegExMatch in regex.search_all(line.get_slice("#", 0)):
			words[found.get_string()] = true
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		var name_found: String = entry["class"]
		assert_bool(words.has(name_found)).override_failure_message(name_found).is_false()


## Left alone, the receipt prints to TOTAL 100%, the title is made held still under the shut
## shutters, they roll up (the doors first), and the title runs as the loader's child (tests keep
## the scene).
func test_the_loader_prints_then_hands_over_to_the_title() -> void:
	var loader: Control = _loader()
	var made: Array[Node] = []
	loader.connect(
		"title_made",
		func(made_title: Node) -> void:
			made.append(made_title)
			assert_int(made_title.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
			assert_float(loader.call("shutter_closed", 1)).is_equal(1.0)
			assert_float(loader.call("printed")).is_equal(1.0)
			# The corners stay hidden under the shutters, as in the boot frame.
			assert_bool((made_title as TitleScreen).export_button().visible).is_false()
			assert_bool((made_title as TitleScreen).build_label().visible).is_false()
	)
	assert_bool(await _until(loader, "is_handed_off")).is_true()
	assert_int(made.size()).is_equal(1)
	var title: TitleScreen = loader.call("title") as TitleScreen
	assert_object(title).is_not_null()
	assert_object(title).is_same(made[0])
	assert_object(title.get_parent()).is_same(loader)
	assert_int(title.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)
	assert_bool(title.export_button().visible).is_true()
	assert_bool(title.build_label().visible).is_true()
	for i: int in 4:
		assert_float(loader.call("shutter_closed", i)).is_equal(0.0)
	# The title's own opening starts from its first frame: the sign still dark.
	assert_bool(title.storefront().is_lit()).is_false()
	assert_bool(title.is_intro_playing()).is_true()


## The finished receipt: every stage OK, then TOTAL 100% and THANK YOU!; mid-print a live STOCK.
func test_the_receipt_lines() -> void:
	var loader: Control = _loader(false)
	loader.call("show_state", 0.5)
	var half: Array = _texts(loader)
	assert_array(half).contains(["LIGHTS", "BANANAS", "STOCK"])
	assert_array(half).not_contains(["TOTAL"])
	var lines: Array = loader.call("receipt_lines")
	var stock: Array = lines.back()
	assert_str(stock[1]).is_equal("50%")
	assert_float(lines[3][3]).is_equal(1.0)
	assert_float(lines[3 + 7][3]).is_equal(0.0)
	loader.call("show_state", 1.0)
	assert_array(_texts(loader)).contains(["TILL", "TOTAL", "THANK YOU!"])
	assert_array(_texts(loader)).not_contains(["STOCK"])


## The doors' shutter rolls first, the bay's last, each easing over ROLL_TIME.
func test_the_shutters_roll_up_door_first() -> void:
	var loader: Control = _loader(false)
	loader.call("show_state", 1.0, 0.3)
	var doors: float = loader.call("shutter_closed", 1)
	var bay: float = loader.call("shutter_closed", 3)
	assert_float(doors).is_less(1.0)
	assert_float(bay).is_equal(1.0)
	var roll: float = loader.call("roll_time")
	loader.call("show_state", 1.0, roll)
	for i: int in 4:
		assert_float(loader.call("shutter_closed", i)).is_equal(0.0)


## The slot's light holds steady on the finished receipt and goes dark while the shutters roll.
func test_the_slot_light_is_off_while_the_shutters_roll() -> void:
	var loader: Control = _loader(false)
	loader.call("show_state", 1.0)
	assert_bool(loader.call("_led_on")).is_true()
	loader.call("show_state", 1.0, 0.3)
	assert_bool(loader.call("_led_on")).is_false()


## Reduced motion: the title is handed over the moment it is made (no hold, no roll).
func test_reduced_motion_cuts_straight_to_the_title() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.set_reduced_motion(true)
	assert_bool(SaveService.new(_folder).save_profile(profile)).is_true()
	var loader: Control = _loader()
	var frames: Array[int] = []
	loader.connect("title_made", func(_title: Node) -> void: frames.append(_frame()))
	var handed: Array[Node] = []
	loader.connect(
		"handed_off",
		func(handed_title: Node) -> void:
			handed.append(handed_title)
			frames.append(_frame())
	)
	assert_bool(await _until(loader, "is_handed_off")).is_true()
	assert_int(handed.size()).is_equal(1)
	var title: TitleScreen = handed[0] as TitleScreen
	assert_bool(title.reduced_motion()).is_true()
	assert_bool(title.storefront().is_lit()).is_true()
	# Handed over on the frame that made it: no hold, no shutter roll.
	assert_int(frames.size()).is_equal(2)
	assert_int(frames[1]).is_equal(frames[0])
	assert_int(title.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)


## The real hand-off: the title made under the loader becomes the current scene, at the root,
## and the loader leaves (the test's own scene is put back after).
func test_the_title_becomes_the_current_scene() -> void:
	var tree: SceneTree = get_tree()
	var previous: Node = tree.current_scene
	var loader: Control = (load(LOADER) as PackedScene).instantiate()
	add_child(loader)
	var handed: Array[Node] = []
	loader.connect("handed_off", func(handed_title: Node) -> void: handed.append(handed_title))
	var waited: float = 0.0
	while handed.is_empty() and waited < PATIENCE:
		await tree.process_frame
		waited += get_process_delta_time()
	assert_int(handed.size()).is_equal(1)
	var title: Node = handed[0]
	var current: Node = tree.current_scene
	tree.current_scene = previous
	assert_object(current).is_same(title)
	assert_object(title.get_parent()).is_same(tree.root)
	assert_bool(not is_instance_valid(loader) or loader.is_queued_for_deletion()).is_true()
	(title as TitleScreen).changes_scene = false
	tree.root.remove_child(title)
	title.free()


## The web shell: the Web preset's, Godot's placeholders kept, its receipt data filled in.
func test_the_web_shell_keeps_the_placeholders() -> void:
	var presets: ConfigFile = ConfigFile.new()
	assert_int(presets.load("res://export_presets.cfg")).is_equal(OK)
	assert_str(presets.get_value("preset.0", "platform")).is_equal("Web")
	assert_str(presets.get_value("preset.0.options", "html/custom_html_shell")).is_equal(SHELL)
	var shell: String = FileAccess.get_file_as_string(SHELL)
	for placeholder: String in PLACEHOLDERS:
		assert_bool(shell.contains(placeholder)).override_failure_message(placeholder).is_true()
	assert_bool(shell.contains(CaptureWebShell.PLACEHOLDER)).is_false()
	assert_bool(shell.contains("window.ncBootDone")).is_true()
	assert_bool(shell.contains("#172c2b")).is_true()


## A loader in the test's tree (loading the title unless `loads` is false); it never replaces
## the test runner's scene.
func _loader(loads: bool = true) -> Control:
	var loader: Control = (load(LOADER) as PackedScene).instantiate()
	loader.set("changes_scene", false)
	loader.set("auto_load", loads)
	add_child(loader)
	auto_free(loader)
	if not loads:
		loader.set_process(false)
	return loader


## Waits until `loader`'s `query` is true, PATIENCE seconds at most.
func _until(loader: Control, query: String) -> bool:
	var waited: float = 0.0
	while not bool(loader.call(query)) and waited < PATIENCE:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return bool(loader.call(query))


static func _frame() -> int:
	return Engine.get_process_frames()


static func _texts(loader: Control) -> Array:
	var texts: Array = []
	for line: Array in loader.call("receipt_lines"):
		if line[0] != "":
			texts.append(line[0])
	return texts


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
