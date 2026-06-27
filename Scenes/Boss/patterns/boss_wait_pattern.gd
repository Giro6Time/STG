class_name BossWaitPattern
extends FlowPattern

@export var duration: float = 1.0

var _elapsed: float = 0.0


# 把等待 Pattern 默认设为阶段完成所需条件。
func _init() -> void:
	required_for_phase_completion = true


# 开始等待并重置计时器。
func start_pattern(pattern_owner: Node) -> void:
	super.start_pattern(pattern_owner)
	_elapsed = 0.0

	if _is_running and duration <= 0.0:
		mark_completed()


# 累计等待时间，到达配置时长后完成 Pattern。
func update_pattern(runtime_data: FlowPhaseRuntimeData) -> void:
	if not _is_running:
		return

	_elapsed += runtime_data.delta
	if _elapsed >= duration:
		mark_completed()
