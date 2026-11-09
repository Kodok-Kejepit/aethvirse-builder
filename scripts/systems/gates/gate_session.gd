class_name GateSession
extends RefCounted
## Transient state while inside a Gate (not saved: leaving/loading ends the run).

var gate: GateData
var return_scene: String = ""
var return_position: Vector3 = Vector3.ZERO
var cleared: bool = false
## Extra enemy levels on top of GateLayout.enemy_level (Double Gates are harder).
var enemy_level_bonus: int = 0
## Test hook / cheat: force the hidden Double Gate to appear in this run.
var force_double: bool = false
## Cheat: force today's kind of place / map shape (DungeonArchetype / DungeonPlan.LAYOUTS).
var force_kind: StringName = &""
var force_layout: StringName = &""
## Dynamic world Gate this run came from (-1 = a fixed portal); cleared runs close it.
var world_gate_uid: int = -1
## Job Change trial: the job granted when this Gate's boss falls.
var trial_job: StringName = &""


func has_rule(rule: StringName) -> bool:
	return gate != null and gate.has_rule(rule)
