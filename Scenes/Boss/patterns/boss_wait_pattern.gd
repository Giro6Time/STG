class_name BossWaitPattern
extends BossPattern

@export var duration: float = 1.0

var _elapsed: float = 0.0


# 把等待 Pattern 默认设为阶段完成所需条件。
func _init() -> void:
	required_for_phase_completion = true


# 开始等待并重置计时器。
func start_pattern(boss: Boss) -> void:
	super.start_pattern(boss)
	_elapsed = 0.0

	if _is_running and duration <= 0.0:
		mark_completed()


# 累计等待时间，到达配置时长后完成 Pattern。
func update_pattern(delta: float) -> void:
	if not _is_running:
		return

	_elapsed += delta
	if _elapsed >= duration:
		mark_completed()
