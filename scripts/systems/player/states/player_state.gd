class_name PlayerState
extends State
## Base for player states; `player` is injected by Player before the machine starts.

const IDLE: StringName = &"Idle"
const MOVE: StringName = &"Move"
const AIR: StringName = &"Air"
const DODGE: StringName = &"Dodge"
const ATTACK: StringName = &"Attack"
const HURT: StringName = &"Hurt"
const DEAD: StringName = &"Dead"

var player: Player


## Shared ground transitions. Returns true if a transition was requested.
func try_ground_transitions() -> bool:
	if not player.is_on_floor():
		transitioned.emit(AIR)
		return true
	if player.consume_jump():
		player.start_jump()
		transitioned.emit(AIR)
		return true
	if player.consume_dodge():
		transitioned.emit(DODGE)
		return true
	if player.combat.consume_attack():
		transitioned.emit(ATTACK)
		return true
	return false
