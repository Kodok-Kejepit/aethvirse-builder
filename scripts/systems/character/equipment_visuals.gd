class_name EquipmentVisuals
extends Node3D
## Shows worn equipment on the character: procedural armour pieces per slot tinted by
## rarity, a weapon glow, a rarity aura (Epic+ sparks, Legendary ring, Mythic flames) and
## costume models (ItemData.visual_scene) or built-in costume styles (wings, halo, cape).
## Rebuilds whenever the inventory changes.

const METAL: Color = Color(0.72, 0.74, 0.8)

var rig: CharacterRig
## slot -> nodes created for it (freed on rebuild).
var _parts: Array[Node] = []
var _spin: Array[Node3D] = []
var _time: float = 0.0


func setup(character_rig: CharacterRig) -> void:
	rig = character_rig
	name = "EquipmentVisuals"
	if GameState.inventory != null:
		GameState.inventory.changed.connect(rebuild)
	rebuild.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	for n: Node3D in _spin:
		if is_instance_valid(n):
			n.rotate_y(delta * 1.4)
			n.position.y += sin(_time * 2.0) * 0.0006


func rebuild() -> void:
	for n: Node in _parts:
		if is_instance_valid(n):
			n.queue_free()
	_parts.clear()
	_spin.clear()
	var inv: Inventory = GameState.inventory
	if inv == null or rig == null:
		return
	var weapon_item: ItemData = inv.get_equipped_item(ItemData.Slot.WEAPON)
	var custom_weapon: bool = weapon_item != null and (weapon_item.visual_prop != &"" or weapon_item.visual_scene != "")
	if rig.weapon_tip != null:
		# A weapon with its own model hides the built-in blade.
		(rig.weapon_tip.get_parent() as Node3D).visible = not custom_weapon
	var costume: ItemData = inv.get_equipped_item(ItemData.Slot.COSTUME)
	var hide_gear: bool = costume != null and costume.hides_gear
	var best: int = -1
	for slot: int in inv.equipped:
		var stack: ItemStack = inv.equipped[slot]
		var item: ItemData = inv.db.get_item(stack.item_id)
		if item == null:
			continue
		var rarity: int = ItemStats.rarity_of(stack, item) if stack.identified else ItemData.Rarity.COMMON
		best = maxi(best, rarity)
		if item.visual_scene != "" or item.visual_style != &"" or item.visual_prop != &"":
			_add_model(item, rarity)
		if hide_gear and slot != ItemData.Slot.WEAPON and slot != ItemData.Slot.COSTUME:
			continue
		_add_piece(slot, rarity)
	_aura(best)


# --- procedural gear ---------------------------------------------------------------------

