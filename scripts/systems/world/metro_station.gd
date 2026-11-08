class_name MetroStation
extends Node3D
## Ruined underground metro station under Ashfall (Region 1, Lv 40-50): an island
## platform between two tracks, glazed tiles gone grimy and mossy, pillars, flickering
## and dead lamps, a caved-in ceiling with daylight falling through, wrecked trains on
## the rails, tunnels at both ends (the west one holds a Rank D Gate), and stairs up to
## the street. Built in code so the layout stays easy to tune.

const SCENE: String = "res://scenes/world/metro/metro_station.tscn"
const GATE_PORTAL_SCENE: String = "res://scenes/world/gates/gate_portal.tscn"
const METRO_GATE: String = "res://data/gates/gate_r1_d_metro.tres"
const PAVEMENT: Shader = preload("res://assets/shaders/pavement.gdshader")
const SURFACES: String = "res://assets/textures/surfaces/%s.jpg"
const ENEMY_SCENE: String = "res://scenes/enemies/enemy.tscn"

const HALF_X: float = 50.0
const HALF_Z: float = 12.6
const CEILING_Y: float = 8.5
const PLATFORM_HALF_Z: float = 4.0
const PLATFORM_Y: float = 1.1
const TRACK_Z: float = 8.0
const GAUGE_HALF: float = 0.72
const TUNNEL_LEN: float = 30.0
const TUNNEL_HALF_W: float = 3.0
const TUNNEL_H: float = 5.0
const LANDING_Y: float = 5.4
const STAIR_X: Vector2 = Vector2(26.0, 42.0)
const HOLE: Rect2 = Rect2(-12.0, -11.5, 7.0, 5.5)

var _tiles: ShaderMaterial
var _slabs: ShaderMaterial
var _bed: StandardMaterial3D
var _steel: StandardMaterial3D
var _sleeper: StandardMaterial3D
var _flicker: Array[OmniLight3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var player: Player = %Player


func _ready() -> void:
	_rng.seed = 7341
	var world_env: WorldEnvironment = get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if world_env != null:
		Settings.apply_effects(world_env.environment)
	AudioManager.set_area_music(&"gate")
	_materials()
	_hall()
	_platform()
	_stairs_and_exit()
	_tunnels()
	_tracks()
	_trains()
	_cave_in()
	_lights()
	_dressing()
	_monsters()
	_gate()
	player.global_position = Vector3(46.0, LANDING_Y + 0.3, 0.0)
	player.visual.rotation.y = MovementMath.yaw_for_direction(Vector3.LEFT)
	player.spawn_point = player.global_position
	player.last_safe_position = player.global_position
	player.camera_rig.snap_to(player.visual.rotation.y)
	Codex.notify(tr(&"CODEX_MSG_METRO"), &"warning")


# --- materials --------------------------------------------------------------------

func _materials() -> void:
	var moss: Texture2D = load(SURFACES % "tile_roots_grass") as Texture2D
	var dirt: Texture2D = load(SURFACES % "tile_dirt") as Texture2D
	_tiles = ShaderMaterial.new()
	_tiles.shader = PAVEMENT
	_tiles.set_shader_parameter(&"mode", 2)
	_tiles.set_shader_parameter(&"tex_moss", moss)
	_tiles.set_shader_parameter(&"tex_dirt", dirt)
	_slabs = ShaderMaterial.new()
	_slabs.shader = PAVEMENT
	_slabs.set_shader_parameter(&"mode", 0)
	_slabs.set_shader_parameter(&"tex_moss", moss)
	_slabs.set_shader_parameter(&"tex_dirt", dirt)
	_bed = StandardMaterial3D.new()
	_bed.albedo_texture = dirt
	_bed.albedo_color = Color(0.55, 0.52, 0.5)
	_bed.uv1_triplanar = true
	_bed.uv1_world_triplanar = true
	_bed.uv1_scale = Vector3.ONE / 2.5
	_bed.roughness = 0.95
	_steel = StandardMaterial3D.new()
	_steel.albedo_color = Color(0.36, 0.3, 0.26)
	_steel.metallic = 0.75
	_steel.roughness = 0.4
	_sleeper = StandardMaterial3D.new()
	_sleeper.albedo_color = Color(0.42, 0.41, 0.39)
	_sleeper.roughness = 0.9


func _box(size: Vector3, pos: Vector3, mat: Material, collide: bool = true, yaw: float = 0.0) -> Node3D:
	var holder: Node3D = StaticBody3D.new() if collide else Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	holder.add_child(mi)
	if collide:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		holder.add_child(cs)
	add_child(holder)
	return holder


# --- structure --------------------------------------------------------------------

func _hall() -> void:
	# Track beds (the floor of the whole hall) and the side walls.
	_box(Vector3(HALF_X * 2.0 + TUNNEL_LEN * 2.0, 0.6, HALF_Z * 2.0), Vector3(0.0, -0.3, 0.0), _bed)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(HALF_X * 2.0, CEILING_Y, 0.6), Vector3(0.0, CEILING_Y * 0.5, side * (HALF_Z + 0.3)), _tiles)
		# End walls: open over each track (tunnel mouths), solid above the platform.
		var x: float = side * (HALF_X + 0.3)
		var lo: float = TRACK_Z - TUNNEL_HALF_W
		var hi: float = TRACK_Z + TUNNEL_HALF_W
		_box(Vector3(0.6, CEILING_Y, lo * 2.0), Vector3(x, CEILING_Y * 0.5, 0.0), _tiles)
		for zs: float in [-1.0, 1.0]:
			_box(Vector3(0.6, CEILING_Y, HALF_Z - hi), Vector3(x, CEILING_Y * 0.5, zs * (hi + (HALF_Z - hi) * 0.5)), _tiles)
			_box(Vector3(0.6, CEILING_Y - TUNNEL_H, hi - lo), Vector3(x, TUNNEL_H + (CEILING_Y - TUNNEL_H) * 0.5, zs * TRACK_Z), _tiles)
	_ceiling()


