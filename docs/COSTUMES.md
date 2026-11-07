# Adding costumes & unique gear (owner guide)

Costumes are items in the **Costume** slot (Codex → Inventory). They are purely cosmetic.
Legendary / Mythic gear can also carry its own model the same way.

## 1. Export the model
- Format: **GLB** (textures embedded). FBX also works.
- Scale in metres, the piece modelled around a character ~1.75 m tall.
- Model it in the **local space of one body part** (e.g. a crown around the head, wings behind
  the chest). Origin = the point where it attaches.
- Keep it light: ≤ 15k triangles per piece, textures ≤ 2048².

## 2. Put it in the project
`assets/costumes/<costume_id>/<costume_id>.glb`

## 3. Create the item
Copy `data/items/costume_wings_of_dawn.tres` to `data/items/<costume_id>.tres` and edit:

| Field | Meaning |
|---|---|
| `id` | same as the file name |
| `display_name`, `description` | shown in the inventory |
| `rarity` | 0 Common · 1 Uncommon · 2 Rare · 3 Epic · **4 Legendary** · **5 Mythic** |
| `slot = 11`, `kind = 9` | Costume slot / kind (keep) |
| `visual_scene` | `res://assets/costumes/<id>/<id>.glb` |
| `visual_joint` | body part: `head`, `neck`, `chest`, `spine`, `hips`, `clav_r/l`, `arm_r/l`, `fore_r/l`, `hand_r/l`, `thigh_r/l`, `shin_r/l`, `foot_r/l` |
| `visual_offset`, `visual_rotation_deg`, `visual_scale` | fine placement |
| `hides_gear = true` | hide the armour pieces while worn (full outfits) |

Without a model, `visual_style` gives a built-in look: `wings`, `halo`, `cape`.

## 4. Try it
In game: `~` → `equip <costume_id>`. `gearup 5` puts Mythic gear in every slot.

Full-body outfits that bend with the body (skinned to the skeleton) come with the VRoid base
body; send those as GLB with the armature included.
