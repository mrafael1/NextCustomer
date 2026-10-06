class_name EventLogService
extends Node
## Autoload "EventLog": the playtest event log (plan section 8). A genuinely global service:
## run state is never stored here.
##
## A session is one launch. Its file is user://playtest_logs/<UTC start>_<session_id>.jsonl,
## created on the first event, so test runs that log nothing create no file.

const LOG_FOLDER := "user://playtest_logs"

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


func _random_id() -> String:
	return "%08x%08x" % [_rng.randi(), _rng.randi()]
