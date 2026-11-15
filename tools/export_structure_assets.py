"""Export verified screen structures + classifications into Blender-ready asset
definitions for an exploded-view 3D layout, WITH A LOCKED SCALE CONTRACT.

Source of truth: assets/data/screen_visual_state.json (WatchSkill-extracted,
verified in game state at commit 2f01719).

HONEST SCALE NOTE
The source data is 2D SCREEN-SPACE pixel boxes from 3120x1440 captures, NOT
world coordinates. We therefore define an EXPLICIT, documented calibration (see
scale_calibration below). These are DECLARATIVE design constants, not
measurements of the game world. All derived metres are recomputed from them.

SCALE LOCK (this revision)
Each scoped mesh carries an immutable scale contract so that swapping the flat
plate for a custom sculpted mesh CANNOT silently change its bounding box:
  - identity object scale (1,1,1), applied/baked into mesh data,
  - NO parent transform inheritance,
  - NO unapplied modifiers may alter the evaluated bounding box,
  - evaluated depsgraph bbox must equal locked_dimensions_m within 0.001 m.
The contract is hashed (scale_contract_sha256) so post-import drift is detectable.
"""
from __future__ import annotations
import hashlib, json, os, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "assets", "data", "screen_visual_state.json")
DST = os.path.join(REPO, "assets", "data", "blender_structure_assets.json")

PX_PER_M = 1000.0
SCREEN_W_M = 3120.0 / PX_PER_M
SCREEN_H_M = 1440.0 / PX_PER_M
PANEL_DEPTH_M = 0.02
EXPLODE_STEP_M = 0.35
BBOX_TOLERANCE_M = 0.001

CLASS_COLOR = {
    "wordmark":  "#c8102e",
    "button":    "#8a5a2b",
    "heading":   "#6fa8ff",
    "level_card":"#a05cff",
    "status":    "#2de0ff",
    "character": "#ffd60a",
    "hud":       "#61cb8b",
    "label":     "#9aa0aa",
}

def classify(text: str, screen: str) -> str:
    t = text.upper().strip()
    if "MUAK" in t or "MOKBANK" in t:
        return "wordmark"
    if screen == "start" and t in {"PLAY", "LEVELS", "SETTINGS", "CREDITS", "QUIT"}:
        return "button"
    if t in {"PLAY", "PLAY NOW", "TAP TO PLAY", "BACK", "PREV PAGE", "NEXT PAGE", "QUIT"}:
        return "button"
    if "SELECT YOUR" in t or "TAP A LEVEL" in t:
        return "heading"
    if t.startswith("LEVEL ") or t in {"LOCKED", "PAGE1/1", "1", "3"}:
        return "level_card"
    if any(k in t for k in ("HEALTH", "WAVE", "HYPE", "OVERWHELM", "STATION READY", "SPRINT", "SPECIAL")):
        return "status"
    if screen == "player" and any(k in t for k in ("DOCTOR", "MEDIC", "SURGEON", "OFFICER", "WHITE")):
        return "character"
    if screen == "final":
        return "hud"
    return "label"


def box_to_metrics(box):
    xs = [p[0] for p in box]; ys = [p[1] for p in box]
    x0, x1 = min(xs), max(xs); y0, y1 = min(ys), max(ys)
    cx = (x0 + x1) / 2.0; cy = (y0 + y1) / 2.0
    w = max(x1 - x0, 1.0); h = max(y1 - y0, 1.0)
    return {
        "assembled_position_m": [round((cx - 1560.0) / PX_PER_M, 4),
                                 round((720.0 - cy) / PX_PER_M, 4), 0.0],
        "dimensions_m": [round(w / PX_PER_M, 4), round(h / PX_PER_M, 4), PANEL_DEPTH_M],
        "source_box_px": box,
    }


