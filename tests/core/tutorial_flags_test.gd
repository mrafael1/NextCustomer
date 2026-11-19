extends GdUnitTestSuite
## The tutorial's profile flags (TutorialFlags, tutorial plan sections 1.1 and 1.5): when a new
## run is guided (a fresh profile; a replay), the guided run's end, the played profile's
## migration (decided with the user, 2026-11-14), the tips' and quick tutorials' flags and RESET
## TIPS, which keeps the guided run's. The flags live in ProfileState.seen: no format bump.


func test_a_fresh_profile_is_guided_until_the_guided_run_is_finished() -> void:
	var profile: ProfileState = ProfileState.new()
	assert_bool(TutorialFlags.guide_done(profile)).is_false()
	assert_bool(TutorialFlags.guided_due(profile)).is_true()
	assert_bool(TutorialFlags.finish_guide(profile)).is_true()
	assert_bool(TutorialFlags.guided_due(profile)).is_false()
	assert_bool(TutorialFlags.guide_done(profile)).is_true()
	assert_array(profile.seen).is_equal([TutorialFlags.GUIDE_DONE])
	# Finishing again changes nothing.
	assert_bool(TutorialFlags.finish_guide(profile)).is_false()


func test_a_replay_makes_the_next_run_guided_and_its_end_clears_it() -> void:
	var profile: ProfileState = ProfileState.new()
	TutorialFlags.finish_guide(profile)
	assert_bool(TutorialFlags.request_replay(profile)).is_true()
	assert_bool(TutorialFlags.request_replay(profile)).is_false()
	assert_bool(TutorialFlags.guided_due(profile)).is_true()
	assert_bool(TutorialFlags.guide_done(profile)).is_true()
	assert_bool(TutorialFlags.finish_guide(profile)).is_true()
	assert_bool(TutorialFlags.guided_due(profile)).is_false()
	assert_bool(TutorialFlags.has_seen(profile, TutorialFlags.GUIDE_REPLAY)).is_false()


func test_a_played_profile_is_done_and_its_migration_sets_the_flag_once() -> void:
	var profile: ProfileState = ProfileState.new()
	assert_bool(TutorialFlags.migrate(profile)).is_false()
	assert_array(profile.seen).is_empty()
	profile.run_count = 2
	# Read as done even before the migration...
	assert_bool(TutorialFlags.guided_due(profile)).is_false()
	# ...which sets the flag, once.
	assert_bool(TutorialFlags.migrate(profile)).is_true()
	assert_bool(TutorialFlags.has_seen(profile, TutorialFlags.GUIDE_DONE)).is_true()
	assert_bool(TutorialFlags.migrate(profile)).is_false()
	assert_array(profile.seen).is_equal([TutorialFlags.GUIDE_DONE])
	# A played profile can still replay the guided run.
	TutorialFlags.request_replay(profile)
	assert_bool(TutorialFlags.guided_due(profile)).is_true()
	# Its tips still show once.
	assert_bool(TutorialFlags.tip_seen(profile, &"day_event")).is_false()


func test_tips_and_quick_tutorials_are_marked_once() -> void:
	var profile: ProfileState = ProfileState.new()
	assert_str(String(TutorialFlags.tip(&"day_event"))).is_equal("tip:day_event")
	assert_str(String(TutorialFlags.quick(TutorialFlags.QUICK_SWAP))).is_equal("quick:swap")
	assert_bool(TutorialFlags.mark_tip(profile, &"day_event")).is_true()
	assert_bool(TutorialFlags.mark_tip(profile, &"day_event")).is_false()
	assert_bool(TutorialFlags.tip_seen(profile, &"day_event")).is_true()
	assert_bool(TutorialFlags.tip_seen(profile, &"redraw")).is_false()
	assert_bool(TutorialFlags.mark_quick(profile, TutorialFlags.QUICK_RESTOCK)).is_true()
	assert_bool(TutorialFlags.quick_seen(profile, TutorialFlags.QUICK_RESTOCK)).is_true()
	assert_bool(TutorialFlags.quick_seen(profile, TutorialFlags.QUICK_PINS)).is_false()
	assert_array(TutorialFlags.QUICK_IDS).is_equal([&"swap", &"restock", &"pins"])


## The first-seen flags' helpers: set once, cleared (any flag, the tutorial's or not).
func test_first_seen_flags_are_set_once_and_cleared() -> void:
	var profile: ProfileState = ProfileState.new()
	assert_bool(TutorialFlags.has_seen(profile, &"capsule_machine")).is_false()
	assert_bool(TutorialFlags.mark_seen(profile, &"capsule_machine")).is_true()
	assert_bool(TutorialFlags.mark_seen(profile, &"capsule_machine")).is_false()
	assert_bool(TutorialFlags.has_seen(profile, &"capsule_machine")).is_true()
	assert_array(profile.seen).is_equal([&"capsule_machine"])
	assert_bool(TutorialFlags.unmark_seen(profile, &"capsule_machine")).is_true()
	assert_bool(TutorialFlags.unmark_seen(profile, &"capsule_machine")).is_false()
	assert_array(profile.seen).is_empty()


func test_reset_tips_keeps_the_guided_runs_flags_and_the_others() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.seen.append(&"capsule_machine")
	TutorialFlags.finish_guide(profile)
	TutorialFlags.request_replay(profile)
	TutorialFlags.mark_tip(profile, &"day_event")
	TutorialFlags.mark_tip(profile, &"redraw")
	TutorialFlags.mark_quick(profile, TutorialFlags.QUICK_PINS)
	assert_int(TutorialFlags.reset_tips(profile)).is_equal(3)
	assert_array(profile.seen).is_equal(
		[&"capsule_machine", TutorialFlags.GUIDE_DONE, TutorialFlags.GUIDE_REPLAY]
	)
	assert_int(TutorialFlags.reset_tips(profile)).is_equal(0)
	assert_bool(TutorialFlags.tip_seen(profile, &"day_event")).is_false()
	assert_bool(TutorialFlags.is_tip_flag(TutorialFlags.GUIDE_DONE)).is_false()
	assert_bool(TutorialFlags.is_tip_flag(&"tip:x")).is_true()
	assert_bool(TutorialFlags.is_tip_flag(&"quick:x")).is_true()


## The flags save in `seen`: they round-trip through the profile's saved form, whose version is
## unchanged, and a profile saved before them reads with none set.
func test_the_flags_round_trip_with_no_format_bump() -> void:
	var profile: ProfileState = ProfileState.new()
	TutorialFlags.finish_guide(profile)
	TutorialFlags.mark_tip(profile, &"coupon")
	TutorialFlags.mark_quick(profile, TutorialFlags.QUICK_SWAP)
	var text: String = JSON.stringify(profile.to_dictionary())
	var read: ProfileState = ProfileState.from_dictionary(JSON.parse_string(text))
	# 8 since the Dairy aisle (v1.44); the flags themselves bumped nothing.
	assert_int(ProfileState.FORMAT_VERSION).is_equal(8)
	assert_array(read.seen).is_equal(profile.seen)
	assert_bool(TutorialFlags.guided_due(read)).is_false()
	assert_bool(TutorialFlags.tip_seen(read, &"coupon")).is_true()
	var old: ProfileState = ProfileState.from_dictionary({"format_version": 6.0})
	assert_bool(TutorialFlags.guided_due(old)).is_true()
