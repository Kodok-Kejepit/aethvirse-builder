class_name TimeFx
extends RefCounted
## Global time effects (hit-stop, slow motion) through Engine.time_scale.
## The strongest (lowest) active scale wins; each effect restores itself on a real-time timer.

const HIT_STOP_SCALE: float = 0.02

static var _effects: Dictionary[int, float] = {}
static var _next_id: int = 0


static func hit_stop(duration_s: float) -> void:
	apply(HIT_STOP_SCALE, duration_s)


static func slow_motion(scale: float, duration_s: float) -> void:
	apply(scale, duration_s)


static func apply(scale: float, duration_s: float) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or duration_s <= 0.0:
		return
	_next_id += 1
	var id: int = _next_id
	_effects[id] = scale
	_refresh()
	# process_always=true, process_in_physics=false, ignore_time_scale=true
	tree.create_timer(duration_s, true, false, true).timeout.connect(func() -> void:
		_effects.erase(id)
		_refresh())


static func reset() -> void:
	_effects.clear()
	_refresh()


static func _refresh() -> void:
	var scale: float = 1.0
	for value: float in _effects.values():
		scale = minf(scale, value)
	Engine.time_scale = scale
