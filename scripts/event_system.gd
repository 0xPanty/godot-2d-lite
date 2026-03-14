class_name EventSystem
extends RefCounted

## Condition types that can be checked each frame or on trigger
enum ConditionType {
	COLLISION,        # 两个对象碰撞
	DISTANCE,         # 两个对象距离小于/大于
	KEY_PRESSED,      # 按键按下
	KEY_HELD,         # 按键持续按住
	PROPERTY_COMPARE, # 对象属性比较（hp > 0）
	FLAG_SET,         # 全局旗标已设置
	FLAG_NOT_SET,     # 全局旗标未设置
	TIMER_FINISHED,   # 定时器结束
	OBJECT_TYPE_IS,   # 对象类型是
	ALWAYS,           # 始终为真（每帧执行）
	HAS_ITEM,         # 背包中有指定物品
	QUEST_STATUS,     # 任务状态检查
}

## Action types that modify game state
enum ActionType {
	SET_PROPERTY,     # 设置对象属性
	ADD_PROPERTY,     # 增加属性值
	PLAY_SOUND,       # 播放音效
	SHOW_DIALOGUE,    # 显示对话
	CHANGE_SCENE,     # 切换场景
	MOVE_OBJECT,      # 移动对象到位置
	DESTROY_OBJECT,   # 销毁对象
	SPAWN_OBJECT,     # 生成新对象
	SET_FLAG,         # 设置全局旗标
	CLEAR_FLAG,       # 清除全局旗标
	START_TIMER,      # 启动定时器
	APPLY_BEHAVIOR,   # 给对象添加行为
	CAMERA_SHAKE,     # 镜头震动
	WAIT,             # 等待秒数
	ADD_ITEM,         # 添加物品到背包
	REMOVE_ITEM,      # 从背包移除物品
	ACCEPT_QUEST,     # 接受任务
	COMPLETE_QUEST,   # 完成任务
}

## Compare operators for property conditions
enum CompareOp { EQ, NEQ, GT, GTE, LT, LTE }

static func create_event(name: String = "", enabled: bool = true) -> Dictionary:
	return {
		"id": "evt_%s" % Time.get_ticks_msec(),
		"name": name,
		"enabled": enabled,
		"conditions": [],
		"actions": [],
		"sub_events": [],
		"once": false,
		"triggered": false,
	}

static func create_condition(type: ConditionType, params: Dictionary = {}) -> Dictionary:
	return {
		"type": type,
		"params": params,
		"negate": false,
	}

static func create_action(type: ActionType, params: Dictionary = {}) -> Dictionary:
	return {
		"type": type,
		"params": params,
	}

# --- Condition factories ---

static func cond_collision(object_a: String, object_b: String) -> Dictionary:
	return create_condition(ConditionType.COLLISION, {"object_a": object_a, "object_b": object_b})

static func cond_distance(object_a: String, object_b: String, op: CompareOp, value: float) -> Dictionary:
	return create_condition(ConditionType.DISTANCE, {"object_a": object_a, "object_b": object_b, "op": op, "value": value})

static func cond_key_pressed(key: String) -> Dictionary:
	return create_condition(ConditionType.KEY_PRESSED, {"key": key})

static func cond_property(object_id: String, property: String, op: CompareOp, value: Variant) -> Dictionary:
	return create_condition(ConditionType.PROPERTY_COMPARE, {"object_id": object_id, "property": property, "op": op, "value": value})

static func cond_flag(flag_name: String) -> Dictionary:
	return create_condition(ConditionType.FLAG_SET, {"flag": flag_name})

static func cond_no_flag(flag_name: String) -> Dictionary:
	return create_condition(ConditionType.FLAG_NOT_SET, {"flag": flag_name})

static func cond_always() -> Dictionary:
	return create_condition(ConditionType.ALWAYS)

# --- Action factories ---

