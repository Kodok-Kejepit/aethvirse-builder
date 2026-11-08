"""Draws an icon for every skill (data/skills/**.tres) into assets/ui/skills/<id>.png.

    ~/.cache/ascendant-venv/bin/python tools/make_skill_icons.py

A gem plate in the skill's colour (light from the top, dark rim), a glowing symbol chosen
from the skill's id / kind (slash, dash, quake, fire, frost, bolt, wind, shield, roar,
arrow, rain, comet, eye, trap, spirit, shadow, rune, fist, wing, mirror, hourglass,
cross, drop), a thin silver frame — gold with rays for ultimates, a hexagon for passives.
Drawn at 512 px and scaled down for smooth edges.
"""
import glob
import math
import os
import re

from PIL import Image, ImageDraw, ImageFilter

BIG = 512
OUT = 128
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "assets", "ui", "skills")

# Kind enum (scripts/resources/skill_data.gd).
MELEE, DASH, AOE, BUFF, PROJECTILE, PASSIVE, SUMMON, SHADOW_EXTRACT, SHADOW_CALL = range(9)

KEYWORDS = [
    ("thousand_cuts", "cross"), ("final_hour", "hourglass"), ("hall_of_mirrors", "mirror"), ("mirage", "mirror"),
    ("arrow_rain", "rain"), ("starfall", "rain"), ("meteor", "comet"), ("cataclysm", "comet"),
    ("heartseeker", "arrow"), ("multishot", "arrow"), ("power_shot", "arrow"), ("piercing", "arrow"),
    ("fire", "fire"), ("flame", "fire"), ("frost", "frost"), ("glacial", "frost"), ("chill", "frost"),
    ("thunder", "bolt"), ("tempest", "wind"), ("slipstream", "wind"), ("flow", "wind"),
    ("shield", "shield"), ("aegis", "shield"), ("bulwark", "shield"), ("iron_body", "shield"), ("ward", "shield"),
    ("earth", "quake"), ("spike", "quake"), ("rampage", "quake"), ("titan", "quake"),
    ("eye", "eye"), ("foresight", "eye"), ("focus", "eye"), ("aim", "eye"),
    ("trap", "trap"), ("snare", "trap"), ("hunters_ground", "trap"),
    ("familiar", "spirit"), ("pack", "spirit"), ("tether", "spirit"),
    ("echo", "shadow"), ("answer", "shadow"), ("sovereign", "shadow"), ("dead", "shadow"),
    ("mind", "rune"), ("arcane", "rune"), ("well", "rune"),
    ("hands", "fist"), ("fleet", "wing"), ("swift", "wing"), ("evasive", "wing"),
    ("blood", "drop"), ("charge", "dash"), ("step", "dash"), ("cut", "slash"), ("slash", "slash"),
    ("edge", "slash"), ("cry", "roar"), ("rhythm", "roar"), ("intent", "roar"), ("surge", "roar"),
]
BY_KIND = {MELEE: "slash", DASH: "dash", AOE: "quake", BUFF: "roar", PROJECTILE: "arrow", PASSIVE: "rune",
           SUMMON: "spirit", SHADOW_EXTRACT: "shadow", SHADOW_CALL: "shadow"}


def read_skill(path):
    text = open(path, encoding="utf-8").read()
    def field(name, default=""):
        m = re.search(r"^%s = (.+)$" % name, text, re.M)
        return m.group(1).strip() if m else default
    sid = field("id", '&"x"').split('"')[1]
    color = field("icon_color", "Color(0.4, 0.7, 1, 1)")
    rgb = [float(v) for v in re.findall(r"[\d.]+", color)[:3]]
    return {"id": sid, "kind": int(field("kind", "0")), "ultimate": field("is_ultimate", "false") == "true", "color": rgb}


def symbol_for(skill):
    for key, sym in KEYWORDS:
        if key in skill["id"]:
            return sym
    return BY_KIND.get(skill["kind"], "slash")


def P(x, y):
    return (x * BIG, y * BIG)


def poly(d, pts, fill):
    d.polygon([P(x, y) for x, y in pts], fill=fill)


def line(d, pts, fill, w):
    d.line([P(x, y) for x, y in pts], fill=fill, width=int(w * BIG), joint="curve")


def arc_band(d, cx, cy, r0, r1, a0, a1, fill, steps=40):
    outer = [(cx + math.cos(math.radians(a0 + (a1 - a0) * i / steps)) * r1, cy + math.sin(math.radians(a0 + (a1 - a0) * i / steps)) * r1) for i in range(steps + 1)]
    inner = [(cx + math.cos(math.radians(a1 - (a1 - a0) * i / steps)) * r0, cy + math.sin(math.radians(a1 - (a1 - a0) * i / steps)) * r0) for i in range(steps + 1)]
    poly(d, outer + inner, fill)


