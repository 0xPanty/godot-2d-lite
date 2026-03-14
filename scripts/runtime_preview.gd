extends Node2D

const ProjectStoreScript = preload("res://scripts/project_store.gd")
const EventRunnerScript = preload("res://scripts/event_runner.gd")
const BehaviorRunnerScript = preload("res://scripts/behavior_runner.gd")
const BehaviorSystemScript = preload("res://scripts/behavior_system.gd")
const DialogueSystemScript = preload("res://scripts/dialogue_system.gd")
const InventorySystemScript = preload("res://scripts/inventory_system.gd")
const QuestSystemScript = preload("res://scripts/quest_system.gd")
const SaveSystemScript = preload("res://scripts/save_system.gd")
const AnimationRunnerScript = preload("res://scripts/animation_runner.gd")
const DialogueUIScene = preload("res://scenes/dialogue_ui.tscn")
const InventoryUIScene = preload("res://scenes/inventory_ui.tscn")
const GRID_SIZE := 32.0
const INTERACT_DISTANCE := 84.0
const TERRAIN_COLORS := {
	"ground": Color("334155"),
	"wall": Color("475569"),
	"water": Color("1d4ed8"),
	"grass": Color("166534"),
	"sand": Color("a16207"),
	"path": Color("78716c"),
}

var scene_objects: Array[Dictionary] = []
var tile_cells: Array[Dictionary] = []
var runtime_nodes := {}
var player_body: CharacterBody2D
var player_data: Dictionary = {}
var active_interactable_id := ""
var consumed_object_ids := {}
var _world_ground: Node2D
var _event_runner: Node
var _behavior_runner: RefCounted
var _dialogue_ui: CanvasLayer
var _inventory_ui: CanvasLayer
var _animation_runner: RefCounted
var _inventory: Dictionary = {}
var _quest_journal: Dictionary = {}
var _current_save_slot := 0
var _quest_check_timer := 0.0
const QUEST_CHECK_INTERVAL := 0.5

@onready var world: Node2D = $World
@onready var title_label: Label = $UI/Panel/Margin/VBox/TitleLabel
@onready var hint_label: Label = $UI/Panel/Margin/VBox/HintLabel
@onready var message_label: RichTextLabel = $UI/Panel/Margin/VBox/MessageLabel

func _ready() -> void:
	var snapshot: Dictionary = ProjectStoreScript.load_snapshot()
	scene_objects = snapshot.get("scene_objects", [])
	tile_cells = snapshot.get("tile_cells", [])
	_build_world()
	_setup_dialogue_ui()
	_setup_inventory_ui()
	_setup_inventory()
	_setup_quest_journal()
	_setup_behavior_runner()
	_setup_animation_runner()
	_setup_event_runner(snapshot.get("events", []))
	_update_header()
	_show_message("运行预览已启动。方向键移动，E 交互，Tab 背包，F5 存档，F9 读档。")

func _setup_dialogue_ui() -> void:
	_dialogue_ui = DialogueUIScene.instantiate()
	add_child(_dialogue_ui)

func _setup_inventory_ui() -> void:
	_inventory_ui = InventoryUIScene.instantiate()
	add_child(_inventory_ui)
	_inventory_ui.item_used.connect(_on_item_used)

func _setup_inventory() -> void:
	_inventory = InventorySystemScript.create_inventory()

func _setup_quest_journal() -> void:
	_quest_journal = QuestSystemScript.create_journal()

func _setup_behavior_runner() -> void:
	_behavior_runner = BehaviorRunnerScript.new()
	for object_id in runtime_nodes.keys():
		var entry: Dictionary = runtime_nodes[object_id]
		var obj_data: Dictionary = entry.get("data", {})
		var node: Node2D = entry.get("node")
		if node == null:
			continue
		var attached: Array = obj_data.get("attached_behaviors", [])
		for beh in attached:
			if beh is Dictionary and bool(beh.get("enabled", true)):
				_behavior_runner.register(node, beh, player_body)

func _setup_animation_runner() -> void:
	_animation_runner = AnimationRunnerScript.new()
	for object_id in runtime_nodes.keys():
		var entry: Dictionary = runtime_nodes[object_id]
		var obj_data: Dictionary = entry.get("data", {})
		var node: Node2D = entry.get("node")
		if node == null:
			continue
		var anim_set: Dictionary = obj_data.get("animation_set", {})
		if not anim_set.get("animations", {}).is_empty():
			_animation_runner.register(node, anim_set)

