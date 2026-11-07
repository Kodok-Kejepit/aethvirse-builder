class_name CodexText
extends RefCounted
## Text helpers for the Codex "System" voice: glitch/corruption for anomalies.

const GLITCH_CHARS: String = "#%&@$*?!/|=+~<>"


## Replaces a fraction of non-space characters with glitch symbols. Deterministic per seed
## so a message garbles the same way each time it is shown.
static func glitch(text: String, intensity: float, seed_value: int = 0) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else hash(text)
	var out: PackedStringArray = []
	for c: String in text.split(""):
		if c != " " and rng.randf() < clampf(intensity, 0.0, 1.0):
			out.append(GLITCH_CHARS[rng.randi() % GLITCH_CHARS.length()])
		else:
			out.append(c)
	return "".join(out)
