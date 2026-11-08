# Progress

## Big Phase 2 — Visuals (branch `p2-1-items-ui`, stacked on m12-polish)

### Done so far
- **Items:** procedural icons per item type on a rarity plate (Common grey · Uncommon green · Rare blue · Epic purple · Legendary orange · Mythic red with sparkles; ID names Biasa/Tak Biasa/Langka/Epik/Legenda/Mitos).
- **Inventory window:** equipment grid (incl. new **Costume** slot), 8-column bag grid sorted best-first (count, +upgrade, equipped dot), detail panel with big icon, rarity, stats, description and actions.
- **Hologram panels:** every Codex-style window has a deep-blue glass background with scanlines, sweep, glowing frame and corner brackets, and a quick power-on animation.
- **Loot on the ground:** floating icon + rarity disc; Rare+ light pillar, Epic+ sparkles, Legendary+ pulsing light.
- **Map:** Codex → Map shows the region painted from its geometry, fog of war (saved), waystones, roads, Gates (Red Gates in red), people, place names, your arrow, the vague secret tracker and % explored. A **minimap** sits under the clock.
- **Gear on the body:** helm circlet (wings at Epic, crown at Legendary), pauldrons + chest gem, bracers, greaves, pendant, rings, shield/orb, weapon sparks; rarity aura (Epic sparks, Legendary/Mythic ground ring).
- **Costumes:** cosmetic slot; demo costumes Starcloak (Epic), Wings of Dawn (Legendary), Halo of the Unwritten (Mythic). Owner costumes plug in via `docs/COSTUMES.md`.

