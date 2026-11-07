class_name RegionMap
extends Node
## Map data for the current region: a top-down picture painted from the graybox blocks,
## the explored fog grid (saved in GameState.map_fog) and live markers (waystones, Gates,
## NPCs, place names). Created by RegionController; UI reads it via RegionMap.current().

const GROUP: StringName = &"region_map"
const IMAGE_PX: int = 256
const FOG_CELLS: int = 32
const REVEAL_RADIUS_M: float = 44.0
const REVEAL_EVERY_S: float = 0.5

enum Marker { PLAYER, WAYSTONE, ROAD, GATE, RED_GATE, NPC, PLACE, HOLLOW }

var region: RegionData
## World rect covered by the map (x/z min, size).
var world_rect: Rect2 = Rect2(-192, -192, 384, 384)
var texture: ImageTexture = null
var _root: Node3D
var _timer: float = 0.0


static func current(tree: SceneTree) -> RegionMap:
	return tree.get_first_node_in_group(GROUP) as RegionMap


func setup(region_data: RegionData, chunks_root: Node3D) -> void:
	region = region_data
	_root = chunks_root
	name = "RegionMap"
	add_to_group(GROUP)
	_paint.call_deferred()


func _process(delta: float) -> void:
	_timer += delta
	if _timer < REVEAL_EVERY_S:
		return
	_timer = 0.0
	var player: Node3D = GameState.player
	if player != null and region != null:
		reveal(player.global_position, REVEAL_RADIUS_M)


# --- fog ---------------------------------------------------------------------------------

func fog() -> PackedByteArray:
	var key: String = String(region.id)
	var grid: PackedByteArray = GameState.map_fog.get(key, PackedByteArray())
	if grid.size() != FOG_CELLS * FOG_CELLS:
		grid = PackedByteArray()
		grid.resize(FOG_CELLS * FOG_CELLS)
		GameState.map_fog[key] = grid
	return grid


func cell_of(world: Vector3) -> Vector2i:
	var uv: Vector2 = to_uv(world)
	return Vector2i(clampi(int(uv.x * FOG_CELLS), 0, FOG_CELLS - 1), clampi(int(uv.y * FOG_CELLS), 0, FOG_CELLS - 1))


func reveal(world: Vector3, radius: float) -> int:
	var grid: PackedByteArray = fog()
	var cell_m: float = world_rect.size.x / FOG_CELLS
	var r: int = ceili(radius / cell_m)
	var c: Vector2i = cell_of(world)
	var opened: int = 0
	for dy: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			var x: int = c.x + dx
			var y: int = c.y + dy
			if x < 0 or y < 0 or x >= FOG_CELLS or y >= FOG_CELLS or dx * dx + dy * dy > r * r:
				continue
			if grid[y * FOG_CELLS + x] == 0:
				grid[y * FOG_CELLS + x] = 1
				opened += 1
	if opened > 0:
		GameState.map_fog[String(region.id)] = grid
		_fog_dirty = true
	return opened


var _fog_tex: ImageTexture = null
var _fog_dirty: bool = true


## Fog as a tiny texture (one pixel per cell) instead of 1024 rects per draw.
func fog_texture() -> ImageTexture:
	if _fog_tex == null or _fog_dirty:
		_fog_dirty = false
		var img: Image = Image.create(FOG_CELLS, FOG_CELLS, false, Image.FORMAT_RGBA8)
		var grid: PackedByteArray = fog()
		for y: int in FOG_CELLS:
			for x: int in FOG_CELLS:
				img.set_pixel(x, y, Color(0, 0, 0, 0) if grid[y * FOG_CELLS + x] == 1 else MapView.FOG_COLOR)
		if _fog_tex == null:
			_fog_tex = ImageTexture.create_from_image(img)
		else:
			_fog_tex.update(img)
	return _fog_tex


func explored_ratio() -> float:
	var grid: PackedByteArray = fog()
	var n: int = 0
	for b: int in grid:
		n += b
	return float(n) / float(grid.size())


func to_uv(world: Vector3) -> Vector2:
	return Vector2((world.x - world_rect.position.x) / world_rect.size.x, (world.z - world_rect.position.y) / world_rect.size.y)


# --- markers -----------------------------------------------------------------------------

## Static markers are rescanned at most this often (walking the whole scene tree every
## frame made fast camera turns stutter).
const MARKER_SCAN_S: float = 0.75
var _static_markers: Array[Array] = []
var _scan_at: float = -INF


## [[Marker, uv: Vector2, label: String, yaw: float], ...]
func markers() -> Array[Array]:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _scan_at > MARKER_SCAN_S:
		_scan_at = now
		_static_markers.clear()
		var owner_node: Node = get_parent()
		if owner_node != null:
			_collect(owner_node, _static_markers)
	var out: Array[Array] = []
	var player: Node3D = GameState.player
	if player != null:
		var p: Player = player as Player
		var yaw: float = p.visual.global_rotation.y if p != null else 0.0
		out.append([Marker.PLAYER, to_uv(player.global_position), "", yaw])
	out.append_array(_static_markers)
	return out


func _collect(node: Node, out: Array[Array]) -> void:
	for child: Node in node.get_children():
		if child is Waystone:
			var w: Waystone = child
			if w.road_to != &"":
				out.append([Marker.ROAD, to_uv(w.global_position), tr(Waystone.name_key(w.road_to)), 0.0])
			elif WorldTravel.is_unlocked(w.waystone_id) or _seen(w.global_position):
				out.append([Marker.WAYSTONE, to_uv(w.global_position), tr(Waystone.name_key(w.waystone_id)), 0.0])
		elif child is GatePortal:
			var g: GatePortal = child
			if g.visible and _seen(g.global_position):
				out.append([Marker.RED_GATE if g.gate.has_rule(&"red") else Marker.GATE, to_uv(g.global_position), tr(g.gate.display_name), 0.0])
		elif child is HollowGate:
			var h: HollowGate = child
			if HollowGate.keys_held() > 0 and _seen(h.global_position):
				out.append([Marker.HOLLOW, to_uv(h.global_position), "", 0.0])
		elif child is Npc:
			var n: Npc = child
			if n.visible and _seen(n.global_position):
				out.append([Marker.NPC, to_uv(n.global_position), "", 0.0])
		elif child is Label3D:
			var l: Label3D = child
			if l.font_size >= 60 and _seen(l.global_position):
				out.append([Marker.PLACE, to_uv(l.global_position), l.text, 0.0])
		if child.get_child_count() > 0 and not child is Enemy:
			_collect(child, out)


func _seen(world: Vector3) -> bool:
	var c: Vector2i = cell_of(world)
	return fog()[c.y * FOG_CELLS + c.x] == 1


# --- painting ----------------------------------------------------------------------------

func _paint() -> void:
	if _root == null:
		return
	var img: Image = MapPainter.paint(_root, world_rect, IMAGE_PX)
	texture = ImageTexture.create_from_image(img)
