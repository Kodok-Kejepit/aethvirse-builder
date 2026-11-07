class_name JobData
extends Resource
## A job (§8): Job Change I (tier 1, Lv 30), Job Change II (tier 2, Lv 60, from `parent`),
## and hidden jobs (only offered once `required_flag` is set by a sealed mission).

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Class this job belongs to; &"" = any class may take it.
@export var base_class: StringName = &""
@export var tier: int = 1
@export var required_level: int = 30
## Job you must have before this one (tier 2 / hidden evolutions).
@export var parent: StringName = &""
@export var hidden: bool = false
## World flag that must be set before the job is offered (hidden jobs).
@export var required_flag: StringName = &""
## Flat stats added on top of the class (permanent).
@export var stat_bonus: StatBlock
@export var attack_bonus: float = 0.0
@export var defense_bonus: float = 0.0
@export var hp_bonus: float = 0.0
## Mana-hungry jobs pay more for every skill (Summoner).
@export var mp_cost_multiplier: float = 1.0
@export var skills: Array[SkillData] = []
## Shows the Codex → Shadow Army tab and keeps the shadow roster.
@export var shadow_army: bool = false
