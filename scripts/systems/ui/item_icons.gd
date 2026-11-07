class_name ItemIcons
extends RefCounted
## Procedural item icons (Big Phase 2 placeholder art): a rarity-tinted plate with a framed
## border and a white glyph per item kind/slot. Textures are cached by the Codex autoload
## (Codex.item_icon) — never in a static dictionary.

const SIZE: int = 96
const GLYPH_COLOR: Color = Color(0.95, 0.97, 1.0)
const GLYPH_SHADOW: Color = Color(0, 0, 0, 0.45)

## Glyph polygons in 0..1 space (y down). Several polygons per glyph.
const GLYPHS: Dictionary[StringName, Array] = {
	&"sword": [[Vector2(0.47, 0.1), Vector2(0.53, 0.1), Vector2(0.55, 0.62), Vector2(0.45, 0.62)],
		[Vector2(0.3, 0.62), Vector2(0.7, 0.62), Vector2(0.7, 0.68), Vector2(0.3, 0.68)],
		[Vector2(0.46, 0.68), Vector2(0.54, 0.68), Vector2(0.54, 0.86), Vector2(0.46, 0.86)],
		[Vector2(0.43, 0.86), Vector2(0.57, 0.86), Vector2(0.57, 0.91), Vector2(0.43, 0.91)]],
	&"shield": [[Vector2(0.25, 0.18), Vector2(0.75, 0.18), Vector2(0.75, 0.5), Vector2(0.5, 0.86), Vector2(0.25, 0.5)]],
	&"helm": [[Vector2(0.24, 0.62), Vector2(0.26, 0.38), Vector2(0.38, 0.22), Vector2(0.62, 0.22), Vector2(0.74, 0.38),
		Vector2(0.76, 0.62), Vector2(0.62, 0.62), Vector2(0.6, 0.48), Vector2(0.4, 0.48), Vector2(0.38, 0.62)],
		[Vector2(0.24, 0.66), Vector2(0.76, 0.66), Vector2(0.72, 0.78), Vector2(0.28, 0.78)]],
	&"armor": [[Vector2(0.3, 0.18), Vector2(0.42, 0.22), Vector2(0.5, 0.3), Vector2(0.58, 0.22), Vector2(0.7, 0.18),
		Vector2(0.84, 0.32), Vector2(0.74, 0.44), Vector2(0.72, 0.84), Vector2(0.28, 0.84), Vector2(0.26, 0.44), Vector2(0.16, 0.32)]],
	&"gloves": [[Vector2(0.3, 0.86), Vector2(0.3, 0.42), Vector2(0.36, 0.2), Vector2(0.42, 0.2), Vector2(0.44, 0.4),
		Vector2(0.5, 0.16), Vector2(0.56, 0.16), Vector2(0.58, 0.4), Vector2(0.64, 0.22), Vector2(0.7, 0.24),
		Vector2(0.7, 0.5), Vector2(0.78, 0.42), Vector2(0.82, 0.48), Vector2(0.68, 0.7), Vector2(0.68, 0.86)]],
	&"boots": [[Vector2(0.34, 0.14), Vector2(0.56, 0.14), Vector2(0.56, 0.62), Vector2(0.82, 0.7), Vector2(0.82, 0.84),
		Vector2(0.3, 0.84), Vector2(0.3, 0.62)]],
	&"ring": [[Vector2(0.5, 0.3), Vector2(0.72, 0.4), Vector2(0.76, 0.6), Vector2(0.62, 0.8), Vector2(0.38, 0.8),
		Vector2(0.24, 0.6), Vector2(0.28, 0.4)], [Vector2(0.42, 0.12), Vector2(0.58, 0.12), Vector2(0.62, 0.24), Vector2(0.5, 0.34), Vector2(0.38, 0.24)]],
	&"necklace": [[Vector2(0.2, 0.16), Vector2(0.26, 0.16), Vector2(0.5, 0.56), Vector2(0.74, 0.16), Vector2(0.8, 0.16), Vector2(0.53, 0.62), Vector2(0.47, 0.62)],
		[Vector2(0.5, 0.56), Vector2(0.64, 0.7), Vector2(0.5, 0.88), Vector2(0.36, 0.7)]],
	&"rune": [[Vector2(0.5, 0.12), Vector2(0.84, 0.5), Vector2(0.5, 0.88), Vector2(0.16, 0.5)]],
	&"potion": [[Vector2(0.42, 0.12), Vector2(0.58, 0.12), Vector2(0.58, 0.34), Vector2(0.78, 0.56), Vector2(0.74, 0.82),
		Vector2(0.5, 0.9), Vector2(0.26, 0.82), Vector2(0.22, 0.56), Vector2(0.42, 0.34)]],
	&"food": [[Vector2(0.2, 0.5), Vector2(0.3, 0.32), Vector2(0.5, 0.24), Vector2(0.7, 0.32), Vector2(0.8, 0.5),
		Vector2(0.76, 0.7), Vector2(0.24, 0.7)], [Vector2(0.18, 0.74), Vector2(0.82, 0.74), Vector2(0.78, 0.82), Vector2(0.22, 0.82)]],
	&"gem": [[Vector2(0.3, 0.3), Vector2(0.7, 0.3), Vector2(0.84, 0.46), Vector2(0.5, 0.86), Vector2(0.16, 0.46)]],
	&"key": [[Vector2(0.2, 0.3), Vector2(0.44, 0.3), Vector2(0.44, 0.54), Vector2(0.2, 0.54)],
		[Vector2(0.44, 0.38), Vector2(0.84, 0.38), Vector2(0.84, 0.46), Vector2(0.44, 0.46)],
		[Vector2(0.7, 0.46), Vector2(0.76, 0.46), Vector2(0.76, 0.62), Vector2(0.7, 0.62)]],
	&"coin": [[Vector2(0.5, 0.18), Vector2(0.73, 0.27), Vector2(0.82, 0.5), Vector2(0.73, 0.73), Vector2(0.5, 0.82),
		Vector2(0.27, 0.73), Vector2(0.18, 0.5), Vector2(0.27, 0.27)]],
	&"book": [[Vector2(0.24, 0.16), Vector2(0.72, 0.16), Vector2(0.76, 0.2), Vector2(0.76, 0.86), Vector2(0.24, 0.86)],
		[Vector2(0.3, 0.16), Vector2(0.34, 0.16), Vector2(0.34, 0.86), Vector2(0.3, 0.86)]],
	&"unknown": [[Vector2(0.36, 0.3), Vector2(0.5, 0.2), Vector2(0.64, 0.3), Vector2(0.64, 0.46), Vector2(0.54, 0.56),
		Vector2(0.54, 0.66), Vector2(0.46, 0.66), Vector2(0.46, 0.52), Vector2(0.56, 0.42), Vector2(0.56, 0.32),
		Vector2(0.5, 0.28), Vector2(0.44, 0.32), Vector2(0.44, 0.38), Vector2(0.36, 0.38)],
		[Vector2(0.46, 0.72), Vector2(0.54, 0.72), Vector2(0.54, 0.8), Vector2(0.46, 0.8)]],
}


