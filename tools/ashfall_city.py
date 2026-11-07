"""Ashfall Outskirts as a ruined, overgrown modern city district (owner's trailer look:
dusk, collapsed towers, mossy wrecks, the cracked overpass).

Everything is laid out in GLOBAL metres on one plan and each 128 m chunk draws the part
inside it, so roads, kerbs and building rows line up across chunk borders.

Plan (x east, z south; chunks span -192..192):
- Ring road around the camp plaza (x/z = ±56) and the main avenue x = 0 running south
  from the plaza to the river bridge and north towards the Region 2 road.
- West road z = 56 to the old apartments, and the north-west road to Region 2.
- The ring's east side passes under the elevated highway (overpass chunk).
- City blocks between roads get rows of ruined towers facing the street, rubble at
  their feet, wrecked cars at the kerb, lamp posts every 24 m, dead trees in planters.
- The region border is a wall of collapsed buildings (plus an invisible barrier).
"""
import math
import random

ASPHALT = "Color(0.32, 0.33, 0.36, 1)"
CONCRETE = "Color(0.55, 0.53, 0.5, 1)"
BUILDING = "Color(0.45, 0.42, 0.48, 1)"
RUST = "Color(0.5, 0.35, 0.25, 1)"
MOSS = "Color(0.26, 0.42, 0.24, 1)"

CHUNK = 128.0
HALF = 64.0
ROAD_W = 12.0
WALK_W = 3.0
KERB_H = 0.12
LAMP_EVERY = 24.0
EDGE = 192.0

# (x0, z0, x1, z1): axis-aligned road centre lines, global metres.
ROADS = [
    (-56, -56, 56, -56),     # ring south
    (-56, 56, 56, 56),       # ring north
    (-56, -56, -56, 56),     # ring west
    (56, -56, 56, 56),       # ring east (passes under the overpass)
    (0, -56, 0, -118),       # avenue south to the river bridge
    (0, 56, 0, 186),         # avenue north
    (-186, 56, -56, 56),     # west road to the apartments
    (56, 56, 186, 56),       # east road under the highway
    (-128, 56, -128, 186),   # north-west road to Region 2
    (56, -56, 186, -56),     # east road south of the culvert
    (-186, -90, 186, -90),   # riverside street (north)
    (-186, 120, 186, 120),   # south street
    (110, 56, 110, 186),     # south-east lane
    (-60, 120, -60, 186),    # south-west lane
    (100, -90, 100, -56),    # lane between the riverside and the culvert road
]

# Areas kept free of generated blocks: (cx, cz, half_x, half_z) global.
RESERVED = [
    (0, 0, 52, 52),          # camp plaza
    (152, 0, 14, 70),        # overpass deck + pillars
    (124, 20, 26, 10),       # culvert grate, tunnel + pump room
    (118, -40, 16, 16),      # Rank E Gate + its hounds
    (-140, 4, 30, 34),       # apartment block + ramp
    (0, -128, 192, 12),      # river
    (0, -128, 24, 10),       # bridge
    (-128, 128, 10, 10),     # road waystone to Region 2
    (152, -94, 8, 20),       # broken highway end (north)
    (152, 94, 8, 20),        # broken highway end (south)
]


def _inside_chunk(cx, cz, x, z, margin=0.0):
    return abs(x - cx) <= HALF + margin and abs(z - cz) <= HALF + margin


def _reserved(x, z, pad=0.0):
    return any(abs(x - rx) < hx + pad and abs(z - rz) < hz + pad for (rx, rz, hx, hz) in RESERVED)


def _on_road(x, z, pad=0.0):
    for (x0, z0, x1, z1) in ROADS:
        lo_x, hi_x = min(x0, x1) - ROAD_W / 2 - WALK_W - pad, max(x0, x1) + ROAD_W / 2 + WALK_W + pad
        lo_z, hi_z = min(z0, z1) - ROAD_W / 2 - WALK_W - pad, max(z0, z1) + ROAD_W / 2 + WALK_W + pad
        if lo_x <= x <= hi_x and lo_z <= z <= hi_z:
            return True
    return False


