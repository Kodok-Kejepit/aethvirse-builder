class_name State
extends Node
## Base state for StateMachine. States request changes by emitting `transitioned`.

@warning_ignore("unused_signal")
signal transitioned(next_state: StringName)


func enter(_previous: StringName) -> void:
	pass


func exit() -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
