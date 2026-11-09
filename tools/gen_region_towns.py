#!/usr/bin/env python3
"""Region expansion (2026-11-10): Regions 2-6 grow from 3x3 to 5x5 chunks (640 m across).

The 3x3 core keeps its places (built with the gen_m9_world.py / gen_m11_world.py builders).
The new outer ring adds, per region (owner: every region has a modern city and villages with
clear borders):
- a walled **city**: streets on a grid, rows of buildings in the region's own facade palette,
  a plaza with a waystone, market, lamps and townsfolk;
- a **village**: the region's own houses around a green, fields, a well, a palisade;
- a **landmark** guarded by a strong pack, with a treasure chest;
- wilds whose monsters climb towards the region's top level (the core keeps its levels).
It also writes the new townsfolk (NpcData) and patches the region data (waystones, Gate
spots, chunk_radius) without touching hand-tuned values (levels, bonuses, totals).

Run from the project root:  python3 tools/gen_region_towns.py
Region 1 (Ashfall) is not touched; its chunks come from gen_ashfall_chunks.py.
This replaces the region_chunks() calls of gen_m9_world.py / gen_m11_world.py.
"""
import math
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import gen_ashfall_chunks as ga  # noqa: E402
import gen_m9_world as w  # noqa: E402
import gen_m11_world as m11  # noqa: E402
import world_dressing as wd  # noqa: E402

GRID = 2                      # chunks from the centre to the edge (5x5)
CORE = 1                      # the old 3x3
HALF = 64.0

ASPHALT = "Color(0.32, 0.33, 0.36, 1)"     # pavement shader: asphalt
SIDEWALK = "Color(0.51, 0.49, 0.47, 1)"    # pavement shader: concrete slabs
CONCRETE = "Color(0.55, 0.53, 0.5, 1)"
DIRT = "Color(0.38, 0.29, 0.2, 1)"
WOOD = "Color(0.45, 0.32, 0.22, 1)"
ROOF = "Color(0.25, 0.35, 0.6, 1)"
FIELD = "Color(0.3, 0.55, 0.25, 1)"        # non-solid green: swaying crops

# Facade palettes (world_streamer.gd STYLES / BUILDING_LOOKS use the same colours).
BLD = {
    "r2": "Color(0.42, 0.44, 0.4, 1)",     # overgrown concrete
    "r3": "Color(0.66, 0.55, 0.42, 1)",    # sandstone
    "r4": "Color(0.5, 0.52, 0.58, 1)",     # cold slate, snowy roofs
    "r5": "Color(0.46, 0.5, 0.52, 1)",     # damp canal stone
    "r6": "Color(0.38, 0.33, 0.48, 1)",    # rift-touched violet
}

REGIONS = {
    "r2": dict(rid="r2_verdant", lv=(50, 100), ground=w.FOREST, rock=w.ROOT, lamp="Color(0.75, 1, 0.6, 1)",
               enemies=["thorn_stalker", "moss_brute"], tree="oak",
               city=((-2, 0), "GREENREACH", "r2_greenreach", ["greenreach_warden", "greenreach_grocer"]),
               village=((1, 2), "THORNFIELD", "r2_thornfield", ["thornfield_farmer", "thornfield_herbalist"]),
               landmark=((2, -2), "ELDER CANOPY"),
               gates=[(-2, -2), (2, 2), (-1, 2)]),
    "r3": dict(rid="r3_dunes", lv=(100, 150), ground=w.SAND, rock=w.STONE, lamp="Color(1, 0.65, 0.35, 1)",
               enemies=["dune_scuttler", "sand_wraith"], tree="palm",
               city=((2, 1), "SANDMERE", "r3_sandmere", ["sandmere_captain", "sandmere_merchant"]),
               village=((-2, -1), "DUSTWELL", "r3_dustwell", ["dustwell_keeper", "dustwell_child"]),
               landmark=((0, 2), "SUNSCAR PLATEAU"),
               gates=[(-2, 2), (2, -2), (-1, -2)]),
    "r4": dict(rid="r4_frostveil", lv=(150, 200), ground=m11.SNOW, rock=m11.ROCK, lamp="Color(1, 0.82, 0.55, 1)",
               enemies=["frost_yeti", "ice_wyvernling"], tree="pine",
               city=((-1, -2), "WHITEHOLD", "r4_whitehold", ["whitehold_sentry", "whitehold_smith"]),
               village=((2, 0), "PINECREST", "r4_pinecrest", ["pinecrest_trapper", "pinecrest_elder"]),
               landmark=((-2, 2), "FROZEN SPIRE"),
               gates=[(2, 2), (-2, -1), (1, 2)]),
    "r5": dict(rid="r5_archive", lv=(200, 250), ground=m11.WATERSTONE, rock=m11.SHELF, lamp="Color(0.6, 0.85, 1, 1)",
               enemies=["drowned_scribe", "ink_wraith"], tree="dead",
               city=((0, 2), "LOWMARKET", "r5_lowmarket", ["lowmarket_ferryman", "lowmarket_scribe"]),
               village=((-2, -1), "SALTREED", "r5_saltreed", ["saltreed_netmender", "saltreed_diver"]),
               landmark=((2, -2), "DROWNED BELLTOWER"),
               gates=[(-2, 2), (2, 1), (-1, -2)]),
    "r6": dict(rid="r6_fracture", lv=(250, 300), ground=m11.RIFT, rock=m11.VOIDWHITE, lamp="Color(0.75, 0.55, 1, 1)",
               enemies=["void_hollow", "rift_stalker"], tree="crystal",
               city=((-2, 1), "SHARDHAVEN", "r6_shardhaven", ["shardhaven_watcher", "shardhaven_tinker"]),
               village=((1, -2), "LAST LANTERN", "r6_lantern", ["lantern_keeper", "lantern_scout"]),
               landmark=((2, 2), "DRIFTING ISLE"),
               gates=[(-2, -2), (2, -1), (0, 2)]),
}

