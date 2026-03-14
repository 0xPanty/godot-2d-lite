extends CanvasLayer

## Runtime inventory UI — grid bag display, item tooltips, use button.
## Toggle with Tab key.

const InventorySystemScript = preload("res://scripts/inventory_system.gd")

signal item_used(item_id: String)

var _inventory: Dictionary = {}
var _visible := false

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var item_grid: GridContainer = $Panel/Margin/VBox/ScrollContainer/ItemGrid
@onready var detail_label: RichTextLabel = $Panel/Margin/VBox/DetailLabel
@onready var use_button: Button = $Panel/Margin/VBox/UseButton
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

var _selected_slot_index := -1

func _ready() -> void:
	panel.visible = false
	use_button.pressed.connect(_on_use_pressed)
	close_button.pressed.connect(hide_inventory)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			toggle()
			get_viewport().set_input_as_handled()

func toggle() -> void:
	if _visible:
		hide_inventory()
	else:
		show_inventory()

func show_inventory() -> void:
	_visible = true
	panel.visible = true
	_refresh_grid()

func hide_inventory() -> void:
	_visible = false
	panel.visible = false
	_selected_slot_index = -1

func is_open() -> bool:
	return _visible

func set_inventory(inv: Dictionary) -> void:
	_inventory = inv
	if _visible:
		_refresh_grid()

func _refresh_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()

	var items := InventorySystemScript.get_all_items(_inventory)
	title_label.text = "背包 (%d/%d)" % [items.size(), int(_inventory.get("capacity", 40))]

	for i in items.size():
		var item: Dictionary = items[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64, 64)
		btn.tooltip_text = "%s\n%s" % [item.get("name", "?"), item.get("description", "")]

		var amount: int = int(item.get("amount", 1))
		if amount > 1:
			btn.text = "%s\nx%d" % [String(item.get("name", "?")).substr(0, 4), amount]
		else:
			btn.text = String(item.get("name", "?")).substr(0, 4)

		var color: Color = item.get("icon_color", Color.WHITE)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(color, 0.3)
		style.border_color = color
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", style)

		var idx := i
		btn.pressed.connect(func(): _on_slot_selected(idx))
		item_grid.add_child(btn)

	_update_detail()

func _on_slot_selected(index: int) -> void:
	_selected_slot_index = index
	_update_detail()

func _update_detail() -> void:
	var items := InventorySystemScript.get_all_items(_inventory)
	if _selected_slot_index < 0 or _selected_slot_index >= items.size():
		detail_label.text = "选择一个物品查看详情"
		use_button.visible = false
		return

	var item: Dictionary = items[_selected_slot_index]
	var cat_name := InventorySystemScript.category_label(int(item.get("category", 0)))
	detail_label.text = "[b]%s[/b] x%d\n[i]%s[/i]\n分类：%s" % [
		item.get("name", "?"),
		int(item.get("amount", 1)),
		item.get("description", ""),
		cat_name,
	]
	use_button.visible = bool(item.get("usable", false))
	use_button.text = "使用 %s" % item.get("name", "?")

func _on_use_pressed() -> void:
	var items := InventorySystemScript.get_all_items(_inventory)
	if _selected_slot_index < 0 or _selected_slot_index >= items.size():
		return
	var item_id := String(items[_selected_slot_index].get("item_id", ""))
	item_used.emit(item_id)
	_selected_slot_index = -1
	_refresh_grid()