## Ceiling slabs around the caved-in hole.
func _ceiling() -> void:
	var t: float = 0.5
	var y: float = CEILING_Y + t * 0.5
	var x0: float = -HALF_X
	var x1: float = HALF_X
	var hx0: float = HOLE.position.x
	var hx1: float = HOLE.end.x
	var hz0: float = HOLE.position.y
	var hz1: float = HOLE.end.y
	_box(Vector3(hx0 - x0, t, HALF_Z * 2.0), Vector3((x0 + hx0) * 0.5, y, 0.0), _slabs)
	_box(Vector3(x1 - hx1, t, HALF_Z * 2.0), Vector3((x1 + hx1) * 0.5, y, 0.0), _slabs)
	_box(Vector3(hx1 - hx0, t, hz0 + HALF_Z), Vector3((hx0 + hx1) * 0.5, y, (-HALF_Z + hz0) * 0.5), _slabs)
	_box(Vector3(hx1 - hx0, t, HALF_Z - hz1), Vector3((hx0 + hx1) * 0.5, y, (hz1 + HALF_Z) * 0.5), _slabs)


func _platform() -> void:
	_box(Vector3(HALF_X * 2.0, PLATFORM_Y, PLATFORM_HALF_Z * 2.0), Vector3(0.0, PLATFORM_Y * 0.5, 0.0), _slabs)
	var yellow: StandardMaterial3D = StandardMaterial3D.new()
	yellow.albedo_color = Color(0.62, 0.52, 0.18)
	yellow.roughness = 0.8
	for side: float in [-1.0, 1.0]:
		_box(Vector3(HALF_X * 2.0, 0.02, 0.45), Vector3(0.0, PLATFORM_Y + 0.01, side * (PLATFORM_HALF_Z - 0.4)), yellow, false)
	# Tiled pillars down the middle of the platform (not where the stairs climb).
	var x: float = -42.0
	while x <= 42.0:
		if x < STAIR_X.x - 2.0 or x > STAIR_X.y + 2.0:
			_box(Vector3(1.0, CEILING_Y - PLATFORM_Y, 1.0), Vector3(x, PLATFORM_Y + (CEILING_Y - PLATFORM_Y) * 0.5, 0.0), _tiles)
		x += 10.0