# Townsfolk: id -> (name key, body colour). Lines are DLG_<ID>_1 / _2 (strings.csv).
TOWNSFOLK = {
    "greenreach_warden": ("NPC_GREENREACH_WARDEN", "Color(0.3, 0.5, 0.35, 1)"),
    "greenreach_grocer": ("NPC_GREENREACH_GROCER", "Color(0.65, 0.55, 0.35, 1)"),
    "thornfield_farmer": ("NPC_THORNFIELD_FARMER", "Color(0.55, 0.45, 0.3, 1)"),
    "thornfield_herbalist": ("NPC_THORNFIELD_HERBALIST", "Color(0.4, 0.6, 0.45, 1)"),
    "sandmere_captain": ("NPC_SANDMERE_CAPTAIN", "Color(0.7, 0.5, 0.3, 1)"),
    "sandmere_merchant": ("NPC_SANDMERE_MERCHANT", "Color(0.8, 0.6, 0.35, 1)"),
    "dustwell_keeper": ("NPC_DUSTWELL_KEEPER", "Color(0.6, 0.45, 0.35, 1)"),
    "dustwell_child": ("NPC_DUSTWELL_CHILD", "Color(0.85, 0.65, 0.45, 1)"),
    "whitehold_sentry": ("NPC_WHITEHOLD_SENTRY", "Color(0.55, 0.6, 0.7, 1)"),
    "whitehold_smith": ("NPC_WHITEHOLD_SMITH", "Color(0.45, 0.35, 0.3, 1)"),
    "pinecrest_trapper": ("NPC_PINECREST_TRAPPER", "Color(0.5, 0.4, 0.3, 1)"),
    "pinecrest_elder": ("NPC_PINECREST_ELDER", "Color(0.75, 0.75, 0.8, 1)"),
    "lowmarket_ferryman": ("NPC_LOWMARKET_FERRYMAN", "Color(0.35, 0.45, 0.55, 1)"),
    "lowmarket_scribe": ("NPC_LOWMARKET_SCRIBE", "Color(0.4, 0.4, 0.55, 1)"),
    "saltreed_netmender": ("NPC_SALTREED_NETMENDER", "Color(0.45, 0.55, 0.5, 1)"),
    "saltreed_diver": ("NPC_SALTREED_DIVER", "Color(0.3, 0.5, 0.6, 1)"),
    "shardhaven_watcher": ("NPC_SHARDHAVEN_WATCHER", "Color(0.5, 0.4, 0.7, 1)"),
    "shardhaven_tinker": ("NPC_SHARDHAVEN_TINKER", "Color(0.6, 0.5, 0.45, 1)"),
    "lantern_keeper": ("NPC_LANTERN_KEEPER", "Color(0.7, 0.6, 0.85, 1)"),
    "lantern_scout": ("NPC_LANTERN_SCOUT", "Color(0.45, 0.4, 0.6, 1)"),
}


def ring_level(folder, gx, gz):
    """Monster level in the outer ring: from the region's start + 15 at the old border
    (192 m) up to its top − 2 at the far corners (the core keeps its own levels)."""
    lo, hi = REGIONS[folder]["lv"]
    d = max(abs(gx), abs(gz)) + 0.35 * min(abs(gx), abs(gz))
    t = max(0.0, min(1.0, (d - 192.0) / (320.0 + 0.35 * 256.0 - 192.0)))
    return int(round(lo + 15 + t * (hi - lo - 17)))


# --- helpers ---------------------------------------------------------------------------------

def flat_town(c, r=78.0):
    """Keep the terrain flat under a town (one wide flatten disc plus the corners)."""
    c.point((0, 0, 0), r)
    for sx in (-1, 1):
        for sz in (-1, 1):
            c.point((sx * 42, 0, sz * 42), 30)


