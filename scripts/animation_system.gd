class_name AnimationSystem
extends RefCounted

## Sprite frame animation data model.
## Each object can have multiple named animations (idle, walk_left, walk_right, attack, etc.).
## Each animation is a list of frame references + fps + loop flag.

static var PRESET_ANIMATIONS: Array[Dictionary] = [
	{
		"id": "idle",
		"name": "待机",
		"description": "静止时播放",
		"default_fps": 4,
		"loop": true,
		"color": Color(0.37, 0.65, 0.98),
	},
	{
		"id": "walk_down",
		"name": "向下走",
		"description": "朝下移动时播放",
		"default_fps": 8,
		"loop": true,
		"color": Color(0.20, 0.83, 0.60),
	},
	{
		"id": "walk_up",
		"name": "向上走",
		"description": "朝上移动时播放",
		"default_fps": 8,
		"loop": true,
		"color": Color(0.20, 0.83, 0.60),
	},
	{
		"id": "walk_left",
		"name": "向左走",
		"description": "朝左移动时播放",
		"default_fps": 8,
		"loop": true,
		"color": Color(0.20, 0.83, 0.60),
	},
	{
		"id": "walk_right",
		"name": "向右走",
		"description": "朝右移动时播放",
		"default_fps": 8,
		"loop": true,
		"color": Color(0.20, 0.83, 0.60),
	},
	{
		"id": "attack",
		"name": "攻击",
		"description": "攻击时播放",
		"default_fps": 12,
		"loop": false,
		"color": Color(0.98, 0.40, 0.40),
	},
	{
		"id": "hurt",
		"name": "受伤",
		"description": "受到伤害时播放",
		"default_fps": 8,
		"loop": false,
		"color": Color(0.98, 0.62, 0.04),
	},
	{
		"id": "death",
		"name": "死亡",
		"description": "死亡时播放",
		"default_fps": 6,
		"loop": false,
		"color": Color(0.58, 0.64, 0.72),
	},
]

static func get_presets() -> Array[Dictionary]:
	return PRESET_ANIMATIONS

static func get_preset(anim_id: String) -> Dictionary:
	for entry in PRESET_ANIMATIONS:
		if String(entry.get("id", "")) == anim_id:
			return entry
	return {}

## Create an animation data entry for an object.
## frames: Array of resource paths (images), played in sequence.
static func create_animation(anim_id: String, frames: Array = [], fps: int = -1, loop: bool = true) -> Dictionary:
	var preset := get_preset(anim_id)
	if fps < 0:
		fps = int(preset.get("default_fps", 8))
	return {
		"id": anim_id,
		"frames": frames.duplicate(),
		"fps": fps,
		"loop": loop,
	}

## Create an animation set (all animations for one object).
static func create_animation_set() -> Dictionary:
	return {"animations": {}, "current": "idle"}

static func add_animation(anim_set: Dictionary, anim: Dictionary) -> void:
	anim_set["animations"][String(anim.get("id", ""))] = anim.duplicate(true)

static func remove_animation(anim_set: Dictionary, anim_id: String) -> void:
	anim_set["animations"].erase(anim_id)

static func get_animation(anim_set: Dictionary, anim_id: String) -> Dictionary:
	return anim_set.get("animations", {}).get(anim_id, {})

static func has_animation(anim_set: Dictionary, anim_id: String) -> bool:
	return anim_set.get("animations", {}).has(anim_id)

static func add_frame(anim_set: Dictionary, anim_id: String, frame_path: String) -> void:
	var anim: Dictionary = get_animation(anim_set, anim_id)
	if anim.is_empty():
		return
	var frames: Array = anim.get("frames", [])
	frames.append(frame_path)
	anim["frames"] = frames

static func remove_frame(anim_set: Dictionary, anim_id: String, frame_index: int) -> void:
	var anim: Dictionary = get_animation(anim_set, anim_id)
	if anim.is_empty():
		return
	var frames: Array = anim.get("frames", [])
	if frame_index >= 0 and frame_index < frames.size():
		frames.remove_at(frame_index)

static func set_fps(anim_set: Dictionary, anim_id: String, fps: int) -> void:
	var anim: Dictionary = get_animation(anim_set, anim_id)
	if not anim.is_empty():
		anim["fps"] = fps

## Create spritesheet frame references from a single image.
## Splits the image into grid cells and returns frame paths with region metadata.
static func create_spritesheet_frames(image_path: String, columns: int, rows: int, start_frame: int = 0, frame_count: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var total := columns * rows
	if frame_count < 0:
		frame_count = total - start_frame
	for i in range(start_frame, mini(start_frame + frame_count, total)):
		var col := i % columns
		var row := i / columns
		result.append({
			"path": image_path,
			"region": true,
			"col": col,
			"row": row,
			"columns": columns,
			"rows": rows,
		})
	return result

# --- Serialization ---

static func serialize_animation_set(anim_set: Dictionary) -> Dictionary:
	return anim_set.duplicate(true)

static func deserialize_animation_set(data: Variant) -> Dictionary:
	if data is Dictionary:
		var s := data.duplicate(true)
		if not s.has("animations"):
			s["animations"] = {}
		if not s.has("current"):
			s["current"] = "idle"
		return s
	return create_animation_set()

# --- Labels ---

static func animation_label(anim_id: String) -> String:
	var preset := get_preset(anim_id)
	if not preset.is_empty():
		return String(preset.get("name", anim_id))
	return anim_id
