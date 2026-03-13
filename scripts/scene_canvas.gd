extends Control

signal object_selected(object_id: String)
signal object_moved(object_id: String, position: Vector2)
signal tile_painted(cell: Vector2i, terrain: String)

const GRID_SIZE := 32.0
const TERRAIN_COLORS := {
	"ground": Color("334155"),
	"wall": Color("475569"),
	"water": Color("1d4ed8"),
}

var _scene_objects: Array[Dictionary] = []
var _tile_cells: Array[Dictionary] = []
var _buttons: Dictionary = {}
var _selected_object_id := ""
var _dragging_object_id := ""
var _drag_offset := Vector2.ZERO
var _tool_mode := "select"
var _selected_terrain := "ground"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	queue_redraw()

func set_scene_objects(scene_objects: Array[Dictionary], selected_object_id: String = "", tile_cells: Array[Dictionary] = [], tool_mode: String = "select", selected_terrain: String = "ground") -> void:
	_scene_objects = []
	for object_data in scene_objects:
		_scene_objects.append(object_data.duplicate(true))
	_tile_cells = []
	for tile_data in tile_cells:
		_tile_cells.append(tile_data.duplicate(true))
	_selected_object_id = selected_object_id
	_tool_mode = tool_mode
	_selected_terrain = selected_terrain
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_buttons.clear()

	for object_data in _scene_objects:
		var button := Button.new()
		button.text = String(object_data.get("name", "Object"))
		button.focus_mode = Control.FOCUS_NONE
		button.size = object_data.get("size", Vector2(96, 96))
		button.position = object_data.get("position", Vector2.ZERO)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.expand_icon = true

		var resource_path := String(object_data.get("resource_path", ""))
		var icon_texture := _load_icon(resource_path)
		if icon_texture:
			button.icon = icon_texture

		if String(object_data.get("id", "")) == _selected_object_id:
			button.modulate = Color(1.0, 0.93, 0.65)
		else:
			button.modulate = Color.WHITE

		button.gui_input.connect(_on_object_gui_input.bind(String(object_data.get("id", ""))))
		add_child(button)
		_buttons[String(object_data.get("id", ""))] = button

	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1f2937"), true)
	for tile_data in _tile_cells:
		var cell := Vector2(float(tile_data.get("x", 0)) * GRID_SIZE, float(tile_data.get("y", 0)) * GRID_SIZE)
		var terrain := String(tile_data.get("terrain", "ground"))
		var color: Color = TERRAIN_COLORS.get(terrain, Color("334155"))
		draw_rect(Rect2(cell, Vector2.ONE * GRID_SIZE), color, true)
	for x in range(0, int(size.x), int(GRID_SIZE)):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.08), 1.0)
	for y in range(0, int(size.y), int(GRID_SIZE)):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.08), 1.0)
	if _tool_mode == "paint":
		var hovered_cell := _snap_cell(get_local_mouse_position())
		var hover_rect := Rect2(Vector2(hovered_cell.x, hovered_cell.y) * GRID_SIZE, Vector2.ONE * GRID_SIZE)
		draw_rect(hover_rect, Color(1, 1, 1, 0.16), false, 2.0)

func _gui_input(event: InputEvent) -> void:
	if _tool_mode != "paint":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_paint_at(event.position)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_paint_at(event.position)
	queue_redraw()

func _on_object_gui_input(event: InputEvent, object_id: String) -> void:
	if _tool_mode != "select":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_selected_object_id = object_id
			_dragging_object_id = object_id
			_drag_offset = event.position
			emit_signal("object_selected", object_id)
			_rebuild()
		else:
			if _dragging_object_id == object_id:
				var button: Button = _buttons.get(object_id)
				if button:
					emit_signal("object_moved", object_id, button.position)
			_dragging_object_id = ""
	elif event is InputEventMouseMotion and _dragging_object_id == object_id:
		var button: Button = _buttons.get(object_id)
		if button:
			button.position = _snap_position(button.position + event.relative)

func _snap_position(raw_position: Vector2) -> Vector2:
	var clamped := raw_position.clamp(Vector2.ZERO, size - Vector2(96, 96))
	return Vector2(
		round(clamped.x / GRID_SIZE) * GRID_SIZE,
		round(clamped.y / GRID_SIZE) * GRID_SIZE
	)

func _load_icon(resource_path: String) -> Texture2D:
	if resource_path.is_empty():
		return null
	if resource_path.begins_with("res://") and ResourceLoader.exists(resource_path):
		return load(resource_path)
	if FileAccess.file_exists(resource_path):
		var image := Image.new()
		if image.load(resource_path) == OK:
			return ImageTexture.create_from_image(image)
	return null

func _paint_at(raw_position: Vector2) -> void:
	var cell := _snap_cell(raw_position)
	emit_signal("tile_painted", cell, _selected_terrain)

func _snap_cell(raw_position: Vector2) -> Vector2i:
	var clamped := raw_position.clamp(Vector2.ZERO, size - Vector2.ONE)
	return Vector2i(floori(clamped.x / GRID_SIZE), floori(clamped.y / GRID_SIZE))
