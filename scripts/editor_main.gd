extends Control

const LogicTemplatesScript = preload("res://scripts/logic_templates.gd")
const ProjectStoreScript = preload("res://scripts/project_store.gd")
const UndoRedoScript = preload("res://scripts/undo_redo_manager.gd")
const AIClientScript = preload("res://scripts/ai_client.gd")
const EventSystemScript = preload("res://scripts/event_system.gd")
const BehaviorSystemScript = preload("res://scripts/behavior_system.gd")
const AnimationSystemScript = preload("res://scripts/animation_system.gd")
const SceneManagerScript = preload("res://scripts/scene_manager.gd")
const OBJECT_TYPES := ["player", "npc", "door", "chest", "trigger", "prop"]
const TRIGGER_MODES := ["interact", "touch", "area", "auto"]
const TILE_LAYERS := ["ground", "decoration", "collision"]
const SAVE_DEBOUNCE_SEC := 1.5

var resources: Array[Dictionary] = []
var scene_objects: Array[Dictionary] = []
var tile_cells: Array[Dictionary] = []
var events: Array[Dictionary] = []
var selected_resource_index := -1
var selected_object_id := ""
var _next_object_id := 1
var _current_scene_id := "main"
var _scene_list: Array[Dictionary] = []
var tool_mode := "select"
var selected_terrain := "ground"
var selected_layer := "ground"
var _undo_redo: RefCounted
var _save_timer: Timer
var _ai_client: Node
var _ai_available := false
var _ai_pending_object_index := -1

@onready var scene_option: OptionButton = $MainSplit/LeftPanel/SceneRow/SceneOption
@onready var resource_list: ItemList = $MainSplit/LeftPanel/ResourceList
@onready var object_list: ItemList = $MainSplit/LeftPanel/ObjectList
@onready var canvas = $MainSplit/CenterPanel/CanvasPanel/SceneCanvas
@onready var log_output: RichTextLabel = $"MainSplit/CenterPanel/BottomTabs/日志"
@onready var event_editor = $"MainSplit/CenterPanel/BottomTabs/事件编辑器"
@onready var file_dialog: FileDialog = $FileDialog
@onready var name_edit: LineEdit = $MainSplit/RightPanel/Inspector/NameEdit
@onready var type_option: OptionButton = $MainSplit/RightPanel/Inspector/TypeOption
@onready var x_spin: SpinBox = $MainSplit/RightPanel/Inspector/PositionRow/PosXSpin
@onready var y_spin: SpinBox = $MainSplit/RightPanel/Inspector/PositionRow/PosYSpin
@onready var solid_check: CheckBox = $MainSplit/RightPanel/Inspector/SolidCheck
@onready var interact_check: CheckBox = $MainSplit/RightPanel/Inspector/InteractCheck
@onready var trigger_option: OptionButton = $MainSplit/RightPanel/Inspector/TriggerOption
@onready var dialogue_edit: TextEdit = $MainSplit/RightPanel/Inspector/DialogueEdit
@onready var prompt_input: TextEdit = $MainSplit/RightPanel/AIPanel/PromptInput
@onready var behavior_container: VBoxContainer = $MainSplit/RightPanel/Inspector/BehaviorContainer
@onready var animation_container: VBoxContainer = $MainSplit/RightPanel/Inspector/AnimationContainer

func _ready() -> void:
	_undo_redo = UndoRedoScript.new()
	_setup_save_timer()
	_setup_ai_client()
	_setup_options()
	_setup_dialog()
	_bind_events()
	_init_scene_manager()
	_load_current_scene()
	if scene_objects.is_empty():
		_add_object("player")
	refresh_all()
	_push_undo_state()
	append_log("Lite2D Studio 已启动。Ctrl+Z 撤销，Ctrl+Y 重做。")

func _setup_ai_client() -> void:
	_ai_client = AIClientScript.new()
	add_child(_ai_client)
	_ai_client.response_received.connect(_on_ai_response)
	_ai_client.error_occurred.connect(_on_ai_error)
	_ai_client.check_health()

func _setup_save_timer() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE_SEC
	_save_timer.timeout.connect(_do_save_snapshot)
	add_child(_save_timer)

func _setup_options() -> void:
	for object_type in OBJECT_TYPES:
		type_option.add_item(object_type.capitalize())
	for trigger_mode in TRIGGER_MODES:
		trigger_option.add_item(trigger_mode)

