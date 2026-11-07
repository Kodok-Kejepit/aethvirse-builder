class_name FlagDoor
extends StaticBody3D
## A sealed slab that dissolves once a world flag is set (story / secret gating).

@export var required_flag: StringName = &""
@export var size: Vector3 = Vector3(3, 4, 0.6)
@export var color: Color = Color(0.2, 0.15, 0.3)

var _open: bool = false


func _ready() -> void:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color.lightened(0.3)
	mat.emission_energy_multiplier = 0.6
	bm.material = mat
	mesh.mesh = bm
	mesh.position.y = size.y * 0.5
	add_child(mesh)


func _process(_delta: float) -> void:
	if _open or Engine.get_process_frames() % 20 != 0:
		return
	if required_flag != &"" and GameState.has_flag(required_flag):
		_open = true
		Codex.notify(tr(&"CODEX_MSG_SEAL_OPENS"), &"anomaly")
		queue_free()
