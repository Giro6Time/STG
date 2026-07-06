class_name BossHorizontalSweepMovement
extends BossMovementPattern

@export var amplitude: float = 80.0
@export var sweep_speed: float = 1.5

var _origin_position: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0


# 记录宿主初始位置，作为水平往复运动中心。
func start_pattern(pattern_owner: Node) -> void:
	super.start_pattern(pattern_owner)

	var owner_node: Node2D = get_owner_as_node2d()
	if _is_running and owner_node != null:
		_origin_position = owner_node.global_position
		_elapsed = 0.0


# 用正弦曲线驱动宿主在水平方向往复移动。
func update_pattern(runtime_data: FlowPhaseRuntimeData) -> void:
	if not _is_running:
		return

	var owner_node: Node2D = get_owner_as_node2d()
	if owner_node == null:
		return

	# 基础横向巡航，用于验证移动 Pattern；后续冲撞类移动可以做成独立 Pattern。
	_elapsed += runtime_data.delta
	var next_position: Vector2 = owner_node.global_position
	next_position.x = _origin_position.x + sin(_elapsed * sweep_speed) * amplitude
	owner_node.global_position = next_position
