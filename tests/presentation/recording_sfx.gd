extends Sfx
## A test double for Sfx that records every sound and note it is asked to play, then plays them
## as Sfx does. Load it with preload("res://tests/presentation/recording_sfx.gd") and give it to
## the code under test in place of an Sfx (no class_name: tests/ is not exported). warm_up()
## records nothing.

## One entry per play: {"sound": String, "take": String, "pitch": float, "volume_db": float,
## "usec": int}: the name asked for, the file that played (a round-robin sound's take), and
## Time.get_ticks_usec() when it played.
var sounds: Array[Dictionary] = []
## One entry per play_note: {"index": int, "sound": String, "volume_db": float}, the sound being
## the note's file (bonus_00 to bonus_10).
var notes: Array[Dictionary] = []


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var entry: Dictionary = {
		"sound": sound,
		"take": next_take(sound),
		"pitch": pitch,
		"volume_db": volume_db,
		"usec": Time.get_ticks_usec(),
	}
	sounds.append(entry)
	super(sound, pitch, volume_db)


func play_note(index: int, volume_db: float = 0.0) -> void:
	notes.append({"index": index, "sound": Sfx.note_sound(index), "volume_db": volume_db})
	super(index, volume_db)


## The note indices played so far, in order.
func note_indices() -> Array[int]:
	var indices: Array[int] = []
	for entry: Dictionary in notes:
		indices.append(int(entry["index"]))
	return indices


## The names asked for so far, in order (round-robin sounds by their base name).
func sound_names() -> Array[String]:
	var names: Array[String] = []
	for entry: Dictionary in sounds:
		names.append(String(entry["sound"]))
	return names


## How many times `sound` was asked for.
func count(sound: String) -> int:
	return sound_names().count(sound)


## Forgets everything recorded so far.
func clear() -> void:
	sounds.clear()
	notes.clear()