def crescent(d, cx, cy, r, a0, a1, thick, fill):
    """A slash: a band thick in the middle and pointed at both ends."""
    steps = 40
    pts_out, pts_in = [], []
    for i in range(steps + 1):
        t = i / steps
        a = math.radians(a0 + (a1 - a0) * t)
        w = thick * math.sin(math.pi * t)
        pts_out.append((cx + math.cos(a) * (r + w), cy + math.sin(a) * (r + w)))
        pts_in.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    poly(d, pts_out + pts_in[::-1], fill)


def draw_symbol(d, sym, c):
    if sym == "slash":
        crescent(d, 0.62, 0.62, 0.36, 190, 290, 0.09, c)
        line(d, [(0.3, 0.7), (0.72, 0.28)], c, 0.022)
    elif sym == "cross":
        crescent(d, 0.6, 0.62, 0.34, 190, 290, 0.07, c)
        crescent(d, 0.4, 0.62, 0.34, 250, 350, 0.07, c)
    elif sym == "dash":
        for k, off in enumerate((0.0, 0.16, 0.32)):
            a = 1.0 - k * 0.25
            col = c[:3] + (int(255 * a),)
            poly(d, [(0.22 + off, 0.3), (0.36 + off, 0.5), (0.22 + off, 0.7), (0.3 + off, 0.7), (0.44 + off, 0.5), (0.3 + off, 0.3)], col)
    elif sym == "quake":
        poly(d, [(0.18, 0.72), (0.82, 0.72), (0.74, 0.8), (0.26, 0.8)], c)
        line(d, [(0.5, 0.7), (0.44, 0.55), (0.53, 0.45), (0.46, 0.3), (0.5, 0.2)], c, 0.03)
        for x, h in ((0.3, 0.16), (0.68, 0.2)):
            poly(d, [(x - 0.06, 0.72), (x, 0.72 - h), (x + 0.06, 0.72)], c)
    elif sym == "fire":
        poly(d, [(0.5, 0.18), (0.66, 0.42), (0.7, 0.6), (0.62, 0.76), (0.5, 0.82), (0.38, 0.76), (0.3, 0.6), (0.36, 0.44), (0.44, 0.5), (0.46, 0.34)], c)
        poly(d, [(0.5, 0.48), (0.58, 0.62), (0.55, 0.74), (0.5, 0.77), (0.45, 0.74), (0.42, 0.62)], (255, 255, 255, 200))
    elif sym == "comet":
        d.ellipse([P(0.52, 0.52), P(0.76, 0.76)], fill=c)
        for k in range(3):
            line(d, [(0.56 - k * 0.06, 0.54 + k * 0.05), (0.2 - k * 0.04, 0.2 + k * 0.08)], c[:3] + (200 - k * 50,), 0.035 - k * 0.008)
    elif sym == "frost":
        for k in range(3):
            a = math.radians(90 + k * 60)
            dx, dy = math.cos(a) * 0.3, math.sin(a) * 0.3
            line(d, [(0.5 - dx, 0.5 - dy), (0.5 + dx, 0.5 + dy)], c, 0.04)
            for s in (-1, 1):
                ex, ey = 0.5 + s * dx * 0.7, 0.5 + s * dy * 0.7
                for t in (-1, 1):
                    b = a + t * math.radians(40)
                    line(d, [(ex, ey), (ex - s * math.cos(b) * 0.1, ey - s * math.sin(b) * 0.1)], c, 0.03)
    elif sym == "bolt":
        poly(d, [(0.56, 0.16), (0.32, 0.54), (0.48, 0.54), (0.42, 0.84), (0.7, 0.42), (0.53, 0.42), (0.62, 0.16)], c)
    elif sym == "wind":
        for k, (r, y) in enumerate(((0.22, 0.38), (0.28, 0.52), (0.18, 0.66))):
            arc_band(d, 0.5, y, r - 0.035, r, 200, 340, c)
    elif sym == "shield":
        poly(d, [(0.5, 0.18), (0.76, 0.28), (0.72, 0.56), (0.5, 0.82), (0.28, 0.56), (0.24, 0.28)], c)
        poly(d, [(0.5, 0.28), (0.66, 0.34), (0.63, 0.54), (0.5, 0.7), (0.37, 0.54), (0.34, 0.34)], (0, 0, 0, 90))
    elif sym == "roar":
        d.ellipse([P(0.4, 0.4), P(0.6, 0.6)], fill=c)
        for r in (0.2, 0.28, 0.36):
            arc_band(d, 0.5, 0.5, r - 0.025, r, 200, 340, c)
            arc_band(d, 0.5, 0.5, r - 0.025, r, 20, 160, c)
    elif sym == "arrow":
        line(d, [(0.24, 0.76), (0.7, 0.3)], c, 0.04)
        poly(d, [(0.78, 0.22), (0.58, 0.28), (0.72, 0.42)], c)
        for k in (0, 1):
            o = k * 0.06
            poly(d, [(0.22 + o, 0.78 - o), (0.2 + o, 0.66 - o), (0.28 + o, 0.72 - o)], c)
    elif sym == "rain":
        for x, y in ((0.3, 0.26), (0.5, 0.18), (0.7, 0.3), (0.4, 0.46), (0.62, 0.52)):
            line(d, [(x, y), (x - 0.04, y + 0.26)], c, 0.025)
            poly(d, [(x - 0.07, y + 0.24), (x - 0.04, y + 0.34), (x + 0.0, y + 0.25)], c)
    elif sym == "eye":
        poly(d, [(0.16, 0.5), (0.34, 0.34), (0.5, 0.3), (0.66, 0.34), (0.84, 0.5), (0.66, 0.66), (0.5, 0.7), (0.34, 0.66)], c)
        d.ellipse([P(0.39, 0.39), P(0.61, 0.61)], fill=(10, 10, 20, 230))
        d.ellipse([P(0.46, 0.46), P(0.54, 0.54)], fill=c)
    elif sym == "trap":
        poly(d, [(0.2, 0.72), (0.8, 0.72), (0.8, 0.78), (0.2, 0.78)], c)
        for k in range(5):
            x = 0.26 + k * 0.12
            poly(d, [(x - 0.05, 0.72), (x, 0.42 - (k % 2) * 0.08), (x + 0.05, 0.72)], c)
    elif sym == "spirit":
        poly(d, [(0.5, 0.2), (0.7, 0.36), (0.72, 0.62), (0.62, 0.78), (0.56, 0.68), (0.5, 0.8), (0.44, 0.68), (0.38, 0.78), (0.28, 0.62), (0.3, 0.36)], c)
        for x in (0.42, 0.58):
            d.ellipse([P(x - 0.04, 0.42), P(x + 0.04, 0.5)], fill=(10, 10, 20, 230))
    elif sym == "shadow":
        poly(d, [(0.5, 0.16), (0.74, 0.42), (0.78, 0.84), (0.22, 0.84), (0.26, 0.42)], c)
        d.ellipse([P(0.38, 0.38), P(0.62, 0.62)], fill=(8, 6, 16, 240))
        for x in (0.45, 0.55):
            d.ellipse([P(x - 0.025, 0.48), P(x + 0.025, 0.52)], fill=(255, 80, 120, 255))
    elif sym == "rune":
        d.ellipse([P(0.24, 0.24), P(0.76, 0.76)], outline=c, width=int(0.035 * BIG))
        poly(d, [(0.5, 0.3), (0.62, 0.5), (0.5, 0.7), (0.38, 0.5)], c)
        for k in range(4):
            a = math.radians(45 + k * 90)
            line(d, [(0.5 + math.cos(a) * 0.2, 0.5 + math.sin(a) * 0.2), (0.5 + math.cos(a) * 0.28, 0.5 + math.sin(a) * 0.28)], c, 0.03)
    elif sym == "fist":
        poly(d, [(0.32, 0.34), (0.68, 0.34), (0.72, 0.5), (0.66, 0.74), (0.36, 0.74), (0.28, 0.52)], c)
        for k in range(4):
            x = 0.36 + k * 0.08
            line(d, [(x, 0.36), (x, 0.48)], (10, 10, 20, 160), 0.012)
    elif sym == "wing":
        for k in range(4):
            poly(d, [(0.3, 0.7), (0.3 + 0.1 * k, 0.24 + 0.08 * k), (0.42 + 0.1 * k, 0.3 + 0.08 * k), (0.36, 0.72)], c[:3] + (255 - k * 40,))
    elif sym == "mirror":
        for x, y, s in ((0.42, 0.5, 0.2), (0.62, 0.42, 0.14), (0.6, 0.66, 0.1)):
            poly(d, [(x, y - s), (x + s * 0.6, y), (x, y + s), (x - s * 0.6, y)], c)
    elif sym == "hourglass":
        poly(d, [(0.3, 0.2), (0.7, 0.2), (0.52, 0.5), (0.7, 0.8), (0.3, 0.8), (0.48, 0.5)], c)
        poly(d, [(0.38, 0.72), (0.62, 0.72), (0.5, 0.58)], (10, 10, 20, 200))
    elif sym == "drop":
        poly(d, [(0.5, 0.18), (0.64, 0.44), (0.68, 0.6), (0.6, 0.76), (0.5, 0.8), (0.4, 0.76), (0.32, 0.6), (0.36, 0.44)], c)


