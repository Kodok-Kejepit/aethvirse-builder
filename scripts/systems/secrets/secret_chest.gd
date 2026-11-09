class_name SecretChest
extends Node3D
## A chest that only appears once `required_flag` is set (the room under the bells opens);
## opening it completes `secret_id` (rewards come from the SecretData).

@export var secret_id: StringName = &""
@export var required_flag: StringName = &""

const CHEST_MODEL: StringName = &"prop_treasure_chest"
const CHEST_HEIGHT: float = 1.1

var _area: Interactable = null


func _ready() -> void:
	PropInstance.attach_model(self, CHEST_MODEL, CHEST_HEIGHT)
	_area = Interactable.new()
	_area.prompt_key = &"PROMPT_OPEN"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 1.6
	shape.shape = sphere
	shape.position = Vector3(0, 0.8, 0)
	_area.add_child(shape)
	add_child(_area)
	_area.interacted.connect(_open)
	_refresh()


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 20 == 0:
		_refresh()


func _refresh() -> void:
	var shown: bool = required_flag == &"" or GameState.has_flag(required_flag)
	var tracker: SecretTracker = SecretTracker.find(self) if is_inside_tree() else null
	var done: bool = tracker != null and tracker.is_found(secret_id)
	visible = shown and not done
	_area.enabled = visible


func _open(_player: Player) -> void:
	var tracker: SecretTracker = SecretTracker.find(self)
	if tracker != null and tracker.complete(secret_id):
		AudioManager.play_ui(&"ding")
	_refresh()
