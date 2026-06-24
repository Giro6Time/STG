class_name BulletSpawnRule
extends Resource

@export var bullet_speed: float = 120.0
@export var acceleration: float = 30.0
@export var damage: int = 1
@export var use_curve_point_as_direction: bool = true
@export var use_tangent_as_direction: bool = false
@export var fallback_direction: Vector2 = Vector2.DOWN


# 把曲线采样点转换为出生位置和方向后生成子弹。
func spawn_from_curve(
	bullet_layer: BulletLayer,
	bullet_scene: PackedScene,
	origin: Vector2,
	local_point: Vector2,
	tangent: Vector2,
	base_init_data: Dictionary = {}
) -> BulletBase:
	var direction: Vector2 = fallback_direction
	if use_tangent_as_direction:
		direction = tangent
	elif use_curve_point_as_direction:
		direction = local_point

	return spawn_bullet(bullet_layer, bullet_scene, origin + local_point, direction, base_init_data)


# 合并通用初始化数据和发射参数，并交给 BulletLayer 创建子弹。
func spawn_bullet(
	bullet_layer: BulletLayer,
	bullet_scene: PackedScene,
	spawn_position: Vector2,
	direction: Vector2,
	base_init_data: Dictionary = {}
) -> BulletBase:
	if bullet_layer == null:
		DebugState.debug_log("Bullet layer missing")
		return null

	if bullet_scene == null:
		DebugState.debug_log("Bullet scene missing")
		return null

	var spawn_direction: Vector2 = direction
	if spawn_direction.length() <= 0.001:
		spawn_direction = fallback_direction

	var init_data: Dictionary = base_init_data.duplicate()
	init_data["velocity"] = spawn_direction.normalized()
	init_data["speed"] = bullet_speed
	init_data["damage"] = damage
	init_data["acceleration"] = acceleration

	return bullet_layer.spawn_bullet(bullet_scene, spawn_position, init_data)
