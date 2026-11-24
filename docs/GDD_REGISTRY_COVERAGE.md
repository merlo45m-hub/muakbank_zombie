# GDD registry coverage gate (§5 / §7)

Probe: `tools/tests/registry_coverage_probe.gd`, wired into the fast-probe manifest.

Coverage proved at real sinks on a clean user-data home:
- 5 survivors (`gamer`, `doctor`, `nurse`, `streamer`, `hunter`) registered through `CharacterRegistry` from `characters.json`, each with a resolvable scene and health/speed/damage stats.
- 5 zombie animals (`dog`, `cat`, `bear`, `rabbit`, `chicken`) recorded through `CollectionManager.record_defeat` and visible in the `Bestiary` facade with non-zero kills.
- 6 core props from `dismantle_tables.json` recorded through `CollectionManager.record_dismantle` and visible in `CollectionLog.union()` with exactly one quantity increment each.
- `CollectionLog` and `Bestiary` expose no writer methods; `Save` registry keys contain every registered id.

Marker: `REGISTRY_COVERAGE_PASS=true survivors=5 animals=5 props=6`.
