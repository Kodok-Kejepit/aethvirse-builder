"""Ashfall Outskirts as a ruined, overgrown coastal city (owner's trailer look: dusk,
collapsed towers, mossy wrecks, the broken elevated highway).

Everything is planned in GLOBAL metres and each 128 m chunk draws the part inside it, so
roads, kerbs, building rows and the highway line up across chunk borders.

Plan (x east, z south; the district spans -192..192):
- Camp plaza in the middle inside a ring road (x/z = ±56); the avenue x = 0 runs north to
  the river bridge (z = -128) and south towards the Region 2 road; side streets split the
  blocks into city blocks.
- The elevated highway runs along x = 152 on pillars; one span has collapsed into a ramp
  you can climb (z -40 .. -8), the south end breaks off over a rubble heap.
- East of the highway: a sand beach and the open sea (the district's east border).
  West / south / north: mountains beyond the edge (scenery) + an invisible barrier.
- Buildings stand in rows facing the streets; debris lies only around collapsed ones.
"""
import math
import random

ASPHALT = "Color(0.32, 0.33, 0.36, 1)"
CONCRETE = "Color(0.55, 0.53, 0.5, 1)"
BUILDING = "Color(0.45, 0.42, 0.48, 1)"
RUST = "Color(0.5, 0.35, 0.25, 1)"
MOSS = "Color(0.26, 0.42, 0.24, 1)"
SAND = "Color(0.74, 0.66, 0.5, 1)"
SIDEWALK = "Color(0.51, 0.49, 0.47, 1)"   # cracked pavement (ruined ground shader)
DIRT = "Color(0.38, 0.29, 0.2, 1)"        # bare earth (ruined ground shader)
SEA = "Color(0.16, 0.3, 0.42, 1)"

HALF = 64.0
ROAD_W = 12.0
WALK_W = 3.0
KERB_H = 0.12
LAMP_EVERY = 32.0
EDGE = 192.0
CITY_EAST = 138.0          # buildings stay west of the highway
HWY_X = 152.0
HWY_W = 16.0
HWY_Y = 8.0
HWY_Z = (-186.0, 150.0)    # deck runs from the north edge to the broken south end
HWY_GAP = (-40.0, -8.0)    # collapsed span (a climbable ramp)
BEACH_X = 164.0
SEA_X = 178.0

# (x0, z0, x1, z1): axis-aligned road centre lines, global metres.
ROADS = [
    (-56, -56, 56, -56),     # ring north
    (-56, 56, 56, 56),       # ring south
    (-56, -56, -56, 56),     # ring west
    (56, -56, 56, 56),       # ring east
    (0, -56, 0, -116),       # avenue north to the river bridge
    (0, 56, 0, 186),         # avenue south
    (-186, 56, -56, 56),     # west road to the apartments
    (56, 56, BEACH_X, 56),   # east road under the highway to the beach
    (-128, 56, -128, 186),   # south-west road to Region 2
    (56, -56, BEACH_X, -56), # east road past the culvert
    (-186, -90, BEACH_X, -90),  # riverside street
    (-186, 120, BEACH_X, 120),  # south street
    (110, 56, 110, 186),     # south-east lane
    (-60, 120, -60, 186),    # south-west lane
    (100, -90, 100, -56),    # lane between the riverside and the culvert road
]

# Areas kept free of generated pieces: (cx, cz, half_x, half_z) global.
RESERVED = [
    (0, 0, 52, 52),            # camp plaza
    (HWY_X, 0, 12, 200),       # highway deck + pillars
    (124, 20, 26, 10),         # culvert grate, tunnel + pump room
    (118, -40, 16, 16),        # Rank E Gate + its hounds
    (-140, -10, 30, 22),       # apartment block
    (0, -128, 200, 12),        # river
    (-128, 128, 10, 10),       # road waystone to Region 2
    (130, 40, 6, 6),           # Hollow Gate spot
]


def _inside_chunk(cx, cz, x, z, margin=0.0):
    return abs(x - cx) <= HALF + margin and abs(z - cz) <= HALF + margin


def _reserved(x, z, pad=0.0):
    return any(abs(x - rx) < hx + pad and abs(z - rz) < hz + pad for (rx, rz, hx, hz) in RESERVED)


def _on_asphalt(x, z, pad=0.0):
    for (x0, z0, x1, z1) in ROADS:
        w = ROAD_W / 2 + pad
        if min(x0, x1) - w <= x <= max(x0, x1) + w and min(z0, z1) - w <= z <= max(z0, z1) + w:
            return True
    return False


