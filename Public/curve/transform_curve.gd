@tool
class_name TransformCurve
extends ParametricCurve

@export var base: ParametricCurve
@export var rotation_degrees: float = 0.0
@export var scale: Vector2 = Vector2.ONE
@export var phase_offset: float = 0.0
@export var offset: Vector2 = Vector2.ZERO

func sample(t: float) -> Vector2:
	var active_base: ParametricCurve = base
	if active_base == null:
		active_base = CircleParametricCurve.new()
	var point: Vector2 = active_base.sample(t + phase_offset)
	return point.rotated(deg_to_rad(rotation_degrees)) * scale + offset
