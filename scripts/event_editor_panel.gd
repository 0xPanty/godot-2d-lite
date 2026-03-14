extends VBoxContainer

const ES = preload("res://scripts/event_system.gd")

signal events_changed(events: Array[Dictionary])

var events: Array[Dictionary] = []
var _object_names: Dictionary = {}
var _selected_event_index := -1

@onready var event_list_container: VBoxContainer = $EventScroll/EventListContainer
@onready var add_event_btn: Button = $Toolbar/AddEventBtn
@onready var delete_event_btn: Button = $Toolbar/DeleteEventBtn
@onready var duplicate_event_btn: Button = $Toolbar/DuplicateEventBtn
@onready var move_up_btn: Button = $Toolbar/MoveUpBtn
@onready var move_down_btn: Button = $Toolbar/MoveDownBtn

func _ready() -> void:
	add_event_btn.pressed.connect(_on_add_event)
	delete_event_btn.pressed.connect(_on_delete_event)
	duplicate_event_btn.pressed.connect(_on_duplicate_event)
	move_up_btn.pressed.connect(_on_move_up)
	move_down_btn.pressed.connect(_on_move_down)

func set_events(new_events: Array[Dictionary], object_names: Dictionary = {}) -> void:
	events = new_events
	_object_names = object_names
	_rebuild_list()

func _rebuild_list() -> void:
	for child in event_list_container.get_children():
		child.queue_free()

	for i in events.size():
		var evt: Dictionary = events[i]
		var row := _create_event_row(i, evt)
		event_list_container.add_child(row)

func _create_event_row(index: int, evt: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.22, 0.28) if index != _selected_event_index else Color(0.25, 0.35, 0.50)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var outer := VBoxContainer.new()
	panel.add_child(outer)

	# Header row: checkbox + name + once badge
	var header := HBoxContainer.new()
	outer.add_child(header)

	var enabled_check := CheckBox.new()
	enabled_check.button_pressed = evt.get("enabled", true)
	enabled_check.toggled.connect(func(val: bool):
		events[index]["enabled"] = val
		events_changed.emit(events)
	)
	header.add_child(enabled_check)

	var event_name := String(evt.get("name", ""))
	if event_name.is_empty():
		event_name = "事件 #%d" % (index + 1)
	var name_btn := Button.new()
	name_btn.text = event_name
	name_btn.flat = true
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.pressed.connect(func():
		_selected_event_index = index
		_rebuild_list()
	)
	header.add_child(name_btn)

	if evt.get("once", false):
		var once_label := Label.new()
		once_label.text = "仅一次"
		once_label.add_theme_font_size_override("font_size", 11)
		once_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		header.add_child(once_label)

	var once_btn := Button.new()
	once_btn.text = "一次" if evt.get("once", false) else "循环"
	once_btn.custom_minimum_size.x = 48
	once_btn.pressed.connect(func():
		events[index]["once"] = not events[index].get("once", false)
		_rebuild_list()
		events_changed.emit(events)
	)
	header.add_child(once_btn)

	# Condition/Action display (GDevelop style: left=conditions, right=actions)
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	# Conditions column (green tint)
	var cond_box := VBoxContainer.new()
	cond_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(cond_box)

	var cond_header := Label.new()
	cond_header.text = "条件"
	cond_header.add_theme_font_size_override("font_size", 11)
	cond_header.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
	cond_box.add_child(cond_header)

	var conditions: Array = evt.get("conditions", [])
	if conditions.is_empty():
		var empty_label := Label.new()
		empty_label.text = "  （无条件 = 每帧执行）"
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		cond_box.add_child(empty_label)
	else:
		for ci in conditions.size():
			var cond_label := Label.new()
			cond_label.text = "  · %s" % ES.condition_label(conditions[ci])
			cond_label.add_theme_font_size_override("font_size", 12)
			cond_box.add_child(cond_label)

	var add_cond_btn := Button.new()
	add_cond_btn.text = "+ 添加条件"
	add_cond_btn.flat = true
	add_cond_btn.add_theme_font_size_override("font_size", 11)
	add_cond_btn.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
	add_cond_btn.pressed.connect(func(): _show_add_condition_dialog(index))
	cond_box.add_child(add_cond_btn)

	# Separator
	var sep := VSeparator.new()
	body.add_child(sep)

	# Actions column (orange tint)
	var act_box := VBoxContainer.new()
	act_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(act_box)

	var act_header := Label.new()
	act_header.text = "动作"
	act_header.add_theme_font_size_override("font_size", 11)
	act_header.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	act_box.add_child(act_header)

	var actions: Array = evt.get("actions", [])
	if actions.is_empty():
		var empty_label := Label.new()
		empty_label.text = "  （无动作）"
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		act_box.add_child(empty_label)
	else:
		for ai_idx in actions.size():
			var act_label := Label.new()
			act_label.text = "  → %s" % ES.action_label(actions[ai_idx])
			act_label.add_theme_font_size_override("font_size", 12)
			act_box.add_child(act_label)

	var add_act_btn := Button.new()
	add_act_btn.text = "+ 添加动作"
	add_act_btn.flat = true
	add_act_btn.add_theme_font_size_override("font_size", 11)
	add_act_btn.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	add_act_btn.pressed.connect(func(): _show_add_action_dialog(index))
	act_box.add_child(add_act_btn)

	return panel

