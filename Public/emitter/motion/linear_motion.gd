class_name LinearMotion
extends BulletMotion

@export var speed: float = 90.0
@export var acceleration: float = 0.0

var _velocity: Vector2 = Vector2.DOWN
var _speed: float = 90.0

func setup(_bullet: BulletBase, init_data: Dictionary = {}) -> void:
	_velocity = init_data.get("velocity", Vector2.DOWN)
	_speed = speed

func process(bullet: BulletBase, delta: float) -> void:
	_speed = max(_speed + acceleration * delta, 0.0)
	bullet.global_position += _velocity.normalized() * _speed * delta
