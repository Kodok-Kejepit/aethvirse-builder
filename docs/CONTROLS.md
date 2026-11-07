# Controls

All input goes through Input Map actions (Project Settings → Input Map). Touch controls feed the same actions.

| Action (Input Map) | PC (KB+M) | Gamepad | Android (touch) | Since |
|---|---|---|---|---|
| `move_forward/back/left/right` | W S A D | Left stick | Floating joystick (touch the left 45% of the screen) | M1 |
| `camera_left/right/up/down` | Mouse (click the game to capture, Esc to release) | Right stick | Drag on the right side of the screen | M1 |
| `jump` | Space | A / ✕ | Big round button (^) | M1 |
| `sprint` | Left Shift (hold while moving, unlimited) | L3 (hold) | Dash button — keep holding after the dash | P2 |
| `dodge` | Left Ctrl — dash (stamina, i-frames; also once in mid-air). Its late part chains into an attack (dash attack), a skill, a jump or another dash; it also breaks out of a stagger | B / ○ | Round button (») | P2 (was `dodge_sprint`) |
| `attack_light` | Left mouse or **J** | X / □ | Big round button (/) | M2 |
| `attack_heavy` | Right mouse or **K** | Y / △ | Round button (thick /) | M2 |
| `lock_on` | Middle mouse / Tab | R3 | Small button top right (◎) | M2 |
| `lock_next` / `lock_prev` | Mouse wheel down / up | Flick right stick while locked | — | M2 |
| `skill_1` … `skill_4` | 1–4 (also Q, R, F, G) | Hold LB + X / Y / B / A | 4 round skill buttons (initials, cooldown sweep) | M3 |
| `ultimate` | T | LT + RT together | Gold-ringed button | M3 |
| `codex` | C | Select / Back | ☰ button top | M3 |
| `inventory` | I | — | Bag button top (next to ☰) | M9 |
| `settings` | F10 | Start | ⚙ button top (also Codex → System, main menu) | M9 |
| `interact` | E | D-pad up | Contextual button (appears near something usable) | M5 |
| `use_potion` | H | D-pad down | — (Bag → Use) | M5 |
| `debug_toggle_overlay` | F3 | — | 3-finger tap | M0 (debug builds only) |
| `debug_console` | ` (backquote / ~) | — | — | M2 (debug builds only) |

**Rebinding (PC):** Settings → Controls → *Atur tombol*: click a slot, press a key or mouse button (Esc cancels, Backspace clears). A key taken from another action moves over. *Serangan dasar pakai klik mouse* off = attacks only on keys (J / K), handy on a laptop touchpad. Saved in `user://settings.cfg`; gamepad bindings are fixed.

Opening screen: any key / click / tap / gamepad button continues.
Desktop testing of the touch UI: run with `-- --mobile-ui` (e.g. `godot --path . -- --mobile-ui`).

Combos (greatsword): `L L L L L` chain · `H` Overhead Smash · `L H` Rising Cleave · `L L H` Whirlwind · `L L L H` Ground Slam · `L L L L H` Piercing Thrust. Dodge cancels attacks after their cancel point; dodging an attack at the last moment (first 0.15 s of the dodge) = **Perfect Dodge** → slow motion + next hit is a guaranteed crit with +50% damage.

Skill combos (Vanguard): Iron Charge → Rending Slash = **Breaker** (guaranteed crit) · War Cry → Earthsplitter = **Fury Quake** (+50%) · Flame Edge → Earthsplitter = **Molten Rift** (+30%, extra stagger).

Cheats (debug, `~`): tp, god, heal, kill_all, spawn, timescale, lock, autoattack, pos, level, xp, nocd, gold, press, save, load, time, day, weather, list_secrets, reveal_secrets, secret, counter, help.
