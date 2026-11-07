<p align="center"><img src="assets/branding/ascendant_banner.png" width="720" alt="ASCENDANT"></p>

# ASCENDANT

> **ascendant-builder** — repo ini khusus untuk *build*: GitHub Actions membangun APK Android dan versi Windows dari snapshot kode terbaru, hasilnya ada di **Releases → latest**. Pengembangan utama tidak dilakukan di sini.

**Third-person 3D action RPG · Open world · Anime cel-shaded**
Windows (full version) · Android 14+

> The world is fractured by *Gates* — rifts into monster dimensions. You are the weakest Hunter alive, rank E.
> After nearly dying inside a mysterious Double Gate, you wake up to a blue interface only you can see: **the Codex**.
> It gives you quests. It punishes you. It rewards you with things it never explains.
> Close the Gates, uncover what the Codex is hiding, and rise from the weakest to the strongest.

## Features (planned)

- Fast, combo-heavy combat with dodge counters, lock-on, and 15 elemental reactions across 9 elements
- Four starting classes with job changes — and paths nobody will tell you about
- A seamless open world with dynamic Gates ranked E to S, Red Gates, and Dungeon Breaks
- Hidden missions, sealed chests, cursed and evolving items, puzzles, and secret rooms everywhere
- Day/night cycle and weather that change what can be found
- Offline single-player

## Tech

- Engine: Godot 4 (GDScript)
- Targets: Windows x86_64, Android arm64 (API 34+)

## Status

Early development.

## Builds

Exports run on GitHub Actions (`.github/workflows/build.yml`), not on the dev machine:
every push to `main` builds the Android share APK and the Windows version, runs the unit
tests, and publishes them as the rolling **latest** release. Other targets (debug APK, AAB)
and other branches: *Actions → Build → Run workflow*. Local exports still work with
`tools/build.sh` when the machine has enough memory.
