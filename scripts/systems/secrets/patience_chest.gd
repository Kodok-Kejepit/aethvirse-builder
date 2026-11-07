class_name PatienceChest
extends StaticBody3D
## MC-R1-01 "For those who are not in a hurry": opens after the player waits nearby without
## attacking it. Hitting it resets the seal and makes it take much longer.

@export var secret_id: StringName = &"MC-R1-01"
@export var wait_s: float = 30.0
@export var wait_after_hit_s: float = 120.0
@export var radius_m: float = 5.0
@export var opened_flag: StringName = &"mc_r1_01_opened"

@onready var interactable: Interactable = %Interactable
@onready var hurtbox: HurtboxComponent = %Hurtbox
@onready var label: Label3D = %Label
@onready var seal: MeshInstance3D = %Seal

const CHEST_MODEL: StringName = &"prop_treasure_chest"
const CHEST_HEIGHT: float = 1.1

var required_s: float = 30.0
var waited_s: float = 0.0


func _ready() -> void:
	required_s = wait_s
	hurtbox.body = self
	hurtbox.hit_received.connect(func(_info: DamageInfo) -> void:
		required_s = wait_after_hit_s
		waited_s = 0.0)
	interactable.prompt_key = &"PROMPT_OPEN"
	interactable.interacted.connect(_open)
	label.text = tr(&"CHEST_PATIENCE_SEAL")
	PropInstance.replace_mesh(get_node(^"Mesh") as MeshInstance3D, CHEST_MODEL, CHEST_HEIGHT)
	if GameState.has_flag(opened_flag):
		_set_opened()


func _physics_process(delta: float) -> void:
	if GameState.has_flag(opened_flag):
		return
	var player: Player = GameState.player as Player
	if player != null and player.global_position.distance_to(global_position) <= radius_m:
		waited_s = minf(waited_s + delta, required_s)
		var tracker: SecretTracker = SecretTracker.find(self)
		if tracker != null and waited_s > 5.0:
			tracker.discover_hint(secret_id, &"HINT_MC_R1_01_2")
	seal.scale = Vector3.ONE * (1.0 - 0.6 * progress())
	interactable.enabled = is_unsealed()


func progress() -> float:
	return waited_s / required_s if required_s > 0.0 else 1.0


func is_unsealed() -> bool:
	return waited_s >= required_s


func _open(_player: Player) -> void:
	if not is_unsealed():
		return
	var tracker: SecretTracker = SecretTracker.find(self)
	if tracker != null and tracker.complete(secret_id):
		GameState.set_flag(opened_flag)
		_set_opened()


func _set_opened() -> void:
	seal.visible = false
	interactable.enabled = false
	label.text = ""
	set_physics_process(false)
