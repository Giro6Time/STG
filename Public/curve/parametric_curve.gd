@tool
class_name ParametricCurve
extends Resource

## 参数曲线基类：把参数 t（0..1）映射为局部坐标。
## 子类只需实现 sample()，tangent() 默认用差分近似；draw_debug_visual 供编辑器预览。

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


func draw_debug_visual(
	drawer: CanvasItem,
	sampler: ParameterSampler,
	origin: Vector2 = Vector2.ZERO,
	color: Color = Color(0.85, 0.3, 1.0, 0.95),
	point_radius: float = 2.5,
	line_width: float = 1.5,
	tangent_length: float = 12.0
) -> void:
	if drawer == null or sampler == null:
		return
	var values: Array[float] = sampler.sample_values()
	var previous_point: Vector2 = Vector2.ZERO
	var has_previous: bool = false
	for index in range(values.size()):
		var t: float = values[index]
		var world_point: Vector2 = origin + sample(t)
		var local_point: Vector2 = drawer.to_local(world_point)
		var tangent_end: Vector2 = drawer.to_local(world_point + tangent(t) * tangent_length)
		if has_previous:
			drawer.draw_line(previous_point, local_point, Color(color.r, color.g, color.b, 0.65), line_width)
		drawer.draw_circle(local_point, point_radius, color)
		drawer.draw_line(local_point, tangent_end, Color(0.4, 1.0, 1.0, 0.75), 1.0)
		previous_point = local_point
		has_previous = true
