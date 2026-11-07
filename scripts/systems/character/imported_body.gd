class_name ImportedBody
extends Node3D
## Skinned hero mesh (tools/import_hero.gd output) driven by CharacterRig's joints:
## one Skeleton3D bone per joint, same hierarchy and rest, so a joint's local transform
## is copied straight into the bone pose every frame.

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var _rig: CharacterRig
var _bone_ids: Array[StringName] = []


func setup(rig: CharacterRig, mesh: ArrayMesh, albedo: Texture2D, normal: Texture2D, outline: bool) -> void:
	_rig = rig
	name = "ImportedBody"
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	var skin: Skin = Skin.new()
	var global_rest: Dictionary[StringName, Vector3] = {}
	for row: Array in CharacterRig.JOINTS:
		var id: StringName = row[0]
		var parent_id: StringName = row[1]
		var bone: int = skeleton.add_bone(String(id))
		if parent_id != &"":
			skeleton.set_bone_parent(bone, skeleton.find_bone(String(parent_id)))
		var local: Vector3 = rig.rest_positions[id]
		skeleton.set_bone_rest(bone, Transform3D(Basis.IDENTITY, local))
		global_rest[id] = (global_rest[parent_id] if parent_id != &"" else Vector3.ZERO) + local
		skin.add_named_bind(String(id), Transform3D(Basis.IDENTITY, -global_rest[id]))
		_bone_ids.append(id)
	skeleton.reset_bone_poses()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Body"
	mesh_instance.mesh = mesh
	mesh_instance.skin = skin
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = mesh_instance.get_path_to(skeleton)
	mesh_instance.material_override = _material(albedo, normal, outline)


static func _material(albedo: Texture2D, normal: Texture2D, outline: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = albedo
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.85
	m.metallic = 0.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	if normal != null:
		m.normal_enabled = true
		m.normal_texture = normal
		m.normal_scale = 0.6
	if outline:
		var o: ShaderMaterial = ShaderMaterial.new()
		o.shader = CharacterRig.OUTLINE_SHADER
		o.set_shader_parameter(&"width", 0.004)
		m.next_pass = o
	return m


## Copies the rig's joint poses into the skeleton (call after the pose is applied).
func sync_from_rig() -> void:
	for i: int in _bone_ids.size():
		var j: Node3D = _rig.joints[_bone_ids[i]]
		skeleton.set_bone_pose_position(i, j.position)
		skeleton.set_bone_pose_rotation(i, j.quaternion)
