class_name BossAttackPattern
extends BossPattern

var _spawn_rule: BulletSpawnRule = BulletSpawnRule.new()


func start_pattern(boss: Boss) -> void:
	super.start_pattern(boss)

	if _is_running:
		DebugState.debug_log("Boss attack start: %s" % get_pattern_label())


func stop_pattern() -> void:
	if _is_running:
		DebugState.debug_log("Boss attack stop: %s" % get_pattern_label())

	super.stop_pattern()


func fire_bullet(spawn_position: Vector2, direction: Vector2, speed: float, damage: int, acceleration: float = 0.0) -> void:
	if not _is_running:
		return

	if _boss == null:
		return

	_spawn_rule.bullet_speed = speed
	_spawn_rule.damage = damage
	_spawn_rule.acceleration = acceleration
	_spawn_rule.fallback_direction = Vector2.DOWN
	_spawn_rule.spawn_bullet(
		_boss.get_bullet_layer(),
		_boss.get_bullet_scene(),
		spawn_position,
		direction,
		_boss.get_enemy_bullet_init_data()
	)
