class_name Breakable
extends StaticBody3D
## A cracked wall/object. Only heavy attacks (or skills flagged heavy) break it.
## Emits `broken` and frees its collision; the owner reveals what was behind.

signal broken

@export var hits_to_break: int = 1
## Persistent flag set when broken (saved in GameState.world_flags), so it stays broken.
@export var save_flag: StringName = &""

@onready var hurtbox: HurtboxComponent = %Hurtbox
@onready var mesh: MeshInstance3D = %Mesh

var _hits: int = 0


func _ready() -> void:
	hurtbox.body = self
	hurtbox.hit_received.connect(_on_hit)
	if save_flag != &"" and GameState.has_flag(save_flag):
		_break(false)


func _on_hit(info: DamageInfo) -> void:
	if not info.is_heavy:
		AudioManager.play_sfx(&"hit")
		return
	_hits += 1
	if _hits >= hits_to_break:
		_break(true)


func _break(announce: bool) -> void:
	if save_flag != &"":
		GameState.set_flag(save_flag)
	collision_layer = 0
	hurtbox.set_deferred(&"monitorable", false)
	mesh.visible = false
	if announce:
		AudioManager.play_sfx(&"hit")
		broken.emit()
