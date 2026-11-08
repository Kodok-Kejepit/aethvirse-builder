class_name Waystone
extends Node3D
## Glowing stone: touching it unlocks it for fast travel, using it opens the travel list.
## With `road_to` set it is a region road instead: using it walks you to that waystone.

const UNLOCK_RADIUS: float = 4.0

@export var waystone_id: StringName = &""
## Road sign mode: target waystone (usually in another region).
@export var road_to: StringName = &""

var interactable: Interactable
var _crystal: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	_build()
	interactable.interacted.connect(_use)


func _process(delta: float) -> void:
	_crystal.rotate_y(delta * 0.8)
	if road_to != &"" or Engine.get_process_frames() % 10 != 0:
		return
	var player: Node3D = GameState.player
	if player != null and player.global_position.distance_to(global_position) < UNLOCK_RADIUS:
		_unlock()
		if WorldTravel.set_respawn(waystone_id):
			Codex.notify(tr(&"CODEX_MSG_RESPAWN_SET") % tr(name_key(waystone_id)), &"info")


func _unlock() -> void:
	if WorldTravel.unlock(waystone_id):
		Codex.notify(tr(&"CODEX_MSG_WAYSTONE") % tr(name_key(waystone_id)), &"info")
		AudioManager.play_ui(&"ding")
	_refresh()


func _use(player: Player) -> void:
	if road_to != &"":
		var region: RegionData = RegionData.region_of_waystone(road_to)
		if region != null and player != null and GameState.progression != null and GameState.progression.level < region.level_min - 5:
			Codex.notify(tr(&"CODEX_MSG_ROAD_DANGER") % [tr(region.display_name), region.level_min], &"warning")
		WorldTravel.unlock(road_to)
		WorldTravel.travel(get_tree(), road_to)
		return
	_unlock()
	var panel: TravelPanel = get_tree().get_first_node_in_group(TravelPanel.GROUP) as TravelPanel
	if panel == null:
		panel = TravelPanel.new()
		get_tree().current_scene.add_child(panel)
	panel.open()


static func name_key(id: StringName) -> StringName:
	return StringName("WAYSTONE_" + String(id).to_upper())


func _refresh() -> void:
	var on: bool = road_to != &"" or WorldTravel.is_unlocked(waystone_id)
	var mat: StandardMaterial3D = _crystal.material_override as StandardMaterial3D
	mat.emission_energy_multiplier = 2.5 if on else 0.4
	_label.modulate = Color(1, 1, 1, 1) if on else Color(1, 1, 1, 0.5)


## Shrine model + height per region (waystone id prefix): each fits its place - a broken
## stone ring in the ruined city, the witch circle in the forest, the moon altar in the
## desert, the golden arch in the snow and the archive, the void altar in the Fracture.
const SHRINES: Dictionary[String, Array] = {
	"r1": [&"landmark_ruined_plaza", 2.4], "r2": [&"landmark_ritual_circle", 2.8],
	"r3": [&"landmark_crimson_altar", 3.0], "r4": [&"landmark_waystone_arch", 3.6],
	"r5": [&"landmark_waystone_arch", 3.6], "r6": [&"landmark_nexus_altar", 3.0],
	"r7": [&"landmark_nexus_altar", 3.0],
}


static func shrine_for(id: StringName) -> Array:
	return SHRINES.get(String(id).substr(0, 2), [&"landmark_waystone_arch", 3.6])


func _build() -> void:
	var stone: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.2, 2.4, 0.5) if road_to == &"" else Vector3(0.25, 2.6, 0.25)
	stone.mesh = box
	stone.position = Vector3(0.0, box.size.y * 0.5, 0.0)
	var grey: StandardMaterial3D = StandardMaterial3D.new()
	grey.albedo_color = Color(0.4, 0.42, 0.5)
	stone.material_override = grey
	add_child(stone)
	_crystal = MeshInstance3D.new()
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.5, 0.8, 0.5) if road_to == &"" else Vector3(1.6, 0.6, 0.1)
	_crystal.mesh = prism
	_crystal.position = Vector3(0.0, 3.0, 0.0)
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.albedo_color = Color(0.4, 0.8, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.3, 0.75, 1.0)
	_crystal.material_override = glow
	add_child(_crystal)
	# Owner's golden archway: the crystal floats inside the arch.
	var shrine: Array = shrine_for(waystone_id)
	var shrine_model: StringName = shrine[0]
	var shrine_h: float = shrine[1]
	if road_to == &"" and PropInstance.replace_mesh(stone, shrine_model, shrine_h):
		_crystal.position = Vector3(0.0, 1.9, 0.0)
		_crystal.scale = Vector3.ONE * 0.7
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 48
	_label.outline_size = 10
	_label.position = Vector3(0.0, 4.4 if road_to == &"" else 4.0, 0.0)
	var target: StringName = road_to if road_to != &"" else waystone_id
	_label.text = ("→ " if road_to != &"" else "") + tr(name_key(target))
	add_child(_label)
	interactable = Interactable.new()
	interactable.prompt_key = &"PROMPT_TRAVEL" if road_to != &"" else &"PROMPT_WAYSTONE"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 2.0
	shape.shape = sphere
	shape.position = Vector3(0.0, 1.0, 0.0)
	interactable.add_child(shape)
	add_child(interactable)
	_refresh()
