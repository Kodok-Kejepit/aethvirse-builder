extends SceneTree
## Imports a Meshy-rigged hero from GLB files (one rigged base + one GLB per animation):
##   godot --headless --path . -s tools/import_hero_glb.gd -- <out_dir> <id> <base.glb> \
##       Name=<anim.glb> [Name=<anim.glb> ...]
## - Renames Meshy bones to mixamo names (mixamorig_Hips ...) so AnimatedBody, the gear
##   joints and Mixamo clips all fit; Mixamo-named clips (mixamorig:X) map onto them too.
## - Every clip keeps only rotations (+ the hips height), so clips made on another hero
##   with the same rig can be shared without changing body proportions; forward root
##   motion is removed; jump clips lose the hip rise (physics lifts the body).
## - Hair and cloth get their own chains (HeroLooseRig) for spring physics in game.
## - Saves <out_dir>/<id>_rig.scn and <id>_rig_albedo.jpg; chains in meta "hair_chains".

const TEX_PX: int = 2048
const MESHY_TO_MIXAMO: Dictionary[String, String] = {
	"Hips": "Hips", "Spine02": "Spine", "Spine01": "Spine1", "Spine": "Spine2", "neck": "Neck",
	"Head": "Head", "head_end": "HeadTop_End",
	"LeftShoulder": "LeftShoulder", "LeftArm": "LeftArm", "LeftForeArm": "LeftForeArm", "LeftHand": "LeftHand",
	"RightShoulder": "RightShoulder", "RightArm": "RightArm", "RightForeArm": "RightForeArm", "RightHand": "RightHand",
	"LeftUpLeg": "LeftUpLeg", "LeftLeg": "LeftLeg", "LeftFoot": "LeftFoot", "LeftToeBase": "LeftToeBase",
	"RightUpLeg": "RightUpLeg", "RightLeg": "RightLeg", "RightFoot": "RightFoot", "RightToeBase": "RightToeBase",
}
const LOOPING: Array[String] = ["Idle", "Walking", "Running", "IdleAlt"]
const NO_HIP_RISE: Array[String] = ["Jump", "JumpRun", "RunLeap"]


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = a[0]
	var id: String = a[1]
	var scene: Node3D = _load(a[2])
	root.add_child(scene)
	var skel: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mi: MeshInstance3D = skel.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	_rename_bones(skel)
	for i: int in skel.get_bone_count():
		print("bone %s <- %s" % [skel.get_bone_name(i), skel.get_bone_name(skel.get_bone_parent(i)) if skel.get_bone_parent(i) >= 0 else "-"])
	var player: AnimationPlayer = _fresh_player(scene, skel)
	var lib: AnimationLibrary = player.get_animation_library(&"")
	var skel_path: String = str(player.get_node(player.root_node).get_path_to(skel))
	var hips_rest_y: float = skel.get_bone_rest(skel.find_bone("mixamorig_Hips")).origin.y
	for i2: int in range(3, a.size()):
		var pair: PackedStringArray = a[i2].split("=", true, 1)
		var anim: Animation = _clip(pair[1], skel_path, pair[0], hips_rest_y)
		if anim != null:
			lib.add_animation(StringName(pair[0]), anim)
	var albedo: Image = _albedo(mi)
	var rig: HeroLooseRig = HeroLooseRig.new(skel, mi)
	rig.build(OS.get_environment("ASC_HAIR_MASK") == "1")
	print("loose vertices %d, chains %d" % [rig.loose_count, rig.chains.size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var tex_path: String = "%s/%s_rig_albedo.jpg" % [out_dir, id]
	if albedo != null:
		if albedo.get_width() > TEX_PX:
			albedo.resize(TEX_PX, TEX_PX, Image.INTERPOLATE_LANCZOS)
		albedo.convert(Image.FORMAT_RGB8)
		albedo.save_jpg(ProjectSettings.globalize_path(tex_path), 0.9)
	scene.set_meta(&"hair_chains", rig.chains)
	_own(scene, scene)
	var packed: PackedScene = PackedScene.new()
	packed.pack(scene)
	var scene_path: String = "%s/%s_rig.scn" % [out_dir, id]
	ResourceSaver.save(packed, scene_path, ResourceSaver.FLAG_COMPRESS)
	print("saved %s anims %s" % [scene_path, lib.get_animation_list()])
	quit()


func _load(path: String) -> Node3D:
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("cannot read " + path)
		return null
	return doc.generate_scene(state) as Node3D


static func _mixamo(bone: String) -> String:
	var b: String = bone.trim_prefix("mixamorig:").trim_prefix("mixamorig_")
	if bone.begins_with("mixamorig"):
		return "mixamorig_" + b
	return "mixamorig_" + MESHY_TO_MIXAMO[b] if MESHY_TO_MIXAMO.has(b) else bone


func _rename_bones(skel: Skeleton3D) -> void:
	for i: int in skel.get_bone_count():
		skel.set_bone_name(i, _mixamo(skel.get_bone_name(i)))


## Replaces whatever player the base file had with an empty one holding a "" library.
func _fresh_player(scene: Node3D, _skel: Skeleton3D) -> AnimationPlayer:
	for old: Node in scene.find_children("*", "AnimationPlayer", true, false):
		old.get_parent().remove_child(old)
		old.free()
	var player: AnimationPlayer = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	scene.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library(&"", AnimationLibrary.new())
	return player


## First clip of an animation GLB, retargeted by bone name onto our skeleton path.
func _clip(path: String, skel_path: String, clip_name: String, hips_rest_y: float) -> Animation:
	var src: Node3D = _load(path)
	if src == null:
		return null
	var players: Array[Node] = src.find_children("*", "AnimationPlayer", true, false)
	var src_skel: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	if players.is_empty():
		src.free()
		return null
	var sp: AnimationPlayer = players[0] as AnimationPlayer
	var anim: Animation = sp.get_animation(sp.get_animation_list()[0]).duplicate(true) as Animation
	var src_hips: int = -1
	for i: int in src_skel.get_bone_count():
		if _mixamo(src_skel.get_bone_name(i)) == "mixamorig_Hips":
			src_hips = i
	var src_hips_y: float = src_skel.get_bone_rest(src_hips).origin.y if src_hips >= 0 else hips_rest_y
	src.free()
	var t: int = anim.get_track_count() - 1
	while t >= 0:
		var np: NodePath = anim.track_get_path(t)
		var bone: String = _mixamo(str(np.get_concatenated_subnames()))
		var kind: Animation.TrackType = anim.track_get_type(t)
		var keep: bool = kind == Animation.TYPE_ROTATION_3D or (kind == Animation.TYPE_POSITION_3D and bone == "mixamorig_Hips")
		if not keep or np.get_subname_count() == 0:
			anim.remove_track(t)
		else:
			anim.track_set_path(t, NodePath("%s:%s" % [skel_path, bone]))
			if kind == Animation.TYPE_POSITION_3D:
				_fix_hips(anim, t, hips_rest_y / maxf(src_hips_y, 0.001), clip_name in NO_HIP_RISE)
		t -= 1
	anim.loop_mode = Animation.LOOP_LINEAR if clip_name in LOOPING else Animation.LOOP_NONE
	return anim


## Hips: keep the first x/z (no forward root motion), scale height to this body, and for
## jumps drop the rise entirely.
static func _fix_hips(anim: Animation, t: int, ratio: float, flat: bool) -> void:
	var first: Vector3 = anim.track_get_key_value(t, 0)
	for k: int in anim.track_get_key_count(t):
		var v: Vector3 = anim.track_get_key_value(t, k)
		var y: float = (first.y if flat else v.y) * ratio
		anim.track_set_key_value(t, k, Vector3(first.x * ratio, y, first.z * ratio))


static func _albedo(mi: MeshInstance3D) -> Image:
	var mat: BaseMaterial3D = mi.mesh.surface_get_material(0) as BaseMaterial3D
	if mat == null and mi.get_surface_override_material(0) != null:
		mat = mi.get_surface_override_material(0) as BaseMaterial3D
	if mat == null or mat.albedo_texture == null:
		return null
	return mat.albedo_texture.get_image()


func _own(node: Node, owner_node: Node) -> void:
	for c: Node in node.get_children():
		c.owner = owner_node
		_own(c, owner_node)
