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
## Machine v2 (#77, Q1 = A): the machine stands in the store, so a visit glides the camera to it
## (the view does, from its plan) and the shift's last visit ends with the glide back: the next
## shift starts first (run.next_shift and the screen's shift start, so it is saved at once and a
## resume lands in planning), then the camera glides back to 1x over MachineTuning's
## return_glide_ms while the fore comes back up and the machine dims (reduced motion: the cut
## behind the fade). Planning input waits for it (is_gliding); a tap ends it at once. `returned`
## follows its end.
##
## The next shift's planning (#77 machine v2, B1 and B5): the copies the shift's visits upgraded
## (MachineLanding.upgraded's pairs, `pending_swaps`) become `shown_swaps` as the next shift
## starts: their items show the old art through the glide back, then upgrade_after_ms after it an
## UpgradeSwap plays on the screen's overlay for those on screen, and the monitor's brief lists
## them (swap_news) until the next checkout. Once planning takes input, BonusNotice pulses the
## inspection chip and the brief's PASS IT plate when passing the shift earns the bonus ticket,
## and PremiumAnnounce (v0.50) prints its gold receipt on the monitor and hangs the PREMIUM NEXT
## tag when passing it earns a PREMIUM visit (RewardMachine.boosted_if_passed; a resume: the tag).
##
## A part of the shift screen, split out to keep that file short (like ShiftDebug): it works on
## the screen's run and display through the screen's own members.

## The glide back to the store is over (planning takes input again).
signal returned

## The most steps debug_skip takes (a visit is at most a choose and a pick or bin).
const DEBUG_SKIP_STEPS := 16
## A debug export (never the editor, the tests or a release) prints how long a visit's four odds
## cards took to compute when it opens (build spec 9's web check: under 150 ms on the web).
const ODDS_TIMING_FEATURE := "template_debug"

var view: RewardMachineView
## The upgraded copies: picked this shift (pending), shown the next one (see the class comment).
var pending_swaps: Array = []
var shown_swaps: Array = []
## The swap on screen (null: none yet, or freed) and the notice's pulse.
var swap: UpgradeSwap
var notice: BonusNotice
var announce: PremiumAnnounce
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
## Seconds into the glide back to the store, or -1 while there is none; its reduced motion is read
## when it starts. A tap ends it (`_presses`).
var _return_t: float = -1.0
var _return_rm: bool = false
var _presses: PressReader
## Seconds since the glide back ended while the swap waits (-1: none), and whether the notice
## waits for planning to take input.
var _swap_wait: float = -1.0
var _notice_due: bool = false
var _announce_prints: bool = true


## Builds the machine on `screen` (a screen child over the shade, added at the screen's call).
func setup(screen: ShiftScreen, event_log: EventLogService) -> RewardMachineView:
	_screen = screen
	_log = event_log
	view = RewardMachineView.new()
	view.camera = screen._camera
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
	_presses = PressReader.new()
	add_child(_presses)
	_presses.tapped.connect(func(_now_ms: int) -> void: _end_return())
	notice = BonusNotice.new()
	add_child(notice)
	announce = PremiumAnnounce.new()
	announce.reduced_motion = _reduced
	announce.active = func() -> bool:
		var run: RunState = screen.run
		return run != null and (run.phase == RunState.Phase.PLANNING or screen._counting)
	screen._overlay.add_child(announce)
	announce.setup(screen._monitor, screen._quota_meter.bar())
	return view


## A new shift's planning (or a resumed one, `printing` false) opened: the notice pulses and the
## premium announce prints (a resume: hangs its tag) once planning takes input.
func shift_started(printing: bool = true) -> void:
	notice.stop()
	announce.clear()
	_announce_prints = printing
	_notice_due = true


## A new run or a resume: no swap is due, none plays (a resume never replays one).
func reset_swaps() -> void:
	pending_swaps = []
	shown_swaps = []
	_swap_wait = -1.0
	if swap != null and is_instance_valid(swap):
		swap.queue_free()
	swap = null


## The monitor brief's lines for the copies upgraded since the last shift ("Banana is GOLDEN now").
func swap_news() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for pair: Array in shown_swaps:
		lines.append(UpgradeSwap.news_line((pair[1] as CardInstance).definition))
	return lines


## Plays the swap of the shown copies on screen (the screen's overlay); returns how many play.
func play_swaps() -> int:
	_swap_wait = -1.0
	if swap != null and is_instance_valid(swap):
		swap.queue_free()
	swap = UpgradeSwap.new()
	_screen._overlay.add_child(swap)
	return swap.play(shown_swaps, _screen.item_views(), _reduced(), _screen._sfx)


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
	if after_dessert:
		shown_swaps = []
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