def plate(skill):
    r, g, b = [int(v * 255) for v in skill["color"]]
    img = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    passive = skill["kind"] == PASSIVE
    ult = skill["ultimate"]
    if passive:
        r, g, b = [int(v * 0.75 + 40) for v in (r, g, b)]
        shape = [P(0.5 + math.cos(math.radians(30 + 60 * k)) * 0.47, 0.5 + math.sin(math.radians(30 + 60 * k)) * 0.47) for k in range(6)]
        d.polygon(shape, fill=(0, 0, 0, 255))
        mask = img.getchannel("A")
    else:
        d.rounded_rectangle([P(0.04, 0.04), P(0.96, 0.96)], radius=int(0.16 * BIG), fill=(0, 0, 0, 255))
        mask = img.getchannel("A")
    # Gem body: light from the top, deep colour below, dark rim.
    body = Image.new("RGBA", (BIG, BIG))
    bd = ImageDraw.Draw(body)
    for y in range(BIG):
        t = y / BIG
        k = 1.25 - 0.85 * t
        bd.line([(0, y), (BIG, y)], fill=(min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), 255))
    vignette = Image.new("L", (BIG, BIG), 0)
    ImageDraw.Draw(vignette).ellipse([P(0.12, 0.08), P(0.88, 0.92)], fill=255)
    vignette = vignette.filter(ImageFilter.GaussianBlur(BIG * 0.12))
    dark = Image.new("RGBA", (BIG, BIG), (8, 10, 18, 255))
    body = Image.composite(body, dark, vignette)
    if ult:
        rays = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
        rd = ImageDraw.Draw(rays)
        for k in range(12):
            a = math.radians(k * 30)
            rd.polygon([P(0.5, 0.5), P(0.5 + math.cos(a - 0.08) * 0.7, 0.5 + math.sin(a - 0.08) * 0.7), P(0.5 + math.cos(a + 0.08) * 0.7, 0.5 + math.sin(a + 0.08) * 0.7)], fill=(255, 220, 140, 60))
        body = Image.alpha_composite(body, rays.filter(ImageFilter.GaussianBlur(6)))
    # Symbol with a soft glow behind it.
    sym = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    draw_symbol(ImageDraw.Draw(sym), symbol_for(skill), (250, 246, 232, 255))
    glow = Image.new("RGBA", (BIG, BIG), (min(255, r + 90), min(255, g + 90), min(255, b + 90), 0))
    glow.putalpha(sym.getchannel("A").filter(ImageFilter.GaussianBlur(BIG * 0.03)))
    body = Image.alpha_composite(body, glow)
    body = Image.alpha_composite(body, glow)
    body = Image.alpha_composite(body, sym)
    out = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    out.paste(body, (0, 0), mask)
    # Frame: thin silver, gold (doubled) for ultimates.
    fd = ImageDraw.Draw(out)
    frame = (236, 200, 120, 255) if ult else (200, 210, 225, 220)
    width = int(BIG * (0.03 if ult else 0.018))
    if passive:
        fd.polygon(shape, outline=frame, width=width)
    else:
        fd.rounded_rectangle([P(0.05, 0.05), P(0.95, 0.95)], radius=int(0.15 * BIG), outline=frame, width=width)
        if ult:
            fd.rounded_rectangle([P(0.1, 0.1), P(0.9, 0.9)], radius=int(0.12 * BIG), outline=(236, 200, 120, 140), width=int(BIG * 0.01))
    return out.resize((OUT, OUT), Image.LANCZOS)


def main():
    os.makedirs(DEST, exist_ok=True)
    paths = sorted(glob.glob(os.path.join(ROOT, "data", "skills", "**", "*.tres"), recursive=True))
    done = 0
    for path in paths:
        skill = read_skill(path)
        plate(skill).save(os.path.join(DEST, skill["id"] + ".png"), optimize=True)
        done += 1
    print(f"{done} skill icons -> {DEST}")


if __name__ == "__main__":
    main()
