class_name SkillIcons
extends RefCounted
## Skill icons drawn by tools/make_skill_icons.py (assets/ui/skills/<id>.png). Null when a
## skill has no icon yet (callers fall back to its initials).

const DIR: String = "res://assets/ui/skills/%s.png"

static var _cache: Dictionary[StringName, Texture2D] = {}


static func icon_for(skill: SkillData) -> Texture2D:
	if skill == null:
		return null
	if _cache.has(skill.id):
		return _cache[skill.id]
	var path: String = DIR % skill.id
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_cache[skill.id] = tex
	return tex
