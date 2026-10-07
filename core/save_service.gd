class_name SaveService
extends RefCounted
## Reads and writes the save files (full build plan section 4) as JSON in one folder: user://
## in the game, a temporary folder in tests. The profile save is profile.json; the run save
## (RunSave) is run.json, written at every save point and deleted when the run ends or is
## abandoned. Steam cloud paths come later (phase 4). JSON never runs code, unlike loading a
## resource file from user://.
##
## Both files get the same treatment, each on its own. Errors go to an injectable reporter
## (push_error by default) so tests never print errors. A file that can't be read (bad JSON, a
## newer or missing format version, a field of the wrong type, and for the run an id that no
## longer resolves or a state the game can't reach) is reported, copied to <file>.bad (or
## .bad.2, .bad.3, … : a backup is never overwritten) and replaced: by a fresh profile, or by a
## new run whose first save point writes over it. If it can't even be opened or backed up, it
## is kept as it is and this service refuses to save over it (or delete it), so it is never
## lost. Writes go to a temporary file first, then over the save.

const PROFILE_FILE := "profile.json"
const RUN_FILE := "run.json"
const BACKUP_SUFFIX := ".bad"
const TEMP_SUFFIX := ".tmp"
## Project setting naming the save folder; unset means user://. Tests set it to a temporary
## folder before the shift screen loads.
const FOLDER_SETTING := "next_customer/save_folder"
const _PROFILE_LABEL := "Profile"
const _RUN_LABEL := "Run save"

var folder: String = ""
## The save files that couldn't be opened or backed up, by file name: saving would destroy
## them.
var _protected: Dictionary[String, bool] = {}
## The run save is refused at every save point while it is protected: only the first refusal
## is reported.
var _run_refusal_reported: bool = false
var _report_error: Callable
## Copies a file (from, to) -> Error: DirAccess.copy_absolute, or a test's stand-in.
var _copy_file: Callable


func _init(
	save_folder: String, report_error: Callable = Callable(), copy_file: Callable = Callable()
) -> void:
	folder = save_folder
	_report_error = report_error if report_error.is_valid() else _push_error
	_copy_file = copy_file if copy_file.is_valid() else _copy


## The game's save folder: the FOLDER_SETTING project setting, or user://.
static func default_folder() -> String:
	return str(ProjectSettings.get_setting(FOLDER_SETTING, "user://"))


func profile_path() -> String:
	return folder.path_join(PROFILE_FILE)


func run_path() -> String:
	return folder.path_join(RUN_FILE)


## The saved profile, or a fresh one when there is none yet (not an error) or it can't be read
## (reported and backed up, see the class doc). A save interrupted between removing the old
## file and moving the new one in left only the complete temporary file: it is read.
func load_profile() -> ProfileState:
	var profile: ProfileState = _load(PROFILE_FILE, _PROFILE_LABEL, _parse_profile)
	return profile if profile != null else ProfileState.new()


## The saved profile for display only (the title screen): a fresh one when there is none yet,
## null when it can't be read. It never reports or backs anything up: load_profile, run by the
## shift screen, does that once.
func peek_profile() -> ProfileState:
	if _existing_path(PROFILE_FILE).is_empty():
		return ProfileState.new()
	return _peek(PROFILE_FILE, _parse_profile)


## Writes the profile: to a temporary file first, then over the save. A write that fails
## leaves the save as it was. Returns false (and reports why) on failure, and when the saved
## profile couldn't be opened or backed up (see load_profile).
func save_profile(profile: ProfileState) -> bool:
	return _write(PROFILE_FILE, _PROFILE_LABEL, JSON.stringify(profile.to_dictionary(), "\t"))


## The saved run, or null when there is none (not an error) or it can't be read (reported and
## backed up, see the class doc). Ids resolve through `lookup`. Like the profile, a complete
## temporary file left by an interrupted save is read.
func load_run(lookup: ContentLookup) -> RunSave:
	return _load(RUN_FILE, _RUN_LABEL, _run_parser(lookup))


## The saved run for display only (the title screen's Continue): null when there is none or it
## can't be read. It never reports or backs anything up: load_run, run by the shift screen,
## does that once.
func peek_run(lookup: ContentLookup) -> RunSave:
	return _peek(RUN_FILE, _run_parser(lookup))


## Writes the run at a save point (RunSave), through a temporary file like the profile. Returns
## false on failure, when the run isn't at a save point (reported), and when the saved run
## couldn't be opened or backed up (reported once).
func save_run(run: RunState, run_id: String, run_ms: int) -> bool:
	var data: Dictionary = RunSave.to_dictionary(run, run_id, run_ms)
	if data.is_empty():
		_report_error.call("%s: not saved, phase %d isn't a save point" % [_RUN_LABEL, run.phase])
		return false
	return _write(RUN_FILE, _RUN_LABEL, JSON.stringify(data, "\t"))


