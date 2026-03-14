class_name AnimationRunner
extends RefCounted

## Runtime animation player — drives SpriteFrames on registered nodes.
## Tracks per-object animation state and switches based on velocity / events.

const AnimSys = preload("res://scripts/animation_system.gd")

var _entries: Array[Dictionary] = []

func register(node: Node2D, anim_set: Dictionary) -> void:
	if anim_set.get("animations", {}).is_empty():
		return
	var sprite := _find_or_create_animated_sprite(node)
	if sprite == null:
		return
	var sf := SpriteFrames.new()
	_build_sprite_frames(sf, anim_set)
	sprite.sprite_frames = sf
	var start_anim := String(anim_set.get("current", "idle"))
	if sf.has_animation(start_anim):
		sprite.play(start_anim)
	elif sf.get_animation_names().size() > 0:
		sprite.play(sf.get_animation_names()[0])
	_entries.append({
		"node": node,
		"sprite": sprite,
		"anim_set": anim_set,
		"current_anim": start_anim,
		"prev_velocity": Vector2.ZERO,
	})

func process_all(_delta: float) -> void:
	for entry in _entries:
		var node: Node2D = entry["node"]
		if node == null or not is_instance_valid(node):
			continue
		_auto_switch(entry)

func play(node: Node2D, anim_id: String) -> void:
	for entry in _entries:
		if entry["node"] == node:
			_switch_animation(entry, anim_id)
			return

func _auto_switch(entry: Dictionary) -> void:
	var node: Node2D = entry["node"]
	var velocity := Vector2.ZERO
	if node is CharacterBody2D:
		velocity = node.velocity

	var anim_set: Dictionary = entry["anim_set"]
	var anims: Dictionary = anim_set.get("animations", {})
	var current := String(entry.get("current_anim", "idle"))

	if velocity.length_squared() < 4.0:
		if anims.has("idle") and current != "idle":
			_switch_animation(entry, "idle")
	else:
		var target_anim := ""
		if abs(velocity.x) >= abs(velocity.y):
			target_anim = "walk_right" if velocity.x > 0 else "walk_left"
		else:
			target_anim = "walk_down" if velocity.y > 0 else "walk_up"
		if not anims.has(target_anim):
			if anims.has("walk_down"):
				target_anim = "walk_down"
			elif anims.has("idle"):
				target_anim = "idle"
			else:
				target_anim = ""
		if not target_anim.is_empty() and target_anim != current:
			_switch_animation(entry, target_anim)

	entry["prev_velocity"] = velocity

func _switch_animation(entry: Dictionary, anim_id: String) -> void:
	var sprite: AnimatedSprite2D = entry["sprite"]
	if sprite == null or not is_instance_valid(sprite):
		return
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_id):
		sprite.play(anim_id)
		entry["current_anim"] = anim_id

func _find_or_create_animated_sprite(node: Node2D) -> AnimatedSprite2D:
	for child in node.get_children():
		if child is AnimatedSprite2D:
			return child
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimSprite"
	node.add_child(sprite)
	return sprite

func _build_sprite_frames(sf: SpriteFrames, anim_set: Dictionary) -> void:
	var anims: Dictionary = anim_set.get("animations", {})
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim_id in anims.keys():
		var anim: Dictionary = anims[anim_id]
		sf.add_animation(anim_id)
		sf.set_animation_speed(anim_id, float(anim.get("fps", 8)))
		sf.set_animation_loop(anim_id, bool(anim.get("loop", true)))
		var frames: Array = anim.get("frames", [])
		for fi in frames.size():
			var frame = frames[fi]
			var texture := _load_frame_texture(frame)
			if texture:
				sf.add_frame(anim_id, texture)

func _load_frame_texture(frame) -> Texture2D:
	var path := ""
	var is_region := false
	var col := 0
	var row := 0
	var columns := 1
	var rows := 1

	if frame is String:
		path = frame
	elif frame is Dictionary:
		path = String(frame.get("path", ""))
		is_region = bool(frame.get("region", false))
		col = int(frame.get("col", 0))
		row = int(frame.get("row", 0))
		columns = int(frame.get("columns", 1))
		rows = int(frame.get("rows", 1))

	if path.is_empty():
		return null

	var full_texture: Texture2D = null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		full_texture = load(path)
	elif FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			full_texture = ImageTexture.create_from_image(image)

	if full_texture == null:
		return null

	if not is_region:
		return full_texture

	var tex_size := full_texture.get_size()
	var frame_w := tex_size.x / float(columns)
	var frame_h := tex_size.y / float(rows)
	var atlas := AtlasTexture.new()
	atlas.atlas = full_texture
	atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
	return atlas
