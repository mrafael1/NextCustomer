class_name PuzzleFlow
extends RefCounted
## A puzzle shift on the shift screen (#183, full build plan section 7.6): split out of ShiftScreen
## to keep that file short; like PinFlow it is a part of the screen and works on its run and
## display. The title's puzzle board asks for it (PuzzlePlay.request); the screen takes it instead
## of its run save.
##
## The shift is PuzzleRun.build's: one fixed hand, no redraw, no machine, never saved (the run
## save stays as it was). The receipt reads HIT EXACTLY over the target and, like the gauge, shows
## planning's projected total as a run's does (play test 2026-11-23). The gauge is the exact tube
## (QuotaMeter.exact) in a run's place (no SHIFT chip: TopBar.hides_shift): it fills as a run's,
## its target a gold notch, the laps past it tomato. The count's dessert plays the pass's sounds
## on EXACT alone, the miss's on OVER and SHORT (CountUp.exact_quota). After the count the
## receipt stamps the verdict (EXACT, OVER n€ or SHORT n€; ReceiptTarget.show_verdict) and the
## verdict keys come in big over the belt (PuzzleVerdictKeys, #183 polish): a miss's RETRY (the
## checked-out belt back, one click), a solve's NEXT (the next open puzzle; BOARD when there is
## none) with a small RETRY beside it. The puzzle's words (PUZZLE n, its pack and title) stand
## on the overlay right of the belt (PuzzleOverlay) with BOARD (the title's board) and, while
## planning, a small RETRY; its tip in the register where a run's Redraw key stands
## (PuzzleHint). An EXACT solve is saved in the profile at once (ProfilePuzzles.solve) and a
## full pack's badge pin unlocks there, its card shown over the screen (PinReveal); the pack's
## first completion asks the board to shine it (PuzzlePlay.note_completed).
##
## Polish 5 (play test 2026-11-23): an EXACT verdict celebrates (PuzzleCheer: the stamp slams, the
## notch flashes, confetti, the bell); the solve that completes a pack turns the overlay gold
## (PuzzleOverlay.go_gold, GOLD_DELAY after the stamp) before its pin's card comes up, and its
## keys are BOARD alone; a completed pack's puzzles show the gold overlay. The tip starts hidden
## behind SHOW TIP. Logged: puzzle_start, puzzle_checkout (its total, target and verdict),
## puzzle_solved and puzzle_tip (SHOW TIP pressed).

const OVER_TEXT := "OVER %d€"
const SHORT_TEXT := "SHORT %d€"
const EXACT_TEXT := "EXACT"
const VERDICT_WORDS: Array[String] = ["exact", "over", "short"]
## A pack's completing solve: the overlay turns gold GOLD_DELAY after the verdict (the stamp
## first), the pin's card comes up once it is gold.
const GOLD_DELAY := 0.45

var puzzle: PuzzleDefinition
var list: PuzzleList
var overlay: PuzzleOverlay
var verdict_keys: PuzzleVerdictKeys
var hint: PuzzleHint
var cheer: PuzzleCheer
## The last checkout's verdict (PuzzleRun.Verdict), -1 before the first.
var last_verdict: int = -1
var _screen: ShiftScreen
var _log: EventLogService
## The belt as it was checked out (card ids in order): what RETRY puts back.
var _checked_out: PackedStringArray = PackedStringArray()
var _reveal: PinReveal
## The completing solve's gold turn, then its pin card.
var _gold_turn: Tween


func _init(screen: ShiftScreen, event_log: EventLogService) -> void:
	_screen = screen
	_log = event_log
	list = PuzzlePlay.list()


## A flow playing puzzle `puzzle_id` on `screen`, or null (nothing changed) when the list has no
## such puzzle (&"": none asked).
static func started(
	screen: ShiftScreen, event_log: EventLogService, puzzle_id: StringName
) -> PuzzleFlow:
	if puzzle_id == &"":
		return null
	var flow: PuzzleFlow = PuzzleFlow.new(screen, event_log)
	return flow if flow.start(puzzle_id) else null


## Plays puzzle `puzzle_id`; false (nothing changed) when the list has no such puzzle.
func start(puzzle_id: StringName) -> bool:
	puzzle = list.find(puzzle_id)
	if puzzle == null:
		return false
	_screen._saves_run = false
	_dress()
	_play(PuzzleRun.build(puzzle, _screen._balance))
	_log.begin_run()
	_log.log_event("puzzle_start", {"puzzle": String(puzzle.id), "target": puzzle.target})
	return true


