class_name SceneManager
extends RefCounted

## Multi-scene management for the editor.
## Each "game scene" is a separate snapshot (objects, tiles, events).
## Stored in user://scenes/ directory.

const SCENES_DIR := "user://scenes/"
const SCENE_EXT := ".litescene"
const INDEX_PATH := "user://scene_index.json"

static func ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SCENES_DIR):
		DirAccess.make_dir_recursive_absolute(SCENES_DIR)

static func create_scene_entry(scene_id: String, title: String, description: String = "") -> Dictionary:
	return {
		"id": scene_id,
		"title": title,
		"description": description,
		"created_at": Time.get_datetime_string_from_system(),
		"updated_at": Time.get_datetime_string_from_system(),
	}

## Load the scene index (list of all scenes).
static func load_index() -> Array[Dictionary]:
	if not FileAccess.file_exists(INDEX_PATH):
		return _create_default_index()
	var file := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if not file:
		return _create_default_index()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		return _create_default_index()
	var result: Array[Dictionary] = []
	for item in parsed:
		if item is Dictionary:
			result.append(item)
	if result.is_empty():
		return _create_default_index()
	return result

static func save_index(scenes: Array[Dictionary]) -> void:
	var file := FileAccess.open(INDEX_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(scenes, "  "))

static func _create_default_index() -> Array[Dictionary]:
	var default_scene := create_scene_entry("main", "主场景", "默认游戏场景")
	var result: Array[Dictionary] = [default_scene]
	save_index(result)
	return result

## Save a scene's data (objects, tiles, events) to its own file.
static func save_scene_data(scene_id: String, data: Dictionary) -> bool:
	ensure_dir()
	var path := SCENES_DIR + scene_id + SCENE_EXT
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data, "  "))
	_update_timestamp(scene_id)
	return true

## Load a scene's data.
static func load_scene_data(scene_id: String) -> Dictionary:
	var path := SCENES_DIR + scene_id + SCENE_EXT
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

## Add a new scene to the index.
static func add_scene(title: String, description: String = "") -> Dictionary:
	var scenes := load_index()
	var scene_id := "scene_%d" % Time.get_ticks_msec()
	var entry := create_scene_entry(scene_id, title, description)
	scenes.append(entry)
	save_index(scenes)
	save_scene_data(scene_id, _empty_scene_data())
	return entry

## Remove a scene from the index and delete its data file.
static func remove_scene(scene_id: String) -> bool:
	if scene_id == "main":
		return false
	var scenes := load_index()
	var new_list: Array[Dictionary] = []
	var found := false
	for s in scenes:
		if String(s.get("id", "")) == scene_id:
			found = true
		else:
			new_list.append(s)
	if not found:
		return false
	save_index(new_list)
	var path := SCENES_DIR + scene_id + SCENE_EXT
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return true

## Rename a scene.
static func rename_scene(scene_id: String, new_title: String) -> bool:
	var scenes := load_index()
	for s in scenes:
		if String(s.get("id", "")) == scene_id:
			s["title"] = new_title
			save_index(scenes)
			return true
	return false

## Duplicate a scene.
static func duplicate_scene(scene_id: String, new_title: String) -> Dictionary:
	var data := load_scene_data(scene_id)
	var entry := add_scene(new_title)
	if not data.is_empty():
		save_scene_data(String(entry.get("id", "")), data)
	return entry

static func get_scene_entry(scene_id: String) -> Dictionary:
	for s in load_index():
		if String(s.get("id", "")) == scene_id:
			return s
	return {}

static func _update_timestamp(scene_id: String) -> void:
	var scenes := load_index()
	for s in scenes:
		if String(s.get("id", "")) == scene_id:
			s["updated_at"] = Time.get_datetime_string_from_system()
	save_index(scenes)

static func _empty_scene_data() -> Dictionary:
	return {
		"resources": [],
		"scene_objects": [],
		"next_object_id": 1,
		"tile_cells": [],
		"events": [],
	}

## List all scene IDs and titles (for scene-switch dropdowns).
static func list_scene_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for s in load_index():
		result.append({
			"id": String(s.get("id", "")),
			"title": String(s.get("title", "")),
		})
	return result
