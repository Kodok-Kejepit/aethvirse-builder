class_name SecretMarker
extends Node3D
## Debug-only label showing a secret's id where it lives (cheat `reveal_secrets`).

const GROUP: StringName = &"secret_markers"

@export var secret_id: StringName = &""

var _label: Label3D


func _ready() -> void:
	add_to_group(GROUP)
	if not OS.is_debug_build():
		return
	_label = Label3D.new()
	_label.text = String(secret_id)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0008
	_label.modulate = Color(1.0, 0.4, 1.0)
	_label.visible = false
	add_child(_label)


func set_revealed(value: bool) -> void:
	if _label != null:
		_label.visible = value
