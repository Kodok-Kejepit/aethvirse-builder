"""Town / landmark dressing with the owner's imported models (Big Phase 2).

Used by gen_ashfall_chunks.py, gen_m9_world.py and gen_m11_world.py. Every piece is an
asset slot (PropInstance): until a model is imported the game shows a graybox block of the
footprint below, so layouts stay valid either way.
"""
import math
import random

WOOD = "Color(0.45, 0.32, 0.22, 1)"
STONE = "Color(0.55, 0.53, 0.5, 1)"
ROOF = "Color(0.25, 0.35, 0.6, 1)"
DARK = "Color(0.2, 0.18, 0.24, 1)"

# id: (width, height, depth) in metres — the slot size; models are scaled to the height.
SIZES = {
    "bld_glade_hut": (6.3, 6, 6.3),
    "bld_cottage_blue_tile": (9.8, 7.5, 9.9),
    "bld_cottage_blue_slate": (10.2, 6.5, 7.1),
    "bld_pavilion_blue": (9.9, 7, 7.9),
    "bld_bakery": (6.3, 8, 9.0),
    "bld_church": (11, 16, 15),
    "bld_house_large": (16, 9, 16),
    "bld_smithy": (8.2, 9, 10),
    "bld_forge_shed": (7.9, 4.5, 7.9),
    "prop_market_stall": (3.7, 3.2, 1.8),
    "prop_well": (2.9, 3.2, 2.5),
    "prop_well_dark": (3.2, 2.0, 2.5),
    "prop_post_car": (4.0, 1.5, 2.5),
    "prop_bridge_wood": (7.9, 2.2, 3.5),
    "prop_treasure_chest": (1.7, 1.1, 1.2),
    "landmark_waystone_arch": (5.4, 4.5, 5.3),
    "landmark_ritual_circle": (5.9, 3.5, 6.0),
    "landmark_crimson_altar": (6.8, 4, 6.8),
    "landmark_nexus_altar": (6.9, 4, 6.9),
    "landmark_ruined_plaza": (9.7, 3, 9.1),
    "landmark_lantern_temple": (26, 22, 34),
    "landmark_sky_isle": (24, 14, 24),
    "landmark_crystal_tree": (15, 18, 19),
    "landmark_dune_plateau": (32, 3, 30),
    "landmark_hollow_castle": (44, 40, 43),
    "landmark_dark_grove": (16, 14, 21),
    "landmark_wyrm_relic": (8.3, 8, 8.6),
    "landmark_treehouse_village": (18, 22, 18),
    "landmark_root_shrine": (15, 16, 19),
    "pillar_rooted": (3.2, 6, 3.3),
    "pillar_astral": (2.4, 6, 2.4),
    "pillar_monolith": (2.0, 7, 2.0),
    "pillar_obsidian": (1.7, 7, 1.7),
    "rock_spire": (8.7, 9, 7.2),
    "rock_pile": (3.7, 2.5, 3.4),
    "rock_slab_a": (4.6, 2.2, 4.4),
    "rock_slab_b": (3.6, 2.0, 7.0),
    "rock_isle_dark": (14, 4, 15),
}


def put(c, pid, x, z, rot=0.0, color=STONE, y=0.0, scale=1.0):
    w, h, d = SIZES[pid]
    c.prop(pid, (x, y, z), (w * scale, h * scale, d * scale), color, rot_y=rot)


def scatter(c, seed, ids, count, inner=24.0, outer=58.0, scale=(0.8, 1.3), color=STONE):
    """Random pieces in the ring inner..outer around the chunk centre."""
    rng = random.Random(seed)
    placed = 0
    tries = 0
    while placed < count and tries < count * 20:
        tries += 1
        x, z = rng.uniform(-outer, outer), rng.uniform(-outer, outer)
        if abs(x) < inner and abs(z) < inner:
            continue
        put(c, rng.choice(ids), x, z, rng.uniform(0, 360), color, scale=rng.uniform(*scale))
        placed += 1


# --- towns --------------------------------------------------------------------------------

