class_name InteractionDetector
extends Area3D
## On the player: finds the best Interactable in range, publishes the prompt, triggers it.

const ACTION: StringName = &"interact"

@export var player: Player

var current: Interactable = null
var _was_down: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Interactable.LAYER_BIT
	monitoring = true
	monitorable = false


func _physics_process(_delta: float) -> void:
	var best: Interactable = _find_best()
	if best != current:
		current = best
		EventBus.interaction_prompt_changed.emit(current.get_prompt() if current != null else "")
	var down: bool = Input.is_action_pressed(ACTION)
	if down and not _was_down and current != null and _can_interact():
		current.interact(player)
		# The interactable may change its prompt or disable itself.
		EventBus.interaction_prompt_changed.emit(current.get_prompt() if current.enabled else "")
	_was_down = down


func _can_interact() -> bool:
	return player.state_machine.get_state_name() in [PlayerState.IDLE, PlayerState.MOVE]


func _find_best() -> Interactable:
	var best: Interactable = null
	var best_score: float = INF
	var facing: Vector3 = player.get_facing()
	for area: Area3D in get_overlapping_areas():
		var candidate: Interactable = area as Interactable
		if candidate == null or not candidate.enabled:
			continue
		var to: Vector3 = candidate.global_position - player.global_position
		to.y = 0.0
		# Distance, slightly favoring things in front of the player; priority dominates.
		var score: float = to.length() - facing.dot(to.normalized()) * 0.5 - candidate.interact_priority * 100.0
		if score < best_score:
			best = candidate
			best_score = score
	return best
