@tool
class_name FormulaCurve
extends ParametricCurve

@export var x_expr: String = "r * cos(TAU * t)"
@export var y_expr: String = "r * sin(TAU * t)"
@export var radius: float = 96.0

var _x_parsed: Expression = null
var _y_parsed: Expression = null
var _parsed_x_src: String = ""
var _parsed_y_src: String = ""
var _last_error: String = ""

func sample(t: float) -> Vector2:
	if not _ensure_parsed():
		return Vector2.ZERO
	var input: Array = [t, radius]
	var x: Variant = _x_parsed.execute(input)
	var y: Variant = _y_parsed.execute(input)
	if _x_parsed.has_execute_failed() or _y_parsed.has_execute_failed():
		_last_error = "Expression execute failed: %s / %s" % [_x_parsed.get_error_text(), _y_parsed.get_error_text()]
		return Vector2.ZERO
	return Vector2(float(x), float(y))

func _ensure_parsed() -> bool:
	if _parsed_x_src == x_expr and _parsed_y_src == y_expr and _x_parsed != null and _y_parsed != null:
		return true
	_x_parsed = Expression.new()
	_y_parsed = Expression.new()
	_parsed_x_src = x_expr
	_parsed_y_src = y_expr
	var input_names := ["t", "r"]
	var x_err := _x_parsed.parse(x_expr, input_names)
	var y_err := _y_parsed.parse(y_expr, input_names)
	if x_err != OK or y_err != OK:
		_last_error = "Expression parse failed: %s / %s" % [_x_parsed.get_error_text(), _y_parsed.get_error_text()]
		return false
	_last_error = ""
	return true

func get_last_error() -> String:
	return _last_error