func _setup_event_runner(event_data: Array) -> void:
	_event_runner = EventRunnerScript.new()
	add_child(_event_runner)
	var typed_events: Array[Dictionary] = []
	for evt in event_data:
		if evt is Dictionary:
			typed_events.append(evt)
	_event_runner.load_events(typed_events)
	_event_runner.set_runtime_refs(runtime_nodes, player_body)
	_event_runner.dialogue_requested.connect(_on_event_dialogue)
	_event_runner.scene_change_requested.connect(_on_event_scene_change)
	_event_runner.object_spawn_requested.connect(_on_event_spawn)
	_event_runner.item_added.connect(_on_event_item_added)
	_event_runner.item_removed.connect(_on_event_item_removed)
	_event_runner.quest_accepted.connect(_on_event_quest_accepted)
	_event_runner.quest_completed.connect(_on_event_quest_completed)
	_event_runner.inventory_ref = _inventory
	_event_runner.quest_journal_ref = _quest_journal

func _on_event_dialogue(object_id: String, text: String) -> void:
	var obj_name := "系统"
	if runtime_nodes.has(object_id):
		obj_name = String(runtime_nodes[object_id].get("data", {}).get("name", object_id))
	if _dialogue_ui and not _dialogue_ui.is_active():
		var dlg := DialogueSystemScript.build_linear("", [[obj_name, text]])
		var flags: Dictionary = {}
		if _event_runner:
			flags = _event_runner.flags
		_dialogue_ui.start_dialogue(dlg, flags)
	else:
		_show_message("%s：%s" % [obj_name, text])

func _on_event_scene_change(scene_path: String) -> void:
	_show_message("切换场景: %s" % scene_path)
	get_tree().change_scene_to_file(scene_path)

func _on_event_spawn(object_type: String, pos: Vector2) -> void:
	var obj_data := ProjectStoreScript.default_object(object_type, randi() % 10000)
	obj_data["position"] = pos
	_create_world_object(obj_data)
	_show_message("生成了 %s" % object_type)

func _on_event_item_added(item_id: String, amount: int) -> void:
	_add_item_to_inventory(item_id, amount)

func _on_event_item_removed(item_id: String, amount: int) -> void:
	InventorySystemScript.remove_item(_inventory, item_id, amount)
	var def := InventorySystemScript.get_item_def(item_id)
	_show_message("失去 %s x%d" % [def.get("name", item_id), amount])
	if _inventory_ui:
		_inventory_ui.set_inventory(_inventory)

func _on_event_quest_accepted(quest_id: String) -> void:
	if QuestSystemScript.accept_quest(_quest_journal, quest_id):
		var quest := QuestSystemScript.get_quest(_quest_journal, quest_id)
		_show_message("接受任务: %s" % quest.get("title", quest_id))
	else:
		_show_message("无法接受任务 %s" % quest_id)

func _on_event_quest_completed(quest_id: String) -> void:
	var result := QuestSystemScript.turn_in_quest(_quest_journal, quest_id)
	if result.get("success", false):
		var quest := QuestSystemScript.get_quest(_quest_journal, quest_id)
		_show_message("完成任务: %s" % quest.get("title", quest_id))
		for reward in result.get("rewards", []):
			if String(reward.get("type", "")) == "item":
				var p: Dictionary = reward.get("params", {})
				_add_item_to_inventory(String(p.get("item_id", "")), int(p.get("amount", 1)))
		for flag_name in result.get("flags", []):
			if _event_runner:
				_event_runner.flags[String(flag_name)] = true

func _physics_process(delta: float) -> void:
	if _behavior_runner:
		_behavior_runner.process_all(delta)
	else:
		_update_player_movement()
	if _animation_runner:
		_animation_runner.process_all(delta)
	_update_interaction_hint()
	if _event_runner:
		_event_runner.process_events(delta)
	_quest_check_timer += delta
	if _quest_check_timer >= QUEST_CHECK_INTERVAL:
		_quest_check_timer = 0.0
		_update_quest_progress()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and not active_interactable_id.is_empty():
			_activate_object(active_interactable_id)
		elif event.keycode == KEY_ESCAPE:
			_return_to_editor()
		elif event.keycode == KEY_F5:
			_save_game()
		elif event.keycode == KEY_F9:
			_load_game()
		elif event.keycode == KEY_Q:
			_show_quest_log()

