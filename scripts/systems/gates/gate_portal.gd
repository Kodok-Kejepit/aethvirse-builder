class_name GatePortal
extends Node3D
## World-side Gate entrance. Optionally visible only when a flag is set and/or weather is wet.

const DUNGEON_SCENE: String = "res://scenes/world/gates/gate_dungeon.tscn"

@export var gate: GateData
@export var required_flag: StringName = &""
@export var requires_wet_weather: bool = false
## Cleared gates close (stored as world flag "gate_cleared_<id>").
@export var closes_when_cleared: bool = true
const RED_GATE_COLOR: Color = Color(0.55, 0.0, 0.05)
## Set by WorldGateManager for dynamic Gates.
var world_gate_uid: int = -1

@onready var interactable: Interactable = %Interactable
@onready var ring: MeshInstance3D = %Ring
@onready var label: Label3D = %Label


func _ready() -> void:
	interactable.prompt_key = &"PROMPT_ENTER"
	interactable.subject = tr(gate.display_name)
	interactable.interacted.connect(_enter)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var color: Color = RED_GATE_COLOR if gate.has_rule(&"red") else GateData.RANK_COLORS[gate.rank]
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	ring.material_override = material
	label.text = "%s  [%s]%s" % [tr(gate.display_name), GateData.Rank.keys()[gate.rank], "  RED" if gate.has_rule(&"red") else ""]
	_add_swirl(color)
	_add_frame()
	_refresh()
	EventBus.weather_changed.connect(func(_w: StringName) -> void: _refresh())


const SWIRL_SHADER: Shader = preload("res://assets/shaders/gate_swirl.gdshader")
var _swirl: MeshInstance3D = null


func _add_swirl(c: Color) -> void:
	var torus: TorusMesh = ring.mesh as TorusMesh
	var r: float = torus.inner_radius if torus != null else 1.2
	_swirl = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(r, r) * 2.0
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SWIRL_SHADER
	m.set_shader_parameter(&"color", c)
	quad.material = m
	_swirl.mesh = quad
	_swirl.transform = ring.transform
	_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_swirl)


const FRAME_MODEL: StringName = &"gate_celestial_frame"
const FRAME_HEIGHT: float = 5.4


## Owner's celestial gateway around the portal (scenery only).
func _add_frame() -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "Frame"
	add_child(holder)
	if not PropInstance.attach_model(holder, FRAME_MODEL, FRAME_HEIGHT):
		holder.queue_free()


func _process(delta: float) -> void:
	ring.rotate_y(delta * 1.5)
	if Engine.get_process_frames() % 30 == 0:
		_refresh()


func is_open() -> bool:
	if closes_when_cleared and GameState.has_flag(StringName("gate_cleared_" + String(gate.id))):
		return false
	if required_flag != &"" and not GameState.has_flag(required_flag):
		return false
	return not requires_wet_weather or GameState.weather.is_wet()


func _refresh() -> void:
	var open: bool = is_open()
	visible = open
	interactable.enabled = open


func _enter(player: Player) -> void:
	if GuildRank.current() < gate.min_guild_rank:
		Codex.notify(tr(&"CODEX_MSG_RANK_TOO_LOW") % GuildRank.NAMES[gate.min_guild_rank], &"warning")
		return
	var session: GateSession = GateSession.new()
	session.gate = gate
	session.return_scene = get_tree().current_scene.scene_file_path
	session.return_position = player.global_position + player.get_facing() * -2.0
	session.world_gate_uid = world_gate_uid
	GameState.gate_session = session
	SaveManager.autosave()
	get_tree().change_scene_to_file.call_deferred(DUNGEON_SCENE)


## Dungeon Break look: the ring turns red and spins faster.
func set_breaking(on: bool) -> void:
	var material: StandardMaterial3D = ring.material_override as StandardMaterial3D
	var color: Color = Color(1.0, 0.15, 0.1) if on else GateData.RANK_COLORS[gate.rank]
	material.albedo_color = color
	material.emission = color
	if _swirl != null:
		((_swirl.mesh as QuadMesh).material as ShaderMaterial).set_shader_parameter(&"color", color)
	label.text = ("⚠ " if on else "") + "%s  [%s]" % [tr(gate.display_name), GateData.Rank.keys()[gate.rank]]