def scale_lock_for(part_id, dims):
    return {
        "part_id": part_id,
        "locked_scale": [1.0, 1.0, 1.0],
        "locked_dimensions_m": dims,
        "apply_transforms": True,
        "transform_inheritance": "forbidden",
        "modifier_policy": "bake_and_remeasure",
        "bbox_tolerance_m": BBOX_TOLERANCE_M,
        "unit": "1 Blender unit = 1 metre (METRIC, scale_length=1.0)",
        "verify_on_import": "tools/blender/verify_scale_contract.py",
    }


def main() -> int:
    with open(SRC, encoding="utf-8") as f:
        state = json.load(f)
    calibration = {
        "note": "DECLARATIVE 2D-screen-to-metre mapping; NOT measured world coords.",
        "screen_resolution_px": [3120, 1440],
        "px_per_m": PX_PER_M,
        "screen_width_m": SCREEN_W_M,
        "screen_height_m": SCREEN_H_M,
        "panel_depth_m": PANEL_DEPTH_M,
        "explode_axis": "+X",
        "explode_step_m": EXPLODE_STEP_M,
        "up_axis": "+Z",
        "forward_axis_godot": [0, 0, -1],
        "gltf_export_yup": True,
        "godot_root_scale": 1.0,
        "scale_lock_policy": {
            "object_scale": [1.0, 1.0, 1.0],
            "bake_scale_into_mesh": True,
            "allow_parent_transform": False,
            "allow_unapplied_modifiers": False,
            "bbox_tolerance_m": BBOX_TOLERANCE_M,
        },
    }
    out = {
        "schema_version": 2,
        "generator": "tools/export_structure_assets.py",
        "source": "assets/data/screen_visual_state.json (WatchSkill extraction, verified)",
        "source_sha256": hashlib.sha256(open(SRC, "rb").read()).hexdigest(),
        "scale_calibration": calibration,
        "materials": CLASS_COLOR,
        "assemblies": [],
    }
    total = 0
    locks = []
    for label in ["start", "player", "level", "final"]:
        scr = state["screens"][label]
        parts = []
        for i, item in enumerate(scr["ocr_items"]):
            text = item.get("text", "")
            cls = classify(text, label)
            m = box_to_metrics(item["box"])
            pid = "%s_%02d" % (label, i)
            lock = scale_lock_for(pid, m["dimensions_m"])
            locks.append(lock)
            parts.append({
                "part_id": pid,
                "assembly": label,
                "order": i,
                "label_text": text,
                "classification": cls,
                "material_color": CLASS_COLOR[cls],
                "confidence": item.get("confidence"),
                "assembled_position_m": m["assembled_position_m"],
                "explode_offset_x_m": round(i * EXPLODE_STEP_M, 4),
                "dimensions_m": m["dimensions_m"],
                "source_box_px": m["source_box_px"],
                "collision_suffix": "-convcol",
                "scale_lock": lock,
            })
        out["assemblies"].append({
            "assembly_id": label,
            "screen_file": scr["file"],
            "screen_sha256": scr["sha256"],
            "brightness": scr["visual"]["brightness"],
            "dark_scene": scr["visual"]["dark_scene"],
            "markers": scr["markers_detected"],
            "part_count": len(parts),
            "parts": parts,
        })
        total += len(parts)
    out["total_parts"] = total
    # Canonical lock order (by part_id) so the verifier can recompute the same
    # hash from the exported JSON alone.
    locks_canonical = sorted(locks, key=lambda l: l["part_id"])
    contract = {"calibration": calibration, "locks": locks_canonical}
    payload = json.dumps(contract, sort_keys=True, separators=(",", ":")).encode("utf-8")
    out["scale_contract_sha256"] = "sha256:" + hashlib.sha256(payload).hexdigest()
    with open(DST, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False, sort_keys=False)
    print("EXPORTED", DST, "bytes", os.path.getsize(DST))
    print("ASSEMBLIES", len(out["assemblies"]), "PARTS", total)
    print("SCALE_CONTRACT_SHA256", out["scale_contract_sha256"])
    for a in out["assemblies"]:
        print("  ", a["assembly_id"], a["part_count"], "parts",
              sorted({p["classification"] for p in a["parts"]}))
    return 0

if __name__ == "__main__":
    sys.exit(main())