## Ends any visit (a new run, a resume, a shift's start): the machine is idle on the wall, the
## camera in the store. A glide back under way stops where it is; the caller starts it again
## after a shift's last visit (_on_finished).
func close() -> void:
	_pending = -1
	_return_t = -1.0
	_presses.end()
	view.show_idle(_screen.run)
	_show_return(MachinePlan.return_length(view.tuning, false))


## Whether a visit is under way.
func is_open() -> bool:
	return view.is_open()


## Whether the camera is gliding back to the store after the shift's last visit.
func is_gliding() -> bool:
	return _return_t >= 0.0


## Whether planning still waits for the machine: the glide back, then the upgrade swap's
## upgrade_after_ms before it starts (a card moved meanwhile would swap on a new view).
func is_settling() -> bool:
	return is_gliding() or _swap_wait >= 0.0


func _process(delta: float) -> void:
	if _swap_wait >= 0.0:
		_swap_wait += delta
		if _swap_wait >= view.tuning.upgrade_after_ms / 1000.0:
			play_swaps()
	if _notice_due and _return_t < 0.0:
		_notice_due = false
		_play_notice()
		_play_announce()
	if _return_t < 0.0:
		return
	_return_t += delta
	if _return_t >= MachinePlan.return_length(view.tuning, _return_rm):
		_end_return()
	else:
		_show_return(_return_t)


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
## each landing fast-forwarded; the next shift starts, with no glide back (#77 machine v2).
func debug_skip() -> void:
	var run: RunState = _screen.run
	view.fast_forward()
	for _step: int in range(DEBUG_SKIP_STEPS):
		if not RunState.MACHINE_PHASES.has(run.phase):
			_end_return()  # The skip lands in planning: no glide back either.
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
	if not RunState.MACHINE_PHASES.has(run.phase):
		_end_return()


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
	pending_swaps.append_array(landing.upgraded)
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
	var reduced: bool = view.plan.reduced_motion if view.plan != null else false
	view.close()
	shown_swaps = UpgradeSwap.collapse(pending_swaps)
	pending_swaps = []
	run.next_shift()
	_screen._on_shift_started()
	UpgradeSwap.hold_old(shown_swaps, _screen.item_views())
	_start_return(reduced)


## The glide back to the store after the shift's last visit (the next shift already started),
## under `reduced` motion or not.
func _start_return(reduced: bool) -> void:
	_return_rm = reduced
	_return_t = 0.0
	_presses.begin()
	_show_return(0.0)


## The glide back ends (or a tap ends it): the store at 1x, the fore up, the machine dim.
func _end_return() -> void:
	if _return_t < 0.0:
		return
	_return_t = -1.0
	_presses.end()
	_show_return(MachinePlan.return_length(view.tuning, _return_rm))
	if not shown_swaps.is_empty():
		_swap_wait = 0.0
	returned.emit()


## The planning notice's pulse, when passing the shift earns the bonus ticket.
func _play_notice() -> void:
	var run: RunState = _screen.run
	if run == null or run.phase != RunState.Phase.PLANNING or run.machine == null:
		return
	if not run.machine.bonus_if_passed(run):
		return
	var monitor: MonitorView = _screen._monitor
	notice.play(
		_screen._inspection_tag, func() -> Control: return monitor.channel.pass_line(), _reduced()
	)


func _play_announce() -> void:
	var run: RunState = _screen.run
	if run == null or run.phase != RunState.Phase.PLANNING or run.machine == null:
		return
	if run.machine.boosted_if_passed(run):
		announce.show_tag(_announce_prints)


func _reduced() -> bool:
	return _screen.profile.reduced_motion()


## The store `t` seconds into the glide back: the camera, the cut's fade, the fore, the machine's
## light.
func _show_return(t: float) -> void:
	var tuning: MachineTuning = view.tuning
	var progress: float = MachinePlan.return_camera(tuning, t, _return_rm)
	if view.camera != null:
		view.camera.set_view(progress)
		view.camera.set_fade(MachinePlan.return_fade(tuning, t, _return_rm))
	var e: float = StoreCamera.ease_in_out(progress)
	_screen._stage.set_fore_drop(e, _return_rm, tuning.fore_drop_px)
	view.set_lit(MachinePlan.return_lit(tuning, t))


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
