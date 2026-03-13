class_name ProjectStore
extends RefCounted

const SNAPSHOT_PATH := "user://editor_state.json"

static func default_object(object_type: String, object_index: int, resource_path: String = "") -> Dictionary:
	var behaviors: Dictionary = {}
	if object_type == "player":
		behaviors["movement"] = {
			"enabled": true,
			"mode": "topdown",
			"speed": 120.0,
			"camera_follow": true,
		}

	return {
		"id": "obj_%s" % object_index,
		"name": "%s %s" % [object_type.capitalize(), object_index],
		"type": object_type,
		"position": Vector2(96 + ((object_index - 1) % 5) * 96, 96 + int((object_index - 1) / 5) * 96),
		"size": Vector2(96, 96),
		"resource_path": resource_path,
		"solid": object_type in ["player", "npc", "door", "chest", "prop"],
		"interactable": object_type in ["npc", "door", "chest", "trigger"],
		"trigger_mode": "area" if object_type == "trigger" else "interact",
		"dialogue": "",
		"behaviors": behaviors,
	}

static func save_snapshot(resources: Array[Dictionary], scene_objects: Array[Dictionary], next_object_id: int, tile_cells: Array[Dictionary] = []) -> void:
	var payload := {
		"resources": _serialize_resources(resources),
		"scene_objects": _serialize_scene_objects(scene_objects),
		"next_object_id": next_object_id,
		"tile_cells": _serialize_tile_cells(tile_cells),
	}
	var file := FileAccess.open(SNAPSHOT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload, "  "))

static func load_snapshot() -> Dictionary:
	if not FileAccess.file_exists(SNAPSHOT_PATH):
		return {
			"resources": [],
			"scene_objects": [],
			"next_object_id": 1,
			"tile_cells": [],
		}

	var file := FileAccess.open(SNAPSHOT_PATH, FileAccess.READ)
	if not file:
		return {
			"resources": [],
			"scene_objects": [],
			"next_object_id": 1,
			"tile_cells": [],
		}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {
			"resources": [],
			"scene_objects": [],
			"next_object_id": 1,
			"tile_cells": [],
		}

	return {
		"resources": _deserialize_resources(parsed.get("resources", [])),
		"scene_objects": _deserialize_scene_objects(parsed.get("scene_objects", [])),
		"next_object_id": int(parsed.get("next_object_id", 1)),
		"tile_cells": _deserialize_tile_cells(parsed.get("tile_cells", [])),
	}

static func _serialize_resources(resources: Array[Dictionary]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for resource_data in resources:
		serialized.append(resource_data.duplicate(true))
	return serialized

static func _deserialize_resources(resources: Array) -> Array[Dictionary]:
	var deserialized: Array[Dictionary] = []
	for resource_data in resources:
		deserialized.append(resource_data)
	return deserialized

static func _serialize_scene_objects(scene_objects: Array[Dictionary]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for object_data in scene_objects:
		var entry: Dictionary = object_data.duplicate(true)
		entry["position"] = _vector_to_dict(entry.get("position", Vector2.ZERO))
		entry["size"] = _vector_to_dict(entry.get("size", Vector2(96, 96)))
		serialized.append(entry)
	return serialized

static func _deserialize_scene_objects(scene_objects: Array) -> Array[Dictionary]:
	var deserialized: Array[Dictionary] = []
	for object_data in scene_objects:
		var entry: Dictionary = object_data.duplicate(true)
		entry["position"] = _dict_to_vector(entry.get("position", {"x": 0, "y": 0}))
		entry["size"] = _dict_to_vector(entry.get("size", {"x": 96, "y": 96}))
		if not entry.has("behaviors") or typeof(entry["behaviors"]) != TYPE_DICTIONARY:
			entry["behaviors"] = {}
		if String(entry.get("type", "")) == "player" and not entry["behaviors"].has("movement"):
			entry["behaviors"]["movement"] = {
				"enabled": true,
				"mode": "topdown",
				"speed": 120.0,
				"camera_follow": true,
			}
		deserialized.append(entry)
	return deserialized

static func _vector_to_dict(value: Variant) -> Dictionary:
	var vector := Vector2.ZERO
	if value is Vector2:
		vector = value
	return {"x": vector.x, "y": vector.y}

static func _dict_to_vector(value: Variant) -> Vector2:
	if typeof(value) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(value.get("x", 0)), float(value.get("y", 0)))

static func _serialize_tile_cells(tile_cells: Array[Dictionary]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for tile_data in tile_cells:
		serialized.append(tile_data.duplicate(true))
	return serialized

static func _deserialize_tile_cells(tile_cells: Array) -> Array[Dictionary]:
	var deserialized: Array[Dictionary] = []
	for tile_data in tile_cells:
		var entry: Dictionary = tile_data.duplicate(true)
		entry["x"] = int(entry.get("x", 0))
		entry["y"] = int(entry.get("y", 0))
		entry["terrain"] = String(entry.get("terrain", "ground"))
		deserialized.append(entry)
	return deserialized
