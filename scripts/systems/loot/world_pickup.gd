class_name WorldPickup
extends Area3D
## Loot on the ground. Walk over it to pick it up. Its icon floats over a rarity-colored
## glow: Rare+ adds a light pillar, Epic+ sparkles, Legendary+ a pulsing light.

const BOB_HEIGHT: float = 0.15
const LIFETIME_S: float = 180.0

var stack: ItemStack
var _icon: Sprite3D
var _beam: MeshInstance3D = null
var _light: OmniLight3D = null
var _age: float = 0.0


static func spawn(parent: Node, at: Vector3, item_stack: ItemStack) -> WorldPickup:
	var pickup: WorldPickup = WorldPickup.new()
	pickup.stack = item_stack
	pickup.position = at
	parent.add_child(pickup)
	return pickup


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 1.2
	shape.shape = sphere
	add_child(shape)
	var color: Color = _color()
	var rarity: int = _rarity()
	_icon = Sprite3D.new()
	_icon.texture = Codex.icon_for_stack(stack)
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.pixel_size = 0.006
	_icon.no_depth_test = false
	_icon.shaded = false
	add_child(_icon)
	var disc: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.55
	cyl.height = 0.02
	cyl.material = _glow_material(color, 0.35)
	disc.mesh = cyl
	disc.position.y = 0.03
	add_child(disc)
	if rarity >= ItemData.Rarity.RARE:
		_beam = MeshInstance3D.new()
		var beam: CylinderMesh = CylinderMesh.new()
		beam.top_radius = 0.05
		beam.bottom_radius = 0.22
		beam.height = 3.0 + float(rarity - ItemData.Rarity.RARE) * 1.2
		beam.material = _glow_material(color, 0.45)
		_beam.mesh = beam
		_beam.position.y = beam.height * 0.5
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_beam)
	if rarity >= ItemData.Rarity.EPIC:
		add_child(_sparkles(color, rarity))
	if rarity >= ItemData.Rarity.LEGENDARY:
		_light = OmniLight3D.new()
		_light.light_color = color
		_light.omni_range = 4.0
		_light.light_energy = 1.2
		_light.position.y = 1.0
		add_child(_light)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_age += delta
	_icon.position.y = 0.7 + sin(_age * 3.0) * BOB_HEIGHT
	if _light != null:
		_light.light_energy = 1.0 + 0.5 * sin(_age * 4.0)
	if _age > LIFETIME_S:
		queue_free()


func _rarity() -> int:
	var item: ItemData = GameState.items.get_item(stack.item_id)
	if item == null or not stack.identified:
		return ItemData.Rarity.COMMON
	return ItemStats.rarity_of(stack, item)


static func _glow_material(color: Color, alpha: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color, alpha)
	return m


static func _sparkles(color: Color, rarity: int) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = 10 + (rarity - ItemData.Rarity.EPIC) * 8
	p.lifetime = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.2
	p.position.y = 0.4
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var m: StandardMaterial3D = _glow_material(color.lightened(0.4), 0.9)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = m
	p.mesh = quad
	return p


func _color() -> Color:
	var item: ItemData = GameState.items.get_item(stack.item_id)
	if item == null:
		return Color.WHITE
	return ItemData.RARITY_COLORS[ItemStats.rarity_of(stack, item)]


func _on_body(body: Node3D) -> void:
	if not body is Player:
		return
	var inv: Inventory = GameState.inventory
	var ok: bool = inv.add_stack(stack) if stack.is_unique_instance() else inv.add(stack.item_id, stack.count) == 0
	if ok:
		Codex.notify(tr(&"CODEX_MSG_PICKED") % [inv.display_name(stack), stack.count], &"reward")
		EventBus.item_picked.emit(stack.item_id, stack.count)
		queue_free()
