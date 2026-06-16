class_name BulletLayer
extends Node2D

@export var despawn_margin: float = 64.0

@onready var active_bullets: Node2D = $ActiveBullets
@onready var inactive_bullets: Node2D = $InactiveBullets

var _pools: Dictionary = {}
var _scene_by_bullet: Dictionary = {}


func spawn_bullet(
	bullet_scene: PackedScene,
	spawn_position: Vector2,
	init_data: Dictionary = {}
) -> BulletBase:
	if bullet_scene == null:
		return null

	var bullet := _get_bullet_from_pool(bullet_scene)
	active_bullets.add_child(bullet)

	bullet.setup(self, spawn_position, init_data)

	return bullet


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


func clear_all() -> void:
	for child in active_bullets.get_children():
		if child is BulletBase:
			child.recycle()


func _process(_delta: float) -> void:
	_cleanup_out_of_bounds()

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


func _cleanup_out_of_bounds() -> void:
	var viewport_size := get_viewport_rect().size
	var bounds := Rect2(
		Vector2(-despawn_margin, -despawn_margin),
		viewport_size + Vector2(despawn_margin * 2.0, despawn_margin * 2.0)
	)

	for child in active_bullets.get_children():
		if child is BulletBase:
			var bullet := child as BulletBase
			if not bounds.has_point(bullet.global_position):
				bullet.recycle()