## The checkout was logged (the screen's): no run's end, no profile record; RETRY keeps its belt.
func log_checkout(checkout_data: Dictionary) -> void:
	_checked_out = PackedStringArray()
	for id: Variant in checkout_data.get("final_order", []):
		_checked_out.append(str(id))
	overlay.set_keys_enabled(false)


## The count has ended on `total`: the verdict stamps, an exact one is saved and the keys wake.
func counted(total: int) -> void:
	last_verdict = PuzzleRun.verdict(total, puzzle.target)
	var exact: bool = last_verdict == PuzzleRun.Verdict.EXACT
	_screen._receipt.target.show_verdict(verdict_text(total, puzzle.target), exact)
	_screen._cabinet.set_total_down(false)
	_screen._stage.dim_hand(false)
	_screen._stage.gauge_panel.show_gauge()  # Back down: the total against the notch.
	_screen._quota_meter.show_exact(total, puzzle.target)
	var data: Dictionary = {
		"puzzle": String(puzzle.id),
		"total": total,
		"target": puzzle.target,
		"verdict": VERDICT_WORDS[last_verdict],
		"row": _checked_out,
	}
	_log.log_event("puzzle_checkout", data)
	var still: bool = _screen.profile.reduced_motion()
	var completed: bool = false
	if exact:
		cheer.celebrate(_screen._receipt.target.stamp, _screen._quota_meter, still)
		completed = _solve(still)
	overlay.set_keys_enabled(true)
	overlay.show_retry(false)
	verdict_keys.still = still
	verdict_keys.show_keys(exact, _next() != null, completed)


## The verdict's words for `total` against `target`: EXACT, OVER 3€ or SHORT 4€.
static func verdict_text(total: int, target: int) -> String:
	match PuzzleRun.verdict(total, target):
		PuzzleRun.Verdict.OVER:
			return OVER_TEXT % (total - target)
		PuzzleRun.Verdict.SHORT:
			return SHORT_TEXT % (target - total)
	return EXACT_TEXT


## RETRY: the same puzzle, the checked-out belt back on it (planning again at once).
func retry() -> void:
	if _screen._counting:
		return
	_log.log_event("puzzle_retry", {"puzzle": String(puzzle.id)})
	_play(PuzzleRun.retry(puzzle, _screen._balance, _checked_out))


## NEXT: the pack's next open puzzle, fresh.
func next() -> void:
	var following: PuzzleDefinition = _next()
	if following == null or _screen._counting:
		return
	puzzle = following
	PuzzlePlay.note(puzzle.id)
	_checked_out = PackedStringArray()
	_play(PuzzleRun.build(puzzle, _screen._balance))
	_log.log_event("puzzle_start", {"puzzle": String(puzzle.id), "target": puzzle.target})


## BOARD: back to the title, on the puzzle board.
func board() -> void:
	if _screen._counting:
		return
	PuzzlePlay.request_board()
	if _screen.changes_scene:
		_screen.get_tree().change_scene_to_file(ShiftScreen.TITLE_SCREEN)


## The pin cards shown over the screen after a full pack, or null.
func reveal() -> PinReveal:
	return _reveal


## The puzzle's place in its pack, counted from 1.
func number() -> int:
	return list.pack(puzzle.pack).find(puzzle) + 1


func _play(run: RunState) -> void:
	_screen.run = run
	_screen.tutorial.strip.refresh()  # Shows the run's parts now, so they stay hidden below.
	for part: Control in [_screen._stage.redraw_button, _screen._stage.medal_case]:
		part.visible = false
	_screen._stage.day_calendar.stripped = false  # Today's events show there, as in a run.
	last_verdict = -1
	_screen._machine.reset_swaps()
	cheer.stop()
	if _gold_turn != null:
		_gold_turn.kill()
	var golden: bool = list.is_complete(puzzle.pack, _screen.profile.solved_puzzles)
	overlay.show_puzzle(puzzle, number(), list.pack_title(puzzle.pack), golden)
	overlay.set_keys_enabled(true)
	overlay.show_retry(true)
	verdict_keys.hide_keys()
	hint.show_puzzle(puzzle)
	_screen._stage.gauge_panel.show_gauge(false)
	_screen._on_shift_started()


