class_name DebugHelper
extends RefCounted

const DEBUG_COLLISION_GROUP: String = "debug_collision_drawables"


# 注册需要在调试碰撞显示开启时重绘的 CanvasItem。
static func register_debug_drawable(node: CanvasItem) -> void:
	if node == null:
		return

	if not node.is_in_group(DEBUG_COLLISION_GROUP):
		node.add_to_group(DEBUG_COLLISION_GROUP)

	node.queue_redraw()


# 通知所有已注册节点刷新调试碰撞绘制。
static func queue_debug_collision_redraw(tree: SceneTree) -> void:
	if tree == null:
		return

	tree.call_group(DEBUG_COLLISION_GROUP, "queue_redraw")


# 按碰撞形状和阵营颜色绘制调试轮廓。
static func draw_collision_shape(drawer: CanvasItem, owner_node: CollisionObject2D) -> void:
	if drawer == null or owner_node == null:
		return

	if not DebugState.debug_enabled or not DebugState.show_collision_shapes:
		return

	var shape_node: CollisionShape2D = owner_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return

	if shape_node.shape is CircleShape2D:
		_draw_circle_shape(drawer, owner_node, shape_node)


# 把圆形碰撞体转换为本地绘制坐标并画出轮廓。
static func _draw_circle_shape(
	drawer: CanvasItem,
	owner_node: CollisionObject2D,
	shape_node: CollisionShape2D
) -> void:
	var circle_shape: CircleShape2D = shape_node.shape as CircleShape2D
	var radius_scale: float = max(abs(shape_node.scale.x), abs(shape_node.scale.y))
	var radius: float = circle_shape.radius * radius_scale
	var color: Color = _get_debug_collision_color(owner_node.collision_layer)
	var fill_color: Color = Color(color.r, color.g, color.b, 0.14)
	var line_color: Color = Color(color.r, color.g, color.b, 0.95)

	drawer.draw_circle(shape_node.position, radius, fill_color)
	drawer.draw_arc(shape_node.position, radius, 0.0, TAU, 48, line_color, 1.5)


# 根据碰撞层选择调试显示颜色。
static func _get_debug_collision_color(collision_layer: int) -> Color:
	if (collision_layer & CollisionLayers.PLAYER) != 0:
		return Color(0.2, 1.0, 0.35, 1.0)
	if (collision_layer & CollisionLayers.PLAYER_BULLET) != 0:
		return Color(0.25, 0.85, 1.0, 1.0)
	if (collision_layer & CollisionLayers.ENEMY) != 0:
		return Color(1.0, 0.25, 0.25, 1.0)
	if (collision_layer & CollisionLayers.ENEMY_BULLET) != 0:
		return Color(1.0, 0.65, 0.15, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)
