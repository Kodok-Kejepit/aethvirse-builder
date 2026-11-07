class_name SecretArea
extends Area3D
## A named zone for IN_AREA conditions ("sec_r1_01_pump_room").

@export var area_id: StringName = &""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player body
	monitoring = true
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			EventBus.secret_area_entered.emit(area_id))
	body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			EventBus.secret_area_exited.emit(area_id))