def _clip(seg, cx, cz):
    x0, z0, x1, z1 = seg
    lx0, lx1 = max(min(x0, x1), cx - HALF), min(max(x0, x1), cx + HALF)
    lz0, lz1 = max(min(z0, z1), cz - HALF), min(max(z0, z1), cz + HALF)
    if lx0 > lx1 or lz0 > lz1:
        return None
    return lx0, lz0, lx1, lz1


# --- streets --------------------------------------------------------------------------------

def roads(c, cx, cz, seed):
    """Cracked asphalt, kerbs / sidewalks and rusted street lamps (some dead, some leaning)."""
    rng = random.Random(seed)
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
                c.block((length, KERB_H, WALK_W), (mx, KERB_H / 2, mz + off), SIDEWALK)
            else:
                c.block((WALK_W, KERB_H, length), (mx + off, KERB_H / 2, mz), SIDEWALK)
        steps = max(1, int(length // 10))
        for i in range(steps + 1):
            t = i / steps
            c.point((x0 + (x1 - x0) * t - cx, 0, z0 + (z1 - z0) * t - cz), ROAD_W)
        # Earth and roots breaking through near the kerbs.
        for _ in range(int(length // 40)):
            t = rng.uniform(0.05, 0.95)
            off = rng.choice((-1, 1)) * (ROAD_W / 2 - rng.uniform(0.8, 2.5))
            gx, gz = (x0 + (x1 - x0) * t, seg[1] + off) if horizontal else (seg[0] + off, z0 + (z1 - z0) * t)
            if not _reserved(gx, gz, 2) and abs(gx - HWY_X) > 10:
                model = rng.choice(("tile_roots_grass", "tile_roots_grass", "tile_dirt", "tile_mud"))
                c.prop(model, (gx - cx, 0, gz - cz), (rng.uniform(2.5, 4.5), 0.5, rng.uniform(2.5, 4.5)), DIRT, rot_y=rng.uniform(0, 360))
                c.points.pop()
        # One lamp every LAMP_EVERY m, alternating sides, never on another road's asphalt.
        v = math.ceil((x0 if horizontal else z0) / LAMP_EVERY) * LAMP_EVERY
        end = x1 if horizontal else z1
        while v <= end:
            side = 1 if int(round(v / LAMP_EVERY)) % 2 == 0 else -1
            off = side * (ROAD_W / 2 + WALK_W - 0.5)
            gx, gz = (v, seg[1] + off) if horizontal else (seg[0] + off, v)
            if not _reserved(gx, gz) and not _on_asphalt(gx, gz, 0.8) and _inside_chunk(cx, cz, gx, gz) \
                    and abs(gx - HWY_X) > 10:
                # The arm reaches over the road.
                yaw = (90 if side > 0 else 270) if horizontal else (180 if side > 0 else 0)
                c.decor("streetlight", (gx - cx, KERB_H, gz - cz), rot_y=yaw, seed=rng.randint(1, 99999))
            v += LAMP_EVERY


def abandoned_cars(c, cx, cz, seed):
    """A few wrecks per street, left where they died: angled, against kerbs, in the lanes."""
    rng = random.Random(seed)
    for seg in ROADS:
        part = _clip(seg, cx, cz)
        if part is None:
            continue
        x0, z0, x1, z1 = part
        horizontal = seg[1] == seg[3]
        length = (x1 - x0) if horizontal else (z1 - z0)
        for _ in range(int(length // 55)):
            t = rng.uniform(0.1, 0.9)
            off = rng.uniform(-ROAD_W / 2 + 1.5, ROAD_W / 2 - 1.5)
            if horizontal:
                gx, gz, base = x0 + (x1 - x0) * t, seg[1] + off, 90.0
            else:
                gx, gz, base = seg[0] + off, z0 + (z1 - z0) * t, 0.0
            if _reserved(gx, gz, 3) or abs(gx - HWY_X) < 10:
                continue
            yaw = base + rng.choice((rng.uniform(-25, 25), rng.uniform(35, 80) * rng.choice((-1, 1)), 180 + rng.uniform(-20, 20)))
            model = "prop_post_car" if rng.random() < 0.5 else "prop_car_rusted"
            c.prop(model, (gx - cx, 0, gz - cz), (4, 1.45, 2.0), RUST, rot_y=yaw)


# --- buildings ------------------------------------------------------------------------------

_PLAN = None


def plan_buildings(seed=4242):
    """Global plan: building rows along both sides of every road (frontage, back to back
    with the odd alley); some are collapsed and shed debris; block interiors are empty lots
    with fallen slabs, moss and dead trees. Entries: (kind, x, z, w, h, d, yaw)."""
    global _PLAN
    if _PLAN is not None:
        return _PLAN
    rng = random.Random(seed)
    placed = []
    boxes = []

    def free(x, z, w, d, yaw):
        hw, hd = (w / 2, d / 2) if yaw % 180 == 0 else (d / 2, w / 2)
        if abs(z) + hd > EDGE - 10 or x - hw < -EDGE + 10 or x + hw > CITY_EAST:
            return False
        for (rx, rz, hx, hz) in RESERVED:
            if abs(x - rx) < hx + hw + 2 and abs(z - rz) < hz + hd + 2:
                return False
        for (x0, z0, x1, z1) in ROADS:
            rw = ROAD_W / 2 + WALK_W + 1.0
            if x + hw > min(x0, x1) - rw and x - hw < max(x0, x1) + rw and z + hd > min(z0, z1) - rw and z - hd < max(z0, z1) + rw:
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
                w, d = rng.uniform(10, 17), rng.uniform(10, 14)
                setback = ROAD_W / 2 + WALK_W + 1.2 + d / 2
                if horizontal:
                    x, z, yaw = v + w / 2, z0 + side * setback, (0.0 if side > 0 else 180.0)
                else:
                    x, z, yaw = x0 + side * setback, v + w / 2, (270.0 if side > 0 else 90.0)
                tall = rng.random() < 0.18
                h = rng.uniform(24, 38) if tall else rng.uniform(9, 22)
                if free(x, z, w, d, yaw):
                    roll = rng.random()
                    kind = "ruin" if roll < 0.35 else ("collapsed" if roll < 0.55 else "tower")
                    placed.append((kind, x, z, w, h, d, yaw))
                v += w + (rng.uniform(3, 6) if rng.random() < 0.3 else 0.4)
    for _ in range(260):
        x, z = rng.uniform(-EDGE + 20, CITY_EAST - 10), rng.uniform(-EDGE + 20, EDGE - 20)
        roll = rng.random()
        if roll < 0.35:
            if free(x, z, 12, 9, 0):
                placed.append(("slab", x, z, 12, 0, 9, rng.uniform(-25, 25)))
        elif roll < 0.7:
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
        fwd = (-math.sin(math.radians(yaw)), -math.cos(math.radians(yaw)))
        if kind == "ruin":
            c.prop("r1_apartment_ruin_a", (lx, 0, lz), (w, h, d), BUILDING, rot_y=yaw + rng.uniform(-3, 3))
        elif kind == "tower":
            c.block((w, h, d), (lx, h / 2, lz), BUILDING, rot_y=yaw)
            if rng.random() < 0.5:
                sh = rng.uniform(2, 4)
                c.block((w * rng.uniform(0.4, 0.7), sh, d * 0.8), (lx, h + sh / 2, lz), BUILDING, rot_y=yaw)
            elif rng.random() < 0.55:
                # Roof garden gone wild: moss bed and a tree that rooted up there.
                c.grass(MOSS, 500, rng.randint(1, 99999), (w * 0.7, d * 0.7), (lx, h, lz))
                if rng.random() < 0.6:
                    c.tree("ruin_bush" if rng.random() < 0.5 else "ruin", (lx + rng.uniform(-w / 4, w / 4), h, lz + rng.uniform(-d / 4, d / 4)), rng.uniform(3, 6), rng.randint(1, 1 << 30))
            if rng.random() < 0.4:
                c.prop("tile_roots_grass", (lx + fwd[0] * (d / 2 + 0.5), 0, lz + fwd[1] * (d / 2 + 0.5)), (w * 0.8, 0.7, 2.5), DIRT, rot_y=yaw)
                c.points.pop()
        elif kind == "collapsed":
            # A broken stump of a building; its upper floors lie as debris on the street side.
            hs = rng.uniform(4, 9)
            c.block((w, hs, d), (lx, hs / 2, lz), BUILDING, rot_y=yaw)
            # Nature took the stump: moss on top, often a tree growing out of it.
            c.grass(MOSS, 600, rng.randint(1, 99999), (w * 0.8, d * 0.8), (lx, hs, lz))
            if rng.random() < 0.6:
                c.tree("ruin", (lx + rng.uniform(-2, 2), hs, lz + rng.uniform(-2, 2)), rng.uniform(6, 10), rng.randint(1, 1 << 30))
            c.prop("tile_roots_grass", (lx, 0, lz + d / 2 + 0.8), (w, 0.8, 3), DIRT, rot_y=yaw)
            c.points.pop()
            for i in range(rng.randint(2, 4)):
                k = d / 2 + rng.uniform(1.5, 5.0)
                sx = rng.uniform(-w / 2, w / 2)
                px = lx + fwd[0] * k + fwd[1] * sx
                pz = lz + fwd[1] * k - fwd[0] * sx
                if not _on_asphalt(px + cx, pz + cz, -2.0):
                    c.decor("debris", (px, 0, pz), seed=rng.randint(1, 99999))
        elif kind == "slab":
            tilt = rng.uniform(8, 22)
            y = math.sin(math.radians(tilt)) * d / 2 - 0.3
            c.block((w, 0.8, d), (lx, y, lz), BUILDING, rot_y=yaw, rot_x=tilt)
            c.decor("debris", (lx + rng.uniform(-3, 3), 0, lz + d / 2), seed=rng.randint(1, 99999))
        elif kind == "tree":
            roll = rng.random()
            kind = "ruin" if roll < 0.55 else ("ruin_twisted" if roll < 0.75 else ("ruin_bush" if roll < 0.9 else "ruin_stump"))
            hh = {"ruin": rng.uniform(8, 13), "ruin_twisted": rng.uniform(6, 9), "ruin_bush": 2.8, "ruin_stump": 1.8}[kind]
            c.tree(kind, (lx, 0, lz), hh, rng.randint(1, 1 << 30))
            c.grass(MOSS, 400, rng.randint(1, 99999), (6, 6), (lx, 0, lz))
        elif kind == "moss":
            c.grass(MOSS, 1400, rng.randint(1, 99999), (w * 1.6, d * 1.6), (lx, 0, lz))
            if rng.random() < 0.5:
                c.prop(rng.choice(("tile_mud", "tile_roots_grass", "tile_dirt")), (lx, 0, lz), (4, 0.5, 4), DIRT, rot_y=rng.uniform(0, 360))
                c.points.pop()


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
                    c.tree("ruin" if rng.random() < 0.6 else "ruin_twisted", (gx - cx, 0, v - cz), rng.uniform(6, 10), rng.randint(1, 1 << 30))
            v += 36


# --- elevated highway -----------------------------------------------------------------------

def highway(c, cx, cz, seed):
    """Deck on pillar pairs every 24 m, guard rails, one collapsed span as a ramp to the
    ground, and a broken south end over a rubble heap."""
    if not (cx - HALF <= HWY_X <= cx + HALF):
        return
    rng = random.Random(seed)
    lx = HWY_X - cx
    for (a, b) in ((HWY_Z[0], HWY_GAP[0]), (HWY_GAP[1], HWY_Z[1])):
        lo, hi = max(a, cz - HALF), min(b, cz + HALF)
        if lo >= hi:
            continue
        mz = (lo + hi) / 2 - cz
        c.block((HWY_W, 1.0, hi - lo), (lx, HWY_Y - 0.5, mz), CONCRETE)
        c.block((HWY_W - 1.0, 0.06, hi - lo), (lx, HWY_Y + 0.03, mz), ASPHALT)
        for side in (-1, 1):
            c.block((0.4, 1.0, hi - lo), (lx + side * (HWY_W / 2 - 0.2), HWY_Y + 0.5, mz), CONCRETE)
    z = HWY_Z[0] + 12
    while z < HWY_Z[1]:
        if cz - HALF <= z < cz + HALF and not (HWY_GAP[0] - 4 < z < HWY_GAP[1] + 4):
            for side in (-1, 1):
                c.block((2.4, HWY_Y - 1.0, 2.4), (lx + side * 5.0, (HWY_Y - 1.0) / 2, z - cz), CONCRETE)
            c.block((HWY_W - 2, 1.0, 2.0), (lx, HWY_Y - 1.5, z - cz), CONCRETE)
        z += 24
    # Collapsed span: tilted deck slab from the north deck edge down to the ground.
    g0, g1 = HWY_GAP
    gm = (g0 + g1) / 2
    if cz - HALF <= gm < cz + HALF:
        run = g1 - g0
        ang = math.degrees(math.atan2(HWY_Y, run))
        c.block((HWY_W - 2, 0.8, math.hypot(run, HWY_Y)), (lx + 0.8, HWY_Y / 2 - 0.2, gm - cz), CONCRETE, rot_x=ang, rot_y=3)
        for i in range(4):
            c.decor("debris", (lx + rng.uniform(-8, 8), 0, g1 - cz + rng.uniform(-3, 4)), seed=rng.randint(1, 99999))
    # Broken south end: rubble heap below the jagged edge.
    if cz - HALF <= HWY_Z[1] < cz + HALF:
        for i in range(6):
            c.decor("debris", (lx + rng.uniform(-7, 7), 0, HWY_Z[1] - cz + rng.uniform(1, 14)), seed=rng.randint(1, 99999))
        c.block((HWY_W * 0.6, 0.8, 7), (lx - 2, 2.5, HWY_Z[1] - cz + 5), CONCRETE, rot_x=-28, rot_y=12)
    # A few wrecks stranded on the deck.
    for _ in range(2):
        zz = rng.uniform(max(HWY_Z[0], cz - HALF + 4), min(HWY_Z[1], cz + HALF - 4))
        if HWY_GAP[0] - 2 < zz < HWY_GAP[1] + 2 or zz >= HWY_Z[1] - 2:
            continue
        c.prop("prop_car_rusted", (lx + rng.uniform(-4, 4), HWY_Y, zz - cz), (4, 1.45, 2.0), RUST, rot_y=rng.uniform(-30, 30))


# --- borders --------------------------------------------------------------------------------

def coast(c, cx, cz):
    """Beach and open sea along the east edge."""
    if cx + HALF < BEACH_X:
        return
    lx0 = BEACH_X - cx
    width = SEA_X - BEACH_X + 6
    c.block((width, 0.3, 128), (lx0 + width / 2, 0.15, 0), SAND)
    c.block((900, 0.2, 128), (SEA_X - cx + 450, 0.0, 0), SEA, solid=False)
    # Keep the rolling ground below the sand and the water.
    for z in range(-60, 61, 12):
        for x in (lx0 + 4, lx0 + 14, lx0 + 24, lx0 + 34):
            if x <= HALF + 8:
                c.point((x, 0, z), 9)


def border(c, cx, cz):
    """Invisible barrier on the district edge (the scenery beyond shows where it ends)."""
    for cond, size, pos in (
        (cx - HALF == -EDGE, (1, 14, 128), (-HALF, 7, 0)),
        (cx + HALF == EDGE, (1, 14, 128), (HALF, 7, 0)),
        (cz - HALF == -EDGE, (128, 14, 1), (0, 7, -HALF)),
        (cz + HALF == EDGE, (128, 14, 1), (0, 7, HALF)),
    ):
        if cond:
            c.block(size, pos, CONCRETE)
            c.nodes[-1] += "visible = false\n"


def skyline(c, cx, cz):
    """Mountains beyond the west, north and south edges (outside the play area)."""
    peaks = {
        (0, 128): [(-60, 270, 11), (40, 300, 14), (120, 265, 10)],
        (-128, 128): [(-250, 250, 12), (-170, 300, 9)],
        (-128, 0): [(-280, -40, 10), (-270, 60, 12)],
        (-128, -128): [(-250, -260, 11)],
        (0, -128): [(-40, -280, 12), (70, -300, 10)],
    }
    for i, (x, z, s) in enumerate(peaks.get((cx, cz), [])):
        c.prop("rock_spire", (x - cx, -6, z - cz), (8.7 * s, 9 * s, 7.2 * s), CONCRETE, rot_y=i * 70)
        c.points.pop()  # scenery: no flatten disc


def wildlife(c, cx, cz, seed):
    """Roaming packs outside the camp's safe zone (two per chunk, on lots and streets)."""
    if cx == 0 and cz == 0:
        return
    rng = random.Random(seed)
    placed = 0
    for _ in range(40):
        if placed >= 2:
            break
        x, z = cx + rng.uniform(-50, 50), cz + rng.uniform(-50, 50)
        if math.hypot(x, z) < 80 or _reserved(x, z, 4) or x > CITY_EAST:
            continue
        enemy = "ash_hound" if rng.random() < 0.55 else "gate_husk"
        for k in range(rng.randint(2, 3)):
            c.spawner(enemy, (x - cx + rng.uniform(-3, 3), 0.3, z - cz + rng.uniform(-3, 3)))
        placed += 1


def dress_chunk(c, cx, cz, seed):
    roads(c, cx, cz, seed)
    abandoned_cars(c, cx, cz, seed + 1)
    planters(c, cx, cz, seed + 2)
    city_blocks(c, cx, cz, seed + 3)
    highway(c, cx, cz, seed + 5)
    coast(c, cx, cz)
    border(c, cx, cz)
    skyline(c, cx, cz)
    wildlife(c, cx, cz, seed + 6)
