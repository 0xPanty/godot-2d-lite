class_name EventRunner
extends Node

const ES = preload("res://scripts/event_system.gd")

signal dialogue_requested(object_id: String, text: String)
signal scene_change_requested(scene_path: String)
signal object_spawn_requested(object_type: String, position: Vector2)
signal flag_changed(flag_name: String, value: bool)
signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)
signal quest_accepted(quest_id: String)
signal quest_completed(quest_id: String)

var events: Array[Dictionary] = []
var flags: Dictionary = {}
var timers: Dictionary = {}
var runtime_nodes: Dictionary = {}
var player_node: Node2D
var inventory_ref: Dictionary = {}
var quest_journal_ref: Dictionary = {}
var _waiting := false
var _wait_remaining := 0.0

func load_events(event_data: Array[Dictionary]) -> void:
	events = []
	for evt in event_data:
		var entry := evt.duplicate(true)
		entry["triggered"] = false
		events.append(entry)

func set_runtime_refs(nodes: Dictionary, player: Node2D) -> void:
	runtime_nodes = nodes
	player_node = player

func process_events(delta: float) -> void:
	if _waiting:
		_wait_remaining -= delta
		if _wait_remaining <= 0:
			_waiting = false
		return

	_update_timers(delta)

	for evt in events:
		if not evt.get("enabled", true):
			continue
		if evt.get("once", false) and evt.get("triggered", false):
			continue
		if _evaluate_conditions(evt.get("conditions", [])):
			_execute_actions(evt.get("actions", []))
			if evt.get("once", false):
				evt["triggered"] = true
			_process_sub_events(evt.get("sub_events", []))

func _process_sub_events(sub_events: Array) -> void:
	for sub_evt in sub_events:
		if not sub_evt is Dictionary:
			continue
		if not sub_evt.get("enabled", true):
			continue
		if sub_evt.get("once", false) and sub_evt.get("triggered", false):
			continue
		if _evaluate_conditions(sub_evt.get("conditions", [])):
			_execute_actions(sub_evt.get("actions", []))
			if sub_evt.get("once", false):
				sub_evt["triggered"] = true
			_process_sub_events(sub_evt.get("sub_events", []))

func _evaluate_conditions(conditions: Array) -> bool:
	if conditions.is_empty():
		return true
	for cond in conditions:
		if not cond is Dictionary:
			continue
		var result := _check_condition(cond)
		if cond.get("negate", false):
			result = not result
		if not result:
			return false
	return true

func _check_condition(cond: Dictionary) -> bool:
	var t: int = int(cond.get("type", 0))
	var p: Dictionary = cond.get("params", {})

	match t:
		ES.ConditionType.ALWAYS:
			return true

		ES.ConditionType.COLLISION:
			var node_a := _get_node(String(p.get("object_a", "")))
			var node_b := _get_node(String(p.get("object_b", "")))
			if node_a == null or node_b == null:
				return false
			return node_a.global_position.distance_to(node_b.global_position) < 64.0

		ES.ConditionType.DISTANCE:
			var node_a := _get_node(String(p.get("object_a", "")))
			var node_b := _get_node(String(p.get("object_b", "")))
			if node_a == null or node_b == null:
				return false
			var dist := node_a.global_position.distance_to(node_b.global_position)
			return _compare(dist, int(p.get("op", 0)), float(p.get("value", 0)))

		ES.ConditionType.KEY_PRESSED:
			var key_name := String(p.get("key", ""))
			return _is_key_just_pressed(key_name)

		ES.ConditionType.KEY_HELD:
			var key_name := String(p.get("key", ""))
			return _is_key_held(key_name)

		ES.ConditionType.PROPERTY_COMPARE:
			var obj_id := String(p.get("object_id", ""))
			var prop := String(p.get("property", ""))
			var obj_data := _get_object_data(obj_id)
			if obj_data.is_empty():
				return false
			var current_val = obj_data.get(prop, 0)
			return _compare(current_val, int(p.get("op", 0)), p.get("value", 0))

		ES.ConditionType.FLAG_SET:
			return flags.get(String(p.get("flag", "")), false)

		ES.ConditionType.FLAG_NOT_SET:
			return not flags.get(String(p.get("flag", "")), false)

		ES.ConditionType.TIMER_FINISHED:
			var timer_id := String(p.get("timer_id", ""))
			return timers.get(timer_id, {}).get("finished", false)

		ES.ConditionType.HAS_ITEM:
			var item_id := String(p.get("item_id", ""))
			var needed := int(p.get("amount", 1))
			var total := 0
			for slot in inventory_ref.get("slots", []):
				if String(slot.get("item_id", "")) == item_id:
					total += int(slot.get("amount", 0))
			return total >= needed

		ES.ConditionType.QUEST_STATUS:
			var quest_id := String(p.get("quest_id", ""))
			var expected := int(p.get("status", 0))
			var quest: Dictionary = quest_journal_ref.get("quests", {}).get(quest_id, {})
			return int(quest.get("status", -1)) == expected

		_:
			return false

func _execute_actions(actions: Array) -> void:
	for act in actions:
		if not act is Dictionary:
			continue
		_run_action(act)