static func act_set_property(object_id: String, property: String, value: Variant) -> Dictionary:
	return create_action(ActionType.SET_PROPERTY, {"object_id": object_id, "property": property, "value": value})

static func act_add_property(object_id: String, property: String, amount: float) -> Dictionary:
	return create_action(ActionType.ADD_PROPERTY, {"object_id": object_id, "property": property, "amount": amount})

static func act_dialogue(object_id: String, text: String) -> Dictionary:
	return create_action(ActionType.SHOW_DIALOGUE, {"object_id": object_id, "text": text})

static func act_change_scene(scene_path: String) -> Dictionary:
	return create_action(ActionType.CHANGE_SCENE, {"scene_path": scene_path})

static func act_move(object_id: String, x: float, y: float, speed: float = 120.0) -> Dictionary:
	return create_action(ActionType.MOVE_OBJECT, {"object_id": object_id, "x": x, "y": y, "speed": speed})

static func act_destroy(object_id: String) -> Dictionary:
	return create_action(ActionType.DESTROY_OBJECT, {"object_id": object_id})

static func act_set_flag(flag_name: String) -> Dictionary:
	return create_action(ActionType.SET_FLAG, {"flag": flag_name})

static func act_clear_flag(flag_name: String) -> Dictionary:
	return create_action(ActionType.CLEAR_FLAG, {"flag": flag_name})

static func act_play_sound(sound_path: String) -> Dictionary:
	return create_action(ActionType.PLAY_SOUND, {"sound_path": sound_path})

static func act_spawn(object_type: String, x: float, y: float) -> Dictionary:
	return create_action(ActionType.SPAWN_OBJECT, {"type": object_type, "x": x, "y": y})

static func act_add_item(item_id: String, amount: int = 1) -> Dictionary:
	return create_action(ActionType.ADD_ITEM, {"item_id": item_id, "amount": amount})

static func act_remove_item(item_id: String, amount: int = 1) -> Dictionary:
	return create_action(ActionType.REMOVE_ITEM, {"item_id": item_id, "amount": amount})

static func act_accept_quest(quest_id: String) -> Dictionary:
	return create_action(ActionType.ACCEPT_QUEST, {"quest_id": quest_id})

static func act_complete_quest(quest_id: String) -> Dictionary:
	return create_action(ActionType.COMPLETE_QUEST, {"quest_id": quest_id})

static func cond_has_item(item_id: String, amount: int = 1) -> Dictionary:
	return create_condition(ConditionType.HAS_ITEM, {"item_id": item_id, "amount": amount})

static func cond_quest_status(quest_id: String, status: int) -> Dictionary:
	return create_condition(ConditionType.QUEST_STATUS, {"quest_id": quest_id, "status": status})

static func act_wait(seconds: float) -> Dictionary:
	return create_action(ActionType.WAIT, {"seconds": seconds})

# --- Serialization ---

