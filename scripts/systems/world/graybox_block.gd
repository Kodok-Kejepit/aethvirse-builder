@tool
class_name GrayboxBlock
extends StaticBody3D
## Big Phase 1 level geometry: a box with collision + flat color. Replaced by art in Phase 2.

@export var size: Vector3 = Vector3(4, 4, 4):
	set(value):
		size = value
		_rebuild()
@export var color: Color = Color(0.5, 0.5, 0.55):
	set(value):
		color = value
		_rebuild()
@export var solid: bool = true

## Blocks at least this big (ground slabs) are always drawn.
const ALWAYS_VISIBLE_SIZE_M: float = 60.0
## Small blocks fade out at this share of the platform view distance.
const PROP_VIEW_SHARE: float = 0.4

var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh)
		_shape = CollisionShape3D.new()
		add_child(_shape)
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = _material_for(color)
	_mesh.mesh = box_mesh
	_apply_view_distance()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	_shape.shape = box_shape
	_shape.disabled = not solid


func _material_for(c: Color) -> Material:
	if Engine.is_editor_hint():
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		return m
	return WorldStreamer.shared_material(c, solid)


func _apply_view_distance() -> void:
	if Engine.is_editor_hint() or Settings.profile == null:
		return
	if maxf(size.x, size.z) >= ALWAYS_VISIBLE_SIZE_M:
		_mesh.visibility_range_end = 0.0
		return
	_mesh.visibility_range_end = Settings.profile.view_distance_m * PROP_VIEW_SHARE
	_mesh.visibility_range_end_margin = 10.0
	_mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
