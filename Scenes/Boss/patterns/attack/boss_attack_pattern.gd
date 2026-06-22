class_name BossAttackPattern
extends BossPattern


func start_pattern(boss: Boss) -> void:
	super.start_pattern(boss)

	if _is_running:
		DebugState.debug_log("Boss attack start: %s" % get_pattern_label())


func stop_pattern() -> void:
	if _is_running:
		DebugState.debug_log("Boss attack stop: %s" % get_pattern_label())

	super.stop_pattern()


func spawn_enemy_bullet(spawn_position: Vector2, direction: Vector2, speed: float, damage: int) -> void:
	if not _is_running:
		return

	if _boss == null:
		return

	_boss.spawn_enemy_bullet(spawn_position, direction, speed, damage)