func _setup_dialog() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.svg ; Images"])

func _bind_events() -> void:
	resource_list.item_selected.connect(_on_resource_selected)
	object_list.item_selected.connect(_on_object_selected_from_list)
	canvas.object_selected.connect(_on_canvas_object_selected)
	canvas.object_moved.connect(_on_canvas_object_moved)
	canvas.tile_painted.connect(_on_canvas_tile_painted)
	canvas.tile_paint_ended.connect(_on_canvas_tile_paint_ended)
	file_dialog.files_selected.connect(_on_files_selected)
	event_editor.events_changed.connect(_on_events_changed)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed and event.keycode == KEY_Z:
		_perform_undo()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_Y:
		_perform_redo()
		get_viewport().set_input_as_handled()

func _perform_undo() -> void:
	if not _undo_redo.can_undo():
		append_log("没有可撤销的操作。")
		return
	var state: Dictionary = _undo_redo.undo()
	_restore_state(state)
	refresh_all()
	_request_save()
	append_log("已撤销。")

func _perform_redo() -> void:
	if not _undo_redo.can_redo():
		append_log("没有可重做的操作。")
		return
	var state: Dictionary = _undo_redo.redo()
	_restore_state(state)
	refresh_all()
	_request_save()
	append_log("已重做。")

func _push_undo_state() -> void:
	_undo_redo.push_state(_capture_state())

func _capture_state() -> Dictionary:
	var objects_copy: Array[Dictionary] = []
	for obj in scene_objects:
		objects_copy.append(obj.duplicate(true))
	var resources_copy: Array[Dictionary] = []
	for res_data in resources:
		resources_copy.append(res_data.duplicate(true))
	var tiles_copy: Array[Dictionary] = []
	for tile in tile_cells:
		tiles_copy.append(tile.duplicate(true))
	var events_copy: Array[Dictionary] = []
	for evt in events:
		events_copy.append(evt.duplicate(true))
	return {
		"resources": resources_copy,
		"scene_objects": objects_copy,
		"tile_cells": tiles_copy,
		"events": events_copy,
		"next_object_id": _next_object_id,
		"selected_object_id": selected_object_id,
	}

func _restore_state(state: Dictionary) -> void:
	resources = []
	for res_data in state.get("resources", []):
		resources.append(res_data.duplicate(true))
	scene_objects = []
	for obj in state.get("scene_objects", []):
		scene_objects.append(obj.duplicate(true))
	tile_cells = []
	for tile in state.get("tile_cells", []):
		tile_cells.append(tile.duplicate(true))
	events = []
	for evt in state.get("events", []):
		events.append(evt.duplicate(true))
	_next_object_id = int(state.get("next_object_id", 1))
	selected_object_id = String(state.get("selected_object_id", ""))

func _request_save() -> void:
	_save_timer.start()

func _do_save_snapshot() -> void:
	ProjectStoreScript.save_snapshot(resources, scene_objects, _next_object_id, tile_cells, events)
	if _current_scene_id != "main":
		_save_current_scene()

func _record_and_save() -> void:
	_push_undo_state()
	_request_save()

func _on_import_pressed() -> void:
	file_dialog.popup_centered_ratio(0.75)

func _on_add_player_pressed() -> void:
	_add_object("player")

func _on_add_npc_pressed() -> void:
	_add_object("npc")

func _on_add_door_pressed() -> void:
	_add_object("door")

func _on_add_chest_pressed() -> void:
	_add_object("chest")

func _on_add_trigger_pressed() -> void:
	_add_object("trigger")

func _on_preview_pressed() -> void:
	_save_current_scene()
	_do_save_snapshot()
	append_log("已生成预览快照，准备切换到运行预览。")
	get_tree().change_scene_to_file("res://scenes/runtime_preview.tscn")

func _on_select_tool_pressed() -> void:
	tool_mode = "select"
	append_log("已切换到对象选择模式。")
	refresh_canvas()

func _on_ground_tool_pressed() -> void:
	tool_mode = "paint"
	selected_terrain = "ground"
	selected_layer = "ground"
	append_log("已切换到地面绘制模式（地面层）。")
	refresh_canvas()

func _on_wall_tool_pressed() -> void:
	tool_mode = "paint"
	selected_terrain = "wall"
	selected_layer = "collision"
	append_log("已切换到墙体绘制模式（碰撞层）。")
	refresh_canvas()

