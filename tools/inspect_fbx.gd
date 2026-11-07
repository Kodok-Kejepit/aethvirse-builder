extends SceneTree
@warning_ignore_start("integer_division")
## Dev tool: prints skeleton bones, meshes and animations of an FBX/GLB.
##   godot --headless --path . -s tools/inspect_fbx.gd -- <file>

func _initialize() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var doc: GLTFDocument = FBXDocument.new() if path.to_lower().ends_with(".fbx") else GLTFDocument.new()
	var state: GLTFState = FBXState.new() if path.to_lower().ends_with(".fbx") else GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("cannot read")
		quit(1)
		return
	var root: Node = doc.generate_scene(state)
	_walk(root, 0)
	quit()


func _walk(n: Node, depth: int) -> void:
	var extra: String = ""
	if n is Skeleton3D:
		var sk: Skeleton3D = n
		var names: PackedStringArray = PackedStringArray()
		for i: int in sk.get_bone_count():
			names.append(sk.get_bone_name(i))
		extra = " bones=%d %s" % [sk.get_bone_count(), ", ".join(names)]
	elif n is MeshInstance3D:
		var mi: MeshInstance3D = n
		var arr: Array = mi.mesh.surface_get_arrays(0)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		extra = " tris=%d verts=%d weights/vert=%d aabb=%s pos=%s skin=%s" % [idx.size() / 3, v.size(), w.size() / maxi(v.size(), 1), mi.mesh.get_aabb().size, mi.mesh.get_aabb().position, mi.skin != null]
	elif n is AnimationPlayer:
		var ap: AnimationPlayer = n
		var lst: PackedStringArray = PackedStringArray()
		for a: StringName in ap.get_animation_list():
			lst.append("%s(%.2fs)" % [a, ap.get_animation(a).length])
		extra = " anims: " + ", ".join(lst)
		for a: StringName in ap.get_animation_list():
			var anim: Animation = ap.get_animation(a)
			for t: int in anim.get_track_count():
				if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and String(anim.track_get_path(t)).ends_with("Hips"):
					var k: int = anim.track_get_key_count(t)
					print("   %s hips %s -> %s" % [a, anim.track_get_key_value(t, 0), anim.track_get_key_value(t, k - 1)])
	if depth < 4 or extra != "":
		print("  ".repeat(depth), n.name, " [", n.get_class(), "]", extra)
	for c: Node in n.get_children():
		_walk(c, depth + 1)
