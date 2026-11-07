extends SceneTree
## Dev tool: renders a model (GLB / FBX / packed scene) from the front, right, back and left.
##   xvfb-run godot --display-driver x11 --audio-driver Dummy --path . \
##     -s tools/render_model_views.gd -- <model> <out.png> [animation] [time_s]
## A GLB keeps its own materials; the first animation found plays when none is named.

const TILE: Vector2i = Vector2i(400, 600)

var _vps: Array[SubViewport] = []
var _frames: int = 0
var _out: String


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[1]
	var world: World3D = World3D.new()
	var model: Node3D = _load(args[0])
	var aabb: AABB = _bounds(model)
	var centre: Vector3 = aabb.get_center()
	var dist: float = maxf(aabb.size.y, aabb.size.x) * 1.9
	for i: int in 4:
		var vp: SubViewport = SubViewport.new()
		vp.size = TILE
		vp.world_3d = world
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		_vps.append(vp)
		var cam: Camera3D = Camera3D.new()
		var a: float = TAU * float(i) / 4.0
		cam.transform = Transform3D(Basis.IDENTITY, centre + Vector3(sin(a), 0.1, cos(a)) * dist).looking_at(centre)
		cam.fov = 40.0
		vp.add_child(cam)
		cam.current = true
	_vps[0].add_child(model)
	# MASK=1: show vertex colours (rig classification masks).
	if OS.get_environment("MASK") == "1":
		var vc: StandardMaterial3D = StandardMaterial3D.new()
		vc.vertex_color_use_as_albedo = true
		for mi: Node in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = vc
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	_vps[0].add_child(sun)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.28, 0.33)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = 0.7
	_vps[0].add_child(env)
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var ap: AnimationPlayer = players[0] as AnimationPlayer
		var list: PackedStringArray = ap.get_animation_list()
		var anim: String = args[2] if args.size() > 2 else (list[0] if not list.is_empty() else "")
		if anim != "":
			ap.play(anim)
			ap.seek(float(args[3]) if args.size() > 3 else 0.0, true)
			ap.pause()


func _load(path: String) -> Node3D:
	if path.ends_with(".fbx"):
		var fdoc: FBXDocument = FBXDocument.new()
		var fstate: FBXState = FBXState.new()
		fdoc.append_from_file(path, fstate)
		return fdoc.generate_scene(fstate) as Node3D
	if path.ends_with(".glb") or path.ends_with(".gltf"):
		var doc: GLTFDocument = GLTFDocument.new()
		var state: GLTFState = GLTFState.new()
		doc.append_from_file(path, state)
		return doc.generate_scene(state) as Node3D
	return (load(path) as PackedScene).instantiate() as Node3D


static func _bounds(n: Node3D) -> AABB:
	# Skinned characters: mesh bounds are in bind space; frame a standing person instead.
	if not n.find_children("*", "Skeleton3D", true, false).is_empty():
		return AABB(Vector3(-0.6, 0.0, -0.6), Vector3(1.2, 1.9, 1.2))
	var out: AABB = AABB()
	var first: bool = true
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var b: AABB = _xform(m) * m.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


static func _xform(n: Node3D) -> Transform3D:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 6:
		return false
	var out: Image = Image.create(TILE.x * 4, TILE.y, false, Image.FORMAT_RGB8)
	for i: int in 4:
		var img: Image = _vps[i].get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		out.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(i * TILE.x, 0))
	out.save_png(_out)
	return true