func _on_water_tool_pressed() -> void:
	tool_mode = "paint"
	selected_terrain = "water"
	selected_layer = "ground"
	append_log("已切换到水域绘制模式（地面层）。")
	refresh_canvas()

func _on_grass_tool_pressed() -> void:
	tool_mode = "paint"
	selected_terrain = "grass"
	selected_layer = "decoration"
	append_log("已切换到草地绘制模式（装饰层）。")
	refresh_canvas()

func _on_sand_tool_pressed() -> void:
	tool_mode = "paint"
	selected_terrain = "sand"
	selected_layer = "decoration"
	append_log("已切换到沙地绘制模式（装饰层）。")
	refresh_canvas()

func _on_path_tool_pressed() -> void:
	tool_mode = "paint"
	selected_terrain = "path"
	selected_layer = "decoration"
	append_log("已切换到路径绘制模式（装饰层）。")
	refresh_canvas()

func _on_erase_tool_pressed() -> void:
	tool_mode = "paint"
	selected_terrain = "erase"
	append_log("已切换到地图擦除模式（当前层: %s）。" % selected_layer)
	refresh_canvas()

func _on_delete_selected_pressed() -> void:
	var object_index := _find_object_index(selected_object_id)
	if object_index == -1:
		append_log("没有可删除的对象。")
		return

	var object_name := String(scene_objects[object_index].get("name", "Object"))
	scene_objects.remove_at(object_index)
	selected_object_id = ""
	if not scene_objects.is_empty():
		selected_object_id = String(scene_objects[0].get("id", ""))
	refresh_all()
	_record_and_save()
	append_log("已删除对象: %s" % object_name)

func _add_object(object_type: String) -> void:
	var resource_path := ""
	if selected_resource_index >= 0 and selected_resource_index < resources.size():
		resource_path = String(resources[selected_resource_index].get("path", ""))

	var object_data: Dictionary = ProjectStoreScript.default_object(object_type, _next_object_id, resource_path)
	var object_id := String(object_data.get("id", ""))
	_next_object_id += 1

	scene_objects.append(object_data)
	select_object(object_id)
	refresh_all()
	_record_and_save()
	append_log("已添加对象: %s" % object_data["name"])

func _on_resource_selected(index: int) -> void:
	selected_resource_index = index
	if index >= 0 and index < resources.size():
		append_log("已选中素材: %s" % resources[index].get("name", ""))

func _on_object_selected_from_list(index: int) -> void:
	if index >= 0 and index < scene_objects.size():
		select_object(String(scene_objects[index].get("id", "")))

func _on_canvas_object_selected(object_id: String) -> void:
	select_object(object_id)

func _on_canvas_object_moved(object_id: String, position: Vector2) -> void:
	var object_index := _find_object_index(object_id)
	if object_index == -1:
		return
	var canvas_size: Vector2 = canvas.size
	var obj_size: Vector2 = scene_objects[object_index].get("size", Vector2(96, 96))
	var clamped := position.clamp(Vector2.ZERO, canvas_size - obj_size)
	scene_objects[object_index]["position"] = clamped
	refresh_inspector()
	refresh_object_list()
	_record_and_save()

func _on_canvas_tile_painted(cell: Vector2i, terrain: String) -> void:
	_apply_tile_change(cell, terrain, selected_layer)
	_request_save()
	refresh_canvas()

func _on_canvas_tile_paint_ended() -> void:
	_push_undo_state()

func _on_files_selected(paths: PackedStringArray) -> void:
	for path in paths:
		var exists := false
		for resource_data in resources:
			if String(resource_data.get("path", "")) == path:
				exists = true
				break
		if exists:
			continue
		resources.append({
			"id": "res_%s" % (resources.size() + 1),
			"name": path.get_file().get_basename(),
			"path": path,
			"kind": "image",
		})
	refresh_resource_list()
	_record_and_save()
	append_log("已导入素材数量: %s" % paths.size())

func _on_apply_inspector_pressed() -> void:
	var object_index := _find_object_index(selected_object_id)
	if object_index == -1:
		append_log("请先选择一个对象。")
		return

	var object_data := scene_objects[object_index]
	object_data["name"] = name_edit.text.strip_edges()
	object_data["type"] = OBJECT_TYPES[type_option.selected]
	object_data["position"] = Vector2(x_spin.value, y_spin.value)
	object_data["solid"] = solid_check.button_pressed
	object_data["interactable"] = interact_check.button_pressed
	object_data["trigger_mode"] = TRIGGER_MODES[trigger_option.selected]
	object_data["dialogue"] = dialogue_edit.text.strip_edges()
	scene_objects[object_index] = object_data
	refresh_all()
	_record_and_save()
	append_log("已更新对象属性: %s" % object_data["name"])

