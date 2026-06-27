class_name BulletBase
extends Area2D

var velocity: Vector2 = Vector2.ZERO
var speed: float = 0.0
var acceleration: float = 0.0
var damage: int = 1
var has_grazed: bool = false

var _owner_layer: BulletLayer
var _active: bool = false


# 连接子弹命中回调并注册调试碰撞绘制。
func _ready() -> void:
	DebugHelper.register_debug_drawable(self)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


# 从对象池取出子弹后应用出生位置和初始化数据。
func setup(owner_layer: BulletLayer, spawn_position: Vector2, init_data: Dictionary = {}) -> void:
	_owner_layer = owner_layer
	global_position = spawn_position

	velocity = init_data.get("velocity", Vector2.UP)
	speed = init_data.get("speed", 600.0)
	acceleration = init_data.get("acceleration", 0.0)
	damage = init_data.get("damage", 1)
	collision_layer = init_data.get("collision_layer", collision_layer)
	collision_mask = init_data.get("collision_mask", collision_mask)
	has_grazed = false

	_active = true
	visible = true
	set_process(true)
	set_physics_process(true)
	monitoring = true
	monitorable = true


# 让活跃子弹停止运行并延迟归还对象池。
func recycle() -> void:
	if not _active:
		return

	_active = false
	has_grazed = false
	visible = false
	set_process(false)
	set_physics_process(false)
	call_deferred("_do_recycle")
	#monitoring = false
	#monitorable = false
#
	#if _owner_layer != null:
		#_owner_layer.recycle_bullet(self)


# 关闭碰撞检测并把子弹交回所属 BulletLayer。
func _do_recycle() ->void:
	monitoring = false
	monitorable = false

	if _owner_layer != null:
		_owner_layer.recycle_bullet(self)

# 按速度和加速度推进子弹位置。
func _process(delta: float) -> void:
	speed = max(speed + acceleration * delta, 0.0)
	global_position += velocity.normalized() * speed * delta


# 标记本轮出生已经触发过擦弹，返回值用于调用方决定是否提交 GrazeContext。
func try_mark_grazed() -> bool:
	if has_grazed or not _active:
		return false

	has_grazed = true
	return true


# 命中 Area2D 目标时造成伤害并回收子弹。
func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		recycle()


# 命中物理身体目标时造成伤害并回收子弹。
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		recycle()


# 在调试模式下绘制子弹碰撞形状。
func _draw() -> void:
	DebugHelper.draw_collision_shape(self, self as Area2D)
