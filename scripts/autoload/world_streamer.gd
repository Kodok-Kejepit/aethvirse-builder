extends Node
## Open-world chunk streaming (§7): keeps the chunks around the player loaded.
## A region scene calls configure(); chunk files are <dir>/chunk_<x>_<z>.tscn.

const CHUNK_SIZE_M: float = ChunkMath.CHUNK_SIZE_M
const UPDATE_INTERVAL_S: float = 0.5
## Extra ring kept loaded before unloading (avoids thrashing at borders).
const UNLOAD_MARGIN: int = 1

var _loaded_chunks: Dictionary[Vector2i, Node3D] = {}
var _loading: Dictionary[Vector2i, String] = {}
## Chunk scene loaded, its models still loading on worker threads: coord -> [scene, paths].
var _waiting: Dictionary[Vector2i, Array] = {}
## Models / textures loaded ahead for streamed chunks (AssetPrefetch), kept while a chunk
## that uses them is in the world.
var _assets: Dictionary[String, Resource] = {}
var _asset_users: Dictionary[String, int] = {}
var _asset_loading: Dictionary[String, bool] = {}
var _chunk_assets: Dictionary[Vector2i, PackedStringArray] = {}
var _root: Node3D = null
var _dir: String = ""
var _timer: float = 0.0
var radius_override: int = -1

## Chunk batching stats for the `perf` cheat.
var batched_parts: int = 0
var batch_ms_max: float = 0.0

## A chunk entered the world (RegionMap paints it).
signal chunk_loaded(coord: Vector2i, chunk: Node3D)


## One material per graybox color + kind (thousands of blocks share a handful of materials).
## Kind comes from the colour: non-solid blue = water, non-solid green = leaves, else surface.
const SURFACE_SHADER: Shader = preload("res://assets/shaders/world_surface.gdshader")
const GROUND_SHADER: Shader = preload("res://assets/shaders/ruin_ground.gdshader")
const SURFACES: String = "res://assets/textures/surfaces/%s.jpg"
## Palette colours drawn with the ruined-ground shader (owner's baked tiles):
## [paving tile, paved share, overgrowth, wetness].
const GROUNDS: Dictionary[String, Array] = {
	"614a33": ["tile_dirt", 0.12, 0.55, 0.2],              # DIRT: camp / lots / open ground
}
## Palette colours drawn with the procedural pavement shader: mode (0 concrete slabs,
## 1 asphalt) and overgrowth.
const PAVEMENT_SHADER: Shader = preload("res://assets/shaders/pavement.gdshader")
const PAVEMENTS: Dictionary[String, Vector2] = {
	"52545c": Vector2(1, 0.35),   # ASPHALT: roads
	"827d78": Vector2(0, 0.3),    # SIDEWALK: kerbs, building aprons
}
const WATER_SHADER: Shader = preload("res://assets/shaders/water.gdshader")
const FOLIAGE_SHADER: Shader = preload("res://assets/shaders/foliage.gdshader")

var _materials: Dictionary[String, Material] = {}
var _styled: Array[ShaderMaterial] = []


## Night factor for lit windows (EnvironmentController calls this every frame).
func set_night(value: float) -> void:
	for m: ShaderMaterial in _styled:
		m.set_shader_parameter(&"night", value)


## Palette colours of the world generators -> surface pattern (world_surface.gdshader `style`).
const STYLES: Dictionary[String, int] = {
	"736b7a": 1,                          # BUILDING
	"6b7066": 1, "a88c6b": 1, "808594": 1, "758085": 1, "61547a": 1,  # region city facades
	"8c8780": 2,                          # CONCRETE
	"52545c": 7,                          # ASPHALT (ruined: cracks, moss, potholes)
	"598073": 3,                          # TENT
	"9e8573": 4, "737a8c": 4, "596b7a": 4, # STONE, ROCK, WATERSTONE
	"523d2e": 5, "664c38": 5, "6b4c38": 5, # BARK, ROOT, SHELF
	"805940": 6,                          # RUST
}