func _on_apply_ai_pressed() -> void:
	var prompt := prompt_input.text.strip_edges()
	var object_index := _find_object_index(selected_object_id)
	if object_index == -1:
		append_log("请先选择对象，再让 AI 帮你补逻辑。")
		return

	if _ai_available:
		_ai_pending_object_index = object_index
		append_log("正在请求 AI 生成逻辑...")
		_ai_client.generate_game_logic(prompt, scene_objects[object_index])
		prompt_input.clear()
	else:
		_apply_template_fallback(prompt, object_index)

func _apply_template_fallback(prompt: String, object_index: int) -> void:
	var result: Dictionary = LogicTemplatesScript.apply_prompt(prompt, scene_objects[object_index])
	var updates: Dictionary = result.get("updates", {})
	for key in updates.keys():
		_apply_update(scene_objects[object_index], String(key), updates[key])
	for note in result.get("notes", []):
		append_log(String(note))
	refresh_all()
	_record_and_save()
	prompt_input.clear()
	append_log("模板指令已应用到对象: %s（AI 不可用，使用内置模板）" % scene_objects[object_index]["name"])

func _on_ai_response(result: Dictionary) -> void:
	var content := String(result.get("content", ""))
	if content.is_empty():
		if result.has("status"):
			_ai_available = true
			append_log("AI 服务已连接 (%s)。" % _ai_client.model)
		return

	if _ai_pending_object_index == -1 or _ai_pending_object_index >= scene_objects.size():
		append_log("AI 返回了结果，但目标对象已不存在。")
		_ai_pending_object_index = -1
		return

	var json := JSON.new()
	if json.parse(content) != OK:
		append_log("AI 返回内容不是有效 JSON，回退到模板模式。")
		append_log("AI 原始回复: %s" % content.substr(0, 200))
		_ai_pending_object_index = -1
		return

	var parsed: Dictionary = json.data
	var updates: Dictionary = parsed.get("updates", {})
	var notes: Array = parsed.get("notes", [])

	for key in updates.keys():
		_apply_update(scene_objects[_ai_pending_object_index], String(key), updates[key])
	for note in notes:
		append_log(String(note))

	refresh_all()
	_record_and_save()
	append_log("AI 逻辑已应用到对象: %s" % scene_objects[_ai_pending_object_index]["name"])
	_ai_pending_object_index = -1

func _on_ai_error(error_message: String) -> void:
	if not _ai_available:
		_ai_available = false
		append_log("AI 不可用: %s（将使用内置模板模式）" % error_message)
	else:
		append_log("AI 请求失败: %s" % error_message)
		if _ai_pending_object_index != -1:
			append_log("回退到模板模式...")
			var prompt := prompt_input.text.strip_edges()
			if not prompt.is_empty() and _ai_pending_object_index < scene_objects.size():
				_apply_template_fallback(prompt, _ai_pending_object_index)
			_ai_pending_object_index = -1

func _apply_update(target: Dictionary, path: String, value: Variant) -> void:
	var parts := path.split("/")
	if parts.size() == 1:
		target[parts[0]] = value
		return

	var current: Dictionary = target
	for part_index in range(parts.size() - 1):
		var part := parts[part_index]
		if not current.has(part) or typeof(current[part]) != TYPE_DICTIONARY:
			current[part] = {}
		current = current[part]
	current[parts[parts.size() - 1]] = value

func _on_events_changed(new_events: Array[Dictionary]) -> void:
	events = new_events
	_record_and_save()
	append_log("事件已更新，共 %d 条。" % events.size())

func _refresh_event_editor() -> void:
	var names: Dictionary = {}
	for obj in scene_objects:
		names[String(obj.get("id", ""))] = String(obj.get("name", ""))
	event_editor.set_events(events, names)

func refresh_all() -> void:
	refresh_resource_list()
	refresh_object_list()
	refresh_canvas()
	refresh_inspector()
	_refresh_event_editor()

