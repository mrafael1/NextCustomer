extends GdUnitTestSuite
## Event log writing and checkout measures (plan section 8).

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()


func after_test() -> void:
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_writer_creates_the_folder_and_appends_lines() -> void:
	var writer: EventLogWriter = EventLogWriter.new(_folder, "a.jsonl")
	assert_bool(writer.append({"type": "run_start", "seq": 1})).is_true()
	assert_bool(writer.append({"type": "shift_start", "seq": 2})).is_true()
	var lines: PackedStringArray = FileAccess.get_file_as_string(writer.file_path).split(
		"\n", false
	)
	assert_int(lines.size()).is_equal(2)
	assert_str(JSON.parse_string(lines[1])["type"]).is_equal("shift_start")


func test_a_second_writer_never_truncates() -> void:
	EventLogWriter.new(_folder, "a.jsonl").append({"n": 1})
	EventLogWriter.new(_folder, "a.jsonl").append({"n": 2})
	var text: String = FileAccess.get_file_as_string(_folder.path_join("a.jsonl"))
	assert_int(text.split("\n", false).size()).is_equal(2)


func test_join_logs_in_name_order() -> void:
	EventLogWriter.new(_folder, "20261006T100000_b.jsonl").append({"n": 2})
	EventLogWriter.new(_folder, "20261005T100000_a.jsonl").append({"n": 1})
	var lines: PackedStringArray = EventLogWriter.join_logs(_folder).split("\n", false)
	assert_int(lines.size()).is_equal(2)
	assert_int(int(JSON.parse_string(lines[0])["n"])).is_equal(1)


func test_write_errors_go_to_the_reporter() -> void:
	var errors: Array[String] = []
	var reporter: Callable = func(message: String) -> void: errors.append(message)
	# A file name that is a folder can't be opened as a file.
	DirAccess.make_dir_recursive_absolute(_folder.path_join("blocked.jsonl"))
	var writer: EventLogWriter = EventLogWriter.new(_folder, "blocked.jsonl", reporter)
	assert_bool(writer.append({"n": 1})).is_false()
	assert_int(errors.size()).is_equal(1)
	DirAccess.remove_absolute(_folder.path_join("blocked.jsonl"))


func test_checkout_measures() -> void:
	var tracker: CheckoutTracker = CheckoutTracker.new()
	tracker.begin(1000)
	for i: int in range(5):
		tracker.on_place()
	tracker.on_remove()
	tracker.on_preview(3, 10)
	tracker.on_preview(3, 12)
	tracker.on_preview(3, 10)
	tracker.on_preview(4, 15)
	tracker.on_focus_lost(2000)
	tracker.on_focus_gained(5000)
	tracker.on_checkout(9000)
	var measures: Dictionary = tracker.measures(3)
	assert_int(measures["placements"]).is_equal(5)
	assert_int(measures["removals"]).is_equal(1)
	assert_int(measures["rearrangements"]).is_equal(2)
	assert_int(measures["distinct_projected_totals"]).is_equal(2)
	assert_int(measures["planning_ms"]).is_equal(5000)
	assert_str(measures["input_method"]).is_equal("click")


func test_checkout_while_unfocused_stops_the_clock_at_focus_loss() -> void:
	var tracker: CheckoutTracker = CheckoutTracker.new()
	tracker.begin(0)
	tracker.on_focus_lost(3000)
	tracker.on_checkout(8000)
	assert_int(tracker.planning_ms()).is_equal(3000)


## Plan 8: planning time ends at the checkout click, so focus changes during the count-up
## don't count.
func test_focus_changes_after_checkout_are_ignored() -> void:
	var tracker: CheckoutTracker = CheckoutTracker.new()
	tracker.begin(0)
	tracker.on_checkout(1500)
	tracker.on_focus_lost(1700)
	tracker.on_focus_gained(2700)
	assert_int(tracker.planning_ms()).is_equal(1500)


func test_shift_started_while_away_counts_from_the_return() -> void:
	var tracker: CheckoutTracker = CheckoutTracker.new()
	tracker.begin(0, false)
	tracker.on_focus_gained(4000)
	tracker.on_checkout(6000)
	assert_int(tracker.planning_ms()).is_equal(2000)


func test_rearrangements_never_negative() -> void:
	var tracker: CheckoutTracker = CheckoutTracker.new()
	tracker.begin(0)
	tracker.on_place()
	assert_int(tracker.rearrangements(3)).is_equal(0)
