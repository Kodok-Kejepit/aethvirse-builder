extends SceneTree
## Imports a Mixamo-rigged, animated hero FBX (owner's Meshy rig) for the game:
##   godot --headless --path . -s tools/import_rigged_hero.gd -- <fbx> <albedo.png> <out_dir> <id>
## - Moves hair off the arm/body bones: vertices far from the body bones
##   (see hero_pipeline/hair_rig.gd) get their own bone chains hanging from the head, simulated at runtime by SpringBone.
## - Strips forward root motion (gameplay moves the character).
## - Saves <out_dir>/<id>_rig.scn (Armature/Skeleton3D/Body + AnimationPlayer) and the
##   albedo as <id>_rig_albedo.jpg. Chain list goes into the scene's meta "hair_chains".

const TEX_PX: int = 2048


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var doc: FBXDocument = FBXDocument.new()
	var state: FBXState = FBXState.new()
	if doc.append_from_file(a[0], state) != OK:
		push_error("cannot read fbx")
		quit(1)
		return
	var scene: Node3D = doc.generate_scene(state) as Node3D
	root.add_child(scene)
	var skel: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mi: MeshInstance3D = skel.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var img: Image = Image.load_from_file(a[1])
	var hair: HeroHairRig = HeroHairRig.new(skel, mi)
	hair.build(OS.get_environment("ASC_HAIR_MASK") == "1")
	var chains: Array = hair.chains
	print("loose vertices %d" % hair.loose_count)
	_strip_root_motion(player)
	var out_dir: String = a[2]
	var id: String = a[3]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	img.resize(TEX_PX, TEX_PX, Image.INTERPOLATE_LANCZOS)
	var tex_path: String = "%s/%s_rig_albedo.jpg" % [out_dir, id]
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(ProjectSettings.globalize_path(tex_path), 0.9)
	var imp: FileAccess = FileAccess.open(ProjectSettings.globalize_path(tex_path + ".import"), FileAccess.WRITE)
	imp.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\n\nsource_file="%s"\n\n[params]\n\ncompress/mode=2\nmipmaps/generate=true\ndetect_3d/compress_to=0\n' % tex_path)
	scene.set_meta(&"hair_chains", chains)
	_own(scene, scene)
	var packed: PackedScene = PackedScene.new()
	packed.pack(scene)
	var scene_path: String = "%s/%s_rig.scn" % [out_dir, id]
	ResourceSaver.save(packed, scene_path, ResourceSaver.FLAG_COMPRESS)
	print("saved %s: %d hair chains, anims %s" % [scene_path, chains.size(), player.get_animation_list()])
	quit()


func _own(node: Node, owner_node: Node) -> void:
	for c: Node in node.get_children():
		c.owner = owner_node
		_own(c, owner_node)


## Forward root motion (Sprint, Weapon_Combo) is removed: hips keep their first x/z.
## The jump's hip rise is removed too (game physics lifts the body).
static func _strip_root_motion(player: AnimationPlayer) -> void:
	for lib_name: StringName in player.get_animation_library_list():
		var lib: AnimationLibrary = player.get_animation_library(lib_name)
		for anim_name: StringName in lib.get_animation_list():
			var anim: Animation = lib.get_animation(anim_name)
			anim.loop_mode = Animation.LOOP_NONE if anim_name in [&"Regular_Jump", &"Weapon_Combo"] else Animation.LOOP_LINEAR
			for t: int in anim.get_track_count():
				if anim.track_get_type(t) != Animation.TYPE_POSITION_3D or not String(anim.track_get_path(t)).ends_with("Hips"):
					continue
				var first: Vector3 = anim.track_get_key_value(t, 0)
				var keep_y: bool = anim_name != &"Regular_Jump"
				for k: int in anim.track_get_key_count(t):
					var v: Vector3 = anim.track_get_key_value(t, k)
					anim.track_set_key_value(t, k, Vector3(first.x, v.y if keep_y else first.y, first.z))