func _run_action(act: Dictionary) -> void:
	var t: int = int(act.get("type", 0))
	var p: Dictionary = act.get("params", {})

	match t:
		ES.ActionType.SET_PROPERTY:
			var obj_data := _get_object_data(String(p.get("object_id", "")))
			if not obj_data.is_empty():
				obj_data[String(p.get("property", ""))] = p.get("value")

		ES.ActionType.ADD_PROPERTY:
			var obj_data := _get_object_data(String(p.get("object_id", "")))
			if not obj_data.is_empty():
				var prop := String(p.get("property", ""))
				var current = obj_data.get(prop, 0)
				obj_data[prop] = float(current) + float(p.get("amount", 0))

		ES.ActionType.SHOW_DIALOGUE:
			dialogue_requested.emit(String(p.get("object_id", "")), String(p.get("text", "")))

		ES.ActionType.CHANGE_SCENE:
			scene_change_requested.emit(String(p.get("scene_path", "")))

		ES.ActionType.MOVE_OBJECT:
			var node := _get_node(String(p.get("object_id", "")))
			if node:
				var target := Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
				node.global_position = target

		ES.ActionType.DESTROY_OBJECT:
			var obj_id := String(p.get("object_id", ""))
			if runtime_nodes.has(obj_id):
				var entry: Dictionary = runtime_nodes[obj_id]
				var node: Node = entry.get("node")
				if node:
					node.queue_free()
				runtime_nodes.erase(obj_id)

		ES.ActionType.SET_FLAG:
			var flag_name := String(p.get("flag", ""))
			flags[flag_name] = true
			flag_changed.emit(flag_name, true)

		ES.ActionType.CLEAR_FLAG:
			var flag_name := String(p.get("flag", ""))
			flags[flag_name] = false
			flag_changed.emit(flag_name, false)

		ES.ActionType.PLAY_SOUND:
			pass # TODO: implement AudioStreamPlayer

		ES.ActionType.SPAWN_OBJECT:
			var obj_type := String(p.get("type", "prop"))
			var pos := Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
			object_spawn_requested.emit(obj_type, pos)

		ES.ActionType.START_TIMER:
			var timer_id := String(p.get("timer_id", ""))
			var duration := float(p.get("duration", 1.0))
			timers[timer_id] = {"remaining": duration, "finished": false}

		ES.ActionType.WAIT:
			_waiting = true
			_wait_remaining = float(p.get("seconds", 0))

		ES.ActionType.ADD_ITEM:
			var item_id := String(p.get("item_id", ""))
			var amount := int(p.get("amount", 1))
			if not item_id.is_empty():
				item_added.emit(item_id, amount)

		ES.ActionType.REMOVE_ITEM:
			var item_id := String(p.get("item_id", ""))
			var amount := int(p.get("amount", 1))
			if not item_id.is_empty():
				item_removed.emit(item_id, amount)

		ES.ActionType.ACCEPT_QUEST:
			var quest_id := String(p.get("quest_id", ""))
			if not quest_id.is_empty():
				quest_accepted.emit(quest_id)

		ES.ActionType.COMPLETE_QUEST:
			var quest_id := String(p.get("quest_id", ""))
			if not quest_id.is_empty():
				quest_completed.emit(quest_id)

		ES.ActionType.CAMERA_SHAKE:
			pass # TODO: implement camera shake

func _get_node(object_id: String) -> Node2D:
	if object_id == "player" and player_node:
		return player_node
	if runtime_nodes.has(object_id):
		return runtime_nodes[object_id].get("node")
	return null

func _get_object_data(object_id: String) -> Dictionary:
	if runtime_nodes.has(object_id):
		return runtime_nodes[object_id].get("data", {})
	return {}

func _compare(a: Variant, op: int, b: Variant) -> bool:
	var fa := float(a) if a != null else 0.0
	var fb := float(b) if b != null else 0.0
	match op:
		ES.CompareOp.EQ: return is_equal_approx(fa, fb)
		ES.CompareOp.NEQ: return not is_equal_approx(fa, fb)
		ES.CompareOp.GT: return fa > fb
		ES.CompareOp.GTE: return fa >= fb
		ES.CompareOp.LT: return fa < fb
		ES.CompareOp.LTE: return fa <= fb
		_: return false

func _is_key_just_pressed(key_name: String) -> bool:
	match key_name.to_lower():
		"e": return Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_E)
		"space": return Input.is_action_just_pressed("ui_accept")
		"up": return Input.is_action_just_pressed("ui_up")
		"down": return Input.is_action_just_pressed("ui_down")
		"left": return Input.is_action_just_pressed("ui_left")
		"right": return Input.is_action_just_pressed("ui_right")
		_: return false

func _is_key_held(key_name: String) -> bool:
	match key_name.to_lower():
		"up": return Input.is_action_pressed("ui_up")
		"down": return Input.is_action_pressed("ui_down")
		"left": return Input.is_action_pressed("ui_left")
		"right": return Input.is_action_pressed("ui_right")
		_: return false

func _update_timers(delta: float) -> void:
	for timer_id in timers.keys():
		var timer: Dictionary = timers[timer_id]
		if timer.get("finished", false):
			continue
		timer["remaining"] = float(timer.get("remaining", 0)) - delta
		if float(timer["remaining"]) <= 0:
			timer["finished"] = true