def town_wall(c, half, color, gates, height=3.4, lamp=None, banner=None):
    """Wall around a town with gaps on the given sides ('n','s','e','w'), posts every 16 m,
    lamps and banners on the gate posts."""
    gap = 18.0
    t = 1.0
    for side in "nsew":
        horizontal = side in "ns"
        fixed = -half if side in "nw" else half
        for sign in (-1, 1):
            if side in gates:
                length = half - gap / 2
                mid = sign * (gap / 2 + length / 2)
            else:
                length = half
                mid = sign * half / 2
            if horizontal:
                c.block((length, height, t), (mid, height / 2, fixed), color)
            else:
                c.block((t, height, length), (fixed, height / 2, mid), color)
        v = -half
        while v <= half:
            if not (side in gates and abs(v) < gap / 2 + 1):
                p = (v, height / 2 + 0.4, fixed) if horizontal else (fixed, height / 2 + 0.4, v)
                c.block((1.6, height + 0.8, 1.6), p, color)
            v += 16.0
        if side in gates:
            for sign in (-1, 1):
                gx, gz = ((sign * (gap / 2 + 0.8), fixed) if horizontal else (fixed, sign * (gap / 2 + 0.8)))
                c.block((1.8, height + 2.4, 1.8), (gx, (height + 2.4) / 2, gz), color)
                inward = -1 if fixed > 0 else 1
                ix, iz = ((gx, gz + inward * 2.0) if horizontal else (gx + inward * 2.0, gz))
                if lamp:
                    c.decor("lamp", (ix, 0, iz), lamp, rot_y=0 if horizontal else 90)
                if banner:
                    c.decor("banner", (gx + (0 if horizontal else inward * 1.2), 0, gz + (inward * 1.2 if horizontal else 0)), banner)


def gate_sides(at):
    """Town gates face the region, never the outer border."""
    x, z = at
    sides = set("nsew")
    if x == -GRID:
        sides.discard("w")
    if x == GRID:
        sides.discard("e")
    if z == -GRID:
        sides.discard("n")
    if z == GRID:
        sides.discard("s")
    return sides


# --- the modern city -------------------------------------------------------------------------

ROAD_W = 10.0
WALK_W = 3.0
CITY_HALF = 56.0


def _street(c, x0, z0, x1, z1):
    horizontal = z0 == z1
    length = (x1 - x0) if horizontal else (z1 - z0)
    mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
    # Asphalt stands a little above the sidewalks so crossings read as one road.
    if horizontal:
        c.block((length, 0.17, ROAD_W), (mx, 0.085, mz), ASPHALT)
    else:
        c.block((ROAD_W, 0.17, length), (mx, 0.085, mz), ASPHALT)
    for side in (-1, 1):
        off = side * (ROAD_W / 2 + WALK_W / 2)
        if horizontal:
            c.block((length, 0.14, WALK_W), (mx, 0.07, mz + off), SIDEWALK)
        else:
            c.block((WALK_W, 0.14, length), (mx + off, 0.07, mz), SIDEWALK)