# --- Add Condition Dialog ---

func _show_add_condition_dialog(event_index: int) -> void:
	var popup := PopupMenu.new()
	popup.add_item("碰撞检测", ES.ConditionType.COLLISION)
	popup.add_item("距离判断", ES.ConditionType.DISTANCE)
	popup.add_item("按键按下", ES.ConditionType.KEY_PRESSED)
	popup.add_item("按键持续", ES.ConditionType.KEY_HELD)
	popup.add_item("属性比较", ES.ConditionType.PROPERTY_COMPARE)
	popup.add_item("旗标已设置", ES.ConditionType.FLAG_SET)
	popup.add_item("旗标未设置", ES.ConditionType.FLAG_NOT_SET)
	popup.add_item("始终执行", ES.ConditionType.ALWAYS)
	add_child(popup)
	popup.id_pressed.connect(func(id: int):
		_add_condition_to_event(event_index, id)
		popup.queue_free()
	)
	popup.popup_centered()

func _add_condition_to_event(event_index: int, cond_type: int) -> void:
	if event_index < 0 or event_index >= events.size():
		return
	var cond: Dictionary
	match cond_type:
		ES.ConditionType.COLLISION:
			cond = ES.cond_collision("player", _first_npc_id())
		ES.ConditionType.DISTANCE:
			cond = ES.cond_distance("player", _first_npc_id(), ES.CompareOp.LT, 100.0)
		ES.ConditionType.KEY_PRESSED:
			cond = ES.cond_key_pressed("e")
		ES.ConditionType.KEY_HELD:
			cond = ES.create_condition(ES.ConditionType.KEY_HELD, {"key": "up"})
		ES.ConditionType.PROPERTY_COMPARE:
			cond = ES.cond_property("player", "hp", ES.CompareOp.GT, 0)
		ES.ConditionType.FLAG_SET:
			cond = ES.cond_flag("quest_started")
		ES.ConditionType.FLAG_NOT_SET:
			cond = ES.cond_no_flag("quest_started")
		ES.ConditionType.ALWAYS:
			cond = ES.cond_always()
		_:
			return

	events[event_index]["conditions"].append(cond)
	_rebuild_list()
	events_changed.emit(events)

# --- Add Action Dialog ---

func _show_add_action_dialog(event_index: int) -> void:
	var popup := PopupMenu.new()
	popup.add_item("设置属性", ES.ActionType.SET_PROPERTY)
	popup.add_item("增加属性", ES.ActionType.ADD_PROPERTY)
	popup.add_item("显示对话", ES.ActionType.SHOW_DIALOGUE)
	popup.add_item("切换场景", ES.ActionType.CHANGE_SCENE)
	popup.add_item("移动对象", ES.ActionType.MOVE_OBJECT)
	popup.add_item("销毁对象", ES.ActionType.DESTROY_OBJECT)
	popup.add_item("生成对象", ES.ActionType.SPAWN_OBJECT)
	popup.add_item("设置旗标", ES.ActionType.SET_FLAG)
	popup.add_item("清除旗标", ES.ActionType.CLEAR_FLAG)
	popup.add_item("播放音效", ES.ActionType.PLAY_SOUND)
	popup.add_item("等待", ES.ActionType.WAIT)
	popup.add_item("添加物品", ES.ActionType.ADD_ITEM)
	add_child(popup)
	popup.id_pressed.connect(func(id: int):
		_add_action_to_event(event_index, id)
		popup.queue_free()
	)
	popup.popup_centered()

