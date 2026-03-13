#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
from typing import Any


def contains_any(text: str, keywords: list[str]) -> bool:
    return any(keyword in text for keyword in keywords)


def build_updates(prompt: str, obj: dict[str, Any]) -> dict[str, Any]:
    normalized = prompt.lower().strip()
    updates: dict[str, Any] = {}
    notes: list[str] = []

    if not normalized:
        return {"updates": updates, "notes": ["empty prompt"]}

    if contains_any(normalized, ["move", "移动", "walk", "run"]):
        updates["behaviors/movement"] = {
            "enabled": True,
            "mode": "topdown",
            "speed": 120.0,
            "camera_follow": True,
        }
        notes.append("movement template applied")

    if contains_any(normalized, ["camera", "镜头", "跟随"]):
        movement = updates.get("behaviors/movement", obj.get("behaviors", {}).get("movement", {}))
        movement["enabled"] = True
        movement["camera_follow"] = True
        movement.setdefault("speed", 120.0)
        updates["behaviors/movement"] = movement
        notes.append("camera follow template applied")

    if contains_any(normalized, ["collision", "碰撞", "solid", "阻挡"]):
        updates["solid"] = True
        notes.append("collision enabled")

    if contains_any(normalized, ["dialog", "对话", "npc", "talk"]):
        updates["interactable"] = True
        updates["trigger_mode"] = "interact"
        if not obj.get("dialogue"):
            updates["dialogue"] = "你好，我是 CLI 生成的默认对话。"
        notes.append("dialog template applied")

    if contains_any(normalized, ["door", "切换场景", "teleport", "传送"]):
        updates["interactable"] = True
        updates["trigger_mode"] = "touch"
        updates["behaviors/scene_transition"] = {
            "enabled": True,
            "target_scene": "res://scenes/placeholder_target.tscn",
        }
        notes.append("scene transition template applied")

    if contains_any(normalized, ["chest", "宝箱", "reward", "loot"]):
        updates["interactable"] = True
        updates["trigger_mode"] = "interact"
        updates["behaviors/reward"] = {
            "enabled": True,
            "item_id": "sample_item",
            "amount": 1,
        }
        notes.append("reward template applied")

    if not notes:
        notes.append("no built-in template matched")

    return {"updates": updates, "notes": notes}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--object-json", default="{}")
    args = parser.parse_args()

    try:
        obj = json.loads(args.object_json)
    except json.JSONDecodeError:
        obj = {}

    print(json.dumps(build_updates(args.prompt, obj), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
