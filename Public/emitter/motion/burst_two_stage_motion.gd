class_name BurstTwoStageMotion
extends BulletMotion

@export var burst_speed: float = 0.0
@export var burst_acceleration: float = 0.0
@export var burst_duration: float = 0.2
@export var cruise_speed: float = 0.0
@export var cruise_acceleration: float = 0.0

var _velocity: Vector2 = Vector2.DOWN
var _in_burst: bool = false
var _burst_elapsed: float = 0.0
var _burst_speed_actual: float = 0.0
var _cruise_speed_actual: float = 0.0
var _speed: float = 0.0
var _acceleration: float = 0.0

func setup(_bullet: BulletBase, init_data: Dictionary = {}) -> void:
	_velocity = init_data.get("velocity", Vector2.DOWN)
	_in_burst = true
	_burst_elapsed = 0.0
	var launch_speed: float = float(init_data.get("speed", 0.0))
	_burst_speed_actual = burst_speed if burst_speed > 0.0 else launch_speed
	_cruise_speed_actual = cruise_speed if cruise_speed > 0.0 else launch_speed
	if _burst_speed_actual <= 0.0:
		_burst_speed_actual = 300.0
	if _cruise_speed_actual <= 0.0:
		_cruise_speed_actual = 300.0

func process(bullet: BulletBase, delta: float) -> void:
	if _in_burst:
		_burst_elapsed += delta
		if _burst_elapsed >= burst_duration:
			_in_burst = false
			_speed = _cruise_speed_actual
			_acceleration = cruise_acceleration
		else:
			_speed = _burst_speed_actual + burst_acceleration * _burst_elapsed
	else:
		_speed = max(_speed + _acceleration * delta, 0.0)
	bullet.global_position += _velocity.normalized() * _speed * delta
