class_name MetroEntrance
extends Node3D
## Street entrance of the ruined metro: a concrete pavilion with a canopy, a rolling
## shutter jammed half open over the dark stairwell and a METRO sign. Using it takes the
## player down to the station (MetroStation); the way back up returns here.
## The front faces +Z.

const WIDTH_M: float = 6.0
const DEPTH_M: float = 9.0
const WALL_H: float = 3.0

var _concrete: StandardMaterial3D


func _ready() -> void:
	_concrete = StandardMaterial3D.new()
	_concrete.albedo_color = Color(0.5, 0.49, 0.47)
	_concrete.roughness = 0.92
	var half_w: float = WIDTH_M * 0.5
	var half_d: float = DEPTH_M * 0.5
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.4, WALL_H, DEPTH_M), Vector3(side * half_w, WALL_H * 0.5, 0.0), _concrete)
	_box(Vector3(WIDTH_M, WALL_H, 0.4), Vector3(0.0, WALL_H * 0.5, -half_d), _concrete)
	_box(Vector3(WIDTH_M + 1.4, 0.3, DEPTH_M + 1.6), Vector3(0.0, WALL_H + 0.15, 0.4), _concrete)
	# Dark stairwell behind a shutter stuck half open.
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.015, 0.015, 0.02)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(Vector3(WIDTH_M - 0.4, WALL_H - 0.2, 0.1), Vector3(0.0, (WALL_H - 0.2) * 0.5, half_d - 0.6), dark, false)
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color(0.38, 0.33, 0.29)
	steel.metallic = 0.6
	steel.roughness = 0.55
	_box(Vector3(WIDTH_M - 0.4, 1.3, 0.12), Vector3(0.0, WALL_H - 0.65, half_d - 0.4), steel, false)
	var label: Label3D = Label3D.new()
	label.text = tr(&"METRO_SIGN")
	label.font_size = 96
	label.outline_size = 12
	label.modulate = Color(0.85, 0.92, 1.0)
	label.position = Vector3(0.0, WALL_H + 0.75, half_d + 1.2)
	add_child(label)
	var use: Interactable = Interactable.new()
	use.prompt_key = &"PROMPT_METRO_DOWN"
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 2.4
	cs.shape = sphere
	use.add_child(cs)
	use.position = Vector3(0.0, 1.0, half_d + 0.6)
	add_child(use)
	use.interacted.connect(_go_down)


func _box(box_size: Vector3, pos: Vector3, mat: Material, collide: bool = true) -> void:
	var holder: Node3D = StaticBody3D.new() if collide else Node3D.new()
	holder.position = pos
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	mi.material_override = mat
	holder.add_child(mi)
	if collide:
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = box_size
		shape.shape = box
		holder.add_child(shape)
	add_child(holder)


## The street spot just outside the shutter (where the player comes back up).
func street_spot() -> Vector3:
	return global_position + global_basis.z * (DEPTH_M * 0.5 + 2.5) + Vector3.UP * 0.3


func _go_down(_player: Player) -> void:
	GameState.interior_return = street_spot()
	SaveManager.autosave()
	LoadingScreen.go(get_tree(), MetroStation.SCENE)