## Glyph id for an item (slot first, then kind).
static func glyph_for(item: ItemData, identified: bool = true) -> StringName:
	if item == null or not identified:
		return &"unknown"
	match item.slot:
		ItemData.Slot.WEAPON:
			return &"sword"
		ItemData.Slot.OFF_HAND:
			return &"shield"
		ItemData.Slot.HELM:
			return &"helm"
		ItemData.Slot.ARMOR:
			return &"armor"
		ItemData.Slot.GLOVES:
			return &"gloves"
		ItemData.Slot.BOOTS:
			return &"boots"
		ItemData.Slot.RING, ItemData.Slot.RING_2:
			return &"ring"
		ItemData.Slot.NECKLACE:
			return &"necklace"
		ItemData.Slot.RUNE_CORE:
			return &"rune"
		ItemData.Slot.COSTUME:
			return &"armor"
	match item.kind:
		ItemData.Kind.CONSUMABLE:
			return &"potion"
		ItemData.Kind.FOOD:
			return &"food"
		ItemData.Kind.KEY:
			return &"key"
		ItemData.Kind.CURRENCY:
			return &"coin"
		ItemData.Kind.SKILL_BOOK:
			return &"book"
	return &"gem"


## Draws one icon image: radial rarity glow, inner frame, glyph with drop shadow.
static func draw(glyph: StringName, rarity: int) -> Image:
	var img: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c: Color = ItemData.RARITY_COLORS.get(rarity, Color.WHITE)
	var center: Vector2 = Vector2(SIZE, SIZE) * 0.5
	var polys: Array = GLYPHS.get(glyph, GLYPHS[&"gem"])
	var border: int = 4 if rarity >= ItemData.Rarity.LEGENDARY else 3
	for y: int in SIZE:
		for x: int in SIZE:
			var p: Vector2 = Vector2(x, y)
			var d: float = p.distance_to(center) / (SIZE * 0.7)
			var px: Color = Color(0.04, 0.06, 0.1).lerp(c.darkened(0.45), clampf(1.0 - d, 0.0, 1.0))
			var edge: int = mini(mini(x, y), mini(SIZE - 1 - x, SIZE - 1 - y))
			if edge < border:
				px = c.lightened(0.15 if edge == 0 else 0.0)
			elif edge < border + 2:
				px = px.lerp(c, 0.35)
			var uv: Vector2 = (p + Vector2(0.5, 0.5)) / float(SIZE)
			if _inside(polys, uv - Vector2(0.025, 0.025)) and not _inside(polys, uv):
				px = px.lerp(GLYPH_SHADOW, GLYPH_SHADOW.a)
			if _inside(polys, uv):
				px = GLYPH_COLOR.lerp(c.lightened(0.5), 0.25 if rarity >= ItemData.Rarity.EPIC else 0.1)
			img.set_pixel(x, y, px)
	if rarity >= ItemData.Rarity.MYTHIC:
		_sparkles(img, c)
	return img


static func _inside(polys: Array, uv: Vector2) -> bool:
	for poly: Array in polys:
		var pts: PackedVector2Array = PackedVector2Array(poly)
		if Geometry2D.is_point_in_polygon(uv, pts):
			return true
	return false


static func _sparkles(img: Image, c: Color) -> void:
	for s: Vector2i in [Vector2i(18, 20), Vector2i(76, 26), Vector2i(70, 74), Vector2i(22, 70)]:
		for k: int in range(-4, 5):
			var a: float = 1.0 - absf(k) / 5.0
			img.set_pixel(s.x + k, s.y, img.get_pixel(s.x + k, s.y).lerp(Color.WHITE.lerp(c, 0.3), a))
			img.set_pixel(s.x, s.y + k, img.get_pixel(s.x, s.y + k).lerp(Color.WHITE.lerp(c, 0.3), a))
