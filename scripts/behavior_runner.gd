class_name BehaviorRunner
extends RefCounted

const BS = preload("res://scripts/behavior_system.gd")

var _active_behaviors: Array[Dictionary] = []

func register(node: Node2D, behavior_data: Dictionary, player_ref: Node2D = null) -> void:
	_active_behaviors.append({
		"node": node,
		"data": behavior_data,
		"player": player_ref,
		"state": _init_state(int(behavior_data.get("behavior_type", -1))),
	})

func process_all(delta: float) -> void:
	for entry in _active_behaviors:
		if entry["node"] == null or not is_instance_valid(entry["node"]):
			continue
		_tick(entry, delta)

func _init_state(btype: int) -> Dictionary:
	match btype:
		BS.BehaviorType.PATROL_NPC:
			return {"direction": 1.0, "origin": Vector2.ZERO, "pausing": false, "pause_timer": 0.0, "origin_set": false}
		BS.BehaviorType.CHASE_NPC:
			return {"chasing": false, "origin": Vector2.ZERO, "origin_set": false}
		BS.BehaviorType.FLEE_NPC:
			return {"fleeing": false}
		BS.BehaviorType.FLOATING:
			return {"time": 0.0, "origin_y": 0.0, "origin_set": false}
		BS.BehaviorType.PROJECTILE:
			return {"lifetime": 0.0}
		BS.BehaviorType.WANDER:
			return {"target": Vector2.ZERO, "pausing": true, "pause_timer": 0.0, "origin": Vector2.ZERO, "origin_set": false}
		_:
			return {}

func _tick(entry: Dictionary, delta: float) -> void:
	var node: Node2D = entry["node"]
	var data: Dictionary = entry["data"]
	var params: Dictionary = data.get("params", {})
	var state: Dictionary = entry["state"]
	var player: Node2D = entry["player"]
	var btype: int = int(data.get("behavior_type", -1))

	if not bool(data.get("enabled", true)):
		return

	match btype:
		BS.BehaviorType.TOPDOWN_PLAYER:
			_tick_topdown_player(node, params, delta)
		BS.BehaviorType.PLATFORM_PLAYER:
			_tick_platform_player(node, params, delta)
		BS.BehaviorType.PATROL_NPC:
			_tick_patrol(node, params, state, delta)
		BS.BehaviorType.CHASE_NPC:
			_tick_chase(node, params, state, player, delta)
		BS.BehaviorType.FLEE_NPC:
			_tick_flee(node, params, state, player, delta)
		BS.BehaviorType.FLOATING:
			_tick_floating(node, params, state, delta)
		BS.BehaviorType.PROJECTILE:
			_tick_projectile(node, params, state, delta)
		BS.BehaviorType.FOLLOW_PLAYER:
			_tick_follow(node, params, player, delta)
		BS.BehaviorType.WANDER:
			_tick_wander(node, params, state, delta)

func _tick_topdown_player(node: Node2D, params: Dictionary, delta: float) -> void:
	var speed := float(params.get("speed", 120.0))
	var input_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if node is CharacterBody2D:
		node.velocity = input_vec * speed
		node.move_and_slide()
	else:
		node.position += input_vec * speed * delta

func _tick_platform_player(node: Node2D, params: Dictionary, delta: float) -> void:
	var speed := float(params.get("speed", 200.0))
	var jump_force := float(params.get("jump_force", 400.0))
	var gravity := float(params.get("gravity", 980.0))
	if node is CharacterBody2D:
		node.velocity.y += gravity * delta
		var h_input := Input.get_axis("ui_left", "ui_right")
		node.velocity.x = h_input * speed
		if node.is_on_floor() and Input.is_action_just_pressed("ui_accept"):
			node.velocity.y = -jump_force
		node.move_and_slide()

func _tick_patrol(node: Node2D, params: Dictionary, state: Dictionary, delta: float) -> void:
	if not state.get("origin_set", false):
		state["origin"] = node.position
		state["origin_set"] = true

	if state.get("pausing", false):
		state["pause_timer"] = float(state.get("pause_timer", 0)) - delta
		if float(state["pause_timer"]) <= 0:
			state["pausing"] = false
			state["direction"] = float(state.get("direction", 1.0)) * -1.0
		return

	var speed := float(params.get("speed", 60.0))
	var patrol_dist := float(params.get("patrol_distance", 200.0))
	var direction := float(state.get("direction", 1.0))
	node.position.x += direction * speed * delta

	var origin: Vector2 = state.get("origin", Vector2.ZERO)
	if abs(node.position.x - origin.x) >= patrol_dist / 2.0:
		state["pausing"] = true
		state["pause_timer"] = float(params.get("pause_time", 1.0))

