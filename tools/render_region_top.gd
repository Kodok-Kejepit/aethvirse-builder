extends SceneTree
## Dev tool: orthographic top-down picture of a region's chunks (layout check).
##   xvfb-run godot --display-driver x11 --audio-driver Dummy --path . \
##     -s tools/render_region_top.gd -- res://scenes/world/chunks/r1 out.png 200 1600
## Args: <chunk_dir> <out.png> <half_extent_m> [pixels]. View-distance culling is switched
## off so small pieces show too.

var _vp: SubViewport
var _frames: int = 0
var _args: PackedStringArray


func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	var px: int = int(_args[3]) if _args.size() > 3 else 1600
	_vp = SubViewport.new()
	_vp.size = Vector2i(px, px)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(_args[2]) * 2.0
	cam.far = 500.0
	cam.transform = Transform3D(Basis.IDENTITY, Vector3(0, 120, 0)).looking_at(Vector3.ZERO, Vector3.FORWARD)
	_vp.add_child(cam)
	cam.current = true
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	_vp.add_child(sun)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.1, 0.12)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = 0.6
	_vp.add_child(env)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		# Autoloads are ready now; no view-distance culling for the overview.
		root.get_node("Settings").set("profile", null)
		for f: String in DirAccess.get_files_at(_args[0]):
			if not f.ends_with(".tscn"):
				continue
			var parts: PackedStringArray = f.get_basename().split("_")
			var chunk: Node3D = (load(_args[0] + "/" + f) as PackedScene).instantiate() as Node3D
			chunk.position = Vector3(float(parts[1]) * 128.0, 0.0, float(parts[2]) * 128.0)
			_vp.add_child(chunk)
	if _frames < 12:
		return false
	var image: Image = _vp.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png(_args[1])
	return true
