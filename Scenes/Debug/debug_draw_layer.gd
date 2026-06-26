class_name DebugDrawLayer
extends Node2D

@export var curve_point_radius: float = 2.5
@export var curve_line_width: float = 1.5
@export var collision_line_width: float = 1.5


# 注册独立调试绘制层，并在调试选项变化时刷新显示。
func _ready() -> void:
	z_index = 4095
	if not is_in_group(DebugHelper.DEBUG_DRAW_LAYER_GROUP):
		add_to_group(DebugHelper.DEBUG_DRAW_LAYER_GROUP)
	DebugState.debug_enabled_changed.connect(_on_debug_options_changed)
	DebugState.options_changed.connect(_on_debug_options_changed)


# 调试绘制需要跟随运行时对象移动，因此开启时每帧刷新。
func _process(_delta: float) -> void:
	if DebugState.debug_enabled and (DebugState.show_collision_shapes or DebugState.show_curve_visuals):
		queue_redraw()


# 统一绘制碰撞框和曲线，确保它们显示在玩法贴图上方。
func _draw() -> void:
	if not DebugState.debug_enabled:
		return

	if DebugState.show_collision_shapes:
		_draw_collision_shapes()
	if DebugState.show_curve_visuals:
		_draw_curve_visuals()


# 绘制所有注册节点的圆形碰撞体。
func _draw_collision_shapes() -> void:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(DebugHelper.DEBUG_COLLISION_GROUP)
	for index in range(nodes.size()):
		var owner_node: CollisionObject2D = nodes[index] as CollisionObject2D
		if owner_node != null and owner_node.is_inside_tree():
			_draw_collision_shape(owner_node)


# 把单个碰撞体的形状转换为全局坐标后绘制。
func _draw_collision_shape(owner_node: CollisionObject2D) -> void:
	var shape_node: CollisionShape2D = owner_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return

	if shape_node.shape is CircleShape2D:
		var circle_shape: CircleShape2D = shape_node.shape as CircleShape2D
		var radius_scale: float = max(abs(shape_node.global_scale.x), abs(shape_node.global_scale.y))
		var radius: float = circle_shape.radius * radius_scale
		var color: Color = DebugHelper.get_debug_collision_color(owner_node.collision_layer)
		var fill_color: Color = Color(color.r, color.g, color.b, 0.12)
		var line_color: Color = Color(color.r, color.g, color.b, 0.95)
		var center: Vector2 = to_local(shape_node.global_position)

		draw_circle(center, radius, fill_color)
		draw_arc(center, radius, 0.0, TAU, 48, line_color, collision_line_width)


# 绘制所有注册节点提供的曲线采样数据。
func _draw_curve_visuals() -> void:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(DebugHelper.DEBUG_CURVE_GROUP)
	for index in range(nodes.size()):
		var provider: Node = nodes[index]
		if provider != null and provider.is_inside_tree() and provider.has_method("get_debug_curve_draw_data"):
			var curves: Array = provider.call("get_debug_curve_draw_data")
			_draw_curve_data_list(curves)


# 绘制一个提供者返回的全部曲线数据。
func _draw_curve_data_list(curves: Array) -> void:
	for index in range(curves.size()):
		var curve_data: Dictionary = curves[index]
		_draw_curve_data(curve_data)


# 调用曲线自身的可视化方法，避免 Debug 层知道具体曲线类型。
func _draw_curve_data(curve_data: Dictionary) -> void:
	var curve: ParametricCurve = curve_data.get("curve") as ParametricCurve
	var sampler: ParameterSampler = curve_data.get("sampler") as ParameterSampler
	if curve == null or sampler == null:
		return

	curve.draw_debug_visual(
		self,
		sampler,
		curve_data.get("origin", Vector2.ZERO),
		curve_data.get("color", Color(0.8, 0.35, 1.0, 1.0)),
		curve_data.get("point_radius", curve_point_radius),
		curve_data.get("line_width", curve_line_width),
		curve_data.get("tangent_length", 12.0)
	)


# 调试开关变化时立即刷新或清空绘制内容。
func _on_debug_options_changed(_value = null) -> void:
	queue_redraw()