func _add_action_to_event(event_index: int, act_type: int) -> void:
	if event_index < 0 or event_index >= events.size():
		return
	var act: Dictionary
	match act_type:
		ES.ActionType.SET_PROPERTY:
			act = ES.act_set_property("player", "hp", 100)
		ES.ActionType.ADD_PROPERTY:
			act = ES.act_add_property("player", "hp", -10)
		ES.ActionType.SHOW_DIALOGUE:
			act = ES.act_dialogue(_first_npc_id(), "你好！")
		ES.ActionType.CHANGE_SCENE:
			act = ES.act_change_scene("res://scenes/runtime_preview.tscn")
		ES.ActionType.MOVE_OBJECT:
			act = ES.act_move("player", 200, 200)
		ES.ActionType.DESTROY_OBJECT:
			act = ES.act_destroy(_first_npc_id())
		ES.ActionType.SPAWN_OBJECT:
			act = ES.act_spawn("npc", 300, 300)
		ES.ActionType.SET_FLAG:
			act = ES.act_set_flag("quest_started")
		ES.ActionType.CLEAR_FLAG:
			act = ES.act_clear_flag("quest_started")
		ES.ActionType.PLAY_SOUND:
			act = ES.act_play_sound("res://audio/hit.wav")
		ES.ActionType.WAIT:
			act = ES.act_wait(1.0)
		ES.ActionType.ADD_ITEM:
			act = ES.act_add_item("potion", 1)
		_:
			return

	events[event_index]["actions"].append(act)
	_rebuild_list()
	events_changed.emit(events)

func _first_npc_id() -> String:
	for id in _object_names:
		if String(_object_names[id]).begins_with("npc") or String(_object_names[id]).begins_with("NPC"):
			return String(id)
	for id in _object_names:
		if String(id) != "player":
			return String(id)
	return "npc_1"

# --- Toolbar handlers ---

func _on_add_event() -> void:
	var evt := ES.create_event("新事件 #%d" % (events.size() + 1))
	events.append(evt)
	_selected_event_index = events.size() - 1
	_rebuild_list()
	events_changed.emit(events)

func _on_delete_event() -> void:
	if _selected_event_index < 0 or _selected_event_index >= events.size():
		return
	events.remove_at(_selected_event_index)
	_selected_event_index = mini(_selected_event_index, events.size() - 1)
	_rebuild_list()
	events_changed.emit(events)

func _on_duplicate_event() -> void:
	if _selected_event_index < 0 or _selected_event_index >= events.size():
		return
	var copy: Dictionary = events[_selected_event_index].duplicate(true)
	copy["id"] = "evt_%s" % Time.get_ticks_msec()
	copy["name"] = String(copy.get("name", "")) + " (副本)"
	events.insert(_selected_event_index + 1, copy)
	_selected_event_index += 1
	_rebuild_list()
	events_changed.emit(events)

func _on_move_up() -> void:
	if _selected_event_index <= 0:
		return
	var tmp: Dictionary = events[_selected_event_index]
	events[_selected_event_index] = events[_selected_event_index - 1]
	events[_selected_event_index - 1] = tmp
	_selected_event_index -= 1
	_rebuild_list()
	events_changed.emit(events)

func _on_move_down() -> void:
	if _selected_event_index < 0 or _selected_event_index >= events.size() - 1:
		return
	var tmp: Dictionary = events[_selected_event_index]
	events[_selected_event_index] = events[_selected_event_index + 1]
	events[_selected_event_index + 1] = tmp
	_selected_event_index += 1
	_rebuild_list()
	events_changed.emit(events)
