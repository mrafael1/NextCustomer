class_name TitleOpeningTuning
extends Resource
## The title's opening (2026-11-13, mock-up title_opening.html, variant C "scanner sweep"): the
## sign sits dark for dark_s, then its scan beam (the hidden toy's sweep) crosses it in sweep_s
## and each tube lights as the line passes its centre (a full-halo flash of letter_flash_s); then
## the accepted scan's BEEP (beep_sound) and one blink of blink_s, the € tag lights, the sconce
## wedge and the reflections come on at half for glow_half_s, then full, and the plates step in
## plates_delay_s after the blink. It lives in data/balance/title_opening.tres so it can be tuned
## by feel without code changes; TitleScreen reads it and never hard-codes it. The defaults are
## neutral (0, no sound), like ScanTuning's, so a script edit can never silently change the tuned
## values in the file.

## Seconds the sign stays dark before the sweep starts.
@export var dark_s: float = 0.0
## Seconds the scan line takes across the sign (2 art px steps).
@export var sweep_s: float = 0.0
## Seconds a tube shows its full halo once over as the line lights it.
@export var letter_flash_s: float = 0.0
## Seconds the sign blinks off after the sweep, with the BEEP.
@export var blink_s: float = 0.0
## Seconds the wedge and the reflections show at half before full.
@export var glow_half_s: float = 0.0
## Seconds between the end of the blink and the first plate stepping in.
@export var plates_delay_s: float = 0.0
## The Sfx sound of the accepted scan (the register's scan beep), "" for none. Reduced motion
## plays only this sound, the sign lit from the first frame.
@export var beep_sound: String = ""
