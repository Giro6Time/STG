class_name ParametricCurve
extends Resource


# 返回参数 t 对应的局部坐标，基类默认提供零点。
func sample(_t: float) -> Vector2:
	return Vector2.ZERO


# 用相邻采样点近似计算曲线切线方向。
func tangent(t: float) -> Vector2:
	var step: float = 0.001
	var before: Vector2 = sample(t - step)
	var after: Vector2 = sample(t + step)
	var delta: Vector2 = after - before
	if delta.length() <= 0.001:
		return Vector2.RIGHT

	return delta.normalized()