- **Aim (owner request):** basic attacks and skills go where the camera looks (PC: the mouse cursor on the ground when it is free; a small crosshair shows when the mouse drives the camera). Soft aim assist pulls toward an enemy inside a 28° / 9 m cone; lock-on still wins. Settings → Controls → Attack aim switches back to movement direction.
- **Codex Status** rebuilt as cards and tables: character card with XP bar, attribute table (STR · Kekuatan · 70 · +), combat stats table, job card, one aligned row per skill (icon, name, Lv/MP/CD, description, +, slots). Inventory preselects the best item.
- **Environment:** world surface shader (noise variation, lighter grass/sand/snow tops, toon light), animated water, swaying foliage, MultiMesh grass in the forest (density by preset), procedural trees (oak, snowy pine, palm, dead, crystal), dynamic sky (clouds by weather, stars and moon at night, blue moonlight), ACES + bloom + grading.
- **VFX:** slash trails, element-coloured hit sparks, crit rings, skill/level-up rings, enemy death bursts, swirling Gate portals. Attack hitbox boxes only show with F3.
- **Creatures:** enemies and NPCs use procedural bodies by type (humanoid, quadruped, brute, wraith, wyvern, serpent) with glowing element eyes, gait/attack/flap/slither animation and tier sizes (elite 1.25×, boss 1.7×).
- **Dragon Maiden (phone):** the owner's clean remesh (15k tris) is the phone body.
- **Towns & buildings (p2-7-towns):** surface patterns by palette — building facades with a window grid that lights up at night, concrete/asphalt slabs with fine cracks and stains, striped tent canvas, brick on stone/rock walls, wood planks, rusted metal. Dressing: lamp posts, campfires (fire + flicker light), crates, barrels, fences, banners, lanterns in the Refugee Camp, overpass, Mossgate, Red Oasis, Hunter's Lodge, Fisher Village and Rift Edge. Lights glow at night and fade with distance (half distance on phones, no light shadows).
- **Animated Dragon Maiden (owner's Mixamo rig):** the hero now plays the owner's animations — Walking / Running / Lean_Forward_Sprint by speed, Regular_Jump for jump/fall (hip rise removed; physics lifts her), Weapon_Combo split into 4 swings by attack type (skills use the finisher), the combo's first frame as the ready stance. Dodge = fast sprint, hurt/death = tilt. Hair re-rigged: Meshy weighted the long hair to the arms, so it swung with the hands; `tools/import_rigged_hero.gd` now finds everything far from the body bones (hair, ribbons, the back dragon), gives it 10 bone chains hanging from the head with blended seams, and the game simulates them with SpringBoneSimulator3D (head/chest/hips/thigh colliders). Weapons, gear and trails follow the animated hands. Character select shows it too.
- 291 tests.

### How to test
- New game → character select: Dragon Maiden holds the Mythic sword in the combo stance, swings, hair sways. In game: walk/run/sprint (Shift), jump, light/heavy attacks, skill 1.
- Re-import after the owner re-exports: `godot --headless --path . -s tools/import_rigged_hero.gd -- <fbx> <albedo.png> res://assets/characters/dragon_maiden/rig dragon_maiden` (`ASC_HAIR_MASK=1` colours the hair chains for checking).
- `time 21:30` at the camp / `travel r3_oasis` at night / Ashfall apartments (west) for lit windows.
- `loot 3 5` / `droploot` / `gearup 4` / `equip costume_wings_of_dawn` / `codex map`.
- Attack while looking somewhere else than you walk; Settings → Arah serangan.
- `travel r2_glade` (grass/oaks), `r3_oasis` (palms/water), `r4_lodge` (pines/snow), `time 22:00` (stars).
- `spawn moss_brute 1`, `spawn sand_wraith 1`, `spawn ice_wyvernling 1`.

### Planned next (owner approved)
- **Sky Rift events** (reference: owner's Veo clip — swirling purple/blue vortex, lightning at the rim, light beams to the ground, purple light on clouds and city):
  1. *Codex penalty*: the sky cracks slowly in the last minutes before a failed Daily Quest; when time runs out it tears open and pulls the player into the Penalty Zone.
  2. *Dungeon Break*: a giant rift above the broken Gate, visible from afar; monsters pour out.
  3. *Rift Night*: rare scheduled event (e.g. every 7 game days at midnight) — whole sky full of rifts, rare monsters, better rewards, secrets that only exist that night.
- Night sky + moon polish; modern city + village per region with clear borders.

## M12 — Polish (branch `m12-polish`, stacked on m11-endgame) — end of Big Phase 1

### Done
- **Pause menu** (Esc / P / gamepad Start / ⏸ touch button): Resume, Save to slot 1–3, Load (slots + autosave, with class, level, playtime, date), Settings, Return to title, Quit (PC). Esc still just closes an open panel first. Settings moved off the Start button.
- **Audio:** placeholder music rendered by `tools/gen_audio.py` (numpy, original): a loop per region (7), Gate, boss and menu, crossfading on region/Gate change; boss fights switch to the boss track and back. SFX for swing, hit, crit, getting hurt, dodge, enemy death, pickup, skill, dragon roar, Gate entry, Gate cleared fanfare.
- **Localization audit test:** every strings.csv row has EN + ID, no duplicates, and every `&"KEY"` used in scripts/data exists (found and fixed a broken chapter-2 row).
- **Performance:** graybox blocks share one material per color and small blocks are culled beyond 40% of the platform view distance (Android Low ≈ 100 m); camp draw calls 148 → 122. The hero keeps the HD body on PC; its outline pass (2× triangles) starts at PC Medium.
- **Bug bash:** automated tour through all 7 regions, dynamic Gates, every Codex tab and a Gate run — no script errors.
- 266 tests.

### How to test
1. Esc (or ⏸ on the phone) → Save to slot 2 → Return to title → Continue / load it from the pause menu.
2. Listen: music changes between regions (`travel …`), in Gates and on a world boss; hits/dodges/pickups have sounds.

### Known limits
- Music/SFX are procedural placeholders (Big Phase 2 replaces them; ids stay).
- Enemy names and 3D place labels are English only.
- Difficulty levels (§15) are not added yet — waiting for the owner's choice.

## M11 — Regions 4–6 + endgame (branch `m11-endgame`, stacked on m10-jobs-shadows)

### Done
- **Frostveil Peaks (Lv 40–55):** Hunter's Lodge, Mirror Temple (cracked wall → Arena of Echoes with the secret boss **Echo King**), terraced Summit (secret in a snowstorm). Frost Yeti, Ice Wyvernling, world boss Glacier Colossus.
- **Sunken Archive (Lv 55–70):** Fisher Village, Great Library with a **tide** (water rises/falls every 12 game hours; the lower stacks open 12:00–18:00), Forbidden Archive sealed until the Echo King has answered → **Codex Umbra**. Drowned Scribe, Ink Wraith, world boss Captain Ink.
- **The Fracture (Lv 70–90):** Rift Edge, **Inverted Tower** inside a light-gravity zone (floating stones up to its crown), Erased City with a heavy-gravity patch. Void Hollow, Rift Stalker, world boss Rift Devourer.
- **Hidden Region — Hollow Throne:** a white ring appears at the prologue spot in Ashfall (south of the overpass) at **03:xx** for whoever holds the three keys (Echo King answered · Codex Umbra read · Fracture's heart). Inside: **The Unwritten** → **Vael's last question** → Ending A / B (20+ shadows) / C (Will ≥ 12; secrets found stand in for Will). Then back to Ashfall (post-game).
- **Shadow Sovereign chain:** Echo King's shadow joins the army automatically for the shadow line; reading the Codex Umbra unlocks Shadow Sovereign (Necromancer, Lv 60).
- **Red Gates** (Red Library, Red Rift): monsters +5 levels, gold ×3, dark-red ring "RED".
- **World boss bar:** open-world bosses show the big HP bar (with phases) when you get close.
- **Main story chapters 2–7** auto-start one after another (reach the region → defeat its boss); chapter 7 = Hollow Throne.
- Region roads continue: Dunes NE corner → Frostveil → (NE) → Archive → (NE) → Fracture.
- Weather carried into a region that has no such weather resets to clear.
- 264 tests.

### How to test
1. `travel r4_temple` / `r5_library` / `r6_tower` (unlocks + jumps).
2. Echo King: Mirror Temple → heavy-attack the cracked back wall → arena. Or `flag echo_king_answered` to skip.
3. Tide: `time 15:00` (low) vs `time 21:00` (high) at the Great Library.
4. Hollow Throne: `flag echo_king_answered`, `flag codex_umbra_read`, `flag fracture_heart`, `time 03:10`, `travel r1_overpass`, walk south to the white ring.

### Known limits
- Region secrets use simplified conditions (heavy attack / weather / time instead of element puzzles); full bible versions come with exploration elements.
- Ending choice 4 uses "secrets found" as Will; the real hidden Will stat is not implemented yet.
- Story chapters are objectives only (no cutscenes/dialogue beats yet).

## M10 — Job change & shadows (branch `m10-jobs-shadows`, stacked on m9-world)

### Done
- **Job Change trials:** the Codex offer now reads "Take the trial: <job>". It sends you into a trial Gate (Tier I: 3 rooms, Trial Warden; Tier II: 4 rooms, Trial Arbiter; enemies scale to you, no Double Gate). Beat the guardian → the job is granted. Dying restarts the trial; hidden jobs (Necromancer, Shadow Sovereign) skip it — their sealed mission is the trial.
- **Shadow ranks:** every shadow soldier earns XP from its own kills (1 + 4×enemy tier) and ranks up Soldier → Knight → Elite → Commander → Marshal (power ×1 → ×2.4). Elite+ cleave nearby enemies, Commander+ taunt (enemies prefer them), Marshal attacks 25% faster. Rank-ups show in the Codex; the Shadow Army tab lists rank and XP. Old saves get soldier ids automatically.
- 257 tests.

### How to test
1. `level 30` → Codex → Status → "Take the trial: …" (or `trial berserker`). Clear the trial Gate → job granted.
2. `job necromancer`, bind a few shadows, call them and let them fight; watch rank-ups in the Codex log.

## M9 — Open world expansion (branch `m9-world`, stacked on p2-test-heroine)

### Done
- **Regions as scenes:** Ashfall (Lv 1–10), **Verdant Hollow** (forest, Lv 10–25) and **Crimson Dunes** (desert, Lv 25–40), each 3×3 chunks of 128 m with its own sky/fog, weather table, NPCs, enemies, Gates, world boss and secrets. Save/load and Gate exits return to the right region.
- **Waystones:** glowing stones unlock when you walk past (Codex message); using one opens **Fast Travel** (all unlocked stones, grouped by region). **Road stones** (blue sign with →) link regions: Ashfall north-west corner → Verdant Glade → (Verdant north-east corner) → Red Oasis. A warning shows if you are far below the region level.
- **New enemies:** Thorn Stalker, Moss Brute, Rootheart Elder (boss) / Dune Scuttler, Sand Wraith, Crimson Burrower (boss). Elders/Burrowers also roam as world bosses (respawn 30 min).
- **Dynamic Gates:** every 2 game hours a region may open a Gate at one of its spots (max 2 per region; saved). Clearing it closes it.
- **Dungeon Break:** a dynamic Gate left alone for a game day breaks — the ring turns red ⚠ and a wave (4 + 2×rank monsters, your level) pours out. Kill them all → gold, XP, guild points, the Gate collapses.
- **Minions in combat:** enemies attack a minion when it is clearly closer than you; minions have their own HP (35% of yours) and vanish when they fall (shadow soldiers stay in the army).
- **Secrets (M9):** SEC-R2-07 (rotten roots behind the Root Shrine), SEC-R2-06 (Mistlake jetty, night + fog), SEC-R3-01 (lone gateway in a sandstorm), SEC-R3-09 (sealed tomb). Each has 2+ hints (NPCs, signs, notes).
- 251 tests.

### How to test
1. Ashfall: walk past the camp waystone; use it → Fast Travel list. Walk to the NW corner road stone → Verdant Hollow.
2. `~` → `travel` lists waystones; `travel r3_ruins` unlocks and jumps there.
3. `~` → `worldgate spawn` (twice for two), `worldgate list`, `worldgate break` → Dungeon Break next second.
4. `job summoner` + call familiars near enemies → they get attacked and can die.
5. Secrets: `weather fog` + `time 23:00` then stand at the end of the Mistlake jetty; `weather storm` at the Lone Gateway.

### Known limits
- Regions are separate scenes joined by road stones (short load), not one seamless map yet.
- Dynamic Gate spots are fixed per region (4); a spot can sit next to graybox blocks.
- World bosses have no big boss HP bar (only Gate bosses do).

## Big Phase 2 preview — test heroine (branch `p2-test-heroine`, stacked on m9-fixes-jobs)

### Done
- The player capsule is replaced by a procedural anime heroine (owner's reference: long blonde→pink hair, starry violet suit with gold filigree, pink sleeves, black feather crest, crimson sashes, heels). Built in code from primitives + toon shader + inverted-hull outline; no external assets.
- 20 poses, blended live from the player state: idle (breathing, weight shift), fidget after 7 s idle, walk / run / sprint cycles, jump / fall / landing crouch, dodge dash, slash / overhead / spin / thrust attacks, shoot (bow draw or staff bolt), skill cast, summon (instant skills), hurt, death (kneel → collapse), level-up victory. Attacking while moving keeps the walking legs.
- Hair (7 strands to the calves + 2 front locks) and sashes swing on springs: drag when running, float when falling, sway in idle.
- Weapon follows the class: sword (Vanguard), twin daggers (Phantom), staff (Arcanist), bow (Ranger).
- **Spirit dragon:** appears only when a skill is cast (never on basic attacks). Coils up around her, rears over her shoulder, strikes forward and dissolves into pink sparks; Ultimate = bigger, longer dragon.
- Rigid parts are baked per joint (≈3× fewer draw calls); phones skip the outline pass.
- 236 tests.

### How to test
1. Play normally: walk, run, sprint (hold dodge), jump, dodge, combo, heavy, skills, ultimate, get hit, die, level up (`level 5`).
2. `~` → `pose` lists poses; `pose run` freezes one; `pose auto` cycles all with captions; `pose off`.
3. `~` → `dragon` / `dragon ult` summons the dragon without a skill. `model graybox` / `model heroine` switches the body.
4. Scene `scenes/test/test_character.tscn` (F6): all poses side by side. Args: `--focus=<pose> --weapon=0..3 --yaw=<deg> --dragon(-ult) --turntable`.

### Update — owner's Meshy models
- New Game → class → **character**: *Starry Dragon Maiden* (long hair, spirit dragon on skills) or *Violet Starblade* (short hair, no dragon). Saved per game (`hero_id`).
- Owner's Meshy image-to-3D GLBs are imported with `tools/hero_pipeline/prep_hero.py` (dragon cut out of the Maiden mesh by colour, face -Z, 1.8 m, feet on 0) + `tools/import_hero.gd` (meshoptimizer decimation, auto-skin to the CharacterRig joints with smoothed weights). PC uses the HD mesh (~130–160k tris, 2–4K texture), phones the light one (~33–40k tris, 1K texture); `*_hi.*` is excluded from Android exports.
- Wide arm spreads are damped on imported bodies (fused sleeves/robes would stretch).
- Cheats: `pose …`, `dragon` (Maiden only), `model graybox|heroine`. Showcase: `--hero=<id> --lite`.

### Known limits
- Auto-skinning a fused statue: sleeves/robe still stretch a little on big arm moves; the Maiden's left hand stays near her cheek (sculpted that way); a few dragon fragments remain near her head. A proper rig (Meshy "Rig" or Mixamo) would fix all three.
- This is a primitive-built stand-in, not the final hero. The final look needs a real modelled/textured mesh (VRoid/Blender per §2) — see DECISIONS.
- The face is simple (eyes, brows, mouth only); no facial expressions. Hair can clip through the arms in extreme poses.

## Big Phase 1 — Systems (graybox). Active: owner feedback round + Job system (branch `m9-fixes-jobs`, stacked on m8 → … → m0)

### Done (m9-fixes-jobs)
- **Fixes from the phone playtest:** touching the joystick no longer attacks (touch = fake left click; mouse buttons are removed from gameplay actions on touch devices). Falling off a bridge / into a gap brings you back to the last safe ground (−10% HP, never lethal) instead of falling forever.
- **Combined actions:** steer while attacking (light 45%, heavy 20% of run speed), jump out of an attack after its combo window, attack and cast skills in the air.
- **Phone UI:** Inventory is its own window (bag button top, key **I**); the Codex keeps Status (stat points, skills, job), quests, journal, lore, log, system. Panels and fonts are 1.45× bigger on touch screens.
- **Settings** (⚙ button / **F10** / Codex → System / main menu): quality preset, FPS cap, 5 volume sliders, camera sensitivity, invert Y, camera distance, touch button size + opacity, language, damage numbers. Saved to `user://settings.cfg`.
- **Daily quests vary:** every day = 1 training task (attacks / dodges / run / skills) + 1 hunting task (kills / close a Gate from Lv 3) + 1 gathering task (pick up items / gather herbs / craft / use consumables).
- **Gates scale:** rooms = base + 1 per 5 levels + rank (max 12), more enemies per room every 20 levels, enemies never more than 2 levels below you. Low level stays short (3 rooms).
- **Double Gate:** ~35% of days a Gate hides a cracked wall (glows near you; the Codex hums when that room is cleared). Heavy attack breaks it → purple portal → a short, harder Gate with one strange rule (no skills or no potions) and a mystery box. A portal at its start and the exit at the end take you home; dying just respawns you at its start.
- **Job system:** Job Change I at Lv 30 (2 branches per class: Berserker/Guardian, Shadowblade/Trickster, Elementalist/Sage, Sharpshooter/Trapper) and Job Change II at Lv 60 (Warlord, Bastion, Nightreaper, Illusionist, Archmage, Oracle, Deadeye, Beastwarden). Codex → Status shows the offers; new job skills land on slots 3–4 and every active skill can be moved with the 1–4 / U buttons.
- **Summoner → Necromancer:** any class can become a **Summoner** at Lv 30 — weak (−10% attack), mana-hungry (skills cost 1.5×), one familiar wisp (two at skill Lv 5). A sealed mission turns it into the hidden **Necromancer** (Lv 35): *Rise, Echo* binds a freshly fallen enemy as a shadow soldier (chance by enemy tier, slots 3 → 30 with level), *Answer Me* calls the strongest shadows to fight. The **Shadow Army** Codex tab only exists on this line. Conjurer (Summoner II) and Shadow Sovereign (Necromancer II, gated behind the later MYSTERY_BIBLE chain) are in the data.
- 228 tests.

### How to test (m9-fixes-jobs)
1. Phone: joystick no longer attacks; ☰ = Codex, bag = Inventory, ⚙ = Settings. Try touch button size in Settings.
2. Jump off the overpass edge / a Gate corridor → you are put back on safe ground.
3. `~` → `gate double` → the hidden Gate is forced on: find the glowing cracked wall in a side wall, heavy attack, step into the purple ring.
4. `~` → `level 30` → Codex → Status → pick a job. Or `job summoner` / `job necromancer` (cheat sets level + flags).
5. Necromancer: kill something, press *Rise, Echo* (slot 4) next to it within 10 s; then *Answer Me* (slot 3). Codex → Pasukan Bayangan lists/releases soldiers.

### Not done yet / known limits
- Enemies ignore minions (they only target the player); minions do not take damage. Shadow ranks beyond Soldier/Knight/Marshal and per-shadow skills come later.
- Job change has no trial quest yet (direct from the Codex). Shadow Sovereign is not reachable yet (needs the R4/R5 chain).
- Daily quests from an old save on the same day may show the new task list with old progress mixed in (fixes itself next day).

## M8 — Other classes (branch `m8-classes`)

### Done (M8)
- Phantom, Arcanist, Ranger playable: own weapon combo graphs (dagger chain, staff bolts/orbs, bow arrows), 6 actives + 3 passives + 3 skill combos each; Vanguard passives.
- Projectile system (pierce, explosions, multi-shot, homing, traps), magic damage for Arcanist, stealth for Phantom.
- Class select on New Game. 193 tests (incl. Ranger arrow hit at 10 m, stealth aggro drop, passives).

### How to test (M8)
1. Delete saves or choose New Game → pick a class.
2. `~` → `level 10` for all skills. Try the skill combos (Codex → Status lists them per class).

## M7 — Quests (branch `m7-quests`)

### Done (M7)
- Quest graph (parallel + optional objectives per stage, start conditions, timers), new objective types (attack, dodge, distance, secret).
- Codex Daily Quest every game day + Penalty Zone survival arena when ignored. Emergency quests with a timer.
- Guild rank E→S (Codex → Status), Gate rank requirements, Codex Points. NPC opening hours.
- 188 tests.

### How to test (M7)
1. Codex → Misi shows the daily. Attack/dodge/run to fill it.
2. Skip it: `~` → `day +1` → 10 s later you are pulled into the Penalty Zone. Survive 90 s, leave through the ring.
3. Wait in the world (or `time` forward hour by hour) for an Emergency Quest.

## M6 — Inventory & loot (branch `m6-loot`)

### Hotfix (on m5)
- Phone stuck on the opening: taps were swallowed by the GUI. Fixed + Continue / New Game menu + save format 2 (atomic, verified, backup).

### Done (M6)
- Rarity loot from the balancing sheet, generated equipment with affixes and item level, enemy drops on the ground (walk over to pick up).
- Mystery Box (tier can climb while opening), upgrade +1…+15 with sheet costs/chances/downgrade, sell, salvage → scrap, crafting (3 recipes).
- All equipment slots incl. two rings. Quartermaster shop in the camp.
- Codex → Inventory: stats per item, equip / upgrade / salvage / sell / use, crafting list.
- Cheats: `loot <n> [rarity]`, `codex <tab>`. 181 tests.

### How to test (M6)
1. Kill enemies → colored cubes drop (color = rarity). Walk over them.
2. Codex (C) → Inventory: equip, upgrade (needs gold — `gold 5000`), salvage, sell, craft potions from herbs.
3. Buy a Mystery Box from the Quartermaster (camp) and open it from the inventory.

## M5 — Vertical slice (branch `m5-vertical-slice`)

### Done (M5)
- Save/load: 3 slots + autosave, Codex → System tab, `save`/`load` cheats, continue on boot.
- World clock (day/night) + weather (clear/rain/fog/storm per region table), HUD clock, night darkening, rain particles.
- Interaction (E / D-pad up / contextual touch button), breakable walls (heavy attacks only), SEN-based secret shimmer.
- Items & inventory: 14 items (weapons, accessories, food, potions, Codex scroll, Rusty Coin), equipment affects stats, lifesteal, curses, evolving weapons, unidentified items (appraiser vs Codex), loot tables, quick potion (H), Codex → Inventory.
- Secrets: data framework (conditions / rewards / unlocks / fail conditions), tracker, Mystery Journal (clues without answers + your notes), Lore tab, `list_secrets` / `reveal_secrets` / `secret` / `counter` cheats. All 9 [M5] entries of the Mystery Bible.
- NPCs + dialog: Old Marrow, Camp Kid, Bread Seller, Honest Appraiser (daily lines, choices, effects, consequences of attacking).
- Ashfall Outskirts graybox region (3×3 streamed chunks): refugee camp hub, overpass, culvert + pump room, bridge, leaning apartments (4th floor), Overpass Rift Gate.
- Gates: seeded dungeons, rules, multi-phase bosses with big HP bar, exit portal. Two Gates: Overpass Rift (rank E) and the hidden rain Gate.
- Quests: 2 auto-started quests with HUD tracker and Codex → Quests.
- 160 tests.

### How to test (M5)
1. `tools/play.sh` → opening → Ashfall camp. `~` opens the console (`help`).
2. Quest 1: talk to the Bread Seller, kill 5 Ash Hounds near the overpass (east), enter the Overpass Rift portal, clear 3 rooms + boss, leave through the blue ring.
3. Secrets (spoilers in `ascendant-dev/docs/MYSTERY_BIBLE.md`; `reveal_secrets` shows pink markers, `list_secrets` shows status). Useful cheats: `weather rain`, `time 22:00`, `day +1`, `level 10`, `tp x y z`.
4. Save in Codex → System, quit, restart: you continue where you saved.
5. Feel/clarity checklist: can you find the culvert/apartment clues without the cheats? Is the dialog readable on the phone? Does the boss phase change feel noticeable?

### Known gaps (M5)
- No main menu / class select yet (always Vanguard). No ledge climbing / swimming. First Fang stage needs the R1 world boss. Gate "Double/Red/Dungeon Break" types are M11.

## M4 — Codex (branch `m4-codex`)

### Done (M4)
- Codex notifications: slide-in "[ SYSTEM ]" toasts with per-kind colors and synthesized "ding" / level-up / anomaly / error sounds.
- Codex window (C / Select / ☰): Status tab (stats, points, skills), Log tab (message history), sealed tabs for upcoming systems. Pauses the game.
- Audio buses + pooled one-shot player. Glitch text for Codex anomalies.
- 94 tests.

### How to test (M4)
1. `~` → `level 6`: four level-up toasts with sound. C opens the Codex; Log shows the messages.

## M3 — Stats & skills (branch `m3-stats-skills`)

### Done (M3)
- Primary stats STR/AGI/INT/VIT/SEN, derived HP/MP/ATK/M.ATK/DEF/CRIT/CRIT DMG/ASPD/MSPD/CDR from the balancing sheet.
- Level + XP curve `round(100 × L^1.8)`, 5 free stat points and 1 skill point per level, class auto-growth, combo-rank XP bonus.
- Enemies scaled by level/tier from the sheet; they grant XP and gold.
- Vanguard: 6 skills (incl. ultimate) with MP cost, cooldowns (CDR), skill levels 1–10, unlock levels, 3 skill combos, ATK buff.
- HUD: MP bar, XP bar, level, skill bar with cooldowns (PC) / skill buttons with cooldown sweep (touch). Notices for level up and skill combos.
- Status panel (C): allocate stat points, level skills.
- Cheats: `level`, `xp`, `nocd`, `gold`, `press`.
- 87 tests (incl. sheet-value checks, data validation for every class, skill casting integration).

### How to test (M3)
1. `tools/play.sh`, open the console with `~` and type `level 10` (all skills unlocked), then `tp -38 0 28` for enemies.
2. Skills on 1–4 / T; try the skill combos from `docs/CONTROLS.md`. C opens Status: spend points, watch HP/ATK change.
3. Feel checklist: skill power vs normal attacks, cooldown lengths, MP pressure, how fast leveling feels on Gate Husks.

## M2 — Combat core (branch `m2-combat`)

### Done (M2)
- Elements (9) with multiplier table, damage formula from §6 with crit/variance, combo counter with rank D→SSS.
- Health / Hitbox / Hurtbox components, hit-stop, knockback, white hit flash, damage numbers (pooled Label3D, element colors, red when the player is hit).
- Player attacks from a data-driven combo graph: 5-hit light chain + 5 heavy branches, input buffer, lunge, dodge-cancel windows, heavy super armor, graybox blade swing + visible hitbox.
- Perfect dodge → slow motion + counter crit. Player HP, hurt stagger, death + respawn.
- Lock-on: Tab/MMB/R3 or touch button; wheel / right-stick flick switches target; camera frames the target; red marker.
- Enemies: Gate Husk (Lv1) and Ember Husk (Lv3, fire) with patrol / chase / telegraphed attack / stagger / leash / death, respawning spawners, max 2 attackers at once. Training dummies with DPS readout.
- HUD: HP bar, combo count + rank, PERFECT DODGE / DOWN notices. Touch: attack, heavy, jump, dodge, lock buttons.
- Cheat console `~`.
- 67 tests incl. integration: player hits dummy, lock-on, enemy chases and hits player, i-frames.

### How to test (M2)
1. `tools/play.sh` (or F5 → any key). Training dummies are just left of the spawn; the enemy arena is at about (-38, 0, 31): walk there or press `~` and type `tp -38 0 28`.
2. Try the combos from `docs/CONTROLS.md`, lock on with Tab, dodge the red telegraphs (perfect dodge = dodge right before the hit).
3. Feel checklist: hit-stop length, attack speed, lunge distance, enemy telegraph readability and timing, damage numbers, camera in lock-on.

## M1 — Core movement (branch `m1-core-movement`)

### Done (M1)
- Input Map for KB+M, gamepad and touch (see `docs/CONTROLS.md`).
- Player (`scenes/player/player.tscn`): capsule placeholder, `StateMachine` with Idle / Move / Air / Dodge, walk-run-sprint, variable jump, coyote time, input buffer, dodge with i-frames and cancel window, `StaminaComponent`.
- Third-person camera rig: orbit (mouse / right stick / touch drag), SpringArm wall collision, smoothing, FOV boost while sprinting, sensitivity / invert Y / distance in `Settings`.
- Touch controls (`scenes/ui/mobile_controls/`): floating joystick, camera drag area, jump and dodge/sprint buttons. Auto on Android, forced on PC with `-- --mobile-ui`.
- HUD stamina bar (appears when stamina is used, red while exhausted).
- Movement sandbox `scenes/test/test_movement.tscn`: grid floor, 20°/40°/55° ramps, step platforms 0.5–2.5 m, gap jumps, narrow roofed corridor (camera collision), pillar ring, big wall.
- Opening → any input → game (sandbox for now).
- Tests: movement math, stamina, joystick, plus integration tests that spawn the real player and simulate input (move, jump, dodge). 33 tests.

### How to test (M1)
1. F5 → opening → press any key → sandbox. Or open `scenes/test/test_movement.tscn` and press **F6**.
2. Click the game to capture the mouse (Esc releases). WASD move, mouse look, Space jump (hold = higher), Shift tap = dodge, hold Shift while moving = sprint. F3 shows state, speed, stamina.
3. Check: walk the 20° ramp (should climb), 40° (should climb), 55° (should slide/block); jump onto the 0.5–1.0 m steps; go through the corridor and check the camera does not clip through walls.
4. Phone: `adb install -r build/android/ascendant-debug.apk`, tap through the opening, left thumb = joystick, right thumb drag = camera, buttons bottom right.
5. Feel checklist for the owner: run speed, acceleration/stop snappiness, jump height & air control, dodge distance/speed, sprint FOV kick, camera sensitivity (PC and phone). Tune in `data/player/default_movement.tres` or tell me the direction.

### Not done yet (M1)
- VRM character model (waiting for a VRoid model + approval of the godot-vrm addon).
- Low-ledge climb, swim, glide; Settings menu UI for sensitivity/invert Y; touch layout editor.

## M0 — Setup (branch `m0-setup`, awaiting owner approval)

### Done
- Godot 4.7.2 project with the folder layout from the master prompt (§3).
- Autoloads (§4): `EventBus`, `Settings`, `GameState`, `SaveManager`, `WorldStreamer`, `AudioManager`, `Codex` (skeletons) + `DebugOverlay`.
- `PlatformProfile` resource + 6 quality presets (Android Low/Mid, PC Low/Medium/High/Ultra) with automatic default detection.
- Opening (`scenes/main/boot.tscn`): full-screen key art (cover-fit 16:9..20:9), no on-screen text. Animated via `assets/shaders/opening_logo.gdshader`: fade-in + slow push-in, rotating HUD rings, pulsing core light + beam, light sweep over the title, short glitch every 6 s, rising sparks.
- `DebugCapture` (debug builds): `-- --capture=<png> --capture-delay=<s> [--capture-overlay]` saves one frame and quits.
- `tools/screenshot.sh linux|windows <WxH> <delay> <out.png>` — screenshots on an invisible Xvfb display; `windows` runs the exported `.exe` under Wine.
- Debug overlay: **F3** (PC) / **3-finger tap** (Android). Shows FPS, draw calls, triangles, RAM/VRAM, loaded chunks, player position/state (`-` until M1 adds a player).
- GUT 9.7.1 + first tests (`tests/`).
- `tools/validate.sh` — import + strict script check (warnings = errors) + 120-frame smoke run + GUT.
- Export presets: `Windows Desktop`, `Android APK`, `Android AAB` (min_sdk 34, target_sdk 36, arm64) + `tools/build.sh`.
- Git LFS for binary assets (`.gitattributes`).

### How to test
1. Open the project in Godot 4.7.2, press **F5** → full-screen animated opening (fade-in, rotating rings, light sweep on the title). Press **F3** → debug overlay.
2. `tools/validate.sh` → must end with `VALIDATION OK`.
3. `tools/build.sh windows` → `tools/screenshot.sh windows 1920x1080 7` (Wine), or `wine build/windows/ASCENDANT.exe` to see it live.
4. `tools/build.sh android` → `adb install -r build/android/ascendant-debug.apk`, open the app, 3-finger tap for the overlay.

### Not done yet
- Cheat console (`~`) — planned alongside the first gameplay systems (M1/M2).
- Android build not yet tested on a real phone (no device connected during setup).
- No real Windows machine available; Windows build is verified under Wine 10 only.

### Known issues
- None.

## Gate dungeons rebuilt (2026-11-08)
- **Branching dungeons:** a Gate is now a graph of rooms (DungeonPlan): start → fight rooms → boss hall, with 1–3 dead-end side rooms. Same Gate + day = same dungeon.
- **Irregular, roofed rooms** (DungeonRoomShape / DungeonRoomBuilder): caves (bulging walls, rocks), halls (near-regular, pillar rings), ruins (walls broken into jagged stubs with rock behind, rubble). Each room has its own size (13–22 m radius) and ceiling (8–14 m).
- **Doors from the owner's downloads** (16 models, by Gate rank; Red Gates use the lava / infernal gates). A room seals its doors with a pulsing red ward while enemies live. Using a door: it shudders, the screen fades to black (~1.5 s in all), and you arrive at the matching door of the next room; the fight starts right away. Only the current room is drawn.
- **Secrets:** side rooms hold an ornate chest, a glowing emerald relic and a gothic statue; ~30% of fight rooms hide a cracked wall (heavy attack) with a lit niche and a chest. Gate chests do not leave world flags.
- **Double Gate = winged door:** when a run has a Double Gate, one room has the winged key gate. It needs a **Gate Key** (30% chance inside every Mystery Box) and uses it up. No key: the Codex hints at the key-shaped hollow.
- Torches in dungeons always burn; the sky light is only a dim fill under the roofs.
- 321 tests.

### How to test
- `gate gate_r1_e_overpass` (add `double` for the winged door), `give gate_key`.
- Debug: `dungeonmap` (all rooms from above, roofs off), `dungeonmap 3` (stand in room 3), `dungeonmap next` (clear room + use its last door).
- Check: door fade timing, the camera right after arriving, red wards, breaking a cracked wall, side-room chests.

## Bug fixes from owner playtest (2026-11-08)
- **Dying in a dungeon showed nothing:** respawn went to the start room while only the current room was drawn. Now the start room is shown again (and the respawn / fall-safe points are set when you enter or change rooms).
- **Respawn at the last altar (owner rule):** standing at any waystone makes it your respawn point (Codex notice, saved). Falling in the world brings you back there; falling inside a Gate fails the Gate and carries you out to that altar. No altar yet: the scene start, as before.
- **Chests gave nothing:** loot was placed at the chest's world position *inside* its moved parent (chunks sit at chunk_x * 128 m), so it landed ~290 m away; also enemy-style rolls are often empty. WorldPickup.spawn now converts to the parent's space; chests always give something and treasure chests always hold equipment.
- **Monsters outside the centre chunk spawned in the wrong place** (same cause, shifted by the chunk offset). EnemySpawner fixed; their drops too.
- **Camp altar:** region data still had the old waystone spot (6, 12); fast travel and the respawn now use (-34, 34). A test checks every waystone's data against the chunk scenes.
- 330 tests.

## Dungeon v2: one connected cave map (2026-11-08)
- Owner: no more teleport doors; abstract rooms (not round / oval), cave tunnels between rooms, some through doors, some open, some straight through.
- **Layout:** rooms on a 64 m grid (DungeonPlan), joined by links: **door** (tunnel with a door model — push it and it sinks into the floor), **open** tunnel, or **breach** (wide, short-wiggle opening). Side branches end in treasure rooms.
- **Shape:** DungeonField builds a density grid (1.5 m): rooms are unions of random ellipses roughened by noise (caves very rough, halls nearly regular), tunnels wind (spline through jittered points), swell / narrow and lift / drop their roof away from the mouths. DungeonMesher traces walls with marching squares (smooth, no blocks); cave walls lean outward, hall / ruin walls stay upright masonry; roofs are one smoothed surface that slopes from tall rooms into low tunnels.
- **Surfaces:** new dungeon shader: paving + cracked slate + mud + moss in world space, shiny wet patches; walls blend cave rock and theme masonry, moss climbs from the floor, root streaks hang from above. Reflective puddles.
- **Fights:** entering a room past its mouths starts the fight; red wards close every mouth until it is cleared.
- **Secrets:** cracked walls (heavy attack) close a lit niche with a chest; side rooms: chest + emerald relic + statue; Double Gate = winged door at the end of a dead-end tunnel (Gate Key).
- Only the current room and its neighbours are drawn. Build time ~0.35 s.
- Fix: leaving a Gate (death / exit) no longer counts a living boss as beaten (rooms notice vanished enemies each physics frame instead of on tree exit).
- 333 tests.

### How to test
- `gate gate_r1_e_overpass double`, then `god` (inside the Gate), `dungeonmap` (whole map from above), `dungeonmap 2` (room), `dungeonmap tunnel 1`, `dungeonmap door`, `dungeonmap zoom`.
- Check: tunnel feel, door push + sink, wards during fights, cracked wall niche, side room chest, winged door with / without a key.

## Region 1 city surfaces (2026-11-08)
- **Pavement shader** (procedural, sharp at any distance) replaces the baked sidewalk / asphalt tiles:
  - Concrete slabs (1.5 m) on sidewalks and new 3 m **aprons around every building**: 80 % intact, 10 % cracked, 10 % gone to earth; moss on ~22 % of slabs (~17.5 % of the area) and in some joints.
  - Asphalt: grain, soft aggregate, long cracks, alligator patches, wet potholes, grass in the cracks.
- Road damage no longer uses rock-like models: sinkholes are flat earth with a tipped-up asphalt rim, heaved slabs are thin tilted asphalt plates, kerb earth patches are flat with grass.
- Building facades: moss uses the real moss texture with ragged edges instead of flat green paint.
- Debug capture waits in real time (hit-stop no longer delays screenshots).

## Region 1 is Lv 1-50 (2026-11-08)
- Owner: Region 1 spans Lv 1-50, Region 2 50-100, and so on (+50 per region).
- Monster level follows the place: camp edge Lv 1-3, inner city to Lv 10, the ring to Lv 25, the outskirts to Lv 40; hot spots (highway, culvert pump room, Rank E Gate, apartments) are harder than their ring. Lv 40-50 is kept for the metro station (next).
- Packs by level: hounds / husks near the camp, moss brutes further out, elites (Ash Hound Alpha leading hounds, Gravewarden) in the far zones.
- EnemySpawner has a `level` override (stats, XP and gold follow the level; the shared data resource is untouched).
- Regions 2-7 moved to 50-100 ... 300-350; until they are reworked their monsters get a per-region level bonus.

## Metro station under Ashfall (2026-11-08)
- **Entrance** in the north-west of Region 1 (between the riverside street and the river): concrete pavilion, shutter jammed half open, METRO sign. "Go down to the metro".
- **Station** (own scene, built in code): 100 m island platform between two tracks; grimy glazed tiles (missing tiles, damp streaks, moss from the floor), tiled pillars, yellow platform edges, flickering / dead lamps, red emergency lights at the tunnel mouths, puddles, a caved-in ceiling with daylight on rubble and roots.
- **Trains** from Meshy (owner-approved, 90 credits): a cab and two cars on the south track (the last one derailed), a crashed car tipped against the platform. Rails are procedural (steel rails on concrete sleepers; the generated rail model came out as a triangular junction and was dropped).
- **Lv 40-50**: brutes, husks, an alpha hound pack, a Gravewarden by the west tunnel; supply chests on the platform, a treasure chest at the east tunnel's dead end.
- **Metro Tunnel Gate** (Rank D, enemies never below Lv 44) in the west tunnel.
- Stairs up to the street exit; the Lv 38 zone around the entrance outside.
- Saves made inside a Gate or the station keep the street position; dying inside carries you out to your altar.
- Debug: `metro`.

## Owner playtest fixes (2026-11-08, evening)
- **No more softlock after dying in a Gate:** you now always rise at your last altar (the camp altar before you have touched any) and are carried out of Gates / the metro. Before, with no altar, you woke in the dungeon's start room while the room you died in stayed sealed.
- Metro cheat "freeze": could not reproduce (walking works after `metro`, also when used from inside a Gate). Likely the first-visit shader compile on a busy laptop; the loading screen now stays up 1.5 s after the switch so shaders compile behind it.
- **Hero light at night:** a soft light above the hero fades in after dusk and stays on in Gates and the metro.
- **Stepping stones / ground pieces:** camp stones and flat ground pieces (mud, root mats, paving) are set into the ground so feet rest on them instead of sinking through.
- **Grass:** tufts of five curved, tapering blades (dark roots, fresh middle, dry tips, light through the blades, per-tuft wind phase) instead of flat spikes, within a similar triangle budget.

## HUD frame and Codex restyle (2026-11-09)
- **Player frame** in the owner's design: his line-art dragon wrapped around the round portrait (extracted from his sketch: the gold lines kept, the face / text removed by colour), name bar, HP bar, MP strip and level tab drawn inside the art; dragon heroes get this frame, shadow heroes a silver-violet frame with a crescent moon and crossed daggers. Level tiers still brighten / glow / sparkle it. The portrait aims at the face (head + "headfront" bones).
- **Codex** is now an elegant card (owner's "System Notification" reference): hero-themed glass (jade + gold for dragon heroes, violet + silver for shadow heroes), double trim frame with corner studs, serif capitals title over an ornament rule, card-style tabs, a "Character Profile" frame around the hero, and the line-art dragon faint in the corner.
- **Inventory lives in the Codex** (tab after Status); **I** opens the Codex on it, **M** on the map; clicking / tapping the minimap opens the map too. M is rebindable.
- Fonts: Noto Serif (OFL), see CREDITS.


## Skill icons (2026-11-09)
- 67 skill icons drawn by `tools/make_skill_icons.py` (gem plate in the skill colour, glowing symbol picked from the skill id / kind, gold frame with rays for ultimates, hexagon for passives). Shown on the skill bar, the touch skill buttons and in the Codex.

## Touch button layout (2026-11-09)
- Settings → Touch controls → Arrange buttons: drag any button, − / + resizes the picked one, Reset, Done. The game pauses meanwhile; the layout is saved in Settings (per button offset + size). Debug: `touchedit` (PC: run with `--mobile-ui`).

## Dungeon variety and challenges (2026-11-09)
- **Kinds of place** per Gate rank, picked per day (DungeonArchetype): Warrens, Fallen Halls, Ruins, Crystal Grotto, Crypt, Rootdeep. Each sets the room style mix, room size and roof height, how much tunnels wind, wetness, moss, light tint and fog; the Codex names it when you enter.
- **Room challenges** in about half of the fight rooms: waves (2-3), timed clear (a treasure chest if quick), fire vents (red warning glow, then a burst for 8 % max HP), darkness (all lights out but the hero's), an elite guardian.


## Ultra preset effects (2026-11-09)
- PC Ultra now really turns on volumetric fog, screen-space reflections, SDFGI + SSIL, TAA and full mesh detail (High: SSAO) in the world, Gates and the metro; phones / software rendering skip them.
