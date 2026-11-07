class_name BossRoom
extends GateRoom
## Boss arena: lets the dungeon attach BossPhases to the spawned boss.


func _on_spawned(enemy: Enemy) -> void:
	if has_meta(&"spawn_hook"):
		var hook: Callable = get_meta(&"spawn_hook")
		hook.call(enemy)
