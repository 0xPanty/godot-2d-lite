class_name QuestSystem
extends RefCounted

## Quest definition + condition trigger + completion detection.
## Quests have objectives (collect items, talk to NPC, reach location, set flag).

enum QuestStatus {
	LOCKED,      # 未解锁（前置条件未满足）
	AVAILABLE,   # 可接取
	ACTIVE,      # 进行中
	COMPLETED,   # 已完成（可交付）
	TURNED_IN,   # 已交付
}

enum ObjectiveType {
	COLLECT_ITEM,   # 收集物品
	TALK_TO,        # 与 NPC 对话
	REACH_LOCATION, # 到达指定位置
	SET_FLAG,       # 设置旗标
	KILL_COUNT,     # 击败指定数量
	CUSTOM,         # 自定义条件（旗标驱动）
}

static func create_quest(id: String, title: String, description: String = "") -> Dictionary:
	return {
		"id": id,
		"title": title,
		"description": description,
		"status": QuestStatus.AVAILABLE,
		"objectives": [],
		"rewards": [],
		"prerequisite_quests": [],
		"prerequisite_flags": [],
		"on_complete_flags": [],
		"on_turnin_flags": [],
		"giver_object_id": "",
		"turnin_object_id": "",
	}

static func create_objective(type: ObjectiveType, params: Dictionary = {}) -> Dictionary:
	return {
		"type": type,
		"params": params,
		"progress": 0,
		"completed": false,
	}

static func obj_collect(item_id: String, amount: int = 1) -> Dictionary:
	return create_objective(ObjectiveType.COLLECT_ITEM, {"item_id": item_id, "amount": amount})

static func obj_talk(object_id: String) -> Dictionary:
	return create_objective(ObjectiveType.TALK_TO, {"object_id": object_id})

static func obj_reach(x: float, y: float, radius: float = 64.0) -> Dictionary:
	return create_objective(ObjectiveType.REACH_LOCATION, {"x": x, "y": y, "radius": radius})

static func obj_flag(flag_name: String) -> Dictionary:
	return create_objective(ObjectiveType.SET_FLAG, {"flag": flag_name})

static func obj_kill(target_type: String, count: int = 1) -> Dictionary:
	return create_objective(ObjectiveType.KILL_COUNT, {"target_type": target_type, "count": count})

static func create_reward(type: String, params: Dictionary = {}) -> Dictionary:
	return {"type": type, "params": params}

static func reward_item(item_id: String, amount: int = 1) -> Dictionary:
	return create_reward("item", {"item_id": item_id, "amount": amount})

static func reward_flag(flag_name: String) -> Dictionary:
	return create_reward("flag", {"flag": flag_name})

# --- Quest journal operations ---

static func create_journal() -> Dictionary:
	return {"quests": {}}

static func add_quest(journal: Dictionary, quest: Dictionary) -> void:
	journal["quests"][String(quest.get("id", ""))] = quest.duplicate(true)

static func get_quest(journal: Dictionary, quest_id: String) -> Dictionary:
	return journal.get("quests", {}).get(quest_id, {})

static func accept_quest(journal: Dictionary, quest_id: String) -> bool:
	var quest: Dictionary = get_quest(journal, quest_id)
	if quest.is_empty():
		return false
	if int(quest.get("status", QuestStatus.LOCKED)) != QuestStatus.AVAILABLE:
		return false
	quest["status"] = QuestStatus.ACTIVE
	return true

static func check_objectives(journal: Dictionary, quest_id: String, flags: Dictionary, inventory: Dictionary, player_pos: Vector2) -> bool:
	var quest: Dictionary = get_quest(journal, quest_id)
	if quest.is_empty() or int(quest.get("status", 0)) != QuestStatus.ACTIVE:
		return false

	var all_done := true
	var objectives: Array = quest.get("objectives", [])
	for obj in objectives:
		if not obj is Dictionary:
			continue
		if bool(obj.get("completed", false)):
			continue

		var t: int = int(obj.get("type", 0))
		var p: Dictionary = obj.get("params", {})

		match t:
			ObjectiveType.COLLECT_ITEM:
				var item_id := String(p.get("item_id", ""))
				var needed: int = int(p.get("amount", 1))
				var has: int = _count_item_in_inventory(inventory, item_id)
				obj["progress"] = has
				if has >= needed:
					obj["completed"] = true

			ObjectiveType.SET_FLAG:
				var flag := String(p.get("flag", ""))
				if flags.get(flag, false):
					obj["completed"] = true
					obj["progress"] = 1

			ObjectiveType.REACH_LOCATION:
				var target := Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
				var radius := float(p.get("radius", 64.0))
				if player_pos.distance_to(target) <= radius:
					obj["completed"] = true
					obj["progress"] = 1

			ObjectiveType.KILL_COUNT:
				var needed: int = int(p.get("count", 1))
				if int(obj.get("progress", 0)) >= needed:
					obj["completed"] = true

			ObjectiveType.TALK_TO:
				if bool(obj.get("completed", false)):
					pass

			ObjectiveType.CUSTOM:
				var flag := String(p.get("flag", ""))
				if flags.get(flag, false):
					obj["completed"] = true
					obj["progress"] = 1

		if not bool(obj.get("completed", false)):
			all_done = false

	if all_done:
		quest["status"] = QuestStatus.COMPLETED
	return all_done

