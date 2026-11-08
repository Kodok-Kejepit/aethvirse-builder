class_name DungeonRoomShape
extends RefCounted
## Outline of an irregular dungeon room (top view, metres, centred on the room): a ring
## of corners whose distance from the centre wobbles by style (caves bulge a lot, halls
## stay nearly regular). Every door gets a straight, door-wide stretch of wall.

const DOOR_HALF_M: float = 3.0
## Style -> [corner count, wobble share of the radius].
const STYLE_SHAPE: Dictionary[StringName, Vector2] = {
	&"cave": Vector2(18, 0.24), &"hall": Vector2(10, 0.05), &"ruin": Vector2(14, 0.14),
}


## Corners in angle order: [{"p": Vector2, "door": door index or -1}]. A door's stretch
## runs from its corner to the next one (both carry the door index).
static func outline(radius: float, style: StringName, door_angles: Array[float], seed_value: int) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var spec: Vector2 = STYLE_SHAPE.get(style, STYLE_SHAPE[&"cave"])
	var corners: int = int(spec.x)
	var wobble: float = spec.y
	var phase_a: float = rng.randf() * TAU
	var phase_b: float = rng.randf() * TAU
	var spans: Array[float] = []
	for _d: int in door_angles.size():
		spans.append(atan(DOOR_HALF_M / (radius * 0.92)))
	var points: Array[Dictionary] = []
	var step: float = TAU / float(corners)
	for i: int in corners:
		var a: float = wrapf(-PI + step * (float(i) + rng.randf_range(-0.25, 0.25)), -PI, PI)
		if _near_door(a, door_angles, spans, 1.7):
			continue
		var r: float = radius * (1.0 + wobble * (0.6 * sin(a * 2.0 + phase_a) + 0.4 * sin(a * 3.0 + phase_b)))
		r *= 1.0 + rng.randf_range(-wobble, wobble) * 0.35
		points.append({"a": a, "p": Vector2(cos(a), sin(a)) * r, "door": -1})
	for d: int in door_angles.size():
		var flat: float = radius * 0.92
		for side: float in [-1.0, 1.0]:
			var a2: float = wrapf(door_angles[d] + side * spans[d], -PI, PI)
			points.append({"a": a2, "p": Vector2(cos(a2), sin(a2)) * (flat / cos(spans[d])), "door": d})
	points.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var ax: float = x["a"]
		var ay: float = y["a"]
		return ax < ay)
	return points


## True when the edge from corner i to the next is a doorway.
static func is_door_edge(points: Array[Dictionary], i: int) -> bool:
	var a: int = points[i]["door"]
	var b: int = points[(i + 1) % points.size()]["door"]
	return a >= 0 and a == b


static func _near_door(a: float, door_angles: Array[float], spans: Array[float], margin: float) -> bool:
	for d: int in door_angles.size():
		if absf(angle_difference(a, door_angles[d])) < spans[d] * margin:
			return true
	return false


## Even-odd point-in-polygon test (spawn points, tests).
static func contains(points: Array[Dictionary], at: Vector2) -> bool:
	var inside: bool = false
	var n: int = points.size()
	for i: int in n:
		var p1: Vector2 = points[i]["p"]
		var p2: Vector2 = points[(i + 1) % n]["p"]
		if (p1.y > at.y) != (p2.y > at.y):
			var x: float = p1.x + (at.y - p1.y) / (p2.y - p1.y) * (p2.x - p1.x)
			if at.x < x:
				inside = not inside
	return inside