func _build_world() -> void:
	for child in world.get_children():
		child.queue_free()
	runtime_nodes.clear()
	player_body = null
	player_data = {}
	active_interactable_id = ""
	consumed_object_ids.clear()

	_world_ground = Node2D.new()
	_world_ground.name = "WorldGround"
	_world_ground.set_script(_create_ground_drawer_script())
	_world_ground.set("tile_cells", tile_cells)
	_world_ground.set("grid_size", GRID_SIZE)
	_world_ground.set("terrain_colors", TERRAIN_COLORS)
	world.add_child(_world_ground)

	_create_tile_collisions()

	for object_data in scene_objects:
		if String(object_data.get("type", "")) == "player" and player_body == null:
			_create_player(object_data)

	if player_body == null:
		var fallback_player := ProjectStoreScript.default_object("player", 1)
		fallback_player["behaviors"] = {
			"movement": {
				"enabled": true,
				"mode": "topdown",
				"speed": 120.0,
				"camera_follow": true,
			}
		}
		_create_player(fallback_player)

	for object_data in scene_objects:
		if String(object_data.get("type", "")) != "player":
			_create_world_object(object_data)

func _create_ground_drawer_script() -> GDScript:
	var code := """extends Node2D

var tile_cells: Array = []
var grid_size: float = 32.0
var terrain_colors: Dictionary = {}

func _ready() -> void:
	z_index = -10
	queue_redraw()

func _draw() -> void:
	var vp_size := get_viewport_rect().size
	var cam_pos := Vector2.ZERO
	var camera := get_viewport().get_camera_2d()
	if camera:
		cam_pos = camera.global_position - vp_size / 2.0

	var bg_rect := Rect2(cam_pos, vp_size)
	draw_rect(bg_rect, Color("101828"), true)

	for tile_data in tile_cells:
		var terrain: String = str(tile_data.get("terrain", "ground"))
		var color: Color = terrain_colors.get(terrain, Color("334155"))
		var cell := Vector2(float(tile_data.get("x", 0)) * grid_size, float(tile_data.get("y", 0)) * grid_size)
		draw_rect(Rect2(cell, Vector2.ONE * grid_size), color, true)

	var start_x := int(cam_pos.x / grid_size) * int(grid_size)
	var start_y := int(cam_pos.y / grid_size) * int(grid_size)
	var end_x := int(cam_pos.x + vp_size.x) + int(grid_size)
	var end_y := int(cam_pos.y + vp_size.y) + int(grid_size)
	for x in range(start_x, end_x, int(grid_size)):
		draw_line(Vector2(x, cam_pos.y), Vector2(x, cam_pos.y + vp_size.y), Color(1, 1, 1, 0.05), 1.0)
	for y in range(start_y, end_y, int(grid_size)):
		draw_line(Vector2(cam_pos.x, y), Vector2(cam_pos.x + vp_size.x, y), Color(1, 1, 1, 0.05), 1.0)

func _process(_delta: float) -> void:
	queue_redraw()
"""
	var script := GDScript.new()
	script.source_code = code
	script.reload()
	return script

func _create_tile_collisions() -> void:
	for tile_data in tile_cells:
		if String(tile_data.get("terrain", "ground")) != "wall":
			continue
		var body := StaticBody2D.new()
		body.position = Vector2(float(tile_data.get("x", 0)) * GRID_SIZE + GRID_SIZE / 2.0, float(tile_data.get("y", 0)) * GRID_SIZE + GRID_SIZE / 2.0)
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2.ONE * GRID_SIZE
		collision.shape = shape
		body.add_child(collision)
		world.add_child(body)

func _create_player(object_data: Dictionary) -> void:
	var body := CharacterBody2D.new()
	body.name = String(object_data.get("name", "Player"))
	body.position = _get_center(object_data)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = object_data.get("size", Vector2(96, 96))
	collision.shape = shape
	body.add_child(collision)

	var visual := _create_visual(object_data, Color("60a5fa"))
	body.add_child(visual)

	var movement_behavior: Dictionary = _get_behavior(object_data, "movement")
	if bool(movement_behavior.get("camera_follow", true)):
		var camera := Camera2D.new()
		camera.enabled = true
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 8.0
		body.add_child(camera)

	world.add_child(body)
	player_body = body
	player_data = object_data.duplicate(true)
	runtime_nodes[String(object_data.get("id", "player"))] = {
		"data": object_data.duplicate(true),
		"node": body,
		"visual": visual,
	}