def camp(c):
    """Ashfall refugee camp: a scrap market, a well, overgrown wrecks."""
    put(c, "prop_market_stall", -12, -2, 90, WOOD)
    put(c, "prop_market_stall", -12, 3, 90, WOOD)
    put(c, "prop_well", -15, 26, 15)
    put(c, "prop_post_car", -30, 4, 70, DARK)
    put(c, "landmark_ruined_plaza", 34, -34, 20)
    for i, (x, z) in enumerate([(-40, -40), (42, 30), (-44, 34)]):
        c.tree("dead", (x, 0, z), 8 + i, 700 + i)
    scatter(c, 1101, ["rock_pile", "rock_slab_a", "rock_slab_b"], 7, inner=32)


def glade(c):
    """Mossgate Glade grows into a forest village around the four huts."""
    put(c, "bld_cottage_blue_tile", -36, -8, 75, ROOF)
    put(c, "bld_bakery", 34, -6, -90, ROOF)
    put(c, "bld_cottage_blue_slate", -32, 24, 120, ROOF)
    put(c, "prop_well", -22, 3, 30)
    put(c, "prop_market_stall", 22, 4, -90, WOOD)
    put(c, "prop_market_stall", 22, 9, -90, WOOD)
    put(c, "landmark_treehouse_village", -42, -42, 35, WOOD)
    # Floating island far above the village (no collision: scenery).
    put(c, "landmark_sky_isle", 10, -70, 20, STONE, y=48)


def root_shrine(c):
    put(c, "landmark_root_shrine", 0, -50, 0, WOOD)
    put(c, "pillar_rooted", -10, 6, 0)
    put(c, "pillar_rooted", 10, 6, 180)


def fog_lake(c):
    put(c, "landmark_ritual_circle", 34, -22, 200)
    put(c, "landmark_crystal_tree", -42, 34, 40)
    put(c, "prop_bridge_wood", 0, -36, 90, WOOD)


def oasis(c):
    """Red Oasis bazaar: stalls along the water, a dark well, the crimson altar."""
    for i, (x, z, r) in enumerate([(-8, -2, 0), (-3, -2, 0), (3, -2, 0), (8, -2, 0), (-24, -14, 90), (24, -14, -90)]):
        put(c, "prop_market_stall", x, z, r, WOOD)
    put(c, "prop_well_dark", 0, 18, 0, DARK)
    put(c, "landmark_crimson_altar", -36, -40, 30, DARK)


def storm_dune(c):
    put(c, "landmark_dune_plateau", 36, -34, 20, STONE)
    scatter(c, 3303, ["rock_slab_a", "rock_slab_b", "rock_pile"], 6, inner=18)


def colonnade_pillars(c, xs, z, heights):
    for x, h in zip(xs, heights):
        c.prop("pillar_monolith", (x, 0, z), (2, h, 2), STONE)


def lodge(c):
    """Hunter's Lodge: stone cottages, the smithy and an old chapel in the snow."""
    put(c, "bld_cottage_blue_slate", -22, -16, 20, ROOF)
    put(c, "bld_smithy", 22, -18, -25, WOOD)
    put(c, "bld_glade_hut", -14, 16, 120, WOOD)
    put(c, "bld_church", 0, -40, 0, STONE)
    put(c, "bld_forge_shed", 20, 12, -110, WOOD)


def fisher_village(c):
    """Fisher Village: lakeside pavilions, a footbridge and the lantern temple on its cliff."""
    for i, (x, z, r) in enumerate([(-16, -10, 15), (16, -10, -15), (-16, 16, 165), (16, 16, -165)]):
        put(c, "bld_pavilion_blue", x, z, r, ROOF)
    put(c, "prop_bridge_wood", 0, 30, 0, WOOD)
    put(c, "landmark_lantern_temple", 0, -48, 180, STONE)


def rift_edge(c):
    put(c, "landmark_nexus_altar", 0, -22, 0, DARK)
    for i in range(6):
        a = i / 6 * math.tau
        c.prop("pillar_obsidian", (math.cos(a) * 26, 0, -6 + math.sin(a) * 26), (1.7, 6 + (i % 3) * 2, 1.7), DARK)
    scatter(c, 6606, ["rock_spire", "rock_isle_dark"], 5, inner=34)
    put(c, "landmark_sky_isle", -30, 40, 140, STONE, y=36, scale=0.8)


def throne(c):
    put(c, "landmark_hollow_castle", 0, -56, 0, DARK, y=10)
    for x in (-14, 14):
        for z in (-16, 4):
            put(c, "pillar_astral", x, z, 0, DARK)
