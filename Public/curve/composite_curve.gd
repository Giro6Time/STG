@tool
class_name CompositeCurve
extends ParametricCurve

enum CombineMode { ADD, MULTIPLY }

@export var curves: Array[ParametricCurve] = []
@export var combine_mode: CombineMode = CombineMode.ADD
@export var rotation_degrees: float = 0.0

func sample(t: float) -> Vector2:
	if curves.is_empty():
		return Vector2.ZERO
	var result: Vector2 = curves[0].sample(t)
	for i in range(1, curves.size()):
		var point: Vector2 = curves[i].sample(t)
		match combine_mode:
			CombineMode.ADD:
				result += point
			CombineMode.MULTIPLY:
				result *= point
	if rotation_degrees != 0.0:
		result = result.rotated(deg_to_rad(rotation_degrees))
	return result
