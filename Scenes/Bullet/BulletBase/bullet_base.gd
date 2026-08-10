class_name BulletBase
extends Area2D

## 基础子弹：负责生命周期（生成/回收/碰撞/擦弹）。
## 运动学完全委托给 BulletMotion 策略，自身不保留速度/方向字段。

var damage: int = 1
var has_grazed: bool = false
var lifetime: float = 0.0
var motion: BulletMotion = null

var _age: float = 0.0
var _owner_layer: BulletLayer
var _active: bool = false


func _ready() -> void:
	DebugHelper.register_debug_drawable(self)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func setup(owner_layer: BulletLayer, spawn_position: Vector2, init_data: Dictionary = {}) -> void:
	_owner_layer = owner_layer
	global_position = spawn_position
	damage = init_data.get("damage", 1)
	collision_layer = init_data.get("collision_layer", collision_layer)
	collision_mask = init_data.get("collision_mask", collision_mask)
	has_grazed = false
	lifetime = init_data.get("lifetime", 0.0)

	var motion_config: BulletMotion = init_data.get("motion", null)
	motion = motion_config.duplicate() if motion_config != null else null
	if motion != null:
		motion.setup(self, init_data)

	_age = 0.0
	_active = true
	visible = true
	set_process(true)
	set_physics_process(true)
	monitoring = true
	monitorable = true


func recycle() -> void:
	if not _active:
		return
	_active = false
	has_grazed = false
	visible = false
	set_process(false)
	set_physics_process(false)
	call_deferred("_do_recycle")


func _do_recycle() -> void:
	monitoring = false
	monitorable = false
	if _owner_layer != null:
		_owner_layer.recycle_bullet(self)


func _process(delta: float) -> void:
	if lifetime > 0.0:
		_age += delta
		if _age >= lifetime:
			recycle()
			return
	if motion != null:
		motion.process(self, delta)


func try_mark_grazed() -> bool:
	if has_grazed or not _active:
		return false
	has_grazed = true
	return true


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		recycle()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		recycle()


func _draw() -> void:
	DebugHelper.draw_collision_shape(self, self as Area2D)
