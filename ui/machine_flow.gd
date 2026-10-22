class_name MachineFlow
extends Node
## The RECEIPT REWARDS machine's visits on the shift screen (#77; build spec 4.2): it opens the
## machine (RewardMachineView) at the dessert's printer feed, chooses the chute the player
## confirms (RewardMachine.choose, then the run is saved at MACHINE_PICK), shows the prizes,
## takes the pick (through the deck-full chooser when the cart is full: DeckView in choosing mode,
## whose cancel goes back to the prizes with nothing picked or saved) or the bin, logs the
## machine_visit event, saves (the next visit's save point, or SCORED after the shift's last
## visit) and lands the prize; at the landing's beat the top bar shows what changed (the Cart
## count, the loyalty card, with the plain stamp while view.plain_landing); once the landing is
## over (the view's `finished`) it opens the next visit (the bonus ticket's, waiting at
## MACHINE_CHOOSE; STAMP DAY's, drawn, at MACHINE_PICK) or starts the next shift. A resumed run
## (MACHINE_CHOOSE or MACHINE_PICK) opens here at its wait point, with no replay. A tap that
## fast-forwards the view's clock up to the pick is logged as the visit's presentation_skipped;
## one during the landing, after the visit was logged, as a machine_landing_skipped event.
##
## A part of the shift screen, split out to keep that file short (like ShiftDebug): it works on
## the screen's run and display through the screen's own members.

## The most steps debug_skip takes (a visit is at most a choose and a pick or bin).
const DEBUG_SKIP_STEPS := 16
## A debug export (never the editor, the tests or a release) prints how long a visit's four odds
## cards took to compute when it opens (build spec 9's web check: under 150 ms on the web).
const ODDS_TIMING_FEATURE := "template_debug"

var view: RewardMachineView
var _screen: ShiftScreen
var _log: EventLogService
## The visit on screen: its timeline, the odds cards opened (chutes, in order), the odds card of
## the chute chosen (as shown before the draw), whether the cart was full when it was chosen,
## whether it was resumed from a save, and a pick waiting for the deck-full chooser (-1: none).
var _timeline: OfferTimeline = OfferTimeline.new()
var _viewed: Array[int] = []
var _odds: MachineOddsCard
var _resumed: bool = false
var _pending: int = -1
## The landing under way (null: none, or a bin).
var _landing: MachineLanding


## Builds the machine on `screen` (a screen child over the shade, added at the screen's call).
func setup(screen: ShiftScreen, event_log: EventLogService) -> RewardMachineView:
	_screen = screen
	_log = event_log
	view = RewardMachineView.new()
	view.loyalty_card = screen._loyalty_card
	view.sfx = screen._sfx
	view.music = screen._music
	view.reduced_motion = func() -> bool: return screen.profile.reduced_motion()
	view.chute_confirmed.connect(_on_chute_confirmed)
	view.prize_picked.connect(_on_prize_picked)
	view.binned.connect(_on_binned)
	view.odds_opened.connect(func(chute: int) -> void: _viewed.append(chute))
	view.beat.connect(_on_beat)
	view.finished.connect(_on_finished)
	view.skipped.connect(_on_skipped)
	return view


## Opens the machine on the run's current visit: at the dessert's printer feed after a checkout
## (the music comes back there), or `resumed` from a save (its prizes shown at once, no replay).
func open(resumed: bool) -> void:
	var run: RunState = _screen.run
	if (
		run.phase == RunState.Phase.MACHINE_CHOOSE
		and run.machine.current_visit().kind == MachineVisit.Kind.TICKET
	):
		ShiftMusic.rewards_shown(_screen._music)
	_resumed = resumed
	_viewed = []
	_pending = -1
	_odds = null
	var count: CountUp = _screen._count_up
	var feed_ms: int = count.printer_feed_ms
	var start: int = Time.get_ticks_msec()
	# Only the ticket's visit follows the dessert: its timeline starts at the printer feed and
	# carries the dessert's skip; the bonus ticket's and STAMP DAY's start at their own show.
	var after_dessert: bool = (
		not resumed and run.machine.current_visit().kind == MachineVisit.Kind.TICKET
	)
	if after_dessert and feed_ms >= 0:
		start = feed_ms
	_timeline = OfferTimeline.new(start)
	_timeline.presentation_skipped = after_dessert and count.dessert_skipped
	_show_receipt_lines(run)
	if OS.has_feature(ODDS_TIMING_FEATURE):
		_print_odds_time(run)
	view.open_visit(run, _screen._receipt, _screen._stage, resumed)
	if run.phase == RunState.Phase.MACHINE_PICK:
		_odds = _shown_odds(run)
		_timeline.mark_presented(Time.get_ticks_msec())


