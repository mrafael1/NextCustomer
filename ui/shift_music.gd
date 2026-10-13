class_name ShiftMusic
extends RefCounted
## The shift screen's music cues (#62, Q2, Q6), kept out of ShiftScreen so the screen stays
## under gdlint's file length: the shift loop while planning and counting, the front loop on the
## run's results. The count-up's dessert ducks the music (CountUp); these bring it back.

const SHIFT_MUSIC := &"shift"
const RESULTS_MUSIC := &"front"
## The music comes back over this when the dessert's duck ends (#62, Q6).
const UNDUCK_S := 0.6
## The final receipt ducks the music this far while its coins print, then brings it back
## after the last coin, and at the earliest COINS_PRINT_S after the coins start (#62, Q6).
const COINS_DUCK_DB := -18.0
const COINS_DUCK_S := 0.12
const COINS_PRINT_S := 1.0


## The shift screen opened: the title's first click (browsers need one) started the front
## loop, unless that click started the run, so this crossfades or starts the shift loop.
static func screen_opened(music: MusicService) -> void:
	music.play(SHIFT_MUSIC)


## A new run (the results' New run, the debug panel's replay or skip, or the screen's first
## run): back to the shift loop, at full level (no fade when it is there already).
static func new_run(music: MusicService) -> void:
	music.play(SHIFT_MUSIC)
	if music.is_ducked():
		music.unduck(UNDUCK_S)


## The reward print-out after a won shift (#61): the music comes back over UNDUCK_S at the
## dessert's printer feed, as the print-out appears.
static func rewards_shown(music: MusicService) -> void:
	music.unduck(UNDUCK_S)


## The win and lose screens: the music crossfades to the front loop, still ducked from the
## dessert. The final receipt ducks it for its coins (coins_printing).
static func results_shown(music: MusicService) -> void:
	music.play(RESULTS_MUSIC)


## The final receipt's coin lines print (ResultsPanel, #61): the music ducks to COINS_DUCK_DB
## while the coins clink, until `coins_s` from now (one gap after the last coin) and at least
## COINS_PRINT_S, then comes back. `duck` cancels a pending unduck, so it goes first.
static func coins_printing(music: MusicService, coins_s: float) -> void:
	music.duck(COINS_DUCK_DB, COINS_DUCK_S)
	music.unduck(UNDUCK_S, maxf(COINS_PRINT_S, coins_s))
