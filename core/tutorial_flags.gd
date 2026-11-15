class_name TutorialFlags
extends RefCounted
## The tutorial's profile flags (the guided first run, the one-time tips and the quick
## tutorials), kept as ids in ProfileState.seen, so the profile's format is unchanged: an older
## profile reads with none set. Pure and static: the caller saves the profile after a change.
##
## - GUIDE_DONE: the guided first run was finished (its last step, G26). Never removed by
##   reset_tips.
## - GUIDE_REPLAY: the HANDBOOK's PLAY THE GUIDED SHIFT asked for the next new run to be guided.
##   finish_guide clears it.
## - "tip:<id>": a one-time tip was shown (tip(id); the ids are the tip data's, e.g. day_event).
## - "quick:<id>": a quick tutorial was finished or backed out of (quick(id); QUICK_RESTOCK,
##   QUICK_PINS, QUICK_SWAP).
##
## A profile that already played (run_count > 0) gets GUIDE_DONE silently (decided with the user,
## 2026-11-14): migrate sets it when the profile is loaded, and guided_due treats such a profile
## as done even before that, so a played profile never starts a guided run unless a replay was
## asked for. Its tips and quick tutorials still show once.

const GUIDE_DONE := &"guide:done"
const GUIDE_REPLAY := &"guide:replay"
const TIP_PREFIX := "tip:"
const QUICK_PREFIX := "quick:"
## The quick tutorials' ids (quick(id) gives their flags).
const QUICK_RESTOCK := &"restock"
const QUICK_PINS := &"pins"
const QUICK_SWAP := &"swap"
const QUICK_IDS: Array[StringName] = [QUICK_SWAP, QUICK_RESTOCK, QUICK_PINS]


## Whether the first-seen flag `id` is set in `profile.seen` (any flag, the tutorial's or not).
static func has_seen(profile: ProfileState, id: StringName) -> bool:
	return profile.seen.has(id)


## Sets the first-seen flag `id`. Returns false (and changes nothing) when it was set already;
## the caller saves the profile on true.
static func mark_seen(profile: ProfileState, id: StringName) -> bool:
	if profile.seen.has(id):
		return false
	profile.seen.append(id)
	return true


## Clears the first-seen flag `id`. Returns whether it was set.
static func unmark_seen(profile: ProfileState, id: StringName) -> bool:
	var had: bool = profile.seen.has(id)
	while profile.seen.has(id):
		profile.seen.erase(id)
	return had


## RESET TIPS (options): clears every one-time tip's and quick tutorial's flag (is_tip_flag),
## keeping the others in their order (the guided run's among them). Returns how many were
## cleared (0: nothing changed; the tips_reset event logs it).
static func reset_tips(profile: ProfileState) -> int:
	var kept: Array[StringName] = []
	for id: StringName in profile.seen:
		if not is_tip_flag(id):
			kept.append(id)
	var cleared: int = profile.seen.size() - kept.size()
	profile.seen = kept
	return cleared


## The flag of the one-time tip `id` ("tip:<id>").
static func tip(id: StringName) -> StringName:
	return StringName(TIP_PREFIX + String(id))


## The flag of the quick tutorial `id` ("quick:<id>").
static func quick(id: StringName) -> StringName:
	return StringName(QUICK_PREFIX + String(id))


## Whether `flag` is one RESET TIPS removes: a tip's or a quick tutorial's.
static func is_tip_flag(flag: StringName) -> bool:
	var text: String = String(flag)
	return text.begins_with(TIP_PREFIX) or text.begins_with(QUICK_PREFIX)


## Whether the guided first run is finished for this profile: GUIDE_DONE, or a profile that has
## played (run_count > 0, migrate's rule).
static func guide_done(profile: ProfileState) -> bool:
	return has_seen(profile, GUIDE_DONE) or profile.run_count > 0


## Whether the next new run is guided: the guided run isn't finished, or a replay was asked for.
static func guided_due(profile: ProfileState) -> bool:
	return has_seen(profile, GUIDE_REPLAY) or not guide_done(profile)


## Asks for the next new run to be guided (the HANDBOOK's PLAY THE GUIDED SHIFT). Never touches
## a saved run. Returns whether the profile changed.
static func request_replay(profile: ProfileState) -> bool:
	return mark_seen(profile, GUIDE_REPLAY)


## The guided run's end (G26): marks GUIDE_DONE and clears GUIDE_REPLAY. Returns whether the
## profile changed.
static func finish_guide(profile: ProfileState) -> bool:
	var changed: bool = mark_seen(profile, GUIDE_DONE)
	return unmark_seen(profile, GUIDE_REPLAY) or changed


## Whether the one-time tip `id` was shown already.
static func tip_seen(profile: ProfileState, id: StringName) -> bool:
	return has_seen(profile, tip(id))


## Marks the one-time tip `id` shown. Returns whether the profile changed.
static func mark_tip(profile: ProfileState, id: StringName) -> bool:
	return mark_seen(profile, tip(id))


## Whether the quick tutorial `id` was done (or backed out of) already.
static func quick_seen(profile: ProfileState, id: StringName) -> bool:
	return has_seen(profile, quick(id))


## Marks the quick tutorial `id` done. Returns whether the profile changed.
static func mark_quick(profile: ProfileState, id: StringName) -> bool:
	return mark_seen(profile, quick(id))


## The load-time migration: a profile that has played (run_count > 0) without GUIDE_DONE gets
## it, so it skips the guided run. Returns whether the profile changed (the caller may save it;
## if not, it is saved with the profile's next save, and guided_due already reads it as done).
static func migrate(profile: ProfileState) -> bool:
	if profile.run_count > 0 and not has_seen(profile, GUIDE_DONE):
		return mark_seen(profile, GUIDE_DONE)
	return false
