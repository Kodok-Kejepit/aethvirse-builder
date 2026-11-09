class_name AssetPrefetch
extends RefCounted
## Lists the models and textures a chunk will load in its _ready (props, decor / tree models,
## chest models, monster bodies) by reading the packed scene's stored properties, so the
## WorldStreamer can load them on a worker thread before the chunk enters the world.
## Before this, a chunk with a not-yet-seen model froze the game for 0.1-1 s while walking.


static func paths_for(scene: PackedScene) -> PackedStringArray:
	var ids: Dictionary[StringName, bool] = {}
	var extra: Dictionary[String, bool] = {}
	var state: SceneState = scene.get_state()
	for n: int in state.get_node_count():
		for p: int in state.get_node_property_count(n):
			var value: Variant = state.get_node_property_value(n, p)
			if value is StringName:
				var name_value: StringName = value
				_add_ids(ids, name_value)
			elif value is EnemyData:
				var e: EnemyData = value
				ids[StringName("mob_" + String(e.id))] = true
				var rig: String = CreatureBody.RIG_PATH % [e.id, e.id]
				if ResourceLoader.exists(rig):
					extra[rig] = true
	var out: PackedStringArray = PackedStringArray(extra.keys())
	for id: StringName in ids:
		var d: PropData = PropData.find(id)
		if d == null:
			continue
		if ResourceLoader.exists(d.mesh_path):
			out.append(d.mesh_path)
		if ResourceLoader.exists(d.albedo_path):
			out.append(d.albedo_path)
	return out


## Every model id a stored StringName may stand for (only existing ones survive find()).
static func _add_ids(ids: Dictionary[StringName, bool], value: StringName) -> void:
	if value == &"" or String(value).length() > 40:
		return
	ids[value] = true
	ids[StringName("prop_" + String(value))] = true
	ids[StringName("tree_" + String(value))] = true
	if TreeProp.VARIANTS.has(value):
		var v: Array = TreeProp.VARIANTS[value]
		var count: int = v[1]
		for i: int in count:
			ids[StringName("%s_%d" % [v[0], i + 1])] = true
	if LootChest.MODELS.has(value):
		var spec: Array = LootChest.MODELS[value]
		var model: StringName = spec[0]
		ids[model] = true
