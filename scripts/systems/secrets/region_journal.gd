class_name RegionJournal
extends RefCounted
## One region's page of the Mystery Journal (owner's design): every hidden place, odd item,
## chest, puzzle and sealed mission of the region is an entry. The page is complete when
## every entry is resolved; then the Codex updates itself and carries the Vanguard on to
## the next region (JournalCompletion). The UI never says what completing it means.

## Entry kinds in display order.
const KINDS: Array[SecretData.Kind] = [
	SecretData.Kind.SEALED_MISSION, SecretData.Kind.LOCATION, SecretData.Kind.SECRET_ITEM,
	SecretData.Kind.CHEST, SecretData.Kind.PUZZLE,
]
const KIND_KEYS: Dictionary[SecretData.Kind, StringName] = {
	SecretData.Kind.SEALED_MISSION: &"JOURNAL_KIND_MISSION",
	SecretData.Kind.LOCATION: &"JOURNAL_KIND_PLACE",
	SecretData.Kind.SECRET_ITEM: &"JOURNAL_KIND_ITEM",
	SecretData.Kind.CHEST: &"JOURNAL_KIND_CHEST",
	SecretData.Kind.PUZZLE: &"JOURNAL_KIND_PUZZLE",
}


## Entries of a region: one per secret, or one per sealed mission (its stages together).
## Each: {"id", "kind", "secrets": Array[SecretData]} in data order.
static func entries(db: SecretDatabase, region_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var by_id: Dictionary[StringName, Dictionary] = {}
	var ids: Array[StringName] = db.secrets.keys()
	ids.sort()
	for id: StringName in ids:
		var secret: SecretData = db.secrets[id]
		if secret.region != region_id or not _tracked(secret):
			continue
		var key: StringName = secret.mission if secret.mission != &"" else secret.id
		if not by_id.has(key):
			var stages: Array[SecretData] = []
			var entry: Dictionary = {"id": key, "kind": secret.kind, "secrets": stages}
			by_id[key] = entry
			out.append(entry)
		var list: Array[SecretData] = by_id[key]["secrets"]
		list.append(secret)
	return out


static func _tracked(secret: SecretData) -> bool:
	return secret.counts_as_secret() or (secret.kind == SecretData.Kind.SEALED_MISSION and not secret.hidden_from_tracker)


## An entry is resolved when every one of its secrets (all mission stages) is found, or
## closed for good when a stage failed (a permanent choice must never block the journal).
static func is_resolved(entry: Dictionary, found: Dictionary[StringName, bool], failed: Dictionary[StringName, bool] = {}) -> bool:
	var list: Array[SecretData] = entry["secrets"]
	for secret: SecretData in list:
		if failed.get(secret.id, false):
			return true
	for secret: SecretData in list:
		if not found.get(secret.id, false):
			return false
	return true


static func is_lost(entry: Dictionary, failed: Dictionary[StringName, bool]) -> bool:
	var list: Array[SecretData] = entry["secrets"]
	for secret: SecretData in list:
		if failed.get(secret.id, false):
			return true
	return false


## x = resolved entries, y = all entries.
static func progress(db: SecretDatabase, region_id: StringName, state: SecretState) -> Vector2i:
	var list: Array[Dictionary] = entries(db, region_id)
	var done: int = 0
	for entry: Dictionary in list:
		if is_resolved(entry, state.found, state.failed):
			done += 1
	return Vector2i(done, list.size())


static func is_complete(db: SecretDatabase, region_id: StringName, state: SecretState) -> bool:
	var p: Vector2i = progress(db, region_id, state)
	return p.y > 0 and p.x == p.y


static func flag_for(region_id: StringName) -> StringName:
	return StringName("journal_done_" + String(region_id))


static func index_of(region_id: StringName) -> int:
	return RegionData.IDS.find(region_id)


static func next_region(region_id: StringName) -> StringName:
	var i: int = index_of(region_id)
	return RegionData.IDS[i + 1] if i >= 0 and i + 1 < RegionData.IDS.size() else &""


static func previous_region(region_id: StringName) -> StringName:
	var i: int = index_of(region_id)
	return RegionData.IDS[i - 1] if i > 0 else &""


## Where a region is entered: its first waystone.
static func entry_waystone(region_id: StringName) -> StringName:
	var region: RegionData = RegionData.load_region(region_id)
	if region == null or region.waystones.is_empty():
		return &""
	var first: StringName = region.waystones.keys()[0]
	return first


## Roads lead forward only once the page before is complete (or the region was reached
## before this rule existed: its entry waystone is already unlocked).
static func road_open(target_region: StringName) -> bool:
	var before: StringName = previous_region(target_region)
	if before == &"" or GameState.has_flag(flag_for(before)):
		return true
	return WorldTravel.is_unlocked(entry_waystone(target_region))


## The page the journal opens on: the first region whose page is not complete.
static func current_page() -> StringName:
	for id: StringName in RegionData.IDS:
		if not GameState.has_flag(flag_for(id)):
			return id
	return RegionData.IDS[RegionData.IDS.size() - 1]