## The screen dressed for puzzles: the receipt's HIT EXACTLY, the exact gauge in a run's place
## and the exact count; the run's keys and the week glass make way for the puzzle's tip; the
## overlay right of the belt and the verdict keys over it follow the belt's length. The day's
## events show where a run's do (play test 2026-11-23): the desk calendar's page (one day, its
## kind's band and sign; today's slip on a tap or a long hover), the belt's slot marks and the
## worn pins on the name badge's lanyard.
func _dress() -> void:
	_screen._receipt.target.use_puzzle()
	_screen._quota_meter.exact = true
	_screen._count_up.exact_quota = true
	(_screen._top_bar as TopBar).hides_shift = true
	var stage: ShiftStage = _screen._stage
	stage.week_glass.stripped = true  # It keeps its own rule: stripped, it stays hidden.
	_screen._week.single_day = true  # The calendar shows the puzzle's day as a run's (its slip).
	hint = PuzzleHint.new()
	stage.add_child(hint)
	hint.revealed.connect(
		func() -> void: _log.log_event("puzzle_tip", {"puzzle": String(puzzle.id)})
	)
	cheer = PuzzleCheer.new()
	_screen._overlay.add_child(cheer)
	overlay = PuzzleOverlay.new()
	stage.add_child(overlay)
	overlay.retry_pressed.connect(retry)
	overlay.board_pressed.connect(board)
	verdict_keys = PuzzleVerdictKeys.new()
	stage.add_child(verdict_keys)
	verdict_keys.retry_pressed.connect(retry)
	verdict_keys.next_pressed.connect(next)
	verdict_keys.board_pressed.connect(board)
	stage.row_strip.cells_changed.connect(_fit_to_belt)
	_fit_to_belt(stage.row_strip.slots.size() + stage.row_strip.closed.size())


## The overlay and the verdict keys follow a belt of `cells` cells (a perk or a day event can
## change its length).
func _fit_to_belt(cells: int) -> void:
	var cut: float = BeltPanel.cut_of(cells)
	overlay.fit(cut)
	verdict_keys.fit(cut)


## Saves the solve; a pack it completes for the first time turns the overlay gold, then shows
## the pins it unlocked (PinReveal). Returns whether it completed the pack now.
func _solve(still: bool) -> bool:
	var first: bool = not ProfilePuzzles.is_solved(_screen.profile, puzzle)
	var unlocked: Array[StringName] = ProfilePuzzles.solve(
		_screen.profile, puzzle, list, _screen._catalogue
	)
	_screen.save_profile()
	var completed: bool = false
	if first:
		_log.log_event("puzzle_solved", {"puzzle": String(puzzle.id), "pins": unlocked})
		completed = list.is_complete(puzzle.pack, _screen.profile.solved_puzzles)
		if completed:
			PuzzlePlay.note_completed(puzzle.pack)  # Its first solve: the board's gold shines.
	if not completed:
		_show_pins(unlocked, still)
		return false
	if still:
		overlay.go_gold(true)
		_show_pins(unlocked, still)
		return true
	_gold_turn = _screen.create_tween()
	_gold_turn.tween_interval(GOLD_DELAY)
	_gold_turn.tween_callback(overlay.go_gold.bind(false))
	_gold_turn.tween_interval(PuzzleOverlay.GOLD_TIME)
	_gold_turn.tween_callback(_show_pins.bind(unlocked, still))
	return true


## The cards of the pins `unlocked` (none: nothing) over the screen.
func _show_pins(unlocked: Array[StringName], still: bool) -> void:
	if unlocked.is_empty():
		return
	if _reveal == null:
		_reveal = PinReveal.new()
		_reveal.set_anchors_preset(Control.PRESET_FULL_RECT)
		_reveal.setup(_screen._receipt, func() -> bool: return false)
		_screen._overlay.add_child(_reveal)
	_reveal.show_news(PinUnlockNews.of(unlocked, _screen.profile, _screen._catalogue), still)


## The pack's next puzzle after this one, if its pack is open; else null.
func _next() -> PuzzleDefinition:
	var following: PuzzleDefinition = list.next_after(puzzle)
	if following == null or not list.is_open(following.pack, _screen.profile.solved_puzzles):
		return null
	return following
