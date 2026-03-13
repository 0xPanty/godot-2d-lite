extends Node2D

const ProjectStoreScript = preload("res://scripts/project_store.gd")
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

@onready var world: Node2D = $World
@onready var title_label: Label = $UI/Panel/Margin/VBox/TitleLabel
@onready var hint_label: Label = $UI/Panel/Margin/VBox/HintLabel
@onready var message_label: RichTextLabel = $UI/Panel/Margin/VBox/MessageLabel

func _ready() -> void:
	var snapshot: Dictionary = ProjectStoreScript.load_snapshot()
	scene_objects = snapshot.get("scene_objects", [])
	tile_cells = snapshot.get("tile_cells", [])
	_build_world()
	_update_header()
	_show_message("运行预览已启动。方向键移动，E 键交互，右上角可返回编辑器。")

func _physics_process(_delta: float) -> void:
	_update_player_movement()
	_update_interaction_hint()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and not active_interactable_id.is_empty():
			_activate_object(active_interactable_id)
		elif event.keycode == KEY_ESCAPE:
			_return_to_editor()

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
		hint_label.text = "方向键移动，E 交互，Esc 返回编辑器"
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
		_show_message("获得奖励：%s x%s" % [reward.get("item_id", "sample_item"), reward.get("amount", 1)])
		var visual: CanvasItem = entry.get("visual")
		if visual:
			visual.modulate = Color(0.7, 0.7, 0.7)
		return

	if bool(event_behavior.get("enabled", false)):
		consumed_object_ids[object_id] = true
		_show_message("触发事件：%s" % event_behavior.get("event_id", "sample_event"))
		return

	var dialogue := String(object_data.get("dialogue", "")).strip_edges()
	if not dialogue.is_empty():
		_show_message("%s：%s" % [object_data.get("name", "对象"), dialogue])
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

func _return_to_editor() -> void:
	get_tree().change_scene_to_file("res://scenes/editor_main.tscn")

func _on_back_button_pressed() -> void:
	_return_to_editor()
