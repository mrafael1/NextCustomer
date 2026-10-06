class_name SaveService
extends RefCounted
## Reads and writes the profile save (full build plan section 4) as JSON in one folder:
## user:// in the game, a temporary folder in tests. The run save (#18) and Steam cloud paths
## (phase 4) come later. JSON never runs code, unlike loading a resource file from user://.
##
## Errors go to an injectable reporter (push_error by default) so tests never print errors. A
## profile that can't be read (bad JSON, a newer or missing format version, a field of the
## wrong type) is reported, copied to profile.json.bad (or .bad.2, .bad.3, … : a backup is
## never overwritten) and replaced by a fresh profile. If it can't even be opened or backed
## up, it is kept as it is and this service refuses to save over it, so the next save never
## loses it.

const PROFILE_FILE := "profile.json"
const BACKUP_SUFFIX := ".bad"
const TEMP_SUFFIX := ".tmp"
## Project setting naming the save folder; unset means user://. Tests set it to a temporary
## folder before the shift screen loads.
const FOLDER_SETTING := "next_customer/save_folder"

var folder: String = ""
## True when the saved profile couldn't be opened or backed up: saving would destroy it.
var _protected: bool = false
var _report_error: Callable


func _init(save_folder: String, report_error: Callable = Callable()) -> void:
	folder = save_folder
	_report_error = report_error if report_error.is_valid() else _push_error


## The game's save folder: the FOLDER_SETTING project setting, or user://.
static func default_folder() -> String:
	return str(ProjectSettings.get_setting(FOLDER_SETTING, "user://"))


func profile_path() -> String:
	return folder.path_join(PROFILE_FILE)


## The saved profile, or a fresh one when there is none yet (not an error) or it can't be read
## (reported and backed up, see the class doc). A save interrupted between removing the old
## file and moving the new one in left only the complete temporary file: it is read.
func load_profile() -> ProfileState:
	var path: String = profile_path()
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path + TEMP_SUFFIX):
		path += TEMP_SUFFIX
	if not FileAccess.file_exists(path):
		return ProfileState.new()
	# Opened, not get_file_as_string: a file that can't be opened (locked by another program) is
	# told apart from bad content, and nothing prints an engine error.
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_protected = true
		_report_error.call(
			(
				"Profile: can't open %s (error %d); it is kept and not saved over"
				% [path, FileAccess.get_open_error()]
			)
		)
		return ProfileState.new()
	var text: String = file.get_as_text()
	file.close()
	# A JSON instance: unlike JSON.parse_string, it never prints a parse error itself.
	var json: JSON = JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		var profile: ProfileState = ProfileState.from_dictionary(json.data)
		if profile != null:
			return profile
	var backup: String = _free_backup_path()
	var error: Error = DirAccess.copy_absolute(path, backup)
	if error == OK:
		_report_error.call("Profile: can't read %s; kept as %s, starting fresh" % [path, backup])
	else:
		_protected = true
		_report_error.call(
			"Profile: can't read %s or back it up (error %d); not saved over" % [path, error]
		)
	return ProfileState.new()


## Writes the profile: to a temporary file first, then over the save. A write that fails
## leaves the save as it was. Returns false (and reports why) on failure, and when the saved
## profile couldn't be opened or backed up (see load_profile).
func save_profile(profile: ProfileState) -> bool:
	if _protected:
		_report_error.call("Profile: not saved, to keep %s that couldn't be read" % profile_path())
		return false
	var error: Error = DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		_report_error.call("Profile: can't create %s (error %d)" % [folder, error])
		return false
	var path: String = profile_path()
	var temp: String = path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		_report_error.call(
			"Profile: can't write %s (error %d)" % [temp, FileAccess.get_open_error()]
		)
		return false
	var written: bool = file.store_string(JSON.stringify(profile.to_dictionary(), "\t"))
	file.flush()
	written = written and file.get_error() == OK
	file.close()
	if not written:
		DirAccess.remove_absolute(temp)
		_report_error.call("Profile: writing %s failed; the save is unchanged" % temp)
		return false
	# Godot's rename on Windows removes the target first too; load_profile reads the temporary
	# file if a crash comes between the two.
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	error = DirAccess.rename_absolute(temp, path)
	if error != OK:
		_report_error.call("Profile: can't move %s to %s (error %d)" % [temp, path, error])
		return false
	return true


## profile.json.bad, or the first of .bad.2, .bad.3, … not taken yet.
func _free_backup_path() -> String:
	var backup: String = profile_path() + BACKUP_SUFFIX
	var candidate: String = backup
	var number: int = 2
	while FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(candidate):
		candidate = "%s.%d" % [backup, number]
		number += 1
	return candidate


static func _push_error(message: String) -> void:
	push_error(message)
