class_name EventLogService
extends Node
## Autoload "EventLog": the playtest event log (plan section 8). A genuinely global service:
## run state is never stored here.
##
## A session is one launch. Its file is user://playtest_logs/<UTC start>_<session_id>.jsonl,
## created on the first event, so test runs that log nothing create no file.

const LOG_FOLDER := "user://playtest_logs"
## The impulse rack's derived stream (full build plan section 4).
const IMPULSE_RACK_STREAM := "impulse_rack"

var session_id: String = ""
var run_id: String = ""
var build_label: String = ""
var _seq: int = 0
var _writer: EventLogWriter
## Its own RNG for ids and new run seeds: never the run's seeded RNG.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	session_id = _random_id()
	build_label = str(ProjectSettings.get_setting("next_customer/build_label", ""))
	var start: String = Time.get_datetime_string_from_system(true).replace("-", "").replace(":", "")
	_writer = EventLogWriter.new(LOG_FOLDER, "%s_%s.jsonl" % [start, session_id])


## Tests only: write this session's events to another folder.
func use_folder(folder: String) -> void:
	_writer = EventLogWriter.new(folder, _writer.file_path.get_file())


## A fresh random seed for a new run (plan section 2: restarts use a new seed).
func new_run_seed() -> int:
	return _rng.randi()


## A derived stream (full build plan section 4): its own RandomNumberGenerator, seeded from the
## run seed and the stream's name, for a choice that must not use the run's RNG (the impulse
## rack). Made here, outside core/, and passed in, so core/ never makes a seed. The same seed
## and name always give the same stream.
static func derived_stream(run_seed: int, stream_name: String) -> RandomNumberGenerator:
	var stream: RandomNumberGenerator = RandomNumberGenerator.new()
	stream.seed = hash([run_seed, stream_name])
	return stream


## Starts a new run id; call before logging run_start.
func begin_run() -> void:
	run_id = _random_id()


func log_event(type: String, data: Dictionary = {}) -> void:
	_seq += 1
	var event: Dictionary = {
		"session_id": session_id,
		"run_id": run_id,
		"seq": _seq,
		"time": Time.get_datetime_string_from_system(true) + "Z",
		"t_ms": Time.get_ticks_msec(),
		"build": build_label,
		"type": type,
	}
	event.merge(data)
	_writer.append(event)


## The Export log button (plan section 8): every session file joined into one .jsonl. On the
## web it is downloaded; on desktop it is written next to the logs and the folder is opened.
## The log_export event is written first, so the exported file contains it. Returns the
## joined text.
func export_logs(screen: String, open_folder: bool = true) -> String:
	var folder: String = _writer.folder
	var files: int = 0
	if DirAccess.dir_exists_absolute(folder):
		for file_name: String in DirAccess.get_files_at(folder):
			if file_name.ends_with(".jsonl"):
				files += 1
	if not FileAccess.file_exists(_writer.file_path):
		files += 1
	log_event("log_export", {"screen": screen, "files": files})
	var joined: String = EventLogWriter.join_logs(folder)
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "-")
	var file_name: String = "next_customer_logs_%s.jsonl" % stamp
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(joined.to_utf8_buffer(), file_name, "application/x-ndjson")
	else:
		var export_path: String = folder.get_base_dir().path_join("playtest_export.jsonl")
		var file: FileAccess = FileAccess.open(export_path, FileAccess.WRITE)
		if file:
			file.store_string(joined)
			file.close()
		if open_folder:
			OS.shell_open(ProjectSettings.globalize_path(folder.get_base_dir()))
	return joined


func _random_id() -> String:
	return "%08x%08x" % [_rng.randi(), _rng.randi()]
