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

## Small things are only drawn near the player: view range = height × this, at least
## MIN_VIEW_M, at most the preset's range for the model (buildings stay visible far away).
const VIEW_PER_METRE: float = 45.0
const MIN_VIEW_M: float = 60.0
## Lower than this (or flat floor pieces) casts no shadow: the shadow pass is the most
## expensive part of a frame, and a crate's shadow is not missed.
const SHADOW_MIN_HEIGHT_M: float = 1.2
const FLAT_PREFIXES: PackedStringArray = ["tile_", "floor_", "rubble_", "rock_pile"]

## One material per model: every copy shares it (fewer GPU state changes).
static var _materials: Dictionary[StringName, StandardMaterial3D] = {}


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
	mi.material_override = material_for(data)
	apply_view(mi, data, size_scale)
	add_child(mi)
	match data.collision:
		PropData.Collision.BOX:
			_box(data.size * size_scale)
		PropData.Collision.CONVEX:
			var cs: CollisionShape3D = CollisionShape3D.new()
			cs.shape = WorldStreamer.convex_for(prop_id, mi.mesh)
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
	mi.material_override = material_for(d)
	apply_view(mi, d, height / d.size.y)
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


static func material_for(d: PropData) -> StandardMaterial3D:
	if _materials.has(d.id):
		return _materials[d.id]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	if ResourceLoader.exists(d.albedo_path):
		mat.albedo_texture = load(d.albedo_path) as Texture2D
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[d.id] = mat
	return mat


## Distance culling by size and shadow casting by size / shape.
static func apply_view(mi: MeshInstance3D, d: PropData, scale_k: float) -> void:
	var height: float = d.size.y * scale_k
	if Settings.profile != null and d.view_share > 0.0:
		mi.visibility_range_end = view_range(height, Settings.profile.view_distance_m * d.view_share)
	if height < SHADOW_MIN_HEIGHT_M or is_flat(d.id):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func view_range(height: float, preset_range: float) -> float:
	return minf(maxf(height * VIEW_PER_METRE, MIN_VIEW_M), preset_range)


static func is_flat(id: StringName) -> bool:
	for prefix: String in FLAT_PREFIXES:
		if String(id).begins_with(prefix):
			return true
	return false
