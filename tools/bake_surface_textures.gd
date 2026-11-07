extends SceneTree
## Bakes tiling surface textures from imported tile / wall models (owner's Meshy floors and
## walls): Meshy texture atlases are scrambled islands, so the albedo itself cannot tile.
## Each tile_* model is rendered unlit from straight above, each wall_* model straight from
## the front, with an orthographic camera fitted to the model; the picture becomes
## assets/textures/surfaces/<id>.jpg (used by Gate dungeons, GateTheme).
##   xvfb-run godot --display-driver x11 --path . -s tools/bake_surface_textures.gd

const OUT_DIR: String = "res://assets/textures/surfaces"
const PX: int = 1024
## Crop inside the model edges so bevels / sides never show.
const INSET: float = 0.16

var _ids: PackedStringArray = []
var _i: int = 0
var _wait: int = 0
var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D


func _initialize() -> void:
	for f: String in DirAccess.get_files_at("res://data/props"):
		var id: String = f.get_basename()
		if f.ends_with(".tres") and (id.begins_with("tile_") or id.begins_with("wall_")):
			_ids.append(id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_vp = SubViewport.new()
	_vp.size = Vector2i(PX, PX)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	_vp.add_child(env)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_cam.current = true
	_holder = Node3D.new()
	_vp.add_child(_holder)


func _show(id: String) -> void:
	for c: Node in _holder.get_children():
		c.free()
	var d: PropData = PropData.find(StringName(id))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = load(d.mesh_path) as Mesh
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = load(d.albedo_path) as Texture2D
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	_holder.add_child(mi)
	var box: AABB = mi.mesh.get_aabb()
	var c: Vector3 = box.get_center()
	# Look along the thinnest axis (some floor models were made standing upright).
	if id.begins_with("tile_") and box.size.y <= box.size.z:
		# Square crop of the top face.
		var side: float = minf(box.size.x, box.size.z) * (1.0 - INSET * 2.0)
		_cam.size = side
		_cam.transform = Transform3D(Basis.IDENTITY, c + Vector3(0, box.size.y + 5.0, 0)).looking_at(c, Vector3.FORWARD)
	else:
		# Front face (models face -Z), square crop of the middle.
		var side2: float = minf(box.size.x, box.size.y) * (1.0 - INSET * 2.0)
		_cam.size = side2
		_cam.transform = Transform3D(Basis.IDENTITY, c + Vector3(0, 0, -(box.size.z + 5.0))).looking_at(c, Vector3.UP)
	_cam.near = 0.05
	_cam.far = 100.0


func _process(_d: float) -> bool:
	if _i >= _ids.size():
		print("baked %d surface textures" % _ids.size())
		return true
	if _wait == 0:
		_show(_ids[_i])
	_wait += 1
	if _wait < 4:
		return false
	_wait = 0
	var im: Image = _vp.get_texture().get_image()
	im.convert(Image.FORMAT_RGB8)
	var path: String = "%s/%s.jpg" % [OUT_DIR, _ids[_i]]
	im.save_jpg(ProjectSettings.globalize_path(path), 0.9)
	print("%s -> %s" % [_ids[_i], path])
	_i += 1
	return false
