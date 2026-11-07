class_name ClassData
extends Resource
## A playable class: stats (Balancing sheet "Kelas"), weapon combo graph, skills and skill combos.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var magic_damage: bool = false
@export var base_stats: StatBlock
## Automatic growth per level.
@export var growth: StatBlock
## Recommended split of free points (sums to 1). Used by auto-allocate and tests/balancing.
@export var recommended_split: StatBlock
@export var combo: ComboData
## Skills in unlock order. Slots 1–4 + ultimate are chosen from these.
@export var skills: Array[SkillData] = []
@export var skill_combos: Array[SkillComboData] = []


func find_skill(skill_id: StringName) -> SkillData:
	for skill: SkillData in skills:
		if skill.id == skill_id:
			return skill
	return null
