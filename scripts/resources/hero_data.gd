class_name HeroData
extends Resource
## Playable character appearance (picked at New Game, independent of the class).
## Imported body = skinned meshes made by tools/import_hero.gd (hi for PC, lo for phones);
## missing files fall back to the procedural CharacterRig.

enum Hair { LONG, SHORT }

@export var id: StringName = &""
## Translation key.
@export var display_name: String = ""
## Translation key.
@export var description: String = ""
## Each hero is one class (owner: one character per class, no free class pick).
@export var class_id: StringName = &"vanguard"
@export_file("*.res") var mesh_hi: String = ""
@export_file("*.res") var mesh_lo: String = ""
@export_file("*.jpg", "*.png") var albedo_hi: String = ""
@export_file("*.jpg", "*.png") var albedo_lo: String = ""
@export_file("*.jpg", "*.png") var normal_hi: String = ""
## Animated rig (tools/import_rigged_hero.gd): preferred over the static mesh when present.
@export_file("*.scn") var rig_scene: String = ""
@export_file("*.jpg", "*.png") var rig_albedo: String = ""
## Spirit dragon on skills.
@export var has_dragon: bool = false
## Procedural fallback hairstyle.
@export var hair: Hair = Hair.LONG
@export var hair_color: Color = Color(0.14, 0.11, 0.1)
@export var hair_tip_color: Color = Color(0.22, 0.18, 0.16)


const DEFAULT_ID: StringName = &"dragon_maiden"
const IDS: Array[StringName] = [&"dragon_maiden", &"starblade"]
## Every class in New Game order; classes whose hero is not made yet show as locked.
const ROSTER: Array[StringName] = [&"vanguard", &"phantom", &"arcanist", &"ranger"]


## The hero who plays this class, or &"" while the owner has not made one yet.
static func hero_for_class(cls: StringName) -> StringName:
	for hid: StringName in IDS:
		if load_hero(hid).class_id == cls:
			return hid
	return &""


static func path_for(hero_id: StringName) -> String:
	return "res://data/heroes/%s.tres" % hero_id


static func load_hero(hero_id: StringName) -> HeroData:
	var path: String = path_for(hero_id)
	if not ResourceLoader.exists(path):
		path = path_for(DEFAULT_ID)
	return load(path) as HeroData


func has_rig() -> bool:
	return not rig_scene.is_empty() and ResourceLoader.exists(rig_scene)


func has_imported_model() -> bool:
	return not mesh_lo.is_empty() and ResourceLoader.exists(mesh_lo)


## Best available body mesh: hi on PC when it was exported, lo otherwise.
func body_mesh(lite: bool) -> ArrayMesh:
	var path: String = mesh_lo if lite or not ResourceLoader.exists(mesh_hi) else mesh_hi
	return load(path) as ArrayMesh


func body_texture(lite: bool) -> Texture2D:
	var path: String = albedo_lo if lite or not ResourceLoader.exists(albedo_hi) else albedo_hi
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func body_normal(lite: bool) -> Texture2D:
	if lite or not ResourceLoader.exists(normal_hi):
		return null
	return load(normal_hi) as Texture2D
