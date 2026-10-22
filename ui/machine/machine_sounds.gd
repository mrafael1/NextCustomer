class_name MachineSounds
extends RefCounted
## The RECEIPT REWARDS machine's sounds (#77, build spec section 6): the existing #62 sounds and
## the note ladder, mapped from the approved page's placeholders, played as the visit's clock
## passes their moments on view.plan (cues), never while the clock jumps (a fast-forward, a
## resume, show_at): a jump plays nothing, as `skipping` beats do.
##
## - the receipt's (or the BONUS stub's) flight lands: `tick` x5 (x3), then `slot_tick` as it is
##   fed; the keys light: one ladder note each (C5 D5 E5 G5), staggered as the keys;
## - the chute confirmed: `ui_confirm` (CONFIRM › plays it as it is pressed, #77 machine v2);
##   each bay pick: a ladder note (C5 E5 G5) and `card_place`;
##   the belt: `rattle_s` as it starts, a `tick` every BELT_TICK while it moves; a box through the
##   RESTOCK curtain: `ui_switch`; PACKED: `stamp_1`; each box's lid tape: `rip`;
## - the reveals (reveal_sounds): COMMON one note and `tick`, RARE two rising notes (E5 A5),
##   LEGENDARY four (C5 E5 G5 C6) and `rattle_l`; every rarity keeps its sound under reduced
##   motion;
## - the pick: `ui_click` (a bin: `ui_back`); the landing: a new card `card_place`, a register
##   (or STAMP DAY's) `stamp_loyalty`, an upgrade's glint `ding` and G5 C6 E6; the punch:
##   `stamp_2`; the restock: a soft `card_place` per bay;
## - the BONUS TICKET's stamp: `stamp_notice` and the stub's `print`; STAMP DAY's: `stamp_paid`.
## The padlocked key's `denied` is the machine's own (RewardMachineView.press_key).
##
## Built by MachineFlyer (the landing's part), framed with it.

## Note indices on the ladder (Sfx.play_note): G4 A4 C5 D5 E5 G5 A5 C6 D6 E6 G6.
const C5 := 2
const D5 := 3
const E5 := 4
const G5 := 5
const A5 := 6
const C6 := 7
const E6 := 9
const KEY_NOTES: Array[int] = [C5, D5, E5, G5]
const BAY_NOTES: Array[int] = [C5, E5, G5]
const GLINT_NOTES: Array[int] = [G5, C6, E6]
## The feed's ticks: per visit kind (TICKET, BONUS, STAMP DAY), this far apart.
const FEED_TICKS: Array[int] = [5, 3, 0]
const TICK_GAP := 0.09
## The belt ticks this often while it moves (the page's placeholder).
const BELT_TICK := 0.18
## The notes of a RARE and a LEGENDARY reveal follow each other this far apart; an upgrade's glint
## notes this far.
const RARE_GAP := 0.12
const LEGENDARY_GAP := 0.1
const GLINT_GAP := 0.06
## Where in its reveal a rarity's sound lands, and where its lid's tape splits (oa x 0.45), as a
## share of the reveal (look F).
const REVEAL_SHARE: Array[float] = [0.6, 0.5, 0.55]
const TAPE_SHARE: Array[float] = [0.0, 0.09, 0.1575]
## The soft sounds' level (dB): the bay's thump, the restock, the belt's ticks.
const SOFT_DB := -8.0
const QUIET_DB := -14.0
## A frame never moves the clock further than this: a longer step is a jump, which plays nothing.
const MAX_STEP := 0.5
## A new visit's clock starts just after this, so its first frame (at 0) plays the cues at 0.
const FIRST_EPS := 0.001
const NOTE := &"note"
const SOUND := &"sound"
const SERIES := &"series"

## The machine whose clock this follows.
var view: RewardMachineView
## The cues of view.plan: [time, kind (NOTE, SOUND, SERIES), sound or note, volume_db or count],
## in time order.
var cues: Array[Array] = []
var _plan: MachinePlan
var _has_draw: bool = false
var _has_landing: bool = false
var _last: float = 0.0
## A beat fired with `skipping`: the next frame is a jump.
var _jumped: bool = false


func _init(machine: RewardMachineView) -> void:
	view = machine
	view.beat.connect(_on_beat)


## The sounds a reveal of `rarity` (MachinePrize.Rarity) plays: one per sound or note, in order
## (a note as "note:<index>"); they differ per rarity (the non-colour signal, build spec 9).
static func reveal_sounds(rarity: int) -> PackedStringArray:
	match rarity:
		MachinePrize.Rarity.RARE:
			return PackedStringArray(["note:%d" % E5, "note:%d" % A5])
		MachinePrize.Rarity.LEGENDARY:
			return PackedStringArray(
				["rattle_l", "note:%d" % C5, "note:%d" % E5, "note:%d" % G5, "note:%d" % C6]
			)
	return PackedStringArray(["tick", "note:%d" % C5])


## Plays the cues the clock passed since the last frame (none after a jump).
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan
	if plan == null:
		_plan = null
		return
	var first: bool = plan != _plan
	if first:
		_plan = plan
		_has_draw = false
		_has_landing = false
		_jumped = false
		# A new visit's cues at 0 (BONUS, STAMP DAY) play on its first frame, which is no jump;
		# a resumed one's start where it waits.
		_last = plan.start if plan.resumed else -FIRST_EPS
		cues = []
		_add_intro(plan)
	if plan.has_draw != _has_draw or plan.has_landing != _has_landing:
		# A resumed visit's segments, there when it is first seen, are the resume: silent. A
		# segment added after that is the player's confirm or press.
		_grow(plan, not (first and plan.resumed))
	if _jumped or t < _last or t - _last > MAX_STEP:
		_jumped = false
		_last = t
		return
	for cue: Array in cues:
		if float(cue[0]) > _last and float(cue[0]) <= t:
			_play(cue)
	_last = t


