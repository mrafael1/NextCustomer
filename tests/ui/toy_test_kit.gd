extends RefCounted
## Shared helpers for the TOY MACHINES tests (#63): the balance and its aisles, profiles with
## chosen items collected, the event log autoload and its events, and temporary folders (the
## real saves and playtest logs are never touched: every suite points both at its own folder).

const BALANCE := "res://data/balance/balance.tres"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)


static func balance() -> BalanceDefinition:
	return load(BALANCE)


static func aisle(from: BalanceDefinition, id: StringName) -> AisleDefinition:
	for found: AisleDefinition in from.aisles:
		if found.id == id:
			return found
	return null


## A profile with `coins` coins, `runs` runs ended, and the first `counts[aisle id]` capsule
## items of each named aisle (data order) collected at run index 0.
static func profile(coins: int, runs: int, counts: Dictionary = {}) -> ProfileState:
	var result: ProfileState = ProfileState.new()
	result.coins = coins
	result.run_count = runs
	var from: BalanceDefinition = balance()
	for id: Variant in counts:
		var cards: Array[CardDefinition] = aisle(from, StringName(str(id))).capsule_cards
		for index: int in range(mini(int(counts[id]), cards.size())):
			result.unlocked_items[cards[index].id] = 0
	return result


## Every capsule item of every aisle collected.
static func full_counts() -> Dictionary:
	var counts: Dictionary = {}
	for found: AisleDefinition in balance().aisles:
		counts[found.id] = found.capsule_cards.size()
	return counts


## The balance with only its first `count` aisles.
static func balance_with_aisles(count: int) -> BalanceDefinition:
	var copy: BalanceDefinition = balance().duplicate() as BalanceDefinition
	var aisles: Array[AisleDefinition] = []
	aisles.assign(copy.aisles.slice(0, count))
	copy.aisles = aisles
	return copy


static func event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")


static func events(folder: String, type: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for line: String in EventLogWriter.join_logs(folder).split("\n", false):
		var event: Dictionary = JSON.parse_string(line)
		if event["type"] == type:
			found.append(event)
	return found


static func remove(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for sub: String in DirAccess.get_directories_at(folder):
		remove(folder.path_join(sub))
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder)


static func left_click() -> InputEventMouseButton:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	return press


static func key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


## Every Label under `root` (visible or not).
static func labels(root: Node) -> Array[Label]:
	var found: Array[Label] = []
	for child: Node in root.find_children("*", "Label", true, false):
		found.append(child as Label)
	return found


## A control's on-screen rect (global, unrotated).
static func rect(control: Control) -> Rect2:
	return control.get_global_rect()
