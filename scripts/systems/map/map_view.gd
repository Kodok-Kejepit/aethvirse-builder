class_name MapView
extends Control
## Draws the RegionMap: picture, fog of war, markers. Full mode fits the whole region;
## minimap mode follows the player at `zoom` and clips to a circle-ish frame.

const COLORS: Dictionary[int, Color] = {
	RegionMap.Marker.PLAYER: Color(1, 1, 1), RegionMap.Marker.WAYSTONE: Color(0.4, 0.85, 1.0),
	RegionMap.Marker.ROAD: Color(0.7, 0.9, 1.0), RegionMap.Marker.GATE: Color(0.55, 0.6, 1.0),
	RegionMap.Marker.RED_GATE: Color(0.9, 0.1, 0.12), RegionMap.Marker.NPC: Color(1.0, 0.85, 0.4),
	RegionMap.Marker.PLACE: Color(0.85, 0.92, 1.0), RegionMap.Marker.HOLLOW: Color(1, 1, 1),
}
const FOG_COLOR: Color = Color(0.02, 0.03, 0.06, 0.92)

@export var minimap: bool = false
## Minimap: fraction of the region shown across the widget.
@export var zoom: float = 0.28
@export var show_labels: bool = true

var _map: RegionMap = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


## Minimap redraws ~15 times a second (full map every frame while open).
const MINIMAP_REDRAW_S: float = 0.066
var _redraw_t: float = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_redraw_t += delta
	if not minimap or _redraw_t >= MINIMAP_REDRAW_S:
		_redraw_t = 0.0
		queue_redraw()


## Rect (in this control) where uv (0..1) of the region maps to.
func _view() -> Rect2:
	if not minimap:
		var side: float = minf(size.x, size.y)
		return Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var full: float = size.x / zoom
	var center_uv: Vector2 = Vector2(0.5, 0.5)
	var player: Node3D = GameState.player
	if player != null and _map != null:
		center_uv = _map.to_uv(player.global_position)
	return Rect2(size * 0.5 - center_uv * full, Vector2(full, full))


func _draw() -> void:
	if _map == null or not is_instance_valid(_map):
		_map = RegionMap.current(get_tree())
	var frame: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(frame, Color(0.02, 0.04, 0.08, 0.85))
	if _map == null or _map.texture == null:
		return
	var v: Rect2 = _view()
	draw_texture_rect(_map.texture, v, false)
	draw_texture_rect(_map.fog_texture(), v, false)
	var font: Font = get_theme_default_font()
	var fs: int = CodexTheme.px(14 if minimap else 18)
	for m: Array in _map.markers():
		var kind: int = m[0]
		var uv: Vector2 = m[1]
		var label: String = m[2]
		var yaw: float = m[3]
		var p: Vector2 = v.position + uv * v.size
		if not frame.grow(-4).has_point(p):
			continue
		_draw_marker(kind, p, yaw)
		if show_labels and label != "" and (not minimap or kind == RegionMap.Marker.PLACE):
			var col: Color = COLORS.get(kind, Color.WHITE)
			draw_string_outline(font, p + Vector2(10, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.85))
			draw_string(font, p + Vector2(10, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_rect(frame, CodexTheme.ACCENT, false, 2.0)


func _draw_marker(kind: int, p: Vector2, yaw: float) -> void:
	var c: Color = COLORS.get(kind, Color.WHITE)
	var s: float = CodexTheme.px(7 if minimap else 9)
	match kind:
		RegionMap.Marker.PLAYER:
			# Model faces -Z; map +y = world +z, so forward on the map is -y rotated by yaw.
			var fwd: Vector2 = Vector2(-sin(yaw), -cos(yaw))
			var side: Vector2 = Vector2(-fwd.y, fwd.x)
			var pts: PackedVector2Array = PackedVector2Array([p + fwd * s * 1.6, p - fwd * s + side * s, p - fwd * s * 0.4, p - fwd * s - side * s])
			draw_colored_polygon(pts, c)
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.5)
		RegionMap.Marker.WAYSTONE, RegionMap.Marker.ROAD:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.7, 0), p + Vector2(0, s), p + Vector2(-s * 0.7, 0)]), c)
		RegionMap.Marker.GATE, RegionMap.Marker.RED_GATE, RegionMap.Marker.HOLLOW:
			draw_arc(p, s, 0.0, TAU, 18, c, 3.0)
			draw_circle(p, s * 0.35, c)
		RegionMap.Marker.NPC:
			draw_circle(p, s * 0.45, c)
		RegionMap.Marker.PLACE:
			pass