def city(c, folder, seed, name, way_id, npcs, at):
    st = REGIONS[folder]
    rng = random.Random(seed)
    bld = BLD[folder]
    c.block((128, 1, 128), (0, -0.5, 0), st["ground"])
    flat_town(c)
    # Streets on a 36 m grid; the avenue (E-W) and the main street (N-S) cross at the plaza
    # and run out through the gates (only where the wall has one).
    gates = gate_sides(at)
    edge = CITY_HALF + 8
    inner = CITY_HALF - 2
    ax0 = -edge if "w" in gates else -inner
    ax1 = edge if "e" in gates else inner
    mz0 = -edge if "n" in gates else -inner
    mz1 = edge if "s" in gates else inner
    streets = [(ax0, 0, ax1, 0), (0, mz0, 0, mz1)]
    for k in (-36, 36):
        streets.append((-inner, k, inner, k))
        streets.append((k, -inner, k, inner))
    # City floor: worn concrete slabs under everything (streets and the plaza sit on it).
    c.block((CITY_HALF * 2 + 6, 0.06, CITY_HALF * 2 + 6), (0, 0.03, 0), SIDEWALK)
    for s in streets:
        _street(c, *s)
    plaza = 13.0
    c.block((plaza * 2, 0.16, plaza * 2), (0, 0.08, 0), SIDEWALK)
    boxes = [(0, 0, plaza, plaza)]
    if folder == "r5":
        # Lowmarket: the two east-west lanes are canals, crossed by footbridges.
        for k in (-36, 36):
            c.block((inner * 2, 0.2, ROAD_W - 1.0), (0, 0.2, k), w.POND, solid=False)
            for bx in (-36, 0, 36):
                wd.put(c, "prop_bridge_wood", bx, k, 90, WOOD)

    def free(x, z, hw, hd, gap=0.8):
        if abs(x) + hw > CITY_HALF - 1.5 or abs(z) + hd > CITY_HALF - 1.5:
            return False
        for (x0, z0, x1, z1) in streets:
            rw = ROAD_W / 2 + WALK_W + 0.4
            if x + hw > min(x0, x1) - rw and x - hw < max(x0, x1) + rw and z + hd > min(z0, z1) - rw and z - hd < max(z0, z1) + rw:
                return False
        for (bx, bz, bw, bd) in boxes:
            if abs(x - bx) < hw + bw + gap and abs(z - bz) < hd + bd + gap:
                return False
        boxes.append((x, z, hw, hd))
        return True

    def building(x, z, wdt, dep, yaw, h):
        c.block((wdt, h, dep), (x, h / 2, z), bld, rot_y=yaw)
        roll = rng.random()
        if roll < 0.3:
            sh = rng.uniform(2, 3.5)
            c.block((wdt * rng.uniform(0.35, 0.6), sh, dep * 0.6), (x, h + sh / 2, z), bld, rot_y=yaw)
        elif roll < 0.45:
            c.decor("water_tank", (x + rng.uniform(-2, 2), h, z + rng.uniform(-2, 2)), seed=rng.randint(1, 99999))
        elif roll < 0.55:
            # Antenna mast on the tall ones.
            c.block((0.3, rng.uniform(4, 8), 0.3), (x, h + 3, z), CONCRETE)
        elif roll < 0.75 and folder == "r6":
            # Shardhaven: a broken-off piece of the building hangs in the air above it.
            c.block((wdt * rng.uniform(0.4, 0.7), rng.uniform(2, 4), dep * rng.uniform(0.4, 0.7)),
                    (x + rng.uniform(-2, 2), h + rng.uniform(5, 11), z + rng.uniform(-2, 2)), bld,
                    rot_y=yaw + rng.uniform(-25, 25), rot_x=rng.uniform(-14, 14))
        elif roll < 0.7 and folder == "r2":
            # Roof gardens gone wild in the forest city.
            c.grass("Color(0.26, 0.42, 0.24, 1)", 300, rng.randint(1, 99999), (wdt * 0.7, dep * 0.6), (x, h, z))

    # Building rows facing every street.
    for (x0, z0, x1, z1) in streets:
        horizontal = z0 == z1
        lo, hi = (min(x0, x1), max(x0, x1)) if horizontal else (min(z0, z1), max(z0, z1))
        for side in (-1, 1):
            v = lo + rng.uniform(0, 3)
            while v < hi:
                wdt, dep = rng.uniform(8, 14), rng.uniform(8, 9.6)
                setback = ROAD_W / 2 + WALK_W + 0.6 + dep / 2
                if horizontal:
                    x, z, yaw, hw, hd = v + wdt / 2, z0 + side * setback, (0.0 if side > 0 else 180.0), wdt / 2, dep / 2
                else:
                    x, z, yaw, hw, hd = x0 + side * setback, v + wdt / 2, (270.0 if side > 0 else 90.0), dep / 2, wdt / 2
                if free(x, z, hw, hd, 0.4):
                    tall = rng.random() < 0.25
                    building(x, z, wdt, dep, yaw, rng.uniform(22, 38) if tall else rng.uniform(8, 19))
                    v += wdt + (rng.uniform(2, 4) if rng.random() < 0.25 else 0.5)
                else:
                    # Blocked (a crossing, the plaza): try again a little further on.
                    v += 1.5
    # Back lots: low annexes, small parks and car parks between the rows.
    for _ in range(90):
        x, z = rng.uniform(-CITY_HALF + 6, CITY_HALF - 6), rng.uniform(-CITY_HALF + 6, CITY_HALF - 6)
        roll = rng.random()
        if roll < 0.5:
            wdt, dep = rng.uniform(5, 8), rng.uniform(5, 8)
            if free(x, z, wdt / 2, dep / 2, 0.6):
                building(x, z, wdt, dep, rng.choice((0.0, 90.0)), rng.uniform(4, 7))
        elif roll < 0.75:
            if free(x, z, 4.5, 4.5, 0.6):
                c.grass("Color(0.3, 0.5, 0.28, 1)" if folder != "r3" else "Color(0.55, 0.5, 0.3, 1)", 500,
                        rng.randint(1, 99999), (8, 8), (x, 0.06, z))
                c.tree(st["tree"], (x, 0, z), rng.uniform(4, 7), rng.randint(1, 1 << 30), folder == "r4")
                if rng.random() < 0.3:
                    wd.put(c, "prop_market_stall", x + 2.5, z - 2.5, rng.uniform(0, 360), WOOD)
        else:
            if free(x, z, 5, 4, 0.6):
                c.block((10, 0.1, 8), (x, 0.08, z), ASPHALT)
                c.prop("prop_car_rusted", (x, 0.1, z), (4, 1.45, 2.0), w.STONE, rot_y=rng.choice((0, 180)) + rng.uniform(-10, 10))
    # Street lamps every 24 m on alternating sides.
    for (x0, z0, x1, z1) in streets:
        horizontal = z0 == z1
        lo, hi = (min(x0, x1), max(x0, x1)) if horizontal else (min(z0, z1), max(z0, z1))
        v = math.ceil((lo + 6) / 24.0) * 24.0
        while v <= hi - 6:
            side = 1 if int(v / 24) % 2 == 0 else -1
            off = side * (ROAD_W / 2 + WALK_W - 0.6)
            px, pz = (v, z0 + off) if horizontal else (x0 + off, v)
            if abs(px) > plaza + 2 or abs(pz) > plaza + 2:
                c.decor("lamp", (px, 0.14, pz), st["lamp"], rot_y=(90 if side > 0 else 270) if horizontal else (180 if side > 0 else 0),
                        seed=rng.randint(1, 99999))
            v += 24.0
    # A few parked wrecks.
    for _ in range(5):
        s = rng.choice(streets)
        horizontal = s[1] == s[3]
        t = rng.choice((-1, 1)) * rng.uniform(plaza + 8, CITY_HALF - 8)
        off = rng.choice((-1, 1)) * (ROAD_W / 2 - 1.5)
        px, pz = (t, s[1] + off) if horizontal else (s[0] + off, t)
        if abs(px) < plaza + 3 and abs(pz) < plaza + 3:
            continue
        c.prop("prop_car_rusted", (px, 0, pz), (4, 1.45, 2.0), w.STONE, rot_y=(90 if horizontal else 0) + rng.uniform(-8, 8))
    # Plaza: waystone, the well, market stalls, benches, trees, townsfolk.
    w.waystone(c, way_id, (0, 0, 8))
    wd.put(c, "prop_well", 0, -6, 0, w.STONE)
    for i, (x, z, r) in enumerate([(-9, -9, 45), (9, -9, -45), (-9, 9, 135), (9, 9, -135)]):
        c.tree(st["tree"], (x, 0, z), rng.uniform(5, 7), seed * 10 + i, folder == "r4")
    for i, (x, z, r) in enumerate([(-6, 11, 180), (6, 11, 180), (-11, -3, 90), (11, -3, -90)]):
        wd.put(c, "prop_market_stall", x, z, r, WOOD)
    for i, p in enumerate([(-12, 0, 12), (12, 0, 12), (-12, 0, -12), (12, 0, -12)]):
        c.decor("lamp", p, st["lamp"], rot_y=i * 90.0, seed=40 + i)
    c.decor("banner", (-3, 0, -12), st["lamp"])
    c.decor("banner", (3, 0, -12), st["lamp"])
    for i, nid in enumerate(npcs):
        c.npc(nid, ((-4, 0, 3), (4, 0, -1))[i % 2], (200, 160)[i % 2])
    town_wall(c, CITY_HALF + 4, CONCRETE, gates, lamp=st["lamp"], banner=st["lamp"])
    c.label(name, (0, 14, 0), 72)


