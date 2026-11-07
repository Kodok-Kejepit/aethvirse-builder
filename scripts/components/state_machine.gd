class_name StateMachine
extends Node
## Generic finite state machine. Child State nodes are the states (node name = state id).
## Does not start by itself: the owner sets up context, then calls start().

signal state_changed(previous: StringName, current: StringName)

@export var initial_state: State

var current: State = null
var _states: Dictionary[StringName, State] = {}


func _ready() -> void:
	for child: Node in get_children():
		var state: State = child as State
		if state != null:
			_states[state.name] = state
			state.transitioned.connect(transition_to)


func start() -> void:
	assert(initial_state != null, "StateMachine needs an initial_state")
	current = initial_state
	current.enter(&"")


func transition_to(next_state: StringName) -> void:
	if not _states.has(next_state):
		push_error("StateMachine: unknown state '%s'" % next_state)
		return
	var previous: StringName = current.name if current != null else &""
	if current != null:
		current.exit()
	current = _states[next_state]
	current.enter(previous)
	state_changed.emit(previous, next_state)


func get_state_name() -> StringName:
	return current.name if current != null else &""


func _unhandled_input(event: InputEvent) -> void:
	if current != null:
		current.handle_input(event)


func _process(delta: float) -> void:
	if current != null:
		current.update(delta)


func _physics_process(delta: float) -> void:
	if current != null:
		current.physics_update(delta)
