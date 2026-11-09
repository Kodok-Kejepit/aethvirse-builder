class_name SequencePuzzle
extends Node3D
## A riddle answered by using its parts in the right order (owner's journal riddles: the
## neon signs that spell a word, the bells that play a lullaby). Each child PuzzlePart is
## used with the interact action; a wrong part resets the attempt. Solved state lives in a
## world flag, so it stays solved.

## Part ids in the right order (repeats allowed: bells).
@export var answer: PackedStringArray = []
@export var solved_flag: StringName = &""

var _entered: PackedStringArray = []


func _ready() -> void:
	for part: PuzzlePart in parts():
		part.used.connect(_on_used)
	if GameState.has_flag(solved_flag):
		_show_solved()


func _on_used(part_id: String) -> void:
	if GameState.has_flag(solved_flag):
		return
	_entered.append(part_id)
	var i: int = _entered.size() - 1
	if i >= answer.size() or answer[i] != part_id:
		_entered.clear()
		Codex.notify(tr(&"PUZZLE_RESET"), &"warning")
		return
	if _entered.size() == answer.size():
		GameState.set_flag(solved_flag)
		AudioManager.play_ui(&"ding")
		Codex.notify(tr(&"PUZZLE_SOLVED"), &"secret")
		_show_solved()


func _show_solved() -> void:
	for part: PuzzlePart in parts():
		part.light(true)


func parts() -> Array[PuzzlePart]:
	var out: Array[PuzzlePart] = []
	for n: Node in find_children("*", "", true, false):
		if n is PuzzlePart:
			out.append(n as PuzzlePart)
	return out
