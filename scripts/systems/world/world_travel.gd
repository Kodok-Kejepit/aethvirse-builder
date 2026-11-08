class_name WorldTravel
extends RefCounted
## Fast travel between waystones (same region: teleport; other region: load its scene).

const ARRIVE_OFFSET: Vector3 = Vector3(0.0, 0.3, 2.5)


static func flag_for(waystone_id: StringName) -> StringName:
	return StringName("waystone_" + String(waystone_id))


static func is_unlocked(waystone_id: StringName) -> bool:
	return GameState.has_flag(flag_for(waystone_id))


static func unlock(waystone_id: StringName) -> bool:
	if is_unlocked(waystone_id):
		return false
	GameState.set_flag(flag_for(waystone_id))
	return true


## Makes this waystone the respawn point. True when it changed.
static func set_respawn(waystone_id: StringName) -> bool:
	if GameState.respawn_waystone == waystone_id:
		return false
	GameState.respawn_waystone = waystone_id
	return true


## After falling in battle: back to the last altar the player stood at. Inside a Gate
## this fails the Gate (you are carried out). False when no altar was ever visited.
static func respawn_at_altar(tree: SceneTree) -> bool:
	var region: RegionData = RegionData.region_of_waystone(GameState.respawn_waystone)
	if region == null:
		return false
	var target: Vector3 = region.waystones[GameState.respawn_waystone] + ARRIVE_OFFSET
	if GameState.gate_session != null or GameState.interior_return != null:
		# Inside a Gate or an interior (metro station): carried back out to the altar.
		GameState.gate_session = null
		GameState.interior_return = null
		GameState.pending_player_position = target
		GameState.current_region = region.id
		LoadingScreen.go(tree, region.scene_path)
		return true
	return go(tree, region, target)


## All unlocked waystones as [[region, waystone_id], ...] in region order.
static func unlocked_list() -> Array[Array]:
	var out: Array[Array] = []
	for rid: StringName in RegionData.IDS:
		var region: RegionData = RegionData.load_region(rid)
		if region == null:
			continue
		for wid: StringName in region.waystones:
			if is_unlocked(wid):
				out.append([region, wid])
	return out


static func travel(tree: SceneTree, waystone_id: StringName) -> bool:
	var region: RegionData = RegionData.region_of_waystone(waystone_id)
	if region == null or GameState.gate_session != null:
		return false
	var target: Vector3 = region.waystones[waystone_id] + ARRIVE_OFFSET
	return go(tree, region, target)


## Moves the player to `target` in `region`, loading the region scene if needed.
static func go(tree: SceneTree, region: RegionData, target: Vector3) -> bool:
	var player: Player = GameState.player as Player
	if GameState.current_region == region.id and player != null:
		player.global_position = target
		player.velocity = Vector3.ZERO
		player.last_safe_position = target
		WorldStreamer.load_around_now(target)
		return true
	GameState.pending_player_position = target
	GameState.current_region = region.id
	SaveManager.autosave()
	tree.paused = false
	LoadingScreen.go(tree, region.scene_path)
	return true