# --- villages --------------------------------------------------------------------------------

def _adobe(c, rng, x, z, yaw, color):
    """Desert house: thick walls, flat roof with a low parapet, a dark doorway."""
    wdt, dep, h = rng.uniform(6, 9), rng.uniform(5, 7), rng.uniform(3.6, 5)
    c.block((wdt, h, dep), (x, h / 2, z), color, rot_y=yaw)
    c.block((wdt + 0.4, 0.5, dep + 0.4), (x, h + 0.25, z), color, rot_y=yaw)
    fx, fz = -math.sin(math.radians(yaw)), -math.cos(math.radians(yaw))
    c.block((1.4, 2.2, 0.3), (x + fx * (dep / 2 + 0.05), 1.1, z + fz * (dep / 2 + 0.05)), "Color(0.12, 0.1, 0.1, 1)", rot_y=yaw)


def _stilt_house(c, rng, x, z, yaw):
    """Fisher hut on posts over the water, with a plank walk to the shore."""
    h = 2.2
    for sx in (-1, 1):
        for sz in (-1, 1):
            c.block((0.35, h, 0.35), (x + sx * 2.6, h / 2, z + sz * 2.2), w.BARK)
    c.block((6.2, 0.3, 5.4), (x, h, z), w.BARK)
    c.block((5.6, 3.0, 4.8), (x, h + 1.65, z), WOOD, rot_y=yaw)
    c.block((6.4, 0.4, 5.6), (x, h + 3.35, z), ROOF, rot_y=yaw)


VILLAGE_HOUSES = {
    "r2": ["bld_glade_hut", "bld_cottage_blue_tile", "bld_bakery", "bld_forge_shed", "bld_glade_hut", "bld_cottage_blue_slate"],
    "r4": ["bld_cottage_blue_slate", "bld_smithy", "bld_cottage_blue_tile", "bld_forge_shed", "bld_cottage_blue_slate", "bld_house_large"],
}


