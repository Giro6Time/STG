class_name ParametricCurve
extends Resource


func sample(_t: float) -> Vector2:
	return Vector2.ZERO


func tangent(t: float) -> Vector2:
	var step: float = 0.001
	var before: Vector2 = sample(t - step)
	var after: Vector2 = sample(t + step)
	var delta: Vector2 = after - before
	if delta.length() <= 0.001:
		return Vector2.RIGHT

	return delta.normalized()
