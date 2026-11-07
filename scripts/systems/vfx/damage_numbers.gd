class_name DamageNumbers
extends Node3D
## Pooled floating damage numbers (Label3D). Listens to EventBus.damage_number_requested.

@export var pool_size: int = 32
@export var rise_m: float = 1.2
@export var lifetime_s: float = 0.8
@export var font_size: int = 64
@export var crit_scale: float = 1.5
@export var player_hit_color: Color = Color(1.0, 0.3, 0.3)

var _pool: Array[Label3D] = []
var _next: int = 0


func _ready() -> void:
	for i: int in pool_size:
		var label: Label3D = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0006
		label.font_size = font_size
		label.outline_size = 12
		label.visible = false
		add_child(label)
		_pool.append(label)
	EventBus.damage_number_requested.connect(show_number)


func show_number(at: Vector3, amount: int, is_crit: bool, element: int, on_player: bool) -> void:
	if not Settings.show_damage_numbers:
		return
	var label: Label3D = _pool[_next]
	_next = (_next + 1) % _pool.size()
	var jitter: Vector3 = Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	label.global_position = at + jitter
	label.text = ("%d!" % amount) if is_crit else str(amount)
	var element_type: Element.Type = element as Element.Type
	label.modulate = player_hit_color if on_player else Element.COLORS.get(element_type, Color.WHITE)
	label.scale = Vector3.ONE * (crit_scale if is_crit else 1.0)
	label.visible = true
	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, ^"global_position:y", label.global_position.y + rise_m, lifetime_s) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, ^"modulate:a", 0.0, lifetime_s).set_delay(lifetime_s * 0.5)
	tween.chain().tween_callback(label.hide)