func _on_beat(_beat_name: StringName, _t0: float) -> void:
	if view.skipping:
		_jumped = true


## The plan grew (the draw, then the landing): the confirm or the press plays now (the clock
## holds at its wait point as the player acts) when `acted` (not a resume's segment), and the new
## segment's cues are added.
func _grow(plan: MachinePlan, acted: bool) -> void:
	var live: bool = acted and not _jumped and not view.skipping
	if plan.has_draw and not _has_draw:
		_has_draw = true
		if live and plan.kind != MachineVisit.Kind.STAMP_DAY and not view.confirm_played:
			_play([0.0, SOUND, "ui_confirm", 0.0])
		_add_draw(plan)
	if plan.has_landing and not _has_landing:
		_has_landing = true
		if live:
			var press: String = "ui_back" if plan.landing == MachinePlan.Landing.BIN else "ui_click"
			_play([0.0, SOUND, press, 0.0])
		_add_landing(plan)
	cues.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func _add_intro(plan: MachinePlan) -> void:
	match plan.kind:
		MachineVisit.Kind.BONUS:
			# The head's stamp lands as the bonus ticket reaches the slot (#77 machine v2).
			_cue(plan.fly_end, SOUND, "stamp_notice")
		MachineVisit.Kind.STAMP_DAY:
			_cue(0.0, SOUND, "stamp_paid")
			return
	if plan.snap >= 0.0:
		# The bonus stub snaps off the receipt, quietly (#77 machine v2).
		_cue(plan.snap, SOUND, "rip", view.tuning.snap_db)
	var ticks: int = FEED_TICKS[plan.kind]
	if not plan.reduced_motion:
		cues.append([plan.fly_end, SERIES, "tick", ticks])
	_cue(plan.feed_end, SOUND, "slot_tick")
	var stagger: int = view.tuning.key_stagger_ms
	if plan.kind == MachineVisit.Kind.BONUS:
		stagger = view.tuning.relight_stagger_ms
	for chute: int in RewardMachine.CHUTES:
		if _lit(chute):
			_cue(plan.lights + MachineTuning.sec(stagger * chute), NOTE, KEY_NOTES[chute])


func _add_draw(plan: MachinePlan) -> void:
	for index: int in range(plan.n_prizes):
		_cue(plan.picks[index], NOTE, BAY_NOTES[mini(index, BAY_NOTES.size() - 1)])
		_cue(plan.picks[index], SOUND, "card_place", SOFT_DB)
		if plan.run_from[index] >= 0.0:
			_cue(plan.run_from[index], SOUND, "ui_switch", QUIET_DB)
		var rarity: int = plan.rarities[index]
		var start: float = plan.reveal_at[index]
		var length: float = plan.reveal_length[index]
		_cue(start + length * TAPE_SHARE[rarity], SOUND, "rip", SOFT_DB)
		var at: float = start + length * REVEAL_SHARE[rarity]
		var gap: float = RARE_GAP if rarity == MachinePrize.Rarity.RARE else LEGENDARY_GAP
		var notes: int = 0
		for sound: String in reveal_sounds(rarity):
			if sound.begins_with("note:"):
				_cue(at + gap * notes, NOTE, int(sound.get_slice(":", 1)))
				notes += 1
			else:
				_cue(at, SOUND, sound)
	_cue(plan.packed, SOUND, "stamp_1")
	if plan.belt_from >= 0.0:
		var ramp: float = MachineTuning.sec(view.tuning.belt_ramp_up_ms)
		var stop: float = plan.belt_to + MachineTuning.sec(view.tuning.belt_ramp_down_ms)
		_cue(plan.belt_from - ramp, SOUND, "rattle_s", SOFT_DB)
		var at: float = plan.belt_from - ramp + BELT_TICK
		while at < stop:
			_cue(at, SOUND, "tick", QUIET_DB)
			at += BELT_TICK


func _add_landing(plan: MachinePlan) -> void:
	match plan.landing:
		MachinePlan.Landing.NEW_CARD:
			_cue(plan.land, SOUND, "card_place")
		MachinePlan.Landing.REGISTER:
			_cue(plan.land, SOUND, "stamp_loyalty")
		MachinePlan.Landing.UPGRADE:
			_cue(plan.glint, SOUND, "ding")
			for index: int in range(GLINT_NOTES.size()):
				_cue(plan.glint + GLINT_GAP * index, NOTE, GLINT_NOTES[index])
	if plan.rises and plan.kind != MachineVisit.Kind.STAMP_DAY:
		_cue(plan.punch, SOUND, "stamp_2")
	for at: float in plan.restock:
		_cue(at, SOUND, "card_place", QUIET_DB)


func _cue(at: float, kind: StringName, what: Variant, level: float = 0.0) -> void:
	cues.append([at, kind, what, level])


## Whether `chute`'s key lights on this visit (a lit chute: OPEN).
func _lit(chute: int) -> bool:
	if view.run == null:
		return false
	return view.run.machine.chute_info(view.run, chute).state == RewardMachine.ChuteState.OPEN


func _play(cue: Array) -> void:
	var sfx: Sfx = view.sfx
	if sfx == null or view.skipping:
		return
	match cue[1]:
		NOTE:
			sfx.play_note(int(cue[2]))
		SERIES:
			sfx.play_series(String(cue[2]), int(cue[3]), TICK_GAP)
		_:
			sfx.play(String(cue[2]), 1.0, float(cue[3]))
