class_name BoosterFx
extends RefCounted
## YOUR STORE's effects (BoosterPage, v1.32): the sounds from audio/sfx (silent while a skip
## boosts an opening, except the RARE's notes), the cues on the page's clock, and the particles
## (dust, foil scraps, sparkles) on a seeded cosmetic stream.

var page: BoosterPage
## Cues, each {at (page clock, s), fn, tag}; particles, each a Dictionary in art px.
var cues: Array[Dictionary] = []
var parts: Array[Dictionary] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(owner_page: BoosterPage) -> void:
	page = owner_page
	rng.seed = 20261113


func clear() -> void:
	cues.clear()
	parts.clear()


## Runs every cue due by `now`, in time order.
func run_cues(now: float) -> void:
	cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at < b.at)
	while not cues.is_empty() and (cues[0].at as float) <= now:
		var due: Dictionary = cues.pop_front()
		(due.fn as Callable).call()


## Drops the cues whose tag starts with `prefix` (a skipped arrival: no late thuds).
func drop_cues(prefix: String) -> void:
	cues = cues.filter(func(c: Dictionary) -> bool: return not String(c.tag).begins_with(prefix))


## Drops the particles whose life is over.
func prune(now: float) -> void:
	parts = parts.filter(
		func(p: Dictionary) -> bool: return now - (p.t as float) < (p.life as float)
	)


func cue(at: float, fn: Callable, tag: String = "") -> void:
	cues.append({"at": at, "fn": fn, "tag": tag})


func sfx(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	for opening: BoosterOpening in page.boosters:
		if opening.boost > 1.0:
			return
	var player: Sfx = Sfx.find(page)
	if player != null:
		player.play(sound, pitch, volume_db)


## Note `index` of the ladder (`force`: even during a skip).
func note(index: int, volume_db: float, force: bool = false) -> void:
	if not force:
		for opening: BoosterOpening in page.boosters:
			if opening.boost > 1.0:
				return
	var player: Sfx = Sfx.find(page)
	if player != null:
		player.play(Sfx.note_sound(clampi(index, 0, 9)), 1.0, volume_db)


func dust(x: float, y: float, count: int) -> void:
	if page.rm:
		return
	for k: int in count:
		var side: float = 1.0 if k % 2 else -1.0
		parts.append(
			{
				"type": "dust",
				"x": x + side * (4 + k * 3),
				"y": y,
				"vx": side * (24 + rng.randf() * 20),
				"vy": -10 - rng.randf() * 10,
				"g": 0.0,
				"t": page.now,
				"life": 0.4
			}
		)


func scraps(x: float, y: float, ramp: Array[Color]) -> void:
	if page.rm:
		return
	var colours: Array[Color] = [
		Palette.PAPER, Palette.STEEL_HIGHLIGHT, ramp[0], Palette.GOLD, Palette.STEEL_LIGHT, ramp[1]
	]
	for k: int in 12:
		parts.append(
			{
				"type": "scrap",
				"x": x + (rng.randf() - 0.5) * 60,
				"y": y,
				"vx": (rng.randf() * 2 - 1) * 140,
				"vy": -160 - rng.randf() * 150,
				"g": 480.0,
				"t": page.now,
				"life": 0.7,
				"c": colours[k % colours.size()],
				"s": 4 + k % 3
			}
		)


func sparkles(x: float, y: float, w: float, h: float, t0: float, gap: float) -> void:
	var places: Array[Vector2] = [
		Vector2(x - 2, y + 6),
		Vector2(x + w - 4, y + 2),
		Vector2(x + w - 2, y + h - 10),
		Vector2(x - 4, y + h - 20)
	]
	for k: int in places.size():
		parts.append(
			{
				"type": "spark",
				"x": places[k].x,
				"y": places[k].y,
				"t": t0 + k * gap,
				"life": 0.15 + k * gap + 0.01
			}
		)