func _create_world_object(object_data: Dictionary) -> void:
	var wrapper := Node2D.new()
	wrapper.name = String(object_data.get("name", "Object"))
	wrapper.position = _get_center(object_data)

	var visual := _create_visual(object_data, _color_for_type(String(object_data.get("type", "prop"))))
	wrapper.add_child(visual)

	if bool(object_data.get("solid", false)):
		var body := StaticBody2D.new()
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = object_data.get("size", Vector2(96, 96))
		collision.shape = shape
		body.add_child(collision)
		wrapper.add_child(body)

	var trigger_mode := String(object_data.get("trigger_mode", "interact"))
	if bool(object_data.get("interactable", false)) or trigger_mode in ["touch", "area", "auto"]:
		var area := Area2D.new()
		var area_collision := CollisionShape2D.new()
		var area_shape := RectangleShape2D.new()
		area_shape.size = object_data.get("size", Vector2(96, 96)) + Vector2(12, 12)
		area_collision.shape = area_shape
		area.add_child(area_collision)
		area.body_entered.connect(_on_area_body_entered.bind(String(object_data.get("id", ""))))
		wrapper.add_child(area)

	world.add_child(wrapper)
	runtime_nodes[String(object_data.get("id", ""))] = {
		"data": object_data.duplicate(true),
		"node": wrapper,
		"visual": visual,
	}

func _create_visual(object_data: Dictionary, fallback_color: Color) -> CanvasItem:
	var size: Vector2 = object_data.get("size", Vector2(96, 96))
	var resource_path := String(object_data.get("resource_path", ""))
	var texture := _load_texture(resource_path)
	if texture:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.offset = -size / 2.0
		if texture.get_size().x > 0 and texture.get_size().y > 0:
			sprite.scale = Vector2(size.x / texture.get_size().x, size.y / texture.get_size().y)
		return sprite

	var visual_root := Node2D.new()
	var polygon := Polygon2D.new()
	polygon.color = fallback_color
	polygon.polygon = PackedVector2Array([
		Vector2(-size.x / 2.0, -size.y / 2.0),
		Vector2(size.x / 2.0, -size.y / 2.0),
		Vector2(size.x / 2.0, size.y / 2.0),
		Vector2(-size.x / 2.0, size.y / 2.0),
	])
	visual_root.add_child(polygon)

	var label := Label.new()
	label.text = String(object_data.get("name", "Object"))
	label.position = Vector2(-size.x / 2.0, size.y / 2.0 + 4.0)
	label.size = Vector2(size.x + 40.0, 24.0)
	visual_root.add_child(label)
	return visual_root

func _update_player_movement() -> void:
	if player_body == null:
		return
	var movement_behavior: Dictionary = _get_behavior(player_data, "movement")
	if not bool(movement_behavior.get("enabled", false)):
		player_body.velocity = Vector2.ZERO
		return
	var speed := float(movement_behavior.get("speed", 120.0))
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player_body.velocity = input_vector * speed
	player_body.move_and_slide()

