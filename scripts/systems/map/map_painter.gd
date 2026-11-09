class_name MapPainter
extends RefCounted
## Paints a top-down map image from GrayboxBlock geometry: ground slabs first, then blocks
## sorted by height (taller = lighter), non-solid blocks (water, leaves) translucent.

const OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.35)


static func paint(root: Node, world_rect: Rect2, px: int) -> Image:
	var img: Image = Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.07, 0.1))
	paint_into(img, root, world_rect)
	return img


## Adds the blocks under `root` to an existing map image (a chunk streamed in later).
static func paint_into(img: Image, root: Node, world_rect: Rect2) -> void:
	var px: int = img.get_width()
	var blocks: Array[GrayboxBlock] = []
	_gather(root, blocks)
	blocks.sort_custom(func(a: GrayboxBlock, b: GrayboxBlock) -> bool:
		return _top(a) < _top(b))
	for b: GrayboxBlock in blocks:
		_draw_block(img, b, world_rect, px)


static func _gather(node: Node, out: Array[GrayboxBlock]) -> void:
	for child: Node in node.get_children():
		if child is GrayboxBlock:
			out.append(child)
		elif child.get_child_count() > 0:
			_gather(child, out)


static func _top(b: GrayboxBlock) -> float:
	return b.global_position.y + b.size.y * 0.5


static func _draw_block(img: Image, b: GrayboxBlock, rect: Rect2, px: int) -> void:
	var t: Transform3D = b.global_transform
	var hx: Vector3 = t.basis.x * b.size.x * 0.5
	var hz: Vector3 = t.basis.z * b.size.z * 0.5
	var c: Vector3 = t.origin
	var corners: PackedVector2Array = PackedVector2Array()
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var w: Vector3 = c + hx * s.x + hz * s.y
		corners.append(Vector2((w.x - rect.position.x) / rect.size.x * px, (w.z - rect.position.y) / rect.size.y * px))
	var lo: Vector2 = corners[0]
	var hi: Vector2 = corners[0]
	for p: Vector2 in corners:
		lo = lo.min(p)
		hi = hi.max(p)
	var x0: int = clampi(floori(lo.x), 0, px - 1)
	var x1: int = clampi(ceili(hi.x), 0, px - 1)
	var y0: int = clampi(floori(lo.y), 0, px - 1)
	var y1: int = clampi(ceili(hi.y), 0, px - 1)
	var height: float = clampf(_top(b) / 20.0, 0.0, 1.0)
	var color: Color = b.color.lightened(height * 0.35)
	var alpha: float = 1.0 if b.solid else 0.55
	var axis_aligned: bool = absf(t.basis.x.z) < 0.001
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var p2: Vector2 = Vector2(x + 0.5, y + 0.5)
			if not axis_aligned and not Geometry2D.is_point_in_polygon(p2, corners):
				continue
			var edge: bool = x == x0 or x == x1 or y == y0 or y == y1
			var col: Color = img.get_pixel(x, y).lerp(color, alpha)
			if edge and b.size.x < 60.0:
				col = col.lerp(OUTLINE, OUTLINE.a)
			img.set_pixel(x, y, col)
