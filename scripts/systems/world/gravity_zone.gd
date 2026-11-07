class_name GravityZone
extends Area3D
## The Fracture: inside this box the player's gravity is scaled (light = huge jumps,
## heavy = jumps barely leave the ground).

@export var size: Vector3 = Vector3(20, 20, 20)
@export_range(0.1, 3.0) var gravity_factor: float = 0.35
@export var tint: Color = Color(0.6, 0.8, 1.0, 0.08)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = tint
	bm.material = mat
	mesh.mesh = bm
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node3D) -> void:
	var player: Player = body as Player
	if player != null:
		player.gravity_scale = gravity_factor
		Codex.notify(tr(&"CODEX_MSG_GRAVITY_LIGHT" if gravity_factor < 1.0 else &"CODEX_MSG_GRAVITY_HEAVY"), &"anomaly")


func _on_exit(body: Node3D) -> void:
	var player: Player = body as Player
	if player != null:
		player.gravity_scale = 1.0
