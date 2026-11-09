extends GutTest
## Journal riddles: parts used in the right order set the solved flag; a wrong part resets.

const TUNING: StatTuning = preload("res://data/balancing/stat_tuning.tres")

var puzzle: SequencePuzzle
var parts: Dictionary[String, PuzzlePart] = {}


func before_each() -> void:
	GameState.player = null
	GameState.new_game(&"vanguard", TUNING)
	puzzle = SequencePuzzle.new()
	puzzle.answer = PackedStringArray(["small", "big", "big", "medium"])
	puzzle.solved_flag = &"test_bells"
	parts.clear()
	for id: String in ["small", "medium", "big"]:
		var part: PuzzlePart = PuzzlePart.new()
		part.part_id = id
		part.style = &"bell"
		puzzle.add_child(part)
		parts[id] = part
	add_child_autofree(puzzle)


func _play(ids: Array[String]) -> void:
	for id: String in ids:
		parts[id].used.emit(id)


func test_right_order_solves() -> void:
	_play(["small", "big", "big", "medium"])
	assert_true(GameState.has_flag(&"test_bells"))


func test_wrong_part_resets_the_attempt() -> void:
	_play(["small", "medium"])
	assert_false(GameState.has_flag(&"test_bells"))
	_play(["small", "big", "big", "medium"])
	assert_true(GameState.has_flag(&"test_bells"), "a fresh attempt still works")


func test_every_r1_riddle_has_data_and_clues() -> void:
	var db: SecretDatabase = SecretDatabase.new()
	for id: StringName in [&"SEC-R1-03", &"SEC-R1-04", &"PZ-R1-01", &"PZ-R1-02", &"MC-R1-03", &"SI-R1-04", &"SM-R1-03:1"]:
		var s: SecretData = db.get_secret(id)
		assert_not_null(s, String(id))
		assert_gte(s.hints.size(), 2, "%s needs two clues" % id)
