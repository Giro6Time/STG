class_name BulletLayer
extends Node2D

const GROUP_NAME: String = "bullet_layers"

@export var despawn_margin: float = 64.0

@onready var active_bullets: Node2D = $ActiveBullets
@onready var inactive_bullets: Node2D = $InactiveBullets

var _pools: Dictionary = {}
var _scene_by_bullet: Dictionary = {}


# 将弹幕层注册到 group，供 Boss、敌人或子弹发射器按场景查找。
func _ready() -> void:
	add_to_group(GROUP_NAME)


# 从对象池取得子弹，初始化后放入活跃节点。
func spawn_bullet(
	bullet_scene: PackedScene,
	spawn_position: Vector2,
	init_data: Dictionary = {}
) -> BulletBase:
	if bullet_scene == null:
		return null

	var bullet: BulletBase = _get_bullet_from_pool(bullet_scene)
	active_bullets.add_child(bullet)

	bullet.setup(self, spawn_position, init_data)
	DebugState.debug_log("Spawn bullet: %s" % bullet.name, "Bullet")

	return bullet


# 把子弹从活跃列表移回对应场景的对象池。
func recycle_bullet(bullet: BulletBase) -> void:
	if bullet == null:
		return

	var bullet_scene: PackedScene = _scene_by_bullet.get(bullet)

	if bullet_scene == null:
		bullet.queue_free()
		return

	if bullet.get_parent() != null:
		bullet.get_parent().remove_child(bullet)

	inactive_bullets.add_child(bullet)

	if not _pools.has(bullet_scene):
		_pools[bullet_scene] = []

	_pools[bullet_scene].append(bullet)
	DebugState.debug_log("Recycle bullet: %s" % bullet.name, "Bullet")


# 回收当前所有活跃子弹，用于清屏或阶段切换。
func clear_all() -> void:
	for child in active_bullets.get_children():
		if child is BulletBase:
			child.recycle()


# 每帧清理飞出视口边界的子弹。
func _process(_delta: float) -> void:
	_cleanup_out_of_bounds()


# 优先复用对象池子弹，池空时实例化新子弹。
func _get_bullet_from_pool(bullet_scene: PackedScene) -> BulletBase:
	if not _pools.has(bullet_scene):
		_pools[bullet_scene] = []

	var pool: Array = _pools[bullet_scene]

	var bullet: BulletBase

	if pool.size() > 0:
		bullet = pool.pop_back()
	else:
		bullet = bullet_scene.instantiate() as BulletBase
		_scene_by_bullet[bullet] = bullet_scene

	if bullet.get_parent() != null:
		bullet.get_parent().remove_child(bullet)

	return bullet


# 检测活跃子弹是否离开扩展边界并回收。
func _cleanup_out_of_bounds() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var bounds: Rect2 = Rect2(
		Vector2(-despawn_margin, -despawn_margin),
		viewport_size + Vector2(despawn_margin * 2.0, despawn_margin * 2.0)
	)

	for child in active_bullets.get_children():
		if child is BulletBase:
			var bullet: BulletBase = child as BulletBase
			if not bounds.has_point(bullet.global_position):
				bullet.recycle()


# 返回当前活跃子弹数量供调试显示。
func get_active_bullet_count() -> int:
	return active_bullets.get_child_count()


# 返回对象池中待复用子弹数量供调试显示。
func get_inactive_bullet_count() -> int:
	return inactive_bullets.get_child_count()


# 返回活跃与待复用子弹总数。
func get_total_bullet_count() -> int:
	return get_active_bullet_count() + get_inactive_bullet_count()
