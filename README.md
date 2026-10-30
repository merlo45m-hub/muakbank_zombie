# Muakbank Zombie

Third-person 3D zombie survival game — **Godot 4.7**, Android target.

Eat food to restore health, fight off zombie animals, survive the shift.

## Play

- **Desktop**: open `project.godot` in Godot 4.7 and press F5.
- **Android**: export with the `Android` preset (`build/muakbank_zombie.apk`).

### Controls

| Action | Desktop | Mobile |
|--------|---------|--------|
| Move | WASD | Left joystick |
| Look | Mouse | Drag |
| Attack | Left click | ATTACK button |
| Special ability | G | SPECIAL button |
| Sprint | Shift (hold) | SPRINT button |
| Jump | Space | JUMP button |
| Swap weapon | Tab | SWAP button |
| Aim | Right click | — |
| Pause | Esc | — |

## Project layout

```
scripts/
  core/         Game, Player, SaveManager, LevelManager, GameAudioManager, ShaderManager,
                GameStateManager, AchievementManager, DifficultyManager, DevMode,
                ProceduralAnimator (procedural rigs)
  characters/   ZombieBase + 5 zombie types + ZombieBoss + ZombieSpawner3D + CharacterStats
  gameplay/     FoodItem3D, FoodSpawner, WeaponSystem, WeaponPickup, PowerUp, PowerUpManager,
                WaveManager, ComboSystem, ObjectiveManager, LootTable, DamagePopup, CameraShake,
                DayNightCycle, WeatherSystem, HitFeedback, MobileControls, PropScatter, and the
                mini-game controllers (BioGenerator, SpoilAndSurvive, LastStandStation,
                TriageRoundup, QuarantineBreach, ArmoryLockdown, EndgameExtraction)
  ui/           TitleScreen, CharacterSelect, LevelSelect, HUD, PauseMenu, Settings, GameOver, Credits
  world/        interactive props: InteractiveDoor, BreakableSupplyCrate, CheckpointArmoryTerminal, FoodCrate
scenes/
  main/         title_screen, game, game_over, pause_menu, settings, credits, HUD
  ui/           character_select, level_select
  characters/   5 player characters + 5 zombies + boss
  world/
    environment/ 3 open-world sandboxes: old_town_enhanced, industrial_district, endgame_heights
                 (folded sub-environments: cemetery, hospital, warehouse, subway, rooftop, mall, sewer)
    props/       reusable crate, barrel, pallet, debris_pile
  minigames/     keep_generator_fed, spoil_and_survive, last_stand_station, triage_roundup,
                 quarantine_breach, armory_lockdown, endgame_extraction
audio/          music (4), sfx (16), ambient (7 per-environment)
assets/
  models/       13 GLB — 5 zombies, 5 characters, 3 weapons
  textures/     157 PNG — food, characters, environment, 100 horror, 20 UI
  materials/    18 .tres
  animations/   20 .anim
  fonts/        NotoSans, Creepster, Nosifer, Bungee, LilitaOne, Poppins, SpecialElite
addons/         VectorFieldNavigation, godot-object-pool, SaveMadeEasy,
                godotx_health_bar, minos_damage_numbers, sound_manager
shaders/        12 .gdshader
tools/          validate_project.py — static project validator
                regression_smoke.sh — canonical headless smoke gate (REGRESSION: PASS)
                minigame_win_probe / addon_probe — headless win-state + food-API probes
tests/          GDUnit4 suite (tests/*_test.gd) — inventory, weapons, mini-game win
                conditions, level-completion gate, sandbox controllers, mobile UI
```


## Systems

- **Waves** — progressive waves; a boss spawns on the final wave
- **Combo** — consecutive kills build a score multiplier
- **Difficulty** — dynamic scaling from player performance
- **Power-ups** — health, speed, damage, shield, frenzy
- **Loot** — zombies drop food (weighted) and rare weapons
- **Objectives / achievements** — tracked and persisted
- **Day/night + weather** — cycling lighting and clear/rain/fog/storm
- **Navigation** — VectorFieldNavigation for horde movement
- **Pooling** — zombies are pooled and reused

## Assets & licensing

- Audio: Kenney.nl (CC0), OpenGameART (CC0 / CC-BY 3.0), Freesound-sourced
- Textures: Screaming Brain Studios Horror Texture Pack (CC0), generated placeholders
- Addons: MIT

CC0 assets need no attribution; CC-BY assets (horror ambient, rain loop) require a
credits line.

## Validation

Godot can't run headless on this Android/Termux setup (the Linux binary needs glibc),
so run the static validator before committing:

```bash
python3 tools/validate_project.py
```

On the VPS (glibc), the canonical gates are the smoke suite and the GDUnit tests:
`bash tools/regression_smoke.sh` (must print `REGRESSION: PASS`) and the GDUnit
headless run (see CHANGELOG for the exact command). The gate enumerates all seven
embedded mini-games and boots the 3-sandbox game scene.

It catches what subagent-generated scenes and folder reorganisations break: missing
`[gd_scene]` headers, `[<node` tags, node headers closed with `>` instead of `]`,
`PointLight3D` (Godot 3), missing root nodes, broken `res://` references, and Godot 3
APIs in scripts.
