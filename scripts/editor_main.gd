extends Control

const LogicTemplatesScript = preload("res://scripts/logic_templates.gd")
const ProjectStoreScript = preload("res://scripts/project_store.gd")
const OBJECT_TYPES := ["player", "npc", "door", "chest", "trigger", "prop"]
const TRIGGER_MODES := ["interact", "touch", "area", "auto"]

var resources: Array[Dictionary] = []
var scene_objects: Array[Dictionary] = []
var tile_cells: Array[Dictionary] = []
var selected_resource_index := -1
var selected_object_id := ""
var _next_object_id := 1
var tool_mode := "select"
var selected_terrain := "ground"

@onready var resource_list: ItemList = $MainSplit/LeftPanel/ResourceList
@onready var object_list: ItemList = $MainSplit/LeftPanel/ObjectList
@onready var canvas = $MainSplit/CenterPanel/CanvasPanel/SceneCanvas
@onready var log_output: RichTextLabel = $MainSplit/CenterPanel/LogOutput
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

func _ready() -> void:
	_setup_options()
	_setup_dialog()
	_bind_events()
	_load_snapshot()
	if scene_objects.is_empty():
		_add_object("player")
	refresh_all()
	append_log("Lite2D Studio 已启动。当前为 2D 轻量编辑器骨架，可继续接 AI CLI。")

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
	file_dialog.files_selected.connect(_on_files_selected)

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
	_save_snapshot()
	append_log("已生成预览快照，准备切换到运行预览。")
	get_tree().change_scene_to_file("res://scenes/runtime_preview.tscn")

func _on_select_tool_pressed() -> void:
	tool_mode = "select"
	append_log("已切换到对象选择模式。")
	refresh_canvas()

func _on_ground_tool_pressed() -> void:
	tool_mode = "paint"
	selected_terrain = "ground"
	append_log("已切换到地面绘制模式。")
	refresh_canvas()

func _on_wall_tool_pressed() -> void:
	tool_mode = "paint"
	selected_terrain = "wall"
	append_log("已切换到墙体绘制模式。")
	refresh_canvas()

func _on_water_tool_pressed() -> void:
	tool_mode = "paint"
	selected_terrain = "water"
	append_log("已切换到水域绘制模式。")
	refresh_canvas()

func _on_erase_tool_pressed() -> void:
	tool_mode = "paint"
	selected_terrain = "erase"
	append_log("已切换到地图擦除模式。")
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
	_save_snapshot()
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
	_save_snapshot()
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
	scene_objects[object_index]["position"] = position
	refresh_inspector()
	refresh_object_list()
	_save_snapshot()

func _on_canvas_tile_painted(cell: Vector2i, terrain: String) -> void:
	_apply_tile_change(cell, terrain)
	_save_snapshot()
	refresh_canvas()

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
	_save_snapshot()
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
	_save_snapshot()
	append_log("已更新对象属性: %s" % object_data["name"])

func _on_apply_ai_pressed() -> void:
	var prompt := prompt_input.text.strip_edges()
	var object_index := _find_object_index(selected_object_id)
	if object_index == -1:
		append_log("请先选择对象，再让 AI 帮你补逻辑。")
		return

	var result: Dictionary = LogicTemplatesScript.apply_prompt(prompt, scene_objects[object_index])
	var updates: Dictionary = result.get("updates", {})
	for key in updates.keys():
		_apply_update(scene_objects[object_index], String(key), updates[key])
	for note in result.get("notes", []):
		append_log(String(note))

	refresh_all()
	_save_snapshot()
	prompt_input.clear()
	append_log("AI 指令已应用到对象: %s" % scene_objects[object_index]["name"])

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

func refresh_all() -> void:
	refresh_resource_list()
	refresh_object_list()
	refresh_canvas()
	refresh_inspector()

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
	canvas.set_scene_objects(scene_objects, selected_object_id, tile_cells, tool_mode, selected_terrain)

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

func _save_snapshot() -> void:
	ProjectStoreScript.save_snapshot(resources, scene_objects, _next_object_id, tile_cells)

func _load_snapshot() -> void:
	var snapshot: Dictionary = ProjectStoreScript.load_snapshot()
	resources = snapshot.get("resources", [])
	scene_objects = snapshot.get("scene_objects", [])
	_next_object_id = int(snapshot.get("next_object_id", 1))
	tile_cells = snapshot.get("tile_cells", [])
	if not scene_objects.is_empty():
		selected_object_id = String(scene_objects[0].get("id", ""))

func _apply_tile_change(cell: Vector2i, terrain: String) -> void:
	var tile_index := _find_tile_index(cell)
	if terrain == "erase":
		if tile_index != -1:
			tile_cells.remove_at(tile_index)
		return

	var entry: Dictionary = {
		"x": cell.x,
		"y": cell.y,
		"terrain": terrain,
	}
	if tile_index == -1:
		tile_cells.append(entry)
	else:
		tile_cells[tile_index] = entry

func _find_tile_index(cell: Vector2i) -> int:
	for index in tile_cells.size():
		if int(tile_cells[index].get("x", -1)) == cell.x and int(tile_cells[index].get("y", -1)) == cell.y:
			return index
	return -1