## Removes the run save (the run ended, or was abandoned) and any temporary file an
## interrupted save left. Returns true when neither is left. A run save that couldn't be opened
## or backed up is kept (reported once).
func delete_run() -> bool:
	if _refuses(RUN_FILE, _RUN_LABEL, "not deleted"):
		return false
	var deleted: bool = true
	for path: String in [run_path(), run_path() + TEMP_SUFFIX]:
		if not FileAccess.file_exists(path):
			continue
		var error: Error = DirAccess.remove_absolute(path)
		if error != OK:
			deleted = false
			_report_error.call("%s: can't delete %s (error %d)" % [_RUN_LABEL, path, error])
	return deleted


## The parsed save `file` (`parse` turns its text into the saved object, or null), or null:
## none yet (not an error), or reported and backed up when it can't be opened or read.
func _load(file: String, label: String, parse: Callable) -> Variant:
	var path: String = _existing_path(file)
	if path.is_empty():
		return null
	# Opened, not get_file_as_string: a file that can't be opened (locked by another program) is
	# told apart from bad content, and nothing prints an engine error.
	var opened: FileAccess = FileAccess.open(path, FileAccess.READ)
	if opened == null:
		_protected[file] = true
		_report_error.call(
			(
				"%s: can't open %s (error %d); it is kept and not saved over"
				% [label, path, FileAccess.get_open_error()]
			)
		)
		return null
	var parsed: Variant = parse.call(opened.get_as_text())
	opened.close()
	if parsed != null:
		return parsed
	var backup: String = _free_backup_path(file)
	var error: int = _copy_file.call(path, backup)
	if error == OK:
		_report_error.call("%s: can't read %s; kept as %s, starting fresh" % [label, path, backup])
	else:
		_protected[file] = true
		_report_error.call(
			"%s: can't read %s or back it up (error %d); not saved over" % [label, path, error]
		)
	return null


## The parsed save `file`, or null when there is none or it can't be opened or read. Never
## reports or backs anything up.
func _peek(file: String, parse: Callable) -> Variant:
	var path: String = _existing_path(file)
	if path.is_empty():
		return null
	var opened: FileAccess = FileAccess.open(path, FileAccess.READ)
	if opened == null:
		return null
	var parsed: Variant = parse.call(opened.get_as_text())
	opened.close()
	return parsed


## Writes `text` to the save `file`: to a temporary file first, then over the save. False (and
## reported) on failure, and when the file is protected.
func _write(file: String, label: String, text: String) -> bool:
	if _refuses(file, label, "not saved"):
		return false
	var error: Error = DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		_report_error.call("%s: can't create %s (error %d)" % [label, folder, error])
		return false
	var path: String = folder.path_join(file)
	var temp: String = path + TEMP_SUFFIX
	var opened: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if opened == null:
		_report_error.call(
			"%s: can't write %s (error %d)" % [label, temp, FileAccess.get_open_error()]
		)
		return false
	var written: bool = opened.store_string(text)
	opened.flush()
	written = written and opened.get_error() == OK
	opened.close()
	if not written:
		DirAccess.remove_absolute(temp)
		_report_error.call("%s: writing %s failed; the save is unchanged" % [label, temp])
		return false
	# Godot's rename on Windows removes the target first too; _load reads the temporary file if
	# a crash comes between the two.
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	error = DirAccess.rename_absolute(temp, path)
	if error != OK:
		_report_error.call("%s: can't move %s to %s (error %d)" % [label, temp, path, error])
		return false
	return true


## True when `file` is protected: the profile's refusals are all reported, the run save's only
## the first (it is refused at every save point).
func _refuses(file: String, label: String, action: String) -> bool:
	if not _protected.get(file, false):
		return false
	if file == RUN_FILE:
		if _run_refusal_reported:
			return true
		_run_refusal_reported = true
	_report_error.call(
		"%s: %s, to keep %s that couldn't be read" % [label, action, folder.path_join(file)]
	)
	return true


## The save to read: the file, else a complete temporary file left by an interrupted save, else
## "" (no save yet).
func _existing_path(file: String) -> String:
	var path: String = folder.path_join(file)
	if FileAccess.file_exists(path):
		return path
	if FileAccess.file_exists(path + TEMP_SUFFIX):
		return path + TEMP_SUFFIX
	return ""


## <file>.bad, or the first of .bad.2, .bad.3, … not taken yet.
func _free_backup_path(file: String) -> String:
	var backup: String = folder.path_join(file) + BACKUP_SUFFIX
	var candidate: String = backup
	var number: int = 2
	while FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(candidate):
		candidate = "%s.%d" % [backup, number]
		number += 1
	return candidate


## Parses the run save's text with `lookup`.
static func _run_parser(lookup: ContentLookup) -> Callable:
	return func(text: String) -> RunSave:
		var data: Variant = _parse_json(text)
		return RunSave.from_dictionary(data, lookup) if data != null else null


## A profile from saved text, or null when it isn't one this version can read.
static func _parse_profile(text: String) -> ProfileState:
	var data: Variant = _parse_json(text)
	return ProfileState.from_dictionary(data) if data != null else null


## The JSON object in the text, or null.
static func _parse_json(text: String) -> Variant:
	# A JSON instance: unlike JSON.parse_string, it never prints a parse error itself.
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return null
	return json.data


static func _copy(from: String, to: String) -> Error:
	return DirAccess.copy_absolute(from, to)


static func _push_error(message: String) -> void:
	push_error(message)