func _mat(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.6
	m.roughness = 0.35
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m


func _trim(rarity: int) -> Color:
	return ItemData.RARITY_COLORS.get(rarity, Color.WHITE)


func _put(joint_id: StringName, mesh: PrimitiveMesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO,
		scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var joint: Node3D = rig.get_joint(joint_id)
	if joint == null:
		return null
	var mi: MeshInstance3D = MeshInstance3D.new()
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scale_v
	joint.add_child(mi)
	_parts.append(mi)
	return mi


func _add_piece(slot: int, rarity: int) -> void:
	var trim: Color = _trim(rarity)
	var glow: float = 0.0 if rarity < ItemData.Rarity.RARE else 0.4 + 0.3 * float(rarity - ItemData.Rarity.RARE)
	var metal: StandardMaterial3D = _mat(METAL.lerp(trim, 0.35))
	var accent: StandardMaterial3D = _mat(trim, glow)
	match slot:
		ItemData.Slot.HELM:
			var band: TorusMesh = TorusMesh.new()
			band.inner_radius = 0.1
			band.outer_radius = 0.125
			_put(&"head", band, accent, Vector3(0, 0.17, 0), Vector3(-12, 0, 0))
			if rarity >= ItemData.Rarity.EPIC:
				for side: float in [1.0, -1.0]:
					var wing: PrismMesh = PrismMesh.new()
					wing.size = Vector3(0.02, 0.16, 0.08)
					_put(&"head", wing, accent, Vector3(0.12 * side, 0.2, 0.02), Vector3(-20, 0, -35 * side))
			if rarity >= ItemData.Rarity.LEGENDARY:
				for i: int in 5:
					var spike: PrismMesh = PrismMesh.new()
					spike.size = Vector3(0.03, 0.07, 0.02)
					var a: float = -0.9 + 0.45 * float(i)
					_put(&"head", spike, accent, Vector3(sin(a) * 0.115, 0.22, -cos(a) * 0.115), Vector3(0, rad_to_deg(-a), 0))
		ItemData.Slot.ARMOR:
			for side: float in [1.0, -1.0]:
				var clav: StringName = &"clav_r" if side > 0.0 else &"clav_l"
				var pauldron: SphereMesh = SphereMesh.new()
				pauldron.radius = 0.08
				pauldron.height = 0.1
				_put(clav, pauldron, metal, Vector3(0.06 * side, 0.04, 0), Vector3(0, 0, -20 * side), Vector3(1.2, 0.7, 1.1))
				var edge: TorusMesh = TorusMesh.new()
				edge.inner_radius = 0.07
				edge.outer_radius = 0.085
				_put(clav, edge, accent, Vector3(0.06 * side, 0.03, 0), Vector3(0, 0, -20 * side), Vector3(1.2, 1, 1.1))
			if rarity >= ItemData.Rarity.RARE:
				var gem: PrismMesh = PrismMesh.new()
				gem.size = Vector3(0.06, 0.08, 0.03)
				_put(&"chest", gem, _mat(trim, 1.6), Vector3(0, 0.02, -0.13), Vector3(180, 0, 0))
		ItemData.Slot.GLOVES:
			for side: String in ["r", "l"]:
				var bracer: CylinderMesh = CylinderMesh.new()
				bracer.top_radius = 0.048
				bracer.bottom_radius = 0.052
				bracer.height = 0.12
				_put(StringName("fore_" + side), bracer, metal, Vector3(0, -0.17, 0))
				var cuff: TorusMesh = TorusMesh.new()
				cuff.inner_radius = 0.046
				cuff.outer_radius = 0.058
				_put(StringName("fore_" + side), cuff, accent, Vector3(0, -0.11, 0))
		ItemData.Slot.BOOTS:
			for side: String in ["r", "l"]:
				var greave: CylinderMesh = CylinderMesh.new()
				greave.top_radius = 0.06
				greave.bottom_radius = 0.05
				greave.height = 0.2
				_put(StringName("shin_" + side), greave, metal, Vector3(0, -0.3, -0.01))
				var knee: SphereMesh = SphereMesh.new()
				knee.radius = 0.045
				knee.height = 0.07
				_put(StringName("shin_" + side), knee, accent, Vector3(0, -0.02, -0.05))
		ItemData.Slot.NECKLACE:
			var pendant: PrismMesh = PrismMesh.new()
			pendant.size = Vector3(0.035, 0.05, 0.02)
			_put(&"chest", pendant, _mat(trim, 1.4), Vector3(0, 0.1, -0.135), Vector3(180, 0, 0))
		ItemData.Slot.RING, ItemData.Slot.RING_2:
			var ring: TorusMesh = TorusMesh.new()
			ring.inner_radius = 0.018
			ring.outer_radius = 0.026
			var hand: StringName = &"hand_r" if slot == ItemData.Slot.RING else &"hand_l"
			_put(hand, ring, _mat(trim, 1.2), Vector3(0, -0.06, -0.02), Vector3(90, 0, 0))
		ItemData.Slot.OFF_HAND:
			if rig.weapon == CharacterRig.Weapon.SWORD:
				var shield: CylinderMesh = CylinderMesh.new()
				shield.top_radius = 0.2
				shield.bottom_radius = 0.2
				shield.height = 0.04
				_put(&"fore_l", shield, metal, Vector3(-0.07, -0.15, 0), Vector3(0, 0, 90))
				var boss: SphereMesh = SphereMesh.new()
				boss.radius = 0.05
				boss.height = 0.06
				_put(&"fore_l", boss, accent, Vector3(-0.1, -0.15, 0))
			else:
				var orb: SphereMesh = SphereMesh.new()
				orb.radius = 0.06
				orb.height = 0.12
				var m: MeshInstance3D = _put(&"chest", orb, _mat(trim, 1.8), Vector3(-0.35, 0.25, 0.2))
				if m != null:
					_spin.append(m)
		ItemData.Slot.WEAPON:
			if rig.weapon_tip != null and rarity >= ItemData.Rarity.RARE:
				var spark: CPUParticles3D = _sparks(trim, 6 + rarity * 2, 0.05)
				rig.weapon_tip.add_child(spark)
				_parts.append(spark)


# --- aura & costumes ---------------------------------------------------------------------

func _aura(best: int) -> void:
	if best < ItemData.Rarity.EPIC:
		return
	var c: Color = _trim(best)
	var sparks: CPUParticles3D = _sparks(c, 10 + (best - ItemData.Rarity.EPIC) * 10, 0.6)
	sparks.position = Vector3(0, 0.4, 0)
	rig.add_child(sparks)
	_parts.append(sparks)
	if best >= ItemData.Rarity.LEGENDARY:
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 0.55
		ring.outer_radius = 0.6
		var m: StandardMaterial3D = _mat(c, 2.0)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(c, 0.55)
		ring.material = m
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = ring
		mi.position.y = 0.03
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.add_child(mi)
		_parts.append(mi)
		_spin.append(mi)


func _sparks(c: Color, amount: int, radius: float) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 30.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.5
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.04, 0.04)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = c.lightened(0.3)
	quad.material = m
	p.mesh = quad
	return p


func _add_model(item: ItemData, rarity: int) -> void:
	var joint: Node3D = rig.get_joint(item.visual_joint)
	if joint == null:
		joint = rig.get_joint(&"chest")
	var holder: Node3D = Node3D.new()
	holder.position = item.visual_offset
	holder.rotation_degrees = item.visual_rotation_deg
	holder.scale = Vector3.ONE * item.visual_scale
	joint.add_child(holder)
	_parts.append(holder)
	if item.visual_prop != &"":
		var d: PropData = PropData.find(item.visual_prop)
		if d != null and PropInstance.attach_model(holder, item.visual_prop, d.size.y):
			return
	if item.visual_scene != "" and ResourceLoader.exists(item.visual_scene):
		var scene: PackedScene = load(item.visual_scene) as PackedScene
		if scene != null:
			holder.add_child(scene.instantiate())
			return
	_style(holder, item.visual_style, _trim(rarity))


func _style(holder: Node3D, style: StringName, c: Color) -> void:
	match style:
		&"wings":
			for side: float in [1.0, -1.0]:
				for i: int in 4:
					var feather: PrismMesh = PrismMesh.new()
					feather.size = Vector3(0.12, 0.7 - 0.12 * float(i), 0.015)
					var mi: MeshInstance3D = MeshInstance3D.new()
					feather.material = _mat(c.lightened(0.2 * float(i)), 1.4)
					mi.mesh = feather
					mi.position = Vector3(0.18 * side + 0.12 * side * float(i), 0.15 - 0.05 * float(i), 0.16)
					mi.rotation_degrees = Vector3(-15, 0, -(55 + 18 * float(i)) * side)
					holder.add_child(mi)
		&"halo":
			var halo: TorusMesh = TorusMesh.new()
			halo.inner_radius = 0.16
			halo.outer_radius = 0.19
			var m: StandardMaterial3D = _mat(c, 3.0)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			halo.material = m
			var mi2: MeshInstance3D = MeshInstance3D.new()
			mi2.mesh = halo
			mi2.position = Vector3(0, 0.38, 0.05)
			mi2.rotation_degrees = Vector3(-15, 0, 0)
			holder.add_child(mi2)
			_spin.append(mi2)
			var flames: CPUParticles3D = _sparks(c, 24, 0.18)
			flames.position = Vector3(0, 0.38, 0.05)
			holder.add_child(flames)
		&"cape":
			var cape: BoxMesh = BoxMesh.new()
			cape.size = Vector3(0.42, 1.05, 0.02)
			cape.material = _mat(c.darkened(0.3), 0.3)
			var mi3: MeshInstance3D = MeshInstance3D.new()
			mi3.mesh = cape
			mi3.position = Vector3(0, -0.35, 0.16)
			mi3.rotation_degrees = Vector3(-8, 0, 0)
			holder.add_child(mi3)