def _clip(seg, cx, cz):
    """Part of a road segment inside the chunk, as (x0, z0, x1, z1) or None."""
    x0, z0, x1, z1 = seg
    lx0, lx1 = max(min(x0, x1), cx - HALF), min(max(x0, x1), cx + HALF)
    lz0, lz1 = max(min(z0, z1), cz - HALF), min(max(z0, z1), cz + HALF)
    if lx0 > lx1 or lz0 > lz1:
        return None
    return lx0, lz0, lx1, lz1


def roads(c, cx, cz):
    """Asphalt, kerbs / sidewalks and street lamps of the chunk."""
    lamp_i = 0
    for seg in ROADS:
        part = _clip(seg, cx, cz)
        if part is None:
            continue
        x0, z0, x1, z1 = part
        horizontal = seg[1] == seg[3]
        length = (x1 - x0) if horizontal else (z1 - z0)
        if length < 1.0:
            continue
        mx, mz = (x0 + x1) / 2 - cx, (z0 + z1) / 2 - cz
        ext = ROAD_W + 2 * WALK_W
        if horizontal:
            c.block((length + ext * 0.5, 0.12, ROAD_W), (mx, 0.06, mz), ASPHALT)
        else:
            c.block((ROAD_W, 0.12, length + ext * 0.5), (mx, 0.06, mz), ASPHALT)
        for side in (-1, 1):
            off = side * (ROAD_W / 2 + WALK_W / 2)
            if horizontal:
                c.block((length, KERB_H, WALK_W), (mx, KERB_H / 2, mz + off), CONCRETE)
            else:
                c.block((WALK_W, KERB_H, length), (mx + off, KERB_H / 2, mz), CONCRETE)
        # Flat ground under the road (terrain flatten discs every 10 m).
        steps = max(1, int(length // 10))
        for i in range(steps + 1):
            t = i / steps
            px = x0 + (x1 - x0) * t - cx
            pz = z0 + (z1 - z0) * t - cz
            c.point((px, 0, pz), ROAD_W)
        # Lamps alternate sides every LAMP_EVERY metres, on global multiples so they
        # line up across chunks, facing the road.
        start = math.ceil((x0 if horizontal else z0) / LAMP_EVERY) * LAMP_EVERY
        end = x1 if horizontal else z1
        v = start
        while v <= end:
            side = 1 if int(round(v / LAMP_EVERY)) % 2 == 0 else -1
            off = side * (ROAD_W / 2 + WALK_W - 0.6)
            gx, gz = (v, seg[1] + off) if horizontal else (seg[0] + off, v)
            if not _reserved(gx, gz) and _inside_chunk(cx, cz, gx, gz):
                rot = (0 if side > 0 else 180) if horizontal else (90 if side > 0 else 270)
                c.decor("lamp", (gx - cx, KERB_H, gz - cz), rot_y=rot + 90, seed=lamp_i)
                lamp_i += 1
            v += LAMP_EVERY


def kerb_cars(c, cx, cz, seed):
    """Wrecks parked along the kerbs (a few crashed at an angle)."""
    rng = random.Random(seed)
    for seg in ROADS:
        part = _clip(seg, cx, cz)
        if part is None:
            continue
        x0, z0, x1, z1 = part
        horizontal = seg[1] == seg[3]
        length = (x1 - x0) if horizontal else (z1 - z0)
        n = int(length // 30)
        for i in range(n):
            t = (i + 0.5 + rng.uniform(-0.25, 0.25)) / max(n, 1)
            side = rng.choice((-1, 1))
            off = side * (ROAD_W / 2 - 1.4)
            if horizontal:
                gx, gz, rot = x0 + (x1 - x0) * t, seg[1] + off, 90
            else:
                gx, gz, rot = seg[0] + off, z0 + (z1 - z0) * t, 0
            if _reserved(gx, gz, 2):
                continue
            crashed = rng.random() < 0.2
            rot += rng.uniform(25, 60) * rng.choice((-1, 1)) if crashed else rng.uniform(-6, 6)
            model = "prop_post_car" if rng.random() < 0.45 else "prop_car_rusted"
            c.prop(model, (gx - cx, 0, gz - cz), (4, 1.45, 2.0), RUST, rot_y=rot)


_PLAN = None


def plan_buildings(seed=4242):
    """Global plan: building rows along both sides of every road (frontage, back to back
    with the odd alley), then open lots with rubble inside the blocks. Each entry:
    (kind, x, z, w, h, d, yaw). Planned once for the whole region so rows run on across
    chunk borders without overlaps."""
    global _PLAN
    if _PLAN is not None:
        return _PLAN
    rng = random.Random(seed)
    placed = []
    boxes = []

    def free(x, z, w, d, yaw):
        hw, hd = (w / 2, d / 2) if yaw % 180 == 0 else (d / 2, w / 2)
        if abs(x) + hw > EDGE - 14 or abs(z) + hd > EDGE - 14:
            return False
        for (rx, rz, hx, hz) in RESERVED:
            if abs(x - rx) < hx + hw + 2 and abs(z - rz) < hz + hd + 2:
                return False
        for (x0, z0, x1, z1) in ROADS:
            rw = ROAD_W / 2 + WALK_W + 1.0
            lo_x, hi_x = min(x0, x1) - rw, max(x0, x1) + rw
            lo_z, hi_z = min(z0, z1) - rw, max(z0, z1) + rw
            if x + hw > lo_x and x - hw < hi_x and z + hd > lo_z and z - hd < hi_z:
                return False
        for (bx, bz, bw, bd) in boxes:
            if abs(x - bx) < hw + bw and abs(z - bz) < hd + bd:
                return False
        boxes.append((x, z, hw, hd))
        return True

    for (x0, z0, x1, z1) in ROADS:
        horizontal = z0 == z1
        lo, hi = (min(x0, x1), max(x0, x1)) if horizontal else (min(z0, z1), max(z0, z1))
        for side in (-1, 1):
            v = lo + rng.uniform(0, 6)
            while v < hi:
                w = rng.uniform(10, 17)
                d = rng.uniform(10, 14)
                setback = ROAD_W / 2 + WALK_W + 1.2 + d / 2
                if horizontal:
                    x, z, yaw = v + w / 2, z0 + side * setback, (0.0 if side > 0 else 180.0)
                else:
                    x, z, yaw = x0 + side * setback, v + w / 2, (270.0 if side > 0 else 90.0)
                tall = rng.random() < 0.18
                h = rng.uniform(24, 38) if tall else rng.uniform(9, 22)
                if free(x, z, w, d, yaw):
                    kind = "ruin" if rng.random() < 0.4 else "tower"
                    placed.append((kind, x, z, w, h, d, yaw))
                v += w + (rng.uniform(3, 6) if rng.random() < 0.3 else 0.4)
    # Block interiors: rubble lots, collapsed slabs, a few dead trees and moss.
    for _ in range(220):
        x, z = rng.uniform(-EDGE + 20, EDGE - 20), rng.uniform(-EDGE + 20, EDGE - 20)
        roll = rng.random()
        if roll < 0.5:
            if free(x, z, 4, 4, 0):
                placed.append(("rubble", x, z, 4, rng.uniform(1.2, 2.6), 4, rng.uniform(0, 360)))
        elif roll < 0.7:
            if free(x, z, 12, 9, 0):
                placed.append(("slab", x, z, 12, rng.uniform(2, 5), 9, rng.uniform(-25, 25)))
        elif roll < 0.85:
            if free(x, z, 3, 3, 0):
                placed.append(("tree", x, z, 3, rng.uniform(5, 9), 3, 0))
        elif free(x, z, 8, 8, 0):
            placed.append(("moss", x, z, 8, 0, 8, 0))
    _PLAN = placed
    return placed


def city_blocks(c, cx, cz, seed):
    rng = random.Random(seed)
    for (kind, x, z, w, h, d, yaw) in plan_buildings():
        if not (cx - HALF <= x < cx + HALF and cz - HALF <= z < cz + HALF):
            continue
        lx, lz = x - cx, z - cz
        if kind == "ruin":
            c.prop("r1_apartment_ruin_a", (lx, 0, lz), (w, h, d), BUILDING, rot_y=yaw + rng.uniform(-3, 3))
        elif kind == "tower":
            c.block((w, h, d), (lx, h / 2, lz), BUILDING, rot_y=yaw)
            if rng.random() < 0.55:
                sh = rng.uniform(2, 5)
                c.block((w * rng.uniform(0.4, 0.7), sh, d * 0.8), (lx + rng.uniform(-2, 2), h + sh / 2, lz), BUILDING,
                        rot_y=yaw + rng.uniform(-8, 8))
            # Fallen chunks on the pavement in front.
            fx = lx - math.sin(math.radians(yaw)) * (d / 2 + 1.5)
            fz = lz - math.cos(math.radians(yaw)) * (d / 2 + 1.5)
            if rng.random() < 0.35:
                c.prop("rock_pile", (fx, 0, fz), (2.4, rng.uniform(0.8, 1.4), 2.4), CONCRETE, rot_y=rng.uniform(0, 360))
        elif kind == "rubble":
            c.prop("rock_pile", (lx, 0, lz), (w, h, d), CONCRETE, rot_y=yaw)
        elif kind == "slab":
            c.block((w, 0.8, d), (lx, h * 0.3, lz), BUILDING, rot_y=yaw, rot_x=rng.uniform(8, 22))
        elif kind == "tree":
            c.tree("dead", (lx, 0, lz), h, rng.randint(1, 1 << 30))
        elif kind == "moss":
            c.grass(MOSS, 900, rng.randint(1, 99999), (w, d), (lx, 0, lz))


def planters(c, cx, cz, seed):
    """Dead trees in kerb planters along the avenue, every 36 m."""
    rng = random.Random(seed)
    for seg in ROADS[4:6]:
        part = _clip(seg, cx, cz)
        if part is None:
            continue
        x0, z0, x1, z1 = part
        v = math.ceil(z0 / 36) * 36
        while v <= z1:
            for side in (-1, 1):
                gx = seg[0] + side * (ROAD_W / 2 + WALK_W + 1.5)
                if not _reserved(gx, v, 2):
                    c.tree("dead", (gx - cx, 0, v - cz), rng.uniform(5, 8), rng.randint(1, 1 << 30))
            v += 36


def border(c, cx, cz, seed):
    """Collapsed buildings along the outside of the district + an invisible wall."""
    rng = random.Random(seed)
    for axis, sign in (("x", -1), ("x", 1), ("z", -1), ("z", 1)):
        edge_here = (axis == "x" and cx + sign * HALF == sign * EDGE) or (axis == "z" and cz + sign * HALF == sign * EDGE)
        if not edge_here:
            continue
        v = -HALF + 8
        while v < HALF:
            if axis == "x":
                lx, lz = sign * (HALF - 7), v
            else:
                lx, lz = v, sign * (HALF - 7)
            if not _on_road(lx + cx, lz + cz, 2) and not _reserved(lx + cx, lz + cz):
                h = rng.uniform(14, 30)
                yaw = 90 if axis == "x" else 0
                c.block((10, h, 10), (lx, h / 2, lz), BUILDING, rot_y=yaw + rng.uniform(-6, 6))
            v += 12
        # Invisible barrier (keeps the old edge behaviour without the bare concrete wall).
        if axis == "x":
            c.block((1, 12, 128), (sign * HALF, 6, 0), CONCRETE, solid=True)
            c.nodes[-1] += "visible = false\n"
        else:
            c.block((128, 12, 1), (0, 6, sign * HALF), CONCRETE, solid=True)
            c.nodes[-1] += "visible = false\n"


def skyline(c, cx, cz):
    """Mountains beyond the district border (scenery outside the play area), toward the
    forests of Region 2 (south, +z) and the west; they frame the dusk sky like the trailer."""
    peaks = {
        (0, 128): [(-60, 270, 11), (40, 300, 14), (120, 265, 10)],
        (-128, 128): [(-250, 250, 12), (-170, 300, 9)],
        (-128, 0): [(-280, -40, 10), (-270, 60, 12)],
    }
    for i, (x, z, s) in enumerate(peaks.get((cx, cz), [])):
        c.prop("rock_spire", (x - cx, -6, z - cz), (8.7 * s, 9 * s, 7.2 * s), CONCRETE, rot_y=i * 70)
        c.points.pop()  # scenery: no flatten disc


def dress_chunk(c, cx, cz, seed):
    roads(c, cx, cz)
    kerb_cars(c, cx, cz, seed + 1)
    planters(c, cx, cz, seed + 2)
    city_blocks(c, cx, cz, seed + 3)
    border(c, cx, cz, seed + 4)
    skyline(c, cx, cz)