func _stairs_and_exit() -> void:
	var run: float = STAIR_X.y - STAIR_X.x
	var rise: float = LANDING_Y - PLATFORM_Y
	var ramp: Node3D = _box(Vector3(Vector2(run, rise).length(), 0.4, 3.6), Vector3((STAIR_X.x + STAIR_X.y) * 0.5, PLATFORM_Y + rise * 0.5, 0.0), _slabs)
	ramp.rotation.z = atan2(rise, run)
	var landing_len: float = HALF_X - STAIR_X.y
	_box(Vector3(landing_len, 0.4, 3.6), Vector3(STAIR_X.y + landing_len * 0.5, LANDING_Y - 0.2, 0.0), _slabs)
	for side: float in [-1.0, 1.0]:
		var rail: Node3D = _box(Vector3(Vector2(run, rise).length(), 1.0, 0.15), Vector3((STAIR_X.x + STAIR_X.y) * 0.5, PLATFORM_Y + rise * 0.5 + 0.6, side * 1.85), _steel)
		rail.rotation.z = atan2(rise, run)
		_box(Vector3(landing_len, 1.0, 0.15), Vector3(STAIR_X.y + landing_len * 0.5, LANDING_Y + 0.5, side * 1.85), _steel)
	# The way out: a dark doorway with a dim exit sign.
	var door: Node3D = _box(Vector3(0.2, 2.6, 2.4), Vector3(HALF_X - 0.05, LANDING_Y + 1.3, 0.0), _dark(), false)
	var exit_sign: Label3D = Label3D.new()
	exit_sign.text = tr(&"METRO_EXIT")
	exit_sign.font_size = 40
	exit_sign.modulate = Color(0.5, 1.0, 0.6)
	exit_sign.position = Vector3(-0.2, 1.7, 0.0)
	exit_sign.rotation.y = -PI * 0.5
	door.add_child(exit_sign)
	var exit: Interactable = Interactable.new()
	exit.prompt_key = &"PROMPT_METRO_UP"
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 2.2
	cs.shape = sphere
	exit.add_child(cs)
	exit.position = Vector3(HALF_X - 1.5, LANDING_Y + 1.0, 0.0)
	add_child(exit)
	exit.interacted.connect(_leave)


func _dark() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.02, 0.025)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Short tunnels past both ends; their far ends have caved in.
func _tunnels() -> void:
	for sx: float in [-1.0, 1.0]:
		var mid_x: float = sx * (HALF_X + TUNNEL_LEN * 0.5)
		for sz: float in [-1.0, 1.0]:
			var z: float = sz * TRACK_Z
			for wall: float in [-1.0, 1.0]:
				_box(Vector3(TUNNEL_LEN, TUNNEL_H, 0.6), Vector3(mid_x, TUNNEL_H * 0.5, z + wall * (TUNNEL_HALF_W + 0.3)), _slabs)
			_box(Vector3(TUNNEL_LEN, 0.5, TUNNEL_HALF_W * 2.0 + 1.2), Vector3(mid_x, TUNNEL_H + 0.25, z), _slabs)
			_box(Vector3(0.6, TUNNEL_H, TUNNEL_HALF_W * 2.0), Vector3(sx * (HALF_X + TUNNEL_LEN), TUNNEL_H * 0.5, z), _slabs)
			_prop(&"rubble_heap", Vector3(sx * (HALF_X + TUNNEL_LEN - 3.0), 0.0, z), 2.4, _rng.randf() * TAU, true)


## Both tracks: steel rails on concrete sleepers, one merged mesh per track.
func _tracks() -> void:
	var length: float = HALF_X * 2.0 + TUNNEL_LEN * 2.0
	for sz: float in [-1.0, 1.0]:
		var z: float = sz * TRACK_Z
		var sleepers: SurfaceTool = SurfaceTool.new()
		sleepers.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sleeper_mesh: BoxMesh = BoxMesh.new()
		sleeper_mesh.size = Vector3(0.24, 0.14, 2.5)
		var x: float = -length * 0.5 + 0.4
		while x < length * 0.5:
			var jitter: float = _rng.randf_range(-0.04, 0.04)
			sleepers.append_from(sleeper_mesh, 0, Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.04, 0.04)), Vector3(x, 0.07, z + jitter)))
			x += 0.65
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = sleepers.commit()
		mi.material_override = _sleeper
		add_child(mi)
		for rail_side: float in [-1.0, 1.0]:
			_box(Vector3(length, 0.15, 0.08), Vector3(0.0, 0.215, z + rail_side * GAUGE_HALF), _steel, false)