func _tick_chase(node: Node2D, params: Dictionary, state: Dictionary, player: Node2D, delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not state.get("origin_set", false):
		state["origin"] = node.position
		state["origin_set"] = true

	var detect := float(params.get("detect_range", 200.0))
	var give_up := float(params.get("give_up_range", 400.0))
	var speed := float(params.get("speed", 80.0))
	var dist := node.global_position.distance_to(player.global_position)

	if not state.get("chasing", false):
		if dist <= detect:
			state["chasing"] = true
	else:
		if dist > give_up:
			state["chasing"] = false

	if state.get("chasing", false):
		var dir := (player.global_position - node.global_position).normalized()
		node.position += dir * speed * delta
	else:
		var origin: Vector2 = state.get("origin", node.position)
		if node.position.distance_to(origin) > 4.0:
			var dir := (origin - node.position).normalized()
			node.position += dir * speed * 0.5 * delta

func _tick_flee(node: Node2D, params: Dictionary, state: Dictionary, player: Node2D, delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var detect := float(params.get("detect_range", 150.0))
	var safe := float(params.get("safe_range", 350.0))
	var speed := float(params.get("speed", 100.0))
	var dist := node.global_position.distance_to(player.global_position)

	if not state.get("fleeing", false):
		if dist <= detect:
			state["fleeing"] = true
	else:
		if dist >= safe:
			state["fleeing"] = false

	if state.get("fleeing", false):
		var dir := (node.global_position - player.global_position).normalized()
		node.position += dir * speed * delta

func _tick_floating(node: Node2D, params: Dictionary, state: Dictionary, delta: float) -> void:
	if not state.get("origin_set", false):
		state["origin_y"] = node.position.y
		state["origin_set"] = true
	state["time"] = float(state.get("time", 0.0)) + delta
	var amp := float(params.get("amplitude", 16.0))
	var freq := float(params.get("frequency", 2.0))
	node.position.y = float(state["origin_y"]) + sin(float(state["time"]) * freq) * amp

func _tick_projectile(node: Node2D, params: Dictionary, state: Dictionary, delta: float) -> void:
	var speed := float(params.get("speed", 300.0))
	var lifetime := float(params.get("lifetime", 3.0))
	state["lifetime"] = float(state.get("lifetime", 0.0)) + delta
	# Move in the direction the node is facing (right by default)
	node.position += Vector2.RIGHT.rotated(node.rotation) * speed * delta
	if float(state["lifetime"]) >= lifetime:
		node.queue_free()

func _tick_follow(node: Node2D, params: Dictionary, player: Node2D, delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var speed := float(params.get("speed", 100.0))
	var follow_dist := float(params.get("follow_distance", 80.0))
	var dist := node.global_position.distance_to(player.global_position)
	if dist > follow_dist:
		var dir := (player.global_position - node.global_position).normalized()
		node.position += dir * speed * delta

func _tick_wander(node: Node2D, params: Dictionary, state: Dictionary, delta: float) -> void:
	if not state.get("origin_set", false):
		state["origin"] = node.position
		state["target"] = node.position
		state["origin_set"] = true

	if state.get("pausing", false):
		state["pause_timer"] = float(state.get("pause_timer", 0)) - delta
		if float(state["pause_timer"]) <= 0:
			state["pausing"] = false
			var radius := float(params.get("wander_radius", 150.0))
			var origin: Vector2 = state.get("origin", Vector2.ZERO)
			var angle := randf() * TAU
			var dist := randf() * radius
			state["target"] = origin + Vector2(cos(angle), sin(angle)) * dist
		return

	var target: Vector2 = state.get("target", node.position)
	var speed := float(params.get("speed", 40.0))
	if node.position.distance_to(target) < 4.0:
		state["pausing"] = true
		var pause_min := float(params.get("pause_min", 1.0))
		var pause_max := float(params.get("pause_max", 3.0))
		state["pause_timer"] = randf_range(pause_min, pause_max)
	else:
		var dir := (target - node.position).normalized()
		node.position += dir * speed * delta
