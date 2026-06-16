class_name BulletBase
extends Area2D

var velocity: Vector2 = Vector2.ZERO
var speed: float = 0.0
var damage: int = 1

var _owner_layer: BulletLayer
var _active: bool = false


func setup(owner_layer: BulletLayer, spawn_position: Vector2, init_data: Dictionary = {}) -> void:
	_owner_layer = owner_layer
	global_position = spawn_position

	velocity = init_data.get("velocity", Vector2.UP)
	speed = init_data.get("speed", 600.0)
	damage = init_data.get("damage", 1)

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
	visible = false
	set_process(false)
	set_physics_process(false)
	monitoring = false
	monitorable = false

	if _owner_layer != null:
		_owner_layer.recycle_bullet(self)


func _process(delta: float) -> void:
	global_position += velocity.normalized() * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		recycle()
