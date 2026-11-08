class_name DebugPerf
extends RefCounted
## `perf` cheat (and `prologue`): what the frame costs right now (render counts, script time, and which
## node scripts are ticking every frame), printed to the console and stdout.
##   perf          frame cost
##   perf mesh     heaviest models near the camera (triangles × copies, full detail)
##   perf shadows  toggle sun shadows (to see what the shadow pass costs)
##   perf lod N    mesh LOD threshold (1 = default, higher = coarser)

const TOP_SCRIPTS: int = 8
const TOP_MESHES: int = 15
const MESH_RADIUS_M: float = 150.0


static func register() -> void:
	DebugConsole.register("prologue", _prologue, "prologue — show the New Game prologue again")
	DebugConsole.register("perf", _perf, "perf [mesh|shadows|lod N] — frame cost; mesh = heaviest models near the camera; shadows = toggle sun shadows; lod = mesh LOD threshold")


static func _prologue(_args: PackedStringArray) -> String:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	_tree().current_scene.add_child(layer)
	var prologue: Prologue = Prologue.new()
	layer.add_child(prologue)
	prologue.finished.connect(layer.queue_free)
	return "prologue"


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _perf(args: PackedStringArray) -> String:
	if args.size() > 0 and args[0] == "mesh":
		return _report(_heaviest_meshes())
	if args.size() > 0 and args[0] == "shadows":
		return _toggle_shadows()
	if args.size() > 1 and args[0] == "lod":
		_tree().root.mesh_lod_threshold = args[1].to_float()
		return "mesh LOD threshold %s" % args[1]
	var lines: PackedStringArray = []
	lines.append("fps %d · process %.2f ms · physics %.2f ms" % [
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	lines.append("draw calls %d · triangles %d · objects %d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	var counts: Dictionary[String, int] = {}
	var stats: Dictionary[String, int] = {"nodes": 0, "grass_tufts": 0, "particles": 0, "lights": 0}
	_walk(_tree().root, counts, stats)
	lines.append("nodes %d · grass tufts %d · particle systems %d · lights %d" % [
		stats["nodes"], stats["grass_tufts"], stats["particles"], stats["lights"]])
	lines.append("ticking: " + ", ".join(_top(counts, TOP_SCRIPTS)))
	return _report("\n".join(lines))


static func _report(out: String) -> String:
	print("[perf] " + out.replace("\n", "\n[perf] "))
	return out


static func _top(counts: Dictionary[String, int], n: int) -> PackedStringArray:
	var names: Array[String] = counts.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b])
	var out: PackedStringArray = []
	for i: int in mini(n, names.size()):
		out.append("%s ×%d" % [names[i], counts[names[i]]])
	return out


static func _walk(node: Node, counts: Dictionary[String, int], stats: Dictionary[String, int]) -> void:
	stats["nodes"] += 1
	var shown: bool = node is Node3D and (node as Node3D).is_visible_in_tree()
	if shown and node is MultiMeshInstance3D and node.get_script() != null:
		var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
		if mm != null:
			stats["grass_tufts"] += mm.instance_count
	if shown and (node is CPUParticles3D or node is GPUParticles3D):
		stats["particles"] += 1
	if shown and node is Light3D:
		stats["lights"] += 1
	var script: Script = node.get_script()
	if script != null and (node.is_processing() or node.is_physics_processing()):
		var key: String = script.resource_path.get_file().get_basename()
		counts[key] = counts.get(key, 0) + 1
	for child: Node in node.get_children():
		_walk(child, counts, stats)


static func _heaviest_meshes() -> String:
	var camera: Camera3D = _tree().root.get_camera_3d()
	if camera == null:
		return "no camera"
	var tris: Dictionary[String, int] = {}
	var copies: Dictionary[String, int] = {}
	_sum_meshes(_tree().root, camera.global_position, tris, copies)
	var total: int = 0
	for n: String in tris:
		total += tris[n]
	var lines: PackedStringArray = ["meshes within %d m: %d triangles (full detail)" % [MESH_RADIUS_M, total]]
	var names: Array[String] = tris.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return tris[a] > tris[b])
	for i: int in mini(TOP_MESHES, names.size()):
		lines.append("  %s ×%d: %d" % [names[i], copies[names[i]], tris[names[i]]])
	return "\n".join(lines)


static func _sum_meshes(node: Node, eye: Vector3, tris: Dictionary[String, int], copies: Dictionary[String, int]) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.is_visible_in_tree() and mi.mesh != null and mi.global_position.distance_to(eye) < MESH_RADIUS_M:
			var key: String = mi.mesh.resource_path.get_file() if mi.mesh.resource_path != "" else String(mi.get_parent().name).rstrip("0123456789")
			tris[key] = tris.get(key, 0) + triangles(mi.mesh)
			copies[key] = copies.get(key, 0) + 1
	for child: Node in node.get_children():
		_sum_meshes(child, eye, tris, copies)


static func triangles(mesh: Mesh) -> int:
	var count: int = 0
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] != null else PackedVector3Array()
		count += floori(float(index.size() if not index.is_empty() else verts.size()) / 3.0)
	return count


static func _toggle_shadows() -> String:
	var lights: Array[Node] = _tree().root.find_children("*", "DirectionalLight3D", true, false)
	for n: Node in lights:
		var light: DirectionalLight3D = n
		light.shadow_enabled = not light.shadow_enabled
	return "sun shadows toggled on %d lights" % lights.size()