static func serialize_events(events: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for evt in events:
		var entry := evt.duplicate(true)
		if entry.has("triggered"):
			entry.erase("triggered")
		result.append(entry)
	return result

static func deserialize_events(data: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in data:
		var evt: Dictionary = item.duplicate(true) if item is Dictionary else {}
		if not evt.has("id"):
			evt["id"] = "evt_%s" % Time.get_ticks_msec()
		evt["triggered"] = false
		evt["enabled"] = evt.get("enabled", true)
		evt["conditions"] = evt.get("conditions", [])
		evt["actions"] = evt.get("actions", [])
		evt["sub_events"] = evt.get("sub_events", [])
		evt["once"] = evt.get("once", false)
		result.append(evt)
	return result

# --- Human-readable labels (中文) ---

static func condition_label(cond: Dictionary) -> String:
	var t: int = int(cond.get("type", 0))
	var p: Dictionary = cond.get("params", {})
	var prefix := "非 " if cond.get("negate", false) else ""
	match t:
		ConditionType.COLLISION:
			return prefix + "%s 碰到 %s" % [p.get("object_a", "?"), p.get("object_b", "?")]
		ConditionType.DISTANCE:
			return prefix + "%s 与 %s 距离 %s %s" % [p.get("object_a", "?"), p.get("object_b", "?"), _op_label(p.get("op", 0)), p.get("value", 0)]
		ConditionType.KEY_PRESSED:
			return prefix + "按下 %s 键" % p.get("key", "?")
		ConditionType.KEY_HELD:
			return prefix + "按住 %s 键" % p.get("key", "?")
		ConditionType.PROPERTY_COMPARE:
			return prefix + "%s.%s %s %s" % [p.get("object_id", "?"), p.get("property", "?"), _op_label(p.get("op", 0)), p.get("value", "?")]
		ConditionType.FLAG_SET:
			return prefix + "旗标 [%s] 已设置" % p.get("flag", "?")
		ConditionType.FLAG_NOT_SET:
			return prefix + "旗标 [%s] 未设置" % p.get("flag", "?")
		ConditionType.ALWAYS:
			return "始终"
		ConditionType.HAS_ITEM:
			return prefix + "背包有 %s x%s" % [p.get("item_id", "?"), p.get("amount", 1)]
		ConditionType.QUEST_STATUS:
			return prefix + "任务 %s 状态为 %s" % [p.get("quest_id", "?"), p.get("status", 0)]
		_:
			return prefix + "未知条件"

static func action_label(act: Dictionary) -> String:
	var t: int = int(act.get("type", 0))
	var p: Dictionary = act.get("params", {})
	match t:
		ActionType.SET_PROPERTY:
			return "%s.%s = %s" % [p.get("object_id", "?"), p.get("property", "?"), p.get("value", "?")]
		ActionType.ADD_PROPERTY:
			return "%s.%s += %s" % [p.get("object_id", "?"), p.get("property", "?"), p.get("amount", 0)]
		ActionType.SHOW_DIALOGUE:
			var text: String = String(p.get("text", ""))
			return "显示对话: %s" % text.substr(0, 20)
		ActionType.CHANGE_SCENE:
			return "切换场景: %s" % p.get("scene_path", "?")
		ActionType.MOVE_OBJECT:
			return "移动 %s 到 (%s, %s)" % [p.get("object_id", "?"), p.get("x", 0), p.get("y", 0)]
		ActionType.DESTROY_OBJECT:
			return "销毁 %s" % p.get("object_id", "?")
		ActionType.SET_FLAG:
			return "设置旗标 [%s]" % p.get("flag", "?")
		ActionType.CLEAR_FLAG:
			return "清除旗标 [%s]" % p.get("flag", "?")
		ActionType.PLAY_SOUND:
			return "播放音效: %s" % p.get("sound_path", "?")
		ActionType.SPAWN_OBJECT:
			return "生成 %s 在 (%s, %s)" % [p.get("type", "?"), p.get("x", 0), p.get("y", 0)]
		ActionType.ADD_ITEM:
			return "获得 %s x%s" % [p.get("item_id", "?"), p.get("amount", 1)]
		ActionType.WAIT:
			return "等待 %s 秒" % p.get("seconds", 0)
		ActionType.REMOVE_ITEM:
			return "移除 %s x%s" % [p.get("item_id", "?"), p.get("amount", 1)]
		ActionType.ACCEPT_QUEST:
			return "接受任务: %s" % p.get("quest_id", "?")
		ActionType.COMPLETE_QUEST:
			return "完成任务: %s" % p.get("quest_id", "?")
		_:
			return "未知动作"

static func _op_label(op: int) -> String:
	match op:
		CompareOp.EQ: return "="
		CompareOp.NEQ: return "≠"
		CompareOp.GT: return ">"
		CompareOp.GTE: return "≥"
		CompareOp.LT: return "<"
		CompareOp.LTE: return "≤"
		_: return "?"
