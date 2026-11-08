# Decisions

Log of technical/design decisions. Newest at the bottom. Format: date — decision — reason.

## M0 — Setup

- **2026-11-06 — Engine locked to Godot 4.7.2-stable (official build).** Latest stable at project start. Installed as the official Linux binary (`~/.local/bin/godot`) with matching export templates, not the distro package, so exports match the templates exactly.
- **2026-11-06 — Two repositories.** `ascendant` = the game (Godot project, code, data, technical docs). `ascendant-dev` = private design docs (master prompt, GDD, mystery bible, balancing sheet). Spoilers never live in the game repo's docs.
- **2026-11-06 — GDScript only, full static typing.** Enforced by project warning settings plus `tools/validate.sh`, which promotes every GDScript warning to an error during validation.
- **2026-11-06 — Physics: Jolt** (`physics/3d/physics_engine="Jolt Physics"`), built into Godot 4.4+.
- **2026-11-06 — Renderers:** Forward+ on desktop, Mobile on Android via `rendering_method.mobile`, with `rendering_device/fallback_to_opengl3=true` for devices without usable Vulkan.
- **2026-11-06 — Test framework: GUT 9.7.1**, vendored in `addons/gut/` (MIT). Excluded from exports.
- **2026-11-06 — Quality presets** are `PlatformProfile` resources in `data/platform_profiles/`. Default preset is picked by `QualityPresets.detect_default(mobile, ram)`: Android < 6 GB RAM → Android Low, else Android Mid; PC < 12 GB RAM → PC Low (owner's 8 GB laptop), else PC Medium. PC High / Ultra are opt-in from Settings. Thresholds are a first guess, tune after M1/M5 performance tests.
- **2026-11-06 — PC High and PC Ultra run uncapped** (`target_fps = 0`); other presets cap at 60 / 30.
- **2026-11-06 — Debug overlay is an autoload scene** (`DebugOverlay`) so F3 works in every scene including F6 test scenes. It frees itself in release builds. On Android it toggles with a 3-finger tap.
- **2026-11-06 — Android export uses the Gradle build** (needed for `min_sdk 34`; the non-Gradle path ignores min/target SDK). `min_sdk = 34`, `target_sdk = 36`, arm64-v8a only. JDK 21 is used for Gradle 8.11.1.
- **2026-11-06 — `tools/build.sh` unsets `ANDROID_SDK_ROOT`.** The owner shell exports `ANDROID_SDK_ROOT=/usr/lib/android-sdk`, which conflicts with the SDK in Godot editor settings (`~/Android/Sdk`) and makes Gradle fail. Exporting from the editor needs the editor started without that variable (or with it pointing to `~/Android/Sdk`).
- **2026-11-06 — Android package id (provisional): `com.kodokkejepit.ascendant`.** Must be final before the first Play Store upload; changing it later means a new app listing.
- **2026-11-06 — Window:** 1920×1080 base viewport, `canvas_items` stretch, `expand` aspect (covers 16:9 to 20:9), editor/desktop window starts at 1280×720. Android orientation: sensor landscape.
- **2026-11-06 — Localization:** CSV (`assets/localization/strings.csv`, columns `en`, `id`), fallback `en`. All UI text goes through `tr()`.
- **2026-11-06 — Opening is the full-screen key art, animated by a single canvas shader** (no separate layered art yet). The square logo is cover-fitted, so 16:9/20:9 crop the top and bottom of the image. If the owner later provides layered art (background, rings, title separately), the shader can be replaced by real layers.
- **2026-11-06 — Windows testing on the owner machine uses Wine (10.0) + Xvfb**, not a Windows VM: the laptop has 8 GB RAM (a Windows VM would need 4+ GB) and a VM has no GPU acceleration, so it would test graphics worse than Wine. Wine is a smoke test, not a replacement for a real Windows run before release.

## M1 — Core movement

- **2026-11-06 — Owner granted blanket autonomy** ("don't ask, auto yes"). Defaults below were taken without asking; all are easy to change.
- **2026-11-06 — Player is a capsule placeholder in M1.** No VRoid model exists yet and the godot-vrm addon is not installed; swapping the `Visual` node for a VRM model is planned once the owner provides a model (hero gender/customization question from §15 still open).
- **2026-11-06 — Jump = Space / A, Dodge+Sprint share one button (Shift / B): tap = dodge, keep holding = sprint.** The master prompt lists Dodge on Space/Shift but has no jump key; sharing dodge and sprint is the common action-RPG pattern and frees Space for jump. Gamepad A is jump, so interact will need a contextual rule in a later milestone.
- **2026-11-06 — Player states:** `Idle`, `Move` (walk/run by stick magnitude, sprint), `Air` (variable jump height, coyote time 0.12 s, momentum kept), `Dodge` (0.38 s, i-frames 0.3 s, cancel into jump/dodge after 60%). Input buffer 0.2 s for jump and dodge. All tuning in `data/player/default_movement.tres`.
- **2026-11-06 — Stamina:** 100 max, regen 28/s after 0.8 s, dodge 20, sprint 18/s. Hitting 0 = exhausted until 30%.
- **2026-11-06 — Physics interpolation enabled** (`physics/common/physics_interpolation`); the camera rig is top-level, not interpolated, and follows the player's interpolated transform every rendered frame.
- **2026-11-06 — Godot 4.7 ships a native `VirtualJoystick` class**, so the touch stick is `FloatingJoystick` (own implementation, feeds the move actions).
- **2026-11-06 — Opening → game:** after the fade-in, any input continues to `scenes/main/game.tscn`, which currently hosts the movement sandbox (`scenes/test/test_movement.tscn`) so the APK is playable for M1 testing.
- **2026-11-06 — Not in M1 yet:** low-ledge climb, swim, glide (listed in §5, not in the M1 milestone row). Lock-on comes with M2 combat.

## Phase plan

- **2026-11-06 — Two big phases (owner decision).** *Big Phase 1 — Systems*: every gameplay system complete and playable with graybox visuals (capsules, boxes, flat colors): combat, stats, skills, items, quests, Codex, world, Gates, secrets, save, all classes. *Big Phase 2 — Presentation*: characters (VRoid/VRM), animation, skins/outfits, environment art, VFX and audio polish. The milestone order of the master prompt still applies inside Phase 1, but art tasks inside milestones (VRM model, toon shader polish, environment art) move to Phase 2.
- **2026-11-06 — Sharing builds to the owner's phone:** chat uploads are limited to 30 MiB, so `tools/build.sh share` makes a release APK signed with the local debug key (~30 MiB, no debug overlay). Native libraries are compressed in all Android exports; banner/poster are excluded from exports; app icon is a 512 px copy (`assets/branding/app_icon.png`); the opening logo texture is imported lossy (0.85). The share APK is right at the limit — if it grows past it, next options are a custom smaller export template (Phase 2/M12) or another delivery channel.
- **2026-11-06 — Playtest launcher:** `tools/play.sh [linux|windows|android|editor]` plus desktop entries "ASCENDANT (Linux)" and "ASCENDANT (Windows via Wine)" in the app launcher. Wine on the real display uses the Intel GPU through Vulkan.

## M2 — Combat core

- **2026-11-06 — Physics layers:** 1 world, 2 player, 3 enemy, 4 player_hurtbox, 5 enemy_hurtbox. Hitboxes are monitoring-only Areas that scan overlapping hurtboxes every physics frame while active (each hurtbox once per activation).
- **2026-11-06 — `CombatStats` resource is the M2 stand-in for stats.** M3's StatsComponent will derive a CombatStats from STR/AGI/INT/VIT/SEN so the damage path stays the same.
- **2026-11-06 — Combo graph as data:** `AttackData` nodes link with `next_light`/`next_heavy`; `ComboData` has the entry points. Greatsword graph in `data/combat/greatsword_combo.tres` (placeholder for Vanguard; other weapons get their own graphs in M8). Not yet: `L (hold) H` variant and aerial launcher/juggle/slam — planned with M3 skills.
- **2026-11-06 — Hit-stop / slow-mo via `TimeFx`** (static, Engine.time_scale, lowest active scale wins, real-time timers).
- **2026-11-06 — Perfect dodge:** hit received during the first 0.15 s of a dodge → 0.5 s slow motion at 0.25×, next hit within 1.5 s = forced crit ×1.5.
- **2026-11-06 — Player poise:** hits with stagger ≥ 15 interrupt the player unless they are in a heavy attack (super armor). Death → respawn at spawn point after 2 s (save/checkpoints come in M5).
- **2026-11-06 — Enemy AI states:** Idle (patrol around home) → Chase → Attack (windup with red ground telegraph, tracks player only during the first half of the windup so dodging works) → Hurt (poise break) → Return (leash, heals) → Dead. Flee and ranged/caster types come with more enemy types later. Max 2 simultaneous attackers via `AttackTokenPool`.
- **2026-11-06 — Cheat console** (`~`, debug builds): tp, god, heal, kill_all, spawn, timescale, lock, autoattack, pos, help. `-- --exec="cmd1;cmd2"` runs commands at startup (used for automated screenshots). `give/level/time/weather/reveal_secrets` get registered by their systems later.
- **2026-11-06 — Static vars holding Resources/lambdas crashed the engine at exit** in headless test runs; avoid `static var` with Resources/Callables to lambdas (static Callables to static funcs are fine).

## M3 — Stats & skills

- **2026-11-06 — Balancing source of truth:** `data/balancing/stat_tuning.tres` mirrors sheet *Parameter* of `ASCENDANT_Balancing.xlsx`; class numbers mirror sheet *Kelas*. Tests assert the sheet values (Vanguard Lv1: HP 330, ATK 27 + weapon, DEF 14.6; Normal enemy Lv1: HP 155, ATK 35, XP 6). When the sheet changes, update the .tres and the tests together.
- **2026-11-06 — Not in the sheet, engine defaults:** MSPD (+0.1%/AGI, cap 1.3), CDR (+0.1%/INT, cap 40%), MP regen (2 + 0.05/INT per second), 1 skill point per level. Starter weapon ATK = level × 4 (sheet's "average gear" assumption) until equipment exists (M6).
- **2026-11-06 — Enemies scale from a reference hero** (Vanguard with the recommended stat split) like the sheet's *Musuh* tab; `EnemyData.scale_by_level` + `tier` (Normal/Elite/Boss) + `hp_scale`/`attack_scale` for per-type flavour.
- **2026-11-06 — Skill keys:** 1–4 and Q/R/F/G (E stays free for Interact, C for Codex), ultimate T. Gamepad: hold LB + face buttons, ultimate LT+RT. Skills cancel normal attacks after the combo window, not other skills. Attack speed (AGI) scales normal attacks only.
- **2026-11-06 — Vanguard kit (graybox):** Rending Slash, Iron Charge (dash), Earthsplitter (earth AoE, Lv3), War Cry (ATK buff, Lv5), Flame Edge (fire, Lv8), Titan's Verdict (ultimate, Lv10). Master prompt targets ≥ 15 skills per base class; the remaining 9 come with the skill tree work in M8.
- **2026-11-06 — Status panel** (C) is a stand-in for the Codex Status tab (M4). The game currently starts a fresh Lv1 Vanguard every run (save/load in M5, class select with the main menu).
- **2026-11-06 — Input polling for menus uses edge detection** (`is_action_pressed` now vs last frame) instead of `is_action_just_pressed`, so on-screen touch buttons (which only set action state) work reliably.
- **2026-11-06 — Known issue:** rare engine crash at shutdown after a GUT run in which all tests passed. `tools/validate.sh` retries once in that exact case and prints a note.

## M4 — Codex (system UI)

- **2026-11-06 — M4 split by big phase:** toon shader, outlines, slash/aura VFX → Big Phase 2. Codex window, notifications and "ding" → done now (systems).
- **2026-11-06 — Codex autoload** owns notifications (`Codex.notify(text, kind)`; kinds info/level_up/quest/secret/warning/anomaly/reward), a 200-entry history (Log tab) and `Codex.anomaly(text)` (glitched text, clean text kept for the Mystery Journal).
- **2026-11-06 — Placeholder audio is synthesized in code** (`Synth`, ids ding/level_up/anomaly/error/hit) and played through `AudioManager` on buses Master/BGM/SFX/Voice/UI (`default_bus_layout.tres`). Real sounds replace the ids in Big Phase 2.
- **2026-11-06 — Codex tabs:** Status (stats + skills, replaces the M3 status panel) and Log work; Quests, Inventory, Map, Shadow Army, Lore, Achievements, Mystery Journal are shown *sealed* until their milestones fill them. Codex is CanvasLayer 60 (above toasts at 50).
- **2026-11-06 — Codex look** (`CodexTheme`): translucent dark-blue panels, cyan border, accent-colored left edge. Scanline/glitch shader polish is Big Phase 2.

## M5 — Vertical slice (systems)

- **2026-11-06 — Systems pulled forward from later milestones because the M5 secrets need them:** world clock + weather (M9), items/inventory/equipment (M6), NPC dialog (M7), quests (M7). Each is a working core; the later milestones extend them (shops, crafting, quest graphs, schedules, more weather visuals).
- **2026-11-06 — Save format:** gzip JSON at `user://saves/<slot>.save`, schema 1, sections `game_state` (class, progression, skills, gold, flags, time, weather, inventory, secrets, quests, player position) + `providers`. Autosave every 5 min and on entering a Gate. Opening continues the most recent save, else starts new.
- **2026-11-06 — Time:** 1 real second = 1 game minute (24 real min/day), new game starts Day 1 08:00, night 20:00–05:00.
- **2026-11-06 — Secrets follow MYSTERY_BIBLE IDs exactly** (`data/secrets/r1/`, `:N` suffix = sealed mission stage). All 9 [M5] entries are implemented with data + world props: SEC-R1-01, SEC-R1-02, SM-R1-01 (stages 1–3), SM-R1-02 (both stages), SI-R1-01/02/03, MC-R1-01, MC-R1-02. Region tracker shows the bible totals (13 / 3).
- **2026-11-06 — SM-R1-01 stage 3 failure:** identifying the license with the Codex scroll fails stage 3 permanently in this build. The bible's "longer path in R2" is not implemented yet (R2 is M9).
- **2026-11-06 — Evolving pipe stage 2 (First Fang via R1 boss)** needs the R1 world boss, which is not in the slice; the pipe evolves to Fanged Pipe at 300 kills. To do with the R1 world boss.
- **2026-11-06 — Gates:** seeded room-template dungeons (open / pillars / split), rooms lock until cleared, boss arena with `BossPhases` (70/40/15%: faster, shorter telegraphs, adds at phase 2). Rules: `no_skills`, `no_potions`. Hidden Gate (SM-R1-02) appears in the pump room only while it rains after the sealed mission triggers.
- **2026-11-06 — Boss HP scaling:** the sheet's ×40 boss HP makes a ~200-hit fight at Lv 5–6; slice bosses use `hp_scale` 0.2–0.25 until gear (M6) exists. Revisit in balancing.
- **2026-11-06 — World:** Ashfall is 3×3 chunks of 128 m generated by `tools/gen_ashfall_chunks.py` (edit the script, not the .tscn). `WorldStreamer` loads chunks in the preset radius with threaded loading, unloads beyond radius+1, and loads the player's chunk synchronously on region start. Graybox blocks (`GrayboxBlock`) replace art until Big Phase 2. Apartment "4th floor" is reached by a ramp (no ledge climbing yet).
- **2026-11-06 — `GameShell` scene** bundles HUD, touch controls, Codex, dialog box, SecretTracker, QuestSystem, damage numbers and the attack token pool; every playable scene instances it.
- **2026-11-06 — Debug cheats registered by nodes use methods, never lambdas, and unregister on exit** (a lambda left in the static console registry crashed the engine at shutdown).
- **2026-11-06 — Bug (phone): stuck on the opening.** The full-screen boot `Control` had `mouse_filter = STOP`, so on touch screens the GUI consumed the tap and `_unhandled_input` never ran (keyboard on PC still worked, which hid it). Fix: root `MOUSE_FILTER_IGNORE`, opening listens in `_input`, regression test `tests/test_boot.gd`.
- **2026-11-06 — Main menu after the opening:** Continue (most recent save, with class + level) / New Game; skipped if there is no save. Continue has a 10 s watchdog that falls back to New Game. `-- --skip-opening` jumps straight in (dev/testing).
- **2026-11-06 — Save file format 2 (`SaveFile`):** `ASAV` magic + format + raw size + MD5 + packed size + gzip JSON, written to `.tmp` and renamed (atomic), previous file kept as `.bak`, every read validated and bounded so a broken file can never hang the game. Format-1 saves (plain Godot gzip files from the first M5 build) are ignored. The game also autosaves when Android sends the app to the background.

## M6 — Inventory & loot

- **2026-11-06 — Loot numbers from the sheet** (`data/balancing/loot_rules.tres`, sheets *Loot_Rarity* + *Upgrade*): rarity weights per enemy tier, stat multiplier 1.0/1.15/1.35/1.6/2.0/2.6, affix count 0–5, mystery box initial tiers + per-tier upgrade chance, upgrade cost `100 × 1.35^(L−1)`, success 100% → 10%, failing at +11..+15 drops a level, bonus +4%/level (+8% after +10). Tests assert these.
- **2026-11-06 — Equipment drop chance per tier:** Normal 8%, Elite 60%, Boss 100% (not in the sheet; tune later). Materials: herb 30%, scrap 20%; mystery box 2% / 20% / 50%.
- **2026-11-06 — Generated equipment** = drop base (`is_drop_base`, one per slot for now) + rolled rarity + level-scaled affixes (prefix/suffix name the item). The rarity multiplier applies only to generated drops; hand-authored items (quest/secret items) use their written numbers. Upgrades apply to all equipment.
- **2026-11-06 — Equipment slots:** Weapon, Off-hand, Helm, Armor, Gloves, Boots, Ring ×2 (`RING_2`), Necklace, Rune Core. Sockets/gems, enchant, reforge and set bonuses are not in yet (later M6 pass / M12).
- **2026-11-06 — Economy UI lives in Codex → Inventory** (sell, salvage, upgrade, craft available anywhere) for Big Phase 1; a blacksmith/vendor-only rule can come with Haven City. Shop = Quartermaster NPC in the Ashfall camp (dialog choices with gold cost).

## M7 — Quests & dialog

- **2026-11-06 — Quest graph:** objectives carry a `stage`; objectives of the same stage run in parallel, `optional` ones never block. Quests have kinds (story / side / daily / emergency / bounty), start conditions (ConditionData), optional time limit, guild points. Old sequential quests were converted to stages 0,1,2.
- **2026-11-06 — Daily quest (Codex):** generated per game day (deterministic from the day), 3 of 4 tasks (attacks, dodges, run distance, kills) scaled by level up to the master-prompt numbers (100 attacks / 50 dodges / 5 km). Reward: XP (15% of the level's XP), 10 Codex Points, 5 guild points. Unfinished when the day changes → **Penalty Zone**: 10 s warning, forced survival arena 90 s with growing waves, then an exit portal back to where you were.
- **2026-11-06 — Emergency quests:** 12% chance per game hour while in a region (none active): defeat 6 monsters in 3 minutes for gold + guild points; fail on timeout. Runtime-only (not kept in saves).
- **2026-11-06 — Guild rank E→S** from guild points (thresholds 0/100/300/700/1500/3000): Gate clears (10 × rank), quests, dailies, emergencies. `GateData.min_guild_rank` blocks entry. Bounty board is not in yet.
- **2026-11-06 — NPC schedules:** simple "away" hour range per NPC (bread seller 21–6, quartermaster 22–7, appraiser 23–8). Full position schedules later with Haven City.
- **2026-11-06 — Not yet:** story chapter content (Big Phase 1 has the systems; chapter writing/cutscenes come with the story pass), bounty board, NPC affinity.

## M8 — Other classes

- **2026-11-06 — Classes from the sheet** (*Kelas*): Phantom (dual daggers, physical, crits/stealth), Arcanist (staff, magic damage = M.ATK, elemental projectiles), Ranger (bow, physical, ranged). Data is generated by `tools/gen_classes.py` (edit numbers there).
- **2026-11-06 — Projectiles** (`ProjectileData` + `Projectile`): speed, range, radius, pierce, explosion radius, multi-shot spread, homing toward the lock-on target, and traps (speed 0 + lifetime). Ranged basic attacks and skills set `AttackData.projectile`; damage is frozen when fired, so it still counts if the attack ends first. Projectile hits feed the same combo/hit-stop/damage-number path as melee.
- **2026-11-06 — Each class: 6 actives (incl. ultimate) + 3 passives + 3 skill combos**, Vanguard also got 3 passives. Passives (`SkillData.Kind.PASSIVE`) add permanent attack/defense/crit/aspd/mspd per skill level and are never slotted. Master prompt target is ≥ 15 skills per base class — the rest come with job changes / skill tree depth (M10) and skill books.
- **2026-11-06 — Spec skill-combo examples implemented with original kits:** Shadow Step → Venom Fang = guaranteed crit (Phantom), Frost Lance → Thunder Step = "Superconduct Step" (Arcanist).
- **2026-11-06 — Stealth** (Smoke Veil) is a buff: enemies drop their target; the first attack ends it and becomes a guaranteed bonus crit.
- **2026-11-06 — Class choice** on New Game (boot menu); `-- --class=<id>` and the `newgame <class>` cheat for testing. Enemy scaling still uses Vanguard as the reference hero.

## m9 — Owner feedback round + Job system

- **2026-11-06 — Touch input:** on touch devices every gameplay action drops its mouse-button bindings (a touch is also a fake left click). UI (`ui_*`) actions keep them.
- **2026-11-06 — Falling out of the world:** below y = −30 the player returns to the last floor position (sampled every 0.5 s), loses 10% max HP (never lethal, skipped in god mode). Enemies below y = −40 are removed.
- **2026-11-06 — Actions combine:** attacks keep 45% (light) / 20% (heavy) of run steering; jump cancels an attack after its combo window; light/heavy attacks and skills work in the air.
- **2026-11-06 — UI windows:** Codex, Inventory and Settings are separate `PausingPanel`s; only one is open at a time. Touch devices scale panel fonts/buttons by 1.45 (`CodexTheme.ui_scale`).
- **2026-11-06 — Settings file:** `user://settings.cfg` (ConfigFile, separate from save slots). Bad values are clamped; unknown presets/languages fall back to Auto.
- **2026-11-06 — Daily quest groups:** one task each from training / hunting / gathering, picked deterministically per day. New objective types PICKUP, CRAFT, USE_ITEM, SKILL. "Close a Gate" only from Lv 3.
- **2026-11-06 — Gate scaling (`GateLayout`):** rooms = data + ⌊(level−1)/5⌋ + rank, max 12; enemies/room +1 per 20 levels, max 7; enemy level = max(data level, player level − 2).
- **2026-11-06 — Double Gate:** 35% per Gate per game day (deterministic). Hidden in a normal room (never the first) behind a heavy-attack wall; 2 rooms, rank +1, enemies +4 levels, one rule (no skills / no potions), 2× gold + mystery box. No Double Gate inside a Double Gate. Leaving returns to the world (not to the outer Gate) — simple and never stuck.
- **2026-11-06 — Job system (M10 pulled forward at the owner's request):** `JobData` (tier, level, parent, hidden flag, stat/atk/def/hp bonus, MP cost multiplier, skills, shadow_army). Jobs stack: you keep the skills and bonuses of earlier jobs. Job Change I Lv 30 (2 per class + Summoner for any class), II Lv 60. Data from `tools/gen_jobs.py`.
- **2026-11-06 — Summoner → Necromancer (owner design):** Summoner is deliberately weak (−10% attack, MP ×1.5, 1–2 familiars). Sealed mission **SM-JOB-01**: familiars land 50 killing blows (counter `familiar_kills`) → then clear a Double Gate at night → flag `necromancer_awakened` → hidden Necromancer (Lv 35). Two hints arrive in the Journal. This is the early part of the "Jalan Bayangan" (MYSTERY_BIBLE 5.6); Shadow Sovereign stays behind the later chain (flag `shadow_sovereign_awakened`).
- **2026-11-06 — Shadow army:** bind chance 75% / 50% / 30% (normal / elite / boss), within 8 m and 10 s of the kill; slots 3 + 1 per 10 levels, max 30 (MYSTERY_BIBLE 5.6). Soldiers hit for 40% of the player's attack × tier power (1 / 1.6 / 2.6). Commands are original: "Rise, Echo." / "Answer me."
- **2026-11-06 — Minions (Big Phase 1):** allies are lightweight `Minion` bodies that follow, hunt the nearest enemy within 14 m and deal a share of the player's damage; enemies do not target them yet and they cannot die (familiars expire after 25 s).

## p2 — Test heroine (procedural)
- No Blender / VRM addon on the machine yet, so the test character is built in GDScript from primitive meshes on a Node3D joint hierarchy (CharacterRig) with procedural poses (CharacterPoses) instead of a Skeleton3D + Mixamo clips. The CharacterModel interface (pose from player state, dragon on `skill_used`) stays when a real .vrm/.glb replaces the mesh.
- The look is based on a reference image supplied by the owner, for internal testing only. The release hero must be an original design (§0 / master prompt: all characters original) — do not ship this likeness.
- Spirit dragon is presentation only: triggered by `EventBus.skill_used`, never by basic attacks; ultimates use the larger variant.
- Phones (mobile feature / Android Low) skip the outline pass; static parts are baked into one mesh per joint for draw calls.
- Final heroes are being made by the owner in an external 3D tool. Import format: **GLB** preferred (mesh + textures + skeleton + animations, native in Godot), **FBX** second (built-in ufbx importer). Not usable here: BLEND (needs Blender installed), OBJ (no skeleton), STL/3MF/DXF (no colour/texture, CAD/print formats), USDZ (not supported by Godot).

## m9 — World expansion
- Regions are separate scenes (RegionData.scene_path) linked by road waystones; each region streams its own chunks. Seamless cross-region streaming is postponed until the world size is final (§15) — loading between regions is short.
- Dynamic Gates: roll every 120 game minutes per region (50%), max 2 per region at fixed spots, break after 1 game day (= 24 real minutes). Wave = 4 + 2×rank, level = max(region min, player). Values live in WorldGates constants for tuning.
- Enemies pick a minion only if it is ≥ 2 m closer than the player (so the player is never ignored for long); minion HP = 35% of owner max HP (SummonData.hp_share).
- R2/R3 secrets follow MYSTERY_BIBLE IDs with simplified Big Phase 1 conditions (heavy attack instead of element interactions); full conditions come with exploration elements.

## m10 — Trials & shadow ranks
- Job trials reuse the Gate system (GateSession.trial_job, rule "trial" + "no_double"); two shared trial Gates (tier I/II) instead of one per job — per-job trials can come with story content.
- Shadow XP per kill = 1 + 4×tier; ranks at 20/60/150/320 XP; power ×1, 1.25, 1.55, 1.9, 2.4. Numbers in ShadowArmy for tuning.

## m11 — Endgame graybox
- Hollow Throne access uses 3 key flags (echo_king_answered, codex_umbra_read, fracture_heart) as stand-ins for 7 Sigils + 4 map pieces until those collectibles exist; hour 03:xx instead of exactly 03:33 (game minutes pass fast).
- Will (Kehendak) stand-in for Ending C = number of secrets found (≥ 12); Ending B = 20+ shadows (Void Resonance stand-in).
- Red Gate = rule "red": +5 enemy levels, gold ×3, no Double Gate.
- Gravity zones scale only falling/rising gravity, not jump velocity → light zones give high jumps.

## m12 — Polish
- Placeholder audio is generated offline (tools/gen_audio.py → OGG loops / WAV) rather than at runtime, to avoid startup hitches on phones; ids match the future real assets.
- Music is skipped in headless runs (dummy audio driver keeps streaming playbacks alive at exit → false leak errors in validation).
- PC keeps the HD hero mesh at every preset (owner: laptop as smooth as possible); only the outline pass is preset-gated (PC Medium+).

## Builds on GitHub Actions
- The dev laptop ran out of memory during Android (Gradle) exports, so exports moved to a **public** GitHub repo `Kodok-Kejepit/ascendant-builder` (owner's choice: the private-repo Actions quota was used up). `tools/setup_builder.sh` pushes a one-commit snapshot of the current branch as `main`, authored with the owner's GitHub noreply address (GitHub blocks pushes that expose the private email); `.github/workflows/build.yml` runs the GUT tests, exports the share APK (signed with the owner's debug key from the `ANDROID_DEBUG_KEYSTORE_B64` secret, so phone updates install over older builds) and the Windows debug build (keeps the `~` console), and republishes them as the rolling `latest` release. Local branches/history stay as they are; merging to the local `main` still waits for the owner's approval.
- No release keystore is stored anywhere in the repo or the workflow.

## Animated hero rig (p2-8)
- The owner's Mixamo FBX (Meshy auto-rig, 24 bones) is converted once by `tools/import_rigged_hero.gd` into a scene (`assets/characters/dragon_maiden/rig/`), not imported by the editor: hair needs re-rigging and root motion must go.
- Hair is found by geometry, not colour (Meshy's texture atlas mixes colours): vertices outside per-bone clearance capsules around the body are "loose"; looseness is smoothed over the mesh and mixed with the original weights, so the seam bends instead of tearing. Loose vertices get 10 sector chains × 6 bones from the head; SpringBoneSimulator3D moves them at runtime (colliders in world metres — skeleton units are cm).
- CharacterRig joints stay the anchor for weapons/gear/trails: AnimatedBody copies bone poses into them every frame (hands use the Mixamo hand +Z as the blade direction).
- The dragon sculpted on her back is part of the same mesh, so it is loose too and sways with the hair; the separate spirit dragon still appears only on skills. A re-export without the back dragon would separate them.
- No idle clip exists yet: the first frame of Weapon_Combo is the stance.

## Owner model batch (p2-8)
- Heavy downloads (up to 10 M triangles) are reduced outside Godot, one file at a time under a memory cap; Godot never loads the originals (laptop OOM history).
- `--rebake` (new UV atlas + baked albedo) instead of the plain simplifier for files whose UV islands block simplification — the weld-and-keep-UV attempt smeared ~80% of triangles.
- Floors/walls: Meshy atlases do not tile, so tiling textures are baked from orthographic renders of the models.
- Monsters / NPCs without rigs animate as a whole (breath, bob, lean) via CreatureBody; slot ids `mob_<enemy>` / `npc_<npc>` so swapping a model needs no code.
- Towns are dressed from `tools/world_dressing.py`; every piece is a PropInstance slot, so a missing model shows its graybox footprint.

## Level cap (2026-11-08)
- Level cap raised from 100 to 1000 (owner: long-term open world with more worlds). XP curve unchanged (100 x level^1.8, ~25 M XP at 999).

## Dungeon doors teleport instead of corridors (2026-11-08)
- Rooms are built far apart and doors move the player with a short fade (owner offered "transisi gelap 1-2 detik"). Reasons: the downloaded door models are single meshes (the leaf cannot swing on its own), irregular rooms never have to line up, and only one room is drawn at a time (phones).
- Double Gate entry moved from the cracked-wall portal to a key door; Gate Keys come from Mystery Boxes (30%). Cracked walls now hide loot niches instead.

