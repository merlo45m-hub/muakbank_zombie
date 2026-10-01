class_name DevMode
extends RefCounted

## DevMode — the single source of truth for "should dev tooling be active?"
##
## WHY THIS EXISTS (do not replace with OS.is_debug_build()):
##   The Android APK is exported with `--export-debug` (see ~/bin/deploy_pipeline.sh), so
##   OS.is_debug_build() returns TRUE in the SHIPPED build. Gating dev tooling on it ships
##   that tooling to every player. An exported APK is an export-TEMPLATE build, so
##   OS.has_feature("editor") is false for it — that is the reliable discriminator.
##
## WHERE THIS FILE LIVES AND WHY:
##   scripts/core/, NOT scripts/dev/. This is a gate primitive that SHIPPED code must be
##   able to `preload()` (scripts/ui/DevMenu.gd does). Anything under scripts/dev/ is
##   forbidden from being preloaded by shipped code — see tools/gate_dev_isolation.sh.
##   Relying on the global class cache instead would break on a fresh clone, because
##   .godot/ (which holds global_script_class_cache.cfg) is gitignored.
##
## RULE:
##   - In the editor (F5/F6) dev tooling is always on — that is the whole point.
##   - In an exported build it is OFF unless someone deliberately opts in by creating the
##     marker file `user://dev_mode` (long-press the title-screen footer to toggle it).
##
## Usage (shipped code):
##   const DevMode := preload("res://scripts/core/DevMode.gd")
##   if DevMode.is_active(): ...
## Never cache the result across a frame boundary; it is cheap (a file_exists call).

const MARKER_PATH := "user://dev_mode"
const MARKER_VERSION := "1"


## True when dev tooling (dev_room, DebugOverlay, title dev menu) should run.
static func is_active() -> bool:
	if OS.has_feature("editor"):
		return true
	if not FileAccess.file_exists(MARKER_PATH):
		return false
	var f := FileAccess.open(MARKER_PATH, FileAccess.READ)
	if not f:
		return false
	var content := f.get_as_text().strip_edges()
	f.close()
	return content == MARKER_VERSION


## True only when running inside the Godot editor (never true in an exported build).
static func is_editor() -> bool:
	return OS.has_feature("editor")


## Turn dev mode on. Safe to call repeatedly.
static func enable() -> void:
	var f := FileAccess.open(MARKER_PATH, FileAccess.WRITE)
	if f:
		f.store_string(MARKER_VERSION)
		f.close()


## Turn dev mode off. Returns true if the marker is absent after the call.
static func disable() -> bool:
	if FileAccess.file_exists(MARKER_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MARKER_PATH))
	return not FileAccess.file_exists(MARKER_PATH)


## Flip dev mode on an exported build. Returns the NEW state.
## In the editor this only ever enables (the editor gate cannot be turned off).
static func toggle() -> bool:
	if is_active() and not is_editor():
		disable()
	else:
		enable()
	return is_active()
