@tool
class_name DebugCurvePreview2D
extends Node2D

@export var curve: ParametricCurve:
	set(value):
		curve = value
		queue_redraw()
@export var sampler: ParameterSampler:
	set(value):
		sampler = value
		queue_redraw()
@export var preview_enabled: bool = true:
	set(value):
		preview_enabled = value
		queue_redraw()
@export var point_radius: float = 2.5:
	set(value):
		point_radius = value
		queue_redraw()
@export var line_width: float = 1.5:
	set(value):
		line_width = value
		queue_redraw()
@export var tangent_length: float = 12.0:
	set(value):
		tangent_length = value
		queue_redraw()
@export var preview_color: Color = Color(0.85, 0.3, 1.0, 0.95):
	set(value):
		preview_color = value
		queue_redraw()


# 编辑器中持续刷新曲线预览，Inspector 改资源参数时能立即看到形态变化。
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


# 在编辑器中把预览职责交给 Curve 自己，预览节点只提供画布和显示参数。
func _draw() -> void:
	if not Engine.is_editor_hint() or not preview_enabled:
		return
	if curve == null or sampler == null:
		return

	curve.draw_debug_visual(
		self,
		sampler,
		global_position,
		preview_color,
		point_radius,
		line_width,
		tangent_length
	)
