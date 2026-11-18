# GDScript typing conventions (mandatory)

Adopted 2026-11-15 after four real type-mismatch failures in this repo. The
automated guard is `python3 tools/check_gdscript_typing.py .` (wired into the
CI static-gate). It must print `TYPING_FINDINGS=0`.

## Rules

1. **Never use `:=` on a call through an untyped `Node` / Variant.**
   GDScript cannot infer the return type. Use explicit annotations:
   `var d: Dictionary = wp.serialize()`, `var n: Node = get_node_or_null(...)`.
   Seen: `var snap := wp.serialize()` -> *Cannot infer the type of "snap"*.

2. **Typed arrays need `.assign()` when the source is untyped (JSON, a plain
   literal, or a Variant).** `@export var edges: Array[Dictionary]` cannot take
   `c.edges = rows`. Do:
   `var typed: Array[Dictionary] = []; typed.assign(rows); c.edges = typed`.
   Seen: *Invalid assignment of property 'edges' with value of type 'Array'*
   and *Invalid assignment of property 'visited_regions' ... 'Array'* (the
   latter also failed because it was assigned through a `Node` reference).

3. **Dictionary loop keys are Variant.** `var cb := "_on_" + sig` cannot infer;
   use `var cb: String = "_on_" + sig`.

4. **Comparison results in `:=` can fail on some expressions** — annotate
   `var ok: bool = ...` when the operands are non-trivial.

5. **JSON round-trips lose int types.** `_coerce()` already handles this;
   any new `world_*` / `game_*` key must be added to `_default_save_data()`
   AND `_coerce()` with an explicit `Array[int]`.assign() or Dictionary guard.

## Why this matters
Godot's `--headless --import` exits 0 even when scripts fail to parse, so a
type-inference error can ship silently. The static validator plus this typing
guard are the only automated catch before a device build.