func _trains() -> void:
	# South track: a cab and two cars, the last one jumped the rails.
	_vehicle(&"metro_cab", Vector3(-31.0, 0.3, TRACK_Z), 0.0, 0.0)
	_vehicle(&"metro_car", Vector3(-20.6, 0.3, TRACK_Z), 0.0, 0.0)
	_vehicle(&"metro_car", Vector3(-7.4, 0.45, TRACK_Z + 0.8), deg_to_rad(5.0), deg_to_rad(4.0))
	# North track: a lone car that crashed and tipped against the platform.
	_vehicle(&"metro_car", Vector3(24.0, 0.6, -TRACK_Z - 0.6), deg_to_rad(-7.0), deg_to_rad(-9.0))


func _vehicle(id: StringName, pos: Vector3, yaw: float, roll: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	body.rotation = Vector3(roll, yaw, 0.0)
	add_child(body)
	if not PropInstance.attach_model(body, id, 3.8):
		return
	var d: PropData = PropData.find(id)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = d.size * 0.95
	cs.shape = box
	cs.position.y = d.size.y * 0.5
	body.add_child(cs)


## The caved-in ceiling: daylight falls through onto a heap of rubble and roots.
func _cave_in() -> void:
	var c: Vector2 = HOLE.get_center()
	var shaft: SpotLight3D = SpotLight3D.new()
	shaft.position = Vector3(c.x, CEILING_Y + 6.0, c.y)
	shaft.rotation.x = -PI * 0.5
	shaft.light_color = Color(1.0, 0.95, 0.85)
	shaft.light_energy = 4.0
	shaft.spot_range = 20.0
	shaft.spot_angle = 22.0
	add_child(shaft)
	_prop(&"rubble_heap", Vector3(c.x, 0.0, c.y), 2.2, 0.4, true)
	_prop(&"ruin_stone_block", Vector3(c.x + 2.5, 0.0, c.y + 1.0), 1.4, 1.1, true)
	_prop(&"ruin_bush_1", Vector3(c.x - 1.5, 0.0, c.y + 1.5), 2.2, 0.0, false)
	_prop(&"ruin_stump_2", Vector3(c.x + 1.0, 0.0, c.y - 1.8), 1.2, 2.0, false)


func _lights() -> void:
	var x: float = -42.0
	while x <= 42.0:
		var roll: float = _rng.randf()
		if roll > 0.3:
			var lamp: OmniLight3D = OmniLight3D.new()
			lamp.position = Vector3(x, CEILING_Y - 0.6, 0.0)
			lamp.light_color = Color(0.82, 0.92, 1.0)
			lamp.light_energy = 1.3
			lamp.omni_range = 14.0
			add_child(lamp)
			if roll > 0.8:
				_flicker.append(lamp)
		_box(Vector3(2.4, 0.12, 0.4), Vector3(x, CEILING_Y - 0.1, 0.0), _lamp_mat(roll > 0.3), false)
		x += 12.0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var red: OmniLight3D = OmniLight3D.new()
			red.position = Vector3(sx * (HALF_X - 1.0), TUNNEL_H - 0.5, sz * TRACK_Z)
			red.light_color = Color(1.0, 0.18, 0.12)
			red.light_energy = 1.4
			red.omni_range = 9.0
			add_child(red)


func _lamp_mat(lit: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.9, 1.0) if lit else Color(0.2, 0.2, 0.22)
	m.emission_enabled = lit
	m.emission = Color(0.8, 0.9, 1.0)
	m.emission_energy_multiplier = 1.5
	return m


func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() * 0.001
	for i: int in _flicker.size():
		var on: bool = sin(t * (13.0 + float(i) * 3.1)) + sin(t * 7.3 + float(i)) > -0.6
		_flicker[i].visible = on


## Puddles, benches, scattered rubble, chests.
func _dressing() -> void:
	var water: StandardMaterial3D = StandardMaterial3D.new()
	water.albedo_color = Color(0.05, 0.07, 0.09, 0.8)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.metallic = 0.4
	water.roughness = 0.04
	for p: Vector3 in [Vector3(-36, PLATFORM_Y + 0.02, 1.5), Vector3(-5, PLATFORM_Y + 0.02, -2.0), Vector3(14, PLATFORM_Y + 0.02, 2.2),
			Vector3(-14, 0.03, -TRACK_Z), Vector3(8, 0.03, TRACK_Z - 1.5), Vector3(36, 0.03, TRACK_Z)]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var disc: CylinderMesh = CylinderMesh.new()
		disc.top_radius = _rng.randf_range(1.0, 2.2)
		disc.bottom_radius = disc.top_radius
		disc.height = 0.01
		disc.radial_segments = 14
		disc.material = water
		mi.mesh = disc
		mi.position = p
		mi.scale = Vector3(_rng.randf_range(0.8, 1.6), 1.0, 1.0)
		mi.rotation.y = _rng.randf() * TAU
		add_child(mi)
	for i: int in 5:
		var x: float = -40.0 + float(i) * 14.0 + _rng.randf_range(-3, 3)
		_prop(&"rubble_heap", Vector3(x, PLATFORM_Y, _rng.randf_range(-2.5, 2.5)), _rng.randf_range(0.8, 1.4), _rng.randf() * TAU, true)
	for spot: Array in [[Vector3(-26, PLATFORM_Y, -2.6), &"supply"], [Vector3(10, PLATFORM_Y, 2.6), &"supply"],
			[Vector3(HALF_X + TUNNEL_LEN - 6.0, 0.0, -TRACK_Z), &"treasure"]]:
		var at: Vector3 = spot[0]
		var kind: StringName = spot[1]
		var chest: LootChest = LootChest.new()
		chest.chest_id = StringName("metro_%d" % _rng.randi())
		chest.kind = kind
		chest.level = 46
		chest.persistent = false
		chest.position = at
		add_child(chest)


## Lv 42-50: brutes and husks on the platform, hounds on the tracks, an elite at the Gate.
func _monsters() -> void:
	var packs: Array[Array] = [
		[&"moss_brute", 44, Vector3(-30, PLATFORM_Y + 0.3, 1.5)], [&"moss_brute", 45, Vector3(-28, PLATFORM_Y + 0.3, -2.0)],
		[&"ember_husk", 42, Vector3(0, PLATFORM_Y + 0.3, 2.0)], [&"ember_husk", 43, Vector3(4, PLATFORM_Y + 0.3, -2.5)],
		[&"ember_husk", 42, Vector3(-2, PLATFORM_Y + 0.3, -1.0)],
		[&"ash_hound_alpha", 47, Vector3(8, 0.3, TRACK_Z)], [&"ash_hound", 45, Vector3(11, 0.3, TRACK_Z - 1.5)],
		[&"ash_hound", 45, Vector3(11, 0.3, TRACK_Z + 1.5)],
		[&"gravewarden", 49, Vector3(-HALF_X - 6.0, 0.3, -TRACK_Z)],
	]
	for pack: Array in packs:
		var id: StringName = pack[0]
		var lvl: int = pack[1]
		var at: Vector3 = pack[2]
		var spawner: EnemySpawner = EnemySpawner.new()
		spawner.enemy_scene = load(ENEMY_SCENE) as PackedScene
		spawner.enemy_data = load("res://data/enemies/%s.tres" % id) as EnemyData
		spawner.level = lvl
		spawner.respawn_s = 300.0
		spawner.position = at
		add_child(spawner)


func _gate() -> void:
	var portal: Node3D = (load(GATE_PORTAL_SCENE) as PackedScene).instantiate() as Node3D
	portal.set(&"gate", load(METRO_GATE))
	portal.position = Vector3(-HALF_X - 14.0, 0.0, -TRACK_Z)
	add_child(portal)


func _prop(id: StringName, pos: Vector3, height: float, yaw: float, collide: bool) -> void:
	var holder: Node3D = StaticBody3D.new() if collide else Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	add_child(holder)
	if not PropInstance.attach_model(holder, id, height):
		holder.queue_free()
		return
	var d: PropData = PropData.find(id)
	if collide and d != null and d.size.y > 0.001:
		var s: Vector3 = d.size * (height / d.size.y) * 0.8
		var cs: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = s
		cs.shape = box
		cs.position.y = s.y * 0.5
		holder.add_child(cs)


## Up the stairs: back to the street in front of the station entrance.
func _leave(_player: Player) -> void:
	var back: Variant = GameState.interior_return
	GameState.interior_return = null
	if back is Vector3:
		GameState.pending_player_position = back
	LoadingScreen.go(get_tree(), SaveManager.region_scene(GameState.current_region))
