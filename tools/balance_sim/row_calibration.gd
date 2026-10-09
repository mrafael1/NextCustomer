extends SceneTree
## Compares the balance simulator's sensible row player with logged players (SimCalibration,
## decided with the user, #41). Run it with tools/row_calibration.sh:
##   --logs=PATH,PATH  exported .jsonl files or folders of them (default the desktop game's
##                     user://playtest_logs)

const DEFAULT_LOGS := "user://playtest_logs"
const BALANCE := "res://data/balance/balance.tres"


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var paths: PackedStringArray = PackedStringArray([DEFAULT_LOGS])
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--logs="):
			push_error("row_calibration: unknown argument %s (see row_calibration.gd)" % argument)
			return 1
		paths = argument.trim_prefix("--logs=").split(",", false)
	var lines: PackedStringArray = PackedStringArray()
	for path: String in paths:
		for file: String in _log_files(path):
			lines.append_array(FileAccess.get_file_as_string(file).split("\n", false))
	var balance: BalanceDefinition = load(BALANCE)
	var calibration: SimCalibration = SimCalibration.new()
	calibration.read(lines, ContentLookup.new(balance))
	print("")
	print(calibration.report(calibration.evaluate(balance, SimRowSearch.new(balance))))
	return 0


## The .jsonl files at `path`: the file itself, or a folder's files in name order.
static func _log_files(path: String) -> PackedStringArray:
	if FileAccess.file_exists(path):
		return PackedStringArray([path])
	var files: PackedStringArray = PackedStringArray()
	for name: String in DirAccess.get_files_at(path):
		if name.ends_with(".jsonl"):
			files.append(path.path_join(name))
	files.sort()
	return files
