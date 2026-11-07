extends Node
## Global signal hub. Systems emit and listen here instead of referencing each other.
## Signals are declared up-front so every system shares one contract; most are emitted
## by systems that arrive in later milestones.

@warning_ignore_start("unused_signal")
signal enemy_killed(enemy_id: StringName, position: Vector3)
signal item_picked(item_id: StringName, amount: int)
signal quest_updated(quest_id: StringName)
signal secret_found(secret_id: StringName)
signal level_up(new_level: int)
signal codex_message(text: String, kind: StringName)
signal quality_preset_changed(preset: QualityPresets.Preset)
signal player_stamina_changed(current: float, maximum: float)
signal player_health_changed(current: int, maximum: int)
signal player_mana_changed(current: float, maximum: float)
signal player_stats_changed
signal xp_gained(amount: int)
signal gold_gained(amount: int)
signal skill_used(skill_id: StringName)
signal skill_combo_triggered(display_name: String)
signal player_died
signal autosave_requested
signal projectile_hit(target: Node, info: RefCounted, applied: bool)
signal player_attack_started
signal player_dodge_started
signal quest_completed(quest_id: StringName)
signal guild_rank_changed(rank: int)
signal npc_talked(npc_id: StringName)
signal gate_cleared(gate_id: StringName)
signal boss_started(boss: Node3D)
signal boss_ended(boss: Node3D, defeated: bool)
signal boss_health_changed(current: int, maximum: int)
signal npc_attacked(npc_id: StringName)
signal secret_area_entered(area_id: StringName)
signal secret_area_exited(area_id: StringName)
signal journal_updated
signal item_used(item_id: StringName)
signal item_crafted(item_id: StringName)
signal item_identified(item_id: StringName, method: StringName)
signal item_evolved(from_id: StringName, to_id: StringName)
## Empty text = nothing to interact with.
signal interaction_prompt_changed(text: String)
signal hour_changed(hour: int)
signal day_changed(day: int)
signal weather_changed(weather: StringName)
signal player_respawned
signal perfect_dodge
signal combo_changed(count: int, rank: int)
signal lock_target_changed(target: Node3D)
signal damage_number_requested(position: Vector3, amount: int, is_crit: bool, element: int, on_player: bool)
## Look delta from touch controls (pixels), consumed by the camera.
signal camera_look_input(relative: Vector2)
signal settings_changed
signal job_changed(job_id: StringName)
signal summon_killed_enemy(summon_id: StringName)
signal shadow_bound(enemy_id: StringName)
signal dungeon_break_started(world_gate_uid: int)
signal dungeon_break_ended(world_gate_uid: int)
@warning_ignore_restore("unused_signal")
