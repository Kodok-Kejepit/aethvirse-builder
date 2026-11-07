class_name Npc
extends CharacterBody3D
## Graybox NPC: talk via Interactable, data-driven dialog, reacts to being attacked.

@export var data: NpcData

@onready var interactable: Interactable = %Interactable
@onready var hurtbox: HurtboxComponent = %Hurtbox
@onready var name_label: Label3D = %NameLabel
@onready var body_mesh: MeshInstance3D = %BodyMesh

var _body: CreatureBody = null
## Idle breathing only plays near the player.
const IDLE_ANIM_RANGE_M: float = 40.0


func _ready() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = data.body_color
	body_mesh.material_override = material
	var body: CreatureBody = CreatureBody.new()
	body.name = "Creature"
	body_mesh.get_parent().add_child(body)
	body.position = Vector3(body_mesh.position.x, 0.0, body_mesh.position.z)
	var model_id: StringName = StringName("npc_" + data.resource_path.get_file().get_basename())
	if not body.build_model(model_id, CreatureBody.Shape.HUMANOID, 1.0):
		body.build(CreatureBody.Shape.HUMANOID, data.body_color, Color(0.75, 0.9, 1.0), 1.0)
	_body = body
	body_mesh.visible = false
	name_label.text = tr(data.display_name)
	interactable.prompt_key = &"PROMPT_TALK"
	interactable.subject = tr(data.display_name)
	interactable.interacted.connect(_on_talk)
	hurtbox.body = self
	hurtbox.hit_received.connect(_on_hit)
	_refresh_visibility()
	EventBus.hour_changed.connect(func(_h: int) -> void: _refresh_visibility())


## Idle breathing / sway.
func _process(delta: float) -> void:
	if _body == null or not visible:
		return
	var player: Node3D = GameState.player
	if player != null and global_position.distance_squared_to(player.global_position) > IDLE_ANIM_RANGE_M * IDLE_ANIM_RANGE_M:
		return
	_body.drive(0.0, false, delta)


func _refresh_visibility() -> void:
	var hidden: bool = (data.hidden_when_flag != &"" and GameState.has_flag(data.hidden_when_flag)) \
		or data.is_away(GameState.clock.hour())
	visible = not hidden
	collision_layer = 0 if hidden else 1
	interactable.enabled = not hidden
	hurtbox.monitorable = not hidden


func _on_talk(player: Player) -> void:
	var tracker: SecretTracker = SecretTracker.find(self)
	var box: DialogBox = DialogBox.find(self)
	if tracker == null or box == null:
		return
	var runner: DialogRunner = DialogRunner.new(tracker)
	var ctx: SecretContext = tracker.make_context()
	var entry: DialogEntry = runner.pick_entry(data, ctx)
	if entry == null:
		return
	_face(player.global_position)
	EventBus.npc_talked.emit(data.id)
	runner.apply(entry.on_show)
	var lines: Array[String] = []
	for key: StringName in DialogRunner.lines_for(entry, GameState.clock.day()):
		lines.append(tr(key))
	var choices: Array[DialogChoice] = DialogRunner.available_choices(entry, tracker.make_context(), GameState.gold)
	box.open(tr(data.display_name), lines, choices, func(choice: DialogChoice) -> void:
		if choice == null:
			return
		runner.choose(choice)
		if not choice.reply.is_empty():
			var reply: Array[String] = []
			for key: StringName in choice.reply:
				reply.append(tr(key))
			box.open.call_deferred(tr(data.display_name), reply, [] as Array[DialogChoice], Callable()))


func _on_hit(_info: DamageInfo) -> void:
	if data.attacked_flag != &"" and not GameState.has_flag(data.attacked_flag):
		GameState.set_flag(data.attacked_flag)
		EventBus.npc_attacked.emit(data.id)
	_refresh_visibility()


func _face(point: Vector3) -> void:
	var to: Vector3 = point - global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		rotation.y = MovementMath.yaw_for_direction(to)