func refresh_resource_list() -> void:
	resource_list.clear()
	for resource_data in resources:
		resource_list.add_item("[%s] %s" % [resource_data.get("kind", "image"), resource_data.get("name", "")])
	if selected_resource_index >= 0 and selected_resource_index < resource_list.item_count:
		resource_list.select(selected_resource_index)

func refresh_object_list() -> void:
	object_list.clear()
	var selected_index := -1
	for index in scene_objects.size():
		var object_data := scene_objects[index]
		object_list.add_item("%s · %s" % [object_data.get("type", "object"), object_data.get("name", "")])
		if String(object_data.get("id", "")) == selected_object_id:
			selected_index = index
	if selected_index != -1:
		object_list.select(selected_index)

func refresh_canvas() -> void:
	canvas.set_scene_objects(scene_objects, selected_object_id, tile_cells, tool_mode, selected_terrain, selected_layer)

func refresh_inspector() -> void:
	var object_index := _find_object_index(selected_object_id)
	var has_object := object_index != -1
	name_edit.editable = has_object
	type_option.disabled = not has_object
	x_spin.editable = has_object
	y_spin.editable = has_object
	solid_check.disabled = not has_object
	interact_check.disabled = not has_object
	trigger_option.disabled = not has_object
	dialogue_edit.editable = has_object

	_refresh_behavior_ui(object_index if has_object else -1)
	_refresh_animation_ui(object_index if has_object else -1)

	if not has_object:
		name_edit.text = ""
		dialogue_edit.text = ""
		return

	var object_data := scene_objects[object_index]
	name_edit.text = String(object_data.get("name", ""))
	type_option.select(max(OBJECT_TYPES.find(String(object_data.get("type", "prop"))), 0))
	x_spin.value = float(object_data.get("position", Vector2.ZERO).x)
	y_spin.value = float(object_data.get("position", Vector2.ZERO).y)
	solid_check.button_pressed = bool(object_data.get("solid", false))
	interact_check.button_pressed = bool(object_data.get("interactable", false))
	trigger_option.select(max(TRIGGER_MODES.find(String(object_data.get("trigger_mode", "interact"))), 0))
	dialogue_edit.text = String(object_data.get("dialogue", ""))

func select_object(object_id: String) -> void:
	selected_object_id = object_id
	refresh_all()

func _find_object_index(object_id: String) -> int:
	for index in scene_objects.size():
		if String(scene_objects[index].get("id", "")) == object_id:
			return index
	return -1

func append_log(message: String) -> void:
	log_output.append_text("- %s\n" % message)
	log_output.scroll_to_line(max(log_output.get_line_count() - 1, 0))

func _load_snapshot() -> void:
	var snapshot: Dictionary = ProjectStoreScript.load_snapshot()
	resources = snapshot.get("resources", [])
	scene_objects = snapshot.get("scene_objects", [])
	_next_object_id = int(snapshot.get("next_object_id", 1))
	tile_cells = snapshot.get("tile_cells", [])
	events = []
	for evt in snapshot.get("events", []):
		events.append(evt)
	if not scene_objects.is_empty():
		selected_object_id = String(scene_objects[0].get("id", ""))

func _apply_tile_change(cell: Vector2i, terrain: String, layer: String = "ground") -> void:
	var tile_index := _find_tile_index(cell, layer)
	if terrain == "erase":
		if tile_index != -1:
			tile_cells.remove_at(tile_index)
		return

	var entry: Dictionary = {
		"x": cell.x,
		"y": cell.y,
		"terrain": terrain,
		"layer": layer,
	}
	if tile_index == -1:
		tile_cells.append(entry)
	else:
		tile_cells[tile_index] = entry

func _find_tile_index(cell: Vector2i, layer: String = "ground") -> int:
	for index in tile_cells.size():
		if int(tile_cells[index].get("x", -1)) == cell.x and int(tile_cells[index].get("y", -1)) == cell.y and String(tile_cells[index].get("layer", "ground")) == layer:
			return index
	return -1

# --- Scene Management ---

func _init_scene_manager() -> void:
	_scene_list = SceneManagerScript.load_index()
	_refresh_scene_option()

func _refresh_scene_option() -> void:
	scene_option.clear()
	var selected_idx := 0
	for i in _scene_list.size():
		var entry: Dictionary = _scene_list[i]
		scene_option.add_item(String(entry.get("title", "?")), i)
		if String(entry.get("id", "")) == _current_scene_id:
			selected_idx = i
	scene_option.select(selected_idx)

