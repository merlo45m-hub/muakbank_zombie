# GDD registry coverage gate (§5 / §7)

Probe: `tools/tests/registry_coverage_probe.gd`, wired into the fast-probe manifest. Run with a fresh `HOME` for deterministic counts; disk reload persistence is covered by the separate cure-persistence harness.

Coverage proved through the production registry APIs, facades, and emitter source contracts:
- 5 survivors (`gamer`, `doctor`, `nurse`, `streamer`, `hunter`) registered through `CharacterRegistry` from `characters.json`, each with a resolvable scene and health/speed/damage stats.
- 5 zombie animal ids derived from `ZombieSpawner3D.gd`, recorded through `CollectionManager.record_defeat`, and visible in the `Bestiary` facade with non-zero kills.
- 6 core props from `dismantle_tables.json` recorded through `CollectionManager.record_dismantle` and visible in `CollectionLog.union()` with exactly one quantity increment each.
- `CollectionLog` and `Bestiary` expose no registry writer or save methods; `Save` in-memory registry state contains every registered id after the sole-writer calls. Source-contract checks confirm `Game.gd`, `DismantleComponent.gd`, and `CharacterSelect.gd` call/expose the same ids and APIs.

Marker: `REGISTRY_COVERAGE_PASS=true survivors=5 animals=5 props=6`.
