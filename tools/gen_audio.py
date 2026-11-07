#!/usr/bin/env python3
"""Big Phase 1 placeholder audio, rendered offline (numpy) — original, procedural.

Run from the project root:  python3 tools/gen_audio.py
Writes assets/audio/bgm/<id>.ogg (seamless loops) and assets/audio/sfx/<id>.wav.
Real composed audio replaces these in Big Phase 2; the ids stay the same.
"""
import os
import subprocess
import tempfile

import numpy as np
from scipy.io import wavfile

SR = 44100
rng = np.random.default_rng(1234)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def env_adsr(n, a=0.01, d=0.1, s=0.7, r=0.2):
    t = np.arange(n) / SR
    total = n / SR
    e = np.ones(n) * s
    e[t < a] = t[t < a] / a
    m = (t >= a) & (t < a + d)
    e[m] = 1 - (1 - s) * (t[m] - a) / d
    rel = t > total - r
    e[rel] *= np.clip((total - t[rel]) / r, 0, 1)
    return e


def osc(freq, n, kind="sine", detune=0.0):
    t = np.arange(n) / SR
    f = freq * (1 + detune)
    ph = 2 * np.pi * f * t
    if kind == "sine":
        return np.sin(ph)
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if kind == "saw":
        return 2 * ((f * t) % 1.0) - 1
    if kind == "square":
        return np.sign(np.sin(ph))
    raise ValueError(kind)


def lowpass(x, cutoff):
    # one-pole low-pass
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def lowpass_fast(x, cutoff):
    # FFT brick-ish low-pass (fast for long buffers)
    X = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / (1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def pad(chord, n, kind="saw", cutoff=1200, vol=0.12):
    out = np.zeros(n)
    for note in chord:
        for d in (-0.004, 0.0, 0.005):
            out += osc(midi(note), n, kind, d)
    out = lowpass_fast(out, cutoff)
    return out * env_adsr(n, 0.8, 0.5, 0.85, 0.8) * vol / len(chord)


def pluck(note, n, vol=0.25, decay=3.0, kind="tri"):
    t = np.arange(n) / SR
    return osc(midi(note), n, kind) * np.exp(-t * decay) * np.minimum(t / 0.004, 1) * vol


def bell(note, n, vol=0.18):
    t = np.arange(n) / SR
    f = midi(note)
    y = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.76 * t) + 0.25 * np.sin(2 * np.pi * f * 5.4 * t)
    return y * np.exp(-t * 2.2) * vol


def noise(n):
    return rng.uniform(-1, 1, n)


def kick(n, vol=0.6):
    t = np.arange(n) / SR
    f = 120 * np.exp(-t * 18) + 45
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * vol


def snare(n, vol=0.3):
    t = np.arange(n) / SR
    return (noise(n) * 0.8 + np.sin(2 * np.pi * 190 * t) * 0.3) * np.exp(-t * 22) * vol


def hat(n, vol=0.1):
    t = np.arange(n) / SR
    return lowpass_fast(noise(n), 9000) * 0 + (noise(n) - lowpass_fast(noise(n), 5000)) * np.exp(-t * 60) * vol


def place(buf, sig, at_s):
    i = int(at_s * SR)
    j = min(len(buf), i + len(sig))
    if i < len(buf):
        buf[i:j] += sig[: j - i]


def reverb(x, mix=0.25):
    out = x.copy()
    for delay, g in ((0.031, 0.5), (0.047, 0.4), (0.071, 0.33), (0.113, 0.25), (0.163, 0.18)):
        d = int(delay * SR)
        y = np.zeros_like(x)
        y[d:] = x[:-d] * g
        out += y * mix * 2
    return out


def loopify(x, tail_s=2.0):
    """Wrap the reverb/release tail back onto the start so the loop is seamless."""
    n = len(x) - int(tail_s * SR)
    head = x[:n].copy()
    head[: len(x) - n] += x[n:]
    return head


# --- music -------------------------------------------------------------------------------

