class_name Interactable
extends Area3D
## Something the player can use with the interact action (E / D-pad up / touch button).
## Owners connect `interacted` and set `prompt_key` (translation key) and `enabled`.

signal interacted(player: Player)

const LAYER_BIT: int = 32  # physics layer 6 "interactable"

@export var prompt_key: StringName = &"PROMPT_INTERACT"
## Extra text after the prompt (e.g. an NPC name). Not translated.
@export var subject: String = ""
@export var enabled: bool = true
## Higher wins when several are in range.
@export var interact_priority: int = 0


func _ready() -> void:
	collision_layer = LAYER_BIT
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_prompt() -> String:
	var text: String = tr(prompt_key)
	return "%s %s" % [text, subject] if subject != "" else text


func interact(player: Player) -> void:
	if enabled:
		interacted.emit(player)