## Hides the machine (a new run, the deck view's chooser keeps it).
func close() -> void:
	_pending = -1
	view.close()


func is_open() -> bool:
	return view.visible


## The top bar's Cart during a visit: the deck view, once the machine has armed; the machine
## comes back when it closes.
func show_deck() -> void:
	if not view.is_armed():
		return
	var run: RunState = _screen.run
	view.visible = false
	_screen._deck_view.open(
		run, "Your cart (%d/%d)" % [run.deck.size(), run.balance.deck_limit], false
	)


## The deck view closed without a choice: the chooser's cancel returns to the prizes, nothing
## picked or saved; the plain deck view gives the machine back.
func on_deck_closed() -> void:
	_pending = -1
	var run: RunState = _screen.run
	if RunState.MACHINE_PHASES.has(run.phase):
		view.visible = true


## The deck-full chooser's card: the waiting pick swaps it out.
func on_deck_card_chosen(card: CardInstance) -> void:
	if _pending >= 0:
		var index: int = _pending
		_pending = -1
		_take(index, card)


## Debug panel and tests: a landing under way ends at once; then every waiting visit chooses NEW
## ITEMS (or the first lit chute) and bins it, STAMP DAY picks its first prize (at the deck limit
## swapping the deck's first card out), as the player could, logging and saving as they would,
## each landing fast-forwarded; the next shift starts.
func debug_skip() -> void:
	var run: RunState = _screen.run
	view.fast_forward()
	for _step: int in range(DEBUG_SKIP_STEPS):
		if not RunState.MACHINE_PHASES.has(run.phase):
			return
		if run.phase == RunState.Phase.MACHINE_CHOOSE:
			var chosen: bool = false
			for chute: int in RewardMachine.CHUTES:
				var lit: bool = (
					run.machine.chute_info(run, chute).state == RewardMachine.ChuteState.OPEN
				)
				if lit and not chosen:
					chosen = _choose(chute)
			if not chosen:
				return
		elif run.machine.can_bin():
			_on_binned()
		else:
			var replaced: CardInstance = run.deck.cards[0] if run.deck_is_full() else null
			_take(0, replaced)
		view.fast_forward()


## The machine armed: at the chute keys the player's chute wait starts (left out of the
## presentation times), at the prizes the visit is armed. The prize landed: the top bar shows it.
func _on_beat(beat_name: StringName, _t0: float) -> void:
	if beat_name == &"land":
		_landed()
		return
	if beat_name != &"armed":
		return
	var now: int = Time.get_ticks_msec()
	if _screen.run.phase == RunState.Phase.MACHINE_CHOOSE:
		_timeline.start_wait(now)
	elif _screen.run.phase == RunState.Phase.MACHINE_PICK:
		_timeline.mark_armed(now)


func _on_chute_confirmed(chute: int) -> void:
	_choose(chute)


## Draws the chosen chute's prizes and shows them; saved at MACHINE_PICK (after the draw).
func _choose(chute: int) -> bool:
	var run: RunState = _screen.run
	var odds: MachineOddsCard = run.machine.chute_info(run, chute).odds
	if not run.machine.choose(run, chute):
		return false
	_timeline.end_wait(Time.get_ticks_msec())
	_odds = odds
	_screen._save_run()
	Sfx.play_at(view, "print")
	view.show_draw(run)
	_timeline.mark_presented(Time.get_ticks_msec())
	return true


func _on_prize_picked(index: int) -> void:
	var run: RunState = _screen.run
	if not run.machine.needs_replace(run, index):
		_take(index, null)
		return
	# Plan section 2: at the deck limit, taking a card means choosing one to remove.
	var prize: MachinePrize = run.machine.prizes()[index]
	_pending = index
	view.visible = false
	_screen._deck_view.open(
		run,
		(
			"Cart full (%d/%d): choose an item to remove for %s"
			% [run.deck.size(), run.balance.deck_limit, prize.card.display_name]
		),
		true
	)


## Takes the prize, logs the visit, saves and lands it (the next visit or shift follows the
## landing: _on_finished).
func _take(index: int, replaced: CardInstance) -> void:
	var run: RunState = _screen.run
	var cart_full: bool = run.deck_is_full()
	var timing: Dictionary = _timeline.fields(Time.get_ticks_msec())
	var landing: MachineLanding = run.machine.pick(run, index, replaced)
	if landing == null:
		return
	_log_visit(cart_full, timing)
	_screen._deck_view.visible = false
	view.visible = true
	_landing = landing
	_screen._save_run()
	view.land(landing)


