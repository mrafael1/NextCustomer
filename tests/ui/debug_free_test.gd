extends GdUnitTestSuite
## The game's screens never reach into debug/ (#75): the exports skip debug/, so a script, scene
## or resource in ui/ or presentation/ that names a res://debug/ path or a debug/ script's class
## would break both builds. The one allowed path is the debug panel, which ShiftDebug loads by
## path only when it exists and the build isn't a playtest one. Comments may mention debug/ code.

const FOLDERS: Array[String] = ["res://ui", "res://presentation"]
const EXTENSIONS: Array[String] = ["gd", "tscn", "tres"]
const DEBUG_PATH := "res://debug/"
## Each allowed mention: the file and the debug/ path it names.
const ALLOWED: Dictionary[String, String] = {
	"res://ui/shift_debug.gd": "res://debug/debug_panel.tscn",
}


func test_no_screen_file_names_a_debug_path() -> void:
	var files: Array[String] = _files()
	assert_int(files.size()).is_greater(40)
	var found: Array[String] = []
	for path: String in files:
		for line: String in _code_lines(path):
			var at: int = line.find(DEBUG_PATH)
			while at >= 0:
				var end: int = line.find('"', at)
				var named: String = line.substr(at, end - at if end > at else -1)
				if ALLOWED.get(path, "") != named:
					found.append("%s: %s" % [path, named])
				at = line.find(DEBUG_PATH, at + 1)
	assert_array(found).override_failure_message("Names debug/: %s" % [found]).is_empty()


func test_no_screen_script_names_a_debug_class() -> void:
	var classes: Array[String] = []
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry["path"]).begins_with(DEBUG_PATH):
			classes.append(String(entry["class"]))
	# No debug/ script declares a class today (style frame v2's went with the mock-up, #75 step
	# 9); the check guards the next one.
	var found: Array[String] = []
	for path: String in _files():
		if path.get_extension() != "gd":
			continue
		var code: String = "\n".join(_code_lines(path))
		for debug_class: String in classes:
			var word: RegEx = RegEx.create_from_string("\\b%s\\b" % debug_class)
			if word.search(code) != null:
				found.append("%s: %s" % [path, debug_class])
	assert_array(found).override_failure_message("Names a debug class: %s" % [found]).is_empty()


## A file's lines without their comments: a whole comment line, or a "#" after a space with no
## quote after it (the names checked never contain a "#").
static func _code_lines(path: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return lines
	var comment: RegEx = RegEx.create_from_string('^\\s*#.*$|\\s+#[^"]*$')
	while not file.eof_reached():
		lines.append(comment.sub(file.get_line(), ""))
	return lines


static func _files() -> Array[String]:
	var files: Array[String] = []
	for folder: String in FOLDERS:
		_collect(folder, files)
	return files


static func _collect(folder: String, files: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(folder):
		if EXTENSIONS.has(file_name.get_extension()):
			files.append(folder.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(sub), files)
