# Changelog

All notable changes to **Muakbank Zombie** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims for [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **3-sandbox restructure (v0.3.0)** — the campaign is now exactly three big
  open-world sandbox levels, each with embedded mini-games that must all clear
  to advance:
  - **SAND1 Old Town** — five embedded mini-games: Keep the Generator Fed,
    Spoil & Survive, Last Stand Station, Triage Roundup, Quarantine Breach.
  - **SAND2 Industrial District** — hospital + warehouse folded in; adds the
    **Armory Lockdown** mini-game (`ArmoryLockdownController`, `l2_armory_salvage`).
  - **SAND3 Endgame Heights** — rooftop + sewers + mall folded in; adds the
    **Endgame Extraction** mini-game (`EndgameExtractionController`, `l3_rooftop_extraction`).
  - Difficulty / enemy pool / ambient escalate 1.0 → 1.6 → 2.5
    (`scripts/core/LevelManager.gd`). Level completion is gated on all embedded
    mini-games clearing (`Game.gd._all_minigames_done()` scoped per level).
- **Smoke-gate coverage for the new sandboxes** — `tools/minigame_win_probe.gd`
  now also drives Armory Lockdown + Endgame Extraction to WON; the regression
  gate enumerates all 7 embedded mini-games.
- **GDUnit4 unit-test framework** (`addons/gdUnit4`, v6.2.2 — the maintained
  Godot 4.x fork, verified on 4.7) with an editable-driven suite under
  `tests/`:
  - `player_inventory_test.gd` — Player GLoot-backed food inventory math
    (`get_food_count` / `get_food_heal` / `add_food` / `consume_food_type` /
    `has_food`) against the real Player scene.
  - `minigame_win_conditions_test.gd` — Bio Generator, Spoil & Survive and
    Last Stand Station controllers reach their `WON` state when their win
    condition is met (and not before), driven through the real mini-game scenes.
  - `weapon_system_test.gd` — trade rules, ammo gates and inventory cycling.
- This changelog.

### How to run the tests

```bash
cd /root/muakbank_zombie
xvfb-run -a /root/Godot_v4.7-stable_linux.x86_64 --headless \
    --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
    -a res://tests --ignoreHeadlessMode
```

(or `./addons/gdUnit4/runtest.sh -a res://tests` with `GODOT_BIN` set).
The suite must print a green count and exit 0.

## 2026-10-29 — v0.2.0 — Level 1 foundations

### Added

- **GLoot-backed player food inventory** — food is stored in a real GLoot
  `Inventory` (one stacked item per food type, heal value remembered from the
  pickup scene) behind the unchanged `get_food_count` / `has_food` /
  `get_food_heal` / `add_food` / `consume_food_type` API, so eating from the
  bar and walking over food always agree.
- **Dialogue Manager + tutorial** — `res://resources/dialogue/tutorial_intro.dialogue`
  wiring and the tutorial balloon flow for new players.
- **Statecharts enemy AI** — `godot-statecharts` finite-state machine driving
  the zombie base mock (idle → chase/attack transitions).
- **Canonical regression smoke gate** — `tools/regression_smoke.sh` (5 checks:
  fresh import, dev-scene boot, game-scene boot, player food API/GLoot probe,
  all three mini-game WIN states). Gate green = exit 0 + `REGRESSION: PASS`.
- **Release-signed export lane** in `tools/export_on_vps.sh`.

### Changed

- Theme pass: full zombie/muckbank `main_theme.tres` assembled per DESIGN.md;
  Creepster display-font variation applied to title, credits, settings and
  game-over headers.
- Generator starting fuel buffed 40 → 60 (mini-game pacing).

### Fixed

- Zombie animation guard — clip playback no longer throws when the rig has no
  matching animation; skeletal animator wiring repaired.
- Level 1 scale pass — chicken/rabbit rescaled 0.26× → 0.67/0.70×, parked cars
  2.5 → 1.0–1.1, so props read correctly against the world.
- Export tooling re-wired to the `rescue/muakbank-work` layout with the `vps`
  alias and correct export preset.
