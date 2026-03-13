class_name LogicTemplates
extends RefCounted

enum TemplatePriority { LOW = 0, MEDIUM = 1, HIGH = 2 }

static func apply_prompt(prompt: String, object_data: Dictionary) -> Dictionary:
	var normalized := prompt.to_lower().strip_edges()
	var updates := {}
	var notes: Array[String] = []
	var matched_trigger_mode := ""
	var trigger_priority := -1

	if normalized.is_empty():
		return {"updates": updates, "notes": ["AI 指令为空，未生成逻辑。"]}

	if _contains_any(normalized, ["move", "移动", "walk", "run"]):
		updates["behaviors/movement"] = {
			"enabled": true,
			"mode": "topdown",
			"speed": 120.0,
			"camera_follow": true,
		}
		notes.append("已为对象启用俯视角移动模板。")

	if _contains_any(normalized, ["camera", "镜头", "跟随"]):
		var movement_update: Dictionary = updates.get("behaviors/movement", object_data.get("behaviors", {}).get("movement", {}))
		movement_update["enabled"] = true
		movement_update["camera_follow"] = true
		if not movement_update.has("speed"):
			movement_update["speed"] = 120.0
		updates["behaviors/movement"] = movement_update
		notes.append("已为对象启用镜头跟随模板。")

	if _contains_any(normalized, ["collision", "碰撞", "solid", "阻挡"]):
		updates["solid"] = true
		notes.append("已启用碰撞标记。")

	if _contains_any(normalized, ["door", "切换场景", "teleport", "传送"]):
		updates["interactable"] = true
		updates["behaviors/scene_transition"] = {
			"enabled": true,
			"target_scene": "res://scenes/placeholder_target.tscn",
		}
		if TemplatePriority.HIGH > trigger_priority:
			matched_trigger_mode = "touch"
			trigger_priority = TemplatePriority.HIGH
		notes.append("已添加切场景模板。")

	elif _contains_any(normalized, ["chest", "宝箱", "loot", "reward"]):
		updates["interactable"] = true
		updates["behaviors/reward"] = {
			"enabled": true,
			"item_id": "sample_item",
			"amount": 1,
		}
		if TemplatePriority.MEDIUM > trigger_priority:
			matched_trigger_mode = "interact"
			trigger_priority = TemplatePriority.MEDIUM
		notes.append("已添加奖励模板。")

	elif _contains_any(normalized, ["trigger", "区域", "event", "剧情"]):
		updates["behaviors/event"] = {
			"enabled": true,
			"event_id": "sample_event",
		}
		if TemplatePriority.MEDIUM > trigger_priority:
			matched_trigger_mode = "area"
			trigger_priority = TemplatePriority.MEDIUM
		notes.append("已添加区域事件模板。")

	if _contains_any(normalized, ["dialog", "对话", "npc", "talk"]):
		updates["interactable"] = true
		if String(object_data.get("dialogue", "")).is_empty():
			updates["dialogue"] = "你好，我是由 AI 自动绑定的对话对象。"
		if TemplatePriority.LOW > trigger_priority:
			matched_trigger_mode = "interact"
			trigger_priority = TemplatePriority.LOW
		notes.append("已添加对话交互模板。")

	if not matched_trigger_mode.is_empty():
		updates["trigger_mode"] = matched_trigger_mode

	if notes.is_empty():
		notes.append("未识别到预置模板关键词，已保留指令供后续 CLI/模型扩展。")

	return {
		"updates": updates,
		"notes": notes,
	}

static func _contains_any(text: String, keywords: Array[String]) -> bool:
	for keyword in keywords:
		if text.contains(keyword):
			return true
	return false
