@tool
class_name PointCurve
extends ParametricCurve

@export var point: Vector2 = Vector2.ZERO

func sample(_t: float) -> Vector2:
	return point
