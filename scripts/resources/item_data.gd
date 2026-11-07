class_name ItemData
extends Resource
## Item definition (data/items/<id>.tres). Instances in the inventory are ItemStack.

enum Kind { CONSUMABLE, FOOD, WEAPON, ACCESSORY, ARMOR, KEY, MATERIAL, CURRENCY, SKILL_BOOK, COSTUME }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC, UNKNOWN }
enum Slot { NONE, WEAPON, OFF_HAND, HELM, ARMOR, GLOVES, BOOTS, RING, NECKLACE, RUNE_CORE, RING_2, COSTUME }

const RARITY_COLORS: Dictionary[Rarity, Color] = {
	Rarity.COMMON: Color("#B0B0B0"), Rarity.UNCOMMON: Color("#4CAF50"), Rarity.RARE: Color("#2F80ED"),
	Rarity.EPIC: Color("#9B51E0"), Rarity.LEGENDARY: Color("#F2994A"), Rarity.MYTHIC: Color("#EB5757"),
	Rarity.UNKNOWN: Color("#FFFFFF"),
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.MATERIAL
@export var rarity: Rarity = Rarity.COMMON
@export var max_stack: int = 1
@export var sell_price: int = 0
@export var can_sell: bool = true

@export_group("Equipment")
@export var slot: Slot = Slot.NONE
@export var attack: float = 0.0
## Weapons that scale with the player level ("ATK scales with level").
@export var attack_per_level: float = 0.0
@export var defense: float = 0.0
## Flat primary/derived bonuses, keys: str agi int vit sen crit lifesteal ...
@export var stat_bonuses: Dictionary[StringName, float] = {}
## Base for random drops (EquipmentGenerator picks bases per slot).
@export var is_drop_base: bool = false
## Generated drops: defense per item level.
@export var defense_per_level: float = 0.0

@export_group("Visual")
## Model shown on the character (owner costumes / unique gear): .glb, .gltf or .tscn.
@export_file("*.glb", "*.gltf", "*.tscn") var visual_scene: String = ""
## Imported model id (tools/import_props.gd → data/props/<id>.tres) — preferred over visual_scene.
@export var visual_prop: StringName = &""
## CharacterRig joint it hangs from (hips, chest, head, hand_r, fore_l, ... see CharacterRig.JOINTS).
@export var visual_joint: StringName = &"chest"
@export var visual_offset: Vector3 = Vector3.ZERO
@export var visual_rotation_deg: Vector3 = Vector3.ZERO
@export var visual_scale: float = 1.0
## Built-in procedural look when there is no model yet: wings, halo, cape, aura.
@export var visual_style: StringName = &""
## Costumes: hide the procedural armour pieces while worn.
@export var hides_gear: bool = false

@export_group("Use")
@export var heal_amount: int = 0
@export var mana_amount: int = 0
@export var identifies_items: bool = false
@export var opens_mystery_box: bool = false

@export_group("Secrets")
## Shown until identified; the real name/description/bonuses apply after.
@export var unidentified: bool = false
@export var unidentified_name: String = "???"
@export_multiline var unidentified_description: String = ""
## If identified through the Codex scroll instead of an honest appraiser, show this name.
@export var codex_identified_name: String = ""
@export var cursed: bool = false
## Fraction of max HP lost every `curse_interval_s` while out of combat.
@export var curse_hp_fraction: float = 0.0
@export var curse_interval_s: float = 5.0
## Evolving: after `evolve_kills` kills with it equipped it becomes `evolves_into`.
@export var evolve_kills: int = 0
@export var evolves_into: StringName = &""
## Hidden effect id (described nowhere until revealed by a secret).
@export var hidden_effect: StringName = &""


func is_stackable() -> bool:
	return max_stack > 1


func is_equipment() -> bool:
	return slot != Slot.NONE


func is_usable() -> bool:
	return kind in [Kind.CONSUMABLE, Kind.FOOD] or identifies_items or opens_mystery_box


func attack_at(level: int) -> float:
	return attack + attack_per_level * level