func _on_binned() -> void:
	var run: RunState = _screen.run
	var timing: Dictionary = _timeline.fields(Time.get_ticks_msec())
	var cart_full: bool = run.deck_is_full()
	if not run.machine.bin(run):
		return
	_log_visit(cart_full, timing)
	_landing = null
	_screen._save_run()
	view.land(null)


## The receipt's lines for the machine's copy of it (ReceiptFeed): as the count-up printed them,
## with the shift end's total, quota and next inspection's notice.
func _show_receipt_lines(run: RunState) -> void:
	view.receipt_header = _screen.receipt_header()
	view.receipt_names = ShiftScreen._names(run.row)
	view.receipt_upgrades = LoyaltyCard.names(run.upgrades)
	view.receipt_inspections = InspectionTag.names(run.inspections)
	view.shift_total = run.last_result.total if run.last_result != null else 0
	view.shift_quota = run.quota()
	view.shift_notice = InspectionTag.next_notice(run.next_inspection)


## The player tapped to fast-forward: before the pick, the visit's presentation_skipped; during
## the landing (the visit already logged at its pick or bin), a machine_landing_skipped event.
func _on_skipped() -> void:
	var run: RunState = _screen.run
	if view.plan == null or not view.plan.has_landing:
		_timeline.presentation_skipped = true
		return
	var record: ShiftRecord = run.history[-1]
	var visit: MachineVisit = record.visits[-1]
	var data: Dictionary = {
		"shift": record.shift,
		"visit_index": record.visits.size() - 1,
		"kind": MachineVisit.KIND_NAMES[visit.kind],
		"at_ms": roundi(view.clock * 1000.0),
	}
	_log.log_event("machine_landing_skipped", data)


## The visit just recorded (the run's last record's last visit), as machine_visit.
func _log_visit(cart_full: bool, timing: Dictionary) -> void:
	var run: RunState = _screen.run
	var visit: MachineVisit = run.history[-1].visits[-1]
	var odds: MachineOddsCard = _odds
	if visit.kind == MachineVisit.Kind.STAMP_DAY:
		odds = visit.stamp_day_odds
	var data: Dictionary = RunEvents.machine_visit(
		run, visit, odds, _viewed, cart_full, _resumed, timing
	)
	_log.log_event("machine_visit", data)


## The prize landed (beat &"land"): the top bar shows what the pick changed (the Cart count, the
## loyalty card); the plain landing stamps the loyalty card and plays its sound (none when the
## beat was fast-forwarded).
func _landed() -> void:
	_screen._refresh_bar()
	if _landing == null or not view.plain_landing or view.skipping:
		return
	if _landing.prize.kind == MachinePrize.Kind.REGISTER:
		_screen._loyalty_card.play_stamp(_landing.box_index)
		_screen._sfx.play("stamp_loyalty")
	else:
		_screen._sfx.play("card_place")


## The landing is over: the next visit (the bonus ticket's, STAMP DAY's), or the next shift after
## the last one. Only the top bar shows what the pick changed: the belt and the receipt stay as
## the count-up left them behind the machine.
func _on_finished() -> void:
	var run: RunState = _screen.run
	_landing = null
	_screen._refresh_bar()
	if RunState.MACHINE_PHASES.has(run.phase):
		open(false)
		return
	view.close()
	run.next_shift()
	_screen._on_shift_started()


## Computes the visit's four odds cards (the machine keeps them for the view) and prints how
## long that took.
static func _print_odds_time(run: RunState) -> void:
	var start: int = Time.get_ticks_usec()
	for chute: int in RewardMachine.CHUTES:
		run.machine.chute_info(run, chute)
	var spent: int = Time.get_ticks_usec() - start
	var visit: MachineVisit = run.machine.current_visit()
	var kind: String = MachineVisit.KIND_NAMES[visit.kind] if visit != null else "none"
	print("machine odds: %d us (shift %d, %s)" % [spent, run.shift_index + 1, kind])


## The odds card a resumed pick was drawn from: STAMP DAY's own, else the chosen chute's now.
static func _shown_odds(run: RunState) -> MachineOddsCard:
	var visit: MachineVisit = run.machine.current_visit()
	if visit.kind == MachineVisit.Kind.STAMP_DAY:
		return run.machine.chute_info(run, RewardMachine.Chute.REGISTER).odds
	return run.machine.chute_info(run, visit.chute).odds
