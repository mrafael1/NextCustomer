class_name PuzzlePlay
extends RefCounted
## The hand-offs between the title's puzzle board and the shift screen (#183): the board's PLAY
## asks for a puzzle shift (request) before the shift screen opens, which takes it (take) instead of
## its run save; the puzzle's BOARD asks the next title to open its board (request_board); a solve
## that completes a pack asks the board to shine it once (note_completed). Like
## TitleScreen.request_lit, the requests live until taken.

const LIST := "res://data/puzzles/puzzle_list.tres"

static var _puzzle: StringName = &""
static var _last: StringName = &""
static var _board: bool = false
static var _completed: int = 0


## The board's PLAY: the next shift screen plays the puzzle `puzzle_id`.
static func request(puzzle_id: StringName) -> void:
	_puzzle = puzzle_id
	_last = puzzle_id


## The puzzle played now (NEXT's): the board opens on it.
static func note(puzzle_id: StringName) -> void:
	_last = puzzle_id


## The puzzle asked for last (the board opens on it), &"" before any.
static func last_played() -> StringName:
	return _last


## The puzzle asked for since the last take (&"": none); clears it.
static func take() -> StringName:
	var asked: StringName = _puzzle
	_puzzle = &""
	return asked


## The puzzle's BOARD: the next title opens on the puzzle board.
static func request_board() -> void:
	_board = true


## Whether the board was asked for since the last take; clears it.
static func take_board() -> bool:
	var asked: bool = _board
	_board = false
	return asked


## A solve completed pack `number`: the board shines it the next time it opens.
static func note_completed(number: int) -> void:
	_completed = number


## The pack completed since the last take (0: none); clears it.
static func take_completed() -> int:
	var number: int = _completed
	_completed = 0
	return number


## The game's puzzle list.
static func list() -> PuzzleList:
	return load(LIST)
