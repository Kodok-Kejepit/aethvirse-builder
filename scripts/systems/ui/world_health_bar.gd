class_name WorldHealthBar
extends Node3D
## Billboard HP bar above enemies (two Sprite3D: back + left-aligned fill via region).

const TEXTURE_W: int = 100
const TEXTURE_H: int = 8

@export var width_px: float = 140.0
@export var fill_color: Color = Color(0.9, 0.25, 0.25)
@export var back_color: Color = Color(0.05, 0.05, 0.08, 0.75)
@export var pixel_size: float = 0.0012
## Bars render through walls (no depth test), so only show them up close.
@export var visible_distance_m: float = 28.0

var _texture: ImageTexture
var _back: Sprite3D
var _fill: Sprite3D


func _ready() -> void:
	var image: Image = Image.create(TEXTURE_W, TEXTURE_H, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_texture = ImageTexture.create_from_image(image)
	_back = _make_sprite(back_color, 0)
	_fill = _make_sprite(fill_color, 1)
	set_ratio(1.0)


func set_ratio(ratio: float) -> void:
	var r: float = clampf(ratio, 0.0, 1.0)
	_fill.region_rect = Rect2(0.0, 0.0, TEXTURE_W * r, TEXTURE_H)
	_fill.visible = r > 0.0


func _make_sprite(color: Color, priority: int) -> Sprite3D:
	var sprite: Sprite3D = Sprite3D.new()
	sprite.texture = _texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.fixed_size = true
	sprite.shaded = false
	sprite.modulate = color
	sprite.render_priority = priority
	sprite.centered = false
	sprite.offset = Vector2(-TEXTURE_W * 0.5, -TEXTURE_H * 0.5)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0.0, 0.0, TEXTURE_W, TEXTURE_H)
	sprite.pixel_size = pixel_size * width_px / TEXTURE_W
	sprite.visibility_range_end = visible_distance_m
	add_child(sprite)
	return sprite
