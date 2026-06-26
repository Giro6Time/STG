@tool
class_name CircleParametricCurve
extends ParametricCurve

@export var radius: float = 96.0
@export var angle_offset_degrees: float = 90.0


# 把参数 t 映射到圆周上的局部坐标。
func sample(t: float) -> Vector2:
	var angle: float = TAU * t + deg_to_rad(angle_offset_degrees)
	return Vector2(cos(angle), sin(angle)) * radius


# 计算圆周上参数 t 对应的切线方向。
func tangent(t: float) -> Vector2:
	var angle: float = TAU * t + deg_to_rad(angle_offset_degrees)
	return Vector2(-sin(angle), cos(angle)).normalized()