def village(c, folder, seed, name, way_id, npcs, at):
    st = REGIONS[folder]
    rng = random.Random(seed)
    c.block((128, 1, 128), (0, -0.5, 0), st["ground"])
    flat_town(c, 70)
    # Dirt paths crossing at the green.
    c.block((96, 0.06, 4.5), (0, 0.03, 0), DIRT)
    c.block((4.5, 0.06, 96), (0, 0.03, 0), DIRT)
    # Houses face the two paths (north / south of the lane, west / east of the road).
    spots = [(-34, -14, 0), (-14, -15, 0), (16, -15, 0), (34, -14, 0),
             (-34, 15, 180), (-14, 16, 180), (16, 16, 180), (34, 15, 180),
             (-13, -35, 90), (-13, 32, 90), (13, -35, -90), (14, 33, -90)]
    if folder in VILLAGE_HOUSES:
        houses = VILLAGE_HOUSES[folder]
        for i, (x, z, r) in enumerate(spots):
            wd.put(c, houses[i % len(houses)], x, z, r + rng.uniform(-6, 6), ROOF)
            if i % 3 == 0:
                c.decor("crate", (x + 5.5, 0, z + (3 if z < 0 else -3)), seed=260 + i)
    elif folder == "r3":
        for i, (x, z, r) in enumerate(spots):
            _adobe(c, rng, x, z, r, BLD["r3"])
        for i, (x, z, r) in enumerate([(-7, 8, 180), (-2, 8, 180), (3, 8, 180), (8, 8, 180)]):
            wd.put(c, "prop_market_stall", x, z, r, WOOD)
    elif folder == "r5":
        c.block((110, 0.2, 26), (0, 0.05, -26), w.POND, solid=False)
        for i, x in enumerate((-36, -18, 0, 18, 36)):
            _stilt_house(c, rng, x, -30, 0)
            c.block((1.6, 0.25, 12), (x, 0.35, -18), w.BARK)
        for i, (x, z, r) in enumerate([(-34, 18, 160), (-14, 20, 180), (16, 20, 180), (34, 18, -160)]):
            wd.put(c, "bld_pavilion_blue", x, z, r, ROOF)
        for x in (-27, -9, 9, 27):
            c.block((10, 0.25, 1.4), (x, 2.3, -30), w.BARK)
        wd.put(c, "prop_bridge_wood", 0, -12, 0, WOOD)
    elif folder == "r6":
        tents = ["camp_tent_frontier", "camp_tent_dome", "camp_tent_hide", "bld_refugee_tent", "camp_tent_frontier", "camp_tent_dome"]
        for i, (x, z, r) in enumerate(spots):
            tent = tents[i % len(tents)]
            size = ga.CAMP_TENT_SIZE.get(tent, (4.2, 3.2, 3.7))
            c.prop(tent, (x * 0.85, 0, z * 0.85), size, m11.RIFT, rot_y=r + rng.uniform(-20, 20))
        for i in range(8):
            a = i / 8 * math.tau
            c.decor("lantern", (math.cos(a) * 16, 0, math.sin(a) * 16), st["lamp"], seed=300 + i)
    # The green: well, fire, lanterns, townsfolk.
    wd.put(c, "prop_well_dark" if folder in ("r5", "r6") else "prop_well", 0, -7, 0, w.STONE)
    c.decor("campfire", (6, 0, -4))
    for i, p in enumerate([(-8, 0, 6), (8, 0, 6), (-8, 0, -12), (8, 0, -12)]):
        c.decor("lantern", p, st["lamp"], seed=200 + i)
    for i, p in enumerate([(-14, 0, -6), (-13, 0, -7.5), (14, 0, 10)]):
        c.decor("barrel" if i % 2 else "crate", p, seed=220 + i)
    w.waystone(c, way_id, (0, 0, 6))
    for i, nid in enumerate(npcs):
        c.npc(nid, ((-4, 0, 2), (5, 0, -3))[i % 2], (200, 150)[i % 2])
    # Fields (forest and snow villages): rows of crops behind the houses.
    if folder in ("r2", "r4", "r3"):
        crop = FIELD if folder != "r4" else "Color(0.35, 0.5, 0.3, 1)"
        for fx in (-1, 1):
            for row in range(5):
                c.block((14, 0.7, 1.2), (fx * 40, 0.35, 36 + row * 3.0), crop, solid=False)
            for i in range(5):
                c.decor("fence", (fx * 40 - 6 + i * 3.0, 0, 31), seed=240 + i + (fx + 1) * 10)
    # Trees around, outside the palisade.
    for i in range(14):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(54, 60)
        c.tree(st["tree"], (math.cos(a) * r, 0, math.sin(a) * r), rng.uniform(7, 12), seed * 7 + i, folder == "r4")
    # Palisade with gaps on the paths.
    half = 50.0
    gates = gate_sides(at)
    for side in "nsew":
        horizontal = side in "ns"
        fixed = -half if side in "nw" else half
        v = -half + 1.6
        while v < half - 1.0:
            if side in gates and abs(v) < 6.0:
                v += 3.1
                continue
            p = (v, 0, fixed) if horizontal else (fixed, 0, v)
            c.decor("palisade", p, rot_y=0 if horizontal else 90, seed=rng.randint(1, 99999))
            v += 3.1
        if side in gates:
            for sign in (-1, 1):
                gx, gz = ((sign * 7.0, fixed) if horizontal else (fixed, sign * 7.0))
                c.decor("banner", (gx, 0, gz), st["lamp"])
    c.label(name, (0, 11, -16), 64)


# --- landmarks -------------------------------------------------------------------------------

