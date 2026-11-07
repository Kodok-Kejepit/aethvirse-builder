class_name PropInstance
extends StaticBody3D
## Places an imported PropData model (toon material, collision, view range). If the asset
## has not been imported yet, shows a graybox stand-in of `fallback_size` instead.

@export var prop_id: StringName = &""
@export var fallback_size: Vector3 = Vector3(2, 2, 2)
@export var fallback_color: Color = Color(0.5, 0.5, 0.55)
## Uniform scale on top of the imported size.
@export var size_scale: float = 1.0
## Scale the imported model so its height matches `fallback_size.y` (slot size).
@export var fit_height: bool = true

var data: PropData = null


func _ready() -> void:
	data = PropData.find(prop_id)
	if data == null or not ResourceLoader.exists(data.mesh_path):
		_fallback()
		return
	if fit_height and data.size.y > 0.001:
		size_scale *= fallback_size.y / data.size.y
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = load(data.mesh_path) as Mesh
	mi.scale = Vector3.ONE * size_scale
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	if ResourceLoader.exists(data.albedo_path):
		mat.albedo_texture = load(data.albedo_path) as Texture2D
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	if Settings.profile != null and data.view_share > 0.0:
		mi.visibility_range_end = Settings.profile.view_distance_m * data.view_share
	add_child(mi)
	match data.collision:
		PropData.Collision.BOX:
			_box(data.size * size_scale)
		PropData.Collision.CONVEX:
			var cs: CollisionShape3D = CollisionShape3D.new()
			cs.shape = mi.mesh.create_convex_shape(true, true)
			cs.scale = mi.scale
			add_child(cs)


func _fallback() -> void:
	var block: GrayboxBlock = GrayboxBlock.new()
	block.size = fallback_size * size_scale
	block.color = fallback_color
	block.position.y = block.size.y * 0.5
	add_child(block)


func _box(s: Vector3) -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var b: BoxShape3D = BoxShape3D.new()
	b.size = s
	cs.shape = b
	cs.position.y = s.y * 0.5
	add_child(cs)


## Replaces procedural dressing with an imported model when one exists (tree_oak,
## prop_barrel, ...). Adds the model scaled to `height` under `parent`. Returns false if none.
static func attach_model(parent: Node3D, model_id: StringName, height: float) -> bool:
	var d: PropData = PropData.find(model_id)
	if d == null or not ResourceLoader.exists(d.mesh_path) or d.size.y <= 0.001:
		return false
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = load(d.mesh_path) as Mesh
	mi.scale = Vector3.ONE * (height / d.size.y)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	if ResourceLoader.exists(d.albedo_path):
		mat.albedo_texture = load(d.albedo_path) as Texture2D
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	if Settings.profile != null and d.view_share > 0.0:
		mi.visibility_range_end = Settings.profile.view_distance_m * d.view_share
	parent.add_child(mi)
	return true


## Shows an imported model in place of a placeholder mesh (chests, waystones): the model
## becomes a child of the placeholder with its base on the floor, so anything that moves
## the placeholder (shakes, tweens) moves the model. Returns false if the model is missing.
static func replace_mesh(placeholder: MeshInstance3D, model_id: StringName, height: float) -> bool:
	var holder: Node3D = Node3D.new()
	holder.position = Vector3(0.0, -placeholder.position.y, 0.0)
	placeholder.add_child(holder)
	if not attach_model(holder, model_id, height):
		holder.queue_free()
		return false
	placeholder.mesh = null
	return true
