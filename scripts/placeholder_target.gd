extends Control

func _on_back_to_preview_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/runtime_preview.tscn")

func _on_back_to_editor_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/editor_main.tscn")
