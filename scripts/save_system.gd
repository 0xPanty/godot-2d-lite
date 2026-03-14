class_name SaveSystem
extends RefCounted

## Runtime game save/load system.
## Stores player position, inventory, quest journal, flags, consumed objects, etc.

const SAVE_DIR := "user://saves/"
const SAVE_EXT := ".litesave"
const MAX_SLOTS := 10

static func ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

static func save_game(slot: int, data: Dictionary) -> Dictionary:
	ensure_save_dir()
	if slot < 0 or slot >= MAX_SLOTS:
		return {"success": false, "reason": "invalid_slot"}

	var payload := data.duplicate(true)
	payload["save_version"] = 1
	payload["save_time"] = Time.get_datetime_string_from_system()
	payload["slot"] = slot

	if payload.has("player_position") and payload["player_position"] is Vector2:
		var pos: Vector2 = payload["player_position"]
		payload["player_position"] = {"x": pos.x, "y": pos.y}

	var path := _slot_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return {"success": false, "reason": "file_write_error"}

	file.store_string(JSON.stringify(payload, "  "))
	return {"success": true, "path": path}

static func load_game(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"success": false, "reason": "no_save"}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"success": false, "reason": "file_read_error"}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"success": false, "reason": "corrupt_data"}

	var data: Dictionary = parsed
	if data.has("player_position") and data["player_position"] is Dictionary:
		var pos_dict: Dictionary = data["player_position"]
		data["player_position"] = Vector2(float(pos_dict.get("x", 0)), float(pos_dict.get("y", 0)))

	data["success"] = true
	return data

static func delete_save(slot: int) -> bool:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return true
	return false

static func list_saves() -> Array[Dictionary]:
	ensure_save_dir()
	var result: Array[Dictionary] = []
	for slot in MAX_SLOTS:
		var path := _slot_path(slot)
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var parsed: Variant = JSON.parse_string(file.get_as_text())
				if parsed is Dictionary:
					result.append({
						"slot": slot,
						"save_time": String(parsed.get("save_time", "")),
						"exists": true,
					})
					continue
		result.append({"slot": slot, "save_time": "", "exists": false})
	return result

static func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))

## Capture runtime state into a saveable dictionary.
static func capture_runtime_state(
	player_pos: Vector2,
	inventory: Dictionary,
	quest_journal: Dictionary,
	flags: Dictionary,
	consumed_ids: Dictionary,
	custom_data: Dictionary = {}
) -> Dictionary:
	var state := {
		"player_position": player_pos,
		"inventory": inventory.duplicate(true),
		"quest_journal": quest_journal.duplicate(true),
		"flags": flags.duplicate(true),
		"consumed_object_ids": consumed_ids.duplicate(true),
	}
	for key in custom_data:
		state[key] = custom_data[key]
	return state

## Restore runtime state from loaded data.
static func extract_runtime_state(data: Dictionary) -> Dictionary:
	return {
		"player_position": data.get("player_position", Vector2.ZERO),
		"inventory": data.get("inventory", {"slots": [], "capacity": 40}),
		"quest_journal": data.get("quest_journal", {"quests": {}}),
		"flags": data.get("flags", {}),
		"consumed_object_ids": data.get("consumed_object_ids", {}),
	}

static func _slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d%s" % [slot, SAVE_EXT]
