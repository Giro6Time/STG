class_name BossMovementPattern
extends BossPattern


func start_pattern(boss: Boss) -> void:
	super.start_pattern(boss)

	if _is_running:
		DebugState.debug_log("Boss movement start: %s" % get_pattern_label())


func stop_pattern() -> void:
	if _is_running:
		DebugState.debug_log("Boss movement stop: %s" % get_pattern_label())

	super.stop_pattern()