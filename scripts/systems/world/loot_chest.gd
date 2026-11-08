class_name LootChest
extends StaticBody3D
## A chest left in the world (owner's models): open it once for random loot scaled to
## the region level. Opened chests stay open (world flag from the chest id).
## kind: &"supply" (broken crate, common loot) or &"treasure" (ornate chest, elite loot).

@export var chest_id: StringName = &""
@export var kind: StringName = &"supply"
@export var level: int = 3
## False for chests in Gate runs (a new run is a new dungeon): no world flag.
@export var persistent: bool = true

const MODELS: Dictionary[StringName, Array] = {
	&"supply": [&"camp_crate_broken", 0.9], &"treasure": [&"prop_treasure_chest", 1.1],
}

var _interactable: Interactable
var _opened: bool = false


func _ready() -> void:
	var spec: Array = MODELS.get(kind, MODELS[&"supply"])
	var model_id: StringName = spec[0]
	var height: float = spec[1]
	if not PropInstance.attach_model(self, model_id, height):
		var box: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(1.2, height, 0.8)
		box.mesh = bm
		box.position.y = height * 0.5
		add_child(box)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.2, height, 0.9)
	cs.shape = shape
	cs.position.y = height * 0.5
	add_child(cs)
	_interactable = Interactable.new()
	_interactable.prompt_key = &"PROMPT_OPEN"
	var use: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 1.8
	use.shape = sphere
	use.position.y = 0.6
	_interactable.add_child(use)
	add_child(_interactable)
	_interactable.interacted.connect(_open)
	if persistent and GameState.has_flag(_flag()):
		_set_opened()


func _flag() -> StringName:
	return StringName("chest_opened_" + String(chest_id))


func _open(_player: Player) -> void:
	if _opened:
		return
	if persistent:
		GameState.set_flag(_flag())
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(chest_id) + GameState.clock.day() if GameState.clock != null else hash(chest_id)
	var tier: EnemyScaling.Tier = EnemyScaling.Tier.ELITE if kind == &"treasure" else EnemyScaling.Tier.NORMAL
	var drops: Array[ItemStack] = LootDropper.roll(level, tier, GameState.items, rng)
	for i: int in drops.size():
		var offset: Vector3 = Vector3(cos(i * 2.1), 0.3, sin(i * 2.1)) * 1.1
		WorldPickup.spawn(get_parent(), global_position + offset, drops[i])
	EventBus.gold_gained.emit(rng.randi_range(level * 2, level * 6) * (3 if kind == &"treasure" else 1))
	AudioManager.play_sfx(&"pickup")
	_set_opened()


func _set_opened() -> void:
	_opened = true
	_interactable.enabled = false
	# Lid gone / crate split: tip the model a little so it reads as looted.
	for child: Node in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).rotation.z = deg_to_rad(8.0)
