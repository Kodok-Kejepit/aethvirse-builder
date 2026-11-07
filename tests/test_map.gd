extends GutTest
## Region map: fog of war, painting, save round trip.

var _map: RegionMap
var _saved_fog: Dictionary[String, PackedByteArray] = {}


func before_each() -> void:
	_saved_fog = GameState.map_fog.duplicate()
	GameState.map_fog.clear()
	_map = RegionMap.new()
	add_child_autofree(_map)
	_map.region = RegionData.load_region(&"r1_ashfall")


func after_each() -> void:
	GameState.map_fog = _saved_fog


func test_reveal_opens_cells_once() -> void:
	assert_eq(_map.explored_ratio(), 0.0)
	var opened: int = _map.reveal(Vector3.ZERO, RegionMap.REVEAL_RADIUS_M)
	assert_gt(opened, 0)
	assert_eq(_map.reveal(Vector3.ZERO, RegionMap.REVEAL_RADIUS_M), 0, "already explored")
	assert_gt(_map.explored_ratio(), 0.0)
	assert_lt(_map.explored_ratio(), 0.2)


func test_uv_covers_the_region() -> void:
	assert_eq(_map.to_uv(Vector3(-192, 0, -192)), Vector2.ZERO)
	assert_eq(_map.to_uv(Vector3(192, 0, 192)), Vector2.ONE)
	assert_eq(_map.cell_of(Vector3(500, 0, -500)), Vector2i(RegionMap.FOG_CELLS - 1, 0), "clamped")


func test_fog_survives_save() -> void:
	_map.reveal(Vector3(100, 0, 100), 30.0)
	var before: float = _map.explored_ratio()
	var json: String = JSON.stringify(GameState.to_dict())
	var prog: Progression = GameState.progression
	var parsed: Dictionary = JSON.parse_string(json)
	GameState.load_dict(parsed, load("res://data/balancing/stat_tuning.tres") as StatTuning)
	assert_almost_eq(_map.explored_ratio(), before, 0.0001)
	GameState.progression = prog


func test_painter_draws_blocks() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var b: GrayboxBlock = GrayboxBlock.new()
	b.size = Vector3(40, 2, 40)
	b.color = Color(1, 0, 0)
	root.add_child(b)
	var img: Image = MapPainter.paint(root, Rect2(-100, -100, 200, 200), 64)
	var center: Color = img.get_pixel(32, 32)
	assert_gt(center.r, 0.8, "block painted red at the centre")
	assert_lt(img.get_pixel(2, 2).r, 0.2, "background stays dark")
