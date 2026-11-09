class_name RegionData
extends Resource
## Region definition: name, level range, tracker totals, weather, scene, waystones, Gate table.

@export var id: StringName = &""
@export var display_name: StringName = &""
@export var level_min: int = 1
@export var level_max: int = 10
## Added to monsters that have no level of their own here (regions whose monsters were
## made for the old 1-100 curve, until they are reworked like Region 1).
@export var enemy_level_bonus: int = 0
## Totals shown by the vague tracker ("Secrets 3/13 · Sealed missions 1/3") — the full count
## from the Mystery Bible, even if not every secret is implemented yet.
@export var secret_total: int = 0
@export var mission_total: int = 0
@export var weather: WeatherTable

@export_group("World")
@export_file("*.tscn") var scene_path: String = ""
## Where a new arrival without a waystone target appears.
@export var spawn: Vector3 = Vector3.ZERO
## Chunks from the centre to the edge: 1 = 3x3 (384 m), 2 = 5x5 (640 m). The map covers it.
@export var chunk_radius: int = 1
## Waystone id -> position (the Waystone nodes in the chunks use the same ids).
@export var waystones: Dictionary[StringName, Vector3] = {}

@export_group("Dynamic Gates")
## Gates that may open in this region (picked at random, weighted equally).
@export var gate_table: Array[GateData] = []
## Candidate spots for dynamic Gates.
@export var gate_points: PackedVector3Array = PackedVector3Array()
@export var max_world_gates: int = 2
## Monsters that pour out on a Dungeon Break.
@export var break_pool: Array[EnemyData] = []

const IDS: Array[StringName] = [&"r1_ashfall", &"r2_verdant", &"r3_dunes", &"r4_frostveil", &"r5_archive",
	&"r6_fracture", &"r7_hollow_throne"]


## Half the width of the playable square, in metres.
func half_extent_m() -> float:
	return (float(chunk_radius) + 0.5) * ChunkMath.CHUNK_SIZE_M


static func load_region(region_id: StringName) -> RegionData:
	var path: String = "res://data/regions/%s.tres" % region_id
	return load(path) as RegionData if ResourceLoader.exists(path) else null


## Region owning a waystone id, or null.
static func region_of_waystone(waystone_id: StringName) -> RegionData:
	for rid: StringName in IDS:
		var r: RegionData = load_region(rid)
		if r != null and r.waystones.has(waystone_id):
			return r
	return null
