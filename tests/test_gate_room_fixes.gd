extends GutTest


func after_each() -> void:
	# Rooms add their enemies next to themselves (to this test node).
	for child: Node in get_children():
		if child is Enemy:
			child.queue_free()

## Gate fixes: rooms clear even if an enemy vanishes without dying; strays are put back;
## a cleared Double Gate never shows up again.


func test_room_clears_when_enemy_vanishes() -> void:
	var room: GateRoom = GateRoom.new()
	room.enemies = [load("res://data/enemies/gate_husk.tres") as EnemyData]
	room.spawn_points = [Vector3(0, 0.3, 0)]
	add_child_autofree(room)
	watch_signals(room)
	room.start()
	await wait_physics_frames(2)
	var enemy: Enemy = room._living[0]
	enemy.queue_free()
	await wait_physics_frames(2)
	assert_signal_emitted(room, "cleared", "vanished enemy still counts")


func test_stray_enemy_is_put_back() -> void:
	var room: GateRoom = GateRoom.new()
	room.size = Vector2(24, 24)
	room.enemies = [load("res://data/enemies/gate_husk.tres") as EnemyData]
	room.spawn_points = [Vector3(0, 0.3, 0)]
	add_child_autofree(room)
	room.start()
	await wait_physics_frames(2)
	var enemy: Enemy = room._living[0]
	enemy.global_position = Vector3(80, 0.3, 0)
	room._check = 0.0
	await wait_physics_frames(2)
	assert_lt(enemy.global_position.distance_to(room.global_position), 20.0)
	enemy.queue_free()


func test_cleared_double_gate_is_gone() -> void:
	var gate: GateData = load("res://data/gates/gate_r1_e_overpass.tres") as GateData
	var flag: StringName = StringName("gate_cleared_" + String(gate.id) + "_double")
	GameState.set_flag(flag)
	for day: int in 40:
		assert_false(GateLayout.has_double_gate(gate, day))
	GameState.set_flag(flag, false)
