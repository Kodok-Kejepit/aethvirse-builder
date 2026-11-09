# World models from Meshy (owner guide)

## How to add one
1. Make the model in Meshy (text-to-3D, your own prompt). Download **GLB**.
2. Name the file with the **id** from the tables below, e.g. `bld_refugee_tent.glb`.
3. Put it in `~/Unduhan/assets/`.
4. Run `tools/import_props.sh` (or ask Claude). It decimates, scales, sets the base on the
   ground, makes collision and textures, and the game uses it everywhere that id appears.
   Until a file exists the game shows the current graybox / procedural version.

Prompt style to keep everything consistent:
`stylized anime fantasy, hand-painted texture, clean shapes, game asset, single object`

Size and triangle budget come from the prefix (override in `assets/props_manifest.csv`:
`id,height_m,collision,max_tris`):

| Prefix | Default height | Max triangles |
|---|---|---|
| `prop_` | 1 m | 5 000 |
| `tree_` | 9 m | 8 000 |
| `rock_` | 3 m | 4 000 |
| `bld_` / `r1_`…`r7_` | 10 m | 25 000 |
| `gate_` | 6 m | 20 000 |
| `landmark_` | 12 m | 40 000 |
| `statue_` | 3 m | 30 000 |

Asset slots scale the model to the slot height automatically.

Huge Meshy files (millions of triangles) are shrunk first with
`tools/hero_pipeline/reduce_glb.py in.glb ~/Unduhan/assets/<id>.glb --tris 30000`
(numpy + meshoptimizer, low memory, keeps UVs) so the laptop never runs out of RAM.

## Imported so far
`r1_apartment_ruin_a` (Ashfall ruins), `prop_car_rusted`, `bld_refugee_tent`,
`landmark_overpass_cracked`, `weapon_sword_mythos` (item **Starfall, Eye of the Void**, Mythic),
`statue_starblade` (camp plaza).

## Ids the game already uses (priority order)

| Id | Where | Notes |
|---|---|---|
| `bld_refugee_tent` | Ashfall camp (5×) | canvas tent, ~6×3×5 m |
| `prop_lamp` | camps, overpass, villages | street lamp ~3.8 m, light added by the game |
| `prop_campfire` | camps | logs + stones only, the game adds the fire |
| `prop_crate`, `prop_barrel` | everywhere | |
| `prop_fence`, `prop_banner`, `prop_lantern` | camps / villages | fence ~3 m wide |
| `tree_oak`, `tree_pine`, `tree_palm`, `tree_dead`, `tree_crystal` | all regions | pine: snowy look fits Frostveil |
| `bld_glade_hut` | Mossgate Glade (4×) | forest hut ~6×5×6 m |
| `statue_starblade` | camp plaza | imported already (test) |

More slots (apartment ruins, Gate frames, waystones, shrines, tombs, bookshelves, the Hollow
Throne) get added as the models arrive — send them and Claude wires them in.


## Big batch (owner's downloads, `~/Unduhan/game/AETHVIRSE`)
Owner-picked Meshy models (own + Meshy community uploads). Pipeline:
1. `reduce_glb.py` shrinks every file (≤ 40k triangles, 1024 albedo). Meshy atlases are
   cut into thousands of UV islands, so very dense files cannot be simplified with their
   UVs; those use `--rebake`: the welded surface is simplified, gets a fresh UV atlas
   (xatlas) and a new albedo sampled from the original (scipy + xatlas in the tool venv).
2. The reduced file is linked as `<id>.glb` into `~/Unduhan/assets/owner2/` and imported
   with `tools/import_props.sh ~/Unduhan/assets/owner2`; sizes live in `assets/props_manifest.csv`.
3. Floor / wall models are photographed straight on by `tools/bake_surface_textures.gd`
   into tiling textures for Gate dungeons (`GateTheme`).

| Id prefix | Used by |
|---|---|
| `bld_*` | town houses (`tools/world_dressing.py`) |
| `prop_*` | market stalls, wells, lamp posts, barrels, campfire, bridge, treasure chest (sealed chests + mimic) |
| `landmark_*` | waystone arch, altars, lantern temple, sky isle, crystal tree, Hollow castle, ... |
| `pillar_*`, `wall_*`, `tile_*` | Gate dungeon theme per rank, colonnade |
| `rock_*`, `tree_dead` | scattered terrain dressing |
| `gate_celestial_frame` | frame around every Gate portal |
| `mob_<enemy id>` | replaces that enemy's procedural body (unrigged: whole-model breathing / gait bob / attack lean) |
| `npc_<dialog file>` | replaces that NPC's body (idle breathing) |
| `weapon_*` | item visuals |

Unrigged characters / monsters move as one piece. For real animation, rig them like the
Dragon Maiden (Meshy auto-rig or Mixamo) and send the FBX — `tools/import_rigged_hero.gd`.

## Generated for the game (Meshy, owner subscription)
- `mob_cinder_archer` — charred hooded archer with a bone bow (2026-11-09, 10 credits), reduced with `--rebake` to 20 k, imported at 10 k + LODs.
- `tunnel_viper`, `venom_matriarch` — Meshy serpents (2026-11-09), rigged by `tools/blender/rig_serpent.py` into `assets/creatures/<id>/<id>.glb`.
- `weapon_dagger_venomfang` — Meshy dagger (item Venomfang, Legendary).
