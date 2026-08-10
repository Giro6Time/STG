class_name FollowCurveMotion
extends BulletMotion

@export var curve: ParametricCurve
@export var speed: float = 0.5

var _origin: Vector2 = Vector2.ZERO
var _t: float = 0.0

func setup(bullet: BulletBase, _init_data: Dictionary = {}) -> void:
	_origin = bullet.global_position
	_t = 0.0

func process(bullet: BulletBase, delta: float) -> void:
	if curve == null:
		return
	_t += speed * delta
	bullet.global_position = _origin + curve.sample(_t)
