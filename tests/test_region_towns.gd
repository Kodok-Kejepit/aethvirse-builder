extends GutTest
## Regions 2-6 are 5x5 chunks with a city and a village each (gen_region_towns.py).

const BIG: Array[StringName] = [&"r2_verdant", &"r3_dunes", &"r4_frostveil", &"r5_archive", &"r6_fracture"]
const TOWNS: Dictionary[StringName, Array] = {
	&"r2_verdant": [&"r2_greenreach", &"r2_thornfield"], &"r3_dunes": [&"r3_sandmere", &"r3_dustwell"],
	&"r4_frostveil": [&"r4_whitehold", &"r4_pinecrest"], &"r5_archive": [&"r5_lowmarket", &"r5_saltreed"],
	&"r6_fracture": [&"r6_shardhaven", &"r6_lantern"],
}

var _saved_fog: Dictionary[String, PackedByteArray] = {}


func before_each() -> void:
	_saved_fog = GameState.map_fog.duplicate()
	GameState.map_fog.clear()


func after_each() -> void:
	GameState.map_fog = _saved_fog


func test_big_regions_have_all_25_chunks() -> void:
	for rid: StringName in BIG:
		var region: RegionData = RegionData.load_region(rid)
		assert_eq(region.chunk_radius, 2, String(rid))
		assert_eq(region.half_extent_m(), 320.0)
		var dir: String = "res://scenes/world/chunks/%s" % String(rid).substr(0, 2)
		for x: int in range(-2, 3):
			for z: int in range(-2, 3):
				assert_true(ResourceLoader.exists("%s/chunk_%d_%d.tscn" % [dir, x, z]), "%s %d,%d" % [rid, x, z])
	assert_eq(RegionData.load_region(&"r1_ashfall").chunk_radius, 1, "Ashfall keeps its size")


func test_every_region_gained_a_city_and_a_village() -> void:
	for rid: StringName in TOWNS:
		var region: RegionData = RegionData.load_region(rid)
		for way: StringName in TOWNS[rid]:
			assert_true(region.waystones.has(way), "%s has %s" % [rid, way])
			assert_ne(tr(Waystone.name_key(way)), String(Waystone.name_key(way)), "%s has a name" % way)
			var at: Vector3 = region.waystones[way]
			assert_gt(maxf(absf(at.x), absf(at.z)), 192.0, "%s sits in the new outer ring" % way)
		assert_gte(region.max_world_gates, 3)
		assert_gte(region.gate_points.size(), 7)


func test_new_townsfolk_speak_both_languages() -> void:
	for nid: String in ["greenreach_warden", "dustwell_child", "whitehold_smith", "saltreed_diver", "lantern_scout"]:
		var npc: NpcData = load("res://data/dialogs/%s.tres" % nid) as NpcData
		assert_not_null(npc, nid)
		var line: StringName = npc.entries[0].lines[0]
		assert_ne(tr(line), String(line), "%s line translated" % nid)


func test_outer_ring_monsters_are_stronger_than_the_core() -> void:
	var core: PackedScene = load("res://scenes/world/chunks/r2/chunk_-1_1.tscn") as PackedScene
	var ring: PackedScene = load("res://scenes/world/chunks/r2/chunk_-2_2.tscn") as PackedScene
	assert_eq(_max_level(core), 0, "the core uses the region bonus")
	var lv: int = _max_level(ring)
	assert_gt(lv, 80, "far corner of Verdant Hollow")
	assert_lte(lv, 100, "never above the region's top")


func test_map_covers_the_bigger_region_and_keeps_old_fog() -> void:
	var old_map: RegionMap = RegionMap.new()
	add_child_autofree(old_map)
	# An explored spot from a save made while Verdant Hollow was 3x3 (key without a size).
	var old_grid: PackedByteArray = PackedByteArray()
	old_grid.resize(RegionMap.FOG_CELLS * RegionMap.FOG_CELLS)
	old_grid[16 * RegionMap.FOG_CELLS + 16] = 1
	GameState.map_fog["r2_verdant"] = old_grid
	var map: RegionMap = RegionMap.new()
	add_child_autofree(map)
	map.region = RegionData.load_region(&"r2_verdant")
	assert_eq(map.world_rect, Rect2(-320, -320, 640, 640))
	assert_eq(map.to_uv(Vector3(320, 0, 320)), Vector2.ONE)
	assert_gt(map.explored_ratio(), 0.0, "old explored cells carried over")
	var c: Vector2i = map.cell_of(Vector3(6, 0, 6))
	assert_eq(map.fog()[c.y * RegionMap.FOG_CELLS + c.x], 1, "the same place is still explored")
	assert_true(GameState.map_fog.has(map.fog_key()))


func _max_level(scene: PackedScene) -> int:
	var state: SceneState = scene.get_state()
	var best: int = 0
	for n: int in state.get_node_count():
		for p: int in state.get_node_property_count(n):
			if state.get_node_property_name(n, p) == &"level":
				var v: int = state.get_node_property_value(n, p)
				best = maxi(best, v)
	return best