func _load_current_scene() -> void:
	if _current_scene_id == "main":
		_load_snapshot()
	else:
		var data := SceneManagerScript.load_scene_data(_current_scene_id)
		if data.is_empty():
			_load_snapshot()
		else:
			resources = _deserialize_resources(data.get("resources", []))
			scene_objects = _deserialize_scene_objects(data.get("scene_objects", []))
			_next_object_id = int(data.get("next_object_id", 1))
			tile_cells = _deserialize_tile_cells(data.get("tile_cells", []))
			events = []
			for evt in data.get("events", []):
				events.append(evt)
			if not scene_objects.is_empty():
				selected_object_id = String(scene_objects[0].get("id", ""))

func _save_current_scene() -> void:
	if _current_scene_id == "main":
		ProjectStoreScript.save_snapshot(resources, scene_objects, _next_object_id, tile_cells, events)
	else:
		var data := {
			"resources": ProjectStoreScript._serialize_resources(resources),
			"scene_objects": ProjectStoreScript._serialize_scene_objects(scene_objects),
			"next_object_id": _next_object_id,
			"tile_cells": ProjectStoreScript._serialize_tile_cells(tile_cells),
			"events": events.duplicate(true),
		}
		SceneManagerScript.save_scene_data(_current_scene_id, data)

func _deserialize_resources(data: Array) -> Array[Dictionary]:
	return ProjectStoreScript._deserialize_resources(data)

func _deserialize_scene_objects(data: Array) -> Array[Dictionary]:
	return ProjectStoreScript._deserialize_scene_objects(data)

func _deserialize_tile_cells(data: Array) -> Array[Dictionary]:
	return ProjectStoreScript._deserialize_tile_cells(data)

func _on_scene_option_selected(index: int) -> void:
	if index < 0 or index >= _scene_list.size():
		return
	var new_id := String(_scene_list[index].get("id", ""))
	if new_id == _current_scene_id:
		return
	_save_current_scene()
	_current_scene_id = new_id
	_load_current_scene()
	refresh_all()
	_push_undo_state()
	append_log("已切换到场景: %s" % _scene_list[index].get("title", "?"))

func _on_add_scene_pressed() -> void:
	var entry := SceneManagerScript.add_scene("新场景 %d" % (_scene_list.size() + 1))
	_scene_list = SceneManagerScript.load_index()
	_save_current_scene()
	_current_scene_id = String(entry.get("id", ""))
	_load_current_scene()
	_refresh_scene_option()
	refresh_all()
	_push_undo_state()
	append_log("已创建新场景: %s" % entry.get("title", ""))

func _on_remove_scene_pressed() -> void:
	if _current_scene_id == "main":
		append_log("无法删除主场景。")
		return
	var removed_title := ""
	for s in _scene_list:
		if String(s.get("id", "")) == _current_scene_id:
			removed_title = String(s.get("title", ""))
	SceneManagerScript.remove_scene(_current_scene_id)
	_scene_list = SceneManagerScript.load_index()
	_current_scene_id = "main"
	_load_current_scene()
	_refresh_scene_option()
	refresh_all()
	_push_undo_state()
	append_log("已删除场景: %s" % removed_title)

# --- Animation UI ---

func _refresh_animation_ui(object_index: int) -> void:
	for child in animation_container.get_children():
		child.queue_free()

	if object_index == -1:
		return

	var obj := scene_objects[object_index]
	var anim_set: Dictionary = obj.get("animation_set", {})
	var anims: Dictionary = anim_set.get("animations", {})

	for anim_id in anims.keys():
		var anim: Dictionary = anims[anim_id]
		var preset := AnimationSystemScript.get_preset(anim_id)
		var row := HBoxContainer.new()

		var color_rect := ColorRect.new()
		color_rect.color = preset.get("color", Color.WHITE)
		color_rect.custom_minimum_size = Vector2(12, 12)
		row.add_child(color_rect)

		var frame_count: int = anim.get("frames", []).size()
		var label := Label.new()
		label.text = "%s (%d帧, %dfps)" % [AnimationSystemScript.animation_label(anim_id), frame_count, int(anim.get("fps", 8))]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var remove_btn := Button.new()
		remove_btn.text = "✕"
		remove_btn.custom_minimum_size.x = 28
		var aid := anim_id
		remove_btn.pressed.connect(func():
			_remove_animation(object_index, aid)
		)
		row.add_child(remove_btn)
		animation_container.add_child(row)

	var add_btn := MenuButton.new()
	add_btn.text = "+ 添加动画"
	add_btn.flat = false
	var popup := add_btn.get_popup()
	var presets := AnimationSystemScript.get_presets()
	for pi in presets.size():
		popup.add_item("%s — %s" % [presets[pi].get("name", ""), presets[pi].get("description", "")], pi)
	popup.id_pressed.connect(func(id: int):
		_add_animation(object_index, String(presets[id].get("id", "")))
	)
	animation_container.add_child(add_btn)