func _update_interaction_hint() -> void:
	active_interactable_id = ""
	if player_body == null:
		hint_label.text = "未检测到玩家对象。"
		return

	var nearest_distance := INTERACT_DISTANCE
	for object_id in runtime_nodes.keys():
		if object_id == String(player_data.get("id", "")):
			continue
		var entry: Dictionary = runtime_nodes[object_id]
		var object_data: Dictionary = entry.get("data", {})
		if not bool(object_data.get("interactable", false)):
			continue
		if String(object_data.get("trigger_mode", "interact")) != "interact":
			continue
		var node: Node2D = entry.get("node")
		var distance := player_body.global_position.distance_to(node.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			active_interactable_id = object_id

	if active_interactable_id.is_empty():
		hint_label.text = "方向键移动 E交互 Tab背包 Q任务 F5存档 F9读档"
	else:
		var object_name := String(runtime_nodes[active_interactable_id].get("data", {}).get("name", "对象"))
		hint_label.text = "按 E 与 %s 交互" % object_name

func _activate_object(object_id: String) -> void:
	if not runtime_nodes.has(object_id):
		return
	var entry: Dictionary = runtime_nodes[object_id]
	var object_data: Dictionary = entry.get("data", {})

	if _is_single_use(object_data) and consumed_object_ids.has(object_id):
		_show_message("%s 已经触发过了。" % object_data.get("name", "对象"))
		return

	var scene_transition: Dictionary = _get_behavior(object_data, "scene_transition")
	var reward: Dictionary = _get_behavior(object_data, "reward")
	var event_behavior: Dictionary = _get_behavior(object_data, "event")

	if bool(scene_transition.get("enabled", false)):
		consumed_object_ids[object_id] = true
		_show_message("正在切换场景：%s" % scene_transition.get("target_scene", "res://scenes/placeholder_target.tscn"))
		get_tree().change_scene_to_file(String(scene_transition.get("target_scene", "res://scenes/placeholder_target.tscn")))
		return

	if bool(reward.get("enabled", false)):
		consumed_object_ids[object_id] = true
		var reward_item_id := String(reward.get("item_id", "coin"))
		var reward_amount := int(reward.get("amount", 1))
		_add_item_to_inventory(reward_item_id, reward_amount)
		var visual: CanvasItem = entry.get("visual")
		if visual:
			visual.modulate = Color(0.7, 0.7, 0.7)
		return

	if bool(event_behavior.get("enabled", false)):
		consumed_object_ids[object_id] = true
		_show_message("触发事件：%s" % event_behavior.get("event_id", "sample_event"))
		return

	# Check for rich dialogue data first
	var dialogue_data: Variant = object_data.get("dialogue_data", null)
	if dialogue_data is Dictionary and not dialogue_data.is_empty():
		if _dialogue_ui and not _dialogue_ui.is_active():
			var flags: Dictionary = _event_runner.flags if _event_runner else {}
			_dialogue_ui.start_dialogue(dialogue_data, flags)
		if _is_single_use(object_data):
			consumed_object_ids[object_id] = true
		return

	# Fallback to simple text dialogue
	var dialogue := String(object_data.get("dialogue", "")).strip_edges()
	if not dialogue.is_empty():
		var speaker := String(object_data.get("name", "对象"))
		if _dialogue_ui and not _dialogue_ui.is_active():
			var dlg := DialogueSystemScript.build_linear("", [[speaker, dialogue]])
			_dialogue_ui.start_dialogue(dlg)
		else:
			_show_message("%s：%s" % [speaker, dialogue])
		if _is_single_use(object_data):
			consumed_object_ids[object_id] = true
		return

	_show_message("%s 被激活，但还没有绑定更具体的逻辑。" % object_data.get("name", "对象"))

func _on_area_body_entered(body: Node2D, object_id: String) -> void:
	if player_body == null or body != player_body or not runtime_nodes.has(object_id):
		return
	var object_data: Dictionary = runtime_nodes[object_id].get("data", {})
	if String(object_data.get("trigger_mode", "interact")) in ["touch", "area", "auto"]:
		_activate_object(object_id)

func _is_single_use(object_data: Dictionary) -> bool:
	var object_type := String(object_data.get("type", ""))
	return object_type in ["chest", "trigger", "door"]

func _get_behavior(object_data: Dictionary, key: String) -> Dictionary:
	var behaviors: Dictionary = object_data.get("behaviors", {})
	if behaviors.has(key) and typeof(behaviors[key]) == TYPE_DICTIONARY:
		return behaviors[key]
	return {}

func _get_center(object_data: Dictionary) -> Vector2:
	var position: Vector2 = object_data.get("position", Vector2.ZERO)
	var object_size: Vector2 = object_data.get("size", Vector2(96, 96))
	return position + object_size / 2.0

func _color_for_type(object_type: String) -> Color:
	match object_type:
		"npc":
			return Color("34d399")
		"door":
			return Color("f59e0b")
		"chest":
			return Color("f97316")
		"trigger":
			return Color("a78bfa")
		"prop":
			return Color("94a3b8")
		_:
			return Color("e5e7eb")

func _load_texture(resource_path: String) -> Texture2D:
	if resource_path.is_empty():
		return null
	if resource_path.begins_with("res://") and ResourceLoader.exists(resource_path):
		return load(resource_path)
	if FileAccess.file_exists(resource_path):
		var image := Image.new()
		if image.load(resource_path) == OK:
			return ImageTexture.create_from_image(image)
	return null

func _update_header() -> void:
	title_label.text = "运行预览 · 对象 %s 个 / 地图块 %s 个" % [scene_objects.size(), tile_cells.size()]

func _show_message(message: String) -> void:
	message_label.clear()
	message_label.append_text(message)

## --- Inventory helpers ---

func _add_item_to_inventory(item_id: String, amount: int = 1) -> void:
	var result := InventorySystemScript.add_item(_inventory, item_id, amount)
	var def := InventorySystemScript.get_item_def(item_id)
	var name := String(def.get("name", item_id))
	if result.get("success", false):
		_show_message("获得 %s x%d" % [name, amount])
	else:
		_show_message("背包已满，无法获得 %s" % name)
	if _inventory_ui:
		_inventory_ui.set_inventory(_inventory)

func _on_item_used(item_id: String) -> void:
	var def := InventorySystemScript.get_item_def(item_id)
	var effects: Dictionary = def.get("effects", {})
	if effects.has("heal") and player_data.has("hp"):
		var hp := float(player_data.get("hp", 0))
		var max_hp := float(player_data.get("max_hp", 100))
		player_data["hp"] = minf(hp + float(effects["heal"]), max_hp)
		_show_message("使用 %s，恢复了 %d 生命值" % [def.get("name", item_id), int(effects["heal"])])
	else:
		_show_message("使用了 %s" % def.get("name", item_id))
	InventorySystemScript.remove_item(_inventory, item_id, 1)
	if _inventory_ui:
		_inventory_ui.set_inventory(_inventory)

## --- Quest helpers ---

func _show_quest_log() -> void:
	var active := QuestSystemScript.get_active_quests(_quest_journal)
	if active.is_empty():
		_show_message("当前没有进行中的任务。")
		return
	var lines: PackedStringArray = []
	for quest in active:
		lines.append("[b]%s[/b] — %s" % [quest.get("title", "?"), quest.get("description", "")])
		for obj in quest.get("objectives", []):
			lines.append("  %s" % QuestSystemScript.objective_label(obj))
	_show_message("\n".join(lines))

func _update_quest_progress() -> void:
	var flags: Dictionary = _event_runner.flags if _event_runner else {}
	var player_pos := player_body.global_position if player_body else Vector2.ZERO
	for quest_id in _quest_journal.get("quests", {}).keys():
		var quest: Dictionary = _quest_journal["quests"][quest_id]
		if int(quest.get("status", 0)) == QuestSystemScript.QuestStatus.ACTIVE:
			QuestSystemScript.check_objectives(_quest_journal, quest_id, flags, _inventory, player_pos)

## --- Save/Load ---

func _save_game() -> void:
	var flags: Dictionary = _event_runner.flags if _event_runner else {}
	var player_pos := player_body.global_position if player_body else Vector2.ZERO
	var state := SaveSystemScript.capture_runtime_state(player_pos, _inventory, _quest_journal, flags, consumed_object_ids)
	var result := SaveSystemScript.save_game(_current_save_slot, state)
	if result.get("success", false):
		_show_message("游戏已保存到槽位 %d。" % _current_save_slot)
	else:
		_show_message("保存失败：%s" % result.get("reason", "unknown"))

func _load_game() -> void:
	var result := SaveSystemScript.load_game(_current_save_slot)
	if not result.get("success", false):
		_show_message("读档失败：%s" % result.get("reason", "no_save"))
		return
	var state := SaveSystemScript.extract_runtime_state(result)
	_inventory = state.get("inventory", InventorySystemScript.create_inventory())
	_quest_journal = state.get("quest_journal", QuestSystemScript.create_journal())
	consumed_object_ids = state.get("consumed_object_ids", {})
	if _event_runner:
		_event_runner.flags = state.get("flags", {})
		_event_runner.inventory_ref = _inventory
		_event_runner.quest_journal_ref = _quest_journal
	var pos: Vector2 = state.get("player_position", Vector2.ZERO)
	if player_body and pos != Vector2.ZERO:
		player_body.global_position = pos
	if _inventory_ui:
		_inventory_ui.set_inventory(_inventory)
	_show_message("已从槽位 %d 读取存档。" % _current_save_slot)

func _return_to_editor() -> void:
	get_tree().change_scene_to_file("res://scenes/editor_main.tscn")

func _on_back_button_pressed() -> void:
	_return_to_editor()
