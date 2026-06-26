class_name DebugHelper
extends RefCounted

const DEBUG_COLLISION_GROUP: String = "debug_collision_drawables"
const DEBUG_CURVE_GROUP: String = "debug_curve_drawables"
const DEBUG_DRAW_LAYER_GROUP: String = "debug_draw_layers"


# 注册需要在调试碰撞显示开启时被独立绘制层读取的 CanvasItem。
static func register_debug_drawable(node: CanvasItem) -> void:
	if node == null:
		return

	if not node.is_in_group(DEBUG_COLLISION_GROUP):
		node.add_to_group(DEBUG_COLLISION_GROUP)

	queue_debug_redraw(node.get_tree())


# 注册能够提供曲线采样数据的节点，供调试绘制层显示弹幕形态。
static func register_curve_drawable(node: Node) -> void:
	if node == null:
		return

	if not node.is_in_group(DEBUG_CURVE_GROUP):
		node.add_to_group(DEBUG_CURVE_GROUP)

	queue_debug_redraw(node.get_tree())


# 移除不再需要绘制的曲线调试节点，避免阶段结束后残留旧曲线。
static func unregister_curve_drawable(node: Node) -> void:
	if node == null:
		return

	if node.is_in_group(DEBUG_CURVE_GROUP):
		node.remove_from_group(DEBUG_CURVE_GROUP)

	queue_debug_redraw(node.get_tree())


# 通知所有独立调试绘制层刷新画面。
static func queue_debug_redraw(tree: SceneTree) -> void:
	if tree == null:
		return

	tree.call_group(DEBUG_DRAW_LAYER_GROUP, "queue_redraw")


# 兼容旧的节点内绘制入口；实际碰撞框由 DebugDrawLayer 统一画到最上层。
static func draw_collision_shape(_drawer: CanvasItem, _owner_node: CollisionObject2D) -> void:
	return


# 根据碰撞层选择调试显示颜色。
static func get_debug_collision_color(collision_layer: int) -> Color:
	if (collision_layer & CollisionLayers.PLAYER) != 0:
		return Color(0.2, 1.0, 0.35, 1.0)
	if (collision_layer & CollisionLayers.PLAYER_BULLET) != 0:
		return Color(0.25, 0.85, 1.0, 1.0)
	if (collision_layer & CollisionLayers.ENEMY) != 0:
		return Color(1.0, 0.25, 0.25, 1.0)
	if (collision_layer & CollisionLayers.ENEMY_BULLET) != 0:
		return Color(1.0, 0.65, 0.15, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)