def song(bpm, bars, progression, scale_notes, pad_kind="saw", cutoff=1400, arp=True, arp_kind="tri",
         bells=False, drums=None, drone=None, melody_density=0.35, melody_kind="sine", seed=0):
    r = np.random.default_rng(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    total = bar * bars + 2.0
    n = int(total * SR)
    buf = np.zeros(n)
    for b in range(bars):
        chord = progression[b % len(progression)]
        place(buf, pad(chord, int(bar * SR) + int(0.8 * SR), pad_kind, cutoff), b * bar)
        if drone is not None:
            place(buf, osc(midi(drone), int(bar * SR), "sine") * 0.08, b * bar)
        if arp:
            for i in range(8):
                note = chord[i % len(chord)] + (12 if i >= 4 else 0)
                place(buf, pluck(note, int(beat * SR), 0.09, 5.0, arp_kind), b * bar + i * beat / 2)
        for i in range(8):
            if r.random() < melody_density:
                note = scale_notes[r.integers(0, len(scale_notes))] + 12
                dur = beat * (1 if r.random() < 0.7 else 2)
                sig = osc(midi(note), int(dur * SR), melody_kind) * env_adsr(int(dur * SR), 0.02, 0.1, 0.6, dur * 0.5) * 0.08
                place(buf, sig, b * bar + i * beat / 2)
        if bells and b % 2 == 0:
            place(buf, bell(chord[-1] + 24, int(2.5 * SR)), b * bar + beat * 2)
        if drums == "pulse":
            for i in range(4):
                place(buf, kick(int(0.4 * SR), 0.35), b * bar + i * beat)
        elif drums == "battle":
            for i in range(8):
                if i % 2 == 0:
                    place(buf, kick(int(0.4 * SR), 0.55), b * bar + i * beat / 2)
                if i in (2, 6):
                    place(buf, snare(int(0.3 * SR), 0.28), b * bar + i * beat / 2)
                place(buf, hat(int(0.08 * SR), 0.05), b * bar + i * beat / 2 + beat / 4)
            for i in range(8):
                place(buf, pluck(chord[0] - 12, int(beat * 0.5 * SR), 0.22, 7.0, "saw"), b * bar + i * beat / 2)
    buf = reverb(buf, 0.2)
    buf = loopify(buf, 2.0)
    return buf / (np.max(np.abs(buf)) + 1e-9) * 0.7


def chords(root, kind_list):
    out = []
    for offset, quality in kind_list:
        r = root + offset
        third = 3 if quality == "m" else 4
        out.append([r, r + third, r + 7])
    return out


MUSIC = {
    "menu": lambda: song(70, 8, chords(50, [(0, "m"), (-4, "M"), (-2, "M"), (-5, "m")]), [62, 64, 65, 67, 69, 72], bells=True,
                         cutoff=900, arp=False, melody_density=0.2, seed=1),
    "r1_ashfall": lambda: song(78, 8, chords(57, [(0, "m"), (-4, "M"), (-7, "M"), (-2, "M")]), [69, 71, 72, 74, 76, 79], seed=2),
    "r2_verdant": lambda: song(84, 8, chords(52, [(0, "m"), (2, "M"), (0, "m"), (-2, "M")]), [64, 66, 67, 69, 71, 73, 74],
                               pad_kind="tri", cutoff=2000, melody_kind="sine", melody_density=0.45, seed=3),
    "r3_dunes": lambda: song(92, 8, chords(50, [(0, "M"), (1, "M"), (0, "M"), (-2, "m")]), [62, 63, 66, 67, 69, 70, 72],
                             drone=38, arp_kind="saw", cutoff=1600, seed=4),
    "r4_frostveil": lambda: song(66, 8, chords(54, [(0, "m"), (-2, "M"), (-5, "M"), (-7, "M")]), [66, 68, 69, 71, 73, 74, 76],
                                 bells=True, pad_kind="tri", cutoff=2600, seed=5),
    "r5_archive": lambda: song(60, 8, chords(48, [(0, "M"), (2, "M"), (4, "m"), (2, "M")]), [60, 62, 64, 66, 67, 69, 71],
                               cutoff=800, arp=True, melody_density=0.25, seed=6),
    "r6_fracture": lambda: song(74, 8, [[50, 54, 58], [52, 56, 60], [48, 52, 56], [54, 58, 62]], [60, 62, 64, 66, 68, 70],
                                pad_kind="saw", cutoff=1100, bells=True, drums="pulse", seed=7),
    "r7_hollow_throne": lambda: song(56, 8, [[45, 48, 51], [44, 47, 50], [45, 48, 51], [41, 44, 47]], [57, 58, 60, 61, 63],
                                     pad_kind="saw", cutoff=700, arp=False, drone=33, melody_density=0.15, seed=8),
    "gate": lambda: song(100, 8, chords(45, [(0, "m"), (1, "M"), (0, "m"), (-2, "M")]), [57, 58, 60, 62, 63, 65],
                         drums="pulse", cutoff=1300, seed=9),
    "boss": lambda: song(140, 8, chords(45, [(0, "m"), (-4, "M"), (-2, "M"), (-5, "m")]), [57, 59, 60, 62, 64, 65, 67],
                         drums="battle", cutoff=2400, melody_density=0.5, melody_kind="square", seed=10),
}


# --- sfx ---------------------------------------------------------------------------------

def sfx_swing():
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    x = noise(n)
    sweep = np.cumsum(800 + 3000 * (t / t[-1])) / SR
    x = x * (0.5 + 0.5 * np.sin(2 * np.pi * sweep))
    return lowpass_fast(x, 3500) * np.sin(np.pi * t / t[-1]) * 0.5


def sfx_hit(heavy=False):
    n = int((0.25 if heavy else 0.15) * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * np.cumsum(180 * np.exp(-t * 20) + 60) / SR) * np.exp(-t * (14 if heavy else 24))
    crack = lowpass_fast(noise(n), 4000) * np.exp(-t * 45)
    return (body * (0.8 if heavy else 0.6) + crack * 0.5)


def sfx_crit():
    base = sfx_hit(True)
    t = np.arange(len(base)) / SR
    return base * 0.8 + np.sin(2 * np.pi * 1760 * t) * np.exp(-t * 12) * 0.25


def sfx_hurt():
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * np.cumsum(260 - 200 * t / t[-1]) / SR) * 0.4 + lowpass_fast(noise(n), 1500) * 0.4) * np.exp(-t * 10)