## Region city facades (gen_region_towns.py): [moss amount, lit window share at night,
## roof / ledge colour, how much of it]. Inhabited towns light far more windows than the
## dead Ashfall towers; desert and rift towns grow no moss, Whitehold's roofs hold snow.
const BUILDING_LOOKS: Dictionary[String, Array] = {
	"6b7066": [1.0, 0.4, Color(0.3, 0.42, 0.24), 0.5],    # Greenreach: overgrown
	"a88c6b": [0.0, 0.45, Color(0.82, 0.7, 0.52), 0.55],  # Sandmere: sand on the ledges
	"808594": [0.15, 0.55, Color(0.88, 0.91, 0.96), 0.9], # Whitehold: snowy roofs
	"758085": [0.6, 0.45, Color(0.4, 0.46, 0.44), 0.3],   # Lowmarket: damp stone
	"61547a": [0.0, 0.3, Color(0.62, 0.5, 0.85), 0.35],   # Shardhaven: rift glow
}


static func style_for(color: Color) -> int:
	return STYLES.get(color.to_html(false), 0)


static func surface_kind(color: Color, solid: bool) -> StringName:
	if not solid and color.b > color.r + 0.04 and color.b >= color.g - 0.05:
		return &"water"
	if not solid and color.g > color.r + 0.05 and color.g > color.b:
		return &"leaves"
	return &"surface"


