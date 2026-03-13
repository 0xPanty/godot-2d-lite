#!/usr/bin/env python3
"""Lite2D Studio CLI — Agent-friendly command-line interface.

Usage:
    python ai_cli_bridge.py list-objects
    python ai_cli_bridge.py add-object --type npc --name "Village Elder" --x 200 --y 300
    python ai_cli_bridge.py set-property --id obj_2 --key solid --value true
    python ai_cli_bridge.py set-behavior --id obj_2 --behavior movement --data '{"enabled":true,"speed":100}'
    python ai_cli_bridge.py paint-tile --x 5 --y 3 --terrain wall --layer collision
    python ai_cli_bridge.py erase-tile --x 5 --y 3 --layer collision
    python ai_cli_bridge.py list-tiles [--layer ground]
    python ai_cli_bridge.py apply-prompt --id obj_2 --prompt "让这个NPC可以对话"
    python ai_cli_bridge.py export-snapshot
    python ai_cli_bridge.py import-snapshot --file snapshot.json
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

SNAPSHOT_FILENAME = "editor_state.json"


def _find_snapshot_path() -> Path:
    if os.name == "nt":
        base = Path(os.environ.get("APPDATA", Path.home() / "AppData" / "Roaming"))
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
    return base / "Godot" / "app_userdata" / "Lite2D Studio" / SNAPSHOT_FILENAME


def load_snapshot(path: Path | None = None) -> dict:
    p = path or _find_snapshot_path()
    if not p.exists():
        return {"resources": [], "scene_objects": [], "next_object_id": 1, "tile_cells": []}
    return json.loads(p.read_text(encoding="utf-8"))


def save_snapshot(data: dict, path: Path | None = None) -> None:
    p = path or _find_snapshot_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def _next_id(data: dict) -> int:
    return int(data.get("next_object_id", 1))


def cmd_list_objects(args: argparse.Namespace) -> int:
    data = load_snapshot()
    objects = data.get("scene_objects", [])
    result = []
    for obj in objects:
        result.append({
            "id": obj.get("id", ""),
            "name": obj.get("name", ""),
            "type": obj.get("type", ""),
            "position": obj.get("position", {}),
            "solid": obj.get("solid", False),
            "interactable": obj.get("interactable", False),
        })
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def cmd_add_object(args: argparse.Namespace) -> int:
    data = load_snapshot()
    idx = _next_id(data)
    obj_type = args.type or "prop"
    obj: dict[str, Any] = {
        "id": f"obj_{idx}",
        "name": args.name or f"{obj_type.capitalize()} {idx}",
        "type": obj_type,
        "position": {"x": args.x, "y": args.y},
        "size": {"x": 96, "y": 96},
        "resource_path": "",
        "solid": obj_type in ("player", "npc", "door", "chest", "prop"),
        "interactable": obj_type in ("npc", "door", "chest", "trigger"),
        "trigger_mode": "area" if obj_type == "trigger" else "interact",
        "dialogue": "",
        "behaviors": {},
    }
    if obj_type == "player":
        obj["behaviors"]["movement"] = {
            "enabled": True, "mode": "topdown", "speed": 120.0, "camera_follow": True,
        }
    data.setdefault("scene_objects", []).append(obj)
    data["next_object_id"] = idx + 1
    save_snapshot(data)
    print(json.dumps({"ok": True, "id": obj["id"], "name": obj["name"]}, ensure_ascii=False))
    return 0


def cmd_set_property(args: argparse.Namespace) -> int:
    data = load_snapshot()
    for obj in data.get("scene_objects", []):
        if obj.get("id") == args.id:
            try:
                value = json.loads(args.value)
            except (json.JSONDecodeError, TypeError):
                value = args.value
            if value == "true":
                value = True
            elif value == "false":
                value = False
            obj[args.key] = value
            save_snapshot(data)
            print(json.dumps({"ok": True, "id": args.id, "key": args.key, "value": value}, ensure_ascii=False))
            return 0
    print(json.dumps({"ok": False, "error": f"Object {args.id} not found"}))
    return 1


def cmd_set_behavior(args: argparse.Namespace) -> int:
    data = load_snapshot()
    for obj in data.get("scene_objects", []):
        if obj.get("id") == args.id:
            behaviors = obj.setdefault("behaviors", {})
            try:
                behavior_data = json.loads(args.data)
            except json.JSONDecodeError:
                print(json.dumps({"ok": False, "error": "Invalid JSON in --data"}))
                return 1
            behaviors[args.behavior] = behavior_data
            save_snapshot(data)
            print(json.dumps({"ok": True, "id": args.id, "behavior": args.behavior}, ensure_ascii=False))
            return 0
    print(json.dumps({"ok": False, "error": f"Object {args.id} not found"}))
    return 1


def cmd_paint_tile(args: argparse.Namespace) -> int:
    data = load_snapshot()
    tiles = data.setdefault("tile_cells", [])
    layer = args.layer or "ground"
    for i, t in enumerate(tiles):
        if t.get("x") == args.x and t.get("y") == args.y and t.get("layer", "ground") == layer:
            tiles[i] = {"x": args.x, "y": args.y, "terrain": args.terrain, "layer": layer}
            save_snapshot(data)
            print(json.dumps({"ok": True, "action": "updated"}, ensure_ascii=False))
            return 0
    tiles.append({"x": args.x, "y": args.y, "terrain": args.terrain, "layer": layer})
    save_snapshot(data)
    print(json.dumps({"ok": True, "action": "added"}, ensure_ascii=False))
    return 0


def cmd_erase_tile(args: argparse.Namespace) -> int:
    data = load_snapshot()
    tiles = data.get("tile_cells", [])
    layer = args.layer or "ground"
    new_tiles = [t for t in tiles if not (t.get("x") == args.x and t.get("y") == args.y and t.get("layer", "ground") == layer)]
    removed = len(tiles) - len(new_tiles)
    data["tile_cells"] = new_tiles
    save_snapshot(data)
    print(json.dumps({"ok": True, "removed": removed}, ensure_ascii=False))
    return 0


def cmd_list_tiles(args: argparse.Namespace) -> int:
    data = load_snapshot()
    tiles = data.get("tile_cells", [])
    if args.layer:
        tiles = [t for t in tiles if t.get("layer", "ground") == args.layer]
    print(json.dumps(tiles, ensure_ascii=False, indent=2))
    return 0


def _contains_any(text: str, keywords: list[str]) -> bool:
    return any(kw in text for kw in keywords)


def cmd_apply_prompt(args: argparse.Namespace) -> int:
    data = load_snapshot()
    target = None
    for obj in data.get("scene_objects", []):
        if obj.get("id") == args.id:
            target = obj
            break
    if target is None:
        print(json.dumps({"ok": False, "error": f"Object {args.id} not found"}))
        return 1

    prompt = args.prompt.lower().strip()
    updates: dict[str, Any] = {}
    notes: list[str] = []

    if _contains_any(prompt, ["move", "移动", "walk", "run"]):
        updates["behaviors"] = target.get("behaviors", {})
        updates["behaviors"]["movement"] = {"enabled": True, "mode": "topdown", "speed": 120.0, "camera_follow": True}
        notes.append("movement template applied")
    if _contains_any(prompt, ["dialog", "对话", "npc", "talk"]):
        updates["interactable"] = True
        updates["trigger_mode"] = "interact"
        if not target.get("dialogue"):
            updates["dialogue"] = "你好，我是 CLI 生成的默认对话。"
        notes.append("dialog template applied")
    if _contains_any(prompt, ["door", "切换场景", "teleport", "传送"]):
        updates["interactable"] = True
        updates["trigger_mode"] = "touch"
        behaviors = updates.get("behaviors", target.get("behaviors", {}))
        behaviors["scene_transition"] = {"enabled": True, "target_scene": "res://scenes/placeholder_target.tscn"}
        updates["behaviors"] = behaviors
        notes.append("scene transition template applied")
    if _contains_any(prompt, ["collision", "碰撞", "solid"]):
        updates["solid"] = True
        notes.append("collision enabled")

    if not notes:
        notes.append("no built-in template matched; prompt preserved for AI model processing")

    for k, v in updates.items():
        target[k] = v
    save_snapshot(data)
    print(json.dumps({"ok": True, "updates": list(updates.keys()), "notes": notes}, ensure_ascii=False, indent=2))
    return 0


def cmd_export_snapshot(args: argparse.Namespace) -> int:
    data = load_snapshot()
    print(json.dumps(data, ensure_ascii=False, indent=2))
    return 0


def cmd_import_snapshot(args: argparse.Namespace) -> int:
    p = Path(args.file)
    if not p.exists():
        print(json.dumps({"ok": False, "error": f"File not found: {args.file}"}))
        return 1
    data = json.loads(p.read_text(encoding="utf-8"))
    save_snapshot(data)
    print(json.dumps({"ok": True, "objects": len(data.get("scene_objects", [])), "tiles": len(data.get("tile_cells", []))}))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(prog="lite2d", description="Lite2D Studio CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list-objects")

    p_add = sub.add_parser("add-object")
    p_add.add_argument("--type", default="prop")
    p_add.add_argument("--name", default="")
    p_add.add_argument("--x", type=float, default=96)
    p_add.add_argument("--y", type=float, default=96)

    p_set = sub.add_parser("set-property")
    p_set.add_argument("--id", required=True)
    p_set.add_argument("--key", required=True)
    p_set.add_argument("--value", required=True)

    p_beh = sub.add_parser("set-behavior")
    p_beh.add_argument("--id", required=True)
    p_beh.add_argument("--behavior", required=True)
    p_beh.add_argument("--data", required=True)

    p_pt = sub.add_parser("paint-tile")
    p_pt.add_argument("--x", type=int, required=True)
    p_pt.add_argument("--y", type=int, required=True)
    p_pt.add_argument("--terrain", required=True)
    p_pt.add_argument("--layer", default="ground")

    p_et = sub.add_parser("erase-tile")
    p_et.add_argument("--x", type=int, required=True)
    p_et.add_argument("--y", type=int, required=True)
    p_et.add_argument("--layer", default="ground")

    p_lt = sub.add_parser("list-tiles")
    p_lt.add_argument("--layer", default="")

    p_ap = sub.add_parser("apply-prompt")
    p_ap.add_argument("--id", required=True)
    p_ap.add_argument("--prompt", required=True)

    sub.add_parser("export-snapshot")

    p_imp = sub.add_parser("import-snapshot")
    p_imp.add_argument("--file", required=True)

    args = parser.parse_args()
    dispatch = {
        "list-objects": cmd_list_objects,
        "add-object": cmd_add_object,
        "set-property": cmd_set_property,
        "set-behavior": cmd_set_behavior,
        "paint-tile": cmd_paint_tile,
        "erase-tile": cmd_erase_tile,
        "list-tiles": cmd_list_tiles,
        "apply-prompt": cmd_apply_prompt,
        "export-snapshot": cmd_export_snapshot,
        "import-snapshot": cmd_import_snapshot,
    }
    return dispatch[args.command](args)


if __name__ == "__main__":
    raise SystemExit(main())
