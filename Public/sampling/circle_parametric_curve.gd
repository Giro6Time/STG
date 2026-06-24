class_name CircleParametricCurve
extends ParametricCurve

@export var radius: float = 96.0
@export var angle_offset_degrees: float = 90.0


func sample(t: float) -> Vector2:
	var angle: float = TAU * t + deg_to_rad(angle_offset_degrees)
	return Vector2(cos(angle), sin(angle)) * radius


func tangent(t: float) -> Vector2:
	var angle: float = TAU * t + deg_to_rad(angle_offset_degrees)
	return Vector2(-sin(angle), cos(angle)).normalized()