def landmark(c, folder, seed, name, level):
    st = REGIONS[folder]
    rng = random.Random(seed)
    c.block((128, 1, 128), (0, -0.5, 0), st["ground"])
    pack = st["enemies"]
    if folder == "r2":
        wd.put(c, "landmark_treehouse_village", 0, -6, 20, WOOD)
        for i in range(8):
            a = i / 8 * math.tau
            c.tree("oak", (math.cos(a) * 26, 0, -6 + math.sin(a) * 26), rng.uniform(12, 16), seed + i)
        c.grass("Color(0.26, 0.5, 0.26, 1)", 20000, seed)
        top_y = 0.0
    elif folder == "r3":
        wd.put(c, "landmark_dune_plateau", 0, -4, 0, w.DUNE)
        wd.put(c, "landmark_crimson_altar", 0, -4, 0, w.STONE, y=3.0)
        for i in range(10):
            s = (rng.uniform(10, 20), rng.uniform(2, 4), rng.uniform(10, 20))
            p = (rng.uniform(-54, 54), s[1] / 2, rng.uniform(-54, 54))
            if abs(p[0]) > 24 or abs(p[2]) > 24:
                c.block(s, p, w.DUNE, rot_y=rng.uniform(0, 90))
        top_y = 3.0
    elif folder == "r4":
        for i, (x, z, s) in enumerate([(0, -8, 2.2), (-14, 6, 1.4), (15, 2, 1.6), (-4, 20, 1.1)]):
            wd.put(c, "rock_spire", x, z, rng.uniform(0, 360), m11.ROCK, scale=s)
        for i in range(12):
            s = (rng.uniform(3, 7), rng.uniform(4, 12), rng.uniform(3, 7))
            p = (rng.uniform(-50, 50), s[1] / 2, rng.uniform(-50, 50))
            if abs(p[0]) > 22 or abs(p[2]) > 22:
                c.block(s, p, m11.ICE, rot_y=rng.uniform(0, 90))
        top_y = 0.0
    elif folder == "r5":
        c.block((70, 0.2, 60), (0, 0.05, 0), w.POND, solid=False)
        # Belltower half sunk in a flooded square: walls, a bell frame, steps up.
        c.room((0, 0, -6), (14, 14), 18, m11.SHELF, "s", 4.0)
        c.block((14.6, 0.6, 14.6), (0, 18.3, -6), m11.WATERSTONE)
        c.block((4, 3, 4), (0, 20.1, -6), m11.SHELF)
        for i in range(9):
            c.block((3, 0.5, 2.4), (-4 + (i % 3) * 4, 1 + i * 1.9, -1.5 - (i // 3) * 3.5), m11.WATERSTONE)
        top_y = 0.0
    else:
        # A floating isle in light gravity, reached by drifting stepping stones.
        m11.scripted(c, "gravity", "Area3D", (0, 14, -6), "size = Vector3(48, 34, 48)\ngravity_factor = 0.35\n")
        wd.put(c, "landmark_sky_isle", 0, -6, 0, m11.RIFT, y=16.0)
        for i in range(9):
            a = i * 0.8
            c.block((3.5, 0.6, 3.5), (12 * math.cos(a), 1.8 + i * 1.7, -6 + 12 * math.sin(a)), m11.RIFT)
        for i in range(6):
            p = (rng.uniform(-50, 50), 0, rng.uniform(-50, 50))
            if abs(p[0]) > 20 or abs(p[2]) > 20:
                c.tree("crystal", p, rng.uniform(3, 6), seed + i)
        top_y = 0.0
    c.chest(f"{folder}_landmark_cache", (3, top_y, 8), "treasure", level)
    for i in range(5):
        a = i / 5 * math.tau + 0.4
        c.spawner(pack[i % 2], (math.cos(a) * 18, 0.3, 6 + math.sin(a) * 18), 60.0, level + 2)
    c.label(name, (0, 26 if folder in ("r2", "r6") else 16, -6), 64)


# --- wilds -----------------------------------------------------------------------------------

def wilds(folder, x, z):
    """The region's own filler, then a supply cache now and then."""
    st = REGIONS[folder]
    seed = x * 31 + z * 7 + 500
    enemy = st["enemies"][(x + z) % 2]

    def build(c):
        if folder == "r2":
            w.forest_filler(c, seed, enemy)
        elif folder == "r3":
            w.desert_filler(c, seed, enemy)
        elif folder == "r4":
            m11.snow_filler(c, seed, enemy)
        elif folder == "r5":
            m11.water_filler(c, seed, enemy)
        else:
            m11.rift_filler(c, seed, enemy)
        rng = random.Random(seed)
        # A fourth monster: the ring is busier than the core.
        c.spawner(st["enemies"][(x + z + 1) % 2], (rng.uniform(-40, 40), 0.3, rng.uniform(-40, 40)))
        if (x + 2 * z) % 3 == 0:
            c.chest(f"{folder}_wild_{x}_{z}", (rng.uniform(-30, 30), 0, rng.uniform(-30, 30)), "supply",
                    ring_level(folder, x * 128, z * 128))
    return build


# --- regions ---------------------------------------------------------------------------------

def core_layouts():
    return {
        "r2": ({(0, 0): w.glade, (1, 0): w.root_shrine, (0, -1): w.fog_lake},
               lambda c, x, z: w.forest_filler(c, x * 13 + z * 5 + 3, "thorn_stalker" if (x + z) % 2 == 0 else "moss_brute",
                                               "r3_oasis" if (x, z) == (1, -1) else None)),
        "r3": ({(0, 0): w.oasis, (1, 0): w.colonnade, (0, -1): w.storm_dune},
               lambda c, x, z: w.desert_filler(c, x * 17 + z * 3 + 9, "dune_scuttler" if (x + z) % 2 == 0 else "sand_wraith",
                                               "r4_lodge" if (x, z) == (1, -1) else None)),
        "r4": ({(0, 0): m11.lodge, (1, 0): m11.mirror_temple, (0, -1): m11.summit},
               lambda c, x, z: m11.snow_filler(c, x * 19 + z * 7 + 4, "frost_yeti" if (x + z) % 2 == 0 else "ice_wyvernling",
                                               "r5_village" if (x, z) == (1, -1) else None)),
        "r5": ({(0, 0): m11.village, (1, 0): m11.library, (0, -1): m11.forbidden_archive},
               lambda c, x, z: m11.water_filler(c, x * 23 + z * 11 + 2, "drowned_scribe" if (x + z) % 2 == 0 else "ink_wraith",
                                                "r6_edge" if (x, z) == (1, -1) else None)),
        "r6": ({(0, 0): m11.rift_edge, (1, 0): m11.inverted_tower, (0, -1): m11.erased_city},
               lambda c, x, z: m11.rift_filler(c, x * 29 + z * 13 + 6, "void_hollow" if (x + z) % 2 == 0 else "rift_stalker")),
    }


def edges(c, x, z, color):
    """Border walls on the outside of the 5x5 map."""
    if x == -GRID:
        c.block((1, 6, 128), (-HALF, 3, 0), color)
    if x == GRID:
        c.block((1, 6, 128), (HALF, 3, 0), color)
    if z == -GRID:
        c.block((128, 6, 1), (0, 3, -HALF), color)
    if z == GRID:
        c.block((128, 6, 1), (0, 3, HALF), color)


def build_region(folder):
    st = REGIONS[folder]
    layout, filler = core_layouts()[folder]
    built = {}
    for x in range(-GRID, GRID + 1):
        for z in range(-GRID, GRID + 1):
            c = ga.Chunk(f"Chunk_{x}_{z}")
            c.origin = (x * 128.0, z * 128.0)
            outer = max(abs(x), abs(z)) > CORE
            if not outer:
                builder = layout.get((x, z))
                if builder:
                    builder(c)
                else:
                    filler(c, x, z)
            else:
                c.level_at = lambda gx, gz, f=folder: ring_level(f, gx, gz)
                level = ring_level(folder, x * 128, z * 128)
                if (x, z) == st["city"][0]:
                    city(c, folder, 1000 + x * 7 + z, st["city"][1], st["city"][2], st["city"][3], (x, z))
                elif (x, z) == st["village"][0]:
                    village(c, folder, 2000 + x * 7 + z, st["village"][1], st["village"][2], st["village"][3], (x, z))
                elif (x, z) == st["landmark"][0]:
                    landmark(c, folder, 3000 + x * 7 + z, st["landmark"][1], level)
                else:
                    wilds(folder, x, z)(c)
            edges(c, x, z, st["rock"])
            built[(x, z)] = c
    style, amp, seed, outcrop, count, skip = w.TERRAIN[folder]
    ga.finish_region(built, folder, style, amp, seed, outcrop, count, skip)


# --- data ------------------------------------------------------------------------------------

def register_data():
    for k in list(w.ENEMIES) + list(m11.ENEMIES):
        ga.DATA[k] = w.enemy_path(k)
    for k in list(w.GATES) + list(m11.GATES):
        ga.DATA[k] = f"res://data/gates/{k}.tres"
    for k in list(w.NPCS) + list(m11.NPCS) + list(TOWNSFOLK):
        ga.DATA[k] = f"res://data/dialogs/{k}.tres"


def write_townsfolk():
    for nid, (key, color) in TOWNSFOLK.items():
        lines = [f"DLG_{nid.upper()}_1", f"DLG_{nid.upper()}_2"]
        w.write(f"data/dialogs/{nid}.tres", w.npc_tres(nid, (key, color, lines)))


def _vec(x, y, z):
    return "Vector3(%g, %g, %g)" % (x, y, z)


def patch_region_data(folder):
    """Adds the new waystones / Gate spots and chunk_radius to the existing region .tres."""
    st = REGIONS[folder]
    path = f"data/regions/{st['rid']}.tres"
    text = open(path).read()
    (cx, cz), _, cway, _ = st["city"]
    (vx, vz), _, vway, _ = st["village"]
    ways = {cway: (cx * 128, 0, cz * 128 + 8), vway: (vx * 128, 0, vz * 128 + 6)}
    m = re.search(r"waystones = Dictionary\[StringName, Vector3\]\(\{(.*)\}\)", text)
    entries = [e.strip() for e in re.split(r",\s*(?=&\")", m.group(1)) if e.strip()]
    keep = [e for e in entries if not any(e.startswith(f'&"{k}"') for k in ways)]
    for k, v in ways.items():
        keep.append(f'&"{k}": {_vec(*v)}')
    text = text[:m.start(1)] + ", ".join(keep) + text[m.end(1):]
    m = re.search(r"gate_points = PackedVector3Array\(([^)]*)\)", text)
    nums = [float(v) for v in m.group(1).split(",") if v.strip()]
    pts = [tuple(nums[i:i + 3]) for i in range(0, len(nums), 3)]
    for (gx, gz) in st["gates"]:
        p = (float(gx * 128), 0.0, float(gz * 128))
        if p not in pts:
            pts.append(p)
    text = text[:m.start(1)] + ", ".join("%g, %g, %g" % p for p in pts) + text[m.end(1):]
    text = re.sub(r"max_world_gates = \d+", "max_world_gates = 3", text)
    if "chunk_radius" not in text:
        text = text.replace("max_world_gates = 3", "max_world_gates = 3\nchunk_radius = 2")
    open(path, "w").write(text)


def main():
    register_data()
    write_townsfolk()
    for folder in REGIONS:
        build_region(folder)
        patch_region_data(folder)
    print("region towns written")


if __name__ == "__main__":
    main()
