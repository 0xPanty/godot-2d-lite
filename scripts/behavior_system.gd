class_name BehaviorSystem
extends RefCounted

## Available behavior presets that users can attach to objects.
## Each behavior auto-configures physics, movement, AI etc.

enum BehaviorType {
	TOPDOWN_PLAYER,     # 俯视角玩家移动 (WASD/方向键)
	PLATFORM_PLAYER,    # 横版平台跳跃玩家
	PATROL_NPC,         # NPC 来回巡逻
	CHASE_NPC,          # NPC 追逐玩家
	FLEE_NPC,           # NPC 远离玩家
	STATIC_OBJECT,      # 静止碰撞体
	FLOATING,           # 悬浮上下运动
	PROJECTILE,         # 投射物（直线飞行+碰撞销毁）
	FOLLOW_PLAYER,      # 跟随玩家
	WANDER,             # 随机游走
}

static var BEHAVIOR_CATALOG: Array[Dictionary] = [
	{
		"type": BehaviorType.TOPDOWN_PLAYER,
		"name": "俯视角玩家",
		"description": "WASD/方向键移动，带碰撞，可选镜头跟随",
		"category": "player",
		"color": Color(0.37, 0.65, 0.98),
		"defaults": {"speed": 120.0, "camera_follow": true},
	},
	{
		"type": BehaviorType.PLATFORM_PLAYER,
		"name": "平台跳跃玩家",
		"description": "左右移动 + 空格跳跃，受重力影响",
		"category": "player",
		"color": Color(0.37, 0.65, 0.98),
		"defaults": {"speed": 200.0, "jump_force": 400.0, "gravity": 980.0, "camera_follow": true},
	},
	{
		"type": BehaviorType.PATROL_NPC,
		"name": "巡逻NPC",
		"description": "在两个点之间来回移动",
		"category": "npc",
		"color": Color(0.20, 0.83, 0.60),
		"defaults": {"speed": 60.0, "patrol_distance": 200.0, "pause_time": 1.0},
	},
	{
		"type": BehaviorType.CHASE_NPC,
		"name": "追逐NPC",
		"description": "检测到玩家后追逐，超出范围返回",
		"category": "npc",
		"color": Color(0.97, 0.62, 0.04),
		"defaults": {"speed": 80.0, "detect_range": 200.0, "give_up_range": 400.0},
	},
	{
		"type": BehaviorType.FLEE_NPC,
		"name": "逃跑NPC",
		"description": "检测到玩家后逃跑",
		"category": "npc",
		"color": Color(0.98, 0.40, 0.40),
		"defaults": {"speed": 100.0, "detect_range": 150.0, "safe_range": 350.0},
	},
	{
		"type": BehaviorType.STATIC_OBJECT,
		"name": "静止障碍物",
		"description": "不动，有碰撞体",
		"category": "object",
		"color": Color(0.58, 0.64, 0.72),
		"defaults": {},
	},
	{
		"type": BehaviorType.FLOATING,
		"name": "悬浮物体",
		"description": "上下浮动（装饰或收集物）",
		"category": "object",
		"color": Color(0.65, 0.55, 0.98),
		"defaults": {"amplitude": 16.0, "frequency": 2.0},
	},
	{
		"type": BehaviorType.PROJECTILE,
		"name": "投射物",
		"description": "直线飞行，碰到东西就销毁",
		"category": "object",
		"color": Color(0.98, 0.85, 0.20),
		"defaults": {"speed": 300.0, "lifetime": 3.0},
	},
	{
		"type": BehaviorType.FOLLOW_PLAYER,
		"name": "跟随玩家",
		"description": "始终跟随玩家但保持距离",
		"category": "npc",
		"color": Color(0.37, 0.82, 0.82),
		"defaults": {"speed": 100.0, "follow_distance": 80.0},
	},
	{
		"type": BehaviorType.WANDER,
		"name": "随机游走",
		"description": "在范围内随机移动",
		"category": "npc",
		"color": Color(0.56, 0.78, 0.40),
		"defaults": {"speed": 40.0, "wander_radius": 150.0, "pause_min": 1.0, "pause_max": 3.0},
	},
]

static func get_catalog() -> Array[Dictionary]:
	return BEHAVIOR_CATALOG

static func get_by_type(type: BehaviorType) -> Dictionary:
	for entry in BEHAVIOR_CATALOG:
		if int(entry.get("type", -1)) == type:
			return entry
	return {}

static func create_behavior_data(type: BehaviorType, overrides: Dictionary = {}) -> Dictionary:
	var catalog_entry := get_by_type(type)
	var defaults: Dictionary = catalog_entry.get("defaults", {}).duplicate(true)
	for key in overrides:
		defaults[key] = overrides[key]
	return {
		"behavior_type": type,
		"enabled": true,
		"params": defaults,
	}

static func behavior_label(type: int) -> String:
	var entry := get_by_type(type as BehaviorType)
	return String(entry.get("name", "未知行为"))

static func behavior_description(type: int) -> String:
	var entry := get_by_type(type as BehaviorType)
	return String(entry.get("description", ""))