func _add_animation(object_index: int, anim_id: String) -> void:
	if object_index < 0 or object_index >= scene_objects.size():
		return
	if not scene_objects[object_index].has("animation_set"):
		scene_objects[object_index]["animation_set"] = AnimationSystemScript.create_animation_set()
	var anim := AnimationSystemScript.create_animation(anim_id)
	AnimationSystemScript.add_animation(scene_objects[object_index]["animation_set"], anim)
	refresh_inspector()
	_record_and_save()
	append_log("已添加动画: %s" % AnimationSystemScript.animation_label(anim_id))

func _remove_animation(object_index: int, anim_id: String) -> void:
	if object_index < 0 or object_index >= scene_objects.size():
		return
	var anim_set: Dictionary = scene_objects[object_index].get("animation_set", {})
	AnimationSystemScript.remove_animation(anim_set, anim_id)
	refresh_inspector()
	_record_and_save()
	append_log("已移除动画: %s" % AnimationSystemScript.animation_label(anim_id))

# --- Behavior UI ---

func _refresh_behavior_ui(object_index: int) -> void:
	for child in behavior_container.get_children():
		child.queue_free()

	if object_index == -1:
		return

	var obj := scene_objects[object_index]
	var attached: Array = obj.get("attached_behaviors", [])

	for bi in attached.size():
		var beh: Dictionary = attached[bi]
		var btype := int(beh.get("behavior_type", 0))
		var info := BehaviorSystemScript.get_by_type(btype as BehaviorSystemScript.BehaviorType)
		var row := HBoxContainer.new()
		var color_rect := ColorRect.new()
		color_rect.color = info.get("color", Color.WHITE)
		color_rect.custom_minimum_size = Vector2(12, 12)
		row.add_child(color_rect)
		var label := Label.new()
		label.text = "%s" % info.get("name", "未知")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var remove_btn := Button.new()
		remove_btn.text = "✕"
		remove_btn.custom_minimum_size.x = 28
		var bi_ref := bi
		remove_btn.pressed.connect(func():
			_remove_behavior(object_index, bi_ref)
		)
		row.add_child(remove_btn)
		behavior_container.add_child(row)

	var add_btn := MenuButton.new()
	add_btn.text = "+ 添加行为"
	add_btn.flat = false
	var popup := add_btn.get_popup()
	var catalog := BehaviorSystemScript.get_catalog()
	for ci in catalog.size():
		popup.add_item("%s — %s" % [catalog[ci].get("name", ""), catalog[ci].get("description", "")], ci)
	popup.id_pressed.connect(func(id: int):
		_add_behavior(object_index, int(catalog[id].get("type", 0)))
	)
	behavior_container.add_child(add_btn)

func _add_behavior(object_index: int, btype: int) -> void:
	if object_index < 0 or object_index >= scene_objects.size():
		return
	var beh := BehaviorSystemScript.create_behavior_data(btype as BehaviorSystemScript.BehaviorType)
	if not scene_objects[object_index].has("attached_behaviors"):
		scene_objects[object_index]["attached_behaviors"] = []
	scene_objects[object_index]["attached_behaviors"].append(beh)
	refresh_inspector()
	_record_and_save()
	append_log("已添加行为: %s" % BehaviorSystemScript.behavior_label(btype))

func _remove_behavior(object_index: int, behavior_index: int) -> void:
	if object_index < 0 or object_index >= scene_objects.size():
		return
	var attached: Array = scene_objects[object_index].get("attached_behaviors", [])
	if behavior_index < 0 or behavior_index >= attached.size():
		return
	var removed_name := BehaviorSystemScript.behavior_label(int(attached[behavior_index].get("behavior_type", 0)))
	attached.remove_at(behavior_index)
	refresh_inspector()
	_record_and_save()
	append_log("已移除行为: %s" % removed_name)
