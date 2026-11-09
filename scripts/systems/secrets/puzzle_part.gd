class_name PuzzlePart
extends Node3D
## One usable piece of a SequencePuzzle: a neon shop sign with a switch, or a hanging bell
## (bell size tells its tone). Glows briefly when used, stays lit once solved.

signal used(part_id: String)

@export var part_id: String = ""
## Translation key shown above it (shop name, "small bell", ...).
@export var label_key: StringName = &""
## &"neon" or &"bell".
@export var style: StringName = &"neon"
## Bells: 0.6 small (high) .. 1.3 big (low).
@export var bell_size: float = 1.0
@export var color: Color = Color(1.0, 0.3, 0.6)

var _mat: StandardMaterial3D = null


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color.darkened(0.6)
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 0.15
	var mesh: MeshInstance3D = MeshInstance3D.new()
	if style == &"bell":
		var bell: CylinderMesh = CylinderMesh.new()
		bell.top_radius = 0.18 * bell_size
		bell.bottom_radius = 0.5 * bell_size
		bell.height = 0.8 * bell_size
		mesh.mesh = bell
		mesh.position = Vector3(0, 2.4 - 0.4 * bell_size, 0)
		_mat.albedo_color = Color(0.55, 0.42, 0.2)
		_mat.metallic = 0.8
		_mat.roughness = 0.35
	else:
		var plate: BoxMesh = BoxMesh.new()
		plate.size = Vector3(1.6, 0.6, 0.12)
		mesh.mesh = plate
		mesh.position = Vector3(0, 2.6, 0)
		var post: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.18, 0.5, 0.12)
		post.mesh = box
		post.position = Vector3(0, 1.1, 0.1)
		add_child(post)
	mesh.material_override = _mat
	add_child(mesh)
	var text: Label3D = Label3D.new()
	text.text = tr(label_key)
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.font_size = 36
	text.outline_size = 8
	text.position = Vector3(0, 3.3, 0)
	add_child(text)
	var area: Interactable = Interactable.new()
	area.prompt_key = &"PROMPT_RING" if style == &"bell" else &"PROMPT_SWITCH"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 1.4
	shape.shape = sphere
	shape.position = Vector3(0, 1.2, 0)
	area.add_child(shape)
	add_child(area)
	area.interacted.connect(func(_p: Player) -> void:
		_flash()
		used.emit(part_id))


func _flash() -> void:
	AudioManager.play_ui(&"ding")
	_mat.emission_energy_multiplier = 3.0
	create_tween().tween_property(_mat, ^"emission_energy_multiplier", 0.15, 0.6)


func light(on: bool) -> void:
	_mat.emission_energy_multiplier = 1.6 if on else 0.15
