class_name MimicChest
extends StaticBody3D
## MC-R1-02: the only dust-free thing in the room. Shifts when stared at for 3 s.
## Opening (or hitting) it wakes the mimic. Beating it without being bitten = +1 loot roll.

const STARE_DOT: float = 0.97
const STARE_S: float = 3.0
const MIMIC_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")

@export var secret_id: StringName = &"MC-R1-02"
@export var mimic_data: EnemyData
@export var defeated_flag: StringName = &"mc_r1_02_defeated"

@onready var interactable: Interactable = %Interactable
@onready var hurtbox: HurtboxComponent = %Hurtbox
@onready var mesh: MeshInstance3D = %Mesh

var _stare_s: float = 0.0
var _woken: bool = false
var _player_was_hit: bool = false


func _ready() -> void:
	hurtbox.body = self
	# Same model as the real sealed chests: the mimic must not look different.
	PropInstance.replace_mesh(mesh, PatienceChest.CHEST_MODEL, PatienceChest.CHEST_HEIGHT)
	hurtbox.hit_received.connect(func(_info: DamageInfo) -> void: _wake())
	interactable.prompt_key = &"PROMPT_OPEN"
	interactable.interacted.connect(func(_p: Player) -> void: _wake())
	if GameState.has_flag(defeated_flag):
		queue_free()


func _process(delta: float) -> void:
	if _woken:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var to: Vector3 = (global_position + Vector3.UP * 0.5 - camera.global_position).normalized()
	if -camera.global_basis.z.dot(to) > STARE_DOT and camera.global_position.distance_to(global_position) < 12.0:
		_stare_s += delta
		if _stare_s >= STARE_S:
			_stare_s = 0.0
			_shift()
			var tracker: SecretTracker = SecretTracker.find(self)
			if tracker != null:
				tracker.discover_hint(secret_id, &"HINT_MC_R1_02_2")
	else:
		_stare_s = 0.0


func _shift() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(mesh, ^"position:x", mesh.position.x + 0.01, 0.05)


func _wake() -> void:
	if _woken:
		return
	_woken = true
	var mimic: Enemy = MIMIC_SCENE.instantiate() as Enemy
	mimic.data = mimic_data
	mimic.position = global_position
	get_parent().add_child(mimic)
	var player: Player = GameState.player as Player
	if player != null:
		player.health.damaged.connect(func(info: DamageInfo) -> void:
			if info.source == mimic:
				_player_was_hit = true)
	mimic.health.died.connect(_on_mimic_died)
	visible = false
	collision_layer = 0
	interactable.enabled = false
	hurtbox.set_deferred(&"monitorable", false)


func _on_mimic_died() -> void:
	GameState.set_flag(defeated_flag)
	var tracker: SecretTracker = SecretTracker.find(self)
	if tracker == null:
		return
	if tracker.complete(secret_id) and not _player_was_hit:
		var bonus: RewardData = RewardData.new()
		bonus.type = RewardData.Type.LOOT_TABLE
		bonus.key = &"mimic_r1"
		tracker.grant(bonus)
