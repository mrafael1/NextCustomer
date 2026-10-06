class_name EventLogWriter
extends RefCounted
## Writes playtest events as JSON lines (plan section 8).
##
## Each event opens the file, appends one line and closes it again. On the web, user:// is
## saved to browser storage asynchronously, and a file kept open isn't guaranteed to be saved.
## Errors go to an injectable reporter (push_error by default) so tests never print errors.

var folder: String = ""
var file_path: String = ""
var _report_error: Callable


func _init(log_folder: String, file_name: String, report_error: Callable = Callable()) -> void:
	folder = log_folder
	file_path = log_folder.path_join(file_name)
	_report_error = report_error if report_error.is_valid() else _push_error


## Appends one event line. Returns false (and reports why) if the file can't be written.
func append(event: Dictionary) -> bool:
	if not _ensure_file():
		return false
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if file == null:
		_report_error.call(
			"Event log: can't open %s (error %d)" % [file_path, FileAccess.get_open_error()]
		)
		return false
	file.seek_end()
	file.store_line(JSON.stringify(event))
	file.close()
	return true


## Every .jsonl file in the folder, joined in name order (names start with the UTC start
## time, so this is chronological). Used by the log export.
static func join_logs(log_folder: String) -> String:
	if not DirAccess.dir_exists_absolute(log_folder):
		return ""
	var names: PackedStringArray = DirAccess.get_files_at(log_folder)
	names.sort()
	var joined: String = ""
	for file_name: String in names:
		if file_name.ends_with(".jsonl"):
			joined += FileAccess.get_file_as_string(log_folder.path_join(file_name))
	return joined


func _ensure_file() -> bool:
	if FileAccess.file_exists(file_path):
		return true
	var error: Error = DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		_report_error.call("Event log: can't create %s (error %d)" % [folder, error])
		return false
	# WRITE truncates, so it is only used to create the file the first time.
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		_report_error.call(
			"Event log: can't create %s (error %d)" % [file_path, FileAccess.get_open_error()]
		)
		return false
	file.close()
	return true


static func _push_error(message: String) -> void:
	push_error(message)
