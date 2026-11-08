class_name GateTheme
extends RefCounted
## Look of a Gate dungeon by rank: floor / wall surfaces baked from the owner's tile and
## wall models (tools/bake_surface_textures.gd), the pillar model, and the light tint.
## Missing textures / models fall back to the old rank-coloured graybox.

const SURFACE_DIR: String = "res://assets/textures/surfaces/%s.jpg"
## Metres per texture repeat.
const FLOOR_TILE_M: float = 4.0
const WALL_TILE_M: float = 5.0

## Rank (E..S) -> [floor tile, wall, pillar model].
const BY_RANK: Array[Array] = [
	[&"tile_dungeon_moss", &"wall_mossy_stone", &"pillar_rooted"],
	[&"tile_dark_slate", &"wall_dungeon_grey", &"pillar_rooted"],
	[&"tile_concrete", &"wall_mossy_dark", &"pillar_astral"],
	[&"tile_marble_snow", &"wall_dungeon_dark", &"pillar_monolith"],
	[&"tile_metal", &"wall_carved", &"pillar_astral"],
	[&"tile_lava_crack", &"wall_carved", &"pillar_obsidian"],
]
const RED: Array = [&"tile_lava_crack", &"wall_dungeon_dark", &"pillar_obsidian"]
## Rank (E..S) -> door models (owner's downloads) the rooms pick from.
const DOORS_BY_RANK: Array[Array] = [
	[&"door_wood_heavy", &"door_cellar", &"door_ruined_stone"],
	[&"door_stone_arch", &"door_ruined_stone", &"door_barred_wall"],
	[&"door_forgotten", &"door_dark_twin", &"door_portcullis"],
	[&"door_runeforged", &"door_ornate", &"door_forgotten"],
	[&"door_dragon", &"door_ornate", &"door_infernal"],
	[&"door_infernal", &"door_lava", &"door_dark_twin"],
]
const RED_DOORS: Array[StringName] = [&"door_lava", &"door_infernal"]

var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var pillar_model: StringName
var tint: Color
var door_models: Array[StringName] = []
var floor_id: StringName
var wall_id: StringName


func _init(rank: int, red: bool) -> void:
	var row: Array = RED if red else BY_RANK[clampi(rank, 0, BY_RANK.size() - 1)]
	tint = GateData.RANK_COLORS.get(clampi(rank, 0, BY_RANK.size() - 1) as GateData.Rank, Color(0.5, 0.6, 0.8))
	if red:
		tint = Color(1.0, 0.25, 0.2)
	floor_id = row[0]
	wall_id = row[1]
	floor_material = surface(floor_id, FLOOR_TILE_M, tint.darkened(0.55))
	wall_material = surface(wall_id, WALL_TILE_M, tint.darkened(0.55))
	pillar_model = row[2]
	door_models.assign(RED_DOORS if red else DOORS_BY_RANK[clampi(rank, 0, DOORS_BY_RANK.size() - 1)])


## World-space triplanar material from a baked surface, or a flat colour.
static func surface(id: StringName, tile_m: float, fallback: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	var path: String = SURFACE_DIR % id
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path) as Texture2D
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / tile_m
		m.roughness = 0.9
	else:
		m.albedo_color = fallback
	return m


func has_textures() -> bool:
	return floor_material.albedo_texture != null


## Puts the pillar model on a pillar body (box collision stays). False if no model.
func dress_pillar(body: StaticBody3D, height: float) -> bool:
	var holder: Node3D = Node3D.new()
	holder.position = Vector3(0.0, -height * 0.5, 0.0)
	body.add_child(holder)
	if not PropInstance.attach_model(holder, pillar_model, height):
		holder.queue_free()
		return false
	for child: Node in body.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	return true
