extends CanvasLayer

const DS = preload("res://scripts/dialogue_system.gd")

signal dialogue_finished()
signal flag_set_requested(flag_name: String, value: bool)

var _dialogue: Dictionary = {}
var _current_node_id := ""
var _flags_ref: Dictionary = {}
var _active := false

@onready var panel: PanelContainer = $DialoguePanel
@onready var speaker_label: Label = $DialoguePanel/Margin/VBox/SpeakerLabel
@onready var text_label: RichTextLabel = $DialoguePanel/Margin/VBox/TextLabel
@onready var choices_container: VBoxContainer = $DialoguePanel/Margin/VBox/ChoicesContainer
@onready var continue_hint: Label = $DialoguePanel/Margin/VBox/ContinueHint

func _ready() -> void:
	panel.visible = false
	_active = false

func start_dialogue(dialogue: Dictionary, flags: Dictionary = {}) -> void:
	_dialogue = dialogue
	_flags_ref = flags
	_current_node_id = String(dialogue.get("start_node", "node_0"))
	_active = true
	panel.visible = true
	_show_current_node()

func _show_current_node() -> void:
	var nodes: Dictionary = _dialogue.get("nodes", {})
	if not nodes.has(_current_node_id):
		_end_dialogue()
		return

	var node: Dictionary = nodes[_current_node_id]
	var node_type := int(node.get("type", DS.NodeType.END))

	for child in choices_container.get_children():
		child.queue_free()
	continue_hint.visible = false

	match node_type:
		DS.NodeType.TEXT:
			speaker_label.text = String(node.get("speaker", ""))
			text_label.text = String(node.get("text", ""))
			continue_hint.visible = true
			continue_hint.text = "按 E 继续..."

		DS.NodeType.CHOICE:
			speaker_label.text = ""
			text_label.text = String(node.get("prompt", "选择："))
			var choices: Array = node.get("choices", [])
			for i in choices.size():
				var option: Dictionary = choices[i] if choices[i] is Dictionary else {}
				var btn := Button.new()
				btn.text = "%d. %s" % [i + 1, option.get("label", "???")]
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				var next_id := String(option.get("next", ""))
				btn.pressed.connect(func():
					if next_id.is_empty():
						_end_dialogue()
					else:
						_current_node_id = next_id
						_show_current_node()
				)
				choices_container.add_child(btn)

		DS.NodeType.SET_FLAG:
			var flag_name := String(node.get("flag", ""))
			var flag_value := bool(node.get("value", true))
			_flags_ref[flag_name] = flag_value
			flag_set_requested.emit(flag_name, flag_value)
			var next_id := String(node.get("next", ""))
			if next_id.is_empty():
				_end_dialogue()
			else:
				_current_node_id = next_id
				_show_current_node()

		DS.NodeType.CONDITION:
			var flag_name := String(node.get("flag", ""))
			var flag_val := bool(_flags_ref.get(flag_name, false))
			if flag_val:
				_current_node_id = String(node.get("true_next", ""))
			else:
				_current_node_id = String(node.get("false_next", ""))
			if _current_node_id.is_empty():
				_end_dialogue()
			else:
				_show_current_node()

		DS.NodeType.END, _:
			_end_dialogue()

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_ENTER:
			_advance()
			get_viewport().set_input_as_handled()

func _advance() -> void:
	var nodes: Dictionary = _dialogue.get("nodes", {})
	if not nodes.has(_current_node_id):
		_end_dialogue()
		return
	var node: Dictionary = nodes[_current_node_id]
	var node_type := int(node.get("type", DS.NodeType.END))

	if node_type == DS.NodeType.TEXT:
		var next_id := String(node.get("next", ""))
		if next_id.is_empty():
			_end_dialogue()
		else:
			_current_node_id = next_id
			_show_current_node()

func _end_dialogue() -> void:
	_active = false
	panel.visible = false
	_dialogue = {}
	_current_node_id = ""
	dialogue_finished.emit()

func is_active() -> bool:
	return _active
