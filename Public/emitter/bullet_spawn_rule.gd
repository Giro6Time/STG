class_name BulletSpawnRule
extends Resource

## 发射规则：决定每颗子弹的方向预设，并执行生成。

enum DirectionMode {
	CURVE_TANGENT,
	FROM_ORIGIN,
	AIM_PLAYER,
	FIXED,
	RANDOM_JITTER,
}

@export var bullet_speed: float = 120.0
@export var acceleration: float = 0.0
@export var damage: int = 1
@export var bullet_lifetime: float = 0.0
@export var direction_mode: DirectionMode = DirectionMode.CURVE_TANGENT
@export var fixed_direction: Vector2 = Vector2.DOWN
@export var jitter_degrees: float = 0.0
@export var fallback_direction: Vector2 = Vector2.DOWN

## 运动策略（发射源注入；null 时默认直线）。
var motion: BulletMotion = null

const PLAYER_GROUP: String = "players"


func spawn_from_curve(
	bullet_layer: BulletLayer,
	bullet_scene: PackedScene,
	origin: Vector2,
	local_point: Vector2,
	tangent: Vector2,
	base_init_data: Dictionary = {}
) -> BulletBase:
	var direction: Vector2 = _compute_direction(origin, local_point, tangent)
	return spawn_bullet(bullet_layer, bullet_scene, origin + local_point, direction, base_init_data)


func _compute_direction(origin: Vector2, local_point: Vector2, tangent: Vector2) -> Vector2:
	var direction: Vector2 = fallback_direction
	match direction_mode:
		DirectionMode.CURVE_TANGENT:
			direction = tangent
		DirectionMode.FROM_ORIGIN:
			direction = local_point
		DirectionMode.AIM_PLAYER:
			direction = _get_player_direction(origin)
		DirectionMode.FIXED:
			direction = fixed_direction
		DirectionMode.RANDOM_JITTER:
			direction = tangent.rotated(deg_to_rad(randf_range(-jitter_degrees, jitter_degrees)))
	if jitter_degrees > 0.0 and direction_mode != DirectionMode.RANDOM_JITTER:
		direction = direction.rotated(deg_to_rad(randf_range(-jitter_degrees, jitter_degrees)))
	if direction.length() <= 0.001:
		direction = fallback_direction
	return direction


func _get_player_direction(origin: Vector2) -> Vector2:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return fallback_direction
	var player := tree.get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player == null:
		return fallback_direction
	var delta: Vector2 = player.global_position - origin
	if delta.length() <= 0.001:
		return fallback_direction
	return delta.normalized()


func spawn_bullet(
	bullet_layer: BulletLayer,
	bullet_scene: PackedScene,
	spawn_position: Vector2,
	direction: Vector2,
	base_init_data: Dictionary = {}
) -> BulletBase:
	if bullet_layer == null or bullet_scene == null:
		return null
	var spawn_direction: Vector2 = direction
	if spawn_direction.length() <= 0.001:
		spawn_direction = fallback_direction

	var init_data: Dictionary = base_init_data.duplicate()
	init_data["velocity"] = spawn_direction.normalized()
	init_data["speed"] = bullet_speed
	init_data["acceleration"] = acceleration
	init_data["damage"] = damage
	init_data["lifetime"] = bullet_lifetime

	var active_motion: BulletMotion = motion
	if active_motion == null:
		var default_motion := LinearMotion.new()
		default_motion.speed = bullet_speed
		default_motion.acceleration = acceleration
		active_motion = default_motion
	init_data["motion"] = active_motion

	return bullet_layer.spawn_bullet(bullet_scene, spawn_position, init_data)