static func mark_talk_objective(journal: Dictionary, quest_id: String, object_id: String) -> void:
	var quest: Dictionary = get_quest(journal, quest_id)
	if quest.is_empty() or int(quest.get("status", 0)) != QuestStatus.ACTIVE:
		return
	for obj in quest.get("objectives", []):
		if int(obj.get("type", -1)) == ObjectiveType.TALK_TO:
			if String(obj.get("params", {}).get("object_id", "")) == object_id:
				obj["completed"] = true
				obj["progress"] = 1

static func increment_kill(journal: Dictionary, target_type: String) -> void:
	for quest in journal.get("quests", {}).values():
		if int(quest.get("status", 0)) != QuestStatus.ACTIVE:
			continue
		for obj in quest.get("objectives", []):
			if int(obj.get("type", -1)) == ObjectiveType.KILL_COUNT:
				if String(obj.get("params", {}).get("target_type", "")) == target_type:
					obj["progress"] = int(obj.get("progress", 0)) + 1

static func turn_in_quest(journal: Dictionary, quest_id: String) -> Dictionary:
	var quest: Dictionary = get_quest(journal, quest_id)
	if quest.is_empty() or int(quest.get("status", 0)) != QuestStatus.COMPLETED:
		return {"success": false, "rewards": []}
	quest["status"] = QuestStatus.TURNED_IN
	return {"success": true, "rewards": quest.get("rewards", []), "flags": quest.get("on_turnin_flags", [])}

static func check_prerequisites(journal: Dictionary, quest_id: String, flags: Dictionary) -> bool:
	var quest: Dictionary = get_quest(journal, quest_id)
	if quest.is_empty():
		return false
	for prereq_id in quest.get("prerequisite_quests", []):
		var prereq: Dictionary = get_quest(journal, String(prereq_id))
		if int(prereq.get("status", 0)) < QuestStatus.TURNED_IN:
			return false
	for flag_name in quest.get("prerequisite_flags", []):
		if not flags.get(String(flag_name), false):
			return false
	return true

static func unlock_available(journal: Dictionary, flags: Dictionary) -> Array[String]:
	var unlocked: Array[String] = []
	for quest_id in journal.get("quests", {}).keys():
		var quest: Dictionary = journal["quests"][quest_id]
		if int(quest.get("status", 0)) == QuestStatus.LOCKED:
			if check_prerequisites(journal, quest_id, flags):
				quest["status"] = QuestStatus.AVAILABLE
				unlocked.append(quest_id)
	return unlocked

static func get_active_quests(journal: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest in journal.get("quests", {}).values():
		if int(quest.get("status", 0)) == QuestStatus.ACTIVE:
			result.append(quest)
	return result

static func get_completed_quests(journal: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest in journal.get("quests", {}).values():
		var status := int(quest.get("status", 0))
		if status == QuestStatus.COMPLETED or status == QuestStatus.TURNED_IN:
			result.append(quest)
	return result

# --- Human-readable labels ---

static func objective_label(obj: Dictionary) -> String:
	var t: int = int(obj.get("type", 0))
	var p: Dictionary = obj.get("params", {})
	var done := bool(obj.get("completed", false))
	var prefix := "[v] " if done else "[ ] "

	match t:
		ObjectiveType.COLLECT_ITEM:
			var progress := int(obj.get("progress", 0))
			var needed := int(p.get("amount", 1))
			return prefix + "收集 %s (%d/%d)" % [p.get("item_id", "?"), progress, needed]
		ObjectiveType.TALK_TO:
			return prefix + "与 %s 对话" % p.get("object_id", "?")
		ObjectiveType.REACH_LOCATION:
			return prefix + "到达 (%s, %s)" % [p.get("x", 0), p.get("y", 0)]
		ObjectiveType.SET_FLAG:
			return prefix + "完成: %s" % p.get("flag", "?")
		ObjectiveType.KILL_COUNT:
			var progress := int(obj.get("progress", 0))
			var needed := int(p.get("count", 1))
			return prefix + "击败 %s (%d/%d)" % [p.get("target_type", "?"), progress, needed]
		ObjectiveType.CUSTOM:
			return prefix + "自定义: %s" % p.get("flag", "?")
		_:
			return prefix + "未知目标"

static func status_label(status: int) -> String:
	match status:
		QuestStatus.LOCKED: return "未解锁"
		QuestStatus.AVAILABLE: return "可接取"
		QuestStatus.ACTIVE: return "进行中"
		QuestStatus.COMPLETED: return "已完成"
		QuestStatus.TURNED_IN: return "已交付"
		_: return "未知"

# --- Serialization ---

static func serialize_journal(journal: Dictionary) -> Dictionary:
	return journal.duplicate(true)

static func deserialize_journal(data: Variant) -> Dictionary:
	if data is Dictionary:
		var j := data.duplicate(true)
		if not j.has("quests"):
			j["quests"] = {}
		return j
	return create_journal()

static func _count_item_in_inventory(inventory: Dictionary, item_id: String) -> int:
	var total := 0
	for slot in inventory.get("slots", []):
		if String(slot.get("item_id", "")) == item_id:
			total += int(slot.get("amount", 0))
	return total
