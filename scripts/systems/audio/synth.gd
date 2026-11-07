class_name Synth
extends RefCounted
## Tiny procedural sound generator for placeholder UI/SFX sounds (Big Phase 1).
## Real audio assets replace these in Big Phase 2; ids stay the same.

const MIX_RATE: int = 44100


## Each note: [frequency_hz, start_s, duration_s, volume 0..1]. Sine with fast attack and exp decay.
static func notes(note_list: Array[Vector4], total_s: float) -> AudioStreamWAV:
	var frames: int = int(total_s * MIX_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	for i: int in frames:
		var t: float = float(i) / MIX_RATE
		var sample: float = 0.0
		for n: Vector4 in note_list:
			var local: float = t - n.y
			if local < 0.0 or local > n.z:
				continue
			var envelope: float = minf(local / 0.005, 1.0) * exp(-local * 6.0 / n.z)
			sample += sin(TAU * n.x * local) * envelope * n.w
			sample += sin(TAU * n.x * 2.0 * local) * envelope * n.w * 0.25
		data.encode_s16(i * 2, clampi(int(sample * 32767.0 * 0.6), -32768, 32767))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


## Library of placeholder sounds by id.
static func make(id: StringName) -> AudioStreamWAV:
	match id:
		&"ding":
			return notes([Vector4(1318.5, 0.0, 0.6, 0.6), Vector4(1975.5, 0.06, 0.7, 0.45)], 0.8)
		&"level_up":
			return notes([Vector4(784.0, 0.0, 0.3, 0.5), Vector4(1046.5, 0.1, 0.3, 0.5),
				Vector4(1318.5, 0.2, 0.3, 0.5), Vector4(1568.0, 0.3, 0.6, 0.55)], 1.0)
		&"anomaly":
			return notes([Vector4(311.1, 0.0, 0.5, 0.5), Vector4(329.6, 0.02, 0.5, 0.5),
				Vector4(155.6, 0.1, 0.6, 0.4)], 0.8)
		&"error":
			return notes([Vector4(220.0, 0.0, 0.2, 0.5), Vector4(185.0, 0.12, 0.25, 0.5)], 0.45)
		&"hit":
			return notes([Vector4(180.0, 0.0, 0.08, 0.7), Vector4(90.0, 0.0, 0.12, 0.6)], 0.15)
		_:
			return notes([Vector4(880.0, 0.0, 0.2, 0.5)], 0.25)
