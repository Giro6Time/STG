class_name BossMovementPattern
extends BossPattern


# 启动移动 Pattern，并输出移动开始日志。
func start_pattern(boss: Boss) -> void:
	super.start_pattern(boss)

	if _is_running:
		DebugState.debug_log("Boss movement start: %s" % get_pattern_label(), "Boss")


# 停止移动 Pattern，并输出移动停止日志。
func stop_pattern() -> void:
	if _is_running:
		DebugState.debug_log("Boss movement stop: %s" % get_pattern_label(), "Boss")

	super.stop_pattern()
