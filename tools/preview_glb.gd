extends SceneTree
## Dev tool: renders a .glb from 4 sides into one PNG.
## godot --path . -s tools/preview_glb.gd -- <in.glb> <out.png>

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if doc.append_from_file(args[0], state) != OK:
		push_error("load failed")
		quit(1)
		return
	var model: Node = doc.generate_scene(state)
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.25, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.7
	env.environment = e
	stage.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	stage.add_child(sun)
	for i: int in 4:
		var copy: Node3D = (model.duplicate() as Node3D) if i > 0 else model as Node3D
		stage.add_child(copy)
		copy.position = Vector3(float(i) * 1.6 - 2.4, 0.0, 0.0)
		copy.rotation_degrees.y = 90.0 * float(i)
		if args.size() > 3:
			_add_joints(copy, args[3].to_float())
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0.0, 0.9 if args.size() > 2 else 0.0, 5.2)
	cam.fov = 40.0
	stage.add_child(cam)
	cam.current = true
	for _f: int in 8:
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(args[1])
	quit()


func _add_joints(parent: Node3D, k: float) -> void:
	var tool: GDScript = load("res://tools/import_hero.gd") as GDScript
	var joints: Dictionary = tool.call(&"fitted_joints", k)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 1.0, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	for id: StringName in joints:
		var m: MeshInstance3D = MeshInstance3D.new()
		var s: SphereMesh = SphereMesh.new()
		s.radius = 0.02
		s.height = 0.04
		s.material = mat
		m.mesh = s
		m.position = joints[id]
		parent.add_child(m)
