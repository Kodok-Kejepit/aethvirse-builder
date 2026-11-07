class_name SkillComboData
extends Resource
## Skill chain (§6): using `second` within `window_s` after `first` triggers a bonus.

@export var id: StringName = &""
@export var display_name: String = ""
@export var first: StringName = &""
@export var second: StringName = &""
@export var window_s: float = 2.0
@export var bonus_multiplier: float = 1.0
@export var force_crit: bool = false
@export var extra_stagger: float = 0.0


func matches(previous_skill: StringName, elapsed_s: float, next_skill: StringName) -> bool:
	return previous_skill == first and next_skill == second and elapsed_s <= window_s
