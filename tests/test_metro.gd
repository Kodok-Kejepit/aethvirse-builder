extends GutTest
## Region 1 metro station: Lv 40-50 monsters, a Rank D Gate, a way back up; saves made
## inside keep the street position.

const STATION: String = "res://scenes/world/metro/metro_station.tscn"


func test_station_has_deep_monsters_a_gate_and_an_exit() -> void:
	var station: MetroStation = (load(STATION) as PackedScene).instantiate() as MetroStation
	add_child_autofree(station)
	await wait_physics_frames(2)
	var spawners: int = 0
	var portal_gate: GateData = null
	var exits: int = 0
	for node: Node in station.find_children("*", "", true, false):
		var spawner: EnemySpawner = node as EnemySpawner
		if spawner != null:
			spawners += 1
			assert_between(spawner.level, 40, 50, "station monsters are Lv 40-50")
		var interactable: Interactable = node as Interactable
		if interactable != null and interactable.prompt_key == &"PROMPT_METRO_UP":
			exits += 1
		if node.get(&"gate") is GateData:
			portal_gate = node.get(&"gate")
	assert_gt(spawners, 6)
	assert_eq(exits, 1)
	assert_not_null(portal_gate, "a Gate waits in the tunnel")
	assert_eq(portal_gate.rank, GateData.Rank.D)
	assert_gt(portal_gate.level_floor, 40)
	for child: Node in get_children():
		if child is Enemy:
			child.queue_free()


func test_saving_inside_keeps_the_street_position() -> void:
	var player: Node3D = Node3D.new()
	add_child_autofree(player)
	player.global_position = Vector3(40.0, 5.0, 0.0)
	var old_player: Node3D = GameState.player
	GameState.player = player
	GameState.interior_return = Vector3(-112.0, 0.3, -99.0)
	var data: Dictionary = GameState.to_dict()
	var pos: Array = data["player_position"]
	var px: float = pos[0]
	var pz: float = pos[2]
	assert_almost_eq(px, -112.0, 0.01)
	assert_almost_eq(pz, -99.0, 0.01)
	GameState.interior_return = null
	GameState.player = old_player


func test_metro_entrance_sits_in_a_deep_zone() -> void:
	var text: String = FileAccess.get_file_as_string("res://scenes/world/chunks/r1/chunk_-1_-1.tscn")
	assert_true(text.contains("metro_entrance.gd"), "the entrance is placed in the north-west chunk")
