extends Node
## Open-world chunk streaming (§7): keeps the chunks around the player loaded.
## A region scene calls configure(); chunk files are <dir>/chunk_<x>_<z>.tscn.

const CHUNK_SIZE_M: float = ChunkMath.CHUNK_SIZE_M
const UPDATE_INTERVAL_S: float = 0.5
## Extra ring kept loaded before unloading (avoids thrashing at borders).
const UNLOAD_MARGIN: int = 1

var _loaded_chunks: Dictionary[Vector2i, Node3D] = {}
var _loading: Dictionary[Vector2i, String] = {}
var _root: Node3D = null
var _dir: String = ""
var _timer: float = 0.0
var radius_override: int = -1


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
	"8c8780": 2,                          # CONCRETE
	"52545c": 7,                          # ASPHALT (ruined: cracks, moss, potholes)
	"598073": 3,                          # TENT
	"9e8573": 4, "737a8c": 4, "596b7a": 4, # STONE, ROCK, WATERSTONE
	"523d2e": 5, "664c38": 5, "6b4c38": 5, # BARK, ROOT, SHELF
	"805940": 6,                          # RUST
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
	return _loaded_chunks.has(ChunkMath.chunk_of(player.global_position)) and _loading.is_empty()


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
		if not _loaded_chunks.has(coord) and not _loading.has(coord) and ResourceLoader.exists(chunk_path(coord)):
			_loading[coord] = chunk_path(coord)
			ResourceLoader.load_threaded_request(chunk_path(coord))
	for coord: Vector2i in _loaded_chunks.keys():
		if maxi(absi(coord.x - center.x), absi(coord.y - center.y)) > r + UNLOAD_MARGIN:
			_loaded_chunks[coord].queue_free()
			_loaded_chunks.erase(coord)


func _poll_loading() -> void:
	for coord: Vector2i in _loading.keys():
		var path: String = _loading[coord]
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_loading.erase(coord)
			_instantiate(coord, ResourceLoader.load_threaded_get(path) as PackedScene)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading.erase(coord)


func _instantiate(coord: Vector2i, scene: PackedScene) -> void:
	if scene == null or _loaded_chunks.has(coord) or not is_active():
		return
	var chunk: Node3D = scene.instantiate() as Node3D
	chunk.position = Vector3(coord.x * CHUNK_SIZE_M, 0.0, coord.y * CHUNK_SIZE_M)
	_root.add_child(chunk)
	_loaded_chunks[coord] = chunk