func shared_material(color: Color, solid: bool = true) -> Material:
	var ground: Material = _ground_material(color)
	if ground != null:
		return ground
	var kind: StringName = surface_kind(color, solid)
	var key: String = "%s:%s" % [kind, color.to_html()]
	if _materials.has(key):
		return _materials[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	match kind:
		&"water":
			m.shader = WATER_SHADER
			m.set_shader_parameter(&"deep_color", Color(color.darkened(0.35), 0.88))
			m.set_shader_parameter(&"shallow_color", Color(color.lightened(0.3), 0.75))
		&"leaves":
			m.shader = FOLIAGE_SHADER
			m.set_shader_parameter(&"base_color", color.darkened(0.15))
			m.set_shader_parameter(&"tip_color", color.lightened(0.25))
			m.set_shader_parameter(&"height_ref", 1.5)
			m.set_shader_parameter(&"sway", 0.12)
		_:
			m.shader = SURFACE_SHADER
			m.set_shader_parameter(&"base_color", color)
			m.set_shader_parameter(&"top_color", _top_for(color))
			var style: int = style_for(color)
			m.set_shader_parameter(&"style", style)
			if style != 0:
				m.set_shader_parameter(&"top_amount", 0.15)
			if style == 1 and ResourceLoader.exists(SURFACES % "tile_roots_grass"):
				m.set_shader_parameter(&"tex_moss", load(SURFACES % "tile_roots_grass"))
				m.set_shader_parameter(&"has_moss", true)
			var look: Array = BUILDING_LOOKS.get(color.to_html(false), [])
			if not look.is_empty():
				var moss_amount: float = look[0]
				var lit: float = look[1]
				var roof: Color = look[2]
				var roof_amount: float = look[3]
				m.set_shader_parameter(&"moss_amount", moss_amount)
				m.set_shader_parameter(&"lit_share", lit)
				m.set_shader_parameter(&"top_color", roof)
				m.set_shader_parameter(&"top_amount", roof_amount)
			_styled.append(m)
	_materials[key] = m
	return m


func _ground_material(color: Color) -> Material:
	var html: String = color.to_html(false)
	if PAVEMENTS.has(html):
		return _pavement_material(html)
	if not GROUNDS.has(html):
		return null
	var key: String = "ground:" + html
	if _materials.has(key):
		return _materials[key]
	var spec: Array = GROUNDS[html]
	var paving: String = spec[0]
	if not ResourceLoader.exists(SURFACES % paving) or not ResourceLoader.exists(SURFACES % "tile_dirt"):
		return null
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter(&"tex_asphalt", load(SURFACES % paving))
	m.set_shader_parameter(&"tex_dirt", load(SURFACES % "tile_dirt"))
	m.set_shader_parameter(&"tex_mud", load(SURFACES % "tile_mud"))
	m.set_shader_parameter(&"tex_grass", load(SURFACES % "tile_roots_grass"))
	m.set_shader_parameter(&"paved", spec[1])
	m.set_shader_parameter(&"overgrowth", spec[2])
	m.set_shader_parameter(&"wetness", spec[3])
	_materials[key] = m
	return m


func _pavement_material(html: String) -> Material:
	var key: String = "pavement:" + html
	if _materials.has(key):
		return _materials[key]
	var spec: Vector2 = PAVEMENTS[html]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = PAVEMENT_SHADER
	m.set_shader_parameter(&"mode", int(spec.x))
	m.set_shader_parameter(&"overgrowth", spec.y)
	m.set_shader_parameter(&"tex_dirt", load(SURFACES % "tile_dirt"))
	m.set_shader_parameter(&"tex_moss", load(SURFACES % "tile_roots_grass"))
	_materials[key] = m
	return m


## Upward faces: greener on green ground, paler crust on sand/stone, white on snow.
static func _top_for(c: Color) -> Color:
	if c.g > c.r + 0.05 and c.g > c.b:
		return c.lightened(0.18).lerp(Color(0.4, 0.62, 0.3), 0.3)
	if c.v > 0.7 and c.s < 0.2:
		return Color(0.8, 0.85, 0.93)
	return c.lightened(0.12)


func _exit_tree() -> void:
	_convex.clear()
	_materials.clear()
	_styled.clear()


func configure(chunks_root: Node3D, chunk_dir: String) -> void:
	clear()
	_root = chunks_root
	_dir = chunk_dir
	_root.tree_exiting.connect(clear)


func clear() -> void:
	_loaded_chunks.clear()
	_loading.clear()
	_waiting.clear()
	_assets.clear()
	_asset_users.clear()
	_chunk_assets.clear()
	_root = null
	_dir = ""


func get_loaded_chunk_count() -> int:
	return _loaded_chunks.size()


func is_active() -> bool:
	return _root != null and is_instance_valid(_root)


## True once the player's own chunk is in and nothing near it is still loading.
func is_ready_around_player() -> bool:
	if not is_active():
		return true
	var player: Node3D = GameState.player
	if player == null or not is_instance_valid(player):
		return false
	return _loaded_chunks.has(ChunkMath.chunk_of(player.global_position)) and _loading.is_empty() and _waiting.is_empty()


## Collision hull per prop model, built once and shared by every copy.
var _convex: Dictionary[StringName, Shape3D] = {}


func convex_for(prop_id: StringName, mesh: Mesh) -> Shape3D:
	if not _convex.has(prop_id):
		_convex[prop_id] = mesh.create_convex_shape(true, true)
	return _convex[prop_id]




func chunk_path(coord: Vector2i) -> String:
	return _dir.path_join("chunk_%d_%d.tscn" % [coord.x, coord.y])


func radius() -> int:
	if radius_override >= 0:
		return radius_override
	return Settings.profile.chunk_load_radius if Settings.profile != null else 1


## Loads the chunk under `position` (and its neighbours) synchronously, e.g. before spawning.
func load_around_now(position: Vector3) -> void:
	for coord: Vector2i in ChunkMath.wanted(ChunkMath.chunk_of(position), 1):
		_instantiate(coord, load(chunk_path(coord)) as PackedScene if ResourceLoader.exists(chunk_path(coord)) else null)


func _process(delta: float) -> void:
	_poll_assets()
	if not is_active():
		return
	_poll_loading()
	_timer += delta
	if _timer < UPDATE_INTERVAL_S:
		return
	_timer = 0.0
	var player: Node3D = GameState.player
	if player == null or not is_instance_valid(player):
		return
	var center: Vector2i = ChunkMath.chunk_of(player.global_position)
	var r: int = radius()
	for coord: Vector2i in ChunkMath.wanted(center, r):
		if not _loaded_chunks.has(coord) and not _loading.has(coord) and not _waiting.has(coord) \
				and ResourceLoader.exists(chunk_path(coord)):
			_loading[coord] = chunk_path(coord)
			ResourceLoader.load_threaded_request(chunk_path(coord))
	for coord: Vector2i in _loaded_chunks.keys():
		if maxi(absi(coord.x - center.x), absi(coord.y - center.y)) > r + UNLOAD_MARGIN:
			_loaded_chunks[coord].queue_free()
			_loaded_chunks.erase(coord)
			_release_assets(coord)


func _poll_loading() -> void:
	for coord: Vector2i in _loading.keys():
		var path: String = _loading[coord]
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_loading.erase(coord)
			var scene: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
			if scene != null:
				_prefetch(coord, scene)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading.erase(coord)
	for coord: Vector2i in _waiting.keys():
		var entry: Array = _waiting[coord]
		var paths: PackedStringArray = entry[1]
		var all_in: bool = true
		for p: String in paths:
			if _asset_loading.has(p):
				all_in = false
				break
		if all_in:
			_waiting.erase(coord)
			var waiting_scene: PackedScene = entry[0]
			_instantiate(coord, waiting_scene)
			if _loaded_chunks.has(coord):
				_hold_assets(coord, paths)


## Starts worker-thread loads for the models a streamed chunk will use.
func _prefetch(coord: Vector2i, scene: PackedScene) -> void:
	var paths: PackedStringArray = AssetPrefetch.paths_for(scene)
	for p: String in paths:
		if _assets.has(p) or _asset_loading.has(p):
			continue
		if ResourceLoader.has_cached(p):
			_assets[p] = load(p)
		elif ResourceLoader.load_threaded_request(p) == OK:
			_asset_loading[p] = true
	_waiting[coord] = [scene, paths]


func _poll_assets() -> void:
	for p: String in _asset_loading.keys():
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(p)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_asset_loading.erase(p)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var res: Resource = ResourceLoader.load_threaded_get(p)
			if is_active():
				_assets[p] = res


func _hold_assets(coord: Vector2i, paths: PackedStringArray) -> void:
	_chunk_assets[coord] = paths
	for p: String in paths:
		_asset_users[p] = _asset_users.get(p, 0) + 1


func _release_assets(coord: Vector2i) -> void:
	if not _chunk_assets.has(coord):
		return
	for p: String in _chunk_assets[coord]:
		var n: int = _asset_users.get(p, 1) - 1
		if n <= 0:
			_asset_users.erase(p)
			_assets.erase(p)
		else:
			_asset_users[p] = n
	_chunk_assets.erase(coord)


func _batch(chunk: Node3D) -> void:
	if not is_instance_valid(chunk) or not chunk.is_inside_tree():
		return
	var t0: int = Time.get_ticks_usec()
	batched_parts += ChunkBatcher.batch(chunk)
	batch_ms_max = maxf(batch_ms_max, (Time.get_ticks_usec() - t0) / 1000.0)


func _instantiate(coord: Vector2i, scene: PackedScene) -> void:
	if scene == null or _loaded_chunks.has(coord) or not is_active():
		return
	var chunk: Node3D = scene.instantiate() as Node3D
	chunk.position = Vector3(coord.x * CHUNK_SIZE_M, 0.0, coord.y * CHUNK_SIZE_M)
	_root.add_child(chunk)
	# Next frame: trees settle on the terrain (deferred) before their parts are merged.
	_batch.call_deferred(chunk)
	_loaded_chunks[coord] = chunk
	chunk_loaded.emit(coord, chunk)
