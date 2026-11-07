class_name RegionController
extends Node3D
## Root of a region scene: applies region weather, starts chunk streaming around the player.

@export var region: RegionData
@export_dir var chunk_dir: String = ""

@onready var chunks_root: Node3D = %Chunks
@onready var player: Player = %Player


func _ready() -> void:
	GameState.weather.table = region.weather
	# Weather carried over from another region must exist here (no rain in the Fracture).
	var w: float = region.weather.weights.get(GameState.weather.current, 0.0) if region.weather != null else 1.0
	if w <= 0.0:
		GameState.set_weather(&"clear")
	GameState.current_region = region.id
	AudioManager.set_area_music(region.id)
	WorldStreamer.configure(chunks_root, chunk_dir)
	WorldStreamer.load_around_now(player.global_position)
	add_child(Vfx.new())
	var map: RegionMap = RegionMap.new()
	add_child(map)
	map.setup(region, chunks_root)
	var gates: WorldGateManager = WorldGateManager.new()
	add_child(gates)
	gates.setup(region)
	Codex.notify(tr(&"CODEX_MSG_REGION") % [tr(region.display_name), region.level_min, region.level_max], &"info")
