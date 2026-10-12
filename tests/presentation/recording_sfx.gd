extends Sfx
## A test double for Sfx that records every sound and note it is asked to play, then plays them
## as Sfx does. Load it with preload("res://tests/presentation/recording_sfx.gd") and give it to
## the code under test in place of an Sfx (no class_name: tests/ is not exported).

## One entry per play: {"sound": String, "pitch": float, "volume_db": float, "usec": int}, the
## last being Time.get_ticks_usec() when it played.
var sounds: Array[Dictionary] = []
## One entry per play_note: {"index": int, "volume_db": float}.
var notes: Array[Dictionary] = []


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	sounds.append(
		{"sound": sound, "pitch": pitch, "volume_db": volume_db, "usec": Time.get_ticks_usec()}
	)
	super(sound, pitch, volume_db)


func play_note(index: int, volume_db: float = 0.0) -> void:
	notes.append({"index": index, "volume_db": volume_db})
	super(index, volume_db)


## The note indices played so far, in order.
func note_indices() -> Array[int]:
	var indices: Array[int] = []
	for entry: Dictionary in notes:
		indices.append(int(entry["index"]))
	return indices
