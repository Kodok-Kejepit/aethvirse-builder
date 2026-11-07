class_name JobRegistry
extends RefCounted
## All jobs in res://data/jobs/, and the rules for which job changes are on offer.

const DIR: String = "res://data/jobs/"


static func all() -> Array[JobData]:
	var out: Array[JobData] = []
	for file: String in DirAccess.get_files_at(DIR):
		var path: String = DIR + file.trim_suffix(".remap")
		if path.ends_with(".tres"):
			var job: JobData = load(path) as JobData
			if job != null:
				out.append(job)
	out.sort_custom(func(a: JobData, b: JobData) -> bool: return String(a.id) < String(b.id))
	return out


static func get_job(id: StringName) -> JobData:
	if id == &"":
		return null
	var path: String = DIR + String(id) + ".tres"
	return load(path) as JobData if ResourceLoader.exists(path) else null


## The job and every job before it (parent chain), oldest first.
static func lineage(id: StringName) -> Array[JobData]:
	var out: Array[JobData] = []
	var job: JobData = get_job(id)
	var guard: int = 0
	while job != null and guard < 8:
		out.push_front(job)
		job = get_job(job.parent)
		guard += 1
	return out


## Job changes the player can take right now.
static func options(class_id: StringName, current: StringName, level: int, has_flag: Callable) -> Array[JobData]:
	var out: Array[JobData] = []
	for job: JobData in all():
		if job.id == current or level < job.required_level:
			continue
		if job.base_class != &"" and job.base_class != class_id:
			continue
		if job.parent != current:
			continue
		if job.required_flag != &"" and not has_flag.call(job.required_flag):
			continue
		out.append(job)
	return out


static func has_shadow_army(id: StringName) -> bool:
	for job: JobData in lineage(id):
		if job.shadow_army:
			return true
	return false
