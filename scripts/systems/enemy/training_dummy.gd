class_name TrainingDummy
extends StaticBody3D
## Immortal target that shows last hit and DPS. Never attacks.

const DPS_WINDOW_S: float = 4.0

@onready var health: HealthComponent = %Health
@onready var hurtbox: HurtboxComponent = %Hurtbox
@onready var label: Label3D = %InfoLabel
@onready var body_mesh: MeshInstance3D = %BodyMesh

var _hits: Array[Vector2] = []  # x = time, y = damage
var _flash_material: StandardMaterial3D


func _ready() -> void:
	hurtbox.body = self
	health.damaged.connect(_on_damaged)
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1, 1, 1, 0)
	body_mesh.material_overlay = _flash_material
	add_to_group(LockOnTargeter.GROUP)
	_refresh(0, false)


func is_lockable() -> bool:
	return true


func get_lock_point() -> Vector3:
	return global_position + Vector3.UP * 1.1


func _on_damaged(info: DamageInfo) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	_hits.append(Vector2(now, info.amount))
	_flash_material.albedo_color.a = 0.85
	create_tween().tween_property(_flash_material, ^"albedo_color:a", 0.0, 0.12)
	_refresh(info.amount, info.is_crit)


func _refresh(last: int, crit: bool) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	_hits = _hits.filter(func(h: Vector2) -> bool: return now - h.x <= DPS_WINDOW_S)
	var total: float = 0.0
	for h: Vector2 in _hits:
		total += h.y
	label.text = "Training Dummy\nlast %d%s · DPS %.0f" % [last, " CRIT" if crit else "", total / DPS_WINDOW_S]
