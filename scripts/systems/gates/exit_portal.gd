class_name ExitPortal
extends Node3D
## Leaves the Gate and returns to the world where the player entered.

const FALLBACK_SCENE: String = "res://scenes/main/game.tscn"

const DOUBLE_COLOR: Color = Color(0.75, 0.25, 1.0)

## True: this portal leads into the hidden Double Gate instead of out of the Gate.
@export var enters_double_gate: bool = false

@onready var interactable: Interactable = %Interactable


func _ready() -> void:
	interactable.prompt_key = &"PROMPT_ENTER_DOUBLE" if enters_double_gate else &"PROMPT_LEAVE_GATE"
	interactable.interacted.connect(_enter_double if enters_double_gate else _leave)
	if enters_double_gate:
		var ring: MeshInstance3D = get_node(^"Ring") as MeshInstance3D
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = DOUBLE_COLOR
		ring.material_override = mat


## The Double Gate keeps the outer Gate's way home: leaving it returns to the world.
func _enter_double(_player: Player) -> void:
	var outer: GateSession = GameState.gate_session
	if outer == null:
		return
	var day: int = GameState.clock.day() if GameState.clock != null else 1
	GameState.gate_session = GateLayout.double_session(outer, day)
	EventBus.secret_area_entered.emit(&"double_gate")
	LoadingScreen.go(get_tree(), GateDungeon.SCENE)


func _process(delta: float) -> void:
	rotate_y(delta * 2.0)


func _leave(_player: Player) -> void:
	var session: GateSession = GameState.gate_session
	var target: String = FALLBACK_SCENE
	if session != null:
		target = session.return_scene if session.return_scene != "" else SaveManager.region_scene(GameState.current_region)
		GameState.pending_player_position = session.return_position
	GameState.gate_session = null
	LoadingScreen.go(get_tree(), target)
