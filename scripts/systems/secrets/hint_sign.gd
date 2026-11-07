class_name HintSign
extends Node3D
## Something readable in the world (graffiti, mailbox label, sign) that is a clue.

@export var text_key: StringName = &""
@export var hint_secret: StringName = &""
@export var hint_key: StringName = &""

@onready var interactable: Interactable = %Interactable


func _ready() -> void:
	_build_board()
	interactable.prompt_key = &"PROMPT_READ"
	interactable.interacted.connect(_read)


## A weathered plank nailed to a post (the old floating card read as paper in the air).
func _build_board() -> void:
	var old: MeshInstance3D = get_node_or_null(^"Mesh") as MeshInstance3D
	if old != null:
		old.visible = false
	var wood: Material = WorldStreamer.shared_material(Color(0.42, 0.3, 0.2))
	var post: MeshInstance3D = MeshInstance3D.new()
	var pm: BoxMesh = BoxMesh.new()
	pm.size = Vector3(0.12, 1.5, 0.12)
	pm.material = wood
	post.mesh = pm
	post.position = Vector3(0.0, 0.75, 0.0)
	add_child(post)
	var board: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.95, 0.55, 0.06)
	bm.material = WorldStreamer.shared_material(Color(0.5, 0.38, 0.26))
	board.mesh = bm
	board.position = Vector3(0.0, 1.3, -0.08)
	board.rotation_degrees = Vector3(-8.0, 0.0, 3.0)
	add_child(board)


func _read(_player: Player) -> void:
	var tracker: SecretTracker = SecretTracker.find(self)
	if tracker != null and hint_secret != &"":
		tracker.discover_hint(hint_secret, hint_key if hint_key != &"" else text_key)
	var box: DialogBox = DialogBox.find(self)
	if box != null:
		box.open("", [tr(text_key)] as Array[String], [] as Array[DialogChoice], Callable())