def sfx_dodge():
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    return lowpass_fast(noise(n), 1800) * np.sin(np.pi * t / t[-1]) ** 2 * 0.6


def sfx_death():
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * np.cumsum(220 * np.exp(-t * 3)) / SR) * 0.4 + lowpass_fast(noise(n), 900) * 0.4) * np.exp(-t * 5)


def sfx_pickup():
    n = int(0.35 * SR)
    out = np.zeros(n)
    for i, note in enumerate((84, 88, 91)):
        place(out, pluck(note, int(0.25 * SR), 0.3, 12.0, "sine"), i * 0.05)
    return out


def sfx_skill():
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    sweep = np.sin(2 * np.pi * np.cumsum(300 + 1500 * t / t[-1]) / SR)
    return (sweep * 0.3 + bell(84, n, 0.25)) * np.minimum(t / 0.02, 1) * np.exp(-t * 3)


def sfx_dragon():
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    growl = osc(70, n, "saw") * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t))
    roar = lowpass_fast(growl + noise(n) * 0.6, 900)
    shimmer = sum(bell(n_, n, 0.08) for n_ in (88, 91, 95))
    return (roar * np.sin(np.pi * np.minimum(t / 1.1, 1)) * 0.6 + shimmer)


def sfx_gate():
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    whoom = np.sin(2 * np.pi * np.cumsum(60 + 200 * (1 - t / t[-1])) / SR)
    return (whoom * 0.5 + lowpass_fast(noise(n), 600) * 0.4) * np.sin(np.pi * t / t[-1])


def sfx_fanfare():
    n = int(1.6 * SR)
    out = np.zeros(n)
    for i, note in enumerate((72, 76, 79, 84)):
        place(out, pluck(note, int(0.9 * SR), 0.3, 2.5, "saw") * 0.6 + pluck(note, int(0.9 * SR), 0.2, 2.5, "sine"), i * 0.12)
    return lowpass_fast(out, 4000)


SFX = {
    "swing": sfx_swing, "hit": sfx_hit, "hit_heavy": lambda: sfx_hit(True), "crit": sfx_crit, "hurt": sfx_hurt,
    "dodge": sfx_dodge, "enemy_death": sfx_death, "pickup": sfx_pickup, "skill": sfx_skill, "dragon": sfx_dragon,
    "gate_enter": sfx_gate, "fanfare": sfx_fanfare,
}


def write_wav(path, x):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.85
    wavfile.write(path, SR, (x * 32767).astype(np.int16))


def main():
    os.makedirs("assets/audio/bgm", exist_ok=True)
    os.makedirs("assets/audio/sfx", exist_ok=True)
    for sid, fn in SFX.items():
        write_wav(f"assets/audio/sfx/{sid}.wav", fn())
    for mid, fn in MUSIC.items():
        x = fn()
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            write_wav(tmp.name, x)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "3",
                            f"assets/audio/bgm/{mid}.ogg"], check=True)
        os.unlink(tmp.name)
        with open(f"assets/audio/bgm/{mid}.ogg.import", "w") as f:
            f.write(f'''[remap]

importer="oggvorbisstr"
type="AudioStreamOggVorbis"

[deps]

source_file="res://assets/audio/bgm/{mid}.ogg"

[params]

loop=true
loop_offset=0.0
''')
        print("music", mid)
    print("audio written")


if __name__ == "__main__":
    main()